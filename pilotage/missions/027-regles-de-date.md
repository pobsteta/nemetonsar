# Mission 027 — Essayer deux règles de date sur les séries relevées

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (fin du cycle 11), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Sur la tuile pilote des Landes, à partir des séries déjà relevées par la mission 026 et sans toucher au package, mesurer ce que donnent un seuil de datation distinct du seuil de détection (−3,0 dB), une date tirée de toutes les orbites, et les deux combinées, contre la v3.0.1 et contre le témoin des dates déjà retrouvées, pour que Pascal choisisse la règle à coder.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapports : `docs/analyses/ecarts-date-v301.md` (024) et `docs/analyses/cause-dates-tardives.md` (026), sous CC BY-NC 4.0 ; scripts voisins.
- Causes désignées par 026 : le seuil de datation égal au seuil de détection (classe « proche du seuil ») et l'orbite et la date tirées du minimum sur toute la série (classe « autre orbite »).
- Séries relevées, **sur le poste de Pascal seulement** : `/home/pascal/dev/nemetonsar-donnees/m026/series/` (30 blocs, 3 orbites), avec `pixels_026.rds` et `analyse_026.rds` ; extrait v3.0.1 et sorties du pilote dans `/home/pascal/dev/nemetonsar-donnees/`.

## Règles à essayer

1. **Seuil de datation distinct** : date = première date où le ratio de datation de l'orbite retenue passe sous −3,0 dB (sans le facteur 1,15), détection inchangée.
2. **Date multi-orbites** : date = première date où l'une quelconque des trois orbites passe sous le seuil de datation actuel, dans l'objet détecté.
3. **Les deux combinées.**

Pour chacune, sur les mêmes pixels : part des tardifs ramenés à 15 j au plus et à 60 j au plus, part des dates déjà retrouvées perdues, écart médian signé, et surface détectée inchangée (la vérifier).

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : scripts de 024 et 026, `rcr_compute()` pour le contrôle | |
| A-t-il les moyens ? | oui en session locale : séries relevées, R, terra ; aucune lecture Sentinel-1 nécessaire | hors du poste de Pascal : s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal choisit la règle).

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/regles-de-date.R` (script), `docs/analyses/regles-de-date.md` (rapport, **CC BY-NC 4.0**, mention « usage non commercial » en tête, attributions [S1] [FOR] [MET] [SUF]). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m027/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package ; mettre une donnée ou un extrait de la v3.0.1 au dépôt ; recopier des valeurs de la v3.0.1 au journal ; utiliser un objet interne de rstac ; changer un réglage par défaut (il propose, Pascal tranche). Toute base de mesure exclut les images qui ont servi à sélectionner les pixels (leçon de 026). Le rapport dit exactement ce qu'il contient.

## Valeur provisoire (chiffre, réglage)

−3,0 dB pour le seuil de datation distinct ; seuils de 15 j et 60 j repris de 024 ; provisoires.

## Dépend de / rouge attendu jusqu'à

Dépend de : 026 (terminée). Indépendante de 028 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument, graine) ; contrôle : la règle actuelle recalculée depuis les séries redonne la carte de 017 au pixel près ; chiffres recalculés par le relecteur ; quelques pixels tracés pour chaque règle.

## Terrain

Les pixels tracés par 024 et 026, sous chaque règle, sur orthophoto.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (règle de date).
