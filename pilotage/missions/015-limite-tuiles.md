# Mission 015 — Coupes à la limite de deux tuiles

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 6), lancée sur demande de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Faire juger la graine et la surface minimale de 0,1 ha sur les objets assemblés en Lambert-93, et non tuile par tuile, et supprimer les pixels en double à la limite des tuiles, pour qu'une coupe à cheval sur deux tuiles ne soit ni perdue ni gonflée.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : écart 014 au journal, relecture 014, fonctions internes de `R/detecter.R` (réétiquetage par blocs) et `R/postprocess.R`, à appeler sans les modifier | |
| A-t-il les moyens ? | oui : tests synthétiques de 014 | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/run.R`, `tests/testthat/test-run.R`. `NAMESPACE` et `man/` par l'orchestrateur (roxygen). Les missions 015 et 016 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** casser ou affaiblir un test existant ; chaînes R non ASCII ; ajouter une dépendance (Rcpp compris : une ADR d'abord, à remonter) ; modifier `R/detecter.R`, `R/postprocess.R` ou `R/segment.R` (une limite se remonte).

## Valeur provisoire (chiffre, réglage)

règle d'attribution d'un pixel Lambert-93 à une seule tuile (par exemple : la tuile dont le morceau d'AOI, reprojeté, contient le centre du pixel), provisoire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 014 (terminée). CI rouge attendue : aucune.

## Tests

**Test d'abord**, rouge avant correction : une coupe de 0,14 ha coupée en deux parties de 0,07 ha par une limite de tuiles doit sortir comme un objet ; une coupe dont la seule graine est d'un côté doit sortir entière ; la surface d'une coupe à cheval égale sa surface vraie à un pixel près (resserrer le test large de 014) ; aucun pixel compté deux fois ; tous les tests de 014 restent verts. `Date` en `expect_equal`.

## Terrain

La coupe c1 du cas synthétique de 014 dans QGIS, avant et après.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
