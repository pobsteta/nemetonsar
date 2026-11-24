# Deux règles de date essayées sur les séries relevées : mission 027

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il contient des chiffres agrégés et, pour les 7 pixels
> tracés (coordonnées L93 données pour le contrôle sur orthophoto), le mois de la date publiée
> par la v3.0.1. Il ne contient aucune autre valeur de pixel de la v3.0.1.

Analyste, 2026-11-24, sur le poste de Pascal. Script : [`regles-de-date.R`](regles-de-date.R)
(étapes `calculer`, `mesurer`, `tracer`). Points de départ :
[`ecarts-date-v301.md`](ecarts-date-v301.md) (024) et [`cause-dates-tardives.md`](cause-dates-tardives.md) (026).

**Problème, en une phrase.** Sur la tuile pilote des Landes, si la date d'un pixel n'est plus celle du
minimum du ratio de datation de l'orbite retenue, mais la première date où le ratio passe sous un seuil
(seuil de datation distinct, date tirée de toutes les orbites, ou les deux), de combien se rapproche-t-on de
la v3.0.1 et que perd-on ?

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Entrées | Les séries relevées par la mission 026 (30 blocs, 3 orbites A030, D008, D081, ratios de détection et de datation à toutes les dates, en centièmes de dB). **Aucune lecture Sentinel-1, package inchangé.** Durée : `calculer` 2 min 20 s, `mesurer` quelques secondes |
| Pixels | 54 160 pixels datés dans les deux cartes (les mêmes qu'en 024 et 026) : 25 181 tardifs (> +180 j), 14 293 « retrouvés » (témoin, ≤ 15 j), 14 686 autres. Pour les objets : les 103 804 pixels datés de la tuile |
| Contrôle de la règle actuelle | Recalculée depuis les séries, elle redonne la date de la carte de 017 pour **53 659 pixels sur 54 160** (99,1 %) ; 389 s'en écartent de plus de 15 j. Sur la tuile : 102 635 pixels sur 103 804 identiques (98,9 %). Au premier essai (une exécution du script avant l'ajout de la passe 2019, non conservée), 87 % seulement : les 6 559 pixels datés de 2019 par la carte viennent de la **passe 2019** (série coupée à fin 2019 plus 3 images), pas de la passe principale. Le script refait cette passe (ratios des dates de 2019 seuls, orbite retenue sur cette fenêtre) pour les pixels que la carte date de 2019 |
| Contrôle du ratio de détection | Le minimum du ratio de détection recalculé égale `ratio.tif` de la tuile (à 0,006 dB) pour **59 960 pixels sur 60 075** hors passe 2019 |
| Contrôle croisé de 024 (fait hors script, par lecture du rapport de 024) | La règle « première date sous tp sur l'orbite retenue » (ligne de référence ci-dessous) redonne les 33,4 % de dates retrouvées de la règle `premiere_datation` de 024, calculée par un autre code en relançant le pipeline. La part de tardifs concorde aussi (30,9 % contre 31,0 %) |
| Contrôle indépendant (fait hors script, par un court calcul à part dans le dossier de session, non versé) | Sur les 14 pixels de `pixels_traces.rds` (séries relues par un autre chemin), les dates de R0, R1 et R3 sont identiques à celles du calcul par blocs : 14 sur 14 |

## Les règles

Écart de date = date de la règle moins date publiée, en jours. Dates = `d_(i+1)`, comme le package.

| Règle | Définition |
|---|---|
| **R0** | Actuelle : orbite retenue = minimum du ratio de détection ; date = minimum du ratio de datation sur cette orbite (recalculée, contrôlée ci-dessus) |
| **R1** | Seuil de datation distinct : première date où le ratio de datation de l'orbite retenue est ≤ **−3,0 dB** (sans le facteur 1,15) ; détection inchangée |
| **R2** | Date multi-orbites : première date où l'une quelconque des trois orbites a un ratio de datation ≤ **−3,45 dB** (seuil effectif de la détection) |
| **R3** | Les deux : première date où l'une quelconque des orbites est ≤ −3,0 dB |

