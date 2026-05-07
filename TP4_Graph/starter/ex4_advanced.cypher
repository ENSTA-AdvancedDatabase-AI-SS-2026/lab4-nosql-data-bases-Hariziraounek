// ============================================================
// TP4 — UniConnect DZ | Ex4 : Requêtes Avancées (6 pts)
// ============================================================

// ─── 4.1 : Trouver un tuteur ─────────────────────────────────
// "Étudiant en Master (annee 4+) qui maîtrise Python
//  ET a eu une note > 14/20 en BDD (INFO401)"
MATCH (tuteur:Etudiant)-[m:MAITRISE]->(comp:Competence {nom: "Python"})
MATCH (tuteur)-[s:SUIT]->(bdd:Cours {code: "INFO401"})
WHERE tuteur.annee >= 4
  AND s.note > 14
RETURN tuteur.prenom      AS prenom,
       tuteur.nom         AS nom,
       tuteur.universite  AS universite,
       tuteur.filiere     AS filiere,
       tuteur.annee       AS annee,
       m.niveau           AS niveau_python,
       s.note             AS note_bdd
ORDER BY s.note DESC, tuteur.annee DESC;


// ─── 4.2 : Réseau alumni dans une entreprise ─────────────────
// "Qui dans mon réseau (jusqu'à 3 sauts) a fait un stage chez Sonatrach ?"
MATCH (moi:Etudiant {prenom: "Ahmed"})
MATCH path = (moi)-[:CONNAIT*1..3]-(contact:Etudiant)
                  -[:A_STAGE_CHEZ]->(ent:Entreprise {nom: "Sonatrach"})
WHERE contact <> moi
WITH contact,
     ent,
     min(length(path)) - 1 AS distance_reseau,    // -1 pour ne pas compter le lien stage
     collect(DISTINCT [n IN nodes(path) | n.prenom])[0] AS chemin_exemple
RETURN contact.prenom     AS contact,
       contact.universite AS universite,
       ent.nom            AS entreprise,
       ent.secteur        AS secteur,
       distance_reseau    AS degres_separation,
       chemin_exemple     AS chemin
ORDER BY distance_reseau;


// ─── 4.3 : Détection de ponts (étudiants connecteurs) ────────
// Étudiants qui servent de pont entre différentes universités
// = connectés à des étudiants d'au moins 3 universités différentes
MATCH (pont:Etudiant)-[:CONNAIT]-(voisin:Etudiant)
WHERE pont.universite <> voisin.universite   // lien inter-université
WITH pont,
     collect(DISTINCT voisin.universite) AS universites_connectees,
     count(DISTINCT voisin.universite)   AS nb_universites_distinctes,
     count(DISTINCT voisin)              AS nb_voisins_inter_univ
WHERE nb_universites_distinctes >= 2
RETURN pont.prenom              AS etudiant_pont,
       pont.universite          AS universite_origine,
       nb_universites_distinctes,
       nb_voisins_inter_univ,
       universites_connectees
ORDER BY nb_universites_distinctes DESC, nb_voisins_inter_univ DESC;

// Version GDS — Betweenness Centrality (étudiants les plus "pont")
// (nécessite la projection reseau_social créée en Ex3)
CALL gds.graph.project('reseau_social2', 'Etudiant', {CONNAIT:{orientation:'UNDIRECTED'}});

CALL gds.betweenness.stream('reseau_social2')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS e, score
WHERE score > 0
RETURN e.prenom     AS etudiant,
       e.universite AS universite,
       round(score) AS score_betweenness
ORDER BY score DESC
LIMIT 10;

CALL gds.graph.drop('reseau_social2');


// ─── 4.4 : Analyse temporelle ────────────────────────────────
// Croissance du réseau : nombre de connexions créées par année
MATCH ()-[r:CONNAIT]->()
WHERE r.depuis IS NOT NULL
RETURN r.depuis                AS annee,
       count(r)                AS nouvelles_connexions,
       sum(count(r)) OVER {    // cumul progressif
         ORDER BY r.depuis
         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       } AS total_cumule
ORDER BY annee;

// Version compatible Neo4j < 5 (sans fenêtrage):
MATCH ()-[r:CONNAIT]->()
RETURN r.depuis  AS annee,
       count(r)  AS nouvelles_connexions
