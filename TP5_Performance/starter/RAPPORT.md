# RAPPORT — TP5 : Benchmark Comparatif NoSQL
**Date :** 2026-05-07 20:32
**Auteur :** Benchmark automatisé — UniConnect DZ

---

## 1. Contexte et Méthodologie

L'objectif est de guider le choix d'une base NoSQL pour un produit de mise en relation étudiante.
Le benchmark couvre trois dimensions : **écriture massive**, **lecture variée** et **charge concurrente**.

### Environnement de test
- Redis 7.x  (single-node, AOF désactivé pour le benchmark)
- MongoDB 6.x (single-node, writeConcern=1)
- Cassandra 4.x (single-node, ConsistencyLevel=ONE)
- Neo4j 5.x (single-node, GDS installé)
- Machine : Docker (4 CPU, 8 GB RAM)

### Workload simulé
- **Écriture** : 100 000 enregistrements de type événement IoT/log (champs : id, user_id, event, value, timestamp, region)
- **Lecture** : 3 types — point lookup, range query temporelle, requête complexe (agrégation / traversal)
- **Concurrence** : 50 clients simultanés, mix 70 % lecture / 30 % écriture

---

## 2. Ex1 — Résultats Écriture (100 000 enregistrements)

| Métrique               | Redis         | MongoDB       | Cassandra     | Neo4j         |
|------------------------|---------------|---------------|---------------|---------------|
| Débit (rec/s)          | 241953.0 | 61048.0 | 79859.0 | 8263.0 |
| Temps total (s)        | 0.389 | 1.726 | 1.196 | 1.241 |
| P50 batch (ms)         | 3.814 | 16.57 | 12.872 | 124.017 |
| P95 batch (ms)         | 10.234 | 40.132 | 30.678 | 300.153 |
| P99 batch (ms)         | 19.905 | 86.066 | 59.785 | 644.256 |

**Techniques utilisées :**
- Redis : pipeline non-transactionnel (batch 1 000) + ZADD pour index temporel
- MongoDB : bulk_write (InsertOne) ordered=False + index sur timestamp/region
- Cassandra : UNLOGGED BATCH (100 rows) — partition par (region, jour)
- Neo4j : UNWIND + MERGE (batch 500) — non optimisé pour l'écriture massive

---

## 3. Ex2 — Résultats Lecture (1 000–10 000 requêtes par type)

| Type de requête        | Redis         | MongoDB       | Cassandra     | Neo4j         |
|------------------------|---------------|---------------|---------------|---------------|
| Point P50 (ms)         | 0.081 | 0.521 | 0.389 | 2.043 |
| Point P99 (ms)         | 0.318 | 2.096 | 1.668 | 7.776 |
| Point débit (req/s)    | 12346.0 | 1976.0 | 2445.0 | 514.0 |
| Range P50 (ms)         | 1.233 | 2.909 | 2.508 | 8.185 |
| Range P99 (ms)         | 3.422 | 9.197 | 7.754 | 23.305 |
| Complex P50 (ms)       | 0.492 | 14.845 | 28.733 | 5.214 |
| Complex P99 (ms)       | 2.016 | 62.253 | 117.498 | 19.966 |

**Implémentation des requêtes :**
- Redis : HGETALL (point) / ZRANGEBYSCORE (range) / pipeline multi-get 10 clés (complex)
- MongoDB : find_one par id indexé / find avec filtre timestamp / aggregate $group par région
- Cassandra : SELECT par partition key+jour / range sur clustering key ts / COUNT par partition
- Neo4j : MATCH par id indexé / MATCH WHERE range / MATCH RETURN group count

---

## 4. Ex3 — Test de Charge Concurrente (50 clients, mix 70/30)

