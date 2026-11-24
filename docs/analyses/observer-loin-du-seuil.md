# Ce que datent les pixels « loin du seuil » : Sentinel-2 et dates de vol des orthophotos — mission 028

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il contient des chiffres agrégés et, pour les pixels
> nommés (coordonnées L93 données pour le contrôle sur orthophoto et sur Sentinel-2), le
> **mois** de la date publiée par la v3.0.1 et une **classe** d'écart de cette date à une
> baisse du NDVI (« dans ±60 j », « plus de 2 mois avant ou après »), jamais l'écart exact : la
> date exacte de la v3.0.1 ne peut pas être refaite depuis ce rapport (vérifié par calcul, voir
> « Ce qui a tourné »). Il ne contient aucune autre valeur de pixel de la v3.0.1. Les dates de
> la carte recalculée (produite par ce projet) sont données en entier.

dev, 2026-11-24, sur le poste de Pascal (aller-retour 1/3 après relecture). Script :
[`observer-loin-du-seuil.R`](observer-loin-du-seuil.R) (étapes `tirer`, `vols`, `s2`,
`analyser`, `orthos`). Point de départ : [`cause-dates-tardives.md`](cause-dates-tardives.md)
(mission 026).

**Problème, en une phrase.** Sur 34 pixels dont 22 de la classe « loin du seuil » de 026 (rien
au signal Sentinel-1 à la date publiée), et sur l'objet FO0 daté par la seule carte
recalculée : que date chaque carte (la v3.0.1, notée **P**, et la carte recalculée, notée
**D**), la coupe des arbres ou un travail du sol, et à quelle date se produit-il ce que l'on
voit sur Sentinel-2 et sur les orthophotos ?

## En bref

1. **Dates de vol des orthophotos (réserve de 026 levée pour 2018 et 2021).** À chacun des
   379 pixels du lot (étude, témoins, FO0), l'ortho « 2018 » est du **2018-08-03** (373
   pixels) ou du **2018-08-02** (6) et l'ortho « 2021 » du **2021-08-31** (379). Aucun graphe de
   vol n'est publié pour l'ortho PAC 2020, l'Ortho Express 2024 et l'ortho PAC 2025 : leurs
   dates de vol sont **inconnues**.
2. **Ce que datent les cartes, sur 20 pixels « loin du seuil » tirés au hasard** (22 avec les
   deux pixels tracés de 026) : la **v3.0.1 date une baisse nette du NDVI à ±60 j dans 10 cas
   sur 20** (intervalle de Wilson à 95 % : 30 à 70 %), la **carte recalculée dans 1 cas sur 20**
   (1 à 24 %). Aucun des 22 pixels « loin du seuil » n'est confirmé pour les deux dates. La
   carte recalculée date **après** la v3.0.1 pour les 22 pixels (écart médian 18 mois), et dans
   12 cas sur 22 en février-mars. Ces comptes sont **inchangés** après la correction de la date
   des baisses (aller-retour 1/3).
3. **Ce que l'on voit au sol sur ces pixels** (lecture à l'œil du dev, à contrôler) :
   sur les 22 pixels « loin du seuil », **11 portaient des arbres en 2018 et n'en ont plus
   ensuite** (coupe), **8 étaient de l'herbe ou de la lande sans arbre au pixel en 2018, puis du
   sol travaillé en 2021** (travail du sol), et 3 sont autres (lisière, herbe puis plantation,
   coupe rase ancienne puis culture). La v3.0.1 date une baisse du NDVI dans 6 des 11 coupes et
   4 des 8 travaux du sol ; la carte recalculée, dans aucune coupe et un seul travail du sol.
4. **FO0.** L'objet daté par la seule carte recalculée (293 des 325 cellules FO0 de l'AOI ; 228
   sont datées d'août 2019) est, sur l'ortho du 2018-08-03, **une coupe rase déjà faite** (sol
   nu, rémanents), puis du sol travaillé en 2021, puis une jeune plantation en 2024. Le NDVI
   des cellules est à 0,35 en 2018, 2019 et 2020 (0,67 à 0,75 sous forêt témoin). **La date
   2019 de la carte recalculée ne date donc pas une coupe d'arbres** : il n'y avait plus d'arbres
   en août 2018.
5. **Les 14 pixels FF0 du lot** : aucun ne portait d'arbres sur l'ortho 2018 (12 sol travaillé,
   1 plantation, 1 conversion en culture). Les 15 pixels « arbres puis coupe » sont tous des
   postes FF2-51-51 (13), FF31 (1) ou FO2 (1).

