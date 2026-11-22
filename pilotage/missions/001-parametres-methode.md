# Mission 001 — Paramètres de la méthode, à la source

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22.

## Mission

**En une phrase (quoi, et pourquoi) :** Relever dans Mermoz et al. (2024), section II, et Bouvet et al. (2018), chaque paramètre de la méthode avec sa page, pour que le code n'utilise aucune valeur non sourcée.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : sources nommées au brief et au `CLAUDE.md` | |
| A-t-il les moyens ? | oui : accès web ; si l'article IEEE est payant, la version auteur (HAL) ou le résumé, et le dire | |

**Temps de la main :** donner : référentiel, pas de code ; l'agent travaille dans sa branche.

**Degré de la main :** le chef tranche (la justesse des données).

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `acquereur`
- **Modèle :** sonnet
- **Ce qui ne lui est pas demandé :** Pas de code, pas de licences (mission 002).

## Harnais

- **Peut (périmètre) :** `docs/referentiels/parametres-sufosat.md`
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul (hooks du plugin).
- **Ne doit pas (écrit) :** sortir du périmètre ; inventer une valeur ; écrire « SUFOSAT » pour une valeur qui vient de Bouvet ; recopier l'article au-delà des valeurs et de leur page.
- **Sources autorisées :** `docs/brief.md`, `docs/spec.md` (« Paramètres exposés »), l'article (doi:10.1109/JSTARS.2024.3429012), Bouvet et al. (doi:10.3390/rs10081250). Fermé : tout code.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

aucune : la mission mesure (relève) les valeurs ; un paramètre « non précisé » s'écrit ainsi.

## Dépend de / rouge attendu jusqu'à

aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Une table : paramètre, valeur, unité, source, page, et « non précisé » quand c'est le cas ; chaque défaut de la spec y figure ; la combinaison ascendante / descendante y est décrite ou dite « non précisée ». Liste de contrôle jointe.

## Terrain

- **Échantillon que Pascal vérifiera :** Pascal ouvre l'article à deux pages citées et vérifie la valeur.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal.

## Comment saura-t-on que ça marche ?

La mission 003 code ses défauts sans une seule valeur hors de la table.
