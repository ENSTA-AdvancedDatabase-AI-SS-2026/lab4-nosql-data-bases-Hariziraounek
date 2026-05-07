// ============================================================
// TP4 — UniConnect DZ | Ex1 : Modélisation et Import du Graphe
// ============================================================

// Nettoyage initial
MATCH (n) DETACH DELETE n;

// Contraintes d'unicité
CREATE CONSTRAINT etudiant_id IF NOT EXISTS FOR (e:Etudiant) REQUIRE e.id IS UNIQUE;
CREATE CONSTRAINT cours_code  IF NOT EXISTS FOR (c:Cours)    REQUIRE c.code IS UNIQUE;
CREATE CONSTRAINT competence_nom IF NOT EXISTS FOR (c:Competence) REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT club_nom    IF NOT EXISTS FOR (c:Club)     REQUIRE c.nom IS UNIQUE;
CREATE CONSTRAINT entreprise_nom IF NOT EXISTS FOR (e:Entreprise) REQUIRE e.nom IS UNIQUE;

// 1.2a : Compétences 
UNWIND [
  {nom: "Python",          categorie: "Programmation"},
  {nom: "Java",            categorie: "Programmation"},
  {nom: "C++",             categorie: "Programmation"},
  {nom: "SQL",             categorie: "Bases de Données"},
  {nom: "NoSQL",           categorie: "Bases de Données"},
  {nom: "Machine Learning",categorie: "IA"},
  {nom: "Deep Learning",   categorie: "IA"},
  {nom: "React",           categorie: "Web"},
  {nom: "Node.js",         categorie: "Web"},
  {nom: "Docker",          categorie: "DevOps"},
  {nom: "Linux",           categorie: "Systèmes"},
  {nom: "Réseaux",         categorie: "Infrastructure"},
  {nom: "Cybersécurité",   categorie: "Infrastructure"},
  {nom: "Mathématiques",   categorie: "Sciences"},
  {nom: "Statistiques",    categorie: "Sciences"}
] AS comp
MERGE (:Competence {nom: comp.nom, categorie: comp.categorie});

// 1.2b : Cours 
UNWIND [
  {code: "INFO401", intitule: "Bases de Données Avancées",  credits: 6, dept: "Informatique"},
  {code: "INFO402", intitule: "Intelligence Artificielle",   credits: 6, dept: "Informatique"},
  {code: "INFO403", intitule: "Développement Web",           credits: 4, dept: "Informatique"},
  {code: "INFO404", intitule: "Systèmes Distribués",         credits: 5, dept: "Informatique"},
  {code: "INFO405", intitule: "Cloud Computing",             credits: 4, dept: "Informatique"},
  {code: "INFO406", intitule: "Sécurité Informatique",       credits: 4, dept: "Informatique"},
  {code: "MATH301", intitule: "Probabilités et Statistiques",credits: 4, dept: "Mathématiques"},
  {code: "MATH302", intitule: "Algèbre Linéaire",            credits: 3, dept: "Mathématiques"},
  {code: "ELE301",  intitule: "Traitement du Signal",        credits: 5, dept: "Electronique"},
  {code: "TEL301",  intitule: "Réseaux et Protocoles",       credits: 5, dept: "Telecoms"}
] AS c
MERGE (:Cours {code: c.code, intitule: c.intitule, credits: c.credits, departement: c.dept});

