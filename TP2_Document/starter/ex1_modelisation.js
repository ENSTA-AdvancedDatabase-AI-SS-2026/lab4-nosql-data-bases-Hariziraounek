/**
 * TP2 - Exercice 1 : Modélisation MongoDB
 * Use Case : HealthCare DZ - Dossiers Médicaux
 *
 * Choix de conception :
 *  - EMBEDDING pour les consultations  → accès fréquent, dossier lu en entier
 *  - REFERENCING pour les analyses     → volume élevé, résultats techniques volumineux
 */

use("medical_db");

// ─── 1.1 : Créer la collection avec validation $jsonSchema ───────────────────
db.createCollection("patients", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["cin", "nom", "prenom", "dateNaissance", "sexe"],
      properties: {
        cin: {
          bsonType: "string",
          pattern: "^[0-9]{12}$",
          description: "Numéro CIN à 12 chiffres, obligatoire"
        },
        nom: {
          bsonType: "string",
          minLength: 2,
          description: "Nom de famille, obligatoire"
        },
        prenom: {
          bsonType: "string",
          minLength: 2,
          description: "Prénom, obligatoire"
        },
        dateNaissance: {
          bsonType: "date",
          description: "Date de naissance au format ISODate, obligatoire"
        },
        sexe: {
          bsonType: "string",
          enum: ["M", "F"],
          description: "Sexe : M ou F, obligatoire"
        },
        adresse: {
          bsonType: "object",
          properties: {
            wilaya:  { bsonType: "string" },
            commune: { bsonType: "string" }
          }
        },
        groupeSanguin: {
          bsonType: "string",
          enum: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]
        },
        antecedents: { bsonType: "array" },
        allergies:   { bsonType: "array" },
        consultations: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["date", "medecin", "diagnostic"],
            properties: {
              date:       { bsonType: "date" },
              diagnostic: { bsonType: "string" },
              medecin: {
                bsonType: "object",
                required: ["nom", "specialite"],
                properties: {
                  nom:        { bsonType: "string" },
                  specialite: { bsonType: "string" }
                }
              },
              medicaments: { bsonType: "array" }
            }
          }
        }
      }
    }
  },
  validationAction: "warn"   // "warn" pour ne pas bloquer les tests, passer à "error" en prod
});

