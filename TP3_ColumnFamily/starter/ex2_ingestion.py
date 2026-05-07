"""
TP3 - Exercice 2 : Ingestion de données IoT
Use Case : SmartGrid DZ - 10 000 capteurs, 5 minutes de mesures

On génère des données simulées réalistes pour le réseau électrique algérien,
puis on les ingère dans Cassandra en utilisant des UNLOGGED BATCH statements
pour maximiser le débit tout en respectant les bonnes pratiques Cassandra.
"""

from cassandra.cluster import Cluster
from cassandra.query import BatchStatement, BatchType
import uuid
import random
from datetime import datetime, timedelta
import time

# Configuration de base
CASSANDRA_HOST = 'localhost'
KEYSPACE = 'smartgrid'
NB_CAPTEURS = 10000
MINUTES_HISTORIQUE = 5

# On travaille avec les 5 wilayas mentionnées dans le sujet
WILAYAS = ["Alger", "Oran", "Constantine", "Annaba", "Blida"]
COMMUNES = {
    "Alger":       ["Bab Ezzouar", "Hydra", "El Harrach", "Dar El Beida"],
    "Oran":        ["Bir El Djir", "Es Senia", "Arzew"],
    "Constantine": ["El Khroub", "Ain Smara", "Hamma Bouziane"],
    "Annaba":      ["El Bouni", "El Hadjar", "Seraidi"],
    "Blida":       ["Bougara", "Boufarik", "Larbaa"],
}

# Taille max recommandée pour un batch Cassandra. Au-delà, on risque
# des timeouts et une pression mémoire sur les coordinateurs.
BATCH_SIZE = 50

# Seuil de tension pour déclencher une alerte (réseau algérien : 220V)
TENSION_MIN = 200.0
TENSION_MAX = 240.0


def connect():
    """Connexion au cluster Cassandra et sélection du keyspace."""
    cluster = Cluster([CASSANDRA_HOST])
    session = cluster.connect(KEYSPACE)
    print(f"Connecté à Cassandra - keyspace : {KEYSPACE}")
    return session, cluster


def generate_mesure(capteur_id, wilaya, commune, timestamp):
    """
    Génère une mesure réaliste pour un capteur donné à un instant donné.
    
    Le réseau électrique algérien tourne à 220V / 50Hz. On simule des
    variations gaussiennes autour de ces valeurs nominales, avec un
    faible bruit pour rester crédible.
    """
    tension = round(220 + random.gauss(0, 5), 2)
    courant = round(random.uniform(0.5, 15.0), 2)
    puissance = round(random.uniform(0.1, 3.3), 3)
    frequence = round(50 + random.gauss(0, 0.1), 2)
    temperature = round(random.uniform(20, 65), 1)

    # Une alerte est déclenchée si la tension sort des bornes normales
    # (hors fourchette 200-240V) ou aléatoirement dans 5% des cas restants
    tension_hors_norme = tension < TENSION_MIN or tension > TENSION_MAX
    alerte = tension_hors_norme or random.random() < 0.05

    code_alerte = None
    if alerte:
        if tension < TENSION_MIN:
            code_alerte = "SOUS_TENSION"
        elif tension > TENSION_MAX:
            code_alerte = "SUR_TENSION"
        else:
            code_alerte = "ANOMALIE_GENERIQUE"

    return {
        "capteur_id":    capteur_id,
        "date_jour":     timestamp.date(),
        "timestamp":     timestamp,
        "wilaya":        wilaya,
        "commune":       commune,
        "tension_v":     tension,
        "courant_a":     courant,
        "puissance_kw":  puissance,
        "frequence_hz":  frequence,
        "temperature":   temperature,
        "alerte":        alerte,
        "code_alerte":   code_alerte,
    }


def prepare_statements(session):
    """
    On prépare les statements une seule fois au démarrage. C'est une bonne
    pratique Cassandra : la préparation parse et compile la requête côté
    serveur, les exécutions suivantes n'envoient que les paramètres.
    """
    insert_mesure = session.prepare("""
        INSERT INTO mesures_par_capteur (
            capteur_id, date_jour, timestamp, wilaya, commune,
            tension_v, courant_a, puissance_kw, frequence_hz,
            temperature, alerte, code_alerte
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 7776000
    """)

    insert_alerte = session.prepare("""
        INSERT INTO alertes_par_wilaya (
            wilaya, date_jour, timestamp, capteur_id,
            code_alerte, description, gravite, resolue
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        USING TTL 31536000
    """)

    return insert_mesure, insert_alerte


def insert_single(session, mesure, stmt_mesure):
    """
    Insère une seule mesure (utile pour les tests unitaires ou les
    insertions de faible volume). En production on préfère insert_batch.
    """
    session.execute(stmt_mesure, (
        mesure["capteur_id"],
        mesure["date_jour"],
        mesure["timestamp"],
        mesure["wilaya"],
        mesure["commune"],
        mesure["tension_v"],
        mesure["courant_a"],
        mesure["puissance_kw"],
        mesure["frequence_hz"],
        mesure["temperature"],
        mesure["alerte"],
        mesure["code_alerte"],
    ))


