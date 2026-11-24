# Règle de date R2 sur la tuile pilote : mission 030

> **Usage non commercial.** Ce rapport contient des chiffres tirés d'une comparaison à la
> carte SUFOSAT v3.0.1 (CC BY-NC 4.0). Il hérite de la clause non commerciale (ADR 0002,
> `docs/referentiels/licences.md`). Il ne contient que des chiffres agrégés ; les sept pixels
> tracés y figurent avec la date de la règle R2, pas avec celle de la v3.0.1 (voir le rapport de
> la mission 027 pour le mois publié).

Développeur, 2026-11-24, sur le poste de Pascal. Script : [`regle-r2-pilote.R`](regle-r2-pilote.R)
(étapes `executer court`, `executer long`, `mesurer`). Règle définie et chiffrée par la mission 027
([`regles-de-date.md`](regles-de-date.md)) ; décisions de Pascal du 2026-11-24 : R2 par défaut, repli
sur R0, seuil de datation = seuil de détection effectif (-3,45 dB), exposé comme `seuil_datation_db`.

**Question.** Une fois R2 codée dans le package, que change-t-elle, sur une exécution réelle de la tuile
pilote, à la surface assemblée, à la correction 2019 et à la stabilité des dates quand la série est prolongée ?

## Ce qui est codé

- `parametres_sufosat(regle_date = "premiere_sous_seuil", seuil_datation_db = NULL)`. `NULL` : le seuil
  vaut `facteur_seuil * tp_db` à la construction (-3,45 dB). `regle_date = "minimum"` rend la règle d'avant.
- `rcr_compute()` rend en plus, par orbite, la première date `d_(i+1)` où le ratio de datation passe au plus
  à `seuil_datation_db` (`date_seuil`, `date_avant_seuil`, `duree_seuil_jours`). Le ratio de détection et le
  minimum sont inchangés.
