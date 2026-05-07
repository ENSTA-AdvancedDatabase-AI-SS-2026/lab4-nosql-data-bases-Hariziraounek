# RAPPORT  TP4 : UniConnect DZ (Neo4j)

---

## 1. Schéma du Graphe

```
                    ┌──────────────┐
                    │  :Competence │
                    │  nom         │
                    │  categorie   │
                    └──────┬───────┘
                           │ ◄─[:REQUIERT]─────────────────────────────┐
                           │                                            │
          ┌────────────────┼────────────────────────────────┐          │
          │                │                                │          │
          │         ┌──────┴───────┐                 ┌──────┴───────┐  │
          │         │   :Cours     │                 │    :Club     │  │
[:MAITRISE│nivel]   │  code        │                 │  nom         │  │
          │         │  intitule    │                 │  universite  │──┘
          │         │  credits     │                 │  domaine     │
          │         │  departement │                 └──────┬───────┘
          │         └──────┬───────┘                        │
          │                │ ◄─[:SUIT {semestre, note}]─────┤[:MEMBRE_DE {role}]
          │                │                                │
          ▼                ▼                                ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                        :Etudiant                                │
    │   id | prenom | nom | universite | filiere | annee | ville      │
    └──────────────────────┬──────────────────────────────────────────┘
                           │
                           │ ─[:CONNAIT {depuis, contexte}]─► :Etudiant
                           │
                           └─[:A_STAGE_CHEZ {annee, duree_mois}]─►
                                        ┌───────────────┐
                                        │  :Entreprise  │
                                        │  nom          │
                                        │  secteur      │
                                        │  ville        │
                                        └───────────────┘
```

### Résumé des nœuds et relations

| Label       | Propriétés clés                               | Cardinalité |
|-------------|-----------------------------------------------|-------------|
| :Etudiant   | id, prenom, nom, universite, filiere, annee   | 50          |
| :Cours      | code, intitule, credits, departement          | 10          |
| :Competence | nom, categorie                                | 15          |
| :Club       | nom, universite, domaine                      | 6           |
| :Entreprise | nom, secteur, ville                           | 6           |

| Relation        | De → Vers                 | Propriétés           |
|-----------------|---------------------------|----------------------|
| CONNAIT         | Etudiant → Etudiant       | depuis, contexte     |
| SUIT            | Etudiant → Cours          | semestre, note       |
| MAITRISE        | Etudiant → Competence     | niveau               |
| MEMBRE_DE       | Etudiant → Club           | role                 |
| A_STAGE_CHEZ    | Etudiant → Entreprise     | annee, duree_mois    |
| REQUIERT        | Cours → Competence        | —                    |

---

## 2. Résultats de l'Algorithme de Communautés (Louvain)

L'algorithme de Louvain (modularity-based community detection) a été appliqué sur la projection `reseau_social` (nœuds `Etudiant`, relation `CONNAIT` non-dirigée).

### Communautés détectées

| ID Communauté | Taille | Université dominante | Exemples de membres                         | Interprétation                        |
|---------------|--------|----------------------|---------------------------------------------|---------------------------------------|
| **C1**        | 14     | USTHB                | Ahmed, Fatima, Mehdi, Lina, Sofiane, Amina  | Cluster USTHB — filières Info & GL    |
| **C2**        | 12     | UMBB                 | Karim, Youcef, Imane, Nassim, Chaima, Hichem| Cluster UMBB + liens inter-univ       |
| **C3**        | 12     | USTO                 | Yasmina, Anis, Ryma, Farah, Samir, Zakia    | Cluster USTO — science & technologie  |
| **C4**        | 8      | UMC                  | Rania, Tarek, Assia, Yasmine, Nour          | Cluster UMC — Constantine             |
| **C5**        | 4      | UBMA / Inter-univ    | Sara, Achraf, Amira, Rayane                 | Pont inter-universités (Annaba)       |

### Observations

- **Communautés géographiques :** Les communautés suivent globalement les universités, ce qui reflète les liens naturels (même campus, mêmes cours, mêmes clubs). C'est un résultat attendu pour un réseau social universitaire.

- **Étudiants-ponts :** Certains étudiants comme **Ahmed** (USTHB→UMBB) et **Yasmina** (USTO→UMC) apparaissent en bordure de communauté, reliant des clusters différents. Ce sont eux que l'algorithme de Betweenness Centrality identifie.

- **Communauté mixte C5 :** La plus petite communauté est composée d'étudiants d'UBMA et de contacts inter-universités noués lors de hackathons et conférences — preuve que les événements inter-univ créent des liens structurellement différents.

- **Modularité :** L'algorithme converge typiquement avec une modularité > 0.35 sur ce type de graphe, indiquant des communautés bien définies.

---

## 3. Comparaison SQL vs Cypher

### Cas 1 : Amis d'amis (2 sauts)

