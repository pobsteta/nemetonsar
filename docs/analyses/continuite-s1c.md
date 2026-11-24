# Détections 2026 et continuité Sentinel-1A, 1C, 1D : mission 029
Analyste, 2026-11-24, sur le poste de Pascal

> **Ce que ce rapport contient.** Des chiffres agrégés tirés de la
> chaîne `nemetonsar` lancée sur la tuile pilote des Landes (images
> Sentinel-1 RTC du Planetary Computer, masque BD Forêt), des
> statistiques de pixels forestiers sans coupe et trois coupes à
> contrôler (coordonnées). Il ne contient **aucune donnée de la carte
> SUFOSAT v3.0.1** (elle s’arrête en septembre 2025) et n’hérite donc
> pas de la clause non commerciale de celle-ci. Il ne contient aucune
> image Sentinel-1. Attribution : Sentinel-1 RTC traité par Catalyst,
> hébergé par Microsoft Planetary Computer, CC BY 4.0 ; données
> Copernicus Sentinel modifiées. Masque forêt : BD Forêt v2 (IGN), par
> le service WFS de la Géoplateforme.

Script : [`continuite-s1c.R`](continuite-s1c.R) (étapes `orbites`,
`executer`, `resumer`, `controle`, `signal`, `synthese`). Mission :
`pilotage/missions/029-continuite-s1c.md`.

**Mission, en une phrase.** Lancer le pilote des Landes sur toute la
période servie jusqu’en novembre 2026 et mesurer si la chaîne passe sans
rupture de Sentinel-1A (arrêté le 2026-06-29) à Sentinel-1C et 1D, pour
tenir l’arbitrage n° 3 du brief.

## Réponses

1.  **Le Planetary Computer sert-il S1C et S1D ?** Oui. 36 dates de
    Sentinel-1C (du 2026-06-30 au 2026-11-21) et 33 de Sentinel-1D (du
    2026-07-06 au 2026-11-16), sur **les trois mêmes orbites relatives
    que Sentinel-1A** (A030, D008, D081). Dernière date servie :
    2026-11-21.
2.  **La chaîne va-t-elle au bout ?** Oui : 809 images, 3 orbites,
    aucune écartée, aucune erreur, aucune série coupée, 38,0 min, 287
    objets dans la carte finale.
3.  **Continuité du signal ?** **Non, pas sans rupture mesurable.** Le
    niveau VH moyen d’une image ne saute pas de façon univoque (1C et 1D
    s’accordent à 0,03 dB près ; l’écart avec les années 1A va de −0,04
    à −0,57 dB selon l’orbite, pour 0,16 à 0,18 dB d’écart-type entre
    années). En revanche, **la queue du ratio de changement sur forêt
    sans coupe s’épaissit : la part de pixels sous le seuil de
    propagation tp est multipliée par 6 à 15 et l’écart robuste augmente
    de 5 à 17 %**, tandis que la médiane baisse de 0,4 à 0,6 dB (du même
    ordre que sa variation saisonnière de ± 0,5 dB) dès que la fenêtre «
    après » du ratio ne contient que des images 1C/1D (section «
    Question 3 »). La cause (étalonnage, géométrie, saison) n’est pas
    isolée avec une seule année.
4.  **Combien de coupes, et le délai ?** 114 objets datés après
    2025-09-30 (267,0 ha), dont 80 à partir du 2026-06-30 (91,6 ha).
    **67 de ces objets tombent dans les 30 jours qui suivent la
    bascule**, contre environ 2 par mois les années précédentes : très
    probablement des faux positifs, en tout cas non démontrés comme
    coupes. Le délai de détection n’est pas dégradé : la 3e image arrive
    en 12 jours après la bascule, contre 24 avant.

**Contrôle du test de la mission.** Sur 2025-01 à 2025-09, les
détections de cette exécution ne sont **pas** celles de 017 : 4 908
pixels sur 11 751 gardent la même date (41,8 %), 21 objets contre 7 en
017. Ce n’est pas propre au changement de capteur (section « Stabilité
des dates »).

