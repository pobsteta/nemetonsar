# Décalage du ratio de changement entre Sentinel-1A et Sentinel-1C/1D : mission 033
Développeur, 2026-11-24, sur le poste de Pascal

> **Ce que ce rapport contient.** Des chiffres agrégés (médianes,
> écarts, parts de pixels) calculés sur quatre fenêtres de forêt de
> 3 km × 3 km, lues dans les images Sentinel-1 RTC du Planetary Computer,
> avec le masque BD Forêt. Il ne contient **aucune donnée de la carte
> SUFOSAT v3.0.1** et n'hérite donc pas de sa clause non commerciale. Il
> ne contient aucune image Sentinel-1. Attribution : Contains modified
> Copernicus Sentinel data 2018-2026. Sentinel-1 RTC processed by
> Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0. Masque
> forêt : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
> https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET.
> Données modifiées : codes TFV regroupés en forêt / non-forêt,
> rastérisés sur la grille de calcul.

Script : [`decalage-1a-1c1d.R`](decalage-1a-1c1d.R) (étapes `orbites`,
`fenetre`, `lire`, `mesurer`, `synthese`, `recouvrement`,
`recouvrement-synthese`, `controle`). Mission :
`pilotage/missions/033-decalage-1a-1c1d.md`. Suite de
[`continuite-s1c.md`](continuite-s1c.md) (mission 029).

**Mission, en une phrase.** Mesurer, sur quatre fenêtres de forêt stable
de régions différentes, le décalage médian du ratio de changement entre
les fenêtres Sentinel-1A et Sentinel-1C/1D, orbite par orbite, et dire
s'il est constant, pour que Pascal sache si un recalage exposé (valeur
par défaut 0) peut corriger la rupture vue par 029 ou si la cause est
ailleurs.

## Réponses

1.  **Décalage de la médiane du ratio, 1C/1D contre 1A (11 couples
    fenêtre-orbite sur 4 fenêtres ; 9 orbites relatives, A059 et D037
    figurant deux fois : les couples ne sont pas indépendants) :** de
    **−0,37 à +0,17 dB**, médiane **−0,09 dB**, signe négatif sur 7
    couples et positif sur 4. Un seul décalage sur 11
    dépasse 2,6 écarts-types de la variation entre années 1A de la même
    saison (0,20 dB en médiane des orbites, de 0,09 à 0,36). La part de forêt stable sous tp est
    **multipliée par 1,8 en médiane** (de 0,7 à 4,1 selon l'orbite), et
    sort de la fourchette des six années 1A pour 4 couples sur 11. Le
    « 6 à 15 fois » de 029 venait d'une référence d'**une seule année**
    (2025) : la part sous tp des années 1A varie déjà d'un facteur 2 à 20
    d'une année à l'autre sur une même orbite.
2.  **Constant ? Non, pas au sens d'un écart chiffré.** Le décalage
    change de signe d'une orbite à l'autre (même orbite relative A059 :
    +0,07 dans le Morvan, +0,12 dans les Cévennes ; D037 : −0,27 et
    +0,03), d'un mois à l'autre (écart-type des décalages mensuels de
    0,28 dB, autant que l'écart-type entre années 1A du même mois, 0,27
    dB) et il dépend de l'année de référence : un **témoin** (fenêtres
    tout-1A de janvier à mai 2026, avant la bascule, même calcul) donne
    de −0,28 à +0,56 dB, c'est-à-dire **la même étendue que le
    décalage**. La méthode, sur une seule année 1C/1D, ne sépare pas un
    changement de capteur de l'année qu'il fait.
3.  **Recalage constant, essai de sensibilité.** Avec le décalage
    médian commun (−0,09 dB), la part sous tp 1C/1D passe d'un rapport
    de 1,78 à 1,52 fois la part 1A (médianes sur 11 couples). Avec le
    décalage propre à chaque orbite (circulaire : on retire ce qu'on
    vient de mesurer), 1,26. **Un recalage constant ne ramène pas la
    part sous tp au niveau 1A**, et il ferait passer sous la moyenne 1A
    les orbites qui n'avaient pas de décalage. Le décalage de la médiane
    n'est de toute façon qu'une partie de l'effet : l'écart robuste du
    ratio grandit aussi (+6 % en médiane, de +2 à +18 %), et un
    décalage constant ne l'enlève pas.
