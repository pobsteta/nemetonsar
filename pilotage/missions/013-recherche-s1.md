# Mission 013 — Rechercher et lire les images Sentinel-1 corrigées

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 4), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `s1_rechercher()` (recherche STAC des images Sentinel-1 RTC sur l'emprise d'une tuile et une période, par orbite relative, avec signature des URL du Planetary Computer) et `s1_lire()` (lecture VH des images trouvées, rééchantillonnées sur la grille de la tuile, en piles par orbite), pour alimenter `nemetonsar_detecter()` avec des données réelles (option B de l'ADR 0001).

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : ADR 0001 et 0003, licences 002 (RTC CC BY 4.0), documentation `rstac` et Planetary Computer (collection `sentinel-1-rtc`) | |
| A-t-il les moyens ? | oui, sous condition : accès réseau au Planetary Computer depuis le conteneur, à vérifier en première tâche ; sinon tests sur réponses STAC enregistrées | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/s1.R`, `tests/testthat/test-s1.R`, `DESCRIPTION` (seulement `rstac` en Suggests). `NAMESPACE` et `man/` par l'orchestrateur (roxygen) ; les trois missions du cycle 4 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier les fonctions des missions précédentes ; chaînes R non ASCII ; inventer une valeur (ce qui n'est pas sourcé est provisoire) ; télécharger plus que la fenêtre d'essai ; écrire hors de `tempdir()` dans les tests.

## Valeur provisoire (chiffre, réglage)

aucune nouvelle ; la conversion des RTC (γ0 linéaire, déjà en puissance ?) est à vérifier à la source et à écrire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 à 010 (terminées), ADR 0003. CI rouge attendue : aucune.

## Tests

parsing d'une réponse STAC enregistrée (fixture JSON dans `tests/testthat/fixtures/`) : items filtrés par date, par capteur (S1A, S1C, S1D selon `capteurs`), regroupés par orbite relative, sans doublon de date ; un test réel (skip hors réseau) qui trouve au moins une image sur un point de France en 2025 et lit une petite fenêtre ; erreurs explicites si `rstac` manque ; attribution « Contains modified Copernicus Sentinel data » rendue avec les items. `Date` en `expect_equal` ; `skip_if_not_installed()` pour les paquets en Suggests ; aucun test qui exige le réseau sans `skip_if_offline()` et `skip_on_cran()`.

## Terrain

Une liste d'images pour un point du pays de Pascal, et une image lue.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
