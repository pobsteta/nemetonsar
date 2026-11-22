# Mission 016 — Performance de la passe 1

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 6), lancée sur demande de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Mesurer d'abord le temps et la mémoire de `nemetonsar_detecter()` sur une tuile représentative, puis réduire le temps de la passe 1 (filtre et ratio) et rendre linéaire le calcul de la date médiane des objets, sans changer un seul résultat, pour qu'une tuile se traite en un temps tenable sur un poste.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : relectures 009 et 007 (copies de tableaux, médiane quadratique dans `table_objets_blocs()`), écart 009 au journal (≈ 10 h estimées par tuile) | |
| A-t-il les moyens ? | oui : R, `bench` ou `system.time()` et `gc()`, rasters synthétiques | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/filtre.R`, `R/rcr.R`, `R/detecter.R`, `tests/testthat/test-filtre.R`, `tests/testthat/test-rcr.R`, `tests/testthat/test-detecter.R`, `docs/analyses/performance.md`, `docs/analyses/performance.R`. `NAMESPACE` et `man/` par l'orchestrateur (roxygen). Les missions 015 et 016 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** casser ou affaiblir un test existant ; chaînes R non ASCII ; ajouter une dépendance (Rcpp compris : une ADR d'abord, à remonter) ; modifier `R/run.R` (mission 015) ; changer un défaut de `parametres_sufosat()`.

## Valeur provisoire (chiffre, réglage)

« ≈ 10 h par tuile » : estimation à remplacer par une mesure en première tâche (sur une fraction de tuile, extrapolée et dite telle) ; taille de bloc par défaut à remesurer.

## Dépend de / rouge attendu jusqu'à

Dépend de : 014 (terminée). CI rouge attendue : aucune.

## Tests

Résultats **identiques au bit près** avant et après sur les cas existants (références naïves, identité blocs/tableau entier) ; un test de non-régression qui compare à des sorties figées avant optimisation ; un test diagonal entre bandes en connexité 8 (relecture 009) ; mesure avant/après dans `docs/analyses/performance.md` (temps, mémoire, extrapolation à une tuile MGRS × 300 dates × 3 orbites). `Date` en `expect_equal`.

## Terrain

Le tableau avant/après de `docs/analyses/performance.md`.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
