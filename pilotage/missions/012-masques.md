# Mission 012 — Masques forêt et feu

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 4), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `masque_foret()` (TCD 2018 ≥ seuil, rééchantillonné sur la grille de la tuile, correction par les détections 2019) et `masque_feu()` (retrait des objets brûlés à au moins `seuil_feu` de leur surface selon des polygones EFFIS), pour appliquer les étapes 3 et 8 de la méthode.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : table 001 (M24 p. 13747-13748 : TCD 10 %, correction 2019, EFFIS 75 %), licences 002 | |
| A-t-il les moyens ? | oui : terra, rasters et polygones synthétiques | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/masques.R`, `tests/testthat/test-masques.R`. `NAMESPACE` et `man/` par l'orchestrateur (roxygen) ; les trois missions du cycle 4 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier les fonctions des missions précédentes ; chaînes R non ASCII ; inventer une valeur (ce qui n'est pas sourcé est provisoire) ; toucher `DESCRIPTION` ; télécharger des données.

## Valeur provisoire (chiffre, réglage)

règle de correction du masque forêt par les détections 2019 : **non précisée** par M24 (table 001) → provisoire, à écrire comme paramètre ; méthode de rééchantillonnage du TCD (plus proche voisin ou moyenne, provisoire) ; masque neige : hors mission (source MODIS en fin de vie, accès Earthdata avec identifiants : mission à part).

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 à 010 (terminées), ADR 0003. CI rouge attendue : aucune.

## Tests

seuil 10 % exact (9,9 exclu, 10 gardé, dire < ou ≥ selon la source) ; rééchantillonnage sur une grille 10 m d'un raster 20 m ; correction 2019 sur un cas connu ; objet brûlé à 75 % retiré, à 74 % gardé ; polygones dans un autre CRS reprojetés ; table des objets mise à jour. `Date` en `expect_equal` ; `skip_if_not_installed()` pour les paquets en Suggests ; aucun test qui exige le réseau sans `skip_if_offline()` et `skip_on_cran()`.

## Terrain

Une carte avant/après masque sur un cas synthétique.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