## Ce qui a tourné

| Élément | Valeur |
|:---|:---|
| Appel | `nemetonsar_run()` sur l’AOI de la mission 017 (10 km × 10 km, tuile 30TXP), réglages par défaut (processus et flux par défaut) |
| Période lue | 2018-01-01 au 2026-11-21 (dernier jour servi). Le début est 2018 et non 2025 : le ratio de référence Mb est la moyenne de toutes les images antérieures (`xb = Inf`) et le noyau du filtre est 2018 ; une série commencée en 2025 ne reproduirait pas 017 |
| Réglages | `parametres_sufosat()` (Xa = 3, ts = −4,5 dB et tp = −3 dB × 1,15, 0,1 ha, combinaison `minimum`) |
| Masque forêt | BD Forêt v2, WFS de la Géoplateforme |
| Images | 809 images, 3 orbites |
| Durée | 38,0 min, un seul passage, sans reprise |
| Poste | poste de Pascal, deux autres analystes en même temps sur la même connexion |

## Question 1 : quels capteurs, quelles orbites

Chaque ligne est une date d’acquisition d’une orbite (les images de
l’orbite ascendante A030 ont deux tranches par date, de même D081 en
1C/1D ; chaque date est comptée une fois).

| mois    | S1A | S1C | S1D |
|:--------|----:|----:|----:|
| 2026-01 |   7 |   0 |   0 |
| 2026-02 |   6 |   0 |   0 |
| 2026-03 |   9 |   0 |   0 |
| 2026-04 |   6 |   0 |   0 |
| 2026-05 |   8 |   0 |   0 |
| 2026-06 |   5 |   1 |   0 |
| 2026-07 |   0 |   7 |   7 |
| 2026-08 |   0 |   8 |   7 |
| 2026-09 |   0 |   7 |   8 |
| 2026-10 |   0 |   8 |   6 |
| 2026-11 |   0 |   5 |   5 |

Dates d’acquisition par mois et par capteur, 2026 (toutes orbites)

| orbite | S1A | S1C | S1D |
|:-------|----:|----:|----:|
| A030   |  42 |  12 |  12 |
| D008   |  45 |  13 |  11 |
| D081   |  42 |  11 |  10 |

Dates par orbite relative et par capteur, 2025-01-01 au 2026-11-21

La bascule se lit le 2026-06-29 (dernière image 1A, orbite D008) et le
2026-06-30 (première image 1C, même orbite). Après elle, 1C et 1D
**alternent à 6 jours sur chaque orbite** (une image de chaque, tous les
12 jours), alors que 1A seul revenait tous les 12 jours : la cadence
double. Quelques trous de 12 à 24 jours subsistent (une date de 1D
manquante, par exemple le 2026-07-18 sur D008).

| orbite | periode        | ecart_moyen_j | ecart_max_j |
|:-------|:---------------|--------------:|------------:|
| A030   | après (1C, 1D) |           6,3 |          13 |
| D008   | après (1C, 1D) |           6,0 |          12 |
| D081   | après (1C, 1D) |           6,9 |          19 |
| A030   | avant (1A)     |          12,9 |          24 |
| D008   | avant (1A)     |          12,3 |          24 |
| D081   | avant (1A)     |          12,9 |          24 |

Écart entre dates successives d’une orbite, en jours

## Question 2 : la chaîne va-t-elle au bout

Oui. Une seule exécution, du 2018-01-01 au 2026-11-21, sans erreur.

| Mesure                                                  | Valeur |
|:--------------------------------------------------------|:-------|
| Images lues                                             | 809    |
| Orbites                                                 | 3      |
| Orbites écartées                                        | 0      |
| Objets, passe 2019 (corrigée)                           | 100    |
| Objets, détection                                       | 301    |
| Objets gardés (compte de la tuile, avant ré-étiquetage) | 399    |
| Objets de la carte finale                               | 287    |
| Bandes                                                  | 3      |
| Disque maximal (Mo)                                     | 1 509  |
| Durée (min)                                             | 38,0   |

