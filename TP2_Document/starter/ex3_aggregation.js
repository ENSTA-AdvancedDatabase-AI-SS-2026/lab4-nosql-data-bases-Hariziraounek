/**
 * TP2 - Exercice 3 : Pipelines d'Agrégation
 * Use Case : Statistiques médicales HealthCare DZ
 *
 * Prérequis : avoir exécuté ex1_modelisation.js
 */

use("medical_db");

// ─── 3.1 : Distribution des diagnostics par wilaya ────────────────────────────
print("=== 3.1 : Top diagnostics par wilaya ===\n");

const diagParWilaya = db.patients.aggregate([
  // Étape 1 : Dérouler le tableau consultations (1 doc par consultation)
  { $unwind: "$consultations" },

  // Étape 2 : Grouper par wilaya + diagnostic et compter
  {
    $group: {
      _id: {
        wilaya:     "$adresse.wilaya",
        diagnostic: "$consultations.diagnostic"
      },
      count: { $sum: 1 }
    }
  },

  // Étape 3 : Trier par nombre décroissant
  { $sort: { count: -1 } },

  // Étape 4 : Garder les 20 premiers
  { $limit: 20 },

  // Étape 5 : Reformater pour la lisibilité
  {
    $project: {
      _id: 0,
      wilaya:     "$_id.wilaya",
      diagnostic: "$_id.diagnostic",
      count:      1
    }
  }
]).toArray();

printjson(diagParWilaya);


// ─── 3.2 : Médicament le plus prescrit par spécialité ─────────────────────────
print("\n=== 3.2 : Top médicament par spécialité ===\n");

const medsParSpecialite = db.patients.aggregate([
  // Dérouler les consultations
  { $unwind: "$consultations" },

  // Dérouler les médicaments dans chaque consultation
  { $unwind: "$consultations.medicaments" },

  // Grouper par spécialité + médicament
  {
    $group: {
      _id: {
        specialite:  "$consultations.medecin.specialite",
        medicament:  "$consultations.medicaments.nom"
      },
      prescriptions: { $sum: 1 }
    }
  },

  // Trier pour avoir le plus prescrit en premier dans chaque spécialité
  { $sort: { "_id.specialite": 1, prescriptions: -1 } },

  // Regrouper par spécialité pour garder uniquement le top 1
  {
    $group: {
      _id: "$_id.specialite",
      topMedicament: { $first: "$_id.medicament" },
      prescriptions: { $first: "$prescriptions" }
    }
  },

  // Tri final sur la spécialité
  { $sort: { _id: 1 } },

  // Mise en forme
  {
    $project: {
      _id: 0,
      specialite:    "$_id",
      topMedicament: 1,
      prescriptions: 1
    }
  }
]).toArray();

printjson(medsParSpecialite);


// ─── 3.3 : Évolution mensuelle des consultations (12 derniers mois) ───────────
print("\n=== 3.3 : Consultations par mois (12 derniers mois) ===\n");

const dateIl_y_a_un_an = new Date();
dateIl_y_a_un_an.setFullYear(dateIl_y_a_un_an.getFullYear() - 1);

const evolutionMensuelle = db.patients.aggregate([
  // Dérouler les consultations
  { $unwind: "$consultations" },

  // Garder uniquement les 12 derniers mois
  {
    $match: {
      "consultations.date": { $gte: dateIl_y_a_un_an }
    }
  },

  // Grouper par année + mois
  {
    $group: {
      _id: {
        annee: { $year:  "$consultations.date" },
        mois:  { $month: "$consultations.date" }
      },
      total: { $sum: 1 }
    }
  },

  // Trier par ordre chronologique
  { $sort: { "_id.annee": 1, "_id.mois": 1 } },

  // Formater en "AAAA-MM"
  {
    $project: {
      _id: 0,
      periode: {
        $concat: [
          { $toString: "$_id.annee" },
          "-",
          {
            $cond: {
              if:   { $lt: ["$_id.mois", 10] },
              then: { $concat: ["0", { $toString: "$_id.mois" }] },
              else: { $toString: "$_id.mois" }
            }
          }
        ]
      },
      total: 1
    }
  }
]).toArray();

printjson(evolutionMensuelle);


