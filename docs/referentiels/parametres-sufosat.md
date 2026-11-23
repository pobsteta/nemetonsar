# Paramètres de la méthode SUFOSAT, relevés à la source

Mission 001 · agent `acquereur` · relevé du 2026-11-22.
Règle : une valeur n'entre ici que si elle est lue dans l'article, avec son emplacement ;
sinon « non précisé » (l'article ne le dit pas) ou « non vérifié à la source » (je n'ai
pas pu le lire). Rien n'est recopié du brief.

## Sources consultées (date de consultation : 2026-11-22)

| Réf. | Document | Version réellement lue | URL |
|---|---|---|---|
| **M24** | Mermoz S. et al. (2024), *Submonthly Assessment of Temperate Forest Clear-Cuts in Mainland France*, IEEE JSTARS 17, p. 13743-13764, doi:10.1109/JSTARS.2024.3429012 | **Manuscrit déposé sur HAL (hal-04675627v1, 23 p., déposé le 2024-08-22), mis en page IEEE avec les numéros de page 13743 à 13764 en en-tête.** Licence du dépôt HAL : CC BY-NC-ND 4.0. | https://hal.science/hal-04675627/document |
| **B18** | Bouvet A. et al. (2018), *Use of the SAR Shadowing Effect for Deforestation Detection with Sentinel-1 Time Series*, Remote Sensing 10(8), 1250, doi:10.3390/rs10081250 | **Dépôt HAL (hal-03272350v1, 20 p.), mise en page MDPI « n of 19 ».** | https://hal.science/hal-03272350/document |

Limites de la consultation :