Le jeton SAS a été renouvelé en cours de lecture sans refus (mission
025) : aucun 403. Un seul avertissement, déjà vu aux exécutions
précédentes : « 1 fichier sans métadonnées d’unité (lu comme gamma0
linéaire) » ; les métadonnées d’une image 1A (2026-06-29), d’une 1C
(2026-06-30) et d’une 1D (2026-07-06) déclarent toutes
`SARPixelContent = intensity` et `Scale = linear` : l’unité ne change
pas au passage de capteur (le fichier sans métadonnées n’a pas été
identifié ici).

## Question 3 : continuité du signal

**Méthode.** Une fenêtre de 300 × 300 pixels (9 km²) de la tuile,
choisie comme celle qui contient le plus de pixels « stables » (dans le
masque forêt, à plus de 3 pixels de tout objet détecté, avant comme
après la bascule ; 80,8 % de la fenêtre). Toutes les images de
2018-01-01 au 2026-11-21 y sont relues. Pour chaque orbite et chaque
date : le VH moyen (linéaire, exprimé en dB) et le ratio de changement
de la définition du package (rapport de la moyenne des 3 images
suivantes à la moyenne de toutes les images jusqu’à la date, en dB),
dont on garde la médiane, l’écart robuste (écart interquartile / 1,349)
et la part de pixels sous tp = −3,45 dB et sous ts = −5,175 dB. Saison
S2 = juillet à novembre (la seule comparable avant et après la bascule)
; S1 = janvier à juin.

| orbite | annee | VH_S1_dB | VH_S2_dB | S2_moins_S1 |
|:-------|------:|---------:|---------:|------------:|
| A030   |  2022 |   -14,27 |   -14,41 |       -0,14 |
| A030   |  2023 |   -14,22 |   -14,16 |        0,06 |
| A030   |  2024 |   -14,04 |   -14,14 |       -0,10 |
| A030   |  2025 |   -13,93 |   -13,96 |       -0,03 |
| A030   |  2026 |   -13,71 |   -14,36 |       -0,65 |
| D008   |  2022 |   -14,85 |   -14,80 |        0,05 |
| D008   |  2023 |   -14,68 |   -14,65 |        0,03 |
| D008   |  2024 |   -14,50 |   -14,65 |       -0,15 |
| D008   |  2025 |   -14,51 |   -14,41 |        0,10 |
| D008   |  2026 |   -14,51 |   -14,67 |       -0,16 |
| D081   |  2022 |   -14,41 |   -14,37 |        0,04 |
| D081   |  2023 |   -14,14 |   -14,03 |        0,11 |
| D081   |  2024 |   -13,96 |   -14,03 |       -0,07 |
| D081   |  2025 |   -13,85 |   -14,03 |       -0,18 |
| D081   |  2026 |   -13,95 |   -14,68 |       -0,73 |

Niveau VH moyen (dB) des pixels stables. 2022 à 2025 : 1A seul ; S2 2026
: 1C et 1D

| orbite | ecart_S2_2026 | sd_annees_S2 | ecart_S1_2026 | sd_annees_S1 |
|:-------|--------------:|-------------:|--------------:|-------------:|
| A030   |         -0,19 |         0,18 |          0,40 |         0,16 |
| D008   |         -0,04 |         0,16 |          0,12 |         0,17 |
| D081   |         -0,57 |         0,17 |          0,14 |         0,24 |

2026 contre la moyenne 2022-2025 (dB) et écart-type des quatre années

| serie | capteur | niveau_db |
|:------|:--------|----------:|
| A030  | S1C     |    -14,37 |
| D008  | S1C     |    -14,66 |
| D081  | S1C     |    -14,68 |
| A030  | S1D     |    -14,35 |
| D008  | S1D     |    -14,68 |
| D081  | S1D     |    -14,68 |

