# Tuile pilote des Landes : comparaison à la carte SUFOSAT v3.0.1 — mission 017

> **Usage non commercial.** Ce rapport contient des valeurs tirées de la carte SUFOSAT
> v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il est séparé du rapport principal,
> [`pilote-landes.md`](pilote-landes.md), qui n'en contient aucune.

Orchestrateur, 2026-11-23, sur le poste de Pascal. Script : [`pilote-landes.R`](pilote-landes.R),
étapes `executer`, `resumer` puis `comparer`. Fonction : `compare_reference()` (`R/comparer.R`).
Définitions des mesures : voir le rapport principal, « Ce que rendra `compare_reference()` ».

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Référence | SUFOSAT v3.0.1, couche des dates (`forest-clearcuts_mainland-france_sufosat_dates_v3_set25.tif`), extraite sur l'AOI par `gdal_translate -projwin 391403 6354861 401403 6344861`. L'extrait reste hors du dépôt. |
| Accès | URL signée par le service de signature de THEIA (`signing.stac.teledetection.fr/sign_urls`, en-têtes `access-key` et `secret-key`, clés de Pascal), comme le fait la bibliothèque `teledetection` de THEIA. L'accès anonyme répond 403, depuis le cloud comme depuis le poste de Pascal. |
| Extrait | 1 001 × 1 001 pixels de 10 m, Lambert-93, int16, nodata 0 ; 10,3 % de pixels datés ; dates de 18114 à 25226 (YYDDD) |
| Carte recalculée | AOI, période et réglages du rapport principal, exécutés de nouveau sur le poste de Pascal |
| Machine | 8 cœurs, R 4.6.2, terra 1.9.60, GDAL 3.11.4 |
| Exécution | **en série** : le fork se bloque sous GDAL 3.11 (mission 023). Script copié hors dépôt, avec `flux = 1` et `fork_disponible()` forcé à `FALSE` ; package inchangé |
| Durée | 52 min (cloud, en parallèle : 24,5 min) ; 676 images ; disque maximal 1 266 Mo |
| Reproductibilité | **identique au cloud** : 170 objets, 1 105,55 ha, mêmes surfaces par année, mêmes trois coupes à contrôler |

## Résultats au pixel et par objet

| Mesure | Valeur |
|---|---|
| Surface publiée (v3.0.1) | 1 034,82 ha |
| Surface recalculée | 1 105,55 ha |
| Surface commune | 559,94 ha |
| Part de la surface publiée retrouvée | **54,1 %** |
| Part de la surface recalculée absente de la référence | **49,4 %** |
| Écart de date médian (recalculée − publiée), pixels communs | **+101 j** |
| Écart de date absolu médian | 192 j |
| Objets publiés / retrouvés (> 75 %) | 218 / 48 : rappel **0,22** |
| Objets recalculés / confirmés (> 75 %) | 170 / 57 : précision **0,34** |
| F1 | **0,27** |

Cibles provisoires du brief : 85 % de surface commune et un écart de date médian de moins
d'un mois. **Aucune n'est atteinte.**

## Par année

Les années de la v3.0.1 servent à la surface publiée, celles du recalcul à la surface recalculée.

| Année | Publiée (ha) | Retrouvée (ha) | Part retrouvée | Recalculée (ha) | Absente (ha) | Part absente | Écart de date médian (j) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 2018 | 143,24 | 30,90 | 22 % | 0,00 | 0,00 | — | 908 |
| 2019 | 216,43 | 110,50 | 51 % | 439,05 | 329,35 | 75 % | 12 |
| 2020 | 181,24 | 141,96 | 78 % | 71,45 | 26,07 | 36 % | 324 |
| 2021 | 222,43 | 95,13 | 43 % | 167,98 | 53,96 | 32 % | 37 |
| 2022 | 48,27 | 27,10 | 56 % | 103,34 | 29,09 | 28 % | 324 |
| 2023 | 96,48 | 59,96 | 62 % | 97,12 | 31,65 | 33 % | 296 |
| 2024 | 41,49 | 32,61 | 79 % | 45,20 | 12,72 | 28 % | 227 |
| 2025 | 85,24 | 61,78 | 72 % | 117,51 | 17,21 | 15 % | 0 |
| sans date | — | — | — | 63,90 | 45,56 | 71 % | — |

« Sans date » : les pixels comblés par la fermeture, qui ont un objet mais pas de date
(rapport principal, contrôle à blanc).

## Distribution des écarts de date

Pixels datés dans les deux cartes : 54 160. L'écart est la date recalculée moins la date publiée.

| Écart | Pixels | Part |
|---|---:|---:|
| ≤ −365 j | 1 609 | 3,0 % |
| −365 à −180 j | 493 | 0,9 % |
| −180 à −60 j | 1 743 | 3,2 % |
| −60 à −15 j | 1 859 | 3,4 % |
| **−15 à +15 j** | **14 293** | **26,4 %** |
| +15 à +60 j | 5 195 | 9,6 % |
| +60 à +180 j | 3 787 | 7,0 % |
| **+180 à +365 j** | **9 174** | **16,9 %** |
| **> +365 j** | **16 007** | **29,6 %** |

Quantiles : 5 % −108 j ; 25 % 0 j ; médiane +101 j ; 75 % +409 j ; 95 % +1 031 j.

**Lecture.** La distribution a deux modes. Un quart des pixels communs est daté à moins
de 15 jours de la v3.0.1 : là, la méthode reproduit la date publiée. Près de la moitié
(46,5 %) est datée **plus de 180 jours plus tard**. Seuls 3,9 % le sont plus de 180 jours
plus tôt. Le désaccord n'est donc pas un bruit symétrique : la chaîne date souvent un
événement **postérieur** à celui de la v3.0.1.

Deux hypothèses, **non vérifiées** :

1. **Règle de date.** La v3.0.1 garderait la première détection d'un pixel, la chaîne
   garde la date du minimum du ratio, qui peut tomber sur un second événement (dessouchage,
   travail du sol, replantation) des mois ou des années après la coupe.
2. **Début de série.** La chaîne ne calcule pas de ratio avant `annee_noyau + 1` (2019). Les
   coupes publiées en 2018 (143 ha, écart médian de 908 j) ressortent plus tard ou pas du
   tout ; une partie de la surface recalculée de 2019, absente à 75 % de la référence, en
   viendrait aussi.

## Trois coupes en désaccord à contrôler sur orthophoto

| Carte | Surface | x, y (Lambert-93) | Lon, lat (WGS 84) |
|---|---:|---|---|
| v3.0.1 seule | 50,42 ha | 398515 ; 6351715 | −0,77352 ; 44,19960 |
| v3.0.1 seule | 31,94 ha | 393185 ; 6352345 | −0,84051 ; 44,20295 |
| recalcul seul | 100,70 ha | 399055 ; 6351465 | −0,76662 ; 44,19758 |

## Limites

Celles du rapport principal (masque BD Forêt au lieu du TCD 2018, S1A seul, masques neige
et feu non appliqués, évolutions non documentées de la v3), plus :

- une seule AOI de 100 km², dans un massif de pin maritime à rotation courte, où les
  seconds passages (dessouchage, labour) sont fréquents ;
- les écarts de date par année portent sur peu de pixels pour 2022 et 2024 ;
- terra 1.9 signale `[rasterize] unexpected additional argument(s): datatype` ; sans effet
  visible ici (résultats identiques au cloud), à reprendre dans la mission 023.

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-1 RTC processed
  by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  codes TFV regroupés en forêt / non-forêt, rastérisés sur la grille de calcul.
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts
  in Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin
  sur la grille de la carte recalculée.