def insert_batch(session, mesures: list, stmt_mesure, stmt_alerte):
    """
    Insère une liste de mesures en UNLOGGED BATCH.

    Pourquoi UNLOGGED ?
    - LOGGED BATCH écrit d'abord dans un batchlog pour garantir l'atomicité.
      C'est utile pour les transactions multi-partitions critiques, mais ici
      on ingère des séries temporelles : perdre quelques mesures n'est pas
      dramatique, et on veut maximiser le débit.
    - UNLOGGED BATCH est beaucoup plus rapide car il évite l'écriture du log.
    - On reste sous 50 lignes par batch pour ne pas surcharger le coordinateur.

    Les alertes sont insérées séparément dans alertes_par_wilaya pour
    respecter la dénormalisation Cassandra (une table = une requête).
    """
    # On découpe en sous-batches de BATCH_SIZE pour rester dans les clous
    for i in range(0, len(mesures), BATCH_SIZE):
        chunk = mesures[i : i + BATCH_SIZE]

        batch_mesures = BatchStatement(batch_type=BatchType.UNLOGGED)
        batch_alertes = BatchStatement(batch_type=BatchType.UNLOGGED)
        has_alertes = False

        for m in chunk:
            batch_mesures.add(stmt_mesure, (
                m["capteur_id"],
                m["date_jour"],
                m["timestamp"],
                m["wilaya"],
                m["commune"],
                m["tension_v"],
                m["courant_a"],
                m["puissance_kw"],
                m["frequence_hz"],
                m["temperature"],
                m["alerte"],
                m["code_alerte"],
            ))

            # Si c'est une alerte, on dénormalise dans la table dédiée
            if m["alerte"]:
                has_alertes = True
                # Gravité déterminée par le code d'alerte
                gravite = 3 if "TENSION" in (m["code_alerte"] or "") else 1
                description = f"Capteur {m['capteur_id']} - {m['code_alerte']} à {m['timestamp']}"
                batch_alertes.add(stmt_alerte, (
                    m["wilaya"],
                    m["date_jour"],
                    m["timestamp"],
                    m["capteur_id"],
                    m["code_alerte"],
                    description,
                    gravite,
                    False,  # non résolue par défaut
                ))

        session.execute(batch_mesures)
        if has_alertes:
            session.execute(batch_alertes)


def run_ingestion(session):
    """
    Génère et insère NB_CAPTEURS × MINUTES_HISTORIQUE mesures.

    Déroulement :
    1. On génère les 10 000 capteurs avec leur affectation wilaya/commune.
    2. Pour chaque minute des 5 dernières minutes, on insère les mesures
       de tous les capteurs en batches.
    3. On affiche le bilan : total d'insertions, durée, débit.
    """
    print(f"Démarrage ingestion : {NB_CAPTEURS:,} capteurs x {MINUTES_HISTORIQUE} min")
    print(f"Soit {NB_CAPTEURS * MINUTES_HISTORIQUE:,} mesures à insérer...\n")

    stmt_mesure, stmt_alerte = prepare_statements(session)

    # Génération des capteurs une seule fois (ID stable sur toute la durée)
    print("Génération des capteurs...")
    capteurs = []
    for _ in range(NB_CAPTEURS):
        wilaya = random.choice(WILAYAS)
        commune = random.choice(COMMUNES[wilaya])
        capteurs.append({
            "id": uuid.uuid4(),
            "wilaya": wilaya,
            "commune": commune,
        })

    # On part du moment présent et on remonte dans le temps
    now = datetime.now()
    timestamps = [now - timedelta(minutes=m) for m in range(MINUTES_HISTORIQUE)]

    start = time.time()
    total_insere = 0
    total_alertes = 0

    for t_idx, ts in enumerate(timestamps, 1):
        print(f"  Minute {t_idx}/{MINUTES_HISTORIQUE} - {ts.strftime('%H:%M:%S')}...")

        # On génère toutes les mesures pour cette minute
        mesures_minute = []
        for cap in capteurs:
            m = generate_mesure(cap["id"], cap["wilaya"], cap["commune"], ts)
            mesures_minute.append(m)
            if m["alerte"]:
                total_alertes += 1

        # On insère en batches de BATCH_SIZE
        insert_batch(session, mesures_minute, stmt_mesure, stmt_alerte)
        total_insere += len(mesures_minute)

    elapsed = time.time() - start
    debit = total_insere / elapsed

    print(f"\nRésultat de l'ingestion :")
    print(f"  Total mesures insérées : {total_insere:,}")
    print(f"  Dont alertes           : {total_alertes:,} ({total_alertes/total_insere*100:.1f}%)")
    print(f"  Durée totale           : {elapsed:.1f}s")
    print(f"  Débit                  : {debit:,.0f} mesures/seconde")

    return total_insere, elapsed


if __name__ == "__main__":
    session, cluster = connect()
    try:
        run_ingestion(session)
    finally:
        cluster.shutdown()
        print("\nConnexion Cassandra fermée proprement.")
