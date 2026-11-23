# La cause non établie des dates tardives, observée à la date publiée : mission 026

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il contient des chiffres agrégés et, pour les pixels
> tracés (coordonnées L93 données pour le contrôle sur orthophoto), le mois de la date publiée
> par la v3.0.1 et la position de cette date dans la série du ratio. Il ne contient aucune autre
> valeur de pixel de la v3.0.1.

Analyste, 2026-11-23, sur le poste de Pascal. Script : [`cause-dates-tardives.R`](cause-dates-tardives.R)
(étapes `relever`, `analyser`, `tracer` ; vignettes par l'étape `orthos` de
[`ecarts-date-v301.R`](ecarts-date-v301.R)). Point de départ :
[`ecarts-date-v301.md`](ecarts-date-v301.md) (mission 024).

**Problème, en une phrase.** Sur la tuile pilote des Landes, 13 104 pixels tardifs (52 % des
25 181) n'ont pas de cause établie après la mission 024. Que montre, orbite par orbite, le ratio de
détection à la date publiée par la v3.0.1, et quand passe-t-il sous le seuil pour la première fois ?

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Relevé | `nemetonsar_run()` sur l'AOI, la période, les réglages et le masque BD Forêt (WFS) de la mission 017. Passe 1 en parallèle (un processus par orbite, mission 023), 4 flux, jeton SAS neuf à chaque bande (contournement de 024, mission 025 non faite). Durée : **45,6 min** |
| Branchement | `utils::assignInNamespace()` autour de `rcr_compute()`, `detecter_blocs()` et `bande_bordee()`. Le package n'est pas modifié et le résultat de `rcr_compute()` est rendu tel quel. Pour chaque bloc de la passe principale et chaque orbite, la série filtrée (VH) et les deux ratios (détection `xb = Inf`, datation `xb_date = 5`) sont gardés à **toutes les dates**, à la date `d_(i+1)`, en centièmes de dB (4,4 Go hors dépôt) |
| Contrôle du relevé | Les 36 appels portent sur 3 457 206 ratios d'orbite. Le minimum du ratio de détection et la date de la règle actuelle, recalculés, sont **identiques à `rcr_compute()`** : 0 date différente, écart de ratio nul. Chaque cellule de la tuile n'est relevée qu'une fois (vérifié sur une AOI d'essai de 800 m) |
| Contrôle de la carte | `dates.tif` du relevé (en parallèle) et celui de la mission 017 (en série) : **0 cellule différente** sur 1 006 009 |
| Appariement | Les 39 474 pixels étudiés sont lus sur la grille UTM de la tuile. Pixels du reste : le ratio minimal de l'orbite retenue est égal au `ratio.tif` de 017 pour 13 091 sur 13 104 ; la date de la règle actuelle est retrouvée pour 12 978 sur 13 104. Les écarts restants viennent des objets de la passe 2019, dont la série est plus courte et n'est pas relevée ici |
| Classes de 024 | Reproduites à l'unité : début de série 2 822, règle à 15 j 4 896, règle à 16–60 j 4 163, plus datés 196, **reste 13 104** |
| Analyse | 3 min. Témoin : les 14 293 pixels « date retrouvée » (\|écart\| ≤ 15 j) de la carte actuelle |

**Définitions** (provisoires, choisies ici) :
- **P** : la date publiée par la v3.0.1.
- **Ratio à P** : le minimum du ratio de détection sur les dates `d_(i+1)` situées à ±15 j de P.
- **Proche du seuil** : la meilleure orbite est à P entre tp (−3,45 dB) et tp + 1 dB.
- **Persistance** à une date X : le VH moyen (linéaire) de ]X+60 j, X+240 j], comparé à celui des
  5 images valides avant X, en dB.

Les seuils de 15 j et de 180 j sont ceux de 024.

## Question 1 : à la date publiée, que voit-on ?

Classement exclusif des 13 104 pixels du reste, dans cet ordre : pas d'image à ±15 j sur l'orbite
retenue ; orbite retenue sous tp à P ; autre orbite sous tp à P ; meilleure orbite proche du
seuil ; le reste, loin du seuil.