Niveau VH (dB), S2 2026, par capteur

**Lecture du niveau.** 1C et 1D s’accordent entre eux (écart de 0,01 à
0,03 dB sur chaque orbite). Face aux quatre années 1A de la même saison,
l’orbite A030 est à −0,19 dB (dans la variation entre années, 0,18 dB),
D008 à −0,04 dB (dans la variation), D081 à −0,57 dB (3,4 fois
l’écart-type entre années). Les images de janvier à juin 2026, toutes en
1A, sont déjà plus claires que les années précédentes sur A030 (+0,40
dB) : l’écart entre saisons de 2026 mélange donc du temps qu’il fait et
un éventuel changement d’instrument. **Le niveau seul ne permet pas de
conclure à un saut d’étalonnage ; il n’exclut pas un décalage de l’ordre
de 0,5 dB sur une orbite.**

| serie | groupe             | ratio_med | ratio_sd | sous_tp_pct | sous_ts_pct | dates |
|:------|:-------------------|----------:|---------:|------------:|------------:|------:|
| A030  | Ma en 1A (2025)    |    0,1532 |   1,1112 |        0,12 |        0,00 |    14 |
| A030  | Ma en 1A (2026)    |    0,4343 |   1,1121 |        0,07 |        0,00 |    11 |
| A030  | Ma en 1C/1D (2026) |   -0,2877 |   1,2636 |        1,07 |        0,04 |    22 |
| A030  | Ma mixte (2026)    |   -0,0312 |   1,1561 |        0,33 |        0,01 |     2 |
| D008  | Ma en 1A (2025)    |    0,2324 |   0,9794 |        0,03 |        0,00 |    16 |
| D008  | Ma en 1A (2026)    |   -0,0504 |   0,9881 |        0,07 |        0,00 |    11 |
| D008  | Ma en 1C/1D (2026) |   -0,1523 |   1,1560 |        0,45 |        0,01 |    22 |
| D008  | Ma mixte (2026)    |    0,5074 |   1,0617 |        0,02 |        0,00 |     2 |
| D081  | Ma en 1A (2025)    |    0,0383 |   1,0972 |        0,18 |        0,00 |    15 |
| D081  | Ma en 1A (2026)    |    0,3371 |   1,0994 |        0,09 |        0,00 |    10 |
| D081  | Ma en 1C/1D (2026) |   -0,5536 |   1,1558 |        1,16 |        0,02 |    19 |
| D081  | Ma mixte (2026)    |   -0,0490 |   1,1204 |        0,24 |        0,00 |     2 |

Ratio de changement des pixels stables, selon les capteurs de la fenêtre
« après » (Ma), de juillet 2025 à novembre 2026

**Lecture du ratio.** Ici la rupture se lit surtout dans la queue de la
distribution, moins dans la médiane (qui varie de ± 0,5 dB au fil des
saisons, voir la figure). Tant que la fenêtre « après » (les 3 images
suivantes) ne contient que des images 1A, le ratio de 2026 est celui de
2025 (écart robuste 1,11, 0,99 et 1,10 dB ; part sous tp de 0,07 à 0,09
%). Dès que la fenêtre ne contient plus que des images 1C/1D, la médiane
du ratio tombe de 0,4 à 0,6 dB sous celle de la même saison de 2025,
l’écart robuste augmente de 5 à 17 % et **la part de pixels sous tp
passe à 0,45 à 1,2 %, soit 6 à 15 fois plus qu’en 1A** (sous ts : 0,01 à
0,04 % des pixels stables et par date, contre 0 en 2022-2025). La
dispersion spatiale du niveau d’une image seule est pourtant la même en
1A, 1C et 1D (voir le tableau suivant) : ce qui change, c’est l’écart
pixel par pixel entre les moyennes « après » (1C/1D) et « avant » (1A),
pas le bruit d’une image.