**Lecture du brief.** La fiche écrit « seuil de datation distinct du seuil de détection (−3,0 dB) ». Le seuil
de détection effectif est −3,45 dB (`tp_db` = −3,0 dB, fois le facteur 1,15) ; −3,0 dB est `tp_db` sans le facteur. J'ai
donc pris −3,0 dB pour la datation, et −3,45 dB pour « le seuil de datation actuel » de la règle 2. Si Pascal visait
autre chose, `S_DATE` et `TP` se changent en tête du script.

**Repli.** Un pixel détecté n'a pas toujours un ratio de datation sous le seuil. Il garde alors la date de R0. Les pixels
concernés sont comptés (colonne « sans passage »). Le choix du repli est à Pascal : sans repli, ces pixels n'auraient pas de date.

**Essais de seuil (sensibilité, pas un réglage retenu).** Le script mesure aussi la première date à −2,5, −3,45
et −4,0 dB, sur l'orbite retenue (R1) et sur toutes les orbites (R3). **Valeurs provisoires** : elles servent à lire
l'effet du seuil, pas à en choisir un sur ces pixels.

## Ce qu'il faut lire d'abord : la base de mesure

Les groupes « tardifs » et « retrouvés » sont définis par le **résultat de la règle actuelle** : les tardifs sont les
pixels où R0 date mal, les retrouvés ceux où R0 date bien. Toute autre règle a donc, par construction, de la marge sur
les premiers et ne peut que perdre sur les seconds (retour à la moyenne). C'est le même défaut de sélection que la
persistance de 026. Je donne ces deux groupes comme **devenir** de pixels connus, et je juge les règles sur les
**54 160 pixels communs**, qui ne sont pas choisis d'après R0. La v3.0.1 n'est pas une vérité terrain : être proche d'elle
n'est pas avoir raison (026 : elle date elle aussi des événements de fin d'hiver).

## Résultats : tous les pixels communs (54 160), base de jugement

| Règle | ≤ 15 j | ≤ 60 j | Tardif (> +180 j) | Précoce (< −180 j) | Écart médian signé (j) | Écart absolu médian (j) | Dates changées | Sans passage (repli R0) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| R0 actuelle | 26,5 % | 39,9 % | 46,4 % | 3,9 % | +101 | 191 | 0 | 0 |
| R1 seuil −3,0 dB, orbite retenue | 33,4 % | 53,5 % | 21,8 % | 10,7 % | 0 | 48 | 32 962 | 4 480 |
| **R2 toutes orbites, −3,45 dB** | **36,5 %** | **57,2 %** | **19,2 %** | 9,7 % | 0 | **36** | 38 472 | 5 282 |
| R3 toutes orbites, −3,0 dB | 29,5 % | 50,0 % | 10,8 % | **24,3 %** | −13 | 60 | 45 656 | 1 602 |
| *Référence 024 : orbite retenue, −3,45 dB* | 33,4 % | 51,0 % | 30,9 % | 5,6 % | +13 | 59 | 22 962 | 10 651 |

Pixels qui entrent dans les « ≤ 15 j » ou en sortent par rapport à R0 :

| Règle | Gagnés | Perdus | Net |
|---|---:|---:|---:|
| R1 | 7 033 | 3 258 | **+3 775** |
| R2 | 9 701 | 4 244 | **+5 457** |
| R3 | 9 166 | 7 548 | +1 618 |

**Stabilité.** Sur les deux moitiés de la tuile (nord, sud), la part à ≤ 15 j de R2 (37,7 % et 35,4 %) reste devant
celle de R1 (33,0 % et 33,8 %), de R0 (23,6 % et 29,3 %) et de R3 (32,0 % et 26,9 %, ce dernier au sud sous R0).

**D'où vient le gain ?** Presque tout vient du passage du **minimum** à la **première date** sous le seuil (ligne de
référence 024 : 33,4 % contre 26,5 %). Le seuil distinct à −3,0 dB n'ajoute rien à ≤ 15 j (33,4 % dans les deux cas), un peu à
≤ 60 j (+2,5 points), et réduit les tardifs (21,8 % contre 30,9 %) au prix de 5 points de précoces de plus. Tirer
la date de toutes les orbites à −3,45 dB (R2) ajoute 3,1 points à ≤ 15 j et 6,2 à ≤ 60 j par rapport à la même règle sur l'orbite
retenue, avec 4 points de précoces de plus. Les deux ensemble (R3) dépassent : une orbite passe sous −3,0 dB sur un
creux faible bien avant l'événement, et un pixel sur quatre est daté plus de 180 j trop tôt.

