# Tuile pilote des Landes — mission 017

Développeur, 2026-11-22. Script : [`pilote-landes.R`](pilote-landes.R), à lancer depuis
la racine du dépôt :

```
Rscript docs/analyses/pilote-landes.R <dossier> executer
Rscript docs/analyses/pilote-landes.R <dossier> resumer
Rscript docs/analyses/pilote-landes.R <dossier> comparer <dates_v301.tif>
```

`<dossier>` est hors du dépôt (le script le refuse dans le dépôt). Graine fixée,
chemins relatifs. Fonction de comparaison : `compare_reference()` (`R/comparer.R`).

**Ce rapport ne contient aucune donnée SUFOSAT v3.0.1** : la carte publiée n'a pas pu être
téléchargée (voir « Comparaison à la v3.0.1 : en attente de l'accès »). Il n'hérite donc
pas de la clause non commerciale (ADR 0002). Le rapport de comparaison, lui, sera un
fichier séparé, sous CC BY-NC 4.0.

## Ce qui a tourné

| Réglage | Valeur |
|---|---|
| AOI | carré de 10 km × 10 km en Lambert-93, de (391403 ; 6344861) à (401403 ; 6354861), soit 100,03 km² |
| Position | centré **2 km au sud** du point pilote (−0,80 E ; 44,20 N), qui reste dans l'AOI. Le carré centré sur le point coupait les tuiles 30TXP et 30TXQ ; décalé, il tient dans la **seule tuile MGRS 30TXP** (1 074 × 1 073 pixels UTM) |
| Période | 2018-01-01 au 2025-09-30 |
| Masque forêt | BD Forêt v2 de l'IGN, lue par le WFS de la Géoplateforme (`bdforet = "wfs"`) ; 8 329 ha de forêt dans l'AOI (83 %) |
| Paramètres | `parametres_sufosat()` par défaut : ts = −5,175 dB, tp = −3,45 dB (facteur 1,15), Xa = 3, VH, connexité 8, 0,1 ha, fermeture 3 × 3, noyau 2018, correction 2019 |
| Lecture | bandes de 512 lignes, 4 flux (défauts), reprojection exacte |
| Masques non appliqués | neige (reporté), feu (EFFIS non fourni) |
| Machine | 4 cœurs, 15 Go de mémoire, R 4.3.3, terra 1.7-65, GDAL 3.8.4 |

## Temps, disque, images

| Mesure | Valeur |
|---|---|
| Durée de `nemetonsar_run()` | **24,5 min** (1 468,7 s) |
| Images utilisées | **676** sur 3 orbites (A030 : 223 ; D008 : 227 ; D081 : 226), du 2018-01-06 au 2025-09-27, toutes de **S1A** ; 815 tranches |
| Orbites écartées | aucune |
| Bandes de lecture | 3 (512 + 512 + 49 lignes) |
| Trafic reçu (eth0) | **9,6 Go** (chaque bande relit les tuiles internes des COG qu'elle touche) |
| Disque des images d'une bande (`disque_images_mo`) | 1 238 Mo |
| Disque maximal de la tuile (`disque_max_mo`) | 1 266 Mo |
| Pic du dossier de sortie (échantillonné toutes les 20 s) | 1 199 Mo |
| Sorties finales | 10,7 Mo (rasters, GeoPackage, journal) |

À l'échelle d'une tuile MGRS entière (environ 105 fois plus de pixels), l'extrapolation
linéaire donne un ordre de 40 h. Ce n'est pas une mesure, et le débit du réseau de la
session domine.

## La carte recalculée

**170 objets, 1 105,55 ha**, soit 13,3 % de la forêt de l'AOI sur 6,5 ans de détections.
Les dates vont du 2019-02-19 au 2025-06-10.

| Année (date médiane de l'objet) | Objets | Surface (ha) | Surface médiane d'un objet (ha) |
|---|---:|---:|---:|
| 2018 | 0 | 0 | — |
| 2019 | 80 | 402,94 | 3,00 |
| 2020 | 10 | 61,61 | 4,75 |
| 2021 | 31 | 311,11 | 1,64 |
| 2022 | 15 | 87,73 | 2,58 |
| 2023 | 16 | 45,95 | 1,80 |
| 2024 | 11 | 161,63 | 5,69 |
| 2025 (au 30 septembre) | 7 | 34,58 | 5,27 |

Trois constats sont à lire avant toute comparaison :

1. **Aucune coupe datée de 2018.** Ce n'est pas une absence de coupes : c'est la règle
   provisoire de `rcr_compute()`, « aucun ratio avant le 1er janvier de `annee_noyau + 1` »,
   déduite de M24, § II-B.1. Les images de 2018 servent au noyau du filtre et à Mb.
   La v3.0.1 date pourtant des coupes de 2018 (codes `18xxx`). Sa surface de 2018
   sera donc **forcément non retrouvée**, ce qui fera baisser la part retrouvée.
2. **2019 porte 36 % de la surface** (403 ha sur 1 106), dont 118 ha sur la seule date du
   2019-03-27 (14 objets). Les coupes de fin 2018 pourraient être datées au début de 2019,
   première date de ratio. C'est une hypothèse à vérifier sur la v3.0.1.
3. **Quelques dates portent de grandes surfaces** : 149 ha au 2021-02-20 (6 objets),
   120 ha au 2021-03-28 (6 objets), 95 ha au 2024-11-06 (un seul objet). Ce peut être de
   vraies grandes coupes des Landes, ou une acquisition qui fait chuter le ratio sur de
   larges zones (sol gelé ou très humide, que le masque neige non appliqué ne retire pas).
   C'est à contrôler.

## Trois coupes détectées à contrôler sur orthophoto

La v3.0.1 manque pour choisir des coupes **en désaccord**. Faute de mieux, voici trois
coupes recalculées, choisies pour éprouver les trois constats ci-dessus. Le point donné
est le centre d'un pixel à l'intérieur de l'objet.

| Objet | Pourquoi | Surface | Date médiane | Lon, lat (WGS 84) | x, y (Lambert-93) |
|---|---|---:|---|---|---|
| 83 | le plus grand objet, sur une date qui porte 120 ha | 113,20 ha | 2021-03-28 | −0,82601 ; 44,18386 | 394240 ; 6350170 |
| 28 | le plus grand objet de 2019 (effet de début de série ?) | 38,95 ha | 2019-07-12 | −0,84728 ; 44,20767 | 392670 ; 6352895 |
| 137 | le plus récent | 6,94 ha | 2025-06-10 | −0,80367 ; 44,15792 | 395885 ; 6347205 |

À ouvrir dans QGIS : `<dossier>/sorties/objets.gpkg` (couche `objets`) et `dates.tif`,
sur l'orthophoto IGN (Géoplateforme). On compare l'orthophoto d'avant et d'après la date
médiane. Une fois l'extrait de la v3.0.1 obtenu, on le superpose, puis on relance l'étape
`comparer`, qui donne les trois coupes en désaccord (les deux plus grands objets publiés
non retrouvés, le plus grand objet recalculé absent de la référence).

## Comparaison à la v3.0.1 : en attente de l'accès

**Ce qui a été tenté (2026-11-22).**

- Page DOI (doi:10.71961/M18T-KB92 → https://doi.theia.data-terra.org/Sufosat/) :
  publique. Elle renvoie au service de diffusion CDS-MTD de THEIA.
- API STAC publique : https://api.datastore-mtd.theia.data-terra.org/collections/sufosat/items.
  Elle contient un seul item, `v3-0-1_20180101_20250901`, publié le 2025-11-24, avec
  deux COG nationaux :
  - dates : `https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/sufosat/forest-clearcuts_mainland-france_sufosat_dates_v3_set25.tif`
  - probabilité : `…/forest-clearcuts_mainland-france_sufosat_prob_v3_set25.tif`
- Format, lu dans le STAC sans télécharger :

  | Propriété | Valeur |
  |---|---|
  | Système | EPSG:2154 (Lambert-93) |
  | Pixel | 10 m |
  | Origine | x = 51639,69 ; y = 7150786,70 |
  | Taille | 126 813 colonnes × 119 159 lignes |
  | Codage | int16, nodata 0 |
  | Dates | `YYDDD`, YY de 18 à 25 (minimum annoncé : 17284) |
  | Probabilité | en %, de 85 à 100 |

- Téléchargement : **403 AccessDenied** du serveur S3 (StorageGRID, université de
  Montpellier), pour ces fichiers comme pour une autre collection du même bucket.
  Ni l'API ni le navigateur STAC ne proposent de signature ou d'authentification.
  On ne sait donc pas si c'est un filtrage par adresse ou une restriction. Rien n'a été
  contourné, et aucune autre diffusion officielle n'a été trouvée.

**Commande d'extraction, pour Pascal**, à lancer là où le lien répond (navigateur ou
poste de travail). On garde l'extrait **hors du dépôt** (CC BY-NC 4.0) :

```
gdal_translate -projwin 391403 6354861 401403 6344861 \
  /vsicurl/https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/sufosat/forest-clearcuts_mainland-france_sufosat_dates_v3_set25.tif \
  sufosat_v301_dates_aoi.tif
```

C'est un carré de 10 km de côté, de l'ordre de quelques centaines de Ko. Ensuite :
`Rscript docs/analyses/pilote-landes.R <dossier> comparer sufosat_v301_dates_aoi.tif`.
Si le lien échoue aussi chez Pascal, il faut demander l'accès à THEIA ou au CESBIO.

**Contrôle à blanc de la chaîne.** La carte recalculée a été reprojetée sur la grille exacte
de la v3.0.1 (même origine, int16, nodata 0 ; fichier du dossier de travail seulement),
puis comparée à elle-même par l'étape `comparer`. Résultats :

- Décalage des grilles : 0,31 m en x et 3,30 m en y, sous le demi-pixel. Le plus proche
  voisin ne perd donc **aucun** pixel daté : 100 % retrouvés, écart de date nul.
- **5,8 %** de la surface recalculée paraît « absente » : ce sont les 63,9 ha comblés par
  la fermeture, qui ont un objet mais pas de date dans `dates.tif`. Le contrôle à blanc
  ne les reprend pas. Sur la vraie comparaison, ces pixels compteront comme absents si la
  v3.0.1 ne date pas ses pixels comblés. On ne sait pas ce qu'elle fait.
- Objets : 185 côté « publié » contre 170 côté recalculé. Le retrait des pixels comblés
  coupe certains objets ; d'où une précision de 0,988 et un F1 de 0,994 sur cette
  comparaison à elle-même.

Ce contrôle borne ce que la grille et le codage coûtent à eux seuls. Il ne dit rien de
l'accord réel.

**Ce que rendra `compare_reference()`** (définitions, voir sa documentation) :

- au pixel : surfaces publiée, recalculée et commune ; part de la surface publiée
  retrouvée ; part de la surface recalculée absente de la référence ;
- dates : écart médian signé (recalculée moins publiée) et écart absolu médian, en jours,
  sur les pixels communs datés ;
- objets (règle des 75 %, strictement plus de 75 %) : rappel, précision, F1. Un objet
  publié est retrouvé si plus de 75 % de sa surface est détectée ; un objet recalculé est
  confirmé si plus de 75 % de sa surface est dans la référence. Les objets sont les
  composantes connexes (connexité 8) des pixels de chaque carte, gardés si leur date
  médiane tombe dans la période. **Écart au protocole de l'article** : celui-ci utilise
  des polygones photo-interprétés, avec des forêts intactes ; ici les deux cartes sont
  des détections, donc la précision porte sur les objets recalculés, et l'exactitude
  globale n'est pas calculable ;
- une ventilation par année.

Les cibles du brief (85 % de surface commune, écart de date médian inférieur à un mois)
restent **provisoires**. Le rapport de comparaison donnera les écarts, et Pascal tranche.

## Limites

- **Masque BD Forêt v2 au lieu du TCD 2018 de M24** (décision de Pascal du 2026-11-22,
  le TCD demande un compte CLMS). Les postes FF0 et FO0 (coupe rase, jeune peuplement)
  sont comptés forêt. Les deux masques diffèrent, et l'écart à la v3.0.1 en dépendra.
- **Pas de ratio en 2018** (voir plus haut) : la surface publiée de 2018 ne peut pas être
  retrouvée. Il faudra la lire à part, ou comparer sur 2019 – 2025.
- **Reprojection.** Les images sont reprojetées exactement sur la grille UTM de la tuile
  (`use_gdal = FALSE`, décision du 2026-11-22). La carte finale est assemblée en
  Lambert-93 au plus proche voisin. La v3.0.1 est sur une autre grille Lambert-93
  (origine décalée de 0,31 m et 3,30 m), ramenée au plus proche voisin : le contrôle à
  blanc montre que cela ne coûte rien ici.
- **S1A seul** (`capteurs_sufosat()`, M24). S1B (2018 – 2021) n'est pas utilisé. S1C et S1D
  ne sont pas utilisés avant le 2026-06-30 : leurs images de 2025 sont absentes. La v3
  n'en dit rien.
- **Masques neige et feu non appliqués.** Des chutes de ratio dues au sol gelé et des
  coupes après incendie peuvent rester dans la carte recalculée.
- **Les évolutions de la v3 ne sont pas documentées** (seuils par type de forêt, masque
  neige analytique, RCR ajusté : page DOI). Un accord parfait n'est pas attendu (brief,
  « Validation »).
- **Valeurs provisoires** utilisées ici : la taille et la position de l'AOI ; la règle
  d'assemblage de la correction 2019 ; la règle « pas de ratio avant `annee_noyau + 1` » ;
  la médiane basse ; la fermeture 3 × 3 ; les bandes de 512 lignes et les 4 flux ; dans
  `compare_reference()`, les objets par composantes connexes et la date médiane pour la
  période ; les cibles d'accord.
- **Une seule exécution, une AOI, une machine.** Temps et trafic dépendent du réseau de la
  session.

## Licences et attributions

Ce rapport et les sorties de l'exécution (rasters, GeoPackage, journal) cumulent :

- **[S1]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-1 RTC processed
  by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  codes TFV regroupés en forêt / non-forêt, rastérisés sur la grille de calcul.
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]**, cité comme source des métadonnées décrites (aucune donnée reproduite) :
  CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts in
  Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0.

Le rapport de comparaison, une fois la v3.0.1 obtenue, portera [S1] [FOR] [MET] [SUF] et la
mention « usage non commercial » (ADR 0002, `docs/referentiels/licences.md`).