- `rcr_combine_orbites()` : le ratio reste celui de l'orbite retenue par la détection ; la date est la plus
  ancienne `date_seuil` de toutes les orbites (première de la liste en cas d'égalité) ; sans passage sous le
  seuil, repli sur le minimum de l'orbite retenue (`date_repli`, `orbite_date`).
- `nemetonsar_run()` et `nemetonsar_detecter()` n'ont pas changé : ils lisent `date_min` de la combinaison.
  La correction 2019 (première détection puis détection principale) applique donc la même règle aux deux passes.
- Pas de `NEWS.md` dans le dépôt : rien à y ajouter.

## Ce qui a tourné

| Élément | Valeur |
|---|---|
| Entrées | Mêmes AOI (carré de 10 km, tuile 30TXP), réglages par défaut et masque BD Forêt que les missions 017 (série courte, 2018-01-01 au 2025-09-30, 676 images) et 029 (série longue, jusqu'au 2026-11-21, 809 images). Sorties de 017 et de 029 relues comme règle d'avant (R0) |
| Durée | 1,0 h (série courte) et 0,78 h (série longue), lecture réelle de Sentinel-1 |
| Comparaison | Même tuile, mêmes séries : seule la règle de date change. Le ratio de détection est identique pour 102 696 pixels sur 102 830 communs (cause non recherchée ; la correction 2019 retire de la forêt 41 513 pixels sous R2 contre 41 584 sous R0, ce qui change le masque de la détection principale) |

## Surface assemblée

| Carte | Objets | Surface (ha) | Objets de date médiane 2019 | Surface 2019 (ha) |
|---|---:|---:|---:|---:|
| R0, série courte | 170 | 1 105,6 | 80 | 402,9 |
| **R2, série courte** | **165** | **1 090,8** | 84 | 443,8 |
| R0, série longue | 287 | 1 468,4 | 69 | 396,1 |
| **R2, série longue** | **283** | **1 456,5** | 75 | 457,7 |

La surface assemblée baisse de **14,8 ha (-1,3 %)** sur la série courte et de 11,9 ha (-0,8 %) sur la série
longue. Pixels datés : 104 165 (R0) et 102 891 (R2), soit 1 274 de moins (-1,2 %) ; 65 804 des 102 830 pixels
datés dans les deux cartes changent de date (64 %, 027 en annonçait 71 % sur ses pixels communs).

Surface par année de la date médiane, série courte (ha) : 2019 402,9 → 443,8 ; 2020 61,6 → 230,0 ; 2021 311,1 → 174,6 ;
2022 87,7 → 121,0 ; 2023 45,9 → 81,7 ; 2024 161,6 → 27,1 ; 2025 34,6 → 12,6. Les dates se déplacent vers le
passé, surtout depuis 2024 et 2025 (R0 les datait au minimum, tardif).

## Correction 2019

| Carte | Première détection (2019) | Détection principale | Dont médiane en 2019 (écartés) | Gardés |
|---|---:|---:|---:|---:|
| R0, série courte | 100 objets, 453,2 ha | 163 | 2 (0,2 ha) | 261 |
| **R2, série courte** | 100 objets, 453,2 ha | 159 | **12 (16,0 ha, 1 602 pixels)** | 247 |
| R0, série longue | 100 objets, 453,2 ha | 301 | 2 (0,4 ha) | 399 |
| **R2, série longue** | 100 objets, 453,2 ha | 300 | **9 (13,6 ha, 1 362 pixels)** | 391 |

027 annonçait 14 objets (1 664 pixels) sur 161 de la détection principale : l'exécution réelle en donne **12 (1 602
pixels)** sur 159. La première détection (2019, avec le masque forêt seul) est la même sous les deux règles : 100
objets, 453,2 ha. Les 12 objets de la détection principale dont la médiane tombe en 2019 sont écartés
(règle de la correction 2019) et **ne sont pas repris par la première détection** : ils représentent 16,0 ha,
soit l'essentiel (15,8 ha) de la baisse de surface de 14,8 ha ci-dessus. **Non vérifié** : si ces 16 ha sont de
vraies coupes de 2019 que la première détection ne retrouve pas (série coupée en fin 2019), ou des coupes plus
tardives que R2 date trop tôt. La règle les date en 2019 ; ni la v3.0.1 ni les orthophotos n'ont été regardées pour ces 12
objets.

## Stabilité quand la série est prolongée

Pixels de la série courte dont la date tombe du 2025-01-01 au 2025-09-30, relus sur la série longue (mêmes pixels).

| Règle | Pixels | Date identique | Date changée | Sans date |
|---|---:|---:|---:|---:|
| R0 | 11 751 | 4 908 (41,8 %) | 6 843 (58,2 %) | 0 |
| **R2** | **6 967** | **6 434 (92,3 %)** | **533 (7,7 %)** | 0 |

Toutes dates de la série courte (jusqu'au 2025-09-30) : R0 89 428 identiques sur 104 165 (85,9 %), **R2 101 037 sur
102 891 (98,2 %)**, soit 1 854 changées.

**Ce que l'on peut déduire des 533 dates changées, et ce que l'on ne peut pas.** À tuile et orbites égales, une date
R2 hors repli ne peut que rester ou reculer quand la série s'allonge (tests unitaires de `test-rcr.R`, « prolonger la
série ne change pas une date déjà sortie » et « prolonger deux orbites… »). Sur l'exécution réelle, 513 des 533 pixels
sont datés plus tard en série longue (469 après le 2025-09-30, dont 2026-03 : 269, 2026-07 : 78, 2025-12 : 36 ; 44 plus
tard mais dans la série courte). Ces 513 pixels sont donc en repli, ou touchés par un changement de chaîne entre les deux
exécutions (masque de la correction 2019, orbites) ; l'exécution ne garde pas l'indicateur de repli, et la part de chaque
cause n'est pas mesurée. Seuls les 20 pixels datés plus tôt restent ambigus : un recul est permis par la règle, mais la
cause n'est pas recherchée. Déplacement médian des 533 : +293 jours. Pour les pixels en repli, la règle ne tient pas la
stabilité : le repli est la part de R0 qui reste.

Le pixel qui devient daté dans la fenêtre sans l'être en série courte (2 063 pixels sous R2, 2 062 sous R0) n'est pas
un défaut : la série courte n'avait pas les `xa` images suivantes pour les dater, ou la marche est arrivée plus tard
dans la fenêtre.

## Comparaison à la v3.0.1 (série courte, agrégée)

| | R0 (017) | R2 (030) |
|---|---:|---:|
| Pixels datés communs | 54 160 | 54 109 |
| Écart de date médian signé (j) | +101 | **0** |
| Écart de date absolu médian (j) | 192 | **36** |
| Surface recalculée (ha) | 1 105,6 | 1 090,8 |
| Part de la surface publiée retrouvée | 54,1 % | 54,1 % |
| Part de la surface recalculée absente | 49,4 % | 48,7 % |
| Rappel / précision / F1 (objets) | 22,0 % / 33,5 % / 26,6 % | 22,0 % / 34,5 % / 26,9 % |

Les écarts de date de R0 (192 j) et R2 (36 j) sont ceux que 027 avait calculés sur ses séries (191 et 36 j) : le code
du package refait ce que le script d'analyse annonçait. La détection ne bouge presque pas (même surface retrouvée,
même rappel) ; ce qui bouge est la date.