## Résultats : tardifs et retrouvés (devenir, conditionnés par R0)

| | R1 | R2 | R3 |
|---|---:|---:|---:|
| Tardifs (25 181) ramenés à ≤ 15 j | 5 135 (**20,4 %**) | 6 444 (**25,6 %**) | 5 983 (**23,8 %**) |
| Tardifs ramenés à ≤ 60 j | 8 657 (**34,4 %**) | 10 333 (**41,0 %**) | 10 146 (**40,3 %**) |
| Restent tardifs (> +180 j) | 11 811 (46,9 %) | 9 899 (39,3 %) | 5 657 (22,5 %) |
| Deviennent précoces (< −180 j) | 1 870 | 1 799 | 5 652 |
| Écart médian signé des tardifs (j) | +137 | +47 | −1 |
| Dates retrouvées (14 293) **perdues** (> 15 j) | 3 261 (**22,8 %**) | 4 237 (**29,6 %**) | 7 530 (**52,7 %**) |
| — perdues à plus de 60 j | 1 315 (9,2 %) | 1 775 (12,4 %) | 4 380 (30,6 %) |
| — dont devenues précoces de plus de 15 j | 3 257 | 3 794 | 7 354 |
| Écart médian signé des retrouvés (j) | −11 | −11 | −20 |

Les dates « perdues » le sont presque toutes **vers le précoce** : la première date sous le seuil précède le
minimum, que la v3.0.1 date mieux quand le creux est net. Sous R0, 16 pixels des retrouvés sont « perdus » :
c'est l'écart du contrôle (recalcul contre carte), non une règle.

**Par classe de 024 (ramenés à ≤ 15 j ; entre parenthèses, à ≤ 60 j).**

| Groupe | Pixels | R1 | R2 | R3 |
|---|---:|---:|---:|---:|
| Début de série (v3.0.1 en 2018) | 2 822 | 0 (0) | 0 (0) | 0 (0) |
| Retrouvés par la première détection, ≤ 15 j (024) | 4 896 | 53,9 % (70,5 %) | 48,2 % (67,8 %) | 38,1 % (58,8 %) |
| Retrouvés par la première détection, 16 à 60 j (024) | 4 163 | 22,4 % (61,5 %) | 30,8 % (63,7 %) | 29,2 % (57,6 %) |
| Plus datés (024) | 196 | 9,7 % (17,3 %) | 3,6 % (8,7 %) | 7,7 % (24,0 %) |
| Reste non établi (026) | 13 104 | 11,8 % (19,9 %) | 21,3 % (33,2 %) | 22,0 % (36,8 %) |

**Le reste de 026, par situation à la date publiée (pixels ramenés à ≤ 15 j, sur ≤ 60 j).**

| Situation (026) | Pixels | R1 | R2 | R3 |
|---|---:|---:|---:|---:|
| Proche du seuil | 7 080 | 1 109 sur 1 639 | 1 407 sur 2 251 | 1 681 sur 2 731 |
| Loin du seuil | 3 359 | 147 sur 357 | 144 sur 472 | 257 sur 689 |
| Autre orbite à l'heure | 2 449 | 256 sur 573 | **1 212 sur 1 569** | 932 sur 1 365 |
| Orbite retenue sous tp à P, passage plus ancien | 182 | 14 sur 23 | 16 sur 35 | 7 sur 18 |