//  Cours → Compétences requises 
MATCH (c1:Cours {code:"INFO401"}), (s:Competence {nom:"SQL"})    MERGE (c1)-[:REQUIERT]->(s);
MATCH (c1:Cours {code:"INFO401"}), (s:Competence {nom:"NoSQL"})  MERGE (c1)-[:REQUIERT]->(s);
MATCH (c2:Cours {code:"INFO402"}), (s:Competence {nom:"Machine Learning"}) MERGE (c2)-[:REQUIERT]->(s);
MATCH (c2:Cours {code:"INFO402"}), (s:Competence {nom:"Python"}) MERGE (c2)-[:REQUIERT]->(s);
MATCH (c2:Cours {code:"INFO402"}), (s:Competence {nom:"Statistiques"}) MERGE (c2)-[:REQUIERT]->(s);
MATCH (c3:Cours {code:"INFO403"}), (s:Competence {nom:"React"})  MERGE (c3)-[:REQUIERT]->(s);
MATCH (c3:Cours {code:"INFO403"}), (s:Competence {nom:"Node.js"})MERGE (c3)-[:REQUIERT]->(s);
MATCH (c4:Cours {code:"INFO404"}), (s:Competence {nom:"Docker"}) MERGE (c4)-[:REQUIERT]->(s);
MATCH (c4:Cours {code:"INFO404"}), (s:Competence {nom:"Linux"})  MERGE (c4)-[:REQUIERT]->(s);
MATCH (c5:Cours {code:"INFO405"}), (s:Competence {nom:"Docker"}) MERGE (c5)-[:REQUIERT]->(s);
MATCH (c6:Cours {code:"INFO406"}), (s:Competence {nom:"Cybersécurité"}) MERGE (c6)-[:REQUIERT]->(s);
MATCH (c6:Cours {code:"INFO406"}), (s:Competence {nom:"Linux"})  MERGE (c6)-[:REQUIERT]->(s);
MATCH (c7:Cours {code:"MATH301"}), (s:Competence {nom:"Statistiques"}) MERGE (c7)-[:REQUIERT]->(s);
MATCH (c7:Cours {code:"MATH301"}), (s:Competence {nom:"Mathématiques"}) MERGE (c7)-[:REQUIERT]->(s);
MATCH (c8:Cours {code:"MATH302"}), (s:Competence {nom:"Mathématiques"}) MERGE (c8)-[:REQUIERT]->(s);
MATCH (c9:Cours {code:"TEL301"}), (s:Competence {nom:"Réseaux"})  MERGE (c9)-[:REQUIERT]->(s);

//  1.2c : Clubs 
UNWIND [
  {nom: "Club IA USTHB",      universite: "USTHB", domaine: "Intelligence Artificielle"},
  {nom: "Club Cyber USTHB",   universite: "USTHB", domaine: "Cybersécurité"},
  {nom: "Club Dev UMBB",      universite: "UMBB",  domaine: "Développement Logiciel"},
  {nom: "Club Robotique USTO",universite: "USTO",  domaine: "Robotique"},
  {nom: "Club Data UMC",      universite: "UMC",   domaine: "Data Science"},
  {nom: "Club IoT UBMA",      universite: "UBMA",  domaine: "Internet des Objets"}
] AS cl
MERGE (:Club {nom: cl.nom, universite: cl.universite, domaine: cl.domaine});

// 1.2d : Entreprises 
UNWIND [
  {nom: "Sonatrach",   secteur: "Énergie",         ville: "Alger"},
  {nom: "Mobilis",     secteur: "Télécommunications",ville: "Alger"},
  {nom: "Djezzy",      secteur: "Télécommunications",ville: "Alger"},
  {nom: "NCA Rouiba",  secteur: "Agroalimentaire",  ville: "Alger"},
  {nom: "Ooredoo",     secteur: "Télécommunications",ville: "Alger"},
  {nom: "Condor",      secteur: "Électronique",      ville: "Bordj Bou Arreridj"}
] AS ent
MERGE (:Entreprise {nom: ent.nom, secteur: ent.secteur, ville: ent.ville});