Ce rapport **ne tranche pas** ce que la carte doit dater, ni FF0 et FO0 : c'est à Pascal (voir
« Ce que cela met sur la table »).

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Pixels | 34 pixels d'étude : **20 tirés au hasard** (graine 20261124, tri des `idx` avant tirage) parmi les 3 359 pixels `tardif_reste` de classe `loin_du_seuil_a_P`, plus les **14 pixels tracés** par 026 (dont 2 de la classe « loin du seuil » : 22 « loin du seuil » au total). 20 **témoins** : forêt BD Forêt (poste FF*, hors FF0) qu'aucune des deux cartes ne date (graine 20261125). **325 cellules FO0** de l'AOI (BD Forêt WFS, centre de cellule), dont 293 datées par la carte recalculée (un seul objet) et 0 par la v3.0.1 |
| Sentinel-2 | Sentinel-2 L2A du Planetary Computer (STAC `sentinel-2-l2a`), tuile **T30TXP** (l'AOI de 10 km est entièrement dedans). 693 items 2018-01-04 à 2025-09-29 sur l'emprise des points, **593 acquisitions** une fois écartés 100 retraitements de 2024 (même acquisition, ligne de base plus récente gardée), **451 scènes à 90 % de nuages ou moins** (seuil provisoire). Lecture de SCL, B04, B08, B11, en une fenêtre par bande, jeton SAS demandé par l'API publique (comme `s1_lire()`), 8 processus. Pixel Sentinel-2 contenant le centre du pixel de la carte. Les 3 x 3 pixels autour des 54 points d'étude et témoins sont aussi lus (colonne `marches_3x3` de `analyse_028.rds`) mais **ne sont pas exploités dans ce rapport** |
| Masque nuages | Classes SCL **4 (végétation) et 5 (sol non végétalisé)** seules ; tout le reste (ombres, nuages, cirrus, neige, eau, non classé) est écarté. Reste en moyenne **214 observations valides par pixel** (201 à 223) sur 7,7 ans, soit une tous les 13 jours en moyenne, avec de longs trous en hiver |
| Indice | **NDVI** = (B08 − B04) / (B08 + B04), réflectance de surface. **B04 et B08 sont corrigés du décalage de la ligne de base >= 04.00** (voir ci-dessous) |
| Décalage de réflectance | Les produits de ligne de base >= 04.00 (depuis 2022-01-25) portent un décalage de +1000 DN. Vérifié sur les données : B04 médian des témoins sous végétation, en hiver, **254 DN avant 04.00 contre 1 237 DN après**, plancher du B04 à **1 DN avant, 1 035 DN après**. Après correction (− 1000 DN, puis /10 000), la réflectance médiane est de 0,0255 avant et 0,0237 après |
| Dates de vol | WFS de la Géoplateforme, graphes de mosaïquage `ORTHOIMAGERY.ORTHOPHOTOS.GRAPHE.2016-2020:graphe_bdortho` et `…GRAPHE.2021-2023:graphe_bdortho`, champ `date_vol`. Intersection exacte du centre du pixel (et de la boîte de 10 m) avec les polygones, en EPSG:4326 (la couche 2016-2020 est servie en EPSG:3857) |
| Orthophotos | Vignettes de 300 m du WMS de la Géoplateforme (2018, 2020, 2021, 2024, 2025), pour lecture à l'œil. Hors dépôt |
| Durées | Lecture Sentinel-2 : environ 15 min de lecture utile en plusieurs lancements (reprise par fichier de scène ; deux premiers essais arrêtés pour lenteur : l'extraction point par point était environ 4 fois plus lente que la lecture d'une fenêtre). Analyse : environ 50 s |
| Contrôle de non-fuite de P | Calcul sur les 34 pixels : pour chacun, intervalle des dates de P compatibles avec ce que publie le rapport (le mois de P, et la classe d'écart appliquée à chaque baisse nette listée du pixel). **Largeur minimale de l'intervalle : 27 jours** (mois entier : 28 à 31 jours). Aucun écart exact en jours n'est publié pour P. Les lignes du rapport qui portent un écart en jours sont toutes relatives à D (carte produite par ce projet) |

## Question 2 : dates de vol des orthophotos

| Orthophoto (couche WMS) | Graphe de vol publié | Date de vol au pixel |
|---|---|---|
| 2018 (`ORTHOIMAGERY.ORTHOPHOTOS2018`) | oui, `…GRAPHE.2016-2020` | **2018-08-03** : 373 pixels sur 379 ; **2018-08-02** : 6 (32 des 34 pixels d'étude sont du 2018-08-03, 2 du 2018-08-02) ; FO0 : 325 sur 325 du 2018-08-03 |
| 2020 PAC (`…ORTHO-ASP_PAC2020`) | **non** | inconnue. **Sur les 35 pixels regardés, l'image est identique à celle de 2018** (même vue, mêmes arbres, pas de changement), comme en 024 : à ne pas lire comme un état de 2020 |
| 2021 (`ORTHOIMAGERY.ORTHOPHOTOS2021`) | oui, `…GRAPHE.2021-2023` | **2021-08-31** : 379 pixels sur 379 |
| Ortho Express 2024 | **non** | inconnue |
| PAC 2025 | **non** | inconnue |

Ce que cela change :
- **La réserve de 026 sur la date de vol de l'ortho 2021 est levée** : le 2021-08-31. Tout
  événement visible sur l'ortho 2021 est donc antérieur au 2021-08-31. Pour les pixels où
  l'événement est déjà visible à cette date (nature « arbres coupés » ou « sol travaillé »,
  voir plus bas : 22 pixels sur 34, dont 15 « loin du seuil »), toute date de carte postérieure
  au 2021-08-31 **ne peut pas dater cet événement**. C'est le cas de la carte recalculée pour
  **11 des 15** pixels « loin du seuil » concernés ; de la v3.0.1 pour **1 sur 15**.
- L'ortho du 2018-08-02/03 montre encore les arbres des pixels « A » en place : leur
  disparition est **postérieure à août 2018**. Sur les pixels « S », il n'y avait pas d'arbre au
  pixel à cette date : une coupe de ces pixels, s'il y en a eu une, est antérieure à août 2018.
- L'ancien constat de la première tentative (« une boîte de 10 m recoupe trois vols ») ne se
  retrouve pas à l'intersection exacte : un seul vol par pixel (centre et boîte de 10 m). Les
  deux autres dates (2018-06-23 et -25) sont du département voisin (33). La date de vol donnée
  par le graphe est celle du polygone de mosaïque, **pas celle de chaque image** ; au bord d'un
  polygone, elle peut être fausse.

## Question 1 : ce que datent la v3.0.1 et la carte recalculée

### Méthode (choix du dev, provisoires)

- **Chute locale** `L(t)` d'une série de NDVI : médiane des observations valides des 45 j qui
  précèdent `t` moins celle des 45 j qui suivent (au moins 2 observations de chaque côté).
- **Ce que la forêt non datée fait toute seule.** Les 20 témoins donnent la distribution de la
  plus forte chute locale à ±60 j d'une date : mêmes jour et mois que la date testée, toutes les
  années 2018-2025, décalages de −20 à +20 j. **95e centile : 0,19 à 0,22** selon le mois,
  **99e : 0,23 à 0,29**. La médiane de la plus forte marche sur 120 j des témoins est de 0,24
  (de 0,16 à 0,47) : le NDVI de la forêt de pin non datée varie nettement entre hiver et été (de
  0,4 à 0,9 sur les témoins les plus marqués).
- Une date de carte est **« confirmée » par Sentinel-2** si la plus forte chute locale à ±60 j
  de la date dépasse le 95e centile des témoins à la même saison, **ou** si une **baisse nette**
  du NDVI (marche >= 0,30 sur 120 j, parmi les six plus fortes marches de la série) tombe à
  ±60 j d'elle. Le second critère rattrape les hivers nuageux, où la chute locale sous-estime
  (pixel 30). **Trois témoins sur 20 ont au moins une baisse nette >= 0,30** en 7,7 ans : le
  faux positif existe : 3 baisses nettes en 154 années-pixel, soit environ 0,6 % par date testée
  (fenêtre de 120 j).
- Les ±60 j sont généreux : la date de la v3.0.1 vient d'un traitement Sentinel-1 qui date
  d'une acquisition postérieure à l'événement, et Sentinel-2 est lui-même lacunaire.
- **Datation des baisses nettes (corrigée à l'aller-retour 1/3).** La marche trouvée par le
  maximum d'un écart de médianes sur 120 j tombe souvent une acquisition ou plus après la
  chute, jusqu'à environ 2 mois. **La date publiée est maintenant la première observation à
  partir de laquelle le NDVI reste sous le milieu entre l'avant et l'après** (à 0,05 près, jusqu'à
  la marche, et médiane des trois observations suivantes sous ce milieu). Un creux saisonnier
  suivi d'une remontée est écarté. La baisse a eu lieu entre l'observation précédente et cette
  date : le **trou** d'observation est donné à côté de chaque date dans le tableau (de 3 à
  80 j, le plus souvent 5 à 30 j). **La précision réelle de la date d'une baisse est ce trou.**
  Les **baisses de pente lente sont mal datées** : pixels 9, 29, 32, 28, et les pixels 4, 5, 6 et 31
  pour la baisse de juillet 2025 (jeunes plantations, pente lente d'environ 0,78 à environ 0,25,
  fenêtre « après » tronquée au 2025-09-30 : la date et le niveau « après » sont incertains).
- **Ce qui est publié de P.** Le mois, et une classe : « dans ±60 j » d'une baisse nette listée,
  « dans ±60 j d'une chute locale (date non publiée) », ou « plus de 2 mois avant/après » la baisse
  nette la plus proche. Jamais un écart en jours. Les écarts en jours donnés plus bas sont
  tous « D − date de la baisse » (D est la carte produite par ce projet).

### Bilan

| Lot | Pixels | P confirmée | D confirmée | P seule | D seule | les deux | aucune |
|---|---:|---:|---:|---:|---:|---:|---:|
| **20 tirés** « loin du seuil » | 20 | **10** | **1** | 10 | 1 | 0 | 9 |
| 22 « loin du seuil » (avec les 2 tracés) | 22 | 11 | 1 | 11 | 1 | 0 | 10 |
| 12 autres pixels tracés | 12 | 3 | 1 | 2 | 0 | 1 | 9 |
| 34 pixels d'étude | 34 | 14 | 2 | 13 | 1 | 1 | 19 |

Sur les 20 tirés : P confirmée **10 / 20 (50 %, Wilson 30 à 70 %)** ; D confirmée **1 / 20
(5 %, Wilson 1 à 24 %)**. **Les comptes de la version précédente (10/20 et 1/20) sont inchangés
par la nouvelle datation** ; seul un pixel hors classe « loin du seuil » (28) passe de confirmé
à non confirmé (les 12 autres tracés : 4 → 3 confirmés pour P). L'échantillon est petit et
**groupé** (voir les limites) : ces intervalles supposent des pixels indépendants, ce qu'ils ne
sont pas.

### Ce que l'on voit au sol, par nature (lecture à l'œil du dev)

Lecture des vignettes de 2018 (2018-08-02/03) et 2021 (2021-08-31), 2024 et 2025 (dates de vol
inconnues) ; l'image 2020 est celle de 2018.

| Nature | Définition | Pixels d'étude | dont « loin du seuil » | P confirmée (loin) | D confirmée (loin) |
|---|---|---:|---:|---:|---:|
| **A** | arbres en 2018, plus d'arbres ensuite (coupe) | 15 | 11 | 6 | 0 |
| **S** | herbe ou lande sans arbre au pixel en 2018, puis sol travaillé en 2021 | 15 | 8 | 4 | 1 |
| L | pixel de lisière | 1 | 1 | 0 | 0 |
| H | herbe puis plantation, pas de sol nu vu | 1 | 1 | 0 | 0 |
| C | coupe rase ancienne (2018), puis culture | 1 | 1 | 1 | 0 |
| R | aucun changement visible à l'ortho | 1 | 0 | – | – |

**Poste BD Forêt par nature** (34 pixels) : FF0 14 pixels = 12 « S », 1 « C », 1 « H », **aucun
« A »** ; FF2-51-51 18 pixels = 13 « A », 3 « S », 1 « L », 1 « R » ; FF31 : 1 « A » ; FO2 : 1 « A ».

### Quand les arbres disparaissent (nature A, pixels « loin du seuil »)

Date de la baisse nette du NDVI (première observation sous le milieu, voir la méthode ; trou
d'observation entre parenthèses) et écart de D à cette date (D − baisse, en jours). P : classe
seulement. « Chute locale » : chute au-dessus du 95e centile des témoins à ±60 j de P, sans
baisse nette dans ±60 j.

| Pixel | Baisse nette du NDVI (trou) | P | Écart de D à la baisse nette la plus proche de D (j) | Lecture |
|---|---|---|---:|---|
| 3 : 400405 ; 6353545 | aucune baisse nette >= 0,30 ; chute locale au-dessus du 95e centile des témoins à ±60 j de P (valeurs non publiées) | dans ±60 j d'une chute locale | – (D à 2025-07-09 : chute de 0,20 le 2025-07-16, rang 0,07, juste sous le seuil) | **compatible** avec la coupe de 2024 ; pas de baisse nette ni de date |
| 4 : 393535 ; 6352525 | 2020-09-10 (5 j) | dans ±60 j | −518 | P compatible avec la coupe |
| 5 : 393465 ; 6352515 | 2020-09-10 (5 j) | dans ±60 j | +199 | P compatible avec la coupe |
| 6 : 393545 ; 6352425 | 2020-08-21 (5 j) | dans ±60 j | −880 | P compatible avec la coupe |
| 31 : 393505 ; 6346965 | 2023-02-02 (30 j) | dans ±60 j | −350 | P compatible avec la baisse de 2023 ; autre baisse en 2025-07-11 |
| 34 : 392835 ; 6345145 | 2021-12-04 (15 j) | dans ±60 j | +162 | P compatible avec la baisse de 2021 (bosquet) |
| 1 : 393315 ; 6354315 | 2019-09-21 (5 j) | plus de 2 mois après | −262 | P **tardive** |
| 2 : 394215 ; 6354215 | 2020-03-24 (15 j) | plus de 2 mois après | +1 052 | P **tardive** |
| 26 : 397465 ; 6349615 | 2018-11-25 (35 j) | plus de 2 mois après | +2 418 | P **tardive** ; la baisse de 2018 est automnale et d'autres pixels en ont une aussi (voir la note) |
| 33 : 399835 ; 6345975 | 2021-02-02 (15 j) | plus de 2 mois après | −230 | P **tardive** ; l'ortho du 2021-08-31 montre la coupe faite |
| 8 : 399425 ; 6352395 | 2024-04-12 (10 j) | plus de 2 mois avant | +340 | P **précoce** |

Pour ces 11 pixels, **la v3.0.1 est compatible avec la baisse du NDVI (à ±60 j) dans 6 cas, plus
tardive de plus de 2 mois dans 4 cas, plus précoce de plus de 2 mois dans 1 cas. La carte
recalculée n'est à ±60 j d'une baisse dans aucun cas.** « Compatible » n'est pas « date » : une
baisse à ±60 j d'une date ne prouve pas que la date vient de cet événement.

*Note sur la baisse de 2018 (pixel 26 et autres).* Une baisse nette en automne 2018 (2018-09-26 à
2018-11-25) est listée pour 11 pixels (14, 15, 16, 19, 21, 22, 23, 24, 25, 26, 27), dont 10 de
nature « herbe » : elle est vraisemblablement **saisonnière** (herbe qui jaunit) ; pour le pixel
26 (forêt mélangée), la nature de cette baisse n'est pas tranchée : la « P tardive » de ce pixel
est la moins sûre des quatre.

### Quand le sol est travaillé (nature S, pixels « loin du seuil »)

| Pixel | Baisse nette du NDVI, herbe → sol nu (trou) | P | Écart de D à la baisse nette la plus proche de D (j) |
|---|---|---|---:|
| 15 : 394725 ; 6350475 | 2020-08-16 (10 j) ; médiane du NDVI 0,76 avant, 0,24 après | dans ±60 j | +584 |
| 17 : 394595 ; 6350375 | 2020-08-21 (5 j) | dans ±60 j | +231 |
| 21 : 394465 ; 6350145 | 2020-08-21 (5 j) | dans ±60 j | +207 |
| 20 : 394515 ; 6350225 | 2020-08-21 (5 j) | dans ±60 j d'une chute locale ; plus de 2 mois après la baisse nette | +591 |
| 19 : 394305 ; 6350245 | 2020-09-05 (5 j) | plus de 2 mois après | +539 |
| 22 : 394175 ; 6350015 | 2020-10-10 (10 j) | plus de 2 mois après | +637 (mais D tombe sur une autre baisse, en 2022-07 : chute locale de 0,31 à −23 j) |
| 10 : 395355 ; 6351835 | 2019-12-15 (5 j) | plus de 2 mois après | +829 |
| 27 : 394155 ; 6349365 | non résolu (baisses nettes en 2018-10 et 2021-10) | plus de 2 mois après | −196 |

Les baisses des pixels 15 à 24 tombent de **mi-août à fin octobre 2020** (10 pixels, dont ceux du
tableau ci-dessus et 16, 18, 23, 24) : un même travail sur un même ensemble de parcelles,
vraisemblablement (hypothèse, non vérifiée). La v3.0.1 est compatible avec ce travail du sol à
±60 j dans 4 des 8 pixels (15, 17, 20, 21), la carte recalculée dans 1 (le pixel 22, sur une
autre baisse). Le pixel 15 est le cas le plus net : sur une herbe qui n'avait pas d'arbre à
l'ortho 2018, la médiane du NDVI passe de 0,76 à 0,24 (fenêtres de 120 j) et la baisse est datée
du 2020-08-16, dans le mois de P.

### Où tombent les dates de la carte recalculée

- Pour les 22 pixels « loin du seuil », **D est postérieure à P dans 22 cas sur 22** (écart
  médian **554 j**, soit 18 mois).
- **12 sur 22 sont en février ou mars**, et **8 sur 22 tombent sur l'une des 8 acquisitions de fin
  d'hiver** de 026 : 3 au 2021-03-28 (pixels 5, 12, 27), 2 au 2022-03-23 (10, 15), 2 au
  2023-02-09 (2, 6) et 1 au 2022-02-26 (19).
- Parmi les 15 pixels « loin du seuil » dont l'événement est déjà visible sur l'ortho du
  2021-08-31, la carte recalculée est **postérieure au vol pour 11**, et **antérieure au vol mais
  de 6 à 8 mois après la baisse du NDVI pour 3 (5, 17 et 21)** ; le 15e (27) n'est pas résolu.
  Ni dans un cas ni dans l'autre elle ne date l'événement.

### Les 12 pixels tracés hors classe « loin du seuil »

Ils sont dans le tableau. Trois points : pixel 9 (coupe lente, NDVI en baisse de mars à septembre
2023, baisse nette datée de 2023-04 avec un trou de 30 j, P plus de 2 mois après), pixel 13
(« pas d'image » : coupe de la parcelle voisine, baisse nette de 2024-02-07 avec un trou de 80 j ;
P plus de 2 mois après, D 16 mois après), et **pixel 28 : aucune coupe visible à l'ortho ; une
baisse nette du NDVI en 2024-08-20 (médiane de 0,82 avant à 0,34 après, fenêtres de 120 j) et P à
plus de 2 mois après**. Aucune coupe sur l'ortho PAC 2025 pour ce pixel : la baisse du NDVI n'est
pas une coupe visible (cause non observée). Avec la nouvelle datation, P n'est plus confirmée
pour ce pixel.

## Tableau des pixels

Colonnes : **P** : mois de la date publiée par la v3.0.1 et, en deuxième colonne, la classe
d'écart au NDVI Sentinel-2 (voir la méthode) ; **D** : date de la carte recalculée, et la chute
locale à ±60 j (« chute à −23 j (0,31) » : chute locale de 0,31, 23 jours **après** la date de
la carte ; « aucune (x) » : chute locale maximale vue, sous le 95e centile des témoins) ;
**baisses nettes** : dates de la première observation sous le milieu, avec le trou d'observation
précédent, des marches >= 0,30 sur 120 j, **y compris la fin d'été et l'automne 2018 des herbes
(2018-09 à 2018-11), qui sont saisonnières**. Dernières colonnes : lecture à l'œil de l'ortho
2018-08 et 2021-08.

| # | Point (L93 E ; N) | Classe 026 | P (mois) | P et le NDVI | D | NDVI à D | Baisses nettes du NDVI (trou d'observation) | Ortho 2018-08 | Ortho 2021-08 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 393315 ; 6354315 | loin | 2020-06 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-05-26 | aucune (0,07) | 2019-09-21 (5 j) ; 2023-02-12 (10 j) | couvert ligneux dense | sol dégagé nu |
| 2 | 394215 ; 6354215 | loin | 2020-08 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2023-02-09 | aucune (0,09) | 2020-03-24 (15 j) | bosquet arboré | sol nu (andains) |
| 3 | 400405 ; 6353545 | loin | 2024-04 | dans ±60 j d'une chute locale (date non publiée) | 2025-07-09 | aucune (0,20) | - | pinède fermée | pinède fermée |
| 4 | 393535 ; 6352525 | loin | 2020-10 | dans ±60 j d'une baisse nette listée | 2024-02-09 | aucune (−0,10) | 2020-09-10 (5 j) ; 2025-07-11 (3 j) | pinède | coupe rase nue |
| 5 | 393465 ; 6352515 | loin | 2020-08 | dans ±60 j d'une baisse nette listée | 2021-03-28 | aucune (0,03) | 2020-09-10 (5 j) ; 2025-07-08 (7 j) | pinède | coupe rase nue |
| 6 | 393545 ; 6352425 | loin | 2020-08 | dans ±60 j d'une baisse nette listée | 2023-02-09 | aucune (0,07) | 2020-08-21 (5 j) ; 2025-07-08 (7 j) | pinède | coupe rase nue |
| 7 | 394175 ; 6352425 | loin | 2019-06 | aucune à ±60 j ; pas de baisse nette dans la série | 2021-03-20 | aucune (0,14) | - | bois, lisière | bord d'une coupe (rémanents) |
| 8 | 399425 ; 6352395 | loin | 2023-07 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois avant | 2025-03-18 | aucune (−0,02) | 2024-04-12 (10 j) | pinède claire, lande | pinède (feuillage roux) |
| 9 | 399475 ; 6352165 | passage antérieur | 2023-09 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2025-02-23 | aucune (0,13) | 2023-04-03 (30 j) | pinède | pinède |
| 10 | 395355 ; 6351835 | loin | 2020-06 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-03-23 | aucune (−0,14) | 2019-12-15 (5 j) | lande herbeuse, arbres épars | sol travaillé |
| 11 | 398525 ; 6351825 | proche | 2020-04 | dans ±60 j d'une chute locale (date non publiée) ; baisse nette la plus proche : plus de 2 mois après | 2021-03-04 | aucune (0,06) | 2020-02-03 (15 j) | herbe | sol travaillé |
| 12 | 395125 ; 6351495 | loin | 2020-07 | aucune à ±60 j ; pas de baisse nette dans la série | 2021-03-28 | aucune (0,10) | - | herbe | jeune plantation sombre |
| 13 | 400015 ; 6351205 | pas d'image | 2024-11 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2025-06-27 | aucune (0,02) | 2024-02-07 (80 j) | pinède (bord) | pinède (bord) |
| 14 | 394475 ; 6350815 | proche | 2020-08 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-02-26 | aucune (−0,14) | 2018-09-26 (15 j) | herbe | sol travaillé |
| 15 | 394725 ; 6350475 | loin | 2020-08 | dans ±60 j d'une baisse nette listée | 2022-03-23 | aucune (−0,18) | 2018-10-16 (20 j) ; 2020-08-16 (10 j) | herbe | sol travaillé |
| 16 | 394485 ; 6350465 | orbite retenue | 2020-08 | dans ±60 j d'une baisse nette listée | 2022-03-23 | aucune (−0,16) | 2018-09-26 (15 j) ; 2020-08-16 (10 j) | herbe | sol travaillé |
| 17 | 394595 ; 6350375 | loin | 2020-09 | dans ±60 j d'une baisse nette listée | 2021-04-09 | aucune (0,06) | 2020-08-21 (5 j) | herbe | sol travaillé |
| 18 | 393965 ; 6350265 | passage antérieur | 2021-02 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-03-23 | aucune (−0,11) | 2020-08-21 (5 j) ; 2021-11-09 (30 j) | herbe | sol travaillé |
| 19 | 394305 ; 6350245 | loin | 2020-12 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-02-26 | aucune (−0,17) | 2018-10-21 (25 j) ; 2020-09-05 (5 j) | herbe | sol travaillé |
| 20 | 394515 ; 6350225 | loin | 2020-11 | dans ±60 j d'une chute locale (date non publiée) ; baisse nette la plus proche : plus de 2 mois après | 2022-04-04 | aucune (−0,11) | 2020-08-21 (5 j) | herbe | sol travaillé |
| 21 | 394465 ; 6350145 | loin | 2020-08 | dans ±60 j d'une baisse nette listée | 2021-03-16 | aucune (0,04) | 2018-09-26 (15 j) ; 2020-08-21 (5 j) | herbe | sol travaillé |
| 22 | 394175 ; 6350015 | loin | 2021-05 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2022-07-09 | chute à −23 j (0,31) | 2018-10-21 (25 j) ; 2020-10-10 (10 j) | herbe | sol travaillé |
| 23 | 393725 ; 6349945 | autre orbite | 2021-03 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2023-02-09 | aucune (0,08) | 2018-10-16 (20 j) ; 2020-10-30 (15 j) | herbe | sol travaillé |
| 24 | 394335 ; 6349885 | orbite retenue (témoin de 026) | 2021-03 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2021-04-09 | aucune (0,05) | 2018-10-21 (25 j) ; 2020-10-15 (5 j) | herbe | sol travaillé |
| 25 | 393975 ; 6349765 | orbite retenue (témoin de 026) | 2021-03 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2021-03-04 | aucune (0,08) | 2018-10-21 (25 j) ; 2019-10-26 (15 j) | herbe | sol travaillé |
| 26 | 397465 ; 6349615 | loin | 2019-07 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2025-07-09 | aucune (0,09) | 2018-11-25 (35 j) | forêt mélangée fermée | trouée de coupe au pixel |
| 27 | 394155 ; 6349365 | loin | 2019-07 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2021-03-28 | aucune (0,04) | 2018-10-21 (5 j) ; 2021-10-10 (10 j) | herbe (clairière) | sol travaillé |
| 28 | 398005 ; 6348715 | pas d'image | 2024-11 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2025-08-02 | aucune (0,15) | 2024-08-20 (10 j) | pinède (lisière) | pinède |
| 29 | 398595 ; 6348385 | autre orbite | 2022-04 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2025-03-06 | aucune (0,01) | 2021-11-09 (30 j) ; 2023-11-19 (5 j) | bosquet de pins | bosquet |
| 30 | 395675 ; 6348115 | loin | 2022-01 | dans ±60 j d'une baisse nette listée | 2023-05-04 | aucune (−0,05) | 2022-02-07 (15 j) | coupe rase ancienne | friche arbustive |
| 31 | 393505 ; 6346965 | loin | 2023-02 | dans ±60 j d'une baisse nette listée | 2024-07-26 | aucune (−0,09) | 2023-02-02 (30 j) ; 2025-07-11 (10 j) | pinède plantée | pinède |
| 32 | 394745 ; 6346215 | orbite retenue | 2022-04 | dans ±60 j d'une baisse nette listée | 2023-08-08 | chute à −3 j (0,40) | 2022-03-09 (45 j) | peuplement mélangé | peuplement |
| 33 | 399835 ; 6345975 | loin | 2022-03 | aucune à ±60 j ; baisse nette la plus proche : plus de 2 mois après | 2023-06-22 | aucune (0,14) | 2021-02-02 (15 j) ; 2024-02-07 (80 j) | pinède | coupe fraîche, sol nu |
| 34 | 392835 ; 6345145 | loin | 2021-10 | dans ±60 j d'une baisse nette listée | 2025-06-23 | aucune (0,03) | 2021-12-04 (15 j) ; 2025-01-12 (15 j) | bosquet de pins, lande | bosquet encore présent |

Les pixels 1 à 6, 8, 10, 12, 15, 17, 19, 20, 22, 26, 27, 30, 31, 33 et 34 sont les 20 tirés ; 7, 9,
11, 13, 14, 16, 18, 21, 23 à 25, 28, 29 et 32 sont les 14 pixels tracés par 026 (7 et 21 sont aussi
de la classe « loin du seuil »). Ortho 2024 et 2025 : coupe, plantation ou sol nu selon les
pixels (voir le script, `LECT`).

## Question 3 : l'objet FO0

Les 325 cellules FO0 de l'AOI forment un carré d'environ 200 m x 200 m (E 398 275 à 398 485,
N 6 346 285 à 6 346 475). 293 sont datées par la carte recalculée (objet n° 151), aucune par la
v3.0.1.

| Observation | Résultat |
|---|---|
| Dates de la carte recalculée (293 cellules) | du 2019-01 au 2020-01 : **228 en 2019-08**, 23 en 2019-02, 16 en 2019-04, 12 en 2019-03, 14 autres. Médiane : 2019-08-06 |
| **Ortho du 2018-08-03**, pixel central (398385 ; 6346375) | une **coupe rase déjà faite** : sol nu et rémanents sur toute la parcelle, bordée de peuplements. L'ortho 2020 est la même image. |
| Ortho du 2021-08-31 | sol travaillé, lignes de plantation ; 2024 : jeune plantation dense, 2025 : idem |
| NDVI médian de l'ensemble des cellules | **0,36 en 2018, 0,35 en 2019, 0,35 en 2020**, puis 0,54 en 2021, 0,56 en 2022, 0,69 en 2023, 0,74 en 2024 (témoins : 0,67 à 0,75 chaque année). À la date de vol de 2018 (2018-08-02) : 0,36 |
| Autour de la date de la carte | marche de la médiane du NDVI entre 2019-07-28 et 2019-08-02 : 0,47 (médiane des 120 j avant) à 0,29 (des 120 j après) ; chute locale de 0,21 le 2019-08-17, **égale au 95e centile des témoins (0,21)** ; 41 % des 293 cellules le dépassent (5 % attendus sans événement) |

**Lecture, au sens de ce qui est observé** :
- **« Coupe réelle en 2019 »** : non observée. L'ortho du 2018-08-03 montre une parcelle sans
  arbre, et le NDVI est déjà de 0,36 au premier semestre 2018.
- **« Jeune peuplement sans coupe »** : non plus. L'ortho de 2018 montre une coupe rase faite
  (sol nu et rémanents) ; la jeune plantation n'apparaît qu'à l'ortho 2021, 2024.
- **« Autre »** : ce qui reste est une baisse modérée du NDVI en été 2019, sur un sol déjà
  ouvert, comparable en taille au plus fort de ce que fait la forêt témoin (95e centile). Sa
  nature (herbe qui sèche, dégagement de la végétation, travail du sol) **n'est pas observée**.
- **Pourquoi la v3.0.1 ne date pas cette surface** n'est pas observé. Ce n'est pas testé ici.

Un seul objet, une seule parcelle, un seul pixel regardé en vignette (la vignette de 300 m
montre toute la parcelle) : cela ne dit rien d'un autre FO0 hors de cette AOI.

## Ce que cela met sur la table (pour Pascal)

Ce rapport ne tranche pas. Ce qu'il apporte, au sens de ce qui est observé :

1. **La classe « loin du seuil » n'est pas une mauvaise date de coupe d'arbres.** Sur 22 pixels
   : 11 coupes d'arbres, 8 travaux du sol sans arbre au pixel en 2018, 3 autres. Les « loin du
   seuil » de la mission 026 mêlent des événements physiques de nature différente.
2. **Dans le lot, la v3.0.1 est compatible avec une baisse du NDVI à ±60 j pour la moitié des
   cas**, et la carte recalculée pour 1 cas sur 20, toujours après la v3.0.1. Ce qui sépare les
   deux cartes dans ces pixels n'est pas une affaire de seuil à la marge : ce sont des dates à
   18 mois.
3. **Ce que la carte « doit dater »** est la décision que cette mission rend nécessaire :
   - *Dater la coupe d'arbres seulement.* Alors, pour les pixels de nature « S » (herbe, sol
     travaillé), la v3.0.1 date 4 fois sur 8 un événement qui n'est pas une coupe d'arbres de la
     période (pas d'arbre en 2018) ; et les 14 pixels FF0 du lot sont tous sans arbre en
     2018. La décision du 2026-11-22 (FF0 et FO0 comptés forêt) maintient ces pixels dans la
     carte.
   - *Dater tout dégagement du sol (coupe ou travail du sol).* Alors les 8 « S » en font partie, et
     la mesure de l'écart à la v3.0.1 doit être lue comme telle.
4. **FF0 et FO0.** Dans ce lot, FF0 = ancienne coupe rase ou herbe, sans arbre en 2018 (14 pixels,
   un seul AOI) ; FO0 = coupe rase de 2018 (1 objet). La v3.0.1 ne date pas FO0 ; la carte
   recalculée le date en 2019 sur un état déjà sans arbre. Ce lot ne montre pas de coupe
   d'arbres sur ces deux postes.

## Pixels à contrôler par Pascal

À ouvrir sur l'orthophoto (2018 et 2021, Géoplateforme) et sur Sentinel-2 (série NDVI de la
tuile T30TXP) :

| Pourquoi | Point (L93 E ; N) | À regarder |
|---|---|---|
| Coupe d'arbres, P compatible avec la baisse | **393545 ; 6352425** (pixel 6) et **393465 ; 6352515** (5) | pinède sur l'ortho 2018-08, coupe rase sur l'ortho 2021-08-31 ; baisse du NDVI le 2020-08-21 (6) et le 2020-09-10 (5), de 0,75 à 0,3 environ ; D en 2023-02 ou 2021-03 : rien |
| Coupe d'arbres, P compatible (chute locale seulement) | **400405 ; 6353545** (3) | pinède en 2021, coupe rase en 2024 ; chute du NDVI à ±60 j de P, pas de baisse nette ; D en 2025-07 : une chute de 0,20 juste sous le seuil |
| Travail du sol, P dans le mois de la baisse | **394725 ; 6350475** (15) | herbe en 2018, sol travaillé en 2021 ; NDVI déjà bas (médiane 0,24 après la baisse) le 2020-08-16, dans le mois de P |
| P plus de 2 mois **avant** la baisse | **399425 ; 6352395** (8) | pinède jusqu'en 2021 ; coupe vue en 2024 ; baisse du NDVI le 2024-04-12 |
| P plus de 2 mois **après** la baisse | **399835 ; 6345975** (33) | pinède en 2018 ; coupe fraîche à l'ortho du 2021-08-31 ; baisse du NDVI le 2021-02-02 |
| Pixel de lisière, mesure mélangée | **394175 ; 6352425** (7) | coupe au nord du pixel ; Sentinel-2 mélange |
| Pixel 28 : baisse du NDVI sans coupe visible | **398005 ; 6348715** | pinède sur toutes les orthos ; baisse nette du NDVI le 2024-08-20 |
| FO0 | **398385 ; 6346375** (centre de l'objet) | coupe rase déjà faite à l'ortho 2018-08-03 ; NDVI à 0,35 de 2018 à 2020 |

## Limites

- **Un AOI (100 km², pin maritime) et 34 pixels groupés.** Les pixels 4, 5 et 6 sont sur la
  même parcelle ; 15 à 25 sur un même ensemble de parcelles voisines (E 393 700 à 394 700,
  N 6 349 700 à 6 350 500). L'ordre de grandeur est de **quelques dizaines de parcelles**, pas
  de pixels. Les intervalles de Wilson supposent des pixels indépendants et sont donc trop
  étroits.
- **Le tirage ne représente que la classe « loin du seuil »** (3 359 pixels), pas le « reste »
  de 026 (13 104) ni tous les pixels tardifs (25 181).
- **NDVI.** Un pixel de 10 m ; en lisière (pixels 7, 13, 34) il mélange deux états. L'herbe et
  les arbres ont tous deux un NDVI de 0,75 à 0,85 l'été : Sentinel-2 ne dit pas s'il y avait des
  arbres, c'est la lecture de l'ortho 2018 qui le dit. L'herbe change de NDVI chaque année
  (de 0,8 en été à 0,4 en hiver) : le seuil des témoins (forêt de pin) **sous-estime peut-être**
  le faux positif sur les pixels « herbe » à l'automne. Les baisses d'août 2020 des pixels 15,
  16, 17, 20 et 21 (un passage, de 0,76 à 0,24 pour le 15) ne ressemblent pas à cette descente
  saisonnière, qui est lente et plutôt en octobre-novembre.
- **Datation des baisses.** La précision d'une date de baisse est le trou d'observation (3 à
  80 j) ; la correction de l'aller-retour 1/3 retire le décalage de la marche, pas ce trou. Un
  même seuil de milieu s'applique à tous les pixels, y compris à ceux dont la baisse est lente.
- **Baisses de juillet 2025 et pixel 28 : pentes lentes mal datées.** Les pixels 4, 5, 6 et 31
  (jeunes plantations) montrent une baisse du NDVI listée du 2025-07-08 au 2025-07-11, mais c'est
  une pente lente (d'environ 0,78 à environ 0,25) dont la fenêtre « après » est tronquée au
  2025-09-30 ; il en est de même du pixel 28. Leurs dates et niveaux sont mal établis, comme ceux
  des pixels 9, 29 et 32. Un événement commun (sécheresse de l'herbe, voile non masqué) est
  possible. Non tranché.
- **Lecture à l'œil.** Les colonnes « Ortho 2018 » et « Ortho 2021 » et la nature (A, S, L, H, C,
  R) sont la lecture du dev de vignettes de 300 m, un seul lecteur : à contrôler. Les dates de
  vol de 2024 et 2025 sont inconnues, l'ortho 2020 est l'image de 2018.
- **Ce que fait la v3.0.1 n'est pas une vérité terrain.** Une baisse du NDVI à ±60 j d'une
  date ne prouve pas que la date vient de cet événement : elle montre que la date est compatible
  avec lui.
- **Les ±60 j**, le seuil de 0,30 pour une baisse nette et le milieu (avant/après) de la datation
  sont des choix du dev, provisoires. Aucun autre réglage n'a été essayé.
- **Lacunes de Sentinel-2.** Une observation valide tous les 13 jours en moyenne, plus
  rarement l'hiver. La chute locale (45 j, 2 observations de chaque côté) peut manquer un
  événement d'hiver (pixel 30 : retrouvé par la marche de 120 j).
- 12 pixels tracés par 026 hors classe « loin du seuil » sont dans le tableau mais ne forment
  pas un échantillon.
- **Sentinel-2 : les scènes à plus de 90 % de nuages sont écartées** (142 acquisitions sur 593), et
  les 100 retraitements de 2024 sont remplacés par l'acquisition la plus récente (même date).
  L'effet d'un autre seuil n'est pas essayé.
- **Dates de vol** : un graphe de mosaïquage, pas un vol par image. Si une prise de vue a été
  remplacée dans la mosaïque de 2018 ou 2021 (retouche), la date du graphe ne la suit pas.

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-1 RTC processed by
  Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0. (Les séries Sentinel-1 de 026 ne
  sont pas relues ici ; mentionné parce que les dates P et D en viennent.)
- **[S2]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-2 L2A
  (`sentinel-2-l2a`), hosted by Microsoft Planetary Computer. Données du programme Copernicus,
  libres et ouvertes (règlement délégué (UE) n° 1159/2013). Données modifiées : NDVI aux pixels
  nommés, hors dépôt.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées : codes
  TFV rastérisés sur la grille de la carte.
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing 10(8),
  1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts in
  Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1, licence CC
  BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin sur la grille de
  la carte recalculée ; seuls des chiffres agrégés et le mois de la date publiée pour les
  pixels nommés sont publiés ici.
- **[ORT]** Source : IGN, BD ORTHO® 2018 et 2021 (graphes de mosaïquage `date_vol`), Ortho
  Express 2024, orthophotos PAC 2020 et 2025, services WMS et WFS de la Géoplateforme
  (data.geopf.fr), Licence Ouverte 2.0. Consultées, non redistribuées (vignettes hors dépôt).