| serie | capteur | sd_db |
|:------|:--------|------:|
| A030  | S1A     |  1,97 |
| D008  | S1A     |  1,79 |
| D081  | S1A     |  1,97 |
| A030  | S1C     |  1,96 |
| D008  | S1C     |  1,96 |
| D081  | S1C     |  1,97 |
| A030  | S1D     |  1,95 |
| D008  | S1D     |  1,96 |
| D081  | S1D     |  1,97 |

Écart-type spatial du niveau VH d’une image (dB), pixels stables, depuis
2025

Version Markdown : la figure (médiane du ratio par date et par orbite)
est dans le PDF.

## Question 4 : coupes détectées et délai

| trimestre         | objets | surface_ha |
|:------------------|:-------|-----------:|
| 2024T1            | 4      |        5,8 |
| 2024T2            | 3      |        2,0 |
| 2024T3            | 1      |        5,7 |
| 2024T4            | 5      |       13,2 |
| 2025T1            | 6      |      126,0 |
| 2025T2            | 3      |        8,1 |
| 2025T3            | 12     |       55,0 |
| 2025T4            | 3      |       10,3 |
| 2026T1            | 17     |      109,1 |
| 2026T2            | 16     |       70,5 |
| 2026T3            | 77     |       77,0 |
| 2026T4            | 1      |        0,2 |
| moyenne 2019-2024 | 6,3    |       42,2 |

Objets par trimestre (date médiane de l’objet)

| mois    | objets | surface_ha |
|:--------|-------:|-----------:|
| 2025-11 |      1 |        0,8 |
| 2025-12 |      2 |        9,5 |
| 2026-03 |     17 |      109,1 |
| 2026-04 |      6 |        8,0 |
| 2026-05 |      3 |        3,3 |
| 2026-06 |      7 |       59,1 |
| 2026-07 |     65 |       69,3 |
| 2026-08 |      3 |        2,8 |
| 2026-09 |      9 |        4,9 |
| 2026-10 |      1 |        0,2 |

Objets datés après 2025-09-30, par mois

Le mois de juillet 2026 porte à lui seul 65 objets (69,3 ha), alors que
le trimestre moyen de 2019 à 2024 en compte 6 à 7. Les dates de ces
objets se rangent sur la **première image 1C/1D de chaque orbite**
(2026-06-30 sur D008, 2026-07-01 sur A030, 2026-07-11 sur D081), puis
sur les suivantes. C’est la signature d’un décalage du ratio qui
franchit le seuil dès que la fenêtre « après » devient 1C/1D, pas celle
de coupes réparties dans le temps ; mais c’est une inférence, pas une
preuve.

| date       | pixels |
|:-----------|-------:|
| 2026-07-01 |   4904 |
| 2026-07-17 |   3067 |
| 2026-07-11 |   2119 |
| 2026-07-07 |   1722 |
| 2026-07-13 |    829 |
| 2026-07-24 |    578 |

Dates qui portent le plus de pixels, du 2026-06-30 au 2026-07-30

| orbite | premiere_image_1C_1D |
|:-------|:---------------------|
| A030   | 2026-07-01           |
| D008   | 2026-06-30           |
| D081   | 2026-07-11           |

Première image 1C ou 1D de chaque orbite

| periode | objets | ratio_moyen_mediane_dB | surface_mediane_ha | part_sous_1_ha |
|:---|---:|---:|---:|---:|
| 2019 à 2025-09 | 173 | -4,28 | 2,37 | 0,31 |
| 2025-10 à 2026-06-29 | 34 | -4,28 | 0,84 | 0,56 |
| 30 jours après la bascule | 67 | -4,27 | 0,49 | 0,75 |
| plus de 30 jours après la bascule | 13 | -4,42 | 0,33 | 0,77 |

Nature des objets selon la période de leur date

Le ratio moyen des objets ne distingue pas les périodes (médiane de −4,3
à −4,4 dB partout) : les objets de juillet 2026 sont **plus petits**
(médiane 0,5 ha, 75 % sous 1 ha contre 31 % de 2019 à 2025-09) mais pas
plus faibles en ratio. Les chiffres seuls n’établissent donc pas qu’ils
sont faux : c’est le rôle du contrôle sur le terrain.

