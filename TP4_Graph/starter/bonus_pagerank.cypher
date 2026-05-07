// ============================================================
// TP4 — UniConnect DZ | BONUS : PageRank sur les Cours (3 pts)
// ============================================================
// Idée : un cours est "populaire" non seulement parce que beaucoup
// d'étudiants le suivent, mais aussi parce que ces étudiants sont
// eux-mêmes très connectés (influenceurs dans le réseau).
// PageRank propage cette influence via les relations SUIT.

// ─── Étape 1 : Projection du graphe bipartite Etudiant↔Cours ─
// On projette les étudiants ET les cours, reliés par SUIT
CALL gds.graph.project(
  'graphe_cours',
  ['Etudiant', 'Cours'],
  {
    SUIT: { orientation: 'NATURAL' }
  }
);

//  Étape 2 : PageRank sur les cours 
CALL gds.pageRank.stream('graphe_cours', {
  maxIterations: 20,
  dampingFactor: 0.85
})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS noeud, score
WHERE noeud:Cours                               // Filtrer uniquement les cours
RETURN noeud.code      AS code_cours,
       noeud.intitule  AS intitule,
       noeud.credits   AS credits,
       noeud.departement AS departement,
       round(score * 1000) / 1000.0 AS pagerank_score
ORDER BY pagerank_score DESC;

//  Étape 3 : Comparaison popularité brute vs PageRank 
// Popularité brute = nombre d'inscrits
MATCH (e:Etudiant)-[:SUIT]->(c:Cours)
WITH c, count(e) AS inscrits

// PageRank (lire depuis propriété stockée ou recalculer)
CALL gds.pageRank.stream('graphe_cours', {maxIterations:20, dampingFactor:0.85})
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS noeud, score, c, inscrits
WHERE noeud = c

RETURN c.code       AS code,
       c.intitule   AS cours,
       inscrits     AS nb_inscrits,
       round(score * 1000) / 1000.0 AS pagerank,
       // Rang popularité brute vs PageRank peut différer si
       // les inscrits sont eux-mêmes des hubs du réseau
       CASE WHEN score > 0.5 AND inscrits >= 3 THEN "⭐ Très influent"
            WHEN score > 0.3 THEN "Influent"
            ELSE "Standard" END AS statut
ORDER BY pagerank DESC;

// Étape 4 : Étudiants-ambassadeurs par cours 
// Étudiants les plus connectés qui suivent chaque cours
// = ambassadeurs naturels pour recruter d'autres étudiants
CALL gds.graph.project(
  'reseau_etudiants',
  'Etudiant',
  { CONNAIT: { orientation: 'UNDIRECTED' } }
);

CALL gds.degree.stream('reseau_etudiants')
YIELD nodeId, score AS degre
WITH gds.util.asNode(nodeId) AS etudiant, degre

MATCH (etudiant)-[:SUIT]->(c:Cours)
WITH c,
     etudiant,
     degre,
     rank() OVER {PARTITION BY c.code ORDER BY degre DESC} AS rang_dans_cours

WHERE rang_dans_cours <= 3
RETURN c.intitule      AS cours,
       etudiant.prenom AS ambassadeur,
       etudiant.universite AS universite,
       toInteger(degre) AS connexions,
       rang_dans_cours  AS rang
ORDER BY cours, rang_dans_cours;

// Nettoyage 
CALL gds.graph.drop('graphe_cours');
CALL gds.graph.drop('reseau_etudiants');
