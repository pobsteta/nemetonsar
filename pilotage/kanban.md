# Kanban de nemetonsar

> Cinq colonnes (fiche n° 8). Chaque carte porte l'Homme (qui), la Mission (quoi, quand,
> combien) et les Moyens (comment, où, avec qui), et renvoie à sa fiche dans
> `pilotage/missions/`. Elle note aussi depuis quel cycle de `/boucle` elle est dans sa
> colonne ; on change ce numéro chaque fois qu'elle change de colonne.
> **Une carte qui ne bouge pas est souvent la mauvaise nouvelle à dire tout de suite.**

**Dernier cycle :** 10 _(augmenté de 1 à la fin de chaque `/boucle`, même quand elle n'a
rien lancé. Une carte est immobile quand dernier cycle − N ≥ 2.)_

_Modèle de carte :_

```
- [NNN-titre](missions/NNN-titre.md) · depuis le cycle N
  - Homme : qui
  - Mission : quoi, quand, combien
  - Moyens : comment, où, avec qui
```

## Bac à sable

- Masquer les adresses signées (sig=…) dans les messages de GDAL et de terra à la console · depuis le cycle 11 (relecture de 025)
- Retirer l'usage devenu inutile de rstac des scripts docs/analyses/ecarts-date-v301.R (ms_token) et lecture-parallele.R (sign_planetary_computer) · depuis le cycle 11 (relecture de 025)

## Validé


## Planifié

- [026-cause-dates-tardives](missions/026-cause-dates-tardives.md) · depuis le cycle 11 · lancée au cycle 11
  - Homme : `analyste` (opus)
  - Mission : observer la cause non établie des dates tardives (52 %)
  - Moyens : voir la fiche ; session locale (données sur le poste de Pascal)


## Terminé

- [025-jeton-sas](missions/025-jeton-sas.md) · depuis le cycle 11
  - Mission : jeton du Planetary Computer renouvelé pendant les lectures longues
- [017-tuile-pilote-landes](missions/017-tuile-pilote-landes.md) · depuis le cycle 10
  - Mission : tuile pilote des Landes et comparaison à la v3.0.1 ; cibles du brief non atteintes, décision reportée au jalon 2 (après 026)
- [024-ecarts-date-v301](missions/024-ecarts-date-v301.md) · depuis le cycle 10
  - Mission : d'où viennent les dates tardives par rapport à la v3.0.1 (analyste)
- [023-fork-gdal](missions/023-fork-gdal.md) · depuis le cycle 10
  - Mission : parallélisme sans blocage sous terra 1.9 ; `processus` dans `nemetonsar_run()`
- [019-mesure-lecture-parallele](missions/019-mesure-lecture-parallele.md) · depuis le cycle 9
  - Mission : mesure de la lecture réelle et du parallélisme (analyste)
- [020-masque-bdforet](missions/020-masque-bdforet.md) · depuis le cycle 9
  - Mission : masque forêt BD Forêt v2 de l'IGN
- [021-orbites-parallele](missions/021-orbites-parallele.md) · depuis le cycle 9
  - Mission : orbites en parallèle (ADR 0004, option 3)
- [022-acquisition-bandes](missions/022-acquisition-bandes.md) · depuis le cycle 9
  - Mission : acquisition par bandes à disque borné, reprojection exacte
- [018-suites-015](missions/018-suites-015.md) · depuis le cycle 7
  - Homme : `dev` (opus)
  - Mission : ratio en double, une copie des passes 2-3, sans GeoPackage brut
  - Moyens : voir la fiche
- [015-limite-tuiles](missions/015-limite-tuiles.md) · depuis le cycle 6
  - Homme : `dev` (opus)
  - Mission : graine et 0,1 ha jugés sur la carte assemblée
  - Moyens : voir la fiche
- [016-performance](missions/016-performance.md) · depuis le cycle 6
  - Homme : `dev` (opus)
  - Mission : passe 1 × 4 plus rapide, résultats identiques
  - Moyens : voir la fiche
