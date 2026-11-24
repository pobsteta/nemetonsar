# Ce que datent les pixels « loin du seuil » : Sentinel-2 et dates de vol des orthophotos — mission 028

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il contient des chiffres agrégés et, pour les pixels
> nommés (coordonnées L93 données pour le contrôle sur orthophoto et sur Sentinel-2), le
> **mois** de la date publiée par la v3.0.1 et l'écart en jours de cette date à une baisse
> du NDVI. Il ne contient aucune autre valeur de pixel de la v3.0.1. Les dates de la
> carte recalculée (produite par ce projet) sont données en entier.

Analyste, 2026-11-24, sur le poste de Pascal. Script :
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
   (1 à 24 %). Aucun des 22 pixels « loin du seuil » n'est confirmé pour les deux dates. La carte recalculée date
   **après** la v3.0.1 pour les 22 pixels (écart médian 18 mois), et dans 12 cas sur 22 en
   février-mars.
3. **Ce que l'on voit au sol sur ces pixels** (lecture à l'œil de l'analyste, à contrôler) :
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
| Durées | Lecture Sentinel-2 : environ 15 min de lecture utile en plusieurs lancements (reprise par fichier de scène ; deux premiers essais arrêtés pour lenteur : l'extraction point par point était environ 4 fois plus lente que la lecture d'une fenêtre). Analyse : 30 s |

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

### Méthode (choix de l'analyste, provisoires)

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
- **Les dates de baisse du NDVI des tableaux sont celles de la première observation après la
  marche** : l'événement a eu lieu entre la dernière observation avant et celle-ci, soit en
  moyenne ~2 semaines, un à deux mois dans les hivers nuageux.

### Bilan

| Lot | Pixels | P confirmée | D confirmée | P seule | D seule | les deux | aucune |
|---|---:|---:|---:|---:|---:|---:|---:|
| **20 tirés** « loin du seuil » | 20 | **10** | **1** | 10 | 1 | 0 | 9 |
| 22 « loin du seuil » (avec les 2 tracés) | 22 | 11 | 1 | 11 | 1 | 0 | 10 |
| 12 autres pixels tracés | 12 | 4 | 1 | 3 | 0 | 1 | 8 |
| 34 pixels d'étude | 34 | 15 | 2 | 14 | 1 | 1 | 18 |

Sur les 20 tirés : P confirmée **10 / 20 (50 %, Wilson 30 à 70 %)** ; D confirmée **1 / 20
(5 %, Wilson 1 à 24 %)**. L'échantillon est petit et **groupé** (voir les limites) : ces
intervalles supposent des pixels indépendants, ce qu'ils ne sont pas.

### Ce que l'on voit au sol, par nature (lecture à l'œil de l'analyste)

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

Date de la baisse nette du NDVI (première observation après la marche) et écarts « date de la
carte − date de la baisse », en jours. Pour P, deux mesures : la **chute locale** à ±60 j
(date de sa plus forte valeur) et la **baisse nette** la plus proche ; « – » : pas de chute locale
au-dessus du 95e centile des témoins. Seul le mois de P est publié ici.

| Pixel | Baisse nette du NDVI | Écart de P : chute locale / baisse nette | Écart de D : baisse nette la plus proche | Lecture |
|---|---|---|---:|---|
| 3 : 400405 ; 6353545 | 2024-04 (chute locale de 0,20 ; pas de marche >= 0,30 ; NDVI médian 0,47 dans les 90 j avant P, 0,36 après) | +5 / – | – (une baisse de 0,20 le 2025-07-16, 7 j après D, rang 0,07) | P date la coupe de 2024 |
| 4 : 393535 ; 6352525 | 2020-09-25 | +32 / +32 | −518 | P date la coupe |
| 5 : 393465 ; 6352515 | 2020-09-10 (chute) à 2020-10-30 (marche) | −17 / −67 | +149 | P date la coupe |
| 6 : 393545 ; 6352425 | 2020-09-05 (chute) à 2020-10-15 (marche) | −12 / −52 | +847 | P date la coupe |
| 31 : 393505 ; 6346965 | 2023-01-03 (chute) à 2023-02-17 (marche) | +37 / −8 | −350 | P date la baisse de 2023 ; une autre baisse en 2025-07 |
| 34 : 392835 ; 6345145 | 2021-12-04 | −59 / −59 | +162 | P date, 2 mois avant, la baisse de 2021 (bosquet) |
| 1 : 393315 ; 6354315 | 2019-09-21 | – / +277 | −262 | P **9 mois après** |
| 2 : 394215 ; 6354215 | 2020-03-24 | – / +140 | +1 052 | P **4,5 mois après** |
| 26 : 397465 ; 6349615 | 2018-11-25 | – / +229 | +2 418 | P **7,5 mois après** |
| 33 : 399835 ; 6345975 | 2021-02-17 | – / +398 | −230 | P **13 mois après** ; l'ortho du 2021-08-31 montre la coupe faite |
| 8 : 399425 ; 6352395 | 2024-04-12 | – / −272 | +340 | P **9 mois avant** la baisse |