4.  **Question ajoutée, hors fiche : 1C et 1A en même temps** (une
    observation, pas un résultat demandé par la mission). Le catalogue
    sert Sentinel-1C **depuis mars 2025**, donc 14 mois avant la bascule
    codée dans `capteurs_sufosat()` (2026-06-30), sur les mêmes
    orbites. En comparant, par couple fenêtre-orbite et par mois, le VH
    moyen de 1C à celui de 1A au même moment (≥ 2 images de chaque),
    **1C est plus sombre que 1A de 0,37 dB en moyenne** : négatif sur
    les 11 couples (9 orbites relatives, non indépendantes ; −0,17 à
    −0,64 dB), sur 10 à 14 mois chacun. L'écart n'est pas constant dans
    le temps : −0,84 dB en 2025-05, −0,24 dB en 2026-05, **+0,01 dB en
    2026-06 (2 couples seulement)**. Il se réduit donc avec le temps, ce
    qui rend fragile un niveau estimé sur le recouvrement de 2025 pour
    corriger l'après-bascule. Et **après la bascule**, la comparaison du
    niveau VH de 1C (depuis le 2026-07-01) à celui de 1A aux mêmes jours
    de 2020-2025 est **de signe mixte** : 0,00 et +0,03 dB (Landes A030,
    D008), +0,17 (Morvan A161), +0,22 (Cévennes A059), et de −0,12 à
    −0,48 sur les sept autres couples ; moyenne −0,15 dB (1D : −0,13 dB).
    Cette seconde mesure a une autre référence (années passées, donc
    avec l'effet de l'année) : elle n'est pas directement comparable à la
    première. 1D contre 1A au même moment (une image par mois en mai et
    juin 2026 seulement) donne −0,19 dB sur des effectifs trop faibles.
    Lecture prudente : ces écarts sont compatibles avec un effet de
    capteur plutôt qu'avec des écarts de jours tirés au hasard, mais le
    rapport ne sépare ni la météo commune aux fenêtres, ni le traitement,
    ni la géométrie ; ce n'est pas un recalage.

**Lecture, sans conclure au-delà de la mesure.** Deux mesures qui se
contredisent en apparence : le ratio sur fenêtres 1A/1C-1D ne montre
pas de décalage constant (−0,09 dB en médiane, signe variable), alors
que 1C et 1A, comparés au même moment (question 4, hors fiche), montrent
−0,37 dB sur les 11 couples fenêtre-orbite en 2025-2026, mais −0,15 dB
seulement, de signe mixte, depuis la bascule. Le témoin explique en partie l'écart : en 2026, la référence
des années précédentes est trop basse (le ratio de janvier à mai 2026 est
déjà plus haut de 0,10 dB en moyenne, et de 0,56 dB sur l'orbite A030 des
Landes, voir « Témoin »), ce qui cache une partie de la baisse. Je ne
sais pas, avec ces chiffres, si un recalage constant est le bon outil :
voir « Ce que Pascal tranche ».

## Ce qui a tourné