La règle multi-orbites traite bien la cause « autre orbite » (49,5 % des pixels ramenés à ≤ 15 j, contre 10,5 % pour R1) ;
le seuil distinct traite un peu la cause « proche du seuil » (15,7 %), et R2 un peu mieux (19,9 %) parce qu'elle lit les trois
orbites. La classe « loin du seuil » ne bouge pas : aucune règle de date ne la touche (elle demande d'observer, mission 028).

## Pareto de ce qui reste : tardifs à plus de 60 j de la date publiée, sous R2

Sur les 25 181 tardifs, **14 848** restent à plus de 60 j (en valeur absolue) sous R2 (25 140 sous R0, 16 524 sous R1,
15 035 sous R3). Par cause connue (groupes de 024 ; situation de 026 pour le reste) :

| Cause | Pixels | % | % cumulé |
|---|---:|---:|---:|
| Proche du seuil à P (signal faible, S1A seul) | 4 829 | 32,5 | 32,5 |
| Loin du seuil à P (rien à cette date) | 2 887 | 19,4 | 51,9 |
| Début de série (v3.0.1 datée de 2018, ratios dès 2019) | 2 822 | 19,0 | 70,9 |
| Règle à 15 j de 024, non retrouvés par R2 | 1 578 | 10,6 | 81,5 |
| Règle à 16–60 j de 024, non retrouvés par R2 | 1 512 | 10,2 | 91,7 |
| *— trait —* | | | |
| Autre orbite à l'heure | 880 | 5,9 | 97,6 |
| Plus datés | 179 | 1,2 | 98,8 |
| Orbite retenue sous tp, passage plus ancien | 147 | 1,0 | 99,8 |
| Orbite retenue sous tp à P selon le relevé | 9 | 0,1 | 99,9 |
| Pas d'image à ±15 j | 5 | 0,03 | 100,0 |

Le trait est mis après cinq lignes (91,7 %). Les lignes « règle à 15 j » et « règle à 16–60 j » de 024 sont des pixels que la première date sous tp du ratio de **détection** sur l'orbite retenue (024) ramenait à 60 j. R2 lit le ratio de **datation** sur toutes les orbites : elle en laisse 1 578 et 1 512 au-delà de 60 j (7,7 % et 6,6 % de chaque groupe sont devenus précoces). Elles pèsent 20,8 % du reste et sont à relire avant de coder R2. La cause « autre orbite » tombe de 2 449 à 880 pixels. Les trois causes qui comptent ensuite sont **proche du seuil**, **loin du seuil** et **début de série** (70,9 %).

## Détection et surface : ce qui est vérifié et ce qui ne l'est pas

- **Vérifié.** Aucune des règles ne lit le ratio de détection : le minimum du ratio de détection de chaque pixel, donc
  l'ensemble des pixels détectés avant segmentation, est le même sous R0, R1, R2 et R3 (59 960 pixels sur 60 075 égaux à
  `ratio.tif` hors passe 2019, les 115 autres : cause non recherchée). Les 103 804 pixels datés de la tuile
  gardent chacun une date sous les trois règles (avec le repli).
- **Non vérifié : la correction 2019 et l'assemblage.** `nemetonsar_run()` lit la **date médiane de chaque objet** : il
  retire de la forêt les pixels datés de 2019 par la première détection, relance la détection principale avec ce masque, et ne
  garde que les objets de la détection principale dont la date médiane n'est pas en 2019. Une règle « première date » date plus tôt :
  sur les 161 objets de la passe principale (61 916 pixels datés), **20 objets (1 782 pixels) sous R1, 14 (1 664) sous R2 et 52
  (7 315, soit 11,8 %) sous R3** auraient une date médiane en 2019, contre aucun sous R0. Leur sort (rester dans la passe principale, ou
  passer dans la passe 2019 avec le masque forêt corrigé) change la surface assemblée. Je ne peux pas le chiffrer sans relancer
  le pipeline (45 min de lecture Sentinel-1, hors de cette mission). **La surface détectée inchangée n'est donc pas démontrée** :
  c'est un point de contrôle à faire au codage.
- Les pixels que la carte date de 2019 (20 % des pixels communs) sont datés dans la **passe 2019** sous toutes les règles :
  les règles « première date » n'y changent la date que dans la fenêtre de 2019.
- La part des pixels communs dont la date tombe en 2019 passe de 20,3 % (R0) à 23,5 % (R1), 23,0 % (R2) et 30,6 % (R3) ; la v3.0.1
  en date 19,6 %.

## Pixels tracés

Les 7 pixels commentés en 026, sous chaque règle ; images hors dépôt
(`/home/pascal/dev/nemetonsar-donnees/m027/traces/`). Mois de la date publiée et mois de la date sous chaque règle.

