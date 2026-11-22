# ADR 0001 — Prétraitement Sentinel-1 : mesurer avant de choisir

- **Date :** 2026-11-22
- **Statut :** proposée
- **Proposée par :** Claude (orchestrateur), d'après le brief et la critique du `contradicteur`
- **Tranchée par :** Pascal

## La décision en une phrase

Le package R appelle le prétraitement par une interface unique (`s1_fetch()` rend des
rasters VH 10 m sur la grille MGRS, valeurs linéaires), avec S1Tiling en conteneur
(option A) comme référence, et ne retient une option plus légère (B, ou D si elle
existe) que si, sur la tuile pilote, son écart à A sur forêt stable est mesuré et
compensé.

## Contexte

R ne sait pas calibrer et orthorectifier des GRD Sentinel-1. Le brief propose trois
options ; le `contradicteur` en ajoute une quatrième, à vérifier.

| Option | Principe |
|---|---|
| A | S1Tiling (CNES, Apache 2.0) en conteneur Docker, appelé depuis R : prétraitement identique à l'article |
| B | Produits déjà corrigés du terrain lus par STAC (`rstac`, `gdalcubes`) : par exemple Sentinel-1 RTC du Planetary Computer |
| C | Google Earth Engine via `rgee` |
| D | Traitement côté Copernicus Data Space (openEO ou Sentinel Hub ; paquets CRAN `CDSE`, `CopernicusDataspace`) — à vérifier |

Décider maintenant, parce que les seuils en dB dépendent de la calibration ; décider
sans mesure, parce qu'on ne sait pas encore si l'écart entre A et B se recale.

## Le crible FRANCE

| Lettre | Question | Réponse (une ligne) | Ce que ça coûte | Prêts à payer ? |
|---|---|---|---|---|
| **F**rugale | La plus simple qui tienne ? | A est la plus lourde ; B la plus simple ; l'interface unique permet de changer | Docker et ~1 160 GRD par tuile pour A | Oui pour la tuile pilote ; à revoir après mesure |
| **R**esponsable | Qui fait quoi ? | A reproduit l'article : la justesse des seuils reste celle des auteurs | Pascal installe Docker | Oui |
| **A**nticiper | Si l'imprévu arrive ? | A dépend du CNES (libre), B de Microsoft, C de Google, D de l'ESA ; S1Tiling et 1C/1D à vérifier | Une option peut disparaître | Oui, grâce à l'interface unique |
| **N**ovateur | Toutes les idées ? | Quatre options, dont D ajoutée par le contradicteur | Une mesure en plus au jalon 0 | Oui |
| **C**oût | Coût complet ? | inconnu (stockage et calcul de A non mesurés) | — | À mesurer au jalon 0 |
| **É**cologique | Que réutilise-t-on ? | S1Tiling, la grille MGRS, les produits RTC existants | A rapatrie beaucoup de données | Oui pour la tuile pilote seulement |

## Valeurs sacrifiées

Frugalité et écologie, pour la tuile pilote : on accepte de télécharger et traiter des
GRD complètes pour avoir une référence fidèle à l'article. C (Google Earth Engine) est
écartée : elle sacrifie la règle « logiciels libres » du `CLAUDE.md`.

## Sources

- S1Tiling : https://github.com/CNES/S1Tiling
- Sentinel-1 RTC, Planetary Computer : https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-1-rtc
- CRAN `CDSE` : https://cran.r-project.org/web/packages/CDSE/index.html ;
  `CopernicusDataspace` : https://cran.r-project.org/web/packages/CopernicusDataspace/index.html
- Mermoz et al. (2024), section II : doi:10.1109/JSTARS.2024.3429012

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?