| Élément | Valeur |
|:---|:---|
| Zones (choisies avant toute lecture) | Landes (pin maritime, plaine, 30TXP comme 029), Vosges (sapin, épicéa, hêtre, montagne moyenne, neige), Morvan (feuillus et douglas), Cévennes (chêne vert, châtaignier, pin, relief méditerranéen) |
| Orbites servies en 1C et 1D | Landes A030, D008, D081 ; Vosges A088, D139 ; Morvan A059, A161, D037, D110 ; Cévennes A059, D037 : 11 couples fenêtre-orbite (9 orbites relatives), tous servis par 1C et 1D, 10 à 12 dates par orbite et par capteur depuis le 2026-06-30 |
| Fenêtre | 300 × 300 pixels de 10 m (3 km × 3 km), la plus riche en forêt à plus de 30 m de toute non-forêt dans 6 km × 6 km, BD Forêt v2 (WFS). Centres (longitude, latitude) : Landes −0,8187 ; 44,1851. Vosges 6,9954 ; 48,1134. Morvan 4,0458 ; 47,1065. Cévennes 3,6052 ; 44,1336 |
| Images | 2018-01-01 au 2026-11-21 (dernière date servie), toutes les images de chaque orbite sur la fenêtre : 809 (Landes), 547 (Vosges), 1 078 (Morvan), 546 (Cévennes) |
| Ratio | `10 log10(Ma / Mb)`, Ma = moyenne linéaire des 3 images suivantes d'une orbite, Mb = moyenne de toutes les précédentes (comme la chaîne), seuils ts = −5,175 dB et tp = −3,45 dB (`parametres_sufosat()`) |
| Forêt stable | Pixels du cœur de forêt (BD Forêt, à plus de 30 m d'une non-forêt) dont le ratio n'est jamais sous ts à deux dates successives d'aucune orbite, de 2018 à 2026-11-21 (**variante A**, façon 029) ; **variante B** : le même critère jugé sur les seules dates avant le 2026-06-30. Les deux variantes donnent des décalages de médiane à 0,02 dB près (au plus 0,017, sortie de `synthese`) |
| Pixels | de 66 207 à 86 853 pixels stables par fenêtre (variante A) |
| Fenêtres comparées | « 1C/1D » : dates dont les 3 images de Ma sont toutes 1C/1D (19 à 22 dates par orbite, du 2026-06-18 au 2026-11-03) ; « 1A » : dates dont les 3 images de Ma sont toutes 1A, **les mêmes jours de l'année**, années 2020 à 2025 (Mb d'au moins deux ans) |
| Durée | lecture de 5 à 30 minutes par fenêtre (une orbite après l'autre) ; mesure de 1 à 4 minutes par fenêtre |

## Question 1 : décalage par fenêtre et par orbite

Médiane sur les pixels stables, moyennée sur les dates de chaque groupe
(variante A). `sd_an` : écart-type des moyennes annuelles 1A (6 années).
`z` : décalage / `sd_an`. `tp` : part des pixels sous tp. `rang_tp` : rang
de 2026 parmi 7 années (1 = la part la plus haute). L'écart robuste est
l'écart interquartile / 1,349.

| fenêtre | orbite | dates | médiane 1C/1D | médiane 1A | **décalage** | sd_an | z | écart robuste 1C/1D ÷ 1A | tp 1C/1D | tp 1A (min–max des années) | rang_tp |
|:--|:--|--:|--:|--:|--:|--:|--:|--:|--:|:--|--:|
| Landes | A030 | 22 | −0,229 | −0,135 | −0,094 | 0,359 | −0,26 | 1,148 | 1,38 % | 0,94 % (0,11–2,18) | 3 |
| Landes | D008 | 22 | −0,111 | −0,041 | −0,070 | 0,288 | −0,24 | 1,178 | 0,63 % | 0,27 % (0,03–0,64) | 2 |
| Landes | D081 | 19 | −0,302 | 0,036 | **−0,338** | 0,264 | −1,28 | 1,052 | 1,02 % | 0,44 % (0,09–1,04) | 2 |
| Vosges | A088 | 19 | −0,242 | 0,060 | **−0,302** | 0,145 | −2,09 | 1,063 | 0,59 % | 0,20 % (0,06–0,37) | 1 |
| Vosges | D139 | 22 | −0,318 | 0,051 | **−0,370** | 0,195 | −1,89 | 1,139 | 0,86 % | 0,21 % (0,09–0,45) | 1 |
| Morvan | A059 | 21 | −0,302 | −0,375 | 0,074 | 0,089 | 0,83 | 1,019 | 1,36 % | 1,33 % (0,66–1,74) | 4 |
| Morvan | A161 | 22 | −0,233 | −0,400 | 0,167 | 0,121 | 1,38 | 1,057 | 1,18 % | 1,00 % (0,48–1,32) | 2 |
| Morvan | D037 | 21 | −0,525 | −0,260 | **−0,265** | 0,098 | −2,72 | 1,018 | 1,73 % | 0,98 % (0,44–1,48) | 1 |
| Morvan | D110 | 21 | −0,453 | −0,220 | −0,234 | 0,161 | −1,45 | 1,050 | 1,63 % | 0,70 % (0,42–1,05) | 1 |
| Cévennes | A059 | 21 | −0,304 | −0,429 | 0,125 | 0,203 | 0,61 | 1,035 | 0,70 % | 0,94 % (0,34–1,75) | 5 |
| Cévennes | D037 | 22 | −0,353 | −0,384 | 0,031 | 0,201 | 0,16 | 1,074 | 0,97 % | 0,95 % (0,34–1,79) | 4 |

Lecture. Les orbites **descendantes du Morvan et des Vosges** et la
D081 des Landes perdent 0,23 à 0,37 dB ; les orbites **ascendantes du
Morvan et des Cévennes** n'en perdent pas (+0,07 à +0,17). La part sous
tp la plus haute de toutes les années sur 4 orbites (Vosges A088 et
D139, Morvan D037 et D110) ; dans la fourchette des années 1A sur les 7
autres. Le décalage de la médiane ne dépasse 2,57 écarts-types
(critère à 5 % pour 5 degrés de liberté) que sur une orbite (Morvan
D037, z = −2,72). Le rapport des écarts robustes est de 1,02 à 1,18
(médiane 1,06).

## Question 2 : constance

Sur les 11 couples : décalage de −0,37 à +0,17 dB, médiane −0,09,
écart-type 0,20 dB ; l'écart-type entre années 1A de la même
orbite et de la même saison est de 0,20 dB (médiane des orbites). Par
fenêtre (moyenne des orbites) : Landes −0,17, Vosges −0,34, Morvan
−0,07, Cévennes +0,08. Écart entre orbites d'une même fenêtre : 0,07
(Vosges), 0,09 (Cévennes), 0,27 (Landes), 0,43 (Morvan).

Par mois (fenêtres tout-1C/1D du mois contre tout-1A du même mois, 2020
à 2025 ; décalage en dB) :

| fenêtre | orbite | juillet | août | septembre | octobre |
|:--|:--|--:|--:|--:|--:|
| Landes | A030 | −0,20 | 0,15 | −0,11 | −0,19 |
| Landes | D008 | −0,11 | −0,06 | −0,21 | −0,15 |
| Landes | D081 | −0,28 | −0,09 | −0,64 | −0,43 |
| Vosges | A088 | −0,06 | −0,26 | −0,32 | −0,27 |
| Vosges | D139 | −0,34 | −0,43 | −0,73 | 0,05 |
| Morvan | A059 | 0,26 | 0,46 | 0,03 | −0,52 |
| Morvan | A161 | 0,37 | 0,48 | 0,03 | −0,30 |
| Morvan | D037 | −0,06 | −0,07 | −0,58 | −0,48 |
| Morvan | D110 | −0,08 | 0,09 | −0,47 | −0,68 |
| Cévennes | A059 | 0,09 | 0,37 | 0,28 | −0,40 |
| Cévennes | D037 | −0,04 | 0,45 | 0,18 | −0,49 |

Le décalage n'est pas constant dans le temps : **octobre est négatif sur
10 couples sur 11** (moyenne −0,35 dB) alors que juillet et août sont
de signe variable ; la pente avec le mois est négative sur 10 couples
sur 11. Une cause commune à toutes les fenêtres en octobre 2026 (temps
qu'il fait, ou autre) n'est pas écartée. Novembre n'est pas montré (une
à deux dates par orbite).

**Témoin.** Même calcul sur les fenêtres tout-1A de janvier à mai 2026,
contre les mêmes jours de 2020 à 2025 :

| fenêtre | orbite | témoin | décalage 1C/1D | décalage moins témoin |
|:--|:--|--:|--:|--:|
| Landes | A030 | +0,56 | −0,09 | −0,65 |
| Landes | D008 | +0,16 | −0,07 | −0,23 |
| Landes | D081 | +0,41 | −0,34 | −0,74 |
| Vosges | A088 | +0,07 | −0,30 | −0,37 |
| Vosges | D139 | +0,07 | −0,37 | −0,43 |
| Morvan | A059 | −0,02 | +0,07 | +0,09 |
| Morvan | A161 | +0,21 | +0,17 | −0,04 |
| Morvan | D037 | −0,26 | −0,27 | 0,00 |
| Morvan | D110 | +0,28 | −0,23 | −0,52 |
| Cévennes | A059 | −0,09 | +0,12 | +0,22 |
| Cévennes | D037 | −0,28 | +0,03 | +0,31 |

Le témoin devrait valoir 0 si la référence des années précédentes
convenait à 2026. Il va de −0,28 à +0,56 dB : l'année 2026 sort de la
référence de la même ampleur avant la bascule qu'après. La différence
« décalage moins témoin » (moyenne −0,22 dB, de −0,74 à +0,31, écart-type
0,36) n'est pas plus constante. (À noter : sur les Landes, 029 avait
mesuré −0,4 à −0,6 dB en comparant à la seule année 2025, dont le ratio
médian était plus haut que la moyenne 2020-2025 sur A030 et D008 ; c'est
une part seulement de l'écart avec les −0,07 à −0,34 dB d'ici.)