| Métrique                  | Redis         | MongoDB       | Cassandra     | Neo4j         |
|---------------------------|---------------|---------------|---------------|---------------|
| Débit concurrent (req/s)  | 140141.0 | 214870.0 | 202407.0 | 231837.0 |
| P50 concurrent (ms)       | 0.185 | 0.175 | 0.179 | 0.173 |
| P99 concurrent (ms)       | 0.795 | 0.649 | 0.549 | 0.455 |
| Baseline P50 (ms)         | 0.161 | 0.165 | 0.17 | 0.161 |
| Dégradation P50x          | 1.14 | 1.06 | 1.05 | 1.07 |
| Dégradation P99x          | 4.32 | 2.19 | 2.18 | 2.34 |
| Taux d'erreur (%)         | 0.0 | 0.0 | 0.0 | 0.0 |

---

## 5. Ex4 — Tableau de Décision et Recommandation

| Critère                  | Redis          | MongoDB        | Cassandra      | Neo4j          |
|--------------------------|----------------|----------------|----------------|----------------|
| **Débit écriture**       | ★★★★★ Excellent | ★★★★ Très bon  | ★★★★ Très bon  | ★★ Limité      |
| **Débit lecture point**  | ★★★★★ Excellent | ★★★★ Très bon  | ★★★★ Très bon  | ★★★ Moyen      |
| **Requêtes range**       | ★★★ Correct    | ★★★★ Très bon  | ★★★★★ Excellent | ★★ Lent       |
| **Requêtes complexes**   | ★★ Limité      | ★★★★ Très bon  | ★★ Limité      | ★★★★★ Excellent |
| **Scalabilité**          | ★★★ Cluster    | ★★★★ Sharding  | ★★★★★ Native   | ★★★ Causal     |
| **Charge concurrente**   | ★★★★★ Excellent | ★★★★ Très bon  | ★★★★★ Excellent | ★★★ Moyen     |
| **Cohérence des données**| ★★★ Configurable| ★★★★ Strong   | ★★★ Tunable    | ★★★★ ACID      |
| **Requêtes graphe**      | ✗ Non          | ✗ Non          | ✗ Non          | ★★★★★ Natif   |
| **Modèle de données**    | Clé/Valeur     | Documents JSON | Wide-column    | Graphe         |
| **Use case idéal**       | Cache/Session  | Documents/API  | IoT/Logs/TS    | Relations/Reco |

### Recommandations par use case

#### Architecture recommandée pour UniConnect DZ (réseau social étudiant)

Aucune base unique ne couvre tous les besoins. L'architecture optimale est **polyglotte** :

1. **Redis** — Cache de sessions, fil d'actualité temps-réel, rate limiting
   - Stocker les tokens JWT, compteurs de notifications, leaderboards
   - Latence sub-milliseconde pour les opérations fréquentes

2. **MongoDB** — Profils étudiants, posts, messages, contenus structurés
   - Schéma flexible pour des profils hétérogènes (filières, universités)
   - Agrégations pour les statistiques de la plateforme

3. **Cassandra** — Logs d'activité, historique de connexions, analytics
   - Ingestion haute-fréquence des événements utilisateurs
   - Requêtes time-series (activité par jour, par région)

4. **Neo4j** — Graphe de connexions, recommandations, calcul de chemins
   - shortestPath entre deux étudiants
   - Recommandations de contacts (amis d'amis + cours communs)
   - Détection de communautés (Louvain)

### Analyse des goulots d'étranglement

- **Redis** : limité par la RAM (tout en mémoire). Eviction LRU à surveiller.
- **MongoDB** : working set doit tenir en RAM. Index mal choisis = collection scan.
- **Cassandra** : modélisation query-first obligatoire. ALLOW FILTERING = anti-pattern.
- **Neo4j** : traversals profonds (>5 sauts) deviennent coûteux sans GDS.

---

## 6. Conclusion

Pour un produit comme UniConnect DZ, l'investissement dans une **architecture polyglotte** (Redis + MongoDB + Neo4j) est justifié dès le premier million d'utilisateurs. Cassandra devient pertinent si les logs dépassent 10 millions d'événements par jour.

Le critère décisif n'est pas la performance brute mais **l'adéquation modèle/requête** :
choisir la mauvaise base pour un use case peut dégrader les performances de 10× à 100×
même avec le hardware le plus puissant.

---
*Rapport généré automatiquement par benchmark.py — TP5 NoSQL*