// ─── 1.2 : 20 patients avec données algériennes réalistes ───────────────────
const patients = [

  // ── Patient 1 ──────────────────────────────────────────────────────────────
  {
    cin: "198001012300",
    nom: "Bensalem",
    prenom: "Ahmed",
    dateNaissance: new Date("1980-01-01"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Bab Ezzouar" },
    groupeSanguin: "O+",
    antecedents: ["Diabète type 2", "HTA"],
    allergies: ["Pénicilline"],
    consultations: [
      {
        date: new Date("2023-03-10"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Hypertension artérielle",
        tension: { systolique: 148, diastolique: 95 },
        medicaments: [
          { nom: "Amlodipine", dosage: "5mg", duree: "30 jours" }
        ],
        notes: "Régime sans sel conseillé"
      },
      {
        date: new Date("2023-07-22"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Hypertension artérielle – contrôle",
        tension: { systolique: 138, diastolique: 88 },
        medicaments: [
          { nom: "Amlodipine", dosage: "5mg", duree: "60 jours" },
          { nom: "Metformine", dosage: "500mg", duree: "60 jours" }
        ],
        notes: "Légère amélioration tensionnelle"
      },
      {
        date: new Date("2024-01-15"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 déséquilibré",
        medicaments: [
          { nom: "Metformine", dosage: "1g", duree: "90 jours" },
          { nom: "Gliclazide",  dosage: "80mg", duree: "90 jours" }
        ],
        notes: "HbA1c à 8,2 % – adapter le régime alimentaire"
      }
    ]
  },

  // ── Patient 2 ──────────────────────────────────────────────────────────────
  {
    cin: "199205153400",
    nom: "Rahmani",
    prenom: "Fatima",
    dateNaissance: new Date("1992-05-15"),
    sexe: "F",
    adresse: { wilaya: "Oran", commune: "Bir El Djir" },
    groupeSanguin: "A+",
    antecedents: ["Asthme"],
    allergies: ["Aspirine"],
    consultations: [
      {
        date: new Date("2023-04-05"),
        medecin: { nom: "Dr. Tlemçani", specialite: "Pneumologie" },
        diagnostic: "Crise d'asthme modérée",
        medicaments: [
          { nom: "Salbutamol", dosage: "100µg", duree: "Selon besoin" },
          { nom: "Beclométasone", dosage: "250µg", duree: "30 jours" }
        ],
        notes: "Éviter les allergènes domestiques"
      },
      {
        date: new Date("2023-10-18"),
        medecin: { nom: "Dr. Tlemçani", specialite: "Pneumologie" },
        diagnostic: "Asthme – suivi",
        medicaments: [
          { nom: "Salmétérol/Fluticasone", dosage: "50/250µg", duree: "60 jours" }
        ],
        notes: "Spirométrie dans 3 mois"
      },
      {
        date: new Date("2024-02-20"),
        medecin: { nom: "Dr. Benali", specialite: "Médecine générale" },
        diagnostic: "Rhinite allergique associée",
        medicaments: [
          { nom: "Loratadine", dosage: "10mg", duree: "15 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 3 ──────────────────────────────────────────────────────────────
  {
    cin: "197512082100",
    nom: "Boudiaf",
    prenom: "Karim",
    dateNaissance: new Date("1975-12-08"),
    sexe: "M",
    adresse: { wilaya: "Constantine", commune: "El Khroub" },
    groupeSanguin: "B+",
    antecedents: ["Diabète type 2", "HTA", "Dyslipidémie"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-02-14"),
        medecin: { nom: "Dr. Meziani", specialite: "Cardiologie" },
        diagnostic: "Dyslipidémie mixte",
        tension: { systolique: 142, diastolique: 90 },
        medicaments: [
          { nom: "Atorvastatine", dosage: "20mg", duree: "90 jours" }
        ],
        notes: "Bilan lipidique à refaire dans 3 mois"
      },
      {
        date: new Date("2023-06-01"),
        medecin: { nom: "Dr. Meziani", specialite: "Cardiologie" },
        diagnostic: "Hypertension artérielle – suivi",
        tension: { systolique: 135, diastolique: 85 },
        medicaments: [
          { nom: "Ramipril", dosage: "5mg", duree: "90 jours" },
          { nom: "Atorvastatine", dosage: "40mg", duree: "90 jours" }
        ],
        notes: ""
      },
      {
        date: new Date("2024-03-10"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – contrôle trimestriel",
        medicaments: [
          { nom: "Metformine", dosage: "1g", duree: "90 jours" }
        ],
        notes: "HbA1c à 7,1 % – objectif atteint"
      }
    ]
  },

  // ── Patient 4 ──────────────────────────────────────────────────────────────
  {
    cin: "200109274500",
    nom: "Larbi",
    prenom: "Amina",
    dateNaissance: new Date("2001-09-27"),
    sexe: "F",
    adresse: { wilaya: "Annaba", commune: "El Bouni" },
    groupeSanguin: "AB+",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-11-03"),
        medecin: { nom: "Dr. Benhamou", specialite: "Médecine générale" },
        diagnostic: "Angine bactérienne",
        medicaments: [
          { nom: "Amoxicilline", dosage: "1g", duree: "7 jours" },
          { nom: "Paracétamol",  dosage: "1g", duree: "5 jours" }
        ],
        notes: "Contrôle à 10 jours si persistance"
      },
      {
        date: new Date("2024-01-30"),
        medecin: { nom: "Dr. Benhamou", specialite: "Médecine générale" },
        diagnostic: "Gastro-entérite aiguë",
        medicaments: [
          { nom: "Tiorfan", dosage: "100mg", duree: "5 jours" },
          { nom: "Smecta",  dosage: "3g", duree: "5 jours" }
        ],
        notes: "Réhydratation orale conseillée"
      }
    ]
  },

  // ── Patient 5 ──────────────────────────────────────────────────────────────
  {
    cin: "196803195600",
    nom: "Hadj",
    prenom: "Mokhtar",
    dateNaissance: new Date("1968-03-19"),
    sexe: "M",
    adresse: { wilaya: "Blida", commune: "Meftah" },
    groupeSanguin: "O-",
    antecedents: ["Diabète type 2", "HTA", "Insuffisance rénale chronique stade 3"],
    allergies: ["AINS"],
    consultations: [
      {
        date: new Date("2023-01-20"),
        medecin: { nom: "Dr. Saadaoui", specialite: "Néphrologie" },
        diagnostic: "IRC stade 3 – suivi",
        tension: { systolique: 150, diastolique: 98 },
        medicaments: [
          { nom: "Furosémide", dosage: "40mg", duree: "30 jours" },
          { nom: "Ramipril",   dosage: "2,5mg", duree: "30 jours" }
        ],
        notes: "Créatinine à surveiller tous les 3 mois"
      },
      {
        date: new Date("2023-05-12"),
        medecin: { nom: "Dr. Saadaoui", specialite: "Néphrologie" },
        diagnostic: "IRC – aggravation légère",
        tension: { systolique: 155, diastolique: 100 },
        medicaments: [
          { nom: "Furosémide",   dosage: "80mg", duree: "30 jours" },
          { nom: "Amlodipine",   dosage: "10mg", duree: "30 jours" }
        ],
        notes: "Régime hypoprotidique strict"
      },
      {
        date: new Date("2023-09-28"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – HbA1c 9 %",
        medicaments: [
          { nom: "Insuline Glargine", dosage: "20UI/soir", duree: "Continu" }
        ],
        notes: "Passage à l'insulinothérapie"
      },
      {
        date: new Date("2024-02-07"),
        medecin: { nom: "Dr. Saadaoui", specialite: "Néphrologie" },
        diagnostic: "IRC – stabilisation",
        tension: { systolique: 145, diastolique: 92 },
        medicaments: [
          { nom: "Furosémide", dosage: "80mg", duree: "60 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 6 ──────────────────────────────────────────────────────────────
  {
    cin: "198806137800",
    nom: "Khelifi",
    prenom: "Soumia",
    dateNaissance: new Date("1988-06-13"),
    sexe: "F",
    adresse: { wilaya: "Tizi Ouzou", commune: "Azazga" },
    groupeSanguin: "A-",
    antecedents: ["Hypothyroïdie"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-08-22"),
        medecin: { nom: "Dr. Aïssaoui", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie – TSH élevée",
        medicaments: [
          { nom: "Lévothyroxine", dosage: "75µg", duree: "90 jours" }
        ],
        notes: "TSH de contrôle dans 6 semaines"
      },
      {
        date: new Date("2024-01-10"),
        medecin: { nom: "Dr. Aïssaoui", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie – TSH normalisée",
        medicaments: [
          { nom: "Lévothyroxine", dosage: "100µg", duree: "90 jours" }
        ],
        notes: "Posologie augmentée – grossesse envisagée"
      },
      {
        date: new Date("2024-04-03"),
        medecin: { nom: "Dr. Aïssaoui", specialite: "Endocrinologie" },
        diagnostic: "Hypothyroïdie – suivi grossesse T1",
        medicaments: [
          { nom: "Lévothyroxine", dosage: "125µg", duree: "90 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 7 ──────────────────────────────────────────────────────────────
  {
    cin: "196205288900",
    nom: "Bouzid",
    prenom: "Abdelkader",
    dateNaissance: new Date("1962-05-28"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Hussein Dey" },
    groupeSanguin: "B-",
    antecedents: ["Diabète type 2", "HTA", "Cardiopathie ischémique"],
    allergies: ["Pénicilline", "Sulfamides"],
    consultations: [
      {
        date: new Date("2023-03-18"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Cardiopathie ischémique – suivi post-infarctus",
        tension: { systolique: 130, diastolique: 80 },
        medicaments: [
          { nom: "Aspirine",     dosage: "100mg", duree: "Continu" },
          { nom: "Bisoprolol",   dosage: "5mg",   duree: "Continu" },
          { nom: "Atorvastatine",dosage: "40mg",  duree: "Continu" }
        ],
        notes: "ECG stable – RDV écho-cœur dans 6 mois"
      },
      {
        date: new Date("2023-09-05"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA – ajustement thérapeutique",
        tension: { systolique: 145, diastolique: 88 },
        medicaments: [
          { nom: "Amlodipine",  dosage: "10mg", duree: "60 jours" }
        ],
        notes: ""
      },
      {
        date: new Date("2024-01-22"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – HbA1c 7,8 %",
        medicaments: [
          { nom: "Insuline Lispro",  dosage: "6UI avant repas", duree: "Continu" },
          { nom: "Insuline Glargine",dosage: "18UI/soir",        duree: "Continu" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 8 ──────────────────────────────────────────────────────────────
  {
    cin: "199507119900",
    nom: "Touati",
    prenom: "Rania",
    dateNaissance: new Date("1995-07-11"),
    sexe: "F",
    adresse: { wilaya: "Sétif", commune: "Aïn Oulmene" },
    groupeSanguin: "O+",
    antecedents: ["Anémie ferriprive"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-06-14"),
        medecin: { nom: "Dr. Ferhat", specialite: "Médecine générale" },
        diagnostic: "Anémie ferriprive – Hb 8,5 g/dL",
        medicaments: [
          { nom: "Ferrocal", dosage: "80mg/j", duree: "90 jours" },
          { nom: "Vitamine C",dosage: "500mg", duree: "90 jours" }
        ],
        notes: "NFS de contrôle dans 2 mois"
      },
      {
        date: new Date("2023-08-20"),
        medecin: { nom: "Dr. Ferhat", specialite: "Médecine générale" },
        diagnostic: "Anémie – amélioration Hb 10,2 g/dL",
        medicaments: [
          { nom: "Ferrocal", dosage: "80mg/j", duree: "60 jours" }
        ],
        notes: ""
      },
      {
        date: new Date("2024-02-15"),
        medecin: { nom: "Dr. Ferhat", specialite: "Médecine générale" },
        diagnostic: "Contrôle annuel – Hb 12,8 g/dL",
        medicaments: [],
        notes: "Bilan normalisé"
      }
    ]
  },

  // ── Patient 9 ──────────────────────────────────────────────────────────────
  {
    cin: "197109034100",
    nom: "Saidi",
    prenom: "Rachid",
    dateNaissance: new Date("1971-09-03"),
    sexe: "M",
    adresse: { wilaya: "Béjaïa", commune: "Bejaia" },
    groupeSanguin: "A+",
    antecedents: ["BPCO", "Tabagisme"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-02-28"),
        medecin: { nom: "Dr. Hadjeb", specialite: "Pneumologie" },
        diagnostic: "BPCO stade 2 – exacerbation",
        medicaments: [
          { nom: "Tiotropium",     dosage: "18µg",  duree: "30 jours" },
          { nom: "Prednisolone",   dosage: "40mg",  duree: "7 jours" },
          { nom: "Amoxicilline",   dosage: "1g",    duree: "7 jours" }
        ],
        notes: "Sevrage tabagique fortement recommandé"
      },
      {
        date: new Date("2023-11-09"),
        medecin: { nom: "Dr. Hadjeb", specialite: "Pneumologie" },
        diagnostic: "BPCO – suivi stable",
        medicaments: [
          { nom: "Tiotropium", dosage: "18µg", duree: "30 jours" }
        ],
        notes: "Spirométrie correcte – patient sevré du tabac"
      },
      {
        date: new Date("2024-04-01"),
        medecin: { nom: "Dr. Hadjeb", specialite: "Pneumologie" },
        diagnostic: "BPCO – contrôle annuel",
        medicaments: [
          { nom: "Tiotropium", dosage: "18µg", duree: "30 jours" }
        ],
        notes: "Stable"
      }
    ]
  },

  // ── Patient 10 ─────────────────────────────────────────────────────────────
  {
    cin: "198510246200",
    nom: "Hamdi",
    prenom: "Nadia",
    dateNaissance: new Date("1985-10-24"),
    sexe: "F",
    adresse: { wilaya: "Oran", commune: "Es Senia" },
    groupeSanguin: "AB-",
    antecedents: ["Migraine chronique"],
    allergies: ["Codéine"],
    consultations: [
      {
        date: new Date("2023-04-19"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Migraine sans aura – crise fréquente",
        medicaments: [
          { nom: "Sumatriptan", dosage: "50mg", duree: "Selon crise" },
          { nom: "Propranolol", dosage: "40mg", duree: "30 jours" }
        ],
        notes: "Journal des crises conseillé"
      },
      {
        date: new Date("2023-10-10"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Migraine – évaluation traitement de fond",
        medicaments: [
          { nom: "Topiramate", dosage: "25mg", duree: "30 jours" }
        ],
        notes: "IRM cérébrale normale"
      },
      {
        date: new Date("2024-03-05"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Migraine – amélioration 60 % des crises",
        medicaments: [
          { nom: "Topiramate", dosage: "50mg", duree: "60 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 11 ─────────────────────────────────────────────────────────────
  {
    cin: "196704177300",
    nom: "Belkacemi",
    prenom: "Hocine",
    dateNaissance: new Date("1967-04-17"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Kouba" },
    groupeSanguin: "O+",
    antecedents: ["Diabète type 2", "HTA", "Rétinopathie diabétique"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-03-07"),
        medecin: { nom: "Dr. Bensaid", specialite: "Ophtalmologie" },
        diagnostic: "Rétinopathie diabétique non proliférante",
        medicaments: [],
        notes: "Laser photocoagulation planifiée"
      },
      {
        date: new Date("2023-07-14"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – HbA1c 8,9 %",
        medicaments: [
          { nom: "Insuline Glargine", dosage: "24UI/soir", duree: "Continu" }
        ],
        notes: "Réévaluation ophtalmologie dans 3 mois"
      },
      {
        date: new Date("2024-01-05"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA – bilan cardiovasculaire",
        tension: { systolique: 140, diastolique: 86 },
        medicaments: [
          { nom: "Périndopril", dosage: "4mg", duree: "90 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 12 ─────────────────────────────────────────────────────────────
  {
    cin: "199312024400",
    nom: "Merzouk",
    prenom: "Imane",
    dateNaissance: new Date("1993-12-02"),
    sexe: "F",
    adresse: { wilaya: "Constantine", commune: "Constantine" },
    groupeSanguin: "B+",
    antecedents: ["Psoriasis"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-05-23"),
        medecin: { nom: "Dr. Aouad", specialite: "Dermatologie" },
        diagnostic: "Psoriasis en plaques modéré",
        medicaments: [
          { nom: "Bétaméthasone crème", dosage: "0,05 %", duree: "30 jours" },
          { nom: "Calcipotriol",        dosage: "50µg/g", duree: "30 jours" }
        ],
        notes: "Éviter le soleil excessif"
      },
      {
        date: new Date("2023-09-11"),
        medecin: { nom: "Dr. Aouad", specialite: "Dermatologie" },
        diagnostic: "Psoriasis – extension des lésions",
        medicaments: [
          { nom: "Méthotrexate", dosage: "7,5mg/sem", duree: "90 jours" },
          { nom: "Acide folique", dosage: "5mg",       duree: "90 jours" }
        ],
        notes: "NFS mensuelle obligatoire"
      },
      {
        date: new Date("2024-02-28"),
        medecin: { nom: "Dr. Aouad", specialite: "Dermatologie" },
        diagnostic: "Psoriasis – bonne réponse au Méthotrexate",
        medicaments: [
          { nom: "Méthotrexate", dosage: "10mg/sem", duree: "90 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 13 ─────────────────────────────────────────────────────────────
  {
    cin: "197807126500",
    nom: "Amrani",
    prenom: "Tarek",
    dateNaissance: new Date("1978-07-12"),
    sexe: "M",
    adresse: { wilaya: "Annaba", commune: "Annaba" },
    groupeSanguin: "A+",
    antecedents: ["Ulcère gastro-duodénal", "Tabagisme"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-01-30"),
        medecin: { nom: "Dr. Benfrid", specialite: "Gastro-entérologie" },
        diagnostic: "Ulcère gastrique Hp+",
        medicaments: [
          { nom: "Oméprazole",    dosage: "20mg x2", duree: "14 jours" },
          { nom: "Amoxicilline",  dosage: "1g x2",   duree: "7 jours" },
          { nom: "Clarithromycine",dosage: "500mg x2",duree: "7 jours" }
        ],
        notes: "Contrôle endoscopique à 6 semaines"
      },
      {
        date: new Date("2023-06-08"),
        medecin: { nom: "Dr. Benfrid", specialite: "Gastro-entérologie" },
        diagnostic: "Ulcère cicatrisé – Hp éradiqué",
        medicaments: [
          { nom: "Oméprazole", dosage: "20mg/j", duree: "30 jours" }
        ],
        notes: "Sevrage tabagique recommandé"
      },
      {
        date: new Date("2024-03-20"),
        medecin: { nom: "Dr. Benfrid", specialite: "Gastro-entérologie" },
        diagnostic: "Contrôle annuel – pas de récidive",
        medicaments: [],
        notes: ""
      }
    ]
  },

  // ── Patient 14 ─────────────────────────────────────────────────────────────
  {
    cin: "199001286700",
    nom: "Bouaziz",
    prenom: "Sara",
    dateNaissance: new Date("1990-01-28"),
    sexe: "F",
    adresse: { wilaya: "Blida", commune: "Blida" },
    groupeSanguin: "O+",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-12-05"),
        medecin: { nom: "Dr. Benali", specialite: "Médecine générale" },
        diagnostic: "Infection urinaire basse",
        medicaments: [
          { nom: "Fosfomycine", dosage: "3g dose unique", duree: "1 jour" }
        ],
        notes: "ECBU avant traitement"
      },
      {
        date: new Date("2024-04-10"),
        medecin: { nom: "Dr. Benali", specialite: "Médecine générale" },
        diagnostic: "Lombalgie mécanique",
        medicaments: [
          { nom: "Ibuprofène",  dosage: "400mg x3", duree: "7 jours" },
          { nom: "Thiocolchicoside", dosage: "4mg x2", duree: "5 jours" }
        ],
        notes: "Kinésithérapie conseillée"
      }
    ]
  },

  // ── Patient 15 ─────────────────────────────────────────────────────────────
  {
    cin: "196011307000",
    nom: "Djaballah",
    prenom: "Messaoud",
    dateNaissance: new Date("1960-11-30"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Birkhadem" },
    groupeSanguin: "B+",
    antecedents: ["Diabète type 2", "HTA", "AVC ischémique (2020)"],
    allergies: ["Clopidogrel"],
    consultations: [
      {
        date: new Date("2023-02-09"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Séquelles AVC – réévaluation",
        medicaments: [
          { nom: "Aspirine",    dosage: "100mg", duree: "Continu" },
          { nom: "Atorvastatine",dosage: "40mg", duree: "Continu" }
        ],
        notes: "Orthophonie 2x/semaine"
      },
      {
        date: new Date("2023-08-14"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "HTA – bilan cardiovasculaire post-AVC",
        tension: { systolique: 135, diastolique: 82 },
        medicaments: [
          { nom: "Ramipril", dosage: "5mg", duree: "90 jours" }
        ],
        notes: ""
      },
      {
        date: new Date("2024-01-18"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – HbA1c 7,5 %",
        medicaments: [
          { nom: "Metformine",    dosage: "1g x2", duree: "90 jours" },
          { nom: "Sitagliptine", dosage: "100mg",  duree: "90 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 16 ─────────────────────────────────────────────────────────────
  {
    cin: "198208166100",
    nom: "Zerrouki",
    prenom: "Lynda",
    dateNaissance: new Date("1982-08-16"),
    sexe: "F",
    adresse: { wilaya: "Tizi Ouzou", commune: "Tizi Ouzou" },
    groupeSanguin: "A+",
    antecedents: ["Polyarthrite rhumatoïde"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-03-27"),
        medecin: { nom: "Dr. Ouali", specialite: "Rhumatologie" },
        diagnostic: "Polyarthrite rhumatoïde – poussée inflammatoire",
        medicaments: [
          { nom: "Méthotrexate",    dosage: "15mg/sem", duree: "90 jours" },
          { nom: "Prednisone",      dosage: "10mg/j",   duree: "15 jours" },
          { nom: "Acide folique",   dosage: "5mg",      duree: "90 jours" }
        ],
        notes: "Bilan hépatique mensuel"
      },
      {
        date: new Date("2023-10-03"),
        medecin: { nom: "Dr. Ouali", specialite: "Rhumatologie" },
        diagnostic: "PR – réponse partielle, ajout hydroxychloroquine",
        medicaments: [
          { nom: "Méthotrexate",       dosage: "20mg/sem", duree: "90 jours" },
          { nom: "Hydroxychloroquine", dosage: "400mg/j",  duree: "90 jours" }
        ],
        notes: ""
      },
      {
        date: new Date("2024-04-15"),
        medecin: { nom: "Dr. Ouali", specialite: "Rhumatologie" },
        diagnostic: "PR – rémission partielle",
        medicaments: [
          { nom: "Méthotrexate",       dosage: "20mg/sem", duree: "90 jours" },
          { nom: "Hydroxychloroquine", dosage: "400mg/j",  duree: "90 jours" }
        ],
        notes: "Évaluation biologique DAS-28 amélioré"
      }
    ]
  },

  // ── Patient 17 ─────────────────────────────────────────────────────────────
  {
    cin: "197303218800",
    nom: "Boucetta",
    prenom: "Youcef",
    dateNaissance: new Date("1973-03-21"),
    sexe: "M",
    adresse: { wilaya: "Sétif", commune: "Sétif" },
    groupeSanguin: "O+",
    antecedents: ["Lithiase urinaire"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-07-04"),
        medecin: { nom: "Dr. Ziane", specialite: "Urologie" },
        diagnostic: "Colique néphrétique – calcul 5mm",
        medicaments: [
          { nom: "Diclofénac",  dosage: "75mg IM", duree: "3 jours" },
          { nom: "Phloroglucinol",dosage: "80mg",  duree: "5 jours" }
        ],
        notes: "Bonne hydratation conseillée – TDM dans 3 mois"
      },
      {
        date: new Date("2023-10-17"),
        medecin: { nom: "Dr. Ziane", specialite: "Urologie" },
        diagnostic: "Calcul expulsé spontanément",
        medicaments: [],
        notes: "Régime pauvre en oxalates"
      },
      {
        date: new Date("2024-03-12"),
        medecin: { nom: "Dr. Ziane", specialite: "Urologie" },
        diagnostic: "Contrôle – pas de nouveau calcul",
        medicaments: [],
        notes: ""
      }
    ]
  },

  // ── Patient 18 ─────────────────────────────────────────────────────────────
  {
    cin: "199803107600",
    nom: "Merad",
    prenom: "Djamila",
    dateNaissance: new Date("1998-03-10"),
    sexe: "F",
    adresse: { wilaya: "Béjaïa", commune: "Aokas" },
    groupeSanguin: "B+",
    antecedents: [],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-05-16"),
        medecin: { nom: "Dr. Ferhat", specialite: "Médecine générale" },
        diagnostic: "Grippe saisonnière",
        medicaments: [
          { nom: "Paracétamol", dosage: "1g x3", duree: "5 jours" }
        ],
        notes: "Repos et hydratation"
      },
      {
        date: new Date("2024-01-25"),
        medecin: { nom: "Dr. Ferhat", specialite: "Médecine générale" },
        diagnostic: "Rhinosinusite aiguë",
        medicaments: [
          { nom: "Amoxicilline-Clavulanate", dosage: "1g x2", duree: "7 jours" },
          { nom: "Pseudoéphédrine",          dosage: "60mg x3", duree: "5 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 19 ─────────────────────────────────────────────────────────────
  {
    cin: "196908137200",
    nom: "Henni",
    prenom: "Samir",
    dateNaissance: new Date("1969-08-13"),
    sexe: "M",
    adresse: { wilaya: "Alger", commune: "Dar El Beida" },
    groupeSanguin: "A+",
    antecedents: ["Diabète type 2", "HTA", "Dyslipidémie"],
    allergies: [],
    consultations: [
      {
        date: new Date("2023-01-11"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Bilan cardiovasculaire annuel – risque élevé",
        tension: { systolique: 142, diastolique: 90 },
        medicaments: [
          { nom: "Amlodipine",    dosage: "5mg",  duree: "90 jours" },
          { nom: "Atorvastatine", dosage: "20mg", duree: "90 jours" }
        ],
        notes: "Score de Framingham élevé"
      },
      {
        date: new Date("2023-07-19"),
        medecin: { nom: "Dr. Chabane", specialite: "Endocrinologie" },
        diagnostic: "Diabète type 2 – HbA1c 8,3 %",
        medicaments: [
          { nom: "Metformine", dosage: "1g x2", duree: "90 jours" },
          { nom: "Empagliflozine",dosage: "10mg", duree: "90 jours" }
        ],
        notes: "Empagliflozine pour bénéfice cardiorénal"
      },
      {
        date: new Date("2024-02-03"),
        medecin: { nom: "Dr. Mansouri", specialite: "Cardiologie" },
        diagnostic: "Suivi cardiovasculaire",
        tension: { systolique: 135, diastolique: 84 },
        medicaments: [
          { nom: "Amlodipine", dosage: "10mg", duree: "90 jours" }
        ],
        notes: ""
      }
    ]
  },

  // ── Patient 20 ─────────────────────────────────────────────────────────────
  {
    cin: "198612186300",
    nom: "Nacer",
    prenom: "Widad",
    dateNaissance: new Date("1986-12-18"),
    sexe: "F",
    adresse: { wilaya: "Oran", commune: "Oran" },
    groupeSanguin: "O+",
    antecedents: ["Épilepsie"],
    allergies: ["Carbamazépine"],
    consultations: [
      {
        date: new Date("2023-04-29"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Épilepsie focale – crises mal contrôlées",
        medicaments: [
          { nom: "Valproate",   dosage: "500mg x2", duree: "90 jours" }
        ],
        notes: "EEG dans 4 semaines"
      },
      {
        date: new Date("2023-09-15"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Épilepsie – ajout Lamotrigine",
        medicaments: [
          { nom: "Valproate",    dosage: "500mg x2", duree: "90 jours" },
          { nom: "Lamotrigine",  dosage: "50mg x2",  duree: "90 jours" }
        ],
        notes: "Titration progressive"
      },
      {
        date: new Date("2024-03-24"),
        medecin: { nom: "Dr. Benali", specialite: "Neurologie" },
        diagnostic: "Épilepsie – bonne réponse, 0 crise en 4 mois",
        medicaments: [
          { nom: "Valproate",   dosage: "500mg x2", duree: "90 jours" },
          { nom: "Lamotrigine", dosage: "100mg x2", duree: "90 jours" }
        ],
        notes: "Continuer le traitement – IRM cérébrale stable"
      }
    ]
  }
];

db.patients.deleteMany({});   // Nettoyage avant ré-insertion
const insertResult = db.patients.insertMany(patients);

print("✅ " + insertResult.insertedIds.length + " patients insérés");

// ─── 1.3 : Analyses référencées ──────────────────────────────────────────────
// Récupérer les _id des patients insérés pour les relier aux analyses
const allPatients = db.patients.find({}, { _id: 1, cin: 1, nom: 1 }).toArray();

// Helper : trouver un _id par CIN
function pid(cin) {
  const p = allPatients.find(x => x.cin === cin);
  return p ? p._id : null;
}

const analyses = [
  // ── Patient 1 : Bensalem Ahmed ───────────────────────────────────────────
  {
    patient_id: pid("198001012300"),
    date: new Date("2024-01-10"),
    type: "Glycémie",
    resultats: { glycemie_ajun: 1.85, unite: "g/L", interpretation: "Élevée" },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: pid("198001012300"),
    date: new Date("2024-01-10"),
    type: "Lipidogramme",
    resultats: {
      cholesterol_total: 2.3, ldl: 1.5, hdl: 0.4, triglycerides: 2.0,
      unite: "g/L"
    },
    laboratoire: "Labo Central Alger",
    valide: true
  },

  // ── Patient 3 : Boudiaf Karim ─────────────────────────────────────────────
  {
    patient_id: pid("197512082100"),
    date: new Date("2023-05-25"),
    type: "Lipidogramme",
    resultats: {
      cholesterol_total: 2.6, ldl: 1.8, hdl: 0.35, triglycerides: 2.4,
      unite: "g/L"
    },
    laboratoire: "Labo Ibn Sina Constantine",
    valide: true
  },
  {
    patient_id: pid("197512082100"),
    date: new Date("2024-03-01"),
    type: "Glycémie",
    resultats: { glycemie_ajun: 1.3, unite: "g/L", interpretation: "Contrôlée" },
    laboratoire: "Labo Ibn Sina Constantine",
    valide: true
  },

  // ── Patient 5 : Hadj Mokhtar ─────────────────────────────────────────────
  {
    patient_id: pid("196803195600"),
    date: new Date("2023-01-12"),
    type: "Créatinine",
    resultats: { creatinine: 145, dfg: 45, unite: "µmol/L", interpretation: "IRC stade 3" },
    laboratoire: "CHU Blida",
    valide: true
  },
  {
    patient_id: pid("196803195600"),
    date: new Date("2023-05-05"),
    type: "NFS",
    resultats: {
      hb: 10.2, gb: 6500, plaquettes: 210000,
      unite: "g/dL & /mm³"
    },
    laboratoire: "CHU Blida",
    valide: true
  },

  // ── Patient 7 : Bouzid Abdelkader ────────────────────────────────────────
  {
    patient_id: pid("196205288900"),
    date: new Date("2023-03-10"),
    type: "ECG",
    resultats: { rythme: "Sinusal", frequence: 68, anomalies: "Séquelles antéroseptales" },
    laboratoire: "CHU Mustapha Pacha",
    valide: true
  },

  // ── Patient 8 : Touati Rania ──────────────────────────────────────────────
  {
    patient_id: pid("199507119900"),
    date: new Date("2023-06-10"),
    type: "NFS",
    resultats: {
      hb: 8.5, gb: 5800, plaquettes: 180000, vgm: 72,
      unite: "g/dL & /mm³", interpretation: "Anémie microcytaire ferriprive"
    },
    laboratoire: "Labo Privé Sétif",
    valide: true
  },
  {
    patient_id: pid("199507119900"),
    date: new Date("2023-08-15"),
    type: "NFS",
    resultats: {
      hb: 10.2, gb: 6000, plaquettes: 195000, vgm: 78,
      unite: "g/dL & /mm³", interpretation: "Amélioration"
    },
    laboratoire: "Labo Privé Sétif",
    valide: true
  },

  // ── Patient 11 : Belkacemi Hocine ─────────────────────────────────────────
  {
    patient_id: pid("196704177300"),
    date: new Date("2023-07-01"),
    type: "Glycémie",
    resultats: { glycemie_ajun: 1.95, hba1c: 8.9, unite: "g/L", interpretation: "Mal contrôlé" },
    laboratoire: "Labo Central Alger",
    valide: true
  },

  // ── Patient 13 : Amrani Tarek ─────────────────────────────────────────────
  {
    patient_id: pid("197807126500"),
    date: new Date("2023-01-25"),
    type: "NFS",
    resultats: {
      hb: 11.5, gb: 8200, plaquettes: 220000, unite: "g/dL & /mm³",
      interpretation: "Sub-normale"
    },
    laboratoire: "Labo Annaba",
    valide: true
  },

  // ── Patient 19 : Henni Samir ──────────────────────────────────────────────
  {
    patient_id: pid("196908137200"),
    date: new Date("2023-01-05"),
    type: "Lipidogramme",
    resultats: {
      cholesterol_total: 2.5, ldl: 1.7, hdl: 0.38, triglycerides: 2.1,
      unite: "g/L"
    },
    laboratoire: "Labo Central Alger",
    valide: true
  },
  {
    patient_id: pid("196908137200"),
    date: new Date("2023-01-05"),
    type: "Glycémie",
    resultats: { glycemie_ajun: 1.78, hba1c: 8.3, unite: "g/L", interpretation: "Mal contrôlé" },
    laboratoire: "Labo Central Alger",
    valide: true
  }
];

db.analyses.deleteMany({});
const analysesResult = db.analyses.insertMany(analyses);

print("✅ " + analysesResult.insertedIds.length + " analyses insérées");
print("✅ Modélisation terminée. Patients:", db.patients.countDocuments(),
      "| Analyses:", db.analyses.countDocuments());