Pour ces 11 pixels, **la v3.0.1 est à ±60 j de la baisse du NDVI dans 6 cas, plus tardive de 4,5
à 13 mois dans 4 cas, plus précoce de 9 mois dans 1 cas. La carte recalculée n'est à ±60 j d'une
baisse dans aucun cas.**

### Quand le sol est travaillé (nature S, pixels « loin du seuil »)

| Pixel | Baisse nette du NDVI (herbe → sol nu) | Écart de P : chute locale / baisse nette | Écart de D : baisse nette la plus proche |
|---|---|---|---:|
| 15 : 394725 ; 6350475 | 2020-08-21 (NDVI 0,76 → 0,24) | +3 / +3 | +579 |
| 17 : 394595 ; 6350375 | 2020-08-31 | +14 / +4 | +221 |
| 21 : 394465 ; 6350145 | 2020-09-10 | +7 / −18 | +187 |
| 20 : 394515 ; 6350225 | 2020-09-30 | +59 / +34 | +551 |
| 19 : 394305 ; 6350245 | 2020-09-25 | – / +92 | +519 |
| 22 : 394175 ; 6350015 | 2020-10-15 | – / +224 | +632 (mais D tombe sur une autre baisse, en 2022-07 : chute locale de 0,31 à −23 j) |
| 10 : 395355 ; 6351835 | 2019-12-15 | – / +197 | +829 |
| 27 : 394155 ; 6349365 | non résolu (série saisonnière, baisses nettes en 2018-11 et 2021-11) | – / +241 | −196 |

Les baisses des pixels 15 à 24 tombent d'**août à novembre 2020** (10 pixels, dont ceux du
tableau ci-dessus et 16, 18, 23, 24) : un même travail sur un même ensemble de parcelles,
vraisemblablement (hypothèse, non vérifiée). La v3.0.1 date ce travail du sol à ±60 j dans 4
des 8 pixels (15, 17, 20, 21), la carte recalculée dans 1 (le pixel 22, sur une autre baisse). Le
pixel 15 est le cas le plus net : NDVI de 0,76 à 0,24 en une acquisition, soit **3 jours
avant P**, sur une herbe qui n'avait pas d'arbre à l'ortho 2018.

### Où tombent les dates de la carte recalculée

- Pour les 22 pixels « loin du seuil », **D est postérieure à P dans 22 cas sur 22** (écart de 205
  à 2 189 j, médiane **554 j**, soit 18 mois).
- **12 sur 22 sont en février ou mars**, et **8 sur 22 tombent sur l'une des 8 acquisitions de fin
  d'hiver** de 026 : 3 au 2021-03-28 (pixels 5, 12, 27), 2 au 2022-03-23 (10, 15), 2 au
  2023-02-09 (2, 6) et 1 au 2022-02-26 (19).
- Parmi les 15 pixels « loin du seuil » dont l'événement est déjà visible sur l'ortho du
  2021-08-31, la carte recalculée est **postérieure au vol pour 11**, et **antérieure au vol mais 5 à
  7 mois après la baisse du NDVI pour 3 (5, 17 et 21)** ; le 15e (27) n'est pas résolu.
  Ni dans un cas ni dans l'autre elle ne date l'événement.

### Les 12 pixels tracés hors classe « loin du seuil »

