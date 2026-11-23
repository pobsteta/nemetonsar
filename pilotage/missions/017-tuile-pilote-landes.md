# Mission 017 — Tuile pilote des Landes et comparaison à la v3.0.1

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 10), lancée sur décision de Pascal (« Vas y »).

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `compare_reference()` (accord avec la carte SUFOSAT v3.0.1 : part de la surface publiée retrouvée, part recalculée absente, écart médian de date, métriques par objets au seuil de 75 %), lancer `nemetonsar_run()` sur une AOI pilote réelle des Landes avec le masque BD Forêt v2 sur 2018 – septembre 2025, et écrire le rapport de comparaison, pour tenir le critère « Accord avec la v3.0.1 » du brief et donner à Pascal les chiffres qui conditionnent la fusion de la PR #2.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : brief (« Validation »), spec (critères 3 et 4), licences (SUFOSAT CC BY-NC 4.0, rapport de comparaison séparé, ADR 0002), fonctions 003 à 022 | |
| A-t-il les moyens ? | sous condition : accès à la carte v3.0.1 (THEIA, doi:10.71961/M18T-KB92) à vérifier en première tâche ; réseau vers le Planetary Computer et la Géoplateforme ; 56 Go de disque libres, 4 cœurs, 15 Go de mémoire | si la v3.0.1 n'est pas accessible sans compte : s'arrêter et remonter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal pour toute cible chiffrée).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/comparer.R`, `tests/testthat/test-comparer.R`, `docs/analyses/pilote-landes.md`, `docs/analyses/pilote-landes.R`. `NAMESPACE` et `man/` par l'orchestrateur.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier les autres fichiers de `R/` (une limite se remonte) ; recopier la carte v3.0.1 dans le dépôt (licence NC : seulement le rapport de comparaison, séparé) ; fixer seul une cible d'accord (85 %, un mois : valeurs provisoires du brief, à confirmer par Pascal) ; chaînes R non ASCII.

## Valeur provisoire (chiffre, réglage)

AOI pilote : un carré d'environ 10 km × 10 km dans les Landes autour de −0,80 E 44,20 N, dans une seule tuile MGRS si possible (taille provisoire, à dire) ; période 2018-01-01 à 2025-09-30 ; cibles : 85 % de surface commune, écart de date médian inférieur à un mois (proposition du brief, provisoire).

## Dépend de / rouge attendu jusqu'à

Dépend de : 014 à 022 (terminées). CI rouge attendue : aucune.

## Tests

`compare_reference()` testée sur cartes synthétiques dont les accords sont connus (surfaces communes, objets retrouvés à 75 %, écart de date) ; `Date` en `expect_equal` ; test réseau éventuel sous `NEMETONSAR_TESTS_RESEAU`. Rapport reproductible (`pilote-landes.R`, chemins relatifs, graine), temps et disque mesurés, licences et attributions citées.

## Terrain

Les cartes recalculée et publiée superposées sur l'AOI pilote, à ouvrir dans QGIS, et trois coupes en désaccord à contrôler sur orthophoto.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (cibles, fusion de la PR).
