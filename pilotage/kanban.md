# Kanban de nemetonsar

> Cinq colonnes (fiche n° 8). Chaque carte porte l'Homme (qui), la Mission (quoi, quand,
> combien) et les Moyens (comment, où, avec qui), et renvoie à sa fiche dans
> `pilotage/missions/`. Elle note aussi depuis quel cycle de `/boucle` elle est dans sa
> colonne ; on change ce numéro chaque fois qu'elle change de colonne.
> **Une carte qui ne bouge pas est souvent la mauvaise nouvelle à dire tout de suite.**

**Dernier cycle :** 3 _(augmenté de 1 à la fin de chaque `/boucle`, même quand elle n'a
rien lancé. Une carte est immobile quand dernier cycle − N ≥ 2.)_

_Modèle de carte :_

```
- [NNN-titre](missions/NNN-titre.md) · depuis le cycle N
  - Homme : qui
  - Mission : quoi, quand, combien
  - Moyens : comment, où, avec qui
```

## Bac à sable


## Validé

## Planifié


## Terminé

- [008-precision-date](missions/008-precision-date.md) · depuis le cycle 3
  - Homme : `analyste` (opus)
  - Mission : précision de la date sur séries simulées
  - Moyens : voir la fiche
- [009-chaine-raster-blocs](missions/009-chaine-raster-blocs.md) · depuis le cycle 3
  - Homme : `dev` (opus)
  - Mission : chaîne sur rasters par blocs, GeoTIFF et GeoPackage
  - Moyens : voir la fiche
- [010-datation-xb](missions/010-datation-xb.md) · depuis le cycle 3
  - Homme : `dev` (opus)
  - Mission : datation à Xb fini (`xb_date`)
  - Moyens : voir la fiche
- [006-postprocess](missions/006-postprocess.md) · depuis le cycle 2
  - Homme : `dev` (opus)
  - Mission : objets < 0,1 ha retirés, fermeture, table des objets
  - Moyens : table 001, testthat
- [007-filtre-quegan](missions/007-filtre-quegan.md) · depuis le cycle 2
  - Homme : `dev` (opus)
  - Mission : filtre multitemporel de Quegan et Yu, noyau sur annee_noyau
  - Moyens : arXiv:2207.11111, code CNES OTB, testthat
- [001-parametres-methode](missions/001-parametres-methode.md) · depuis le cycle 1
  - Homme : `acquereur`
  - Mission : table des paramètres sourcés, cycle 1
  - Moyens : article section II, Bouvet et al., web
- [002-licences-sources](missions/002-licences-sources.md) · depuis le cycle 1
  - Homme : `acquereur`
  - Mission : licence et attribution par source, cycle 1
  - Moyens : ADR 0002, pages des fournisseurs
- [003-parametres-et-db](missions/003-parametres-et-db.md) · depuis le cycle 1
  - Homme : `dev` (opus), plan d'abord
  - Mission : `parametres_sufosat()` et conversions dB, plan au cycle 1, code après 001
  - Moyens : spec, table 001, testthat
- [004-rcr-compute](missions/004-rcr-compute.md) · depuis le cycle 1
  - Homme : `dev` (opus)
  - Mission : ratio et date du minimum, sur tableau R, après 003
  - Moyens : séries synthétiques, testthat
- [005-rcr-segment](missions/005-rcr-segment.md) · depuis le cycle 1
  - Homme : `dev` (opus)
  - Mission : graines sous ts, croissance jusqu'à tp, après 004
  - Moyens : rasters synthétiques, testthat

## Abandonné

_Avec la raison, en une ligne._

## Livraisons

_Une ligne par cycle, ajoutée sous la précédente à la fin de chaque `/boucle`, et une
par `/bilan` : la livraison que Pascal a retenue, pour qui, et ce qu'elle apporte de plus
que la précédente du même rythme. On lance petit (fiche n° 12) : la plus petite version
qui rend déjà un service réel, un MVP, essayée tout de suite sur le terrain. Un cycle sans livraison neuve livre sa mauvaise
nouvelle, car
« une mauvaise nouvelle est une livraison sur laquelle on apprend » (Pascal) : on
l'inscrit avec ce qu'elle nous apprend._

```
- cycle N · livraison · pour qui · ce qu'elle apporte de plus que la précédente
- cycle N · mauvaise nouvelle : … · pour qui · ce qu'elle nous apprend
- bilan du AAAA-MM-JJ · livraison · pour qui · ce qu'elle apporte de plus que la précédente
- bilan du AAAA-MM-JJ · mauvaise nouvelle : … · pour qui · ce qu'elle nous apprend
```

- cycle 1 · le cœur de la détection testé sur données synthétiques : paramètres sourcés (`parametres_sufosat()`), ratio de changement radar et date du minimum (`rcr_compute()`, `rcr_combine_orbites()`), segmentation en deux seuils (`rcr_segment()`), plus les référentiels des paramètres et des licences · pour Pascal · première livraison : on peut voir, sur une série synthétique, une coupe datée et segmentée selon la méthode ; pas encore sur une vraie image
- cycle 2 · la chaîne de détection complète sur données synthétiques : filtre de Quegan et Yu (`s1_filter_multitemp()`), ratio, segmentation, post-traitement (`postprocess()`) et table des objets (surface, date, ratio) · pour Pascal · de plus que le cycle 1 : une série synthétique donne maintenant des objets de coupe filtrés, nettoyés et datés, et l'on sait que la date reste imprécise avec les réglages provisoires
- cycle 3 · la chaîne sur fichiers : `nemetonsar_detecter()` lit des rasters par blocs et écrit `dates.tif`, `ratio.tif`, `objets.tif` et `objets.gpkg` ; la date de coupe est calculée avec `xb_date = 5` (96 % de dates exactes en simulation contre 16 %) ; ADR 0003 (terra) acceptée · pour Pascal · de plus que le cycle 2 : des fichiers qui s'ouvrent dans QGIS, et une date fiable en simulation ; mauvaise nouvelle apprise : ≈ 10 h estimées par tuile en base R
