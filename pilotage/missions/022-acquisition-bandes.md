# Mission 022 — Acquisition par bandes à disque borné

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 9), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Faire lire les images par bandes de la tuile (hauteur alignée sur les tuiles internes des COG, 512 lignes par défaut), avec téléchargements en parallèle et reprojection multi-fil, sans garder les images d'une exécution à l'autre, pour ramener le disque d'environ 488 Go à environ 23 Go par tuile et réduire le temps d'acquisition, selon la décision de Pascal.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : `docs/analyses/lecture-parallele.md` (causes 1 et 2, bandes de 512 lignes, DEFLATE + prédicteur, `project(threads = TRUE)`), relecture 019 (bandes non alignées : surcoût possible jusqu'à × 2 à chiffrer) | |
| A-t-il les moyens ? | oui : R, `parallel` (base R), terra, réseau vers le Planetary Computer | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/s1.R`, `R/run.R`, `tests/testthat/test-s1.R`, `tests/testthat/test-run.R`. `NAMESPACE` et `man/` par l'orchestrateur. Les missions 021 et 022 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** changer un résultat (identité au bit près) ; affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle ; toucher `R/detecter.R` (mission 021) ; garder des images entre deux exécutions.

## Valeur provisoire (chiffre, réglage)

hauteur de bande 512 lignes, nombre de flux de téléchargement 4, compression DEFLATE + prédicteur 3 : provisoires, à mesurer.

## Dépend de / rouge attendu jusqu'à

Dépend de : 019 (terminée), ADR 0004 (tranchée). CI rouge attendue : aucune.

## Tests

Résultats de `nemetonsar_run()` identiques au bit près avec et sans bandes (cas synthétiques injectés) ; disque maximal mesuré par bande ; nettoyage des fichiers de bande ; un test réseau (sous `NEMETONSAR_TESTS_RESEAU`) sur l'AOI des Landes qui compare bandes et lecture d'un seul tenant ; mesure du surcoût de téléchargement des bandes non alignées.

## Terrain

Le temps et le disque d'une exécution sur l'AOI des Landes, avant et après.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