- La page IEEE Xplore (https://ieeexplore.ieee.org/document/10604724/) est revenue vide ; je
  n'ai donc **pas lu la version éditeur** de M24. Les pages citées sont celles des en-têtes
  du dépôt HAL ; à contrôler par Pascal sur la version IEEE si elle diffère.
- mdpi.com a répondu 403 à la récupération automatique ; je n'ai pas contourné ce refus.
  B18 est lu sur HAL, pas sur mdpi.com. La pagination « n of 19 » est celle du PDF MDPI.
- Les résumés web (agris, DOAJ, Crossref) n'ont servi qu'à retrouver les dépôts HAL, pas à
  relever des valeurs.
- Non lus : S1Tiling (doc.), Quegan et Yu (2001), spécification du fichier v3.0.1. Tout ce
  qu'ils précisent reste ici « non précisé dans l'article ».
- « Page » = page de l'article ; « col. » = colonne ; Fig./Table/Éq. = numéro de l'article.

## Table des paramètres

Convention : la valeur est celle de **M24** (SUFOSAT) ; la valeur de **B18** (Bouvet) figure
dans sa propre ligne ou dans la remarque. « ND » = non précisé dans l'article.

### A. Données et prétraitement

| Paramètre | Valeur | Unité | Source | Emplacement | Remarque |
|---|---|---|---|---|---|
| Polarisation (SUFOSAT) | VH | - | M24 | § II-B.1, p. 13746, col. droite : « interferometric wide swath VH-polarized Sentinel-1A images » | Mode IW, produits GRD, orbites ascendantes et descendantes. |
| Polarisation (Bouvet) | VV seule | - | B18 | § 2.2.1, p. 4 (VV jusqu'à fin 2016, VV+VH ensuite) ; § 2.3.2, p. 11 : VH et VV « perform similarly », VV retenue pour garder une série homogène | Écart SUFOSAT/Bouvet. |
| Capteurs (SUFOSAT) | Sentinel-1A seul, pas de 1B | - | M24 | § II-B.1, p. 13746 : raisons données = grand volume d'images en Europe, homogénéité temporelle ; anomalie de 1B depuis décembre 2021, fin officielle en août 2022 | 1C et 1D : hors article (publié avant). Volume : 100 947 images, 87 tuiles (même §). |
| Capteurs (Bouvet) | Sentinel-1A et 1B (« S1 »), 92 images, 22-10-2014 à 21-09-2017, 43 ascendantes + 49 descendantes | - | B18 | § 2.2.1, p. 4 | Site du Pérou. |
| Prétraitement | S1Tiling ; calibration, orthorectification, filtrage multitemporel | - | M24 | § II-B.1, p. 13746 | Type de calibration (γ0, σ0), MNT, grille de sortie : **ND** (la grille MGRS pour S1 n'est **pas** écrite ; MGRS n'apparaît que pour Sentinel-2 et les tuiles INRAE). Résolution 10 m : Table I, p. 13744. |
| Prétraitement (Bouvet) | Calibration γ0 ; orthorectification UTM 10 m avec MNT SRTM 30 m ; chaîne OTB | - | B18 | § 2.2.1, p. 4 | ENL approx. 4,4 avant filtre. |
| Filtre multitemporel, type | Filtre multitemporel de Quegan et Yu | - | M24 | § II-B.1, p. 13746 : « multitemporal filter described in [28] », [28] = Quegan et Yu, IEEE TGRS 39(11), 2001 (liste des références) | Le nom Quegan et Yu vient de la référence [28], pas du corps du texte. |
| Filtre, fenêtre | 3 x 3 | pixels | M24 | § II-B.1, p. 13746 | Aucun autre filtre de speckle (« no further speckle reduction methods »). |
| Filtre, noyau | Rapport moyen entre images filtrées spatialement et images originales, calculé sur les images de **2018** | - | M24 | § II-B.1, p. 13746 | Paramètre `annee_noyau` = 2018. |
| Filtre, application | Noyau appliqué à chaque image acquise **après le 1er janvier 2019** | - | M24 | § II-B.1, p. 13746 | Le traitement des images de 2018 elles-mêmes : **ND**. |
| Filtre (Bouvet) | Fenêtre 3 x 3 ; chaque image filtrée **avec les seules images antérieures** (simulation du temps quasi réel) ; ENL jusqu'à 39,6 | pixels | B18 | § 2.2.1, p. 4 ; réfs [24,25] (Quegan et Yu = [25]) | Écart SUFOSAT/Bouvet. |

### B. Ratio de changement radar (RCR)

| Paramètre | Valeur | Unité | Source | Emplacement | Remarque |
|---|---|---|---|---|---|
| Définition du RCR | RCR = Ma / Mb ; Mb = moyenne temporelle de la rétrodiffusion sur Xb images avant la date di (incluse) ; Ma = moyenne sur Xa images à partir de di+1 (incluse) | - | M24 ; B18 | M24 § II-D.1, p. 13747 ; B18 § 2.3.2, p. 10, Éq. (1) | B18 donne la somme explicite sur γ0. |
| Xa | 3 | images | M24 ; B18 | M24 § II-D.1, p. 13747 (« Xa was fixed at 3 », réduit le speckle et les fausses alertes mais retarde les détections, comparé à 1 et 2) ; B18 § 2.3.2, p. 10 (et § 4, p. 17 : retard d'environ 1 mois à 12 j de revisite) | Même valeur dans les deux articles. |
| Xb (SUFOSAT) | **ND** (M24 définit Xb mais n'en donne pas la valeur) | images | M24 | § II-D.1, p. 13747 | Le défaut `xb = Inf` du brief et de la spec vient de B18, pas de M24. |
| Xb (Bouvet) | Toutes les images acquises avant la date (« average all images acquired before the considered date ») | images | B18 | § 2.3.2, p. 10 | Éq. (1) est écrite pour Xb fini ; l'exemple de la Fig. 8 prend Xb = 5. |
| Délai de détection | 12 à 24 jours après l'arrivée d'une nouvelle image, pour une cadence de 6 jours (2 satellites) ou 12 jours (1 satellite) | jours | M24 | § II-D.1, p. 13747 | Valeur de l'article ; la spec la garde comme provisoire à mesurer. |
| Unité du ratio | Seuils et valeurs du ratio exprimés en **dB** (ex. ts = -4,5 dB, RCR = -5,2 dB) | dB | M24 ; B18 | M24 § II-D.1, p. 13748 ; B18 § 2.3.2, p. 10 (Fig. 8) et p. 11 | **Le passage linéaire/dB n'est pas écrit** : Éq. (1) de B18 fait la moyenne de γ0 (coefficient de rétrodiffusion), puis le ratio est exprimé en dB ; B18 p. 16 parle de « rapport d'intensité ». La moyenne se fait donc très probablement sur des valeurs linéaires, mais **ni M24 ni B18 ne le disent explicitement**. À trancher avec Pascal (règle de test dB du CLAUDE.md). |
| Date retenue pour une coupe | Date du RCR minimal, si ce minimum est sous un seuil | - | M24 ; B18 | M24 § II-D.1, p. 13747 : « the date corresponding to the lowest RCR value » ; B18 § 2.3.2, p. 11 : min(RCRi) < Y dB, intervalle [dk, dk+1] avec RCRk = min(RCRi) | Date calendaire exacte (di ou di+1) retenue : **ND** dans M24. |
| Combinaison ascendante / descendante | **ND dans M24** : l'article dit que les images ascendantes et descendantes sont traitées, jamais comment leurs RCR se combinent | - | M24 | § II-B.1, p. 13746 (seule mention des orbites) ; seul indice indirect, § II-D.1, p. 13748 : « We then mosaicked and cleaned the resulting map » (mosaïquage et nettoyage de la carte, sans dire comment les orbites se combinent) | **Réponse au point « à relire en section II » de la spec : l'article ne le précise pas.** Chez B18 : seuil appliqué à « l'image formée par le minimum temporel du RCR **dans les deux orbites** » (§ 2.3.2, p. 11), formule ambiguë (minimum des deux ? image par orbite ?) ; l'appariement ascendante/descendante avec enveloppe convexe est une autre option, § 2.3.3, p. 11 (Fig. 10). Le brief affirme « séparément », non vérifié à la source. |

### C. Seuillage et segmentation

| Paramètre | Valeur | Unité | Source | Emplacement | Remarque |
|---|---|---|---|---|---|
| ts (seuil des ombres) | -4,5 | dB | M24 (reprise de B18) ; B18 | M24 § II-D.1, p. 13748 : seuil « optimal » de [23] = B18, « initially adapted to the tropics » ; B18 § 2.3.2, p. 11 (-4,5 dB, VV, minimum de 2016) | Valeur **empirique de Bouvet** (B18 p. 16 : « chosen empirically »), VV, Pérou ; SUFOSAT la reprend. À ne pas étiqueter « SUFOSAT » seule. |
| tp (seuil des taches) | -3 | dB | M24 (reprise de B18) ; B18 | M24 § II-D.1, p. 13748 ; B18 § 2.3.3, p. 12 | Idem : empirique chez B18 (p. 16). |
| Facteur de correction des seuils (valeur finale) | **1,15**, multiplicatif sur ts et tp | - | M24 | § III-A, p. 13750 (« threshold correction factor of 1.15, which we thus used for deriving the final clear-cuts maps ») | Critère de choix : rappel > 80 % avec la plus haute précision (§ II-D.2, p. 13749). Produits : -4,5 x 1,15 = -5,175 dB et -3 x 1,15 = -3,45 dB (calcul ; M24 ne donne pas ces deux nombres). |
| Facteur, plage testée | 0,8 à 1,2, pas 0,05 | - | M24 | § II-D.1, p. 13748 ; Fig. 3, p. 13749 | Exemple de M24 : facteur 1,1 donne ts = -4,95 dB et tp = -3,3 dB, système plus strict. |
| Métriques à 1,15 (tous types de forêt) | Rappel 80,9 % ; précision 99,4 % ; F1 89,2 % ; exactitude globale 87,6 % | % | M24 | § III-A, p. 13750 | Validation sur 967 polygones. |
| Métriques à 1,0 (meilleurs OA et F1) | F1 = 94,7 % (tous), 93,1 % (feuillus), 96,5 % (résineux) | % | M24 | § III-A, p. 13749 ; Fig. 3 | Rappel et précision à 1,0 : lisibles seulement sur la Fig. 3, **non relevés** (valeurs chiffrées absentes du texte). |
| Validation par objets | Polygone « coupe » vrai positif si plus de 75 % de sa surface est détectée ; polygone « sans coupe » vrai négatif si plus de 75 % non détectée | % | M24 | § II-D.2, p. 13748-13749 | 967 polygones, dessinés sur images THR : § II-B.2, p. 13746 ; 63 % « coupes », 37 % « sans coupe ». |
| Croissance de région, principe | Pixels à RCR très bas = graines ; extension sur les valeurs « modérément négatives » ; on ne garde que les taches associées à une ombre | - | M24 ; B18 | M24 § II-D.1, p. 13747-13748 ; B18 § 2.3.3, p. 12 (« only those that intersect with a detected shadow are kept ») | Le « même image du minimum RCR » pour les deux seuils est écrit chez B18 (p. 12), pas chez M24. |
| Connexité de la croissance de région | **ND** (4 ou 8 voisins) | - | M24 ; B18 | M24 § II-D.1 ; B18 § 2.3.3, p. 12 | Ni l'un ni l'autre ne précise ; B18 parle de taches « connectées » (Fig. 11) sans type de voisinage. |
| Objets minimaux, ombres (Bouvet) | Segments de plus de 4 pixels (tamisage, « sieving ») | pixels de 10 m | B18 | § 2.3.2, p. 11 | M24 : **ND** pour les ombres. |
| Objets minimaux, taches (Bouvet) | Segments de plus de 10 pixels (tamisage) | pixels de 10 m | B18 | § 2.3.3, p. 12 | Équivaut à 0,1 ha à 10 m, mais B18 l'écrit en pixels. |
| Contour des coupes (Bouvet) | Alpha shapes (fonction MATLAB `boundary`), facteur de rétrécissement 0,6, choisi visuellement | - | B18 | § 2.3.3, p. 12 | M24 n'en parle pas : **ND**. |

### D. Post-traitement et masques

| Paramètre | Valeur | Unité | Source | Emplacement | Remarque |
|---|---|---|---|---|---|
| Surface minimale | Détections de moins de 0,1 ha écartées | ha | M24 | § II-D.1, p. 13748 ; rappel « 0.1 ha minimum mapping unit » p. 13747 | Écartées avant la fermeture. |
| Fermeture morphologique | Appliquée « pour lisser légèrement » les zones détectées, après l'élimination des objets < 0,1 ha | - | M24 | § II-D.1, p. 13748 (« a closing morphological operation has been applied to slightly smooth detection areas ») | Élément structurant (taille, forme) : **ND**. À fixer par ADR/paramètre ; ne pas inventer. |
| Masque forêt, produit | Copernicus CLMS, Tree Cover Density 2018, 10 m | - | M24 | Table I, p. 13744 ; § II-C, p. 13747 | Version exacte du produit : ND. |
| Seuil TCD | Couvert arborescent minimal de 10 % (définition de la forêt de la FAO) | % | M24 | § II-D.1, p. 13747, col. droite | |
| Correction du masque forêt | Méthode appliquée d'abord aux données Sentinel-1 de **2019** sur la France métropolitaine et la Corse ; ces détections servent à **mettre à jour** le masque forêt/non-forêt (retirer sols nus, cultures à forte variabilité) ; la détection est ensuite lancée de janvier 2020 à juillet 2023 | - | M24 | § II-D.1, p. 13748 | La règle de mise à jour (retirer tout pixel détecté en 2019 ? autre) : **ND**. |
| Masque neige, produit | MODIS/Terra MOD10A1, couverture neigeuse quotidienne, 500 m, algorithme NDSI | - | M24 | Table I, p. 13744 ; § II-D.1, p. 13748 | Fin de Terra annoncée : hors article. |
| Masque neige, règle mensuelle | Pour un mois donné, on calcule la **surface** détectée par le produit neige (quotidien), puis on **masque les images Sentinel-1 de ce mois** ; les détections s'arrêtent temporairement ; toute coupe est détectée avec un retard d'au plus un mois | - | M24 | § II-D.1, p. 13748 | Seuil de surface enneigée déclenchant l'écartement, règle par image ou par pixel, agrégation : **ND**. Période appliquée : janvier 2020 à juillet 2023 (même §). |
| Masque feu, produit | EFFIS, cartes annuelles de surfaces brûlées, haute résolution (Table I : polygones, 30 m) | - | M24 | Table I, p. 13744 ; § II-D.1, p. 13748 | |
| Masque feu, seuil | Objets détectés touchés par le feu sur **75 % ou plus** de leur surface sont écartés ; masquage temporaire (une forêt brûlée morte ou coupée est ensuite détectée) | % | M24 | § II-D.1, p. 13748 | Rappel : ce 75 % est le seuil du **masque feu**, distinct du 75 % de la validation. |

### E. Paramètres qui diffèrent : synthèse Bouvet (2018) contre SUFOSAT (2024)

| Point | Bouvet et al. (2018) | Mermoz et al. (2024) |
|---|---|---|
| Polarisation | VV (B18 p. 4, p. 11) | VH (M24 p. 13746) |
| Calibration / MNT | γ0, SRTM 30 m (B18 p. 4) | ND (S1Tiling cité) |
| Filtre multitemporel | Images antérieures seules, 3 x 3 (B18 p. 4) | Noyau 2018 appliqué à partir du 1er janvier 2019, 3 x 3 (M24 p. 13746) |
| Xa / Xb | 3 / toutes les images antérieures (B18 p. 10) | 3 / ND (M24 p. 13747) |
| ts / tp | -4,5 / -3 dB (B18 p. 11-12) | -4,5 / -3 dB x 1,15 (M24 p. 13748, 13750) |
| Nettoyage | Ombres > 4 px, taches > 10 px (B18 p. 11-12) | Objets < 0,1 ha écartés, puis fermeture (M24 p. 13748) |
| Contour | Alpha shapes, 0,6 (B18 p. 12) | ND |
| Masque forêt | Masque forêt/non-forêt jugé souhaitable mais non disponible à grande échelle ; aucun n'est cité comme utilisé (§ 2.3.4, p. 12) | TCD 2018 >= 10 %, corrigé par les détections 2019 (M24 p. 13747-13748) |
| Neige, feu | Non traités (masque du lit des rivières seulement, B18 p. 12) | MOD10A1 mensuel, EFFIS >= 75 % (M24 p. 13748) |

Piste de B18 non retenue par M24 : retirer la tendance temporelle moyenne des forêts
naturelles (`gamma0_j - t_j`) avant le ratio, pour les forêts saisonnières (B18 § 4,
p. 17). Aucune valeur chiffrée : à tester après la v1.

## Écarts constatés avec `docs/brief.md` et `docs/spec.md`

1. **Combinaison ascendante/descendante** : le brief (étape 4) écrit « calculé séparément en
   orbite ascendante et descendante » et la spec demande de la relire en section II. M24 ne
   dit **rien** de la combinaison ni de l'agrégation. À poser à Pascal (ou à GlobEO/CESBIO).
2. **ts et tp ne sont pas des valeurs « SUFOSAT » d'origine** : ce sont les valeurs
   empiriques de Bouvet (VV, Pérou), reprises par M24 (p. 13748) puis multipliées par 1,15.
   Le brief les attribue à la section II de M24 : exact pour la reprise, à nuancer dans la
   spec (colonne « source »).
3. **Étape 5 du brief** (« les deux seuils s'appliquent à la même image du ratio minimal dans
   le temps », « ne garde que celles qui touchent une ombre ») : l'énoncé est de **B18**
   (§ 2.3.3, p. 12) ; M24 dit seulement « object-oriented segmentation ... seeds and extends »
   (p. 13747-13748). Le brief l'inscrit sous « paramètres de la section II ».
4. **Fermeture morphologique** : le brief la cite sans paramètre, M24 aussi ; élément
   structurant **non précisé**. La spec expose `fermeture = TRUE` seulement : manque la taille
   et la forme.
5. **Masque neige** : le brief dit que les images « des zones enneigées » sont écartées ; M24
   dit qu'on calcule la **surface** détectée par MODIS puis qu'on masque **les images du
   mois** (p. 13748). Écart possible entre pixel et image ; seuil de surface **non précisé**.
   De plus, M24 n'applique ce masque que de janvier 2020 à juillet 2023 (Table I : neige
   2019-2022), le brief le présente comme règle générale.
6. **Grille MGRS** : le brief et le CLAUDE.md disent « tuiles MGRS 10 m (S1Tiling) » ; M24 dit
   10 m (Table I) et « 87 tiles » mais **n'écrit pas MGRS pour Sentinel-1**. Le fichier v3.0.1
   (non lu ici) est la bonne source pour la grille.
7. **Calcul du ratio** : le brief/la spec ne tranchent pas linéaire/dB ; **ni M24 ni B18 ne
   l'écrivent**. Hypothèse la plus probable (moyennes linéaires, ratio en dB), non vérifiée
   à la source.
8. **Précisions du brief confirmées** : Xa = 3 ; filtre 3 x 3, noyau 2018, application dès
   le 1er janvier 2019 ; TCD 10 % ; correction 2019 ; 0,1 ha ; EFFIS 75 % ; facteur 1,15
   avec rappel 80,9 % et précision 99,4 % ; F1 maximal de 94,7 % à facteur 1 ; F1 feuillus
   93,1 % et résineux 96,5 % ; 100 947 images sur 87 tuiles ; tableau Bouvet du brief
   (VV, 4 px, 10 px, alpha 0,6, Xb = toutes antérieures) confirmé ligne à ligne. Ajout : F1 =
   89,2 % et OA = 87,6 % à 1,15 (p. 13750).
9. **Statut du texte** : le brief dit « Lu pour les sections II et III » ; ce relevé confirme
   les valeurs sur le manuscrit HAL, pas sur la version éditeur IEEE (voir en tête).

## Échantillon à vérifier par Pascal (deux pages de M24)

À ouvrir sur la version IEEE (le relevé est fait sur le manuscrit HAL) :

| Page | Valeurs à y retrouver |
|---|---|
| 13747 (§ II-D.1) | Xa = 3 ; TCD 2018, forêt = couvert minimal de 10 % ; délai de détection 12 à 24 jours (cadence de 6 ou 12 jours) ; date retenue = RCR le plus bas ; rappel : 0,1 ha comme unité minimale de cartographie |
| 13748 (§ II-D.1) | ts = -4,5 dB et tp = -3 dB ; facteur 0,8 à 1,2 par pas de 0,05 (exemple 1,1 : -4,95 et -3,3 dB) ; détections 2019 pour corriger le masque forêt ; objets < 0,1 ha écartés puis fermeture ; masque neige MODIS mensuel (retard d'au plus un mois) ; EFFIS : 75 % de la surface ; phrase « mosaicked and cleaned » |

## Liste de contrôle passée (`liste-de-controle.md`), ligne à ligne

Réserve générale : les pages de M24 sont celles du **manuscrit HAL** (en-têtes IEEE), pas de la
version éditeur ; B18 est lu sur le dépôt HAL, pas sur mdpi.com (403).

1. Chaque chiffre a sa source et son emplacement
   - [x] Source, page ou ligne, version, date pour chaque valeur : oui (versions = manuscrits HAL, consultés le 2026-11-22). Les valeurs calculées (-5,175 ; -3,45 dB) sont signalées comme calculs.
   - [x] URL réellement consultées : inscrites en tête. Celles qui ont échoué (IEEE Xplore vide, mdpi.com 403) y sont dites.
   - [x] Référence datée par sa version : manuscrit HAL hal-04675627v1 (déposé 2024-08-22) et hal-03272350v1.
   - [ ] Emplacements relus sur la version à jour : **non** ; relus sur le manuscrit HAL, pas sur la version IEEE (page vide) ni sur mdpi.com (403). D'où l'échantillon à vérifier par Pascal.
2. Les décomptes sont complets
   - [x] Décomptes (967 polygones, 100 947 images, 87 tuiles, 4 530 parcelles non utilisées ici) recopiés du texte ; non recomptés (aucune commande de comptage possible sur un texte).
   - [x] Correction de décompte : sans objet, aucune correction.
   - [x] Aucune entrée omise : les paramètres demandés par la mission sont tous présents, ou dits « ND ».
3. Les termes sont exacts
   - [x] Bornes recopiées du texte (0,8 à 1,2, pas 0,05 ; 75 % ; 10 %).
   - [x] Valeur ajoutée partout où elle se retrouve : table, synthèse Bouvet/SUFOSAT, écarts.
   - [x] Limites dites : versions non lues, éléments non précisés, Fig. 3 non lue en chiffres (rappel et précision à 1,0).
4. Le statut est dit tel qu'il est
   - [x] Chaque élément porte son état : confirmé, « non précisé » (ND), ou « non vérifié à la source ».
   - [x] Dépendances entre PR : sans objet (aucune branche, aucun git).
5. Pour le testeur : sans objet (l'agent est l'acquéreur).
