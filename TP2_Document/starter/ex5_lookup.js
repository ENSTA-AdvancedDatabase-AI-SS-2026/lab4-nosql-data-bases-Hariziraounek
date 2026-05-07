/**
 * TP2 - Exercice 5 : $lookup et Données Référencées
 * Use Case : HealthCare DZ – Jointures patients ↔ analyses
 *
 * Prérequis : avoir exécuté ex1_modelisation.js et ex4_indexes.js
 */

use("medical_db");

//  5.1 : Dossier complet d'un patient (consultations + analyses) 
print("=== 5.1 : Dossier complet – Bensalem Ahmed ===\n");

const dossierComplet = db.patients.aggregate([
  // Cibler un patient précis (peut être remplacé par un _id dynamique)
  {
    $match: { cin: "198001012300" }
  },

  // Joindre la collection analyses sur _id ↔ analyses.patient_id
  {
    $lookup: {
      from:         "analyses",
      localField:   "_id",
      foreignField: "patient_id",
      as:           "analysesLabo"
    }
  },

  // Projection finale : dossier médical complet et lisible
  {
    $project: {
      _id: 0,
      cin: 1,
      nom: 1,
      prenom: 1,
      dateNaissance: 1,
      sexe: 1,
      "adresse.wilaya": 1,
      groupeSanguin: 1,
      antecedents: 1,
      allergies: 1,
      nombreConsultations: { $size: "$consultations" },
      consultations: 1,
      analysesLabo: {
        $map: {
          input: "$analysesLabo",
          as:    "a",
          in: {
            date:        "$$a.date",
            type:        "$$a.type",
            resultats:   "$$a.resultats",
            laboratoire: "$$a.laboratoire",
            valide:      "$$a.valide"
          }
        }
      }
    }
  }
]).toArray();

printjson(dossierComplet);


//  5.2 : Patients avec glycémie à jeun > 1,26 g/L ─────────────────────────
print("\n=== 5.2 : Patients hyperglycémiques (glycémie > 1,26 g/L) ===\n");

// Approche : partir de la collection analyses, filtrer, puis rejoindre patients
const hyperglycemiques = db.analyses.aggregate([
  // Garder uniquement les analyses de type Glycémie avec valeur élevée
  {
    $match: {
      type: "Glycémie",
      "resultats.glycemie_ajun": { $gt: 1.26 }
    }
  },

  // Joindre avec la collection patients
  {
    $lookup: {
      from:         "patients",
      localField:   "patient_id",
      foreignField: "_id",
      as:           "infosPatient"
    }
  },

  // Dérouler le tableau (1 seul patient par analyse normalement)
  { $unwind: "$infosPatient" },

  // Mise en forme
  {
    $project: {
      _id: 0,
      "infosPatient.nom":             1,
      "infosPatient.prenom":          1,
      "infosPatient.adresse.wilaya":  1,
      "infosPatient.antecedents":     1,
      dateAnalyse:                    "$date",
      glycemie_ajun:                  "$resultats.glycemie_ajun",
      hba1c:                          "$resultats.hba1c",
      laboratoire:                    1
    }
  },

  { $sort: { glycemie_ajun: -1 } }
]).toArray();

printjson(hyperglycemiques);
print("→ " + hyperglycemiques.length + " patient(s) concerné(s)");


//  5.3 : Taux d'analyses anormales par wilaya 
print("\n=== 5.3 : Statistiques croisées – Analyses anormales par wilaya ===\n");

// Définition "anormale" :
//   Glycémie  : glycemie_ajun > 1.10 g/L
//   NFS       : hb < 12 (femme) ou < 13 (homme) → on simplifie à hb < 12
//   Lipidogramme : ldl > 1.6 g/L
//   Créatinine   : dfg < 60

const analysesAnormales = db.analyses.aggregate([
  // Joindre avec patients pour récupérer la wilaya
  {
    $lookup: {
      from:         "patients",
      localField:   "patient_id",
      foreignField: "_id",
      as:           "patient"
    }
  },
  { $unwind: "$patient" },

  // Identifier si l'analyse est anormale selon le type
  {
    $addFields: {
      estAnormale: {
        $switch: {
          branches: [
            {
              case: { $and: [
                { $eq: ["$type", "Glycémie"] },
                { $gt: ["$resultats.glycemie_ajun", 1.10] }
              ]},
              then: true
            },
            {
              case: { $and: [
                { $eq: ["$type", "NFS"] },
                { $lt: ["$resultats.hb", 12] }
              ]},
              then: true
            },
            {
              case: { $and: [
                { $eq: ["$type", "Lipidogramme"] },
                { $gt: ["$resultats.ldl", 1.6] }
              ]},
              then: true
            },
            {
              case: { $and: [
                { $eq: ["$type", "Créatinine"] },
                { $lt: ["$resultats.dfg", 60] }
              ]},
              then: true
            }
          ],
          default: false
        }
      }
    }
  },

  // Grouper par wilaya
  {
    $group: {
      _id: "$patient.adresse.wilaya",
      totalAnalyses:    { $sum: 1 },
      analysesAnormales:{ $sum: { $cond: ["$estAnormale", 1, 0] } }
    }
  },

  // Calculer le taux en pourcentage
  {
    $addFields: {
      tauxAnormalite: {
        $round: [
          {
            $multiply: [
              { $divide: ["$analysesAnormales", "$totalAnalyses"] },
              100
            ]
          },
          1
        ]
      }
    }
  },

  // Trier par taux décroissant
  { $sort: { tauxAnormalite: -1 } },

  // Mise en forme
  {
    $project: {
      _id: 0,
      wilaya:            "$_id",
      totalAnalyses:     1,
      analysesAnormales: 1,
      tauxAnormalite:    1
    }
  }
]).toArray();

printjson(analysesAnormales);

print("\n✅ Exercice 5 terminé");
