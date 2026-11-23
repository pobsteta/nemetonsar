# D'où viennent les dates tardives par rapport à la v3.0.1 — mission 024

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il contient des chiffres agrégés et, pour les deux
> pixels tracés (section « Deux pixels tracés », coordonnées L93 données pour le contrôle
> sur orthophoto), la position de la date publiée par la v3.0.1 par rapport à la série du
> ratio. Aucune autre valeur de pixel de la v3.0.1.

Analyste, 2026-11-23, sur le poste de Pascal. Script : [`ecarts-date-v301.R`](ecarts-date-v301.R)
(étapes `recalculer`, `comparer`, `tracer`, `orthos`). Point de départ :
[`pilote-landes-comparaison.md`](pilote-landes-comparaison.md) (mission 017).

**Problème, en une phrase.** Sur la tuile pilote des Landes, 46,5 % des pixels datés dans
les deux cartes (25 181 sur 54 160) sont datés par la chaîne plus de 180 jours après la
v3.0.1 : d'où vient ce retard ?

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Carte « actuelle » | sorties de la mission 017 (règle du package : date du minimum du ratio de datation, `xb_date = 5`) |
| Règle `premiere_detection` | première date `d_i` admise où le ratio de **détection** (`xb = Inf`) est `<= tp` (−3,45 dB) ; date retenue `d_(i+1)`, comme le package |
| Règle `premiere_datation` | idem sur le ratio de **datation** (`xb_date = 5`) |
| Ce qui ne change pas | le minimum du ratio de détection, donc les zones détectées et l'orbite retenue ; seule la date change. Les objets changent un peu par la correction 2019 et le filtre de période, qui lisent la date (152 / 160 objets de détection contre 163) |
| Branchement | `utils::assignInNamespace()` autour de `rcr_compute()`, package inchangé ; même AOI, période, réglages, masque BD Forêt et lecture en série que la mission 017 |
| Contrôle de la règle | le script recalcule aussi la règle actuelle, pixel à pixel, à chaque appel : **7 004 628 ratios d'orbite, dates toutes identiques à `rcr_compute()`, écart de ratio nul** (48 appels par exécution) ; même résultat sur un jeu synthétique avec images manquantes |
| Durées | 99 min (`premiere_datation`) et 74 min (`premiere_detection`), en série, en partie simultanées |
| Incident | deux premières exécutions arrêtées par un **403 du Planetary Computer** : le jeton SAS a expiré pendant la lecture d'une bande (rstac ne le renouvelle qu'à moins de 5 min de sa fin). Contourné dans le script (jeton neuf à chaque lecture de bande) ; voir « Autres constats » |

Classes d'écart : celles du rapport 017 (le script les reproduit à l'unité sur la carte actuelle).
« Date retrouvée » : |écart| ≤ 15 j ; « tardif » : écart > +180 j (seuils provisoires du rapport 017).

## Hypothèse 1 : règle de date

| Mesure (pixels datés dans les deux cartes) | Actuelle | `premiere_datation` | `premiere_detection` |
|---|---:|---:|---:|
| Pixels comparés | 54 160 | 54 151 | 53 655 |
| Écart médian | +101 j | +13 j | **+25 j** |
| Écart absolu médian | 192 j | 59 j | **41 j** |
| Date retrouvée (≤ 15 j) | 26,4 % | 33,4 % | **36,6 %** |
| Tardifs (> +180 j) | 46,5 % | 31,0 % | **24,1 %** |
| Précoces (< −180 j) | 3,9 % | 5,6 % | 2,4 % |
| Quantiles 5 / 25 / 75 / 95 % | −108 / 0 / 409 / 1 031 | −228 / −11 / 268 / 905 | −36 / 0 / 168 / 744 |
| Surface publiée retrouvée | 54,1 % | 54,1 % | 53,5 % |
| F1 (objets, 75 %) | 0,27 | 0,27 | 0,26 |

**Devenir des 25 181 pixels tardifs de la carte actuelle :**

| | `premiere_datation` | `premiere_detection` |
|---|---:|---:|
| Redeviennent à ≤ 15 j | 3 876 (**15,4 %**) | 4 896 (**19,4 %**) |
| À ≤ 60 j | 6 153 (24,4 %) | 9 059 (36,0 %) |
| Restent tardifs (> +180 j) | 16 761 (66,6 %) | 11 393 (45,2 %) |
| Deviennent précoces (< −180 j) | 493 | 228 |
| Ne sont plus datés | 7 | 426 |

