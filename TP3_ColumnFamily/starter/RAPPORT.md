# RAPPORT TP3 — SmartGrid DZ : Cassandra IoT

---

## 1. Justification des Partition Keys et risques de hot partition

### Table mesures_par_capteur : PRIMARY KEY ((capteur_id, date_jour), timestamp)

La partition key composite `(capteur_id, date_jour)` a été choisie après avoir écarté deux alternatives.

La première alternative était `capteur_id` seul. C'est la première idée qui vient à l'esprit, mais elle est dangereuse : une seule partition contiendrait toutes les mesures d'un capteur depuis sa création. Avec une mesure par minute sur 5 ans, ça fait 2,6 millions de lignes par partition. Cassandra supporte des partitions larges, mais les performances se dégradent et la compaction devient coûteuse.

La deuxième alternative était `wilaya` seul. Encore pire : 5 partitions seulement pour 10 000 capteurs. C'est la définition d'une hot partition. Le nœud hébergeant la partition "Alger" recevrait environ 40% du trafic total à lui seul.

La solution retenue, `(capteur_id, date_jour)`, crée un bucket journalier par capteur. Chaque partition contient au maximum 1 440 mesures (une par minute sur 24h), ce qui est parfaitement gérable. On obtient environ 10 000 partitions actives par jour, bien distribuées sur le cluster via le partitioner.

### Table alertes_par_wilaya : PRIMARY KEY ((wilaya, date_jour), timestamp, capteur_id)

Ici la requête cible est clairement définie : "toutes les alertes de la wilaya X le jour Y". La partition key `(wilaya, date_jour)` est donc le choix naturel.

Le risque de hot partition existe théoriquement si une wilaya concentre toutes les alertes, mais avec 5 wilayas équilibrées et seulement ~10% des mesures déclenchant une alerte, la charge reste distribuée. Si une wilaya devenait problématique, on pourrait descendre au niveau commune dans la partition key.

On ajoute `capteur_id` en deuxième clustering key pour garantir l'unicité : deux capteurs différents peuvent générer une alerte exactement au même timestamp, et Cassandra a besoin d'une clé unique pour différencier ces lignes.

### Table agregats_horaires : PRIMARY KEY (wilaya, date_heure)

Pour les agrégats pré-calculés, `wilaya` seul comme partition key est acceptable. Le volume est très faible : une ligne par heure par wilaya, soit 5 × 24 × 365 = 43 800 lignes par an pour l'ensemble du système. Les partitions ne grossiront jamais de façon problématique.

---

## 2. Pourquoi ALLOW FILTERING est dangereux en production

`ALLOW FILTERING` contourne la règle fondamentale de Cassandra : chaque requête doit pouvoir être résolue en accédant à un nombre borné de partitions.

Quand on écrit `SELECT * FROM mesures_par_capteur WHERE wilaya = 'Alger' ALLOW FILTERING`, Cassandra ne peut pas utiliser le partitioner pour localiser les données, puisque `wilaya` n'est pas dans la partition key. Il doit donc contacter tous les nœuds du cluster et scanner toutes les partitions de la table, ligne par ligne, pour appliquer le filtre.

Avec 10 000 capteurs et 90 jours de données, ça représente potentiellement 1,3 milliard de lignes à lire pour en retourner quelques milliers. Les conséquences pratiques sont des timeouts en cascade, une pression mémoire sur les coordinateurs qui accumulent les résultats, et dans les cas extrêmes, des GC pauses qui rendent le cluster inaccessible.

La solution dans notre modèle est simple : on ne filtre jamais sur une colonne qui n'est pas dans la primary key. Si on a besoin de filtrer par wilaya, on utilise `alertes_par_wilaya` qui a justement `wilaya` dans sa partition key. Si un nouveau pattern de requête émerge, on crée une nouvelle table dédiée plutôt que d'utiliser ALLOW FILTERING.

---

## 3. Comparaison TWCS vs STCS vs LCS

### STCS : SizeTieredCompactionStrategy

