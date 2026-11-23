# Mission 010 — Dater la coupe avec un Xb fini

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 3), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Ajouter le réglage `xb_date` (défaut 5, provisoire) et faire dater chaque pixel détecté par le minimum du ratio calculé avec `xb = xb_date`, la détection restant calculée avec `xb`, pour corriger l'imprécision de la date mesurée par la mission 008.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : `docs/analyses/precision-date.md`, décision 008 au journal, code de 003 et 004 | |
| A-t-il les moyens ? | oui : R, tests existants, script de 008 | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev` · **Modèle :** opus · **Pas demandé :** changer la détection (`ratio_min_db` à `xb`).

## Harnais

- **Peut (périmètre) :** `R/parametres.R`, `R/rcr.R`, `tests/testthat/test-parametres.R`, `tests/testthat/test-rcr.R`. `NAMESPACE` et `man/` par l'orchestrateur.
- **Ne doit pas (écrit) :** toucher `R/detecter.R` (mission 009 en cours) ; casser un test existant sans le dire ; chaînes non ASCII.

## Valeur provisoire (chiffre, réglage)

`xb_date = 5` (repli 10) : simulation de 008 ; mesure sur données réelles au jalon 2. `xb_date = Inf` rend le comportement d'avant.

## Dépend de / rouge attendu jusqu'à

Dépend de : 008 (terminée). Compatible avec 009 : nouveau réglage avec défaut, signatures inchangées. CI rouge attendue : aucune.

## Tests

- `rcr_compute()` rend `ratio_min_db` inchangé (à `xb`) et `date_min` / `date_avant` issues du minimum à `xb_date` ; avec `xb_date = Inf` les dates d'avant sont rendues à l'identique ; sur un cas tiré du script de 008 (graine fixée), la date exacte passe de la valeur à `xb = Inf` à celle à `xb = 5` ; `rcr_combine_orbites()` garde l'orbite au ratio de détection le plus bas ; validation de `xb_date` ; `Date` en `expect_equal`.

## Terrain

- Le cas simulé de 008 avant/après, en une ligne de chiffres.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.

## Comment saura-t-on que ça marche ?

Sur le cas simulé de 008 (fenêtre 3, −6 dB, 12 j), la date exacte dépasse 90 % sans changer les pixels détectés.
