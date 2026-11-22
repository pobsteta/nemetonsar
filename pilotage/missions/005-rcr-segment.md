# Mission 005 — Segmentation en deux seuils

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `rcr_segment()` : graines sous ts, croissance de région jusqu'à tp, sur le raster du ratio minimal en tableau R, pour reproduire l'étape 5 de la méthode.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : brief (étape 5), table 001 | |
| A-t-il les moyens ? | oui : rasters synthétiques | |

**Temps de la main :** donner.

**Degré de la main :** le chef tranche.

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `dev`
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** Pas de post-traitement (surface, fermeture).

## Harnais

- **Peut (périmètre) :** `R/segment.R`, `tests/testthat/test-segment.R`, `NAMESPACE`, `man/`
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul (hooks du plugin).
- **Ne doit pas (écrit) :** sortir du périmètre ; ajouter Rcpp ou une dépendance sans ADR ; changer la connexité sans la dire (4 ou 8 voisins : à écrire comme paramètre si l'article ne la précise pas).
- **Sources autorisées :** `docs/brief.md`, `docs/referentiels/parametres-sufosat.md`, `R/parametres.R`.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

connexité : provisoire si l'article ne la précise pas, jusqu'à la comparaison avec la v3 (jalon 2).

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 et 004 (périmètre commun : `NAMESPACE`, `man/`). Ordre : 003 → 004 → 005 ; part de `main` après la fusion de 004. CI rouge attendue : aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Zone sous tp touchant une graine → gardée ; zone sous tp sans graine → rejetée ; graine isolée → gardée ; seuils pris de `parametres_sufosat()`.

## Terrain

- **Échantillon que Pascal vérifiera :** Pascal regarde une image synthétique avant/après segmentation.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal.

## Comment saura-t-on que ça marche ?

Les cas synthétiques donnent exactement les zones attendues.