| Classe (situation à P) | Pixels | % | % cumulé |
|---|---:|---:|---:|
| **Proche du seuil** : la meilleure orbite est entre −3,45 et −2,45 dB à P | 7 080 | 54,0 | 54,0 |
| **Loin du seuil** : aucune orbite sous −2,45 dB à P (rien à cette date) | 3 359 | 25,6 | 79,7 |
| **Autre orbite à l'heure** : l'orbite retenue n'est pas sous tp à P, une autre l'est | 2 449 | 18,7 | **98,3** |
| *— trait —* | | | |
| Orbite retenue sous tp à P, mais un passage plus ancien (> 60 j avant P) | 182 | 1,4 | 99,7 |
| Orbite retenue sous tp à P selon le relevé (dont 16 exactement à −3,45 dB, à la limite de l'arrondi au centième) | 29 | 0,2 | 99,96 |
| Pas d'image à ±15 j sur l'orbite retenue | 5 | 0,04 | 100,0 |

Comment lire ces classes : ce sont des **situations du signal à la date publiée**, pas encore des
causes. La section « Causes » plus bas les rattache aux branches.

**Ratio de détection à P, meilleure des trois orbites (quantiles 10/25/50/75/90 %, dB) :**

| Groupe | Ratio à P | Ratio de datation à P | VH avant P (médiane) | Premier passage sous tp − P (médiane) |
|---|---|---|---:|---:|
| Témoin (date retrouvée) | −6,34 / −5,44 / **−4,45** / −3,83 / −3,40 | médiane −4,68 | −14,5 dB | 0 j |
| Reste | −3,86 / −3,35 / **−2,91** / −2,43 / −1,95 | médiane −2,86 | −14,9 dB | +253 j |

**Lecture.**
- Pour plus de la moitié du reste, le signal **existe** à la date publiée, mais il est faible : la
  médiane est à 0,5 dB au-dessus de tp, alors que celle du témoin est 1 dB en dessous.
  **3 264 pixels** (24,9 % du reste) ont à P un ratio entre −3,45 et −3,0 dB : ils seraient sous
  le seuil sans le facteur 1,15 de `parametres_sufosat()`. Ceci est une indication, pas un essai :
  ce même seuil sert aussi à la détection.
- Un pixel sur cinq est **à l'heure sur une autre orbite**. L'orbite retenue (celle du ratio minimal
  sur toute la série) passe sous tp plus tard, souvent sur un creux de fin d'hiver. Les trois
  orbites sont concernées (A030 : 758, D008 : 692, D081 : 999 pixels).
- Un quart **ne montre rien** à la date publiée. Pour ceux-là, le premier passage sous tp vient
  60 à 180 j après P (822 pixels), 180 à 365 j après (1 103) ou plus d'un an après (1 378). Il tombe
  en février–mars dans 38 % des cas et en juin–août dans 39 %.
- Le VH avant P du reste n'est que de 0,4 dB plus bas que celui du témoin. « Peuplement déjà
  clair » ne suffit donc pas à distinguer le reste.

**Le témoin non plus n'est pas « parfait » à P.** Sur les 14 293 pixels à date retrouvée, 83,8 %
ont l'orbite retenue sous tp à P, 10,2 % sont proches du seuil, 4,2 % sont sous tp sur une autre
orbite seulement, et 0,7 % sont loin du seuil. Le classement sépare nettement les deux groupes,
mais pas parfaitement.

## Question 2 : les 8 acquisitions de fin d'hiver

Ces 8 acquisitions sont celles où la carte actuelle place le plus de pixels tardifs : **52,6 % des
tardifs**, et 45,2 % des pixels du reste. Pour chacune, sur la forêt de l'AOI (masque de la tuile)
:
- part des pixels dont le ratio de **datation** est ≤ tp à cette date, comparée à la médiane de
  toutes les dates de la même orbite depuis février 2019 ;
- persistance médiane, par groupe.

Les groupes sont les suivants :
- « déjà coupée » : coupe publiée par la v3.0.1 plus de 60 j avant la date ;
- « sans coupe » : ni dans la carte recalculée, ni dans la v3.0.1 (720 906 pixels) ;
- « tardifs » : pixels tardifs datés à cette acquisition.

| Acquisition | Orbite | Tardifs (% des tardifs) | Déjà coupée ≤ tp (médiane de l'orbite) | Sans coupe ≤ tp (médiane) | Persistance médiane : tardifs / déjà coupée / sans coupe |
|---|---|---:|---:|---:|---|
| 2022-03-23 | A030 | 4 254 (16,9 %) | 20,9 % (0,04 %) | 0,78 % (0,02 %) | **−2,65** / −0,85 / −0,15 dB |
| 2023-02-09 | D008 | 2 195 (8,7 %) | 19,8 % (0,02 %) | 2,72 % (0,01 %) | **−0,45** / +0,15 / +0,05 dB |
| 2021-03-28 | A030 | 1 553 (6,2 %) | 20,5 % | 1,64 % | **−2,25** / −1,05 / −0,75 dB |
| 2021-03-04 | A030 | 1 143 (4,5 %) | 20,5 % | 1,17 % | **−2,35** / −1,25 / −0,65 dB |
| 2022-02-26 | D008 | 1 113 (4,4 %) | 15,9 % | 0,77 % | **−2,45** / −1,05 / −0,45 dB |
| 2021-02-20 | A030 | 1 095 (4,3 %) | 17,0 % | 0,83 % | **−2,55** / −1,25 / −0,65 dB |
| 2025-03-06 | D008 | 988 (3,9 %) | 6,1 % | 0,38 % | **−2,15** / −0,45 / −0,25 dB |
| 2024-03-24 | A030 | 902 (3,6 %) | 4,1 % | 0,14 % | **−2,15** / −0,15 / −0,05 dB |

Médianes de l'orbite (part ≤ tp, toutes dates) : A030 0,04 % / 0,02 % ; D008 0,02 % / 0,01 %.
Rang de la part « sans coupe » parmi les dates de l'orbite : 1er, 1er, 2e, 2e, 5e, 5e, 6e, 22e.

**Lecture.**
- **Ce sont des chutes larges, et pas seulement des événements.** À ces dates, 16 à 21 % des
  parcelles déjà coupées passent sous tp, contre 0,02 à 0,04 % un jour ordinaire, soit environ
  500 fois plus. La forêt sans coupe est touchée aussi (0,8 à 2,7 %, 40 à 300 fois la médiane), mais
  bien moins : la chute frappe surtout le **sol découvert**. C'est la branche Milieu (humidité ou
  gel du sol). Le masque neige n'est pas appliqué, et la météo n'a pas été lue.
- **Sur les pixels tardifs, la chute est suivie d'une baisse durable**, à une exception près. Le VH
  des 2 à 8 mois suivants reste plus bas d'environ 2,2 à 2,7 dB. C'est plus que la saison seule
  (−0,15 à −0,75 dB en forêt sans coupe) et que les parcelles déjà coupées en général (−0,15 à
  −1,25 dB). La chute de fin d'hiver coïncide donc, sur ces pixels, avec un changement réel qui
  dure : sur orthophoto, souvent un sol travaillé (voir les pixels tracés).
- **L'exception est le 9 février 2023 (D008)** : persistance médiane −0,45 dB pour les tardifs. C'est
  une chute passagère (2 195 pixels, 8,7 % des tardifs), et la plus large des huit en forêt sans
  coupe (2,72 %, au 1er rang de l'orbite).
- La persistance compare un hiver à un printemps-été : elle porte une part saisonnière. C'est
  pourquoi elle est donnée à côté de celle des deux groupes de comparaison, mesurés aux mêmes dates.

## Question 3 : postes BD Forêt FF0 et FO0

BD Forêt v2 par le WFS de la Géoplateforme, rastérisée au centre des cellules sur la grille de la
carte (L93).

| Groupe | Pixels | FF0 | FO0 | Autres postes forêt |
|---|---:|---:|---:|---:|
| AOI | 1 000 000 | 39,3 % | 0,03 % | 48,1 % |
| Pixels datés dans les deux cartes | 54 160 | 48,8 % | 0 | 51,1 % |
| Date retrouvée (témoin) | 14 293 | **64,3 %** | 0 | 35,6 % |
| Tardifs | 25 181 | **45,1 %** | 0 | 54,8 % |
| — dont début de série | 2 822 | 72,6 % | 0 | 27,4 % |
| — dont reste | 13 104 | 42,5 % | 0 | 57,3 % |
| — reste, loin du seuil à P | 3 359 | 44,6 % | 0 | 55,2 % |
| — reste, proche du seuil | 7 080 | 42,9 % | 0 | 57,0 % |
| — reste, autre orbite | 2 449 | 39,4 % | 0 | 60,5 % |

**Lecture.** Les postes FF0 et FO0, comptés forêt par décision du 2026-11-22, **ne portent pas les
dates tardives**. FO0 est absent (325 pixels dans l'AOI, aucun daté). FF0 est **moins fréquent**
parmi les tardifs (45 %) que parmi les pixels à date retrouvée (64 %) ou que parmi l'ensemble des
pixels communs (49 %). La forte part de FF0 en « début de série » (73 %) est cohérente avec des
parcelles déjà ouvertes au relevé de la BD Forêt.

## Pixels tracés

L'étape `tracer` tire 2 pixels par classe du reste et 2 témoins (graine 20261123). Elle dessine les
trois orbites :
- ratio de détection en bleu, ratio de datation en gris, VH en points verts ;
- la date publiée en noir, la date de la carte en rouge, le premier passage sous tp en pointillés
  bleus.

Les images sont hors dépôt (`<dossier>/traces/`). Les vignettes d'orthophoto (2018, 2020, 2021,
2024, 2025 ; l'ortho PAC 2020 est identique à 2018 ici, comme en 024) n'ont été faites que pour les
7 pixels ci-dessous. Les 7 autres pixels tirés (classes marginales) sont tracés mais non commentés.

Sur les 7 vignettes, 5 parcelles sont de l'herbe ou une jeune plantation en 2018, puis un sol
travaillé en 2021, puis une plantation. Ce que la v3.0.1 et la chaîne datent n'y est souvent pas
une coupe d'arbres, mais le **travail du sol**.

| Point (L93) | Classe | Série | Orthophoto |
|---|---|---|---|
| 398525 ; 6351825 | proche du seuil | P au printemps 2020 : chute à environ −3 dB sur A030, sous tp en août 2020 seulement. Date de la carte : creux de mars 2021 (−5,5 dB), suivi d'un **rebond** au-dessus de la normale | 2018 : herbe et arbres épars. 2021 : sol labouré nu. 2024 : replanté |
| 398595 ; 6348385 | autre orbite | P au printemps 2022 : A030 et D081 passent sous tp **à P**. L'orbite retenue (D008) l'est par un creux de mars 2025 suivi d'un rebond | 2018–2021 : peuplement en place. **2024 : coupé et replanté**. La date de la carte (mars 2025) est postérieure à ce que montre l'ortho 2024 |
| 394175 ; 6352425 | loin du seuil | P à l'été 2019 : rien sur aucune orbite, VH plat. Date de la carte : creux de mars 2021 (D081), juste sous tp | 2018 et 2020 : boisé. **2021 : coupé**, rémanents ; pixel en lisière du reste du peuplement. 2024 : planté. L'ortho ne départage pas 2019 et mars 2021 |
| 394465 ; 6350145 | loin du seuil | P à la fin de l'été 2020 : rien. Chute en mars 2021 **sur les trois orbites**, durable (−4,6 dB) | 2018–2020 : herbe et arbres épars (aucun arbre au pixel). **2021 : sol travaillé**. 2024 : planté. Événement réel postérieur, le travail du sol, et pas la coupe des arbres épars |
| 394475 ; 6350815 | proche du seuil | P à la fin de l'été 2020 (−2,9 dB à P). Date de la carte : février 2022, durable | Pixel **sur une piste**, au bord de deux parcelles. 2018 : herbe, un arbre isolé. 2021 : sol travaillé des deux côtés. 2024 : planté. Pixel de lisière |
| 393725 ; 6349945 | autre orbite | P en mars 2021, sous tp sur une autre orbite que D008. Date de la carte : 9 février 2023 (la chute passagère) | 2018 : herbe, jeune plantation. **2021 : sol travaillé**. 2024 : planté. La date de la carte (2023) est postérieure au travail du sol que montre l'ortho 2021 |
| 393975 ; 6349765 | témoin | P et carte en mars 2021, chute suivie d'un rebond | 2018 : herbe, jeune plantation. 2021 : labouré. 2024 : plantation. **La v3.0.1 date ici aussi un événement de fin d'hiver** |

**Sentinel-2 : pas fait.** Les dates de vol des orthophotos n'ont pas été lues.

## Causes : rattachement (Ishikawa) et Pareto

Les situations à P renvoient aux branches suivantes. Une situation peut relever de deux branches ;
la ligne du Pareto suit la situation.

| Situation à P | Branche | Cause sur laquelle une action est possible |
|---|---|---|
| Proche du seuil (54,0 %) | Mesure / Matière | Seuil de datation égal au seuil de détection, avec le facteur 1,15. S1A seul (3 images = 36 j, contre 18 j avec S1B dans la v3.0.1). La règle de date ne lit qu'un passage franc sous tp |
| Autre orbite à l'heure (18,7 %) | Méthode | L'orbite est retenue par le minimum sur **toute** la série, et la date ne vient que d'elle. Un creux tardif profond, souvent de fin d'hiver, fait retenir l'orbite et la date |
| Loin du seuil (25,6 %) | Milieu / Mesure | Plusieurs événements sur la même parcelle (coupe, travail du sol, plantation), dont la chaîne date le plus visible en VH. La date de la v3.0.1 suit sa propre règle, et on ne sait pas lequel des événements elle date |
| Commun aux trois | Milieu | Creux de fin d'hiver sur sol découvert. La règle « minimum » les choisit : 61 % des dates du reste sont en février–mars |

**Trait** : trois situations couvrent 98,3 % du reste. Les deux premières (« proche du seuil » et
« autre orbite », 72,7 %) mènent à des causes sur lesquelles on peut agir dans la règle de date.
La troisième (« loin du seuil », 25,6 %) demande d'abord de mieux observer : elle n'est pas
tranchée ici.

## Autres constats

- **Le parallèle donne la même carte que la série** au pixel près, sur une exécution réelle de 45,6
  min (contre 74 à 99 min en série en 024).
- Le contournement du jeton a tenu sur toute l'exécution (aucun 403).

## Limites

- Une AOI de 100 km² en pin maritime.
- Fenêtre de ±15 j et marge de 1 dB choisies ici, provisoires. Seuils de 15 et 180 j de 024.
- Ratios relevés au centième de dB : 58 pixels du reste sont exactement à −3,45 dB à P et sont
  comptés sous tp.
- La persistance porte une part saisonnière (voir la question 2).
- La passe 2019 n'est pas relevée.
- Météo, masque neige et Sentinel-2 non lus. Dates de vol des orthophotos inconnues.
- La v3.0.1 n'est pas une vérité terrain : le témoin tracé montre qu'elle date elle aussi un
  événement de fin d'hiver.

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2018–2025. Sentinel-1 RTC processed
  by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  codes TFV rastérisés sur la grille de la carte ; masque forêt de la chaîne (codes regroupés en
  forêt / non-forêt).
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts
  in Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin
  sur la grille de la carte recalculée et sur celle de la tuile ; seuls des chiffres agrégés et
  la position de la date publiée pour les pixels tracés sont publiés ici.
- **[ORT]** Source : IGN, BD ORTHO® 2018 et 2021, Ortho Express 2024, orthophotos PAC 2020 et
  2025, service WMS de la Géoplateforme (data.geopf.fr), Licence Ouverte 2.0. Consultées, non
  redistribuées (vignettes hors dépôt).