Ils sont dans le tableau. Trois points : pixel 9 (coupe lente, NDVI en baisse de mars à septembre
2023, P à la fin de la baisse), pixel 13 (« pas d'image » : coupe de la parcelle voisine, NDVI
du pixel de bord en baisse en 2024-03, P et D 8 et 16 mois après), et **pixel 28 : aucune coupe
visible à l'ortho ; P tombe à +25 j d'une baisse nette du NDVI** (de 0,82 à 0,34, d'octobre 2024 à
mars 2025, puis retour à 0,62). Aucune coupe sur l'ortho PAC 2025 pour ce pixel : la v3.0.1
y date ce qui ressemble à une baisse du NDVI sans coupe visible (cause non observée).

## Tableau des pixels

Colonnes : **P** : mois de la date publiée par la v3.0.1 et, en deuxième colonne, ce que fait
le NDVI Sentinel-2 à ±60 j (« chute à +5 j (0,20) » : chute locale de 0,20, 5 jours **avant**
la date ; l'écart est « date de la carte − date de la chute ») ; **D** : date de la carte
recalculée, idem ; **baisses nettes** : dates (première observation après la marche) des
marches >= 0,30 sur 120 j, **y compris la fin d'automne des herbes (2018-10 à 2018-11), qui est
saisonnière**. Dernières colonnes : lecture à l'œil de l'ortho 2018-08 et 2021-08.

| # | Point (L93 E ; N) | Classe 026 | P (mois) | S2 à P | D | S2 à D | Baisses nettes du NDVI | Ortho 2018-08 | Ortho 2021-08 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 393315 ; 6354315 | loin | 2020-06 | aucune (0,01) | 2022-05-26 | aucune (0,07) | 2019-09-21 ; 2023-02-12 | couvert ligneux dense | sol dégagé nu |
| 2 | 394215 ; 6354215 | loin | 2020-08 | aucune (0,17) | 2023-02-09 | aucune (0,09) | 2020-03-24 | bosquet arboré | sol nu (andains) |
| 3 | 400405 ; 6353545 | loin | 2024-04 | chute à +5 j (0,20) | 2025-07-09 | aucune (0,20) | - | pinède fermée | pinède fermée |
| 4 | 393535 ; 6352525 | loin | 2020-10 | chute à +32 j (0,28) | 2024-02-09 | aucune (−0,10) | 2020-09-25 ; 2025-07-11 | pinède | coupe rase nue |
| 5 | 393465 ; 6352515 | loin | 2020-08 | chute à −17 j (0,36) | 2021-03-28 | aucune (0,03) | 2020-10-30 ; 2025-07-08 | pinède | coupe rase nue |
| 6 | 393545 ; 6352425 | loin | 2020-08 | chute à −12 j (0,28) | 2023-02-09 | aucune (0,07) | 2020-10-15 ; 2025-07-08 | pinède | coupe rase nue |
| 7 | 394175 ; 6352425 | loin | 2019-06 | aucune (0,01) | 2021-03-20 | aucune (0,14) | - | bois, lisière | bord d'une coupe (rémanents) |
| 8 | 399425 ; 6352395 | loin | 2023-07 | aucune (−0,03) | 2025-03-18 | aucune (−0,02) | 2024-04-12 | pinède claire, lande | pinède (feuillage roux) |
| 9 | 399475 ; 6352165 | passage antérieur | 2023-09 | aucune (0,00) | 2025-02-23 | aucune (0,13) | 2023-04-03 | pinède | pinède |
| 10 | 395355 ; 6351835 | loin | 2020-06 | aucune (0,01) | 2022-03-23 | aucune (−0,14) | 2019-12-15 | lande herbeuse, arbres épars | sol travaillé |
| 11 | 398525 ; 6351825 | proche | 2020-04 | chute à +12 j (0,19) | 2021-03-04 | aucune (0,06) | 2020-02-23 | herbe | sol travaillé |
| 12 | 395125 ; 6351495 | loin | 2020-07 | aucune (0,07) | 2021-03-28 | aucune (0,10) | - | herbe | jeune plantation sombre |
| 13 | 400015 ; 6351205 | pas d'image | 2024-11 | aucune (0,03) | 2025-06-27 | aucune (0,02) | 2024-03-13 | pinède (bord) | pinède (bord) |
| 14 | 394475 ; 6350815 | proche | 2020-08 | aucune (0,12) | 2022-02-26 | aucune (−0,14) | 2018-10-21 | herbe | sol travaillé |
| 15 | 394725 ; 6350475 | loin | 2020-08 | chute à +3 j (0,53) | 2022-03-23 | aucune (−0,18) | 2018-11-25 ; 2020-08-21 | herbe | sol travaillé |
| 16 | 394485 ; 6350465 | orbite retenue | 2020-08 | chute à +18 j (0,53) | 2022-03-23 | aucune (−0,16) | 2018-11-15 ; 2020-08-16 | herbe | sol travaillé |
| 17 | 394595 ; 6350375 | loin | 2020-09 | chute à +14 j (0,32) | 2021-04-09 | aucune (0,06) | 2020-08-31 | herbe | sol travaillé |
| 18 | 393965 ; 6350265 | passage antérieur | 2021-02 | aucune (0,09) | 2022-03-23 | aucune (−0,11) | 2020-08-31 ; 2021-11-19 | herbe | sol travaillé |
| 19 | 394305 ; 6350245 | loin | 2020-12 | aucune (0,10) | 2022-02-26 | aucune (−0,17) | 2018-11-25 ; 2020-09-25 | herbe | sol travaillé |
| 20 | 394515 ; 6350225 | loin | 2020-11 | chute à +59 j (0,28) | 2022-04-04 | aucune (−0,11) | 2020-09-30 | herbe | sol travaillé |
| 21 | 394465 ; 6350145 | loin | 2020-08 | chute à +7 j (0,35) | 2021-03-16 | aucune (0,04) | 2018-11-25 ; 2020-09-10 | herbe | sol travaillé |
| 22 | 394175 ; 6350015 | loin | 2021-05 | aucune (0,01) | 2022-07-09 | chute à −23 j (0,31) | 2018-10-21 ; 2020-10-15 | herbe | sol travaillé |
| 23 | 393725 ; 6349945 | autre orbite | 2021-03 | aucune (0,04) | 2023-02-09 | aucune (0,08) | 2018-11-25 ; 2020-10-30 | herbe | sol travaillé |
| 24 | 394335 ; 6349885 | orbite retenue (témoin de 026) | 2021-03 | aucune (0,05) | 2021-04-09 | aucune (0,05) | 2018-11-25 ; 2020-11-29 | herbe | sol travaillé |
| 25 | 393975 ; 6349765 | orbite retenue (témoin de 026) | 2021-03 | aucune (0,08) | 2021-03-04 | aucune (0,08) | 2018-11-25 ; 2019-10-26 | herbe | sol travaillé |
| 26 | 397465 ; 6349615 | loin | 2019-07 | aucune (−0,01) | 2025-07-09 | aucune (0,09) | 2018-11-25 | forêt mélangée fermée | trouée de coupe au pixel |
| 27 | 394155 ; 6349365 | loin | 2019-07 | aucune (0,15) | 2021-03-28 | aucune (0,04) | 2018-11-25 ; 2021-11-19 | herbe (clairière) | sol travaillé |
| 28 | 398005 ; 6348715 | pas d'image | 2024-11 | baisse nette à +25 j | 2025-08-02 | aucune (0,15) | 2024-10-24 | pinède (lisière) | pinède |
| 29 | 398595 ; 6348385 | autre orbite | 2022-04 | aucune (−0,09) | 2025-03-06 | aucune (0,01) | 2021-11-19 ; 2023-11-19 | bosquet de pins | bosquet |
| 30 | 395675 ; 6348115 | loin | 2022-01 | baisse nette à −24 j | 2023-05-04 | aucune (−0,05) | 2022-02-07 | coupe rase ancienne | friche arbustive |
| 31 | 393505 ; 6346965 | loin | 2023-02 | chute à +37 j (0,36) | 2024-07-26 | aucune (−0,09) | 2023-02-17 ; 2025-07-11 | pinède plantée | pinède |
| 32 | 394745 ; 6346215 | orbite retenue | 2022-04 | baisse nette à +25 j | 2023-08-08 | chute à −3 j (0,40) | 2022-03-09 | peuplement mélangé | peuplement |
| 33 | 399835 ; 6345975 | loin | 2022-03 | aucune (−0,01) | 2023-06-22 | aucune (0,14) | 2021-02-17 ; 2024-02-07 | pinède | coupe fraîche, sol nu |
| 34 | 392835 ; 6345145 | loin | 2021-10 | chute à −59 j (0,29) | 2025-06-23 | aucune (0,03) | 2021-12-04 ; 2025-01-12 | bosquet de pins, lande | bosquet encore présent |

Les pixels 1 à 6, 8, 10, 12, 15, 17, 19, 20, 22, 26, 27, 30, 31, 33 et 34 sont les 20 tirés ; 7, 9,
11, 13, 14, 16, 18, 21, 23 à 25, 28, 29 et 32 sont les 14 pixels tracés par 026 (7 et 21 sont aussi
de la classe « loin du seuil »). La colonne « aucune (x) » donne la chute locale maximale vue à
±60 j. Ortho 2024 et 2025 : coupe, plantation ou sol nu selon les pixels (voir le script, `LECT`).

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
2. **Dans le lot, la v3.0.1 est à ±60 j d'une baisse du NDVI pour la moitié des cas**, et la
   carte recalculée pour 1 cas sur 20, toujours après la v3.0.1. Ce qui sépare les deux cartes
   dans ces pixels n'est pas une affaire de seuil à la marge : ce sont des dates à 18 mois.
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
| Coupe d'arbres, P à la date de la baisse du NDVI | **393545 ; 6352425** (pixel 6) et **393465 ; 6352515** (5) | pinède sur l'ortho 2018-08, coupe rase sur l'ortho 2021-08-31 ; baisse du NDVI de 0,75 à 0,3 en septembre-octobre 2020 ; D en 2023-02 ou 2021-03 : rien |
| Coupe d'arbres, P à +5 j de la baisse | **400405 ; 6353545** (3) | pinède en 2021, coupe rase en 2024 ; baisse du NDVI en 2024-04 |
| Travail du sol, P à +3 j | **394725 ; 6350475** (15) | herbe en 2018, sol travaillé en 2021 ; NDVI de 0,76 à 0,24 le 2020-08-21 |
| P 9 mois **avant** la baisse | **399425 ; 6352395** (8) | pinède jusqu'en 2021 ; coupe vue en 2024 ; baisse du NDVI en 2024-04 |
| P 13 mois **après** la baisse | **399835 ; 6345975** (33) | pinède en 2018 ; coupe fraîche à l'ortho du 2021-08-31 ; baisse du NDVI en 2021-02 |
| Pixel de lisière, mesure mélangée | **394175 ; 6352425** (7) | coupe au nord du pixel ; Sentinel-2 mélange |
| Pixel 28 : P sur une baisse du NDVI sans coupe visible | **398005 ; 6348715** | pinède sur toutes les orthos ; NDVI de 0,82 à 0,34 de 2024-10 à 2025-03 |
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
  16 et 21 (un passage, de 0,76 à 0,24) ne ressemblent pas à cette descente saisonnière, qui est
  lente et plutôt en octobre-novembre.
- **Baisses d'une date unique.** Les pixels 3, 4, 5, 6, 9, 31 montrent une baisse du NDVI
  autour du 2025-07-08 à 2025-07-16, la même semaine, sur des pixels différents : un événement
  commun (sécheresse de l'herbe des jeunes plantations, voile non masqué) est possible. Non
  tranché.
- **Lecture à l'œil.** Les colonnes « Ortho 2018 » et « Ortho 2021 » et la nature (A, S, L, H, C,
  R) sont la lecture de l'analyste de vignettes de 300 m, un seul relecteur : à contrôler. Les
  dates de vol de 2024 et 2025 sont inconnues, l'ortho 2020 est l'image de 2018.
- **Ce que fait la v3.0.1 n'est pas une vérité terrain.** Une baisse du NDVI à ±60 j d'une
  date ne prouve pas que la date vient de cet événement : elle montre que la date est compatible
  avec lui.
- **Les ±60 j** et le seuil de 0,30 pour une baisse nette sont des choix de l'analyste,
  provisoires. Avec ±30 j, moins de dates sont confirmées.
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
  nommés, hors dépôt. *`docs/referentiels/licences.md` n'a pas d'entrée [S2] : à ajouter par
  l'orchestrateur.*
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
