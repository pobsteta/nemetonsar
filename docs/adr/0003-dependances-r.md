# ADR 0003 — Dépendances R pour lire et écrire les données géographiques

- **Date :** 2026-11-22
- **Statut :** acceptée le 2026-11-22 par l'orchestrateur, par délégation de Pascal (« tout »), après critique du `contradicteur`
- **Proposée par :** Claude (orchestrateur)
- **Tranchée par :** Pascal, ou l'orchestrateur par délégation (« tout », 2026-11-22)

## La décision en une phrase

Le cœur de la détection reste en base R sur des tableaux (missions 003 à 007) ; la
lecture et l'écriture des rasters **et des vecteurs** passent par `terra` seul
(`SpatRaster`, `SpatVector`), en **Imports** ; l'accès aux catalogues d'images par
`rstac`, en **Suggests**. Le calcul se fait **par tuile de la grille de sortie, dans
son système UTM, et par blocs** de lignes avec une bordure, pour tenir en mémoire.

*Amendée après la critique du `contradicteur` (2026-11-22) : `sf` retiré (option 3),
mémoire et systèmes de coordonnées ajoutés.*

## Contexte

La v1 doit lire une AOI vectorielle, des rasters Sentinel-1 corrigés (ADR 0001), le
TCD 2018 et les surfaces brûlées EFFIS, et écrire des GeoTIFF (dates `YYDDD`, ratio
en dB) et un GeoPackage (spec, « Sorties attendues »). Base R ne lit aucun de ces
formats. Le brief nomme `terra`, `sf`, `stars`, `gdalcubes`, `rstac`, `targets`.

Options envisagées :

| Option | Principe |
|---|---|
| 1 | `terra` + `sf` en Imports, `rstac` en Suggests |
| 2 | `stars` + `sf` (+ `gdalcubes` pour les cubes) |
| 3 | Tout dans `terra` (vecteurs compris, `SpatVector`), `rstac` en Suggests (retenue) |
| 4 | Ajouter `targets` dès maintenant pour le cache et l'incrémental |

## Mémoire et systèmes de coordonnées

- **Mémoire.** Le cœur travaille sur des tableaux pixels × dates : pour un département
  (de l'ordre de 57 millions de pixels à 10 m et de 300 dates par orbite, calcul du
  `contradicteur`, non sourcé), une seule matrice dépasserait 100 Go. Le pipeline lit
  donc par blocs de lignes (`terra::readValues()`, `writeValues()`) avec une bordure
  égale au plus grand rayon des opérations spatiales (fenêtre du filtre, fermeture,
  connexité), et assemble ; les objets coupés par une limite de bloc sont réétiquetés
  après assemblage. Critère : pic de mémoire mesuré sur une tuile pilote.
- **Systèmes de coordonnées.** La France métropolitaine couvre les zones UTM 30, 31 et
  32. Le calcul se fait par tuile de la grille de sortie (MGRS 10 m, comme les fichiers
  publiés ; système UTM de la tuile), les images sont rééchantillonnées sur cette
  grille, et une AOI à cheval sur deux zones donne plusieurs tuiles, assemblées en
  sortie dans un système unique (Lambert-93, EPSG:2154, provisoire). Un test porte
  sur une AOI à cheval sur deux zones UTM.

## Licences

| Paquet | Version | Licence | Date | Rôle |
|---|---|---|---|---|
| `terra` | 1.9-60 | GPL (≥ 3) | 2026-11-20 | Imports |
| `rstac` | 1.0.1 | MIT | 2024-07-18 | Suggests (peu actif : repli documenté par jeton SAS et `/vsicurl/` de GDAL) |
| `sf` | 1.1-3 | GPL-2 \| MIT | 2026-09-11 | non retenu |

Sources : pages CRAN des paquets, relevées par le `contradicteur` le 2026-11-22.
Toutes compatibles avec la GPL-3 du package.

## Le crible FRANCE

| Lettre | Question | Réponse (une ligne) | Ce que ça coûte | Prêts à payer ? |
|---|---|---|---|---|
| **F**rugale | La plus simple qui tienne ? | Un seul paquet en Imports, un optionnel ; le cœur reste en base R | GDAL, GEOS, PROJ à installer (déjà requis par toute chaîne SIG) | Oui |
| **R**esponsable | Qui fait quoi ? | `terra` lit/écrit rasters et vecteurs ; nos fonctions convertissent en tableaux, par blocs | Une conversion et un découpage par blocs à tester | Oui |
| **A**nticiper | Si l'imprévu arrive ? | `terra` et `sf` sont maintenus par des communautés larges (r-spatial, rspatial) ; le cœur ne dépend d'aucun des deux et peut changer de lecteur | Dépendance à GDAL | Oui |
| **N**ovateur | Toutes les idées ? | `stars`/`gdalcubes` gardés pour plus tard si les cubes temporels pèsent ; `targets` reporté à la mission incrémentale | — | Oui |
| **C**oût | Coût complet ? | inconnu (temps d'installation en CI, à mesurer) | CI plus longue | Oui |
| **É**cologique | Que réutilise-t-on ? | GDAL et l'écosystème r-spatial ; formats ouverts (GeoTIFF, GeoPackage) | — | Oui |

Questions « Choisir » (fiche n° 11) pour `terra` : format ouvert, oui ; code
corrigeable par d'autres, oui (GPL ≥ 3) ; fonctionne d'un poste à l'autre, oui ;
communauté, oui. Pour `rstac` : oui, oui, oui, communauté faible (dernière version
2024) : d'où Suggests et un repli écrit.

## Valeurs sacrifiées

La frugalité pure (base R seule) : on accepte GDAL, GEOS et PROJ pour lire et écrire les
formats ouverts exigés par la spec. `targets` (option 4) est reporté : l'incrémental
se fera d'abord sans lui, et une ADR le reprendra si le cache maison ne tient pas.

## Sources

- `terra` : https://cran.r-project.org/package=terra
- `sf` (non retenu) : https://cran.r-project.org/package=sf
- `rstac`, signature Planetary Computer : https://cran.r-project.org/web/packages/rstac/refman/rstac.html
- `rstac` : https://cran.r-project.org/package=rstac
- Brief, « Architecture technique » ; spec, « Sorties attendues » ; ADR 0001.

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?