// ─── 3.4 : Patients à risque multiple ────────────────────────────────────────
print("\n=== 3.4 : Profil patients à risque élevé (Diabète + HTA + âge > 60) ===\n");

const aujourd_hui = new Date();
const age60 = new Date(aujourd_hui);
age60.setFullYear(age60.getFullYear() - 60);

const patientsRisque = db.patients.aggregate([
  // Filtrer : Diabète type 2 ET HTA (les deux présents dans antécédents)
  {
    $match: {
      antecedents: { $all: ["Diabète type 2", "HTA"] },
      dateNaissance: { $lte: age60 }          // âge > 60 ans
    }
  },

  // Calculer l'âge et le nombre de consultations
  {
    $addFields: {
      age: {
        $floor: {
          $divide: [
            { $subtract: [aujourd_hui, "$dateNaissance"] },
            1000 * 60 * 60 * 24 * 365.25
          ]
        }
      },
      nbConsultations: { $size: "$consultations" }
    }
  },

  // Projeter les informations utiles par patient
  {
    $project: {
      _id: 0,
      nom: 1,
      prenom: 1,
      age: 1,
      "adresse.wilaya": 1,
      antecedents: 1,
      nbConsultations: 1
    }
  },

  { $sort: { age: -1 } }
]).toArray();

printjson(patientsRisque);

// Statistiques globales sur ce groupe à risque
const statsRisque = db.patients.aggregate([
  {
    $match: {
      antecedents: { $all: ["Diabète type 2", "HTA"] },
      dateNaissance: { $lte: age60 }
    }
  },
  {
    $group: {
      _id: null,
      nombrePatients:         { $sum: 1 },
      ageMoyen:               { $avg: {
        $floor: {
          $divide: [
            { $subtract: [aujourd_hui, "$dateNaissance"] },
            1000 * 60 * 60 * 24 * 365.25
          ]
        }
      }},
      moyenneConsultations:   { $avg: { $size: "$consultations" } },
      maxConsultations:       { $max: { $size: "$consultations" } }
    }
  },
  {
    $project: {
      _id: 0,
      nombrePatients:       1,
      ageMoyen:             { $round: ["$ageMoyen", 1] },
      moyenneConsultations: { $round: ["$moyenneConsultations", 1] },
      maxConsultations:     1
    }
  }
]).toArray();

print("\n→ Statistiques globales du groupe à risque :");
printjson(statsRisque);


// ─── 3.5 : Top 5 médecins & taux de ré-consultation ──────────────────────────
print("\n=== 3.5 : Top 5 médecins & taux de ré-consultation ===\n");

const rapportMedecins = db.patients.aggregate([
  // Dérouler les consultations
  { $unwind: "$consultations" },

  // Grouper par médecin ET par patient pour identifier les patients uniques
  {
    $group: {
      _id: {
        medecin:   "$consultations.medecin.nom",
        specialite:"$consultations.medecin.specialite",
        patient_id:"$_id"
      },
      consultationsParPatient: { $sum: 1 }
    }
  },

  // Regrouper par médecin uniquement
  {
    $group: {
      _id: {
        medecin:    "$_id.medecin",
        specialite: "$_id.specialite"
      },
      patientsUniques:      { $sum: 1 },
      totalConsultations:   { $sum: "$consultationsParPatient" }
    }
  },

  // Calculer le taux de ré-consultation
  // Formule : (consultations_totales - patients_uniques) / patients_uniques × 100
  {
    $addFields: {
      tauxReConsultation: {
        $multiply: [
          {
            $divide: [
              { $subtract: ["$totalConsultations", "$patientsUniques"] },
              "$patientsUniques"
            ]
          },
          100
        ]
      }
    }
  },

  // Trier par consultations totales décroissantes
  { $sort: { totalConsultations: -1 } },

  // Garder le Top 5
  { $limit: 5 },

  // Mise en forme finale
  {
    $project: {
      _id: 0,
      medecin:              "$_id.medecin",
      specialite:           "$_id.specialite",
      patientsUniques:      1,
      totalConsultations:   1,
      tauxReConsultation:   { $round: ["$tauxReConsultation", 1] }
    }
  }
]).toArray();

printjson(rapportMedecins);