**Délai de détection (Xa = 3 images).** Délai = jours entre la date de
l’objet et la 3e image disponible à partir d’elle, sur la meilleure
orbite (combinaison `minimum`).

| periode              | objets | delai_moyen_j | delai_max_j |
|:---------------------|-------:|--------------:|------------:|
| 2025-10 a 2026-06-29 |     34 |          23,3 |          32 |
| apres 2026-06-30     |     80 |          12,0 |          13 |

Délai jusqu’à la 3e image, objets datés après 2025-09-30

| orbite | avant_j | apres_j |
|:-------|--------:|--------:|
| A030   |    25,6 |    12,0 |
| D008   |    23,9 |    12,5 |
| D081   |    25,9 |    12,6 |

Durée de trois images consécutives (jours), moyenne par orbite, avant et
après la bascule (depuis 2025-01)

Le délai **est tenu, et même raccourci** à la reprise : 12 jours au lieu
de 24 environ, parce que 1C et 1D alternent. Dernier jour détectable le
2026-11-09 (3e image avant la fin, meilleure orbite) : les coupes de la
dernière semaine servie ne peuvent pas encore l’être. Ce
raccourcissement joue dans les deux sens : il accélère aussi les faux
positifs.

## Stabilité des dates : 2025-01 à 2025-09 contre la mission 017

Le test de la mission demandait que, sur 2025-01 à 2025-09, les
détections soient celles de 017. **Il échoue.** 017 s’arrêtait au
2025-09-30 ; ici la série continue jusqu’en novembre 2026.

| Mesure                                                  | Valeur |
|:--------------------------------------------------------|:-------|
| Pixels datés de 2025-01 à 2025-09, 017                  | 11 751 |
| Pixels datés de 2025-01 à 2025-09, 029                  | 8 603  |
| Dans les deux, même date                                | 4 908  |
| Dans les deux, date différente                          | 1 633  |
| Seulement en 017 (daté ailleurs ou plus du tout en 029) | 5 210  |
| Seulement en 029                                        | 2 062  |
| Objets datés de 2025-01 à 2025-09, 017                  | 7      |
| Objets datés de 2025-01 à 2025-09, 029                  | 21     |

| date_029                               | pixels |
|:---------------------------------------|-------:|
| 2025-01 à 2025-09 (même date ou autre) |   6541 |
| 2025-10 à 2025-12                      |     54 |
| 2026                                   |   4453 |
| avant 2025                             |    703 |

Pixels datés de 2025-01 à 2025-09 en 017 : leur date dans cette
exécution

| mois_029 | pixels |
|:---------|-------:|
| 2025-09  |    922 |
| 2026-03  |   3740 |
| 2026-04  |    616 |
| 2026-07  |   3515 |
| 2026-09  |   1063 |
| 2026-10  |    361 |

Pixels de 017 re-datés plus tard en 029 (mois d’arrivée de plus de 300
pixels)

| Pixels                                         | Nombre  |
|:-----------------------------------------------|:--------|
| datés par 017 : total                          | 104 165 |
| re-datés plus tard en 029                      | 12 698  |
| re-datés plus tôt en 029                       | 2 039   |
| dont, datés de 2025 en 017, passés à 2019-2024 | 703     |
| même date                                      | 89 428  |
| plus datés du tout                             | 0       |
| datés en 029 seulement, avant le 2025-09-30    | 11 346  |

Dates de 029 par rapport à celles de 017

Ce que je mesure : sur 104 165 pixels datés par 017, 12 698 (12,2 %)
sont re-datés plus tard, 2 039 plus tôt, aucun n’est perdu. En outre 11
346 pixels nouveaux sont datés d’avant le 2025-09-30 (en 017, ils
n’étaient pas datés).

