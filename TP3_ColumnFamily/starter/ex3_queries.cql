-- TP3 - Exercice 3 : Requêtes CQL
-- Use Case : SmartGrid DZ
-- Toutes les requêtes respectent le modèle de données défini en Ex1 :
-- on ne filtre que sur les colonnes de la primary key, sans ALLOW FILTERING.

USE smartgrid;


-- 3.1 : Mesures d'un capteur spécifique sur les dernières 6 heures
-- On doit fournir capteur_id + date_jour (la partition key complète).
-- Le timestamp en clustering DESC fait que les mesures les plus récentes
-- arrivent en tête de résultat naturellement.

SELECT capteur_id, timestamp, tension_v, courant_a, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour  = '2025-01-15'
  AND timestamp >= '2025-01-15 10:00:00'
  AND timestamp <= '2025-01-15 16:00:00';


-- 3.2 : Dernière mesure connue de chaque capteur d'une wilaya
-- Cassandra ne fait pas de GROUP BY multi-partitions. La bonne approche
-- est de requêter chaque capteur individuellement avec LIMIT 1, ce que
-- l'application fait en parallèle (async). Ici on montre la requête unitaire.
-- Le LIMIT 1 combiné au CLUSTERING ORDER BY DESC retourne bien la dernière.

SELECT capteur_id, timestamp, tension_v, puissance_kw, alerte
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour  = '2025-01-15'
LIMIT 1;


-- 3.3 : Capteurs en alerte dans la wilaya "Alger" aujourd'hui
-- On utilise alertes_par_wilaya qui a été conçue exactement pour cette requête.
-- La partition (wilaya, date_jour) isole les données d'Alger pour aujourd'hui.

SELECT capteur_id, timestamp, code_alerte, gravite, description
FROM alertes_par_wilaya
WHERE wilaya   = 'Alger'
  AND date_jour = '2025-01-15';

-- Compter le nombre total d'alertes d'Alger aujourd'hui
SELECT COUNT(*)
FROM alertes_par_wilaya
WHERE wilaya   = 'Alger'
  AND date_jour = '2025-01-15';


-- 3.4 : Consommation totale par heure sur une journée (dashboard)
-- On lit les agrégats pré-calculés depuis agregats_horaires.
-- La partition est la wilaya, le clustering key est date_heure.
-- On filtre sur une plage de 24h pour obtenir les 24 points du dashboard.

SELECT wilaya, date_heure, puissance_moy_kw, puissance_max_kw, nb_capteurs, nb_alertes
FROM agregats_horaires
WHERE wilaya    = 'Alger'
  AND date_heure >= '2025-01-15 00:00:00'
  AND date_heure <  '2025-01-16 00:00:00';


-- 3.5 : Détection d'anomalie - capteurs avec tension hors norme dans les 30 dernières minutes
-- On cherche les alertes de type tension dans alertes_par_wilaya.
-- On passe la plage de timestamp en clustering key pour un scan efficace.

SELECT capteur_id, timestamp, code_alerte, gravite
FROM alertes_par_wilaya
WHERE wilaya    = 'Alger'
  AND date_jour  = '2025-01-15'
  AND timestamp >= '2025-01-15 15:30:00'
  AND timestamp <= '2025-01-15 16:00:00';

-- Remarque : le filtre sur code_alerte (SOUS_TENSION, SUR_TENSION) n'est pas
-- possible sans ALLOW FILTERING car ce n'est pas une clustering key.
-- La bonne pratique serait de créer une table alertes_par_type si cette
-- requête devient fréquente. Exemple de schéma à ajouter en bonus :
--   PRIMARY KEY ((wilaya, code_alerte, date_jour), timestamp, capteur_id)


-- 3.6 : Top 10 capteurs les plus actifs (plus de mesures) cette semaine
-- Cassandra n'est pas fait pour ce type de requête analytique sur plusieurs
-- partitions. La bonne approche est de maintenir un compteur applicatif,
-- ou d'utiliser Spark + Cassandra pour les analytics. Néanmoins, si on
-- dispose d'une table de compteurs dédiée, on peut faire :

-- Dans notre modèle actuel, on peut lire par capteur + date et compter
-- côté application. Voici la requête pour un capteur sur une semaine :
SELECT capteur_id, COUNT(*) as nb_mesures
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour IN ('2025-01-09', '2025-01-10', '2025-01-11',
                    '2025-01-12', '2025-01-13', '2025-01-14', '2025-01-15');

-- Pour un vrai Top 10, l'application parcourt tous les capteurs en async,
-- collecte les COUNT(*) et trie côté client. C'est le pattern correct
-- avec Cassandra : faire le tri et l'agrégation dans le code applicatif.


-- 3.7 : ALLOW FILTERING - pourquoi l'éviter, et comment faire mieux

-- Version DANGEREUSE - ne jamais faire ça en production :
-- SELECT * FROM mesures_par_capteur WHERE wilaya = 'Alger' ALLOW FILTERING;
--
-- Pourquoi c'est dangereux ?
--   - Cassandra va scanner TOUTES les partitions de la table sur TOUS les nœuds
--     du cluster pour trouver les lignes où wilaya = 'Alger'.
--   - Avec 10 000 capteurs et 5 minutes de données, ça représente 50 000 lignes
--     à lire juste pour en retourner ~10 000. En production avec des mois de data,
--     ça peut faire tomber le cluster (timeouts, GC pressure, nodetool tpstats rouge).
--   - Le nom "ALLOW FILTERING" est trompeur : Cassandra vous avertit qu'il va
--     faire un full scan, mais il le fait quand même si vous insistez.
--
-- La version correcte utilise la bonne table avec la bonne partition key :
SELECT capteur_id, timestamp, tension_v, puissance_kw
FROM alertes_par_wilaya
WHERE wilaya   = 'Alger'
  AND date_jour = '2025-01-15';
--
-- Cette requête lit UNE seule partition sur UN seul nœud. O(1) en termes
-- de partitions accédées, même si la table contient des milliards de lignes.
-- C'est le cœur du principe "model your queries, not your entities".