## Question 3 : recalage constant, essai de sensibilité

Part de forêt stable sous tp (variante A), moyenne sur les fenêtres
tout-1C/1D. Le « recalage » retire c dB au ratio 1C/1D (c = décalage
mesuré). Recalculé à partir des quantiles 0,1 % à 20 % du ratio, par
interpolation (d'où 1,74 % pour Morvan D037 ici contre 1,73 % compté
sur les pixels au tableau de la question 1 : seul écart de 0,01 point, les
autres lignes coïncident). **Ce n'est pas un réglage proposé** : c'est la réponse à
« que resterait-il ? ».

| fenêtre | orbite | tp 1A | tp 1C/1D sans | avec c propre | avec c commun (−0,094) |
|:--|:--|--:|--:|--:|--:|
| Landes | A030 | 0,94 % | 1,38 % | 1,18 % | 1,18 % |
| Landes | D008 | 0,27 % | 0,63 % | 0,55 % | 0,51 % |
| Landes | D081 | 0,44 % | 1,02 % | 0,54 % | 0,86 % |
| Vosges | A088 | 0,20 % | 0,59 % | 0,29 % | 0,48 % |
| Vosges | D139 | 0,21 % | 0,86 % | 0,40 % | 0,72 % |
| Morvan | A059 | 1,33 % | 1,36 % | 1,53 % | 1,17 % |
| Morvan | A161 | 1,00 % | 1,18 % | 1,55 % | 1,02 % |
| Morvan | D037 | 0,98 % | 1,74 % | 1,12 % | 1,49 % |
| Morvan | D110 | 0,70 % | 1,63 % | 1,12 % | 1,40 % |
| Cévennes | A059 | 0,94 % | 0,70 % | 0,90 % | 0,58 % |
| Cévennes | D037 | 0,95 % | 0,97 % | 1,03 % | 0,81 % |

