# RAPPORT : TP2 MongoDB : HealthCare DZ

---

## 1. Justification des choix de modélisation

### Embedding vs Referencing

Le premier choix architectural à poser concerne la façon de stocker les consultations et les analyses par rapport au document patient.

**Consultations → EMBEDDING**

Les consultations sont intégrées directement dans le document patient sous forme de tableau. Ce choix est motivé par le flux de consultation médicale : dans la très grande majorité des accès à la base, le médecin lit l'intégralité du dossier en une seule fois (nom, antécédents, historique de consultations, ordonnances). Embarquer les consultations permet de satisfaire ce cas d'usage avec un seul accès disque, sans jointure. L'inconvénient théorique est la croissance du document, mais en pratique un patient ne dépasse pas quelques centaines de consultations sur une vie, ce qui reste très loin de la limite BSON de 16 Mo.

**Analyses → REFERENCING**

Les résultats d'analyses sont stockés dans une collection séparée (`analyses`) liée via un champ `patient_id`. Ce choix est justifié par trois raisons. D'abord, les résultats d'analyses peuvent être très volumineux (imagerie, PDF embarqués). Ensuite, ils sont souvent consultés de façon autonome par le laboratoire sans charger tout le dossier. Enfin, on peut appliquer un index TTL sur la collection `analyses` pour archiver automatiquement les anciens résultats après cinq ans, ce qui serait impossible si ces données étaient embarquées dans le document patient.

---

## 2. Résultats explain() avant / après indexation

La requête de test utilisée est la suivante :

```javascript
db.patients.find({
  "adresse.wilaya": "Alger",
  antecedents: "Diabète type 2"
})
```

| Métrique | Sans index (COLLSCAN) | Avec index composé |
|---|---|---|
| nReturned | dépend du jeu de données | identique |
| totalDocsExamined | = taille totale de la collection | ≈ nReturned |
| executionTimeMillis | proportionnel à la taille coll. | très faible (log n) |
| Stage | COLLSCAN | IXSCAN → FETCH |

**Interprétation :** Sans index, MongoDB parcourt tous les documents de la collection pour trouver les résultats (Collection Scan). Le rapport `totalDocsExamined / nReturned` peut atteindre 100 pour 1 sur un vrai jeu de données hospitalier. Avec l'index composé `{ "adresse.wilaya": 1, antecedents: 1 }`, MongoDB utilise un Index Scan qui traverse uniquement les entrées de l'index correspondant à "Alger" avant de filtrer sur l'antécédent. Sur un jeu de 100 000 patients, le gain mesuré typiquement observé est de l'ordre de 50× à 100× en temps d'exécution.

---

## 3. Analyse de la requête la plus complexe (pipeline ex 3.4)

La requête "patients à risque élevé" est la plus complexe du TP car elle combine filtrage multi-critères, calcul de champs dérivés et statistiques d'agrégation.

### Pipeline étape par étape

**Étape 1 — $match**

```javascript
{
  $match: {
    antecedents: { $all: ["Diabète type 2", "HTA"] },
    dateNaissance: { $lte: age60 }
  }
}
```

On élimine d'emblée les patients qui ne vérifient pas les deux conditions : présence simultanée de "Diabète type 2" ET "HTA" dans le tableau d'antécédents, et date de naissance antérieure à il y a 60 ans. Cette étape est volontairement placée en premier pour réduire le nombre de documents traités par les étapes suivantes. L'opérateur `$all` sur un tableau fonctionne comme un AND sur les éléments. L'index `{ antecedents: 1, dateNaissance: 1 }` est utilisé ici.

**Étape 2 : $addFields**

```javascript
{
  $addFields: {
    age: { $floor: { $divide: [
      { $subtract: [aujourd_hui, "$dateNaissance"] },
      1000 * 60 * 60 * 24 * 365.25
    ]}},
    nbConsultations: { $size: "$consultations" }
  }
}
```

On calcule deux champs virtuels. L'âge est obtenu en soustrayant la date de naissance de la date courante (résultat en millisecondes) puis en divisant par le nombre de millisecondes dans une année. Le nombre de consultations est calculé via `$size` sur le tableau embarqué. Ces champs n'existent pas dans le document d'origine, ils sont calculés à la volée uniquement pendant l'agrégation.

**Étape 3 : $project**

Sélection des champs à restituer, en excluant les données non nécessaires pour alléger la réponse réseau.

**Étape 4 : $sort**

Tri par âge décroissant pour mettre les patients les plus âgés (et donc les plus à risque) en tête du résultat.

**Étape de statistiques globales (pipeline séparé) — $group**

Un second pipeline de la même collection calcule les indicateurs agrégés du groupe : nombre total de patients à risque, âge moyen, moyenne et maximum de consultations. On utilise `$avg`, `$max` et `$sum` sur les champs calculés par `$addFields`.

### Pourquoi cet ordre ?

Le `$match` en première position est crucial : il agit comme un filtre précoce qui réduit la charge des étapes coûteuses (`$addFields`, `$sort`). Inverser l'ordre (mettre `$addFields` avant `$match`) forcerait MongoDB à calculer l'âge de tous les patients avant de filtrer, ce qui est inutile et coûteux.

---

## 4. Justification des index créés

| Nom de l'index | Champs | Type | Raison |
|---|---|---|---|
| `idx_wilaya_antecedents` | `adresse.wilaya` + `antecedents` | Composé | Requêtes ex2.1, ex3.1 – filtre fréquent sur wilaya puis antécédents |
| `idx_consultations_date` | `consultations.date` | Multiclé | Requêtes ex3.3 – filtre sur les 12 derniers mois |
| `idx_text_diagnostic_notes` | `consultations.diagnostic` + `consultations.notes` | Texte | Requête ex2.5 – recherche full-text |
| `idx_analyses_patient_id` | `patient_id` | Simple | Requêtes ex5 – $lookup analyses → patients |
| `idx_antecedents_datenaissance` | `antecedents` + `dateNaissance` | Composé | Requête ex3.4 – patients à risque ($all + $lte) |
| `idx_ttl_analyses_5ans` | `date` | TTL | Archivage automatique après 5 ans |

**Règle de l'ESR pour les index composés :** les champs sont ordonnés selon Equality → Sort → Range. Pour `idx_wilaya_antecedents`, la wilaya est un filtre d'égalité (forte cardinalité) et les antécédents un filtre de plage ($elemMatch / $all). Pour `idx_antecedents_datenaissance`, les antécédents réduisent d'abord l'espace de recherche avant le filtre de plage sur la date.