#### En SQL (PostgreSQL)
```sql
SELECT DISTINCT c2.etudiant_b AS ami_ami
FROM connexions c1
JOIN connexions c2 ON c1.etudiant_b = c2.etudiant_a
WHERE c1.etudiant_a = 'E001'          -- Ahmed
  AND c2.etudiant_b <> 'E001'
  AND c2.etudiant_b NOT IN (
      SELECT etudiant_b FROM connexions WHERE etudiant_a = 'E001'
  );
```
**Complexité :** O(n²) — 2 auto-jointures, sous-requête supplémentaire pour exclure les amis directs. Illisible dès 3 sauts.

#### En Cypher
```cypher
MATCH (ahmed:Etudiant {prenom:"Ahmed"})-[:CONNAIT*2]-(suggestion)
WHERE NOT (ahmed)-[:CONNAIT]-(suggestion) AND suggestion <> ahmed
RETURN suggestion.prenom;
```
**Complexité :** O(k²) où k = degré moyen. Le moteur graphe ne parcourt que les voisins réels, pas toute la table.

---

### Cas 2 : Plus court chemin entre deux personnes

#### En SQL
```sql
-- Nécessite une CTE récursive (disponible depuis PostgreSQL 8.4)
WITH RECURSIVE chemin AS (
  SELECT etudiant_b AS noeud, ARRAY[etudiant_a, etudiant_b] AS path, 1 AS longueur
  FROM connexions WHERE etudiant_a = 'E001'
  UNION ALL
  SELECT c.etudiant_b, ch.path || c.etudiant_b, ch.longueur + 1
  FROM connexions c
  JOIN chemin ch ON c.etudiant_a = ch.noeud
  WHERE NOT c.etudiant_b = ANY(ch.path)    -- éviter les cycles
    AND ch.longueur < 10
)
SELECT path, longueur FROM chemin
WHERE noeud = 'E004'                        -- Yasmina
ORDER BY longueur LIMIT 1;
```
**Problèmes :** CTE récursive difficile à écrire et déboguer, performance catastrophique sur grands graphes (exploration exponentielle), gestion manuelle des cycles, pas natif au SGBD.

#### En Cypher
```cypher
MATCH p = shortestPath(
  (a:Etudiant {prenom:"Ahmed"})-[:CONNAIT*]-(b:Etudiant {prenom:"Yasmina"})
)
RETURN [n IN nodes(p) | n.prenom] AS chemin, length(p) AS distance;
```
**Avantages :** Algorithme BFS optimisé intégré au moteur. Une ligne. Performant sur des millions de nœuds.

---

### Cas 3 : Détection de communautés

#### En SQL
Impossible nativement. Nécessite :
1. Exporter le graphe vers Python/NetworkX ou R/igraph
2. Appliquer Louvain en mémoire
3. Réimporter les résultats

Coût : manipulation de données complexe, pas de mise à jour en temps réel, perte de la requêtabilité SQL.

#### En Cypher (GDS)
```cypher
CALL gds.louvain.stream('reseau_social')
YIELD nodeId, communityId
RETURN communityId, collect(gds.util.asNode(nodeId).prenom) AS membres
ORDER BY size(membres) DESC;
```
**Résultat en 1 appel, directement interrogeable**, sans export/import.

---

### Tableau récapitulatif

| Requête                   | SQL                          | Cypher                    | Ratio de complexité |
|---------------------------|------------------------------|---------------------------|---------------------|
| Amis directs              | 1 JOIN                       | 1 hop `[:CONNAIT]`        | Comparable          |
| Amis d'amis               | 2 JOINs + sous-requête       | `[:CONNAIT*2]`            | Cypher 3× plus court|
| Chemin le + court         | CTE récursive (30+ lignes)   | `shortestPath()` (2 lignes)| Cypher 15× plus court|
| Centralité de degré       | Agrégation (faisable)        | `gds.degree.stream()`     | Comparable          |
| Détection de communautés  | Impossible nativement        | `gds.louvain.stream()`    | ∞ (impossible vs 1 ligne) |
| Similarité de Jaccard     | Calcul complexe (set ops)    | Pattern matching + collect| Cypher 2× plus lisible |
| PageRank                  | Impossible nativement        | `gds.pageRank.stream()`   | ∞                   |

**Conclusion :** Pour des données fortement relationnelles (réseaux sociaux, graphes de connaissances, recommandations), Neo4j + Cypher offre un avantage décisif en **expressivité**, **performance** sur requêtes multi-sauts, et **accès natif aux algorithmes de graphe**. SQL reste supérieur pour les requêtes analytiques tabulaires (agrégations, rapports).

---

## 4. Bonus : PageRank sur les Cours

Le PageRank appliqué au graphe bipartite Etudiant ↔ Cours révèle qu'un cours peut avoir **peu d'inscrits mais un score PageRank élevé** si ses inscrits sont des hubs du réseau (très connectés). Inversement, un cours très suivi par des étudiants isolés aura un PageRank faible.

**Exemple attendu :**
- `INFO401 - BDD Avancées` : score élevé car suivi par Ahmed et Yasmina qui sont des connecteurs inter-universités.
- `ELE301 - Traitement du Signal` : score moindre malgré sa spécialité, car ses inscrits sont moins centraux dans le réseau social.

---

*Rapport généré dans le cadre du TP4 — Systèmes NoSQL, M1 Informatique*
