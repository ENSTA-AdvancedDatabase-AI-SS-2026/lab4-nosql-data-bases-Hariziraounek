// ============================================================
// TP4 — UniConnect DZ | Ex2 : Requêtes de Base (4 pts)
// ============================================================

// ─── 2.1 : Tous les amis directs d'Ahmed (1 saut) ────────────
// Retourne les personnes qu'Ahmed connaît directement
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(ami:Etudiant)
RETURN ami.prenom        AS prenom,
       ami.nom           AS nom,
       ami.universite    AS universite,
       ami.filiere       AS filiere
ORDER BY ami.prenom;


// ─── 2.2 : Amis d'amis d'Ahmed (non déjà amis) ───────────────
// Suggestions de 2ème degré : personnes à 2 sauts mais pas à 1
MATCH (ahmed:Etudiant {prenom: "Ahmed"})-[:CONNAIT]-(intermediaire:Etudiant)
                                        -[:CONNAIT]-(suggestion:Etudiant)
WHERE  suggestion <> ahmed
  AND  NOT (ahmed)-[:CONNAIT]-(suggestion)
WITH   suggestion,
       count(DISTINCT intermediaire) AS amis_en_commun,
       collect(DISTINCT intermediaire.prenom) AS via
RETURN suggestion.prenom     AS suggestion,
       suggestion.universite AS universite,
       amis_en_commun,
       via
ORDER BY amis_en_commun DESC
LIMIT 10;


// ─── 2.3 : Étudiants dans le même cours que Fatima ───────────
// Qui suit les mêmes cours que Fatima sans la connaître ?
MATCH (fatima:Etudiant {prenom: "Fatima"})-[:SUIT]->(cours:Cours)
                              <-[:SUIT]-(autre:Etudiant)
WHERE autre <> fatima
  AND NOT (fatima)-[:CONNAIT]-(autre)
RETURN autre.prenom     AS prenom,
       autre.universite AS universite,
       collect(cours.intitule) AS cours_en_commun,
       count(cours)            AS nb_cours_partages
ORDER BY nb_cours_partages DESC;


// ─── 2.4 : Clubs les plus populaires ────────────────────────
// Classement par nombre de membres
MATCH (e:Etudiant)-[:MEMBRE_DE]->(c:Club)
RETURN c.nom        AS club,
       c.universite AS universite,
       c.domaine    AS domaine,
       count(e)     AS nb_membres
ORDER BY nb_membres DESC;


// ─── 2.5 : Profil complet d'un étudiant ─────────────────────
// Amis, cours suivis, compétences maîtrisées, clubs
MATCH (e:Etudiant {prenom: "Ahmed"})

// Amis directs
OPTIONAL MATCH (e)-[:CONNAIT]-(ami:Etudiant)

// Cours
OPTIONAL MATCH (e)-[s:SUIT]->(cours:Cours)

// Compétences
OPTIONAL MATCH (e)-[m:MAITRISE]->(comp:Competence)

// Clubs
OPTIONAL MATCH (e)-[mb:MEMBRE_DE]->(club:Club)

RETURN
  e.prenom + " " + e.nom      AS etudiant,
  e.universite                 AS universite,
  e.filiere                    AS filiere,
  e.annee                      AS annee,
  collect(DISTINCT ami.prenom) AS amis,
  collect(DISTINCT {cours: cours.intitule, note: s.note}) AS cours_suivis,
  collect(DISTINCT {competence: comp.nom, niveau: m.niveau}) AS competences,
  collect(DISTINCT {club: club.nom, role: mb.role}) AS clubs;