C'est la stratégie par défaut. Elle fonctionne en regroupant les SSTables de taille similaire pour les compacter ensemble. Elle est bien adaptée aux charges d'écriture intensives et aux cas généraux, mais elle a deux inconvénients pour notre use case. Premièrement, les données récentes et anciennes se retrouvent mélangées dans les mêmes SSTables, ce qui signifie que Cassandra ne peut pas supprimer efficacement les données expirées par TTL : il faut lire la SSTable entière pour identifier les lignes expirées. Deuxièmement, elle crée de l'amplification d'espace disque temporaire lors des compactions (les fichiers source et destination coexistent).

**Quand l'utiliser :** Tables sans TTL, charges write-heavy, ou comme stratégie par défaut quand le pattern d'accès est mal défini.

### TWCS : TimeWindowCompactionStrategy

TWCS est la stratégie faite pour les séries temporelles avec TTL. Elle organise les SSTables en fenêtres de temps fixes (par exemple, une SSTable par jour). Les nouvelles données vont dans la fenêtre courante. Les fenêtres passées ne reçoivent plus d'écriture et sont compactées une seule fois. Quand le TTL expire pour une fenêtre entière, Cassandra peut simplement supprimer la SSTable sans aucune lecture. C'est l'avantage clé : la purge des données est une opération O(1), indépendante du volume.

**Quand l'utiliser :** Toute table avec TTL et des données temporelles. Dans SmartGrid DZ : mesures_par_capteur (TTL 90 jours, fenêtre 1 jour) et alertes_par_wilaya (TTL 1 an, fenêtre 7 jours).

**Attention :** TWCS fonctionne mal si on insère des données avec des timestamps très anciens (out-of-order writes), ce qui casse le modèle de fenêtres. Dans notre cas, l'ingestion est quasi temps-réel, donc aucun problème.

### LCS : LeveledCompactionStrategy

LCS organise les SSTables en niveaux (L0, L1, L2...) avec une taille max par niveau. Les lectures sont très efficaces car chaque niveau couvre l'ensemble des données et le nombre de SSTables à lire est minimal (au maximum `niveaux` SSTables). En revanche, le write amplification est élevé : chaque écriture peut déclencher une réorganisation en cascade entre les niveaux.

**Quand l'utiliser :** Tables avec un ratio lectures/écritures élevé, faible volume d'écriture, et où la latence de lecture est critique. Dans SmartGrid DZ : agregats_horaires est parfaitement adapté. Les agrégats sont écrits une fois par heure par wilaya (très peu d'écritures) et lus très fréquemment par les dashboards.

### Tableau récapitulatif

| Stratégie | Write perf | Read perf | Espace disque | TTL efficiency | Use case idéal |
|-----------|-----------|-----------|---------------|----------------|----------------|
| STCS | Excellente | Bonne | Variable | Faible | Charge générale, write-heavy |
| TWCS | Excellente | Bonne | Stable | Excellente | Séries temporelles avec TTL |
| LCS | Correcte | Excellente | Stable | Bonne | Read-heavy, faibles écritures |

---

## Bonus : Materialized Views

Les Materialized Views permettent de créer automatiquement une table secondaire maintenue à jour par Cassandra à chaque écriture dans la table de base. Cela évite d'écrire la logique de dénormalisation dans le code applicatif.

Exemple : créer une vue pour accéder aux mesures par wilaya sans avoir à maintenir une table séparée.

```sql
CREATE MATERIALIZED VIEW mesures_par_wilaya AS
    SELECT wilaya, date_jour, timestamp, capteur_id, tension_v, puissance_kw, alerte
    FROM mesures_par_capteur
    WHERE wilaya IS NOT NULL
      AND capteur_id IS NOT NULL
      AND date_jour IS NOT NULL
      AND timestamp IS NOT NULL
    PRIMARY KEY ((wilaya, date_jour), timestamp, capteur_id)
    WITH CLUSTERING ORDER BY (timestamp DESC, capteur_id ASC);
```

Cependant, les Materialized Views ont des limitations importantes en production. Chaque écriture dans la table de base déclenche une écriture supplémentaire dans la vue, ce qui double la charge d'écriture. En cas d'incohérence (par exemple après une panne), la vue et la table de base peuvent se désynchroniser. Pour ces raisons, beaucoup d'équipes préfèrent gérer la dénormalisation côté application plutôt que d'utiliser les Materialized Views en production à grande échelle.
