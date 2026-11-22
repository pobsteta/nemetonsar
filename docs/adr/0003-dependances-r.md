# ADR 0003 — Dépendances R pour lire et écrire les données géographiques

- **Date :** 2026-11-22
- **Statut :** proposée
- **Proposée par :** Claude (orchestrateur)
- **Tranchée par :** Pascal, ou l'orchestrateur par délégation (« tout », 2026-11-22)

## La décision en une phrase

Le cœur de la détection reste en base R sur des tableaux (missions 003 à 007) ; la
lecture et l'écriture des données passent par `terra` (rasters) et `sf` (vecteurs,
AOI, polygones de sortie), en **Imports**, et l'accès aux catalogues d'images par
`rstac`, en **Suggests**, appelé seulement par les fonctions de recherche d'images.

## Contexte

La v1 doit lire une AOI vectorielle, des rasters Sentinel-1 corrigés (ADR 0001), le
TCD 2018 et les surfaces brûlées EFFIS, et écrire des GeoTIFF (dates `YYDDD`, ratio
en dB) et un GeoPackage (spec, « Sorties attendues »). Base R ne lit aucun de ces
formats. Le brief nomme `terra`, `sf`, `stars`, `gdalcubes`, `rstac`, `targets`.

Options envisagées :

| Option | Principe |
|---|---|
| 1 | `terra` + `sf` en Imports, `rstac` en Suggests (retenue) |
| 2 | `stars` + `sf` (+ `gdalcubes` pour les cubes) |
| 3 | Tout dans `terra` (vecteurs compris, `SpatVector`) |
| 4 | Ajouter `targets` dès maintenant pour le cache et l'incrémental |

## Le crible FRANCE

| Lettre | Question | Réponse (une ligne) | Ce que ça coûte | Prêts à payer ? |
|---|---|---|---|---|
| **F**rugale | La plus simple qui tienne ? | Deux paquets très répandus, un seul optionnel ; le cœur reste en base R | GDAL, GEOS, PROJ à installer (déjà requis par toute chaîne SIG) | Oui |
| **R**esponsable | Qui fait quoi ? | `terra` lit/écrit les rasters, `sf` les vecteurs ; nos fonctions convertissent en tableaux | Deux conversions à tester | Oui |
| **A**nticiper | Si l'imprévu arrive ? | `terra` et `sf` sont maintenus par des communautés larges (r-spatial, rspatial) ; le cœur ne dépend d'aucun des deux et peut changer de lecteur | Dépendance à GDAL | Oui |
| **N**ovateur | Toutes les idées ? | `stars`/`gdalcubes` gardés pour plus tard si les cubes temporels pèsent ; `targets` reporté à la mission incrémentale | — | Oui |
| **C**oût | Coût complet ? | inconnu (temps d'installation en CI, à mesurer) | CI plus longue | Oui |
| **É**cologique | Que réutilise-t-on ? | GDAL et l'écosystème r-spatial ; formats ouverts (GeoTIFF, GeoPackage) | — | Oui |

Questions « Choisir » (fiche n° 11) pour `terra` et `sf` : format ouvert, oui ; code
corrigeable par d'autres, oui (GPL-3 / GPL-2 ou MIT selon le paquet, sur CRAN et GitHub) ;
fonctionne d'un poste à l'autre, oui ; communauté, oui.

## Valeurs sacrifiées

La frugalité pure (base R seule) : on accepte GDAL, GEOS et PROJ pour lire et écrire les
formats ouverts exigés par la spec. `targets` (option 4) est reporté : l'incrémental
se fera d'abord sans lui, et une ADR le reprendra si le cache maison ne tient pas.

## Sources

- `terra` : https://cran.r-project.org/package=terra
- `sf` : https://cran.r-project.org/package=sf ; Pebesma (2018), R Journal 10(1), doi:10.32614/RJ-2018-009
- `rstac` : https://cran.r-project.org/package=rstac
- Brief, « Architecture technique » ; spec, « Sorties attendues » ; ADR 0001.

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?