//  1.3 : 50 Étudiants
UNWIND [
  // USTHB — Alger (10 étudiants)
  {id:"E001",prenom:"Ahmed",   nom:"Bensalem",  universite:"USTHB",filiere:"Informatique",  annee:3,ville:"Alger"},
  {id:"E002",prenom:"Fatima",  nom:"Ouali",     universite:"USTHB",filiere:"Informatique",  annee:3,ville:"Alger"},
  {id:"E006",prenom:"Mehdi",   nom:"Derbal",    universite:"USTHB",filiere:"Electronique",  annee:2,ville:"Alger"},
  {id:"E009",prenom:"Lina",    nom:"Boudia",    universite:"USTHB",filiere:"Informatique",  annee:1,ville:"Alger"},
  {id:"E011",prenom:"Sofiane", nom:"Kaci",      universite:"USTHB",filiere:"GL",            annee:4,ville:"Alger"},
  {id:"E012",prenom:"Meriem",  nom:"Benali",    universite:"USTHB",filiere:"Mathématiques", annee:3,ville:"Alger"},
  {id:"E013",prenom:"Walid",   nom:"Toumi",     universite:"USTHB",filiere:"Informatique",  annee:2,ville:"Alger"},
  {id:"E014",prenom:"Nadia",   nom:"Sahraoui",  universite:"USTHB",filiere:"Electronique",  annee:3,ville:"Alger"},
  {id:"E015",prenom:"Bilal",   nom:"Hadjali",   universite:"USTHB",filiere:"GL",            annee:1,ville:"Alger"},
  {id:"E016",prenom:"Amina",   nom:"Zerrouki",  universite:"USTHB",filiere:"Informatique",  annee:4,ville:"Alger"},
  // UMBB — Boumerdes (10 étudiants)
  {id:"E003",prenom:"Karim",   nom:"Meziane",   universite:"UMBB", filiere:"Informatique",  annee:2,ville:"Boumerdes"},
  {id:"E008",prenom:"Youcef",  nom:"Cherif",    universite:"UMBB", filiere:"Mathématiques", annee:4,ville:"Boumerdes"},
  {id:"E017",prenom:"Imane",   nom:"Bouzidi",   universite:"UMBB", filiere:"GL",            annee:3,ville:"Boumerdes"},
  {id:"E018",prenom:"Nassim",  nom:"Aouina",    universite:"UMBB", filiere:"Informatique",  annee:2,ville:"Boumerdes"},
  {id:"E019",prenom:"Leila",   nom:"Oukaci",    universite:"UMBB", filiere:"Mathématiques", annee:1,ville:"Boumerdes"},
  {id:"E020",prenom:"Redouane",nom:"Ferhat",    universite:"UMBB", filiere:"Electronique",  annee:3,ville:"Boumerdes"},
  {id:"E021",prenom:"Chaima",  nom:"Maarouf",   universite:"UMBB", filiere:"Informatique",  annee:4,ville:"Boumerdes"},
  {id:"E022",prenom:"Adel",    nom:"Benkhaled", universite:"UMBB", filiere:"GL",            annee:2,ville:"Boumerdes"},
  {id:"E023",prenom:"Sonia",   nom:"Bellouti",  universite:"UMBB", filiere:"Telecoms",      annee:3,ville:"Boumerdes"},
  {id:"E024",prenom:"Hichem",  nom:"Rahmouni",  universite:"UMBB", filiere:"Informatique",  annee:1,ville:"Boumerdes"},
  // USTO — Oran (10 étudiants)
  {id:"E004",prenom:"Yasmina", nom:"Hamdi",     universite:"USTO", filiere:"Informatique",  annee:4,ville:"Oran"},
  {id:"E010",prenom:"Anis",    nom:"Haddar",    universite:"USTO", filiere:"GL",            annee:3,ville:"Oran"},
  {id:"E025",prenom:"Ryma",    nom:"Bendjelloul",universite:"USTO",filiere:"Informatique",  annee:2,ville:"Oran"},
  {id:"E026",prenom:"Lotfi",   nom:"Belabes",   universite:"USTO", filiere:"Electronique",  annee:3,ville:"Oran"},
  {id:"E027",prenom:"Houda",   nom:"Drici",     universite:"USTO", filiere:"GL",            annee:1,ville:"Oran"},
  {id:"E028",prenom:"Mourad",  nom:"Chikhi",    universite:"USTO", filiere:"Mathématiques", annee:4,ville:"Oran"},
  {id:"E029",prenom:"Farah",   nom:"Benzerga",  universite:"USTO", filiere:"Informatique",  annee:3,ville:"Oran"},
  {id:"E030",prenom:"Samir",   nom:"Tlemcani",  universite:"USTO", filiere:"Telecoms",      annee:2,ville:"Oran"},
  {id:"E031",prenom:"Zakia",   nom:"Kadri",     universite:"USTO", filiere:"Informatique",  annee:4,ville:"Oran"},
  {id:"E032",prenom:"Amine",   nom:"Boukhari",  universite:"USTO", filiere:"GL",            annee:3,ville:"Oran"},
  // UMC — Constantine (10 étudiants)
  {id:"E005",prenom:"Rania",   nom:"Belkacem",  universite:"UMC",  filiere:"GL",            annee:3,ville:"Constantine"},
  {id:"E033",prenom:"Tarek",   nom:"Boudissa",  universite:"UMC",  filiere:"Informatique",  annee:2,ville:"Constantine"},
  {id:"E034",prenom:"Assia",   nom:"Guerroudj", universite:"UMC",  filiere:"Mathématiques", annee:4,ville:"Constantine"},
  {id:"E035",prenom:"Ismail",  nom:"Rahmani",   universite:"UMC",  filiere:"GL",            annee:1,ville:"Constantine"},
  {id:"E036",prenom:"Yasmine", nom:"Benbraham", universite:"UMC",  filiere:"Informatique",  annee:3,ville:"Constantine"},
  {id:"E037",prenom:"Khalil",  nom:"Bouchareb", universite:"UMC",  filiere:"Electronique",  annee:2,ville:"Constantine"},
  {id:"E038",prenom:"Nour",    nom:"Benaissa",  universite:"UMC",  filiere:"Informatique",  annee:4,ville:"Constantine"},
  {id:"E039",prenom:"Ramzi",   nom:"Khelifa",   universite:"UMC",  filiere:"GL",            annee:3,ville:"Constantine"},
  {id:"E040",prenom:"Dina",    nom:"Amirouche", universite:"UMC",  filiere:"Mathématiques", annee:2,ville:"Constantine"},
  {id:"E041",prenom:"Oussama", nom:"Benmoussa", universite:"UMC",  filiere:"Informatique",  annee:1,ville:"Constantine"},
  // UBMA — Annaba (10 étudiants)
  {id:"E007",prenom:"Sara",    nom:"Amrani",    universite:"UBMA", filiere:"Telecoms",      annee:3,ville:"Annaba"},
  {id:"E042",prenom:"Achraf",  nom:"Benouza",   universite:"UBMA", filiere:"Informatique",  annee:4,ville:"Annaba"},
  {id:"E043",prenom:"Hadjer",  nom:"Benseddik", universite:"UBMA", filiere:"Electronique",  annee:2,ville:"Annaba"},
  {id:"E044",prenom:"Fares",   nom:"Laouari",   universite:"UBMA", filiere:"GL",            annee:3,ville:"Annaba"},
  {id:"E045",prenom:"Ines",    nom:"Djebara",   universite:"UBMA", filiere:"Informatique",  annee:1,ville:"Annaba"},
  {id:"E046",prenom:"Zakaria", nom:"Boudrahem", universite:"UBMA", filiere:"Mathématiques", annee:4,ville:"Annaba"},
  {id:"E047",prenom:"Amira",   nom:"Ferroukhi", universite:"UBMA", filiere:"GL",            annee:2,ville:"Annaba"},
  {id:"E048",prenom:"Rayane",  nom:"Messikh",   universite:"UBMA", filiere:"Telecoms",      annee:3,ville:"Annaba"},
  {id:"E049",prenom:"Siham",   nom:"Bouanani",  universite:"UBMA", filiere:"Informatique",  annee:4,ville:"Annaba"},
  {id:"E050",prenom:"Yassine", nom:"Beloufa",   universite:"UBMA", filiere:"Electronique",  annee:2,ville:"Annaba"}
] AS data
MERGE (e:Etudiant {id: data.id})
SET e += data;

