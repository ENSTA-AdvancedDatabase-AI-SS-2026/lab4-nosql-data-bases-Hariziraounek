// ============================================================
// TP4 — UniConnect DZ | Ex3 : Algorithmes de Graphe (6 pts)
// ============================================================

// ─── 3.1 : Plus court chemin entre Ahmed et Yasmina ──────────
// "Comment Ahmed peut-il rencontrer Yasmina ?"
MATCH p = shortestPath(
  (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT*..10]-(yasmina:Etudiant {prenom: "Yasmina"})
)
RETURN [n IN nodes(p) | n.prenom + " (" + n.universite + ")"] AS chemin,
       length(p) AS nb_intermediaires,
       [r IN relationships(p) | r.contexte]  AS contextes_rencontre;


// ─── 3.2 : Centralité de degré (Top 10 étudiants connectés) ──
// Étape A : Créer la projection du graphe en mémoire
CALL gds.graph.project(
  'reseau_social',
  'Etudiant',
  {
    CONNAIT: { orientation: 'UNDIRECTED' }
  }
);

// Étape B : Calculer la centralité de degré
CALL gds.degree.stream('reseau_social')
YIELD nodeId, score
WITH gds.util.asNode(nodeId) AS etudiant, score
RETURN etudiant.prenom     AS prenom,
       etudiant.nom        AS nom,
       etudiant.universite AS universite,
       etudiant.filiere    AS filiere,
       toInteger(score)    AS nb_connexions
ORDER BY nb_connexions DESC
LIMIT 10;


// ─── 3.3 : Détection de communautés — Algorithme de Louvain ──
// Identifier les cercles sociaux naturels du réseau
CALL gds.louvain.stream('reseau_social')
YIELD nodeId, communityId, intermediateCommunityIds
WITH communityId,
     collect(gds.util.asNode(nodeId).prenom)      AS membres_prenoms,
     collect(gds.util.asNode(nodeId).universite)  AS universites,
     count(*)                                      AS taille
RETURN communityId,
       taille,
       membres_prenoms[0..6]              AS exemples_membres,
       // Université dominante dans la communauté
       apoc.coll.sortMaps(
         [u IN universites |
            {uni: u, cnt: size([x IN universites WHERE x = u])}
         ], 'cnt'
       )[-1].uni                          AS universite_dominante
ORDER BY taille DESC;

// Version simplifiée (sans APOC) :
CALL gds.louvain.stream('reseau_social')
YIELD nodeId, communityId
WITH communityId,
     collect(gds.util.asNode(nodeId).prenom) AS membres,
     count(*) AS taille
RETURN communityId,
       taille,
       membres[0..5] AS exemple_membres
ORDER BY taille DESC;


// ─── 3.4 : Recommandation de contacts pour Ahmed ─────────────
// Score = nb_amis_communs×3 + nb_cours_communs×2 + (même_filière?1:0)
MATCH (moi:Etudiant {prenom: "Ahmed"})

// Candidats : non connus, différents de moi
MATCH (candidat:Etudiant)
WHERE candidat <> moi
  AND NOT (moi)-[:CONNAIT]-(candidat)

// Composante 1 : amis en commun
OPTIONAL MATCH (moi)-[:CONNAIT]-(ami_commun:Etudiant)-[:CONNAIT]-(candidat)

// Composante 2 : cours en commun
OPTIONAL MATCH (moi)-[:SUIT]->(cours_commun:Cours)<-[:SUIT]-(candidat)

WITH moi, candidat,
     count(DISTINCT ami_commun) AS nb_amis_communs,
     count(DISTINCT cours_commun) AS nb_cours_communs,
     CASE WHEN moi.filiere = candidat.filiere THEN 1 ELSE 0 END AS meme_filiere

// Calcul du score composite
WITH candidat,
     nb_amis_communs,
     nb_cours_communs,
     meme_filiere,
     (nb_amis_communs * 3) + (nb_cours_communs * 2) + meme_filiere AS score

WHERE score > 0

RETURN candidat.prenom     AS suggestion,
       candidat.universite AS universite,
       candidat.filiere    AS filiere,
       nb_amis_communs,
       nb_cours_communs,
       meme_filiere        AS meme_filiere,
       score
ORDER BY score DESC
LIMIT 5;


// ─── 3.5 : Chemin de compétences vers Machine Learning ────────
// "Quels cours dois-je suivre pour maîtriser Machine Learning ?"
// Via la chaîne Cours → REQUIERT → Competence
MATCH (comp_cible:Competence {nom: "Machine Learning"})

// Cours qui requièrent cette compétence directement
MATCH (cours:Cours)-[:REQUIERT]->(comp_cible)
RETURN "Cours direct" AS type_chemin,
       cours.intitule AS cours_recommande,
       cours.credits  AS credits,
       comp_cible.nom AS competence_cible;

// Chemin via compétences pré-requises (multi-sauts)
MATCH path = (debut:Cours)-[:REQUIERT*1..3]->(but:Competence {nom: "Machine Learning"})
RETURN [n IN nodes(path) |
  CASE
    WHEN n:Cours      THEN "📚 " + n.intitule
    WHEN n:Competence THEN "🎯 " + n.nom
  END
] AS parcours_apprentissage,
length(path) AS profondeur
ORDER BY profondeur;


// ─── Nettoyage de la projection GDS ───────────────────────────
CALL gds.graph.drop('reseau_social');