Rapport tp 1C/1D ÷ tp 1A (médiane des 11 couples) : sans recalage 1,78 ;
c commun 1,52 ; c propre 1,26. Des quatre orbites qui sortaient de la
fourchette des années 1A, le c commun n'en ramène qu'une à sa limite
(Morvan D037, 1,49 % pour un maximum de 1,48 %) ; les Vosges (0,48 et
0,72 % pour des maxima de 0,37 et 0,45 %) et le Morvan D110 restent
au-dessus. Le c propre à chaque orbite en ramène trois dans la
fourchette (D110 reste à 1,12 % pour 1,05 %). Le c commun fait aussi
passer sous la moyenne 1A (sans sortir de sa fourchette) les orbites
qui n'avaient pas de décalage (Cévennes : 0,58 et 0,81 % pour 0,94 et
0,95 %). Un c unique corrige donc peu les unes et déplace les autres :
c'est le signe de non-constance de la question 2.

## Question 4 (ajoutée) : 1C et 1A en même temps

Découverte en cours de mission : en cherchant avec les trois capteurs
(`parametres_sufosat(capteurs = list("2014-04-03" = c("S1A", "S1C",
"S1D")))`), le catalogue rend des images Sentinel-1C **dès mars 2025**
(1 date en mars, 2 en avril, 6 à 9 par mois ensuite, toutes orbites) sur les mêmes
orbites que 1A, et 1D à partir de mai 2026. Le package ne les lit pas
avant le 2026-06-30 (valeur de `capteurs_sufosat()`). Cela donne une
mesure **sans saison à séparer** : même orbite, même mois, deux capteurs.

VH moyen du mois de 1C moins celui de 1A (≥ 2 images de chaque capteur
dans le mois ; médiane sur les pixels de cœur de forêt, sans
exclusion de pixel ; dB) :