Les arrivées plus tardives se concentrent sur **mars 2026** (sans lien
avec le capteur : toutes les images y sont en 1A) et sur **juillet
2026** (bascule). **Une partie** s’explique par la règle du package : un
pixel garde la date du minimum de son ratio sur toute la série, de sorte
qu’une chute plus profonde, plus tard, sur un pixel déjà coupé (nouvelle
opération, ou décalage du ratio), déplace sa date vers plus tard. **La
règle n’explique ni les re-datages vers plus tôt, ni les pixels nouveaux
datés d’avant septembre 2025** : un minimum global ne peut que rester ou
se déplacer vers un point plus bas, il ne devrait pas apparaître plus
tôt pour un pixel déjà daté. Autre écart relevé, sans que j’en mesure
l’effet : la recherche STAC rend aujourd’hui 813 tranches d’images pour
2018-01-01 à 2025-09-30 contre 815 dans le journal de 017, pour les
mêmes 676 dates (les tranches de S1A du 2018-05-23 et du 2020-01-13 ne
sont plus servies). **La cause de ces écarts reste ouverte.**
Conséquence pour l’usage : une date publiée peut changer quand on
prolonge la série. Je ne propose pas de changer la règle ici (choix de
méthode) ; je signale à Pascal que 017 et 029 ne se recouvrent pas.

## Causes : où mettre la main

Objets datés après 2025-09-30, rangés par cause **probable** (les causes
sont des hypothèses, la mesure ne les établit pas) :

| cause | nombre | % | % cumulé |
|:---|---:|---:|---:|
| Fenêtre de 30 jours après la bascule 1A vers 1C/1D (décalage du ratio, hypothèse) | 67 | 58,8 | 58,8 |
| Autres dates (cause inconnue) | 30 | 26,3 | 85,1 |
| Mars 2026 (événement non expliqué : 3 726 pixels le 2026-03-26) | 17 | 14,9 | 100,0 |

Le trait ne peut tomber qu’après la première cause : 67 objets sur 114
(59 %) tombent dans la fenêtre des 30 jours après la bascule, ce qui est
moins que l’essentiel ; le changement de capteur en est l’hypothèse, non
établie. La ligne « cause inconnue » (26 %, une trentaine d’objets
dispersés sur huit mois) vient en second et mars 2026 (15 %) en dernier
: la cause inconnue n’est pas en tête, on peut donc agir sur la première
sans mieux observer d’abord, mais **un quart des objets reste sans
explication**.

## Les trois coupes à contrôler

À contrôler par Pascal sur Sentinel-2 ou orthophoto récente. Choix :
parmi les objets des 30 jours qui suivent la bascule, les deux plus
grands **dont au moins 75 % des pixels datés le sont à partir du
2026-06-30**, et le plus grand objet plus tardif, hors de cette fenêtre
(témoin). Date = date médiane de l’objet (première image après la
chute).

| identifiant | surface_ha | date_mediane | date_au_centroide | part_apres | lon | lat | x_l93 | y_l93 | attendu |
|---:|---:|:---|:---|---:|---:|---:|---:|---:|:---|
| 198 | 2,43 | 2026-07-11 | 2026-07-06 | 0,85 | -0,76208 | 44,17152 | 399280 | 6348555 | coupe ou non ? |
| 206 | 6,87 | 2026-07-11 | 2026-07-24 | 0,76 | -0,74394 | 44,16989 | 400720 | 6348305 | coupe ou non ? |
| 234 | 2,21 | 2026-08-17 | 2026-08-11 | 0,74 | -0,81803 | 44,15827 | 394740 | 6347300 | témoin hors fenêtre |

`part_apres` est la part des pixels datés de l’objet qui le sont à
partir du 2026-06-30 ; `date_au_centroide` est la date du pixel au
centroïde de l’objet.

