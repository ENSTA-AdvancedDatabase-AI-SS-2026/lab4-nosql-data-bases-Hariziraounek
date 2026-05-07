-- TP3 - Exercice 1 : Schéma Cassandra
-- Use Case : SmartGrid DZ - Surveillance du Réseau Electrique Algérien
-- 10 000 capteurs, 5 wilayas, ingestion de mesures IoT en temps réel


-- 1.1 : Créer le Keyspace
-- On utilise NetworkTopologyStrategy plutôt que SimpleStrategy parce qu'on
-- anticipe un déploiement multi-datacenter. replication_factor=1 pour le TP
-- local (pas besoin de 3 nœuds sur une machine), mais en prod on met 3.

CREATE KEYSPACE IF NOT EXISTS smartgrid
WITH replication = {
    'class': 'NetworkTopologyStrategy',
    'datacenter1': 1
}
AND durable_writes = true;

USE smartgrid;


-- 1.2 : Table mesures_par_capteur
-- Requête cible : "Toutes les mesures du capteur X entre T1 et T2"
--
-- Pourquoi cette partition key ?
--   - (capteur_id, date_jour) : on groupe les mesures d'un capteur par jour.
--     Cela évite la "hot partition" : si on avait juste capteur_id, une seule
--     partition contiendrait TOUTES les mesures sur des années entières.
--     Avec le bucketing par jour, chaque partition ne stocke que 1440 mesures
--     max (une par minute sur 24h), ce qui est parfaitement gérable.
--
-- Pourquoi timestamp en clustering key DESC ?
--   - On veut les dernières mesures en premier, sans ORDER BY dans les requêtes.
--     Cassandra trie physiquement les données dans cet ordre sur disque.

CREATE TABLE IF NOT EXISTS mesures_par_capteur (
    capteur_id    UUID,
    date_jour     DATE,
    timestamp     TIMESTAMP,
    wilaya        TEXT,
    commune       TEXT,
    tension_v     FLOAT,
    courant_a     FLOAT,
    puissance_kw  FLOAT,
    frequence_hz  FLOAT,
    temperature   FLOAT,
    alerte        BOOLEAN,
    code_alerte   TEXT,
    PRIMARY KEY ((capteur_id, date_jour), timestamp)
) WITH CLUSTERING ORDER BY (timestamp DESC)
  AND default_time_to_live = 7776000
  AND comment = 'Mesures brutes par capteur, bucketing journalier. TTL 90 jours.';


-- 1.3 : Table alertes_par_wilaya
-- Requête cible : "Toutes les alertes de la wilaya Alger le jour J"
--
-- Pourquoi (wilaya, date_jour) comme partition key ?
--   - C'est exactement le pattern de la requête. On veut toutes les alertes
--     d'une wilaya sur un jour donné. Séparer par jour évite que la partition
--     grossisse indéfiniment : même avec 10 000 capteurs et 10% d'alertes,
--     on a au max ~14 400 alertes par wilaya par jour, ce qui reste raisonnable.
--
-- On ajoute capteur_id en clustering key pour garantir l'unicité quand deux
-- alertes arrivent au même timestamp (ce qui peut arriver avec des batches).

CREATE TABLE IF NOT EXISTS alertes_par_wilaya (
    wilaya       TEXT,
    date_jour    DATE,
    timestamp    TIMESTAMP,
    capteur_id   UUID,
    code_alerte  TEXT,
    description  TEXT,
    gravite      INT,
    resolue      BOOLEAN,
    PRIMARY KEY ((wilaya, date_jour), timestamp, capteur_id)
) WITH CLUSTERING ORDER BY (timestamp DESC, capteur_id ASC)
  AND default_time_to_live = 31536000
  AND comment = 'Alertes par wilaya et par jour. TTL 1 an.';


-- 1.4 : Table agregats_horaires
-- Requête cible : "Consommation moyenne par heure pour le dashboard d'une wilaya"
--
-- Pourquoi wilaya comme partition key seule ici ?
--   - Les agrégats sont pré-calculés (une ligne par heure par wilaya).
--     Le volume est très faible : 5 wilayas × 24h × 365j × 5ans = ~219 000 lignes
--     au total. On peut se permettre une partition par wilaya sans risque.
--     Si on ajoutait l'année ou le mois, les requêtes dashboard deviendraient
--     plus complexes (multiple partition queries).
--
-- date_heure en clustering DESC pour avoir les heures les plus récentes en premier,
-- parfait pour un dashboard "temps réel".

CREATE TABLE IF NOT EXISTS agregats_horaires (
    wilaya            TEXT,
    date_heure        TIMESTAMP,
    nb_capteurs       INT,
    puissance_moy_kw  FLOAT,
    puissance_max_kw  FLOAT,
    puissance_min_kw  FLOAT,
    nb_alertes        INT,
    PRIMARY KEY (wilaya, date_heure)
) WITH CLUSTERING ORDER BY (date_heure DESC)
  AND default_time_to_live = 157680000
  AND comment = 'Agregats horaires pre-calcules par wilaya pour les dashboards. TTL 5 ans.';


-- Verification : on liste les tables créées
DESCRIBE TABLES;
