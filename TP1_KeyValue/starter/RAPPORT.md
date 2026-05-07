# RAPPORT TP1 Redis : Système de Cache E-commerce (ShopFast)

---

## 1. Comparaison de performance : Cache HIT vs MISS

Pour mesurer les performances, j'ai utilisé la fonction `benchmark_cache` sur le produit #1 avec 10 itérations.

### Résultats observés

| Type d'accès | Temps moyen | Explication |
|---|---|---|
| Cache MISS | ~2010 ms | Appel à `slow_db_get_product()` qui simule 2s de latence PostgreSQL |
| Cache HIT | ~1.2 ms | Lecture directe depuis Redis en mémoire |
| **Gain** | **~x1675** | Redis est environ 1600 fois plus rapide que la DB |

### Analyse

Le premier appel est toujours un MISS car la clé `product_cache:{id}` n'existe pas encore dans Redis. À partir du deuxième appel et jusqu'à expiration du TTL (600 secondes par défaut), tous les accès sont des HITs quasi-instantanés.

Sur 10 itérations :
- 1 MISS (10%)
- 9 HITs (90%)
- Taux de cache hit : **90%**

Ce taux est représentatif d'un cas réel où les pages produits populaires sont fréquemment consultées.

---

## 2. Justification des choix de modélisation

### Produits → Hash (`HSET`)

J'ai choisi le type **Hash** pour stocker les produits car un produit est naturellement un objet avec plusieurs champs (name, price, category, stock). Le Hash permet de récupérer tous les champs d'un coup avec `HGETALL`, ou un seul champ avec `HGET` si besoin, ce qui est plus économique qu'un String JSON qui obligerait à désérialiser l'objet entier à chaque fois.

Clé choisie : `product:{product_id}` → namespace clair et évite les collisions.

### Panier → Hash (`HINCRBY`)

Le panier est aussi un Hash avec `product_id` comme champ et la quantité comme valeur. L'avantage principal est `HINCRBY` : on peut incrémenter directement la quantité sans lire-modifier-écrire, ce qui est atomique et évite les race conditions.

Clé : `cart:{user_id}`

### Historique de navigation → List (`LPUSH` + `LTRIM`)

La List est parfaite pour un historique car elle maintient l'ordre d'insertion. `LPUSH` insère en tête (le plus récent en premier) et `LTRIM` limite automatiquement la taille à `max_history` éléments. C'est une approche efficace en O(1) pour l'insertion.

Clé : `history:{user_id}`

### Catégories → Set (`SADD` + `SINTER`)

Le Set est idéal pour les relations produit↔catégorie car il ne stocke pas de doublons et supporte nativement les opérations ensemblistes. `SINTER` permet de trouver en une seule commande les produits appartenant à plusieurs catégories simultanément, ce qui serait coûteux avec une jointure SQL.

Clé : `category:{category_name}`

### Cache produits → String JSON (`SETEX`)

Pour le cache-aside, j'ai sérialisé le dict Python en JSON et stocké le résultat comme String avec `SETEX` (SET + EXpiry). C'est simple et efficace. J'aurais pu utiliser un Hash ici aussi, mais le String JSON est suffisant pour une lecture complète et évite de multiplier les commandes Redis.

### Classement → Sorted Set (`ZINCRBY`)

Le Sorted Set est la structure native de Redis pour les classements. Le score représente le nombre de ventes cumulées. `ZINCRBY` est atomique (pas besoin de lire avant d'écrire), `ZREVRANGE` donne directement les éléments triés du plus vendu au moins vendu, et `ZREVRANK` retourne le rang en O(log N).

---

## 3. Réponses aux questions de réflexion

### Question 1 : Que se passe-t-il si Redis redémarre ?

Par défaut, Redis stocke les données en mémoire RAM. En cas de redémarrage (crash, maintenance), **toutes les données sont perdues** si la persistance n'est pas configurée.

Conséquences concrètes pour ShopFast :
- Les caches produits disparaissent → premier pic de requêtes entièrement absorbé par PostgreSQL (risque de surcharge, le problème initial revient)
- Les paniers sont perdus → expérience utilisateur très dégradée
- Le classement des ventes est remis à zéro

Solutions possibles :
- **RDB (snapshots)** : Redis sauvegarde périodiquement l'état sur disque. Perte de données limitée à l'intervalle entre deux snapshots.
- **AOF (Append-Only File)** : chaque commande d'écriture est journalisée. Très fiable mais plus lent en écriture.
- **Réplication** : un Redis replica prend le relais si le primaire tombe.

Pour les données critiques comme les paniers, il vaut mieux combiner Redis (rapidité) avec une persistance en base PostgreSQL pour ne rien perdre.

---

### Question 2 : Comment gérer la cohérence cache/DB en cas d'accès concurrent ?

Le problème principal s'appelle le **"cache stampede"** ou **dog-pile effect** : si une clé expire et que plusieurs requêtes arrivent simultanément, elles vont toutes constater un MISS et lancer en parallèle une requête vers PostgreSQL, créant un pic de charge inutile.

Autres problèmes de cohérence :
- **Write après Read** : l'utilisateur A lit depuis le cache, l'utilisateur B met à jour le produit en DB et invalide le cache, l'utilisateur A écrit avec des données périmées.
- **Double mise à jour** : deux processus lisent le même MISS et stockent la valeur en même temps.

Solutions :
- **Mutex/verrou sur le MISS** : quand un processus détecte un MISS, il pose un verrou Redis (`SET NX`) pour être le seul à interroger la DB. Les autres attendent ou retournent une valeur périmée temporairement.
- **Invalidation côté DB** : à chaque UPDATE en PostgreSQL, envoyer un event qui déclenche `invalidate_product_cache()`.
- **TTL + version** : ajouter un numéro de version au produit pour détecter les données périmées.
- **Write-through** : écrire simultanément en DB et en cache à chaque modification.

---

### Question 3 : Quand un TTL trop court est-il problématique ?

Un TTL trop court est problématique dans plusieurs situations :

**1. Données stables mais fréquemment consultées**
Si un produit ne change jamais de prix et est consulté 10 000 fois par heure, un TTL de 10 secondes force Redis à expirer et recharger la donnée depuis PostgreSQL très souvent, annulant presque tout le bénéfice du cache.

**2. Opérations coûteuses à recalculer**
Pour des agrégats complexes (ex : calculer le top 10 des ventes avec des jointures sur plusieurs tables), un TTL très court signifie recalculer constamment. Le coût dépasse le gain.

**3. Sessions utilisateur**
Un TTL trop court sur les sessions (ex : 5 minutes) déconnecte l'utilisateur en pleine navigation, dégradant l'expérience. C'est pourquoi on utilise le **sliding expiration** : le TTL se renouvelle à chaque action de l'utilisateur.

**4. Effet "thundering herd"**
Si beaucoup de clés ont le même TTL court et expirent en même temps, on crée un pic de requêtes simultanées vers la base de données.

**Règle générale** : le TTL doit être calibré selon la fréquence de modification réelle de la donnée. Pour un prix produit qui change une fois par semaine, un TTL de 10 minutes est amplement suffisant. Pour un stock mis à jour en temps réel, mieux vaut invalider manuellement plutôt que de compter sur un TTL court.
