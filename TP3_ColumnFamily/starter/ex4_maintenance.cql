-- TP3 - Exercice 4 : Compaction et Maintenance
-- Use Case : SmartGrid DZ

USE smartgrid;


-- 4.1 : Choisir la stratégie de compaction pour chaque table
--
-- Il existe trois stratégies principales en Cassandra :
--
-- TWCS (TimeWindowCompactionStrategy) :
--   Conçue pour les séries temporelles avec TTL. Elle groupe les SSTables
--   par fenêtres de temps. Une fois une fenêtre fermée (plus d'écriture dans
--   cette période), les SSTables sont compactées entre elles une seule fois.
--   Résultat : les données expirées (TTL) sont purgées efficacement car elles
--   vivent dans des SSTables dédiées à leur période. Idéal pour mesures_par_capteur
--   et alertes_par_wilaya.
--
-- STCS (SizeTieredCompactionStrategy) :
--   Stratégie par défaut. Compacte les SSTables de taille similaire ensemble.
--   Bien pour les charges mixtes (lectures + écritures variées), mais moins
--   efficace pour les séries temporelles car les données récentes et anciennes
--   se retrouvent mélangées, ce qui complique l'expiration par TTL.
--
-- LCS (LeveledCompactionStrategy) :
--   Maintient les données dans des niveaux (L0, L1, L2...) avec une taille
--   maximale par niveau. Excellente pour les lectures (peu de SSTables à lire),
--   mais écrit beaucoup plus sur disque (write amplification élevée). Bien
--   adapté aux tables avec beaucoup de lectures et peu d'écritures, comme
--   agregats_horaires.
--
-- Résumé pour SmartGrid DZ :
--   mesures_par_capteur  -> TWCS  : insertions massives avec TTL 90 jours
--   alertes_par_wilaya   -> TWCS  : insertions fréquentes avec TTL 1 an
--   agregats_horaires    -> LCS   : peu d'écritures, beaucoup de lectures dashboard


-- 4.2 : Configurer TWCS pour la table des mesures
-- On choisit une fenêtre de 1 jour car :
--   - On insère environ 1 440 mesures/capteur/jour (1 par minute)
--   - Le TTL est de 90 jours : après 90 jours, une fenêtre entière expire
--     et Cassandra peut supprimer l'intégralité de la SSTable sans merge.
--   - Une fenêtre trop petite (1h) crée trop de SSTables à gérer.
--   - Une fenêtre trop grande (1 semaine) retarde la libération de l'espace disque.

ALTER TABLE mesures_par_capteur
WITH compaction = {
    'class':                    'TimeWindowCompactionStrategy',
    'compaction_window_unit':   'DAYS',
    'compaction_window_size':   1
};

-- TWCS pour les alertes : fenêtre de 7 jours
-- Les alertes sont moins fréquentes (10% des mesures), une fenêtre plus large
-- est acceptable et réduit le nombre de SSTables créées.

ALTER TABLE alertes_par_wilaya
WITH compaction = {
    'class':                    'TimeWindowCompactionStrategy',
    'compaction_window_unit':   'DAYS',
    'compaction_window_size':   7
};

-- LCS pour les agrégats : lecture-intensive, faible volume d'écriture
ALTER TABLE agregats_horaires
WITH compaction = {
    'class':          'LeveledCompactionStrategy',
    'sstable_size_in_mb': 160
};


-- 4.3 : Vérifier l'utilisation des TTL
-- Cassandra ne fournit pas de requête native "combien de lignes expirent dans 7 jours",
-- mais on peut utiliser la fonction TTL() sur une colonne non-primary-key pour voir
-- le temps restant avant expiration d'une ligne donnée.

-- Voir le TTL restant d'une mesure spécifique :
SELECT capteur_id, timestamp, TTL(tension_v) as secondes_avant_expiration
FROM mesures_par_capteur
WHERE capteur_id = 550e8400-e29b-41d4-a716-446655440000
  AND date_jour  = '2025-01-15'
LIMIT 10;

-- Identifier les mesures qui expirent dans moins de 7 jours (604 800 secondes) :
-- Note : il n'est pas possible de filtrer sur TTL() directement en CQL.
-- Cette vérification se fait soit côté application (parcourir les partitions
-- récentes et filtrer TTL < 604800), soit via nodetool cfstats pour voir
-- les statistiques globales de compression et d'expiration par table.

-- Commandes nodetool utiles pour surveiller les TTL et la compaction :
--   nodetool cfstats smartgrid.mesures_par_capteur
--   nodetool compactionstats
--   nodetool tpstats


-- 4.4 : Analyser une partition "hot" - détection et correction
--
-- Qu'est-ce qu'une hot partition ?
--   Une partition qui reçoit beaucoup plus de trafic que les autres.
--   Cassandra distribue les données par partition key. Si une partition est
--   trop populaire, le nœud qui l'héberge se retrouve surchargé pendant que
--   les autres sont inactifs. C'est le problème qu'on voulait éviter avec
--   notre bucketing (capteur_id, date_jour).
--
-- Comment détecter une hot partition ?
--   1. nodetool tpstats : si un nœud a des latences bien supérieures aux autres.
--   2. nodetool cfhistograms smartgrid mesures_par_capteur : distribution des
--      tailles de partitions. Une partition anormalement grande est suspecte.
--   3. Outils externes : DataStax OpsCenter, Prometheus + Grafana, ou les logs
--      Cassandra qui signalent les "large partition warnings" (configurable via
--      compaction_large_partition_warning_threshold_mb dans cassandra.yaml).
--
-- Comment corriger une hot partition ?
--   Stratégie 1 - Affiner le bucketing :
--     Au lieu de (capteur_id, date_jour), passer à (capteur_id, date_heure)
--     pour les capteurs très actifs. Cela divise la taille des partitions par 24.
--
--   Stratégie 2 - Ajouter un salt / shard key :
--     Ajouter un chiffre aléatoire (0-9) à la partition key pour distribuer
--     artificiellement la charge sur 10x plus de partitions.
--     La requête devient une scatter-gather sur 10 partitions, mais c'est
--     préférable à un seul nœud surchargé.
--
--   Stratégie 3 - Revoir le modèle si la cardinalité est insuffisante :
--     Par exemple, si on avait mis uniquement 'wilaya' comme partition key,
--     on aurait 5 partitions pour 10 000 capteurs -> hot partition garantie.
--     La solution est de descendre au niveau capteur_id comme on l'a fait.

-- Exemple de requête pour estimer la taille d'une partition dans cqlsh
-- (disponible depuis Cassandra 4.x avec virtual tables system_views) :
SELECT partition_key, mean_partition_size, max_partition_size
FROM system_views.table_sizes
WHERE keyspace_name = 'smartgrid'
  AND table_name    = 'mesures_par_capteur';
