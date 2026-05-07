/**
 * TP2 - Exercice 2 : Requêtes de Base
 * Use Case : HealthCare DZ – Dossiers Médicaux
 *
 * Prérequis : avoir exécuté ex1_modelisation.js
 */

use("medical_db");

//  2.1 : Patients diabétiques de plus de 50 ans à Alger 
print("=== 2.1 : Diabétiques > 50 ans à Alger ===");

const ageLimite50 = new Date();
ageLimite50.setFullYear(ageLimite50.getFullYear() - 50);

const diabetiquesAlger = db.patients.find(
  {
    "adresse.wilaya": "Alger",
    antecedents: "Diabète type 2",
    dateNaissance: { $lte: ageLimite50 }
  },
  {
    _id: 0,
    nom: 1,
    prenom: 1,
    dateNaissance: 1,
    "adresse.commune": 1,
    antecedents: 1
  }
).toArray();

printjson(diabetiquesAlger);
print("→ " + diabetiquesAlger.length + " résultat(s)\n");


//  2.2 : Patients allergiques à la Pénicilline avec ≥ 3 consultations 
print("=== 2.2 : Allergiques Pénicilline avec ≥ 3 consultations ===");

const allergiques3Consult = db.patients.find(
  {
    allergies: "Pénicilline",
    $expr: { $gte: [{ $size: "$consultations" }, 3] }
  },
  {
    _id: 0,
    nom: 1,
    prenom: 1,
    allergies: 1,
    nbConsultations: { $size: "$consultations" }   // Projection calculée
  }
).toArray();

// Note : la projection calculée n'est pas supportée directement dans find().
// On la recalcule après pour affichage.
allergiques3Consult.forEach(p => {
  print(p.prenom + " " + p.nom + " — allergies : " + p.allergies.join(", "));
});
print("→ " + allergiques3Consult.length + " résultat(s)\n");


//  2.3 : Projection : nom, prénom et DERNIÈRE consultation seulement ───────
print("=== 2.3 : Nom, prénom et dernière consultation ===");

// Astuce : on trie les consultations par date côté appli
// (ou via agrégation si on veut rester côté Mongo)
const derniereConsult = db.patients.aggregate([
  {
    $project: {
      _id: 0,
      nom: 1,
      prenom: 1,
      derniereConsultation: { $arrayElemAt: [
        {
          $sortArray: {
            input: "$consultations",
            sortBy: { date: -1 }
          }
        },
        0
      ]}
    }
  }
]).toArray();

printjson(derniereConsult.slice(0, 5));   // Afficher 5 premiers pour la lisibilité
print("→ " + derniereConsult.length + " patients traités\n");


//  2.4 : Patients sans antécédents dont la tension systolique > 140 
//           lors de leur DERNIÈRE consultation
print("=== 2.4 : Sans antécédents & tension systolique > 140 ===");

const sansAntecedentsTension = db.patients.aggregate([
  // Garder les patients sans antécédents
  {
    $match: {
      $or: [
        { antecedents: { $exists: false } },
        { antecedents: { $size: 0 } }
      ]
    }
  },
  // Ajouter un champ "dernièreConsultation" triée
  {
    $addFields: {
      derniereConsultation: { $arrayElemAt: [
        {
          $sortArray: {
            input: "$consultations",
            sortBy: { date: -1 }
          }
        },
        0
      ]}
    }
  },
  // Filtrer sur la tension systolique
  {
    $match: {
      "derniereConsultation.tension.systolique": { $gt: 140 }
    }
  },
  {
    $project: {
      _id: 0,
      nom: 1,
      prenom: 1,
      "adresse.wilaya": 1,
      "derniereConsultation.date": 1,
      "derniereConsultation.tension": 1
    }
  }
]).toArray();

printjson(sansAntecedentsTension);
print("→ " + sansAntecedentsTension.length + " résultat(s)\n");


//  2.5 : Recherche textuelle sur les diagnostics
//           (nécessite un index text, créé ici si absent)
print("=== 2.5 : Recherche full-text sur les diagnostics ===");

// Création de l'index text (idempotent – sans effet si déjà existant)
db.patients.createIndex(
  { "consultations.diagnostic": "text", "consultations.notes": "text" },
  { name: "idx_text_diagnostic" }
);

// Exemples de recherches textuelles
const motsCles = ["hypertension", "diabète", "BPCO"];

motsCles.forEach(mot => {
  const resultats = db.patients.find(
    { $text: { $search: mot } },
    {
      _id: 0,
      nom: 1,
      prenom: 1,
      score: { $meta: "textScore" }
    }
  ).sort({ score: { $meta: "textScore" } }).toArray();

  print(`\nRecherche "${mot}" → ${resultats.length} patient(s) :`);
  resultats.forEach(r => print("  • " + r.prenom + " " + r.nom));
});