| fenêtre | orbite | moyenne des mois | écart-type des mois | mois |
|:--|:--|--:|--:|--:|
| Landes | A030 | −0,41 | 0,34 | 12 |
| Landes | D008 | −0,47 | 0,44 | 12 |
| Landes | D081 | −0,64 | 0,70 | 12 |
| Vosges | A088 | −0,21 | 0,45 | 12 |
| Vosges | D139 | −0,39 | 0,61 | 14 |
| Morvan | A059 | −0,29 | 0,44 | 13 |
| Morvan | A161 | −0,17 | 0,24 | 10 |
| Morvan | D037 | −0,42 | 0,47 | 12 |
| Morvan | D110 | −0,25 | 0,54 | 13 |
| Cévennes | A059 | −0,44 | 0,37 | 13 |
| Cévennes | D037 | −0,37 | 0,61 | 11 |

Moyenne des 11 couples −0,37 dB, de −0,64 à −0,17, écart-type entre
orbites 0,13 dB (inférieur à l'écart-type entre mois d'une même orbite,
0,24 à 0,70). Par mois (moyenne des orbites) : −0,84 (2025-05), −0,56,
−0,33, −0,48, −0,41, −0,32, −0,49, −0,33, −0,27, −0,36, −0,04 (2026-03),
−0,28, −0,24 (2026-05). **Sur les 11 couples fenêtre-orbite (9 orbites relatives, non
indépendantes), 1C est plus sombre que 1A**, avec un écart plus faible en
2026 qu'en 2025 : 2026-06 donne +0,01 dB, mais sur 2 couples seulement.
1D contre 1A (mai et juin 2026 : un seul mois utilisable par couple,
deux au mieux ; −0,19 dB en moyenne, de −0,62 à −0,01) n'a pas
l'effectif pour être lu.

**Après la bascule** (niveau VH médian des pixels de cœur de forêt, 1C
et 1D depuis le 2026-07-01 contre 1A aux mêmes jours de l'année, 2020 à
2025 ; dB ; `ecart_1C`, `ecart_1D`) :

| fenêtre | orbite | écart 1C | écart 1D |
|:--|:--|--:|--:|
| Landes | A030 | 0,00 | +0,06 |
| Landes | D008 | +0,03 | −0,03 |
| Landes | D081 | −0,22 | −0,24 |
| Vosges | A088 | −0,37 | −0,47 |
| Vosges | D139 | −0,40 | −0,49 |
| Morvan | A059 | −0,18 | +0,14 |
| Morvan | A161 | +0,17 | −0,10 |
| Morvan | D037 | −0,48 | −0,30 |
| Morvan | D110 | −0,25 | −0,31 |
| Cévennes | A059 | +0,22 | +0,11 |
| Cévennes | D037 | −0,13 | +0,22 |

Moyenne des 11 couples : −0,15 dB pour 1C (de −0,48 à +0,22), −0,13 dB
pour 1D. Le signe est mixte (1C : 7 couples négatifs, 3 positifs, 1 nul).
La référence est ici 1A des années passées, avec l'effet de l'année (le
témoin de la question 2 va de −0,28 à +0,56 dB) : cette mesure ne se
compare pas telle quelle aux −0,37 dB du recouvrement. Elle montre
seulement que, depuis la bascule, un niveau 1C plus sombre de 0,37 dB
sur tous les couples ne se retrouve pas.