**Ce que coûte la règle aux 14 293 pixels déjà retrouvés :** 89,7 % le restent avec
`premiere_datation` (1 475 deviennent précoces de plus de 15 j), 83,7 % avec
`premiere_detection` (501 deviennent précoces, environ 1 800 plus tardifs : le minimum du ratio de
datation peut précéder le premier passage du ratio de détection sous tp). Bilan net : les
pixels retrouvés passent de 14 293 à 18 060 et à 19 643.

**Indication, non exécutée :** la plus ancienne des deux « premières dates », pixel par pixel,
donne 37,8 % de dates retrouvées, 18,6 % de tardifs, 6,1 % de précoces, écart médian +1 j,
et garde 87,9 % des pixels déjà retrouvés. C'est une approximation (les objets des deux cartes
diffèrent un peu), pas une règle essayée.

**Lecture.** La règle de date est une cause réelle mais minoritaire : la plus favorable des
deux règles ramène un cinquième des pixels tardifs à moins de 15 j, un bon tiers à moins de 60 j.
Les surfaces et les objets ne bougent presque pas : la règle change la date, pas la détection.

### Deux pixels tracés

Étape `tracer` : série du ratio des trois orbites, relue sur une AOI de 210 m autour du pixel
(vignettes et séries hors dépôt, `<dossier>/trace_*.png` et `.rds`). Sur cette petite AOI, le
pixel n° 1 n'est pas retenu comme objet (objet tronqué, sans graine : date de la trace vide) et sa
trace sert pour la série seule ; le pixel n° 2 est retenu, à la même date que la carte de la
mission 017 (21063, `trace2.log`).

*Journal du pixel n° 1.* `trace1.log` se termine sur une erreur de syntaxe d'une version antérieure
du script (boucle du graphique, corrigée depuis), écrite après l'enregistrement de la série :
`trace_398355_6352105.rds` et `.png` sont complets. Les dates par orbite relues dans ce `.rds`
(`trace1_relu.log`, hors dépôt) sont identiques à celles du journal. La trace n'a pas été
relancée : cela relit les images Sentinel-1.

- **Pixel tardif retrouvé par la règle (L93 398355 ; 6352105).** Orbite retenue (ratio de
  détection minimal −4,15 dB) : le ratio de détection passe sous tp une première fois au
  printemps 2020, **à la date publiée** ; le ratio de datation a son minimum un an plus tard, au
  4 mars 2021, sur un creux de fin d'hiver. La carte actuelle garde le 4 mars 2021 (21063), les deux
  règles « première » gardent le printemps 2020. Le mécanisme de l'hypothèse 1 est là.
- **Pixel tardif non retrouvé par `premiere_datation` (L93 395945 ; 6352275).** Orbite retenue
  (−3,95 dB, signal faible) : le ratio de détection passe sous tp fin juin 2020, environ 50 j
  après la date publiée ; le ratio de datation ne passe sous tp qu'au creux de mars 2021, que les
  deux règles « minimum » et `premiere_datation` retiennent. Pixel en bordure d'une piste
  (orthophoto).

Sur les deux pixels et les trois orbites, la série montre un **creux de fin d'hiver chaque année**
(février–mars), plus marqué en mars 2021.

## Hypothèse 2 : début de série

| Mesure | Valeur |
|---|---:|
| Pixels tardifs dont la date publiée est en 2018 | 2 822 sur 25 181 (**11,2 %**) |
| Comparaison 2019–2025 (pixels publiés en 2018 écartés des deux côtés) : tardifs, carte actuelle | 43,6 % (au lieu de 46,5 %) |
| idem, date retrouvée | 27,9 % (au lieu de 26,4 %) ; écart médian +68 j |
| idem avec `premiere_detection` : tardifs / retrouvée / écart médian | 20,2 % / 38,5 % / +24 j |
| Pixels publiés en 2018 (143,24 ha) : recalculés | 21,6 % ; dont datés 2019 : 1 110 px, après 2019 : 1 780 px |
| Surface recalculée datée de 2019 | 439,05 ha (43 905 px) |
| — commune avec une coupe publiée en 2018 | 11,10 ha (2,5 %) |
| — commune avec une coupe publiée une autre année | 98,60 ha (22,5 %) |
| — absente de la référence | 329,35 ha (75,0 %) |
| — absente, à moins de 30 m d'un pixel publié en 2018 | **10,95 ha, soit 3,3 % de la surface absente** |