ORDER BY annee;

// Contexte des connexions (comment se sont-ils rencontrés ?)
MATCH ()-[r:CONNAIT]->()
RETURN r.contexte AS mode_rencontre,
       count(r)   AS occurences
ORDER BY occurences DESC;


// ─── 4.5 : Score de similarité de Jaccard ────────────────────
// "Étudiants les plus similaires à Ahmed"
// Jaccard = |A ∩ B| / |A ∪ B|  (sur cours + compétences + clubs)
MATCH (moi:Etudiant {prenom: "Ahmed"})

// Collecter les entités d'Ahmed
OPTIONAL MATCH (moi)-[:SUIT]->(c:Cours)
WITH moi, collect(DISTINCT c.code) AS mes_cours
OPTIONAL MATCH (moi)-[:MAITRISE]->(comp:Competence)
WITH moi, mes_cours, collect(DISTINCT comp.nom) AS mes_comps
OPTIONAL MATCH (moi)-[:MEMBRE_DE]->(club:Club)
WITH moi, mes_cours, mes_comps, collect(DISTINCT club.nom) AS mes_clubs

// Pour chaque autre étudiant
MATCH (autre:Etudiant)
WHERE autre <> moi

OPTIONAL MATCH (autre)-[:SUIT]->(c2:Cours)
WITH moi, mes_cours, mes_comps, mes_clubs, autre,
     collect(DISTINCT c2.code) AS leurs_cours
OPTIONAL MATCH (autre)-[:MAITRISE]->(comp2:Competence)
WITH moi, mes_cours, mes_comps, mes_clubs, autre, leurs_cours,
     collect(DISTINCT comp2.nom) AS leurs_comps
OPTIONAL MATCH (autre)-[:MEMBRE_DE]->(club2:Club)
WITH mes_cours, mes_comps, mes_clubs, autre, leurs_cours, leurs_comps,
     collect(DISTINCT club2.nom) AS leurs_clubs

// Calcul Jaccard pour chaque dimension
WITH autre,
     // Jaccard cours
     toFloat(size([x IN mes_cours WHERE x IN leurs_cours]))  /
     toFloat(size(apoc.coll.union(mes_cours, leurs_cours)) + 0.001)  AS j_cours,
     // Jaccard compétences
     toFloat(size([x IN mes_comps WHERE x IN leurs_comps]))  /
     toFloat(size(apoc.coll.union(mes_comps, leurs_comps)) + 0.001)  AS j_comps,
     // Jaccard clubs
     toFloat(size([x IN mes_clubs WHERE x IN leurs_clubs]))  /
     toFloat(size(apoc.coll.union(mes_clubs, leurs_clubs)) + 0.001)  AS j_clubs

WITH autre,
     round(100 * (j_cours * 0.4 + j_comps * 0.4 + j_clubs * 0.2)) / 100.0
     AS score_jaccard_pondere

WHERE score_jaccard_pondere > 0

RETURN autre.prenom     AS etudiant,
       autre.universite AS universite,
       autre.filiere    AS filiere,
       score_jaccard_pondere AS similarite
ORDER BY similarite DESC
LIMIT 5;

// ── Version sans APOC (Jaccard manuel sur les cours) ─────────
MATCH (moi:Etudiant {prenom: "Ahmed"})-[:SUIT]->(c:Cours)
WITH moi, collect(c.code) AS mes_cours

MATCH (autre:Etudiant)-[:SUIT]->(c2:Cours)
WHERE autre <> moi
WITH moi, mes_cours, autre, collect(c2.code) AS leurs_cours

// Intersection et union manuelles
WITH autre,
     [x IN mes_cours WHERE x IN leurs_cours]    AS intersection,
     [x IN mes_cours WHERE NOT x IN leurs_cours]
     + leurs_cours                               AS union_approx

WITH autre,
     toFloat(size(intersection)) /
     toFloat(size(union_approx) + 0.001)         AS jaccard_cours

WHERE jaccard_cours > 0
RETURN autre.prenom     AS etudiant,
       autre.universite AS universite,
       round(100 * jaccard_cours) / 100.0        AS similarite_cours
ORDER BY jaccard_cours DESC
LIMIT 5;