**Pourquoi pas les deux plus grands.** L’objet 192 (14,17 ha, date
médiane 2026-06-30) est **mixte** : sur ses 1 285 pixels datés, 635 le
sont avant la bascule (77 au seul 2023-02-09) et le pixel au centroïde
est daté du 2026-05-17. Il juxtapose donc une partie déjà dégagée avant
la bascule et une partie datée après : sa date médiane n’a pas de sens
pour un contrôle. L’objet 174 (11,4 ha) l’est aussi, à un moindre degré
(73 % après la bascule). Si Pascal veut les voir, la règle de lecture
est de regarder séparément la partie datée avant la bascule (déjà nue
sur une image d’avant juillet 2026 ?) et celle datée après (encore en
forêt avant juillet 2026, nue après ?) : seule la seconde relève du
changement de capteur.

Lecture pour les trois objets retenus : une coupe rase récente se voit
sur Sentinel-2 comme une tache sans végétation (sol nu, résidus), à
partir de la date indiquée et pas avant. Si 198 et 206 sont encore en
forêt sur une image de septembre ou octobre 2026, ce sont des faux
positifs du changement de capteur.

## Limites et écarts

- **Une tuile, une fenêtre de 9 km², une année avec 1C/1D** : les
  décalages mesurés (0,4 à 0,6 dB, 6 à 15 fois plus de pixels sous tp)
  sont ceux de cette zone et de cette saison. Rien ne sépare
  l’étalonnage du temps qu’il fait ou de la géométrie (les orbites
  relatives sont les mêmes, mais rien ne garantit des passages au mètre
  près).
- **Pas de vérité de terrain** : aucune des coupes postérieures au
  2026-06-30 n’est vérifiée.
- Le critère de « pixel stable » (hors des objets détectés, faux
  positifs compris) retire par construction les pixels qui ont franchi
  le seuil : il **sous-estime** la part sous tp des fenêtres 1C/1D, ce
  qui va dans le sens prudent.
- Le **test de la mission** (« sur 2025-01 à 2025-09, les détections
  sont celles de 017 ») est faux tel qu’écrit : voir « Stabilité des
  dates ». Il aurait fallu écrire « sur la même période et avec la même
  fin de série ».
- La mission demandait une période « 2025-01-01 au dernier mois » ; la
  lecture part de 2018-01-01 (raison en tête de rapport), ce qui
  rallonge le calcul mais garde la référence de 017.
- Le « dernier mois disponible » est novembre 2026, incomplet (au
  2026-11-21).

## Ce que je propose

1.  **Mesurer le décalage 1A vers 1C/1D sur plus large**, avant toute
    décision de réglage. Mission `analyste` : *mesurer, sur au moins
    trois tuiles de forêt stable de régions différentes, le décalage
    médian du ratio entre fenêtres 1A et 1C/1D par orbite, et dire s’il
    est constant.* Cause : le passage de capteur (hypothèse : 59 % des
    objets récents tombent dans la fenêtre des 30 jours qui suit la
    bascule).
2.  **Si le décalage est constant, un paramètre exposé de recalage**
    (valeur par défaut 0, comme les autres réglages), jamais une
    correction muette. Mission `dev` : *ajouter à `parametres_sufosat()`
    un recalage en dB du ratio entre capteurs 1A et 1C/1D, valeur par
    défaut 0, avec test d’aller-retour.* À Pascal de trancher
    (changement de réglage).
3.  **Contrôler les trois coupes**, puis, si les deux premières sont
    fausses, ne pas publier les détections postérieures au 2026-06-30
    avant l’action 1 (arbitrage n° 3 du brief, à Pascal).

Les autres causes attendent leur tour : mars 2026 (17 objets, 109 ha,
cause inconnue) ; le re-datage des pixels quand la série est prolongée
(12 % des pixels de 017), à nommer en décision de méthode plutôt qu’en
défaut.

**Question de contrôle.** Quelles sont les deux ou trois causes sur
lesquelles agir ? Le passage de capteur 1A vers 1C/1D (hypothèse, 59 %
des objets récents dans la fenêtre des 30 jours après la bascule),
l’absence de vérité de terrain sur les détections 2026 et, à décider, le
re-datage des pixels quand la série est prolongée.