**Lecture.** Le début de série explique au plus un pixel tardif sur neuf, et presque rien de la
surface de 2019 absente de la référence : 3,3 % de celle-ci touche (à 30 m près) une coupe publiée
en 2018. L'hypothèse « une partie de la surface recalculée de 2019 vient des coupes de 2018 » ne
tient donc pas sur cette tuile, au moins sous cette forme (contiguïté à 30 m ; un décalage plus
grand n'a pas été cherché).

## Pareto des pixels tardifs

Causes exclusives, attribuées dans cet ordre : début de série, puis règle de date (essai
`premiere_detection`), puis le reste. 25 181 pixels tardifs de la carte actuelle.

| Cause | Pixels | % | % cumulé |
|---|---:|---:|---:|
| **Cause non établie** : sur l'orbite retenue, premier passage du ratio de détection sous tp à plus de 60 j de la date publiée | 13 104 | 52,0 | 52,0 |
| **Règle de date**, date retrouvée (≤ 15 j avec `premiere_detection`) | 4 896 | 19,4 | 71,5 |
| **Règle de date**, rapprochée sans être retrouvée (16 à 60 j avec `premiere_detection`) | 4 163 | 16,5 | **88,0** |
| *— trait —* | | | |
| Début de série (date publiée en 2018, aucun ratio avant 2019) | 2 822 | 11,2 | 99,2 |
| Plus datés avec la règle `premiere_detection` | 196 | 0,8 | 100,0 |

**Ce que compte la règle de date.** Le chiffre principal est **19,4 % des pixels tardifs ramenés à
15 j ou moins** (4 896). La tranche de 16 à 60 j (16,5 %) est comptée sous « règle de date » parce
que la règle en rapproche fortement la date (de plus de 180 j à moins de 60 j), mais ces pixels
**ne redeviennent pas « date retrouvée »** au seuil de 15 j ; si l'on ne garde que la date retrouvée,
le cumul au trait tombe à 71,5 % et le reste (non établi plus 16-60 j) pèse 68,5 %.

La ligne « cause non établie » est **en tête** : avant d'agir sur elle, il faut mieux observer.
Ce qu'on en sait (faits, non des causes) :

- **Saison.** 67 % des pixels tardifs ont une date (carte actuelle) en février ou mars ;
  **8 acquisitions portent 53 % des pixels tardifs**, sur 312 dates distinctes (la plus chargée,
  le 23 mars 2022, en porte 17 %). Pour le reste après `premiere_detection`, les dates se
  répartissent entre février–mars (37 %) et juin–août (42 %).
- **Force du signal.** Le ratio de détection minimal des pixels du reste (médiane −4,89 dB) est
  du même ordre que celui des pixels déjà retrouvés (−4,97 dB) : la faiblesse du signal à elle
  seule ne les distingue pas. Mais ce minimum peut tomber sur un événement postérieur à la coupe
  publiée : ce qu'il faudrait lire, c'est le ratio **à la date publiée**, que les sorties ne gardent pas.
- **Orthophotos** (ci-dessous) : souvent un peuplement déjà clair en 2018, puis un sol travaillé en 2021.

### Pistes pour la cause non établie (Ishikawa, non vérifiées)

| Branche | Piste |
|---|---|
| Matière | S1A seul (la v3.0.1 a aussi S1B jusqu'à fin 2021) ; RTC du Planetary Computer et non le prétraitement de la v3.0.1 ; peuplements clairs, à chute de rétrodiffusion faible |
| Méthode | orbite retenue par le ratio minimal, puis date de cette seule orbite (une autre orbite peut passer sous tp à la date publiée) ; facteur 1,15 sur les seuils |
| Milieu | creux de fin d'hiver communs à toutes les orbites (humidité, gel), qui font passer sous tp des parcelles déjà ouvertes |
| Mesure | la date de la v3.0.1 suit sa propre règle, inconnue ; plus proche voisin à ½ pixel ; seuils 15 / 180 j provisoires ; une seule AOI |

## Hypothèse 3 : orthophotos IGN

Étape `orthos` : vignettes de 300 m, croix au pixel. Couches qui couvrent l'AOI : BD ORTHO 2018
et 2021, Ortho Express 2024, ortho PAC 2020 et 2025. **L'ortho PAC 2020 est identique à 2018 à
l'œil ici** (même prise de vue probable) : elle ne compte pas comme une date de plus. Dates de vol
dans l'année non lues. On ne conclut pas au-delà de ce qu'on voit.

| Point (L93) | Pourquoi | Ce qu'on voit |
|---|---|---|
| 394495 ; 6350305 | plus grand groupe de pixels tardifs | 2018 : peuplement bas et clair (herbe, arbres épars). 2021 : sol travaillé en bandes. 2024 : plantation en lignes |
| 398575 ; 6351625 | 2e groupe tardif | 2018 : pins épars sur fond herbeux. 2021 : sol nu travaillé. 2024–2025 : plantation |
| 393475 ; 6352545 | 3e groupe tardif | 2018 : peuplement fermé. 2021 : coupé, sol travaillé. 2024 : jeune plantation |
| 393185 ; 6346695 | 4e groupe tardif | 2018 et 2021 : peuplement en place. 2024 : coupé, rangs de plantation. Les deux dates sont entre 2021 et 2024 : l'ortho ne les départage pas |
| 396115 ; 6352015 | 5e groupe tardif | 2018 : clair, herbeux. 2021 : sol travaillé. 2024 : plantation |
| 398355 ; 6352105 | pixel tracé n° 1 | 2018 : peuplement clair, arbres restants. 2021 : coupé, sol nu et rémanents. 2024 : végétation basse |
| 395945 ; 6352275 | pixel tracé n° 2 | en bordure de piste, entre une jeune plantation et un peuplement clair ; 2021 : la partie sud est travaillée. Pixel de lisière |
| 398515 ; 6351715 | désaccord 017, v3.0.1 seule (50,42 ha) | 2018 : pins épars sur herbe. 2021 : sol nu travaillé. 2024 : plantation |
| 393185 ; 6352345 | désaccord 017, v3.0.1 seule (31,94 ha) | sur une piste ; la parcelle voisine est déjà plantée en lignes en 2018. Rien ne change au point entre 2018 et 2025 |
| 399055 ; 6351465 | désaccord 017, recalcul seul (100,70 ha) | **déjà coupée en 2018** (sol nu, andains) ; 2021 : sol travaillé ; 2024 : plantation |

**Ce qu'on voit, sans conclure au-delà.** Sur les groupes tardifs, la parcelle est souvent
**déjà claire en 2018** (arbres épars), puis **nue et travaillée en 2021**, puis plantée. Coupe
des derniers arbres, dessouchage, travail du sol et plantation se suivent en quelques années :
plusieurs événements datables sur le même pixel. La coupe « recalcul seul » de 100,70 ha est
déjà coupée sur l'ortho 2018 : la chaîne y date en 2019 un événement postérieur à la coupe, sur une
parcelle que la BD Forêt garde en forêt (masque, voir « Autres constats »).

## Autres constats (hors des deux hypothèses)

- **Jeton SAS expiré en cours de lecture (403).** Deux exécutions sur quatre ont échoué au milieu
  d'une bande : `s1_lire()` signe les adresses une fois par appel, avec le jeton en cache de rstac,
  qui n'est renouvelé qu'à moins de 5 min de son expiration (≈ 45 min de vie). Une lecture de bande
  plus longue que le reste du jeton échoue. Sur une tuile MGRS entière, les bandes sont bien plus
  longues à lire que sur cette AOI : à verser au package (mission à proposer).
- **Masque forêt.** La coupe « recalcul seul » de 100,70 ha est antérieure à 2018 ; avec le TCD
  2018 (masque de la méthode) elle serait probablement hors forêt. Piste pour la surface absente
  de la référence, non chiffrée ici.

## Limites

Une AOI de 100 km² en pin maritime ; règles essayées sur la seule orbite retenue par le ratio
minimal ; deux pixels tracés ; orthophotos à dates de vol inconnues et espacées (2018, 2021, 2024,
2025) ; seuils de 15 et 180 j provisoires ; l'indication « plus ancienne des deux » n'est pas une
exécution.

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
  sur la grille de la carte recalculée ; seuls des chiffres agrégés sont publiés ici.
- **[ORT]** Source : IGN, BD ORTHO® 2018 et 2021, Ortho Express 2024, orthophotos PAC 2020 et
  2025, service WMS de la Géoplateforme (data.geopf.fr), Licence Ouverte 2.0. Consultées, non
  redistribuées (vignettes hors dépôt).
