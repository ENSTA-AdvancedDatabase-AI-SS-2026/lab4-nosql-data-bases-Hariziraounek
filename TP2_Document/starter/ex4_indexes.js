/**
 * TP2 - Exercice 4 : Index et Optimisation
 *
 * Prérequis : avoir exécuté ex1_modelisation.js
 */

use("medical_db");

//  4.1 : Créer les index appropriés 

/**
 * Index 1 : Recherche fréquente par wilaya + antécédents
 *
 * Justification :
 *  - La requête filtre d'abord sur "adresse.wilaya" (forte cardinalité par wilaya)
 *    puis sur "antecedents" (tableau). L'ordre wilaya → antecedents est optimal
 *    car la wilaya réduit significativement l'ensemble de documents avant
 *    l'inspection du tableau des antécédents.
 */
db.patients.createIndex(
  { "adresse.wilaya": 1, antecedents: 1 },
  { name: "idx_wilaya_antecedents" }
);

/**
 * Index 2 : Recherche par date de consultation (champ dans un sous-document embedded)
 *
 * Justification :
 *  - Les agrégations de l'ex3 filtrent souvent sur "consultations.date"
 *    (ex : évolution mensuelle sur 12 mois). L'index multiclé sur un champ
 *    de tableau accélère le $match et le $unwind+$match.
 */
db.patients.createIndex(
  { "consultations.date": 1 },
  { name: "idx_consultations_date" }
);

/**
 * Index 3 : Texte sur diagnostics et notes (recherche full-text)
 *
 * Justification :
 *  - La requête 2.5 effectue une recherche $text. MongoDB exige un index text
 *    sur les champs concernés. On couvre diagnostic + notes pour élargir
 *    la recherche sans surcoût majeur.
 *  - Une seule collection ne peut avoir qu'un seul index text.
 */
db.patients.createIndex(
  {
    "consultations.diagnostic": "text",
    "consultations.notes":      "text"
  },
  { name: "idx_text_diagnostic_notes" }
);

/**
 * Index 4 : Analyses par patient_id (pour les $lookup)
 *
 * Justification :
 *  - L'exercice 5 fait des jointures (via $lookup) entre patients et analyses
 *    sur le champ patient_id. Sans cet index, chaque lookup scanne toute
 *    la collection analyses. L'index réduit la complexité de O(n) à O(log n).
 */
db.analyses.createIndex(
  { patient_id: 1 },
  { name: "idx_analyses_patient_id" }
);

/**
 * Index 5 (bonus) : Index composé pour la requête complexe ex3.4
 *  Patients : antecedents + dateNaissance (pour le filtre risque élevé)
 *
 * Justification :
 *  - $match { antecedents: {$all: [...]}, dateNaissance: {$lte: ...} }
 *    Mettre antecedents en premier (tableau, filtre sélectif), puis dateNaissance.
 */
db.patients.createIndex(
  { antecedents: 1, dateNaissance: 1 },
  { name: "idx_antecedents_datenaissance" }
);

print("✅ Tous les index créés");
print("");
db.patients.getIndexes().forEach(idx => print("  •", idx.name, JSON.stringify(idx.key)));


//  4.2 : Comparer avant / après index avec explain()

const requeteTest = {
  "adresse.wilaya": "Alger",
  antecedents: "Diabète type 2"
};

//  AVANT (forcer un COLLSCAN en ignorant les index via hint $natural) 
print("\n=== AVANT index (hint $natural = Collection Scan) ===");

const avantIndex = db.patients.find(requeteTest)
  .hint({ $natural: 1 })
  .explain("executionStats");

const statsAvant = avantIndex.executionStats;
print("  nReturned            :", statsAvant.nReturned);
print("  totalDocsExamined    :", statsAvant.totalDocsExamined);
print("  executionTimeMillis  :", statsAvant.executionTimeMillis, "ms");
print("  stage                :", avantIndex.queryPlanner.winningPlan.stage);


//  APRÈS (laisser MongoDB choisir l'index optimal) 
print("\n=== APRÈS index (MongoDB choisit idx_wilaya_antecedents) ===");

const apresIndex = db.patients.find(requeteTest)
  .hint("idx_wilaya_antecedents")
  .explain("executionStats");

const statsApres = apresIndex.executionStats;
print("  nReturned            :", statsApres.nReturned);
print("  totalDocsExamined    :", statsApres.totalDocsExamined);
print("  executionTimeMillis  :", statsApres.executionTimeMillis, "ms");
print("  stage                :", apresIndex.queryPlanner.winningPlan.inputStage
                                    ? apresIndex.queryPlanner.winningPlan.inputStage.stage
                                    : apresIndex.queryPlanner.winningPlan.stage);

//  Tableau comparatif 
print("\n╔══════════════════════════╦═════════════╦════════════╗");
print("║ Métrique                 ║ Sans index  ║ Avec index ║");
print("╠══════════════════════════╬═════════════╬════════════╣");
print("║ nReturned                ║ " + String(statsAvant.nReturned).padEnd(11)
    + " ║ " + String(statsApres.nReturned).padEnd(10) + " ║");
print("║ totalDocsExamined        ║ " + String(statsAvant.totalDocsExamined).padEnd(11)
    + " ║ " + String(statsApres.totalDocsExamined).padEnd(10) + " ║");
print("║ executionTimeMillis (ms) ║ " + String(statsAvant.executionTimeMillis).padEnd(11)
    + " ║ " + String(statsApres.executionTimeMillis).padEnd(10) + " ║");
print("╚══════════════════════════╩═════════════╩════════════╝");
print("→ Avec 20 docs le gain est minime, mais avec 100 000 docs il est majeur !");


//  4.3 : Explication du plan pour la requête ex3.4 (la plus complexe) 
print("\n=== 4.3 : Plan d'exécution requête complexe (patients à risque élevé) ===");

const age60 = new Date();
age60.setFullYear(age60.getFullYear() - 60);

const planRisque = db.patients.find(
  {
    antecedents: { $all: ["Diabète type 2", "HTA"] },
    dateNaissance: { $lte: age60 }
  }
).hint("idx_antecedents_datenaissance").explain("executionStats");

print("  Winning plan stage   :", planRisque.queryPlanner.winningPlan.stage);
print("  totalDocsExamined    :", planRisque.executionStats.totalDocsExamined);
print("  nReturned            :", planRisque.executionStats.nReturned);


//  4.4 : Index TTL pour archiver les analyses de plus de 5 ans 
// 5 ans = 5 × 365,25 jours × 24h × 3600s ≈ 157 766 400 secondes
db.analyses.createIndex(
  { date: 1 },
  {
    expireAfterSeconds: 157_766_400,   // 5 ans
    name: "idx_ttl_analyses_5ans"
  }
);

print("\n✅ Index TTL créé sur analyses.date (expiration après 5 ans)");
print("   → MongoDB supprimera automatiquement les analyses dont le champ 'date'");
print("     est antérieur à (maintenant - 5 ans). Le nettoyage tourne toutes les 60 s.");