| Point (L93) | Orbite retenue | Publiée | R0 | R1 | R2 | R3 | Orthophoto (lecture de 026) |
|---|---|---|---|---|---|---|---|
| 398525 ; 6351825 | A030 | 2020-04 | 2021-03 | **2020-03** | **2020-03** | **2020-03** | 2021 : sol labouré nu |
| 398595 ; 6348385 | D008 | 2022-04 | 2025-03 | **2022-02** | **2022-02** | **2022-02** | 2024 : coupé et replanté. R0 (2025) est postérieur à ce que montre l'ortho 2024 |
| 394175 ; 6352425 | D081 | 2019-06 | 2021-03 | 2021-03 | 2021-03 | 2021-03 | 2021 : coupé. Aucune règle ne rejoint la date publiée (été 2019, rien sur les séries) |
| 394465 ; 6350145 | A030 | 2020-08 | 2021-03 | 2021-03 | 2021-03 | 2021-03 | 2021 : sol travaillé. Les quatre règles datent le même événement réel |
| 394475 ; 6350815 | D008 | 2020-08 | 2022-02 | 2021-03 | 2020-12 | 2020-12 | Pixel de piste, 2021 : sol travaillé. R0 (2022) est postérieur à l'ortho 2021 |
| 393725 ; 6349945 | D008 | 2021-03 | 2023-02 | **2021-03** | **2021-03** | **2021-03** | 2021 : sol travaillé. R0 (2023) est postérieur |
| 393975 ; 6349765 | A030 | 2021-03 | 2021-03 | 2021-02 | 2021-02 | 2021-02 | Témoin : la règle actuelle retrouve la date, les trois autres la devancent d'un passage |