## Sept pixels tracés de 027 (L93), date sous R2

| Point (L93) | R0 (017) | R2, série courte | R2, série longue |
|---|---|---|---|
| 398525 ; 6351825 | 2021-03-04 | 2020-03-21 | 2020-03-21 |
| 398595 ; 6348385 | 2025-03-06 | 2022-02-26 | 2022-02-26 |
| 394175 ; 6352425 | 2021-03-20 | 2021-03-20 | 2021-03-20 |
| 394465 ; 6350145 | 2021-03-16 | 2021-03-04 | 2021-03-04 |
| 394475 ; 6350815 | 2022-02-26 | 2020-12-26 | 2020-12-26 |
| 393725 ; 6349945 | 2023-02-09 | 2021-03-16 | 2021-03-16 |
| 393975 ; 6349765 | 2021-03-04 | 2021-02-20 | 2021-02-20 |

Les dates de R2 du package égalent à un mois près celles que 027 donnait pour R2 (2020-03, 2022-02, 2021-03, 2021-03,
2020-12, 2021-03, 2021-02). Les sept sont stables entre série courte et série longue. À regarder sur orthophoto par
Pascal (voir le rapport de 027 pour la date publiée et la lecture de chacune).

## Ce qui n'est pas fait ni démontré

- La part des 533 re-datages de 2025 due au repli n'est pas mesurée sur les données (voir plus haut).
- Le sort des 16 ha écartés par la correction 2019 n'est pas jugé (aucune orthophoto regardée).
- L'ensemble est sur une tuile et une période ; `seuil_datation_db` reste à -3,45 dB (valeur provisoire, gèle au
  jalon 2). Aucun autre seuil essayé ici.
- Le calcul de `date_seuil` compare le rapport linéaire `Ma / Mb` au seuil converti en linéaire : les dates
  des pixels dont le ratio vaut exactement le seuil à 1e-12 près peuvent différer d'un calcul en dB.
- Les chiffres de surface par année et le nombre d'objets de 2026 (66 sous R2 contre 111 sous R0 sur la série longue) ne
  sont pas interprétés ici : la série longue contient la bascule S1C/S1D de la mission 029.

## Licences et attributions

**Usage non commercial** (CC BY-NC 4.0, hérité de SUFOSAT v3.0.1).

- **[S1]** Contains modified Copernicus Sentinel data 2018-2026. Sentinel-1 RTC processed by Catalyst,
  hosted by Microsoft Planetary Computer, CC BY 4.0.
- **[FOR]** Source : IGN, BD Forêt® version 2.0 (2006-2019), Licence Ouverte 2.0 ;
  https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. Données modifiées :
  masque forêt de la chaîne (codes regroupés en forêt / non-forêt).
- **[MET]** Méthode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764,
  doi:10.1109/JSTARS.2024.3429012 (CC BY-NC-ND 4.0) ; Bouvet et al. (2018), Remote Sensing
  10(8), 1250, doi:10.3390/rs10081250.
- **[SUF]** CESBIO. (2026): Sufosat : Submonthly Assessment of Temperate Forest Clear-Cuts
  in Mainland France. Data Terra. (Collection) doi:10.71961/M18T-KB92. Version 3.0.1,
  licence CC BY-NC 4.0. Données modifiées : extrait sur l'AOI, ramené au plus proche voisin
  sur la grille de la carte recalculée ; seuls des chiffres agrégés sont publiés ici.