// 1.4 : Relations CONNAIT (réseau social connexe) 
// Liens intra-USTHB
MATCH (a:Etudiant {id:"E001"}),(b:Etudiant {id:"E002"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E001"}),(b:Etudiant {id:"E006"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E001"}),(b:Etudiant {id:"E013"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E002"}),(b:Etudiant {id:"E009"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E002"}),(b:Etudiant {id:"E016"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E006"}),(b:Etudiant {id:"E014"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E011"}),(b:Etudiant {id:"E015"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"projet"}]->(b);
MATCH (a:Etudiant {id:"E012"}),(b:Etudiant {id:"E016"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E013"}),(b:Etudiant {id:"E015"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E014"}),(b:Etudiant {id:"E016"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"projet"}]->(b);
// Liens intra-UMBB
MATCH (a:Etudiant {id:"E003"}),(b:Etudiant {id:"E008"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E003"}),(b:Etudiant {id:"E017"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E017"}),(b:Etudiant {id:"E021"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E018"}),(b:Etudiant {id:"E022"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"projet"}]->(b);
MATCH (a:Etudiant {id:"E019"}),(b:Etudiant {id:"E024"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E020"}),(b:Etudiant {id:"E023"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E021"}),(b:Etudiant {id:"E024"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E008"}),(b:Etudiant {id:"E022"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
// Liens intra-USTO
MATCH (a:Etudiant {id:"E004"}),(b:Etudiant {id:"E010"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E004"}),(b:Etudiant {id:"E025"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E025"}),(b:Etudiant {id:"E029"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E026"}),(b:Etudiant {id:"E030"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"projet"}]->(b);
MATCH (a:Etudiant {id:"E027"}),(b:Etudiant {id:"E032"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E028"}),(b:Etudiant {id:"E031"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E029"}),(b:Etudiant {id:"E031"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E010"}),(b:Etudiant {id:"E032"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
// Liens intra-UMC
MATCH (a:Etudiant {id:"E005"}),(b:Etudiant {id:"E033"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E005"}),(b:Etudiant {id:"E036"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E033"}),(b:Etudiant {id:"E038"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E034"}),(b:Etudiant {id:"E040"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E035"}),(b:Etudiant {id:"E041"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E036"}),(b:Etudiant {id:"E038"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"projet"}]->(b);
MATCH (a:Etudiant {id:"E037"}),(b:Etudiant {id:"E039"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E039"}),(b:Etudiant {id:"E041"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
// Liens intra-UBMA
MATCH (a:Etudiant {id:"E007"}),(b:Etudiant {id:"E042"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E007"}),(b:Etudiant {id:"E048"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E042"}),(b:Etudiant {id:"E045"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E043"}),(b:Etudiant {id:"E050"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E044"}),(b:Etudiant {id:"E047"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"projet"}]->(b);
MATCH (a:Etudiant {id:"E045"}),(b:Etudiant {id:"E049"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"club"}]->(b);
MATCH (a:Etudiant {id:"E046"}),(b:Etudiant {id:"E049"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"cours"}]->(b);
MATCH (a:Etudiant {id:"E047"}),(b:Etudiant {id:"E050"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"cours"}]->(b);
// Liens INTER-universités (assure connexité globale)
MATCH (a:Etudiant {id:"E001"}),(b:Etudiant {id:"E003"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"conférence"}]->(b);
MATCH (a:Etudiant {id:"E003"}),(b:Etudiant {id:"E004"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"hackathon"}]->(b);
MATCH (a:Etudiant {id:"E004"}),(b:Etudiant {id:"E005"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"compétition"}]->(b);
MATCH (a:Etudiant {id:"E005"}),(b:Etudiant {id:"E007"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"conférence"}]->(b);
MATCH (a:Etudiant {id:"E002"}),(b:Etudiant {id:"E017"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"réseau alumni"}]->(b);
MATCH (a:Etudiant {id:"E016"}),(b:Etudiant {id:"E004"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"hackathon"}]->(b);
MATCH (a:Etudiant {id:"E011"}),(b:Etudiant {id:"E033"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"compétition"}]->(b);
MATCH (a:Etudiant {id:"E021"}),(b:Etudiant {id:"E036"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"conférence"}]->(b);
MATCH (a:Etudiant {id:"E029"}),(b:Etudiant {id:"E042"}) MERGE (a)-[:CONNAIT {depuis:2022,contexte:"hackathon"}]->(b);
MATCH (a:Etudiant {id:"E038"}),(b:Etudiant {id:"E049"}) MERGE (a)-[:CONNAIT {depuis:2023,contexte:"stage"}]->(b);

// ─── 1.5 : Relations SUIT (étudiant → cours avec notes) ──────
MATCH (e:Etudiant {id:"E001"}),(c:Cours {code:"INFO401"}) MERGE (e)-[:SUIT {semestre:"S5",note:16.5}]->(c);
MATCH (e:Etudiant {id:"E001"}),(c:Cours {code:"INFO402"}) MERGE (e)-[:SUIT {semestre:"S5",note:15.0}]->(c);
MATCH (e:Etudiant {id:"E002"}),(c:Cours {code:"INFO401"}) MERGE (e)-[:SUIT {semestre:"S5",note:17.0}]->(c);
MATCH (e:Etudiant {id:"E002"}),(c:Cours {code:"INFO403"}) MERGE (e)-[:SUIT {semestre:"S5",note:14.5}]->(c);
MATCH (e:Etudiant {id:"E003"}),(c:Cours {code:"INFO402"}) MERGE (e)-[:SUIT {semestre:"S3",note:13.0}]->(c);
MATCH (e:Etudiant {id:"E003"}),(c:Cours {code:"INFO403"}) MERGE (e)-[:SUIT {semestre:"S3",note:15.5}]->(c);
MATCH (e:Etudiant {id:"E004"}),(c:Cours {code:"INFO401"}) MERGE (e)-[:SUIT {semestre:"S7",note:18.0}]->(c);
MATCH (e:Etudiant {id:"E004"}),(c:Cours {code:"INFO404"}) MERGE (e)-[:SUIT {semestre:"S7",note:16.0}]->(c);
MATCH (e:Etudiant {id:"E005"}),(c:Cours {code:"INFO403"}) MERGE (e)-[:SUIT {semestre:"S5",note:15.0}]->(c);
MATCH (e:Etudiant {id:"E006"}),(c:Cours {code:"ELE301"}) MERGE (e)-[:SUIT {semestre:"S3",note:12.5}]->(c);
MATCH (e:Etudiant {id:"E007"}),(c:Cours {code:"TEL301"}) MERGE (e)-[:SUIT {semestre:"S5",note:14.0}]->(c);
MATCH (e:Etudiant {id:"E008"}),(c:Cours {code:"MATH301"}) MERGE (e)-[:SUIT {semestre:"S7",note:19.0}]->(c);
MATCH (e:Etudiant {id:"E009"}),(c:Cours {code:"INFO401"}) MERGE (e)-[:SUIT {semestre:"S1",note:12.0}]->(c);
MATCH (e:Etudiant {id:"E010"}),(c:Cours {code:"INFO403"}) MERGE (e)-[:SUIT {semestre:"S5",note:16.0}]->(c);
MATCH (e:Etudiant {id:"E011"}),(c:Cours {code:"INFO404"}) MERGE (e)-[:SUIT {semestre:"S7",note:17.5}]->(c);
MATCH (e:Etudiant {id:"E011"}),(c:Cours {code:"INFO405"}) MERGE (e)-[:SUIT {semestre:"S7",note:16.0}]->(c);
MATCH (e:Etudiant {id:"E012"}),(c:Cours {code:"MATH301"}) MERGE (e)-[:SUIT {semestre:"S5",note:18.5}]->(c);
MATCH (e:Etudiant {id:"E016"}),(c:Cours {code:"INFO402"}) MERGE (e)-[:SUIT {semestre:"S7",note:15.5}]->(c);
MATCH (e:Etudiant {id:"E021"}),(c:Cours {code:"INFO401"}) MERGE (e)-[:SUIT {semestre:"S7",note:14.0}]->(c);
MATCH (e:Etudiant {id:"E025"}),(c:Cours {code:"INFO402"}) MERGE (e)-[:SUIT {semestre:"S3",note:13.5}]->(c);

// 1.6 : Relations MAITRISE (étudiant → compétence) 
MATCH (e:Etudiant {id:"E001"}),(c:Competence {nom:"Python"})   MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E001"}),(c:Competence {nom:"SQL"})      MERGE (e)-[:MAITRISE {niveau:"intermédiaire"}]->(c);
MATCH (e:Etudiant {id:"E002"}),(c:Competence {nom:"Java"})     MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E002"}),(c:Competence {nom:"SQL"})      MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E003"}),(c:Competence {nom:"React"})    MERGE (e)-[:MAITRISE {niveau:"intermédiaire"}]->(c);
MATCH (e:Etudiant {id:"E004"}),(c:Competence {nom:"Python"})   MERGE (e)-[:MAITRISE {niveau:"expert"}]->(c);
MATCH (e:Etudiant {id:"E004"}),(c:Competence {nom:"Machine Learning"}) MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E005"}),(c:Competence {nom:"Node.js"})  MERGE (e)-[:MAITRISE {niveau:"intermédiaire"}]->(c);
MATCH (e:Etudiant {id:"E006"}),(c:Competence {nom:"Linux"})    MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E007"}),(c:Competence {nom:"Réseaux"})  MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E008"}),(c:Competence {nom:"Statistiques"}) MERGE (e)-[:MAITRISE {niveau:"expert"}]->(c);
MATCH (e:Etudiant {id:"E011"}),(c:Competence {nom:"Docker"})   MERGE (e)-[:MAITRISE {niveau:"avancé"}]->(c);
MATCH (e:Etudiant {id:"E012"}),(c:Competence {nom:"Mathématiques"}) MERGE (e)-[:MAITRISE {niveau:"expert"}]->(c);
MATCH (e:Etudiant {id:"E016"}),(c:Competence {nom:"Python"})   MERGE (e)-[:MAITRISE {niveau:"intermédiaire"}]->(c);
MATCH (e:Etudiant {id:"E016"}),(c:Competence {nom:"Machine Learning"}) MERGE (e)-[:MAITRISE {niveau:"intermédiaire"}]->(c);

// 1.7 : Relations MEMBRE_DE (étudiant → club) 
MATCH (e:Etudiant {id:"E001"}),(c:Club {nom:"Club IA USTHB"})       MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);
MATCH (e:Etudiant {id:"E002"}),(c:Club {nom:"Club IA USTHB"})       MERGE (e)-[:MEMBRE_DE {role:"Vice-Président"}]->(c);
MATCH (e:Etudiant {id:"E006"}),(c:Club {nom:"Club Cyber USTHB"})    MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);
MATCH (e:Etudiant {id:"E011"}),(c:Club {nom:"Club IA USTHB"})       MERGE (e)-[:MEMBRE_DE {role:"Président"}]->(c);
MATCH (e:Etudiant {id:"E003"}),(c:Club {nom:"Club Dev UMBB"})       MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);
MATCH (e:Etudiant {id:"E017"}),(c:Club {nom:"Club Dev UMBB"})       MERGE (e)-[:MEMBRE_DE {role:"Trésorier"}]->(c);
MATCH (e:Etudiant {id:"E004"}),(c:Club {nom:"Club Robotique USTO"}) MERGE (e)-[:MEMBRE_DE {role:"Président"}]->(c);
MATCH (e:Etudiant {id:"E010"}),(c:Club {nom:"Club Robotique USTO"}) MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);
MATCH (e:Etudiant {id:"E005"}),(c:Club {nom:"Club Data UMC"})       MERGE (e)-[:MEMBRE_DE {role:"Secrétaire"}]->(c);
MATCH (e:Etudiant {id:"E036"}),(c:Club {nom:"Club Data UMC"})       MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);
MATCH (e:Etudiant {id:"E007"}),(c:Club {nom:"Club IoT UBMA"})       MERGE (e)-[:MEMBRE_DE {role:"Présidente"}]->(c);
MATCH (e:Etudiant {id:"E042"}),(c:Club {nom:"Club IoT UBMA"})       MERGE (e)-[:MEMBRE_DE {role:"Membre"}]->(c);

// 1.8 : Relations A_STAGE_CHEZ 
MATCH (e:Etudiant {id:"E011"}),(ent:Entreprise {nom:"Sonatrach"})  MERGE (e)-[:A_STAGE_CHEZ {annee:2023,duree_mois:2}]->(ent);
MATCH (e:Etudiant {id:"E016"}),(ent:Entreprise {nom:"Mobilis"})    MERGE (e)-[:A_STAGE_CHEZ {annee:2024,duree_mois:3}]->(ent);
MATCH (e:Etudiant {id:"E004"}),(ent:Entreprise {nom:"Djezzy"})     MERGE (e)-[:A_STAGE_CHEZ {annee:2023,duree_mois:2}]->(ent);
MATCH (e:Etudiant {id:"E008"}),(ent:Entreprise {nom:"NCA Rouiba"}) MERGE (e)-[:A_STAGE_CHEZ {annee:2024,duree_mois:3}]->(ent);
MATCH (e:Etudiant {id:"E021"}),(ent:Entreprise {nom:"Condor"})     MERGE (e)-[:A_STAGE_CHEZ {annee:2023,duree_mois:2}]->(ent);

// 1.9 : Import CSV (Ex 1.4)
// Charger le fichier students.csv dans le répertoire import Neo4j
LOAD CSV WITH HEADERS FROM 'file:///students.csv' AS row
MERGE (e:Etudiant { id: row.id })
SET e.prenom      = row.prenom,
    e.nom         = row.nom,
    e.universite  = row.universite,
    e.filiere     = row.filiere,
    e.annee       = toInteger(row.annee),
    e.ville       = row.ville;

//  Vérifications finales 
MATCH (n) RETURN labels(n)[0] AS type, count(n) AS total ORDER BY total DESC;
MATCH ()-[r]->() RETURN type(r) AS relation, count(r) AS total ORDER BY total DESC;