- [014-nemetonsar-run](missions/014-nemetonsar-run.md) · depuis le cycle 5
  - Homme : `dev` (opus)
  - Mission : une commande unique, `nemetonsar_run()`
  - Moyens : voir la fiche
- [011-aoi](missions/011-aoi.md) · depuis le cycle 4
  - Homme : `dev` (opus)
  - Mission : AOI, validation et tuiles MGRS en UTM
  - Moyens : voir la fiche
- [012-masques](missions/012-masques.md) · depuis le cycle 4
  - Homme : `dev` (opus)
  - Mission : masques forêt (TCD) et feu (EFFIS)
  - Moyens : voir la fiche
- [013-recherche-s1](missions/013-recherche-s1.md) · depuis le cycle 4
  - Homme : `dev` (opus)
  - Mission : recherche et lecture Sentinel-1 RTC (Planetary Computer)
  - Moyens : voir la fiche
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
- cycle 4 · les entrées réelles : une AOI découpée en tuiles UTM (`aoi_preparer()`), les images Sentinel-1 RTC trouvées et lues depuis le Planetary Computer (`s1_rechercher()`, `s1_lire()`), les masques forêt et feu (`masque_foret()`, `masque_feu()`) · pour Pascal · de plus que le cycle 3 : les briques pour passer d'une AOI réelle à des piles d'images réelles ; pas encore enchaînées en une commande
- cycle 5 · une commande unique : `nemetonsar_run(aoi, date_debut, date_fin, dossier, tcd, effis)` de l'AOI aux sorties Lambert-93 et au journal d'exécution ; essai réel 2 km × 2 km dans les Landes, 123 images, 95 s, 1 objet de 0,97 ha au 2025-03-06 (sans masque forêt) · pour Pascal · de plus que le cycle 4 : le premier critère du brief est tenu sur une vraie AOI ; mauvaise nouvelle apprise : une coupe à la limite de deux tuiles peut être perdue
- cycle 6 · coupes à la limite des tuiles ni perdues ni gonflées (015) ; détection quatre fois plus rapide à résultats identiques, ≈ 7 h par tuile au lieu de ≈ 27 h extrapolées (016) · pour Pascal · de plus que le cycle 5 : une carte juste aux limites de tuiles, et un temps par tuile mesuré ; mauvaise nouvelle apprise : l'estimation de 10 h était trop basse, il faudrait du C pour descendre vers 2 h
- cycle 7 · chaîne exacte de bout en bout (ratio en double précision, une seule copie de la segmentation, plus de GeoPackage intermédiaire) ; ADR 0004 (noyau C) proposée et critiquée · pour Pascal · de plus que le cycle 6 : `nemetonsar_run()` rend exactement `nemetonsar_detecter()` sur une tuile ; décision du C renvoyée à une mesure de la lecture réelle et du parallélisme
- cycles 8 et 9 · masque forêt BD Forêt v2 (IGN, ouvert) ; mesure réelle : une tuile ≈ 49 h extrapolées, dont 85 % d'acquisition ; orbites en parallèle (passe 1 × 2,6) ; acquisition par bandes à disque borné (≈ 12 Go par bande extrapolés au lieu de ≈ 490 Go), reprojection exacte, identique au bit près à la lecture d'un seul tenant · pour Pascal · de plus que le cycle 7 : une chaîne qui tient sur le disque d'un poste et un masque forêt sans compte ; mauvaise nouvelle apprise : c'est le téléchargement, pas le calcul, qui fait la durée
- cycle 10 · la chaîne en parallèle sur le poste de Pascal (terra 1.9, GDAL 3.11) : pilote Landes 100 km² en 35 min au lieu de 52 en série, sans blocage, résultats identiques au bit près (023) ; premier diagnostic chiffré des écarts à la v3.0.1 (024, rapport NC) · pour Pascal · de plus que les cycles 8 et 9 : une exécution réelle et parallèle sur sa machine, plus seulement dans le cloud ; mauvaise nouvelle apprise : l'accord avec la v3.0.1 est faible, et la moitié des dates tardives reste sans cause établie