Ce que cette mesure ne dit pas : si l'écart est un défaut d'étalonnage,
une différence de traitement par Catalyst/Planetary Computer (1C
traité autrement que 1A), ou la géométrie (heures de passage, angle
d'incidence). Elle est faite sur le niveau VH moyen et non sur le ratio.
Les images 1A et 1C d'un même mois sont de jours différents (de 2 à 6
jours d'écart) : on suppose que le temps qu'il fait y ajoute surtout un
bruit, qui expliquerait l'écart-type entre mois ; cette hypothèse n'est
pas mesurée ici (pas de test d'un biais commun aux fenêtres, qui
partagent les mêmes jours).

## Limites et écarts

- **Une seule année 1C/1D** pour les questions 1 à 3 : la variation de
  l'année (témoin de −0,28 à +0,56 dB) est de la taille du décalage
  cherché. Le décalage médian de −0,09 dB est dans la variation.
- **Quatre fenêtres de 9 km², en France**, masque BD Forêt (le masque
  TCD 2018 n'a pas été lu : pas de TCD sur le poste). Les orbites A059
  et D037 apparaissent deux fois (Morvan et Cévennes) : 11 couples
  fenêtre-orbite, **9 orbites relatives**, non indépendantes entre
  elles (même saison, même jour).
- **« Forêt stable »** : critère défini plus haut ; il ne sait pas ce
  qu'est une coupe ni une tempête. Les variantes A et B donnent des
  décalages à 0,02 dB près (au plus 0,017), des parts sous tp un peu plus hautes en B
  (+0,0005 à +0,0044).
- **Les années de référence 2020 à 2025** (6 années) donnent un
  écart-type entre années ; pour 5 degrés de liberté, le seuil à 5 % est
  2,57 écarts-types. Ce n'est pas un test.
- **Différence avec 029** : référence sur 6 années au lieu de 2025
  seule ; critère de pixel stable à partir du ratio (deux dates
  successives sous ts) au lieu des objets de la chaîne ; fenêtre
  choisie par la BD Forêt et non par les objets. Les chiffres de 029 ne
  sont donc pas repris tels quels, mais ceux des Landes sont de même
  ordre en 2026 : part sous tp de 0,63 à 1,38 % (029 : 0,45 à 1,16 %).
- **Le calcul** est vérifié par l'étape `controle` du script (ratio
  contre la définition écrite à la main, écart 6·10⁻¹⁵ dB ; composition
  des fenêtres ; aller-retour dB). Le calcul de la question 4 ne l'est
  que par recoupement : 11 couples, mêmes signes.
- Novembre 2026 est incomplet : peu de fenêtres tout-1C/1D (la dernière
  date de fenêtre est le 2026-11-03).
- **Hors périmètre (noté, non fait)** : `capteurs_sufosat()` ignore 1C
  de mars 2025 à juin 2026 ; le package ne les lit donc pas, alors que
  le catalogue les sert. À décider.

## Ce que Pascal tranche

1.  **Faut-il un recalage constant du ratio ?** Les chiffres ne le
    soutiennent pas : le décalage mesuré sur le ratio n'est pas
    constant (signe variable, 0,43 dB entre deux orbites du Morvan) et
    un recalage unique laisse la part sous tp à 1,5 fois la part 1A.
    Je ne propose pas de valeur.
2.  **Piste hors fiche, issue de la question 4** : 1C est plus sombre
    que 1A de 0,37 dB au même moment sur 11 couples fenêtre-orbite
    (9 orbites relatives, non indépendantes) en 2025-2026, mais de
    signe mixte (−0,15 dB) depuis la bascule, et l'écart se réduit avec
    le temps (+0,01 dB en 2026-06, 2 couples). Si l'écart se confirmait
    comme un biais de capteur, ce qui se corrigerait serait le niveau
    des images 1C et 1D avant le calcul du ratio, et non le ratio ;
    mais un niveau estimé sur le recouvrement de 2025 serait fragile pour
    l'après-bascule, puisque l'écart change. Ce n'est pas une
    conclusion. Mission possible, `analyste` ou `dev` : *mesurer le
    recouvrement 1A/1C, par orbite et par mois, sur des fenêtres de
    forêt, sur une plus longue période ou plus de tuiles, et chiffrer ce
    qu'un recalage du niveau (et non du ratio) laisserait comme part
    sous tp.* À Pascal de dire s'il garde cette question au rapport et
    s'il lance cette mission.
3.  **Les détections postérieures au 2026-06-30** : ce rapport ne les
    rend pas plus sûres. L'arbitrage n° 3 du brief reste à lui.

**Question de contrôle.** Qui fait quoi d'ici quand, et comment saura-t-on
que ça marche ? Pascal décide s'il lance la mission de recouvrement
1A/1C (point 2) : elle réussira si, sur plus de fenêtres, 1C reste plus
sombre que 1A de 0,2 à 0,6 dB au même moment (ou si l'écart se révèle
se réduire avec le temps, ce qui dirait que le recalage de niveau ne tient pas), et si un recalage du
niveau par orbite ramène la part sous tp 1C/1D dans la fourchette des
années 1A (aujourd'hui 4 couples sur 11 en sortent).