Sur les six pixels que R0 ne retrouve pas, les trois règles en rapprochent quatre de la date publiée (398525, 398595 et 393725 à environ deux mois ou moins ; 394475 à quatre mois avec R2 et R3 et sept avec R1, contre plus d'un an avec R0), n'en rapprochent presque pas un (394465, 12 jours) et pas du tout un (394175). Là où R0 date après une orthophoto qui montre déjà le sol travaillé ou la coupe (398595, 394475, 393725), R1 à R3 datent plus tôt, sans être contredites par elle. **Les dates de vol des orthophotos ne sont pas connues**
(028) : cela dit « R0 est trop tard », pas « R1 à R3 sont exactes ». Sur 398595 ; 6348385, R1 se déclenche sur un creux à peine sous le
seuil de datation (février 2022), deux mois avant la chute nette de la date publiée : c'est le défaut attendu d'une première date, qui se
déclenche sur le premier creux.

## Causes : rattachement et actions

| Cause | Branche | Ce que montre la mission |
|---|---|---|
| Date = minimum sur toute la série de la seule orbite retenue (un creux tardif profond l'emporte) | Méthode | Passer à la première date sous tp sur toutes les orbites (R2) gagne 10 points à ≤ 15 j sur les pixels communs et divise les tardifs par 2,4. C'est la cause en tête de celles qu'on peut corriger |
| Seuil de datation = seuil de détection, facteur 1,15 compris | Mesure | Un seuil de −3,0 dB sur la première date n'apporte pas de gain à ≤ 15 j par rapport à −3,45 dB sur la même règle ; il augmente les précoces. Pas la cause principale |
| Début de série (v3.0.1 datée de 2018 ; ratios à partir de 2019) | Méthode / Matière | Aucune règle n'y change rien (0 sur 2 822) ; 19 % de ce qui reste. Cause nommée en 024, non traitée |
| Proche du seuil à P | Mesure / Matière | 32,5 % de ce qui reste ; signal faible (−3,45 à −2,45 dB à P), S1A seul. Un seuil plus bas le traite mais date plus de la moitié des pixels plus de 180 j trop tôt (essai à −2,5 dB sur toutes les orbites : 51,8 % de précoces) |
| Loin du seuil à P | Milieu | 19,4 % de ce qui reste ; aucune règle de date n'y touche |

## Deux ou trois actions

1. **Coder la date « première date sous tp, toutes orbites » (R2) comme règle exposée.**
   *Cause :* date tirée du minimum de l'orbite retenue seule. *Mission proposée :* « Coder dans le package une règle de date
   exposée (la règle actuelle restant le défaut tant que Pascal n'a pas tranché) qui date chaque pixel à la première date où
   l'une des orbites a un ratio de datation ≤ tp, avec repli sur le minimum, des tests (aller-retour `YYDDD`, repli, seuils en dB),
   puis vérifier par une exécution réelle de la tuile pilote que la surface assemblée et la correction 2019 ne changent que comme
   prévu par 027. » R1 et R3 ne sont pas à coder : R1 apporte 3 points de moins que R2 à ≤ 15 j, R3 date plus de 180 j
   trop tôt un pixel sur quatre. **C'est Pascal qui choisit la règle** ; R2 est ma proposition d'après les pixels communs.
2. **Trancher le périmètre du début de série.** *Cause :* 2 822 tardifs (19 % du reste après R2) dont la date publiée est en
   2018, alors que les ratios commencent en 2019 par construction (`annee_noyau + 1`). *Mission proposée :* « Lire dans Mermoz et al. (2024)
   comment la méthode date 2018 (noyau du filtre, premières images), puis chiffrer sur la tuile pilote ce qu'un départ en 2018
   changerait, pour que Pascal décide si 2018 est dans le périmètre. » C'est une décision de périmètre avant d'être du code.
3. **Mettre un arbitre indépendant de la v3.0.1 avant de régler « proche du seuil » et « loin du seuil ».** *Cause :* à elles deux,
   52 % de ce qui reste, et la v3.0.1 n'est pas une vérité. *Mission proposée :* « Étendre aux pixels « proche du seuil » (échantillon
   tiré avec une graine) la lecture Sentinel-2 et les dates de vol des orthophotos de la mission 028, pour dire laquelle des deux dates,
   la publiée ou celle de R2, tombe sur l'événement réel. » À lancer après 028.

**Les autres causes attendent leur tour :** seuil de datation distinct (à exposer au plus comme paramètre, sans valeur par défaut
nouvelle), S1A seul (cadence de 12 j sur les trois orbites, 3 images = 36 j contre 18 j avec S1B ; **non vérifié** que la source n'a pas
de S1B), masque neige et météo (non lus), objet FO0 (028), les 1 578 et 1 512 pixels de 024 que R2 ne ramène pas à 60 j.

## Limites

- Une AOI de 100 km² en pin maritime ; une tuile ; une période.
- La v3.0.1 n'est pas une vérité terrain : l'écart à elle mesure l'accord, pas l'exactitude. Les dates de vol des orthophotos sont inconnues.
- **Le repli sur R0 est un choix** : 8 à 10 % des pixels communs n'ont pas de passage sous le seuil sur l'orbite retenue (R1 : 4 480
  pixels ; R2 : 5 282). Un autre repli (pas de date, ou autre) donnerait d'autres chiffres.
- Valeurs relevées au centième de dB (« ≤ −3,45 » compte une valeur arrondie à −3,45, soit jusqu'à −3,445 dB).
- Les groupes tardifs et retrouvés sont conditionnés par R0 (voir « la base de mesure ») ; le jugement porte sur les pixels communs.
- Les essais de seuil (−2,5 ; −3,45 ; −4,0 dB) sont faits sur les mêmes pixels que la comparaison : ils indiquent une sensibilité, non un réglage.
- Le sort des objets dont la date passe en 2019 n'est pas simulé (voir « Détection et surface »).
- **Le choix de la passe de chaque pixel dépend de la règle actuelle.** Pour chaque pixel, le script prend la passe 2019 si l'année de la date de la carte actuelle (R0) est 2019, la passe principale sinon, et garde ce choix sous R1, R2 et R3. Cela touche environ 20 % des pixels communs (20,3 %). Un pixel que R1 à R3 dateraient autrement en 2019, ou hors de 2019, reste dans la passe que R0 lui a donnée.
- La passe 2019 est refaite à partir de la série principale (les ratios des dates de 2019 ne dépendent que des images d'avant et des 3
  suivantes) ; elle reproduit la carte de 017 à 99 % mais n'est pas la passe réelle.
- Un seul balayage des seuils, des règles et des moitiés de la tuile : pas d'intervalle de confiance.

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-1 RTC processed
  by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  masque forêt de la chaîne (codes regroupés en forêt / non-forêt).
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts
  in Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin
  sur la grille de la carte recalculée ; seuls des chiffres agrégés et le mois de la date
  publiée pour les pixels tracés sont publiés ici.
- **[ORT]** Source : IGN, BD ORTHO® 2018 et 2021, Ortho Express 2024, orthophotos PAC 2020 et
  2025, service WMS de la Géoplateforme (data.geopf.fr), Licence Ouverte 2.0. Consultées par la
  mission 026, non redistribuées (vignettes hors dépôt).
