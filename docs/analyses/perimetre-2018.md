# Le périmètre 2018 : comment SUFOSAT date la première année, et ce qu'un départ en 2018 changerait (mission 031)

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il ne contient que des chiffres agrégés (au plus au mois
> pour les dates publiées) : aucune valeur de pixel de la v3.0.1, aucun extrait.

Développeur (agent `dev`), 2026-11-24, sur le poste de Pascal. Script :
[`perimetre-2018.R`](perimetre-2018.R) (étapes `executer`, `calculer`, `signal`, `mesurer`). Points de
départ : [`regles-de-date.md`](regles-de-date.md) (027, groupe « Début de série ») et
[`referentiels/parametres-sufosat.md`](../referentiels/parametres-sufosat.md).

**Problème, en une phrase.** Les ratios du package partent du 1er janvier 2019 (`annee_noyau + 1`), alors que la
v3.0.1 publie des dates de 2018 (2 822 des pixels tardifs de 027) : l'article dit-il comment dater 2018, un départ
en 2018 est-il permis, et que change-t-il sur la tuile pilote, pour que Pascal décide si 2018 est dans le périmètre ?

**Base de ces chiffres.** Package tel que sur `main` (règle de date actuelle, R0 de 027 ; la mission 030 n'est pas
livrée dans cette branche, donc **rien ici n'est mesuré sous R2**). Tuile pilote des Landes (30TXP, AOI de 10 km x 10 km),
une seule, un seul passage de chaque calcul : pas d'intervalle de confiance.

## 1. Ce que dit l'article (lu sur le dépôt HAL hal-04675627v1, pagination IEEE de l'en-tête)

Mermoz et al. (2024), IEEE JSTARS 17, p. 13743-13764. Page = page de l'article ; la version éditeur n'a pas été lue
(voir `parametres-sufosat.md`).

| Point | Ce que l'article écrit | Où |
|---|---|---|
| Noyau du filtre | « The filtering kernel (...) was calculated using the Sentinel-1 images acquired in 2018 and used to filter each image acquired after January 1, 2019. » | § II-B.1, p. 13746 |
| Images lues | « The entire Sentinel-1A archive over this area of interest was processed » ; aucune image de 2017 citée | § II-B.1, p. 13746 |
| Première année traitée | La méthode est « first applied to Sentinel-1 data acquired in 2019 » pour **corriger le masque forêt** ; « we then applied the clear-cuts detection method on Sentinel-1 data acquired from **January 2020 to July 2023** » | § II-D.1, p. 13748 |
| Période des données radar | « Radar backscattering, 2020-2023 » ; neige et feu : 2019-2022 ; polygones de validation : 2019-2022 | Table I, p. 13744 |
| Résultats | Les cartes et les surfaces vont de 2020 à juillet 2023 (« remarkable stability over time from 2020 ») | résumé, p. 13743 ; § III-B |
| Mb | `Xb` défini (« Xb images before and including date d_i ») mais sa valeur n'est pas donnée ; Bouvet et al. (2018) prend toutes les images antérieures | § II-D.1, p. 13747 ; Bouvet § 2.3.2, p. 10 |
| Début de série chez Bouvet | RCR calculable pour i dans [Xb, N - Xa] ; filtre fait « avec les seules images antérieures », 18 images disponibles au début de la période | Bouvet § 2.2.1, p. 4 ; § 2.3.2, p. 10 |

**Ce que l'article ne dit pas :** aucune détection datée de 2018 ; aucun traitement des images de 2018 elles-mêmes ni de
leurs ratios ; aucune règle de début de série pour `Mb`.

**Ce que dit la page de la collection** (THEIA / CESBIO, doi:10.71961/M18T-KB92, lue le 2026-11-24) : la **version 1.0**
est « le résultat de la méthode publiée dans l'article » (janvier 2020 - juillet 2023). La **version 2.0** « étend la
période de détection (janvier 2018 - août 2024) » **et modifie « certains aspects de l'algorithme » : masque neige affiné,
« adaptative Radar Change Ratio computation »**. La 3.0 ajoute un masque neige analytique, des seuils ajustés par type de
forêt et un calcul du RCR « ajusté ». La 3.0.1 ne change que la période (janvier 2018 - septembre 2025). La page renvoie à l'article pour le détail : **le
calcul adaptatif du RCR n'y est pas décrit.**

## 2. Un départ des ratios en 2018 est-il permis par la méthode écrite ?

**Non écrit, non interdit : l'article ne dit rien de 2018.** Ce qui est écrit (noyau sur 2018, filtre appliqué à partir du
1er janvier 2019, détection de 2020 à 2023) donne 2019 comme première année de ratios (c'est la lecture du package, `annee_noyau + 1`)
et 2020 comme première année de carte publiée par l'article. Les dates de 2018 de la v3.0.1 viennent de la version 2.0 et
suivantes, dont le changement d'algorithme (RCR adaptatif) n'est pas décrit. **La v3.0.1 fait donc autrement que ce qui est
publié sur ce point précis, et ce « autrement » n'est pas lisible.** Le « noyau 2017 » et le « noyau plus court » essayés ici sont
des hypothèses de l'équipe, pas des lectures de l'article ; c'est aussi pourquoi la v3.0.1 n'est pas un moyen de vérifier le choix
(elle date 2018 par une règle inconnue).

## 3. Ce que change un départ en 2018 sur la tuile pilote

### Ce qui a tourné

| Élément | Valeur |
|---|---|
| **A. Package relancé, noyau 2017** | `nemetonsar_run()` avec `parametres_sufosat(annee_noyau = 2017)` et rien d'autre de changé (même AOI, période 2018-01-01 à 2025-09-30, BD Forêt par le WFS, réglages par défaut). Noyau calculé sur 2017, ratios dès le 1er janvier 2018. 765 images lues (676 pour la carte de 017 : +89 images de 2017), 76 min (contre 46 min pour 026, sur un poste chargé). Carte comparée à celle de 017 (`annee_noyau = 2018`) sur les mêmes cellules |
| **B. Noyau 2018 conservé, ratios dès 2018** | Pas de lecture : depuis le VH filtré relevé par 026 (noyau 2018 appliqué à toutes les images, 2018 comprises, ce que le package fait déjà), ratios recalculés avec un premier ratio en 2018, et un nombre minimal d'images dans `Mb` de 1, 3, 5 ou 10 (le « noyau plus court » et le « départ prudent »). Règle de date = R0. Pixels : les 103 804 datés de la tuile par 017 et les 54 160 communs aux deux cartes (ceux de 024 à 027) |
| **Contrôle de B** | Le départ actuel (2019, 1 image) refait, par ce chemin (VH au centième de dB, ratios recalculés, passe 2019 coupée à la première image de 2020, pixel daté si son minimum de détection est sous tp), la date de la carte de 017 à ±15 j pour **99 666 pixels sur 103 804 (96,0 %)**. Moins bon que les 99,1 % de 027, qui choisissait la passe d'après l'année de la carte ; ici le choix est fait sans la carte. **B est une approximation au pixel de la détection par objets** (pas de graine, de surface minimale ni de fermeture) |
| **Signal** | Pour les pixels communs, le minimum du ratio de détection (xb = Inf) à ±15 j de la date publiée, sur les 3 orbites, avec `Mb` d'au moins 1, 5 ou 10 images |

### Les pixels publiés en 2018

La v3.0.1 date **14 324 pixels de l'AOI en 2018**. Par mois, ils se placent presque tous en été : **juillet à septembre = 93,5 %**
(1 195, 4 097 et 8 097 pixels), 45 en avril, 15 en mai, 337 en juin, 443 en octobre, 93 en novembre, 2 en décembre ; **aucun de janvier à mars**.

| | Carte de 017 (départ 2019) | Carte relancée, noyau 2017 (A) |
|---|---|---|
| Pixels publiés en 2018 que la carte date (n'importe quelle année) | 2 890 (20,2 %) | 2 904 (20,3 %) |
| dont datés **en 2018** | 0 | **205 (1,4 % des 14 324)** |
| Sur ces pixels communs : écart à la date publiée ≤ 15 j | 0 % | **3,1 %** |
| Sur ces pixels communs : écart ≤ 60 j | 0 % | 4,6 % |
| Sur ces pixels communs : plus de 180 j trop tard | 97,7 % | 92,0 % |

Un départ en 2018 **retrouve environ 1 % des pixels publiés en 2018** (≤ 60 j : 4,6 % de 2 904 communs, soit environ 130 pixels sur 14 324).
Variante B (noyau 2018 conservé), sur les 2 881 communs publiés en 2018 : ≤ 15 j 1,2 % (1 image minimale) à 1,6 % (10 images) ; ≤ 60 j 2,3 % à 2,8 %.

**Le signal n'est pas dans la série à la date publiée.** Part des pixels communs dont le ratio de détection passe sous tp (-3,45 dB) à ±15 j de la date publiée :

| Groupe | Pixels | Sous tp | Sous -3,0 dB | Médiane du minimum |
|---|---:|---:|---:|---:|
| Publiés en 2018 | 2 890 | **14,1 %** | 28,3 % | -2,57 dB |
| dont groupe « début de série » de 027 | 2 822 | 13,5 % | 27,4 % | -2,55 dB |
| Publiés en 2019 | 10 626 | 61,7 % | 76,8 % | -3,70 dB |
| Publiés en 2020 et après | 40 644 | 53,0 % | 70,4 % | -3,52 dB |

Le résultat est le même avec 1, 5 ou 10 images minimales dans `Mb` (13,7 % à 14,1 % pour 2018) : ce n'est pas un effet de `Mb` trop court.
Par mois publié (juillet à septembre, 1 419 pixels en septembre, 778 en août) la part reste de 13 à 16 %. **Limite :** ces mesures portent sur les
pixels que **notre** carte date aussi (les communs) ; les 11 434 pixels publiés en 2018 que notre carte ne date pas du tout n'ont pas été
examinés un par un (la carte relancée n'en date en 2018 que 205 au total).

### Ce qu'un départ en 2018 coûte ailleurs

Carte relancée (A), noyau 2017, contre la carte de 017 :

| Mesure | 017 (départ 2019) | A (noyau 2017) | v3.0.1 |
|---|---:|---:|---:|
| Pixels datés | 104 165 | 119 925 | 103 482 |
| dont datés en 2018 | 0 | **26 949** | 14 324 |
| dont datés en 2019 | 43 905 | 24 009 | 21 643 |
| dont datés en 2020 | 7 145 | 10 312 | 18 124 |
| Accord ≤ 15 j sur les pixels publiés **en 2019 et après** (n = 51 270 / 50 361) | 27,9 % | 27,1 % | |
| Plus de 180 j trop tard (même base) | 43,6 % | 45,2 % | |
| Sur ces mêmes pixels datés par les deux cartes : gagnés / perdus à ≤ 15 j | | 332 / 603 | |

- La carte relancée date **26 949 pixels en 2018, dont 25 805 (95,8 %) absents de la v3.0.1**, 205 (0,8 %) datés 2018 par elle aussi, 939 (3,5 %) datés
  d'une autre année. Ils se placent surtout en **avril (12 222) et février (2 633)**, des mois où la v3.0.1 n'en publie à peu près aucun (45 en avril, 0 en février).
- 10 732 pixels que la carte de 017 datait en 2019 ou après sont datés en 2018 par la carte relancée ; 9 507 pixels datés par 017 ne le sont plus, 25 267 sont nouveaux.
- Sur les pixels datés par les deux cartes, **22,7 % (21 455 sur 94 658) changent de date de plus de 15 j.**
- L'accord avec la v3.0.1 sur 2019 et après **baisse un peu** (-0,8 point à ≤ 15 j) ; les pixels que le départ en 2018 « déplace » vers 2018 sont, pour 86 % des cas
  (variante B, 1 image), des pixels que la v3.0.1 publie en 2019 ou après.

Variante B (noyau 2018 conservé), pixels communs, accord à ≤ 15 j sur les pixels publiés en 2019 et après (n = 50 974) :

| Départ des ratios | Minimum d'images dans `Mb` | Accord ≤ 15 j | Passent en 2018 (communs) | dont publiés en 2018 | dont publiés en 2019 ou après | Gagnés / perdus à ≤ 15 j (communs) | Pixels de la tuile qui passent en 2018 (sur 103 163) |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1er janvier 2019 (actuel) | 1 | 28,2 % | 0 | 0 | 0 | 0 / 0 | 0 |
| 1er janvier 2018 | 1 | 27,1 % | 1 656 | 227 | 1 429 | 64 / 588 | 15 053 (14,6 %) |
| 1er janvier 2018 | 3 | 27,4 % | 1 034 | 179 | 855 | 66 / 404 | 13 565 |
| 1er janvier 2018 | 5 | 27,7 % | 624 | 120 | 504 | 69 / 288 | 12 000 |
| 1er janvier 2018 | 10 | 27,8 % | 485 | 88 | 397 | 67 / 228 | 9 304 (9,0 %) |

Plus on exige d'images dans `Mb`, moins le départ en 2018 coûte (588 pixels perdus à 228), mais **il ne retrouve jamais plus de 1,6 % (≤ 15 j) des communs publiés en 2018**. Les dates de 2018
de la variante B se placent aussi en février-avril (variantes à 1 et 3 images : février 2 375, avril 4 650) ; avec 10 images minimales, elles passent à mai-septembre (3 364 en mai, 2 674 en septembre).

## 4. Ce qui se lit, et ce qui ne se lit pas

**Lu :** l'article ne décrit aucune détection de 2018 ; il part de 2019 pour le masque et de 2020 pour la carte. La v3.0.1 date 2018 par une règle (RCR « adaptatif », masque neige)
que ni l'article ni la page de la collection ne décrivent.

**Mesuré :** sur la tuile pilote, dater 2018 avec la méthode écrite (noyau 2017 ou 2018, ratios dès 2018) ne retrouve qu'environ 1 % des dates 2018 de la v3.0.1,
fabrique en 2018 un nombre de pixels (26 949) près de deux fois celui de la v3.0.1 (14 324), presque tous absents d'elle, et abaisse un peu l'accord des années suivantes. À la date publiée,
86 % des pixels que nous datons plus tard (communs) n'ont **aucune chute** sous tp dans nos séries (contre 38 à 47 % pour les années suivantes).

**Non lu, non mesuré (à ne pas déduire de ce rapport) :**

- **Pourquoi** les 2018 de la v3.0.1 sont à 93 % en juillet-septembre et absents de janvier à mars. Une hypothèse, non testée : des coupes antérieures à 2018 datées à la première
  image où le calcul adaptatif les voit. Une autre : une règle de neige ou de début de série propre aux versions 2.0 et suivantes. Les deux demandent la documentation de ces versions ou une question à
  GlobEO / CESBIO.
- Si la v3.0.1 a **raison** en 2018 : ce n'est pas une vérité terrain (027, 026). On n'a pas regardé d'orthophoto de 2018 pour ce rapport.
- Les 11 434 pixels publiés en 2018 que notre carte ne date pas (80 %).
- Une autre tuile, un autre massif : un seul site.

## 5. Ce que Pascal décide, et le prix

La mission ne règle rien : elle chiffre. Les deux voies, avec ce que chacune fait payer (test du roseau et du chêne : d'abord « si je tiens, qui paie ? », puis « si je plie, qui paie ? »).

| | Tenir : ratios dès 2019 (statu quo) | Plier : ratios dès 2018 |
|---|---|---|
| Qui paie | L'utilisateur qui veut les coupes de 2018 : le package n'en date aucune (14 324 pixels publiés sur la tuile, soit 14 % des pixels datés de la v3.0.1) | L'utilisateur qui lit les cartes de 2018 à 2020 : environ 26 000 dates en 2018 dont 96 % absentes de la v3.0.1, et jusqu'à 1 429 dates de 2019 et après déplacées en 2018 (variante B, 1 image) ; coût de calcul +13 % d'images et +30 min mesurées (sous charge) |
| Ce qui est gagné | Écrit comme limite connue : « première année cartographiée 2019 », accord avec l'article (qui part de 2019/2020) | Environ 1 % des dates 2018 de la v3.0.1 (4,6 % à ±60 j des communs) |
| Test | On sait dire ce qu'on ne couvre pas, et c'est mesuré ici | La méthode écrite ne le justifie pas : on obtiendrait des 2018 que ni l'article ni la v3.0.1 n'appuient |

Pas de recommandation de ma part sur le périmètre (c'est la décision de Pascal), mais deux faits à garder : **la voie « plier » avec la méthode écrite n'achète presque rien**, et
**ce qui achèterait le 2018 de la v3.0.1 est le calcul adaptatif du RCR, qu'on ne sait pas lire.** Si Pascal veut 2018 dans le périmètre, la question à poser d'abord est celle de la description
de cette version (CESBIO / GlobEO), pas un réglage de `annee_noyau`.

## 6. Limites

- Une tuile, un site (Landes de Gascogne, résineux), un seul passage ; pas d'intervalle de confiance.
- La variante B approxime au pixel une détection qui est faite par objets (graine, 0,1 ha, fermeture) ; son contrôle redonne la carte de 017 à ±15 j sur 96,0 % des pixels.
- La carte relancée (A) mélange deux changements : le noyau (2017 au lieu de 2018) et le départ des ratios. B isole le départ : les deux donnent la même baisse d'accord (27,1 % à ≤ 15 j sur 2019 et après), donc la baisse vient du départ, pas du noyau.
- Le recalcul passe par VH au centième de dB (séries relevées par 026) : écart de ratio négligeable devant les seuils, non quantifié ici.
- Seul le sens « la v3.0.1 date 2018 » est mesuré ; pas l'avis d'un tiers sur la justesse de ces dates.
- Hors périmètre : modifier le package (aucun fichier de `R/` touché).

## Pour recontrôler

```
Rscript docs/analyses/perimetre-2018.R <m031> executer
Rscript docs/analyses/perimetre-2018.R <m031> calculer <m026> <m027>
Rscript docs/analyses/perimetre-2018.R <m031> signal   <m026> <m027>
Rscript docs/analyses/perimetre-2018.R <m031> mesurer  <m026> <m027> <dates_v301.tif> <sorties_017>
```

Les tableaux ci-dessus sont le journal de `mesurer` (`A_*` : cartes complètes, `B_*` : variantes, `S_*` : signal, `M_*` : mois).
Les citations de l'article se contrôlent sur `https://hal.science/hal-04675627/document` (pdftotext -layout : « kernel », « January 2020 to July 2023 », « Table I »).

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2017–2025. Sentinel-1 RTC processed
  by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  masque forêt de la chaîne (codes regroupés en forêt / non-forêt).
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0, citations courtes) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts
  in Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin
  sur la grille de la carte recalculée ; seuls des chiffres agrégés (au plus au mois) sont publiés ici.
