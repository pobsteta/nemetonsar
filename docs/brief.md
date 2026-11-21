# nemetonsar — Brief projet : recalcul des cartes SUFOSAT sur une AOI

21 novembre 2026 · Pascal Obstetar

## Objectif

Construire nemetonsar, un package R de la famille nemeton qui, à partir d'une zone d'intérêt (AOI) et d'une période, recalcule une carte des coupes rases selon la méthode SUFOSAT (Mermoz et al., 2024).

Le besoin vient d'un constat : la dernière version publiée (v3.0.1) s'arrête à septembre 2025 et sa mise à jour n'est pas financée. L'outil doit permettre de prolonger la série sur un territoire donné sans dépendre de la chaîne nationale.

Critères de réussite :

- Une commande unique, `nemetonsar_run(aoi, date_debut, date_fin)`, produit les rasters de date et de confiance sur l'AOI.
- Sur la période commune 2018–2025, les détections recoupent celles de la v3.0.1 publiée à un niveau fixé à l'avance (voir Validation).
- Le pipeline est relançable en incrémental : un nouveau mois de données ne retraite pas tout l'historique.

## Périmètre

La v1 reproduit la méthode telle que décrite dans l'article, sur une AOI de la taille d'un massif ou d'un département, en France métropolitaine.

| Inclus en v1 | Hors v1 |
| --- | --- |
| AOI fournie en fichier vecteur (GeoPackage, GeoJSON, shapefile) | Traitement France entière |
| Détection par radar change ratio sur Sentinel-1 VH | Améliorations v2 et v3 non documentées dans l'article (ratio adaptatif, masque de neige analytique, seuils par type de forêt) |
| Masques forêt, neige et feu | Analyses par essence, par propriété publique ou privée, par hauteur |
| Rasters date et confiance, plus polygones des coupes | Interface de visualisation en ligne |
| Rapport de comparaison avec la carte publiée | Distinction coupe rase / dépérissement au-delà de ce que fait la méthode |

## Méthode à reproduire

La détection repose sur une chute durable de la rétrodiffusion radar, mesurée par un ratio avant/après, puis sur une segmentation en deux seuils. Les paramètres ci-dessous viennent de la section II de l'article.

1. **Prétraitement Sentinel-1.** Images GRD en mode IW, polarisation VH, orbites ascendantes et descendantes, Sentinel-1A uniquement. Calibration et orthorectification avec S1Tiling, grille MGRS à 10 m.
2. **Filtrage du speckle.** Filtre multitemporel de Quegan et Yu, fenêtre 3×3. Le noyau est calculé sur les images de 2018, puis appliqué à chaque image postérieure au 1er janvier 2019. Aucun autre filtre spatial.
3. **Masque forêt.** Tree Cover Density 2018 de Copernicus, seuil à 10 % de couvert. Le masque est ensuite corrigé avec les détections de l'année 2019 pour retirer les sols nus et cultures à forte variabilité.
4. **Radar change ratio.** Pour chaque date, rapport entre la moyenne des 3 images suivantes (Xa = 3) et la moyenne de toutes les images antérieures (Xb = tout l'historique), calculé séparément en orbite ascendante et descendante. La date retenue pour une coupe est celle du ratio minimal.
5. **Seuillage en deux temps.** D'abord les ombres radar en bordure de coupe, qui servent de graines (seuil ts). Puis détection des zones modérément négatives (seuil tp), dont on ne garde que celles qui touchent une ombre. Les deux seuils s'appliquent à la même image du ratio minimal dans le temps.
6. **Post-traitement.** Suppression des objets de moins de 0,1 ha, puis fermeture morphologique.
7. **Masque neige.** Chaque mois, les images Sentinel-1 des zones enneigées selon MODIS sont écartées. La détection reprend ensuite, avec un mois de retard au plus.
8. **Masque feu.** Les objets brûlés à 75 % ou plus de leur surface selon EFFIS sont retirés.

```math
RCR = \frac{M_a}{M_b}, \qquad t_s = 1{,}15 \times (-4{,}5\ \mathrm{dB}) \approx -5{,}2\ \mathrm{dB}, \qquad t_p = 1{,}15 \times (-3\ \mathrm{dB}) \approx -3{,}45\ \mathrm{dB}
```

Le facteur 1,15 est celui retenu par les auteurs pour la carte finale : rappel 80,9 %, précision 99,4 %. Avec un facteur de 1, le F1 est maximal (94,7 %) mais les fausses détections augmentent. Ce facteur doit rester un paramètre exposé.

Bouvet et al. (2018) précise le cœur de l'algorithme, mais sur un site tropical et avec des choix que SUFOSAT a modifiés. Les écarts ci-dessous sont à rendre paramétrables.

| Point | Bouvet et al. (2018) | SUFOSAT (Mermoz et al., 2024) |
| --- | --- | --- |
| Polarisation | VV | VH |
| Calibration | Gamma0, orthorectification avec SRTM 30 m | S1Tiling, non précisé |
| Filtre multitemporel | Chaque image filtrée avec les seules images antérieures | Noyau calculé sur 2018, appliqué ensuite |
| Xa et Xb | Xa = 3, Xb = toutes les images antérieures | Xa = 3, Xb non précisé |
| Nettoyage | Ombres de plus de 4 pixels, zones de plus de 10 pixels | Objets de plus de 0,1 ha, fermeture morphologique |
| Contour des coupes | Enveloppe par alpha shapes, facteur 0,6 | Non précisé |

Bouvet et al. suggèrent aussi, pour les forêts à forte saisonnalité, de retirer la tendance saisonnière moyenne des forêts intactes avant de calculer le ratio. C'est une piste directe pour les feuillus, à tester après la v1.

## Données d'entrée

Toutes les sources sont ouvertes ; seule la référence de validation des auteurs ne l'est pas. Les modalités d'accès sont indiquées de mémoire et sont à confirmer au démarrage.

| Donnée | Source | Résolution | Usage | Accès pressenti |
| --- | --- | --- | --- | --- |
| Sentinel-1 GRD IW, VH | Copernicus | 10 m | Détection | Copernicus Data Space (STAC, S3), ou produits déjà corrigés du terrain sur un catalogue cloud |
| Tree Cover Density 2018 | Copernicus Land Monitoring Service | 10 m | Masque forêt | Téléchargement CLMS |
| Dominant Leaf Type 2018 | Copernicus Land Monitoring Service | 10 m | Statistiques feuillus / résineux (optionnel) | Téléchargement CLMS |
| Couverture neigeuse MOD10A1 | MODIS / Terra | 500 m, quotidien | Masque neige | NASA Earthdata |
| Surfaces brûlées | EFFIS | Polygones annuels | Masque feu | Portail EFFIS |
| Carte SUFOSAT v3.0.1 | THEIA / CESBIO | 10 m | Référence de comparaison | DOI 10.71961/M18T-KB92 |

Les 967 polygones de validation de l'article ont été tracés par les auteurs sur imagerie très haute résolution et ne sont pas diffusés. Il faudra les demander à GlobEO ou constituer une référence locale sur l'AOI.

## Architecture technique

R convient pour toute la chaîne sauf le prétraitement radar, qui est le seul vrai point dur. La recommandation est un package R qui délègue cette étape.

La chaîne d'origine est en Python (S1Tiling, Xarray, Dask). R n'a pas d'équivalent pour calibrer et orthorectifier des images GRD. Trois options :

| Option | Principe | Avantage | Limite |
| --- | --- | --- | --- |
| A. S1Tiling en conteneur, appelé depuis R (recommandée) | R lance Docker, récupère les tuiles orthorectifiées | Prétraitement identique à l'article | Docker requis, téléchargement des GRD bruts |
| B. Produits Sentinel-1 déjà corrigés, lus via un catalogue STAC | `rstac` + `gdalcubes`, lecture limitée à l'AOI | Tout en R, peu de stockage | Calibration différente de l'article, seuils à recaler |
| C. Google Earth Engine via `rgee` | Calcul côté serveur | Rapide à prototyper | Dépendance à un service tiers, filtrage multitemporel à réécrire |

Structure proposée du package, orchestrée avec `targets` pour le cache et l'incrémental :

- `s1_search()` et `s1_fetch()` : inventaire et récupération des images sur l'AOI.
- `s1_filter_multitemp()` : filtre de Quegan et Yu, noyau figé sur une année de référence.
- `mask_forest()`, `mask_snow()`, `mask_fire()` : préparation des masques sur la grille Sentinel-1.
- `rcr_compute()` : ratio glissant et date du minimum, par orbite relative.
- `rcr_segment()` : graines sous ts, croissance de région jusqu'à tp.
- `postprocess()` : surface minimale, fermeture morphologique, vectorisation.
- `compare_reference()` : accord avec la carte publiée et métriques sur polygones.

Packages pressentis : `terra`, `sf`, `stars`, `gdalcubes`, `rstac`, `targets`. La croissance de région et le filtre multitemporel sont les deux noyaux à écrire avec soin, éventuellement en C++ via `Rcpp` si `terra` est trop lent.

Ordre de grandeur du volume : une tuile MGRS porte environ 1 160 images Sentinel-1A sur 2018–2023 d'après l'article (100 947 images pour 87 tuiles). Un département tient sur un poste de travail ; au-delà, prévoir un serveur.

## Sorties attendues

Les sorties reprennent le format des fichiers publiés pour rester directement comparables.

| Sortie | Format | Contenu |
| --- | --- | --- |
| Carte des dates | GeoTIFF 10 m, entier | Date estimée de la coupe codée YYDDD (année sur deux chiffres, jour de l'année), comme le fichier publié |
| Carte de confiance | GeoTIFF 10 m | Valeur minimale du ratio en dB par pixel détecté |
| Polygones des coupes | GeoPackage | Un objet par coupe : date, surface en ha, ratio moyen, type de forêt |
| Rapport | HTML (Quarto) | Surfaces par mois et par année, carte, comparaison avec la référence |
| Journal d'exécution | Texte | Images utilisées, images écartées pour neige, paramètres |

Le fichier publié donne une probabilité en pourcentage, mais l'article n'explique pas son calcul. La v1 livre donc le ratio brut plutôt qu'une probabilité reconstruite.

## Validation

Le recalcul est jugé fidèle s'il retrouve la carte publiée sur la période commune, puis s'il tient face à une référence indépendante.

1. **Accord avec la v3.0.1** sur l'AOI, 2018 à septembre 2025 : part de la surface publiée retrouvée, part de la surface recalculée absente de la référence, écart médian sur la date. Cibles à fixer avant le premier essai ; proposition de départ : 85 % de surface commune et un écart de date médian inférieur à un mois.
2. **Validation par objets**, selon le protocole de l'article : un polygone de coupe est retrouvé si plus de 75 % de sa surface est détectée ; un polygone intact est correct si plus de 75 % de sa surface reste non détectée. Métriques : rappel, précision, F1, exactitude globale.
3. **Sensibilité au facteur de seuil**, de 0,8 à 1,2 par pas de 0,05, pour reproduire la figure 3 de l'article sur l'AOI.
4. **Contrôle visuel** d'un échantillon de détections postérieures à septembre 2025 sur orthophotos ou images Sentinel-2.

Un accord parfait avec la v3 n'est pas attendu, puisque ses évolutions ne sont pas documentées. La méthode décrite dans l'article est la cible ; la v3 est le point de comparaison disponible.

## Risques et points durs

Le risque principal pour une mise à jour 2026 est le changement de satellite, pas le code.

| Risque | Conséquence | Parade |
| --- | --- | --- |
| Fin de mission de Sentinel-1A, annoncée pour mi-2026 (à confirmer) | La série de l'article est mono-satellite ; passer à Sentinel-1C ou 1D change les orbites et peut créer de faux changements | Traiter chaque orbite relative séparément, vérifier la continuité radiométrique sur forêt stable, recaler le noyau de filtrage |
| Évolutions v2 et v3 non publiées | Accord incomplet avec la carte de référence | Contacter GlobEO et le CESBIO ; garder les seuils paramétrables |
| Écarts entre Bouvet et al. (2018) et SUFOSAT : polarisation, filtrage, contour | Choix d'implémentation à trancher sans certitude sur ce que fait la chaîne nationale | Rendre ces choix paramétrables dès `rcr_compute()` |
| Prétraitement différent de S1Tiling (option B ou C) | Seuils en dB décalés | Étude de sensibilité sur l'AOI |
| Saisonnalité des feuillus | Plus d'omissions qu'en résineux (F1 de 93,1 % contre 96,5 % dans l'article) | Rapporter les métriques par type de forêt |
| Neige et relief | Fausses alertes en montagne | Masque neige ; signaler les AOI de montagne comme moins fiables |
| Petites AOI | Peu de polygones de référence, métriques instables | Compléter par un contrôle visuel |
| Licences | L'article est sous CC BY-NC-ND et les données SUFOSAT sont affichées en non commercial | Réécrire le code à partir de la description ; clarifier l'usage prévu des résultats |

La méthode détecte les coupes qui enlèvent tout ou une grande partie du peuplement. Les éclaircies et les coupes de moins de 0,1 ha restent hors de portée, quel que soit le soin apporté au recalcul.

## Jalons proposés

Cinq étapes, chacune livrant quelque chose de vérifiable. Les durées sont des estimations pour une personne à l'aise en R et en télédétection.

| Étape | Livrable | Durée estimée |
| --- | --- | --- |
| 0. Cadrage | Choix de l'option de prétraitement, AOI pilote d'une tuile, prise de contact avec GlobEO | 1 semaine |
| 1. Prototype | Série Sentinel-1 filtrée sur l'AOI pilote, ratio et seuillage, première carte 2020–2023 | 3 à 4 semaines |
| 2. Fidélité | Masques neige et feu, post-traitement, comparaison chiffrée avec la v3.0.1, réglage des seuils | 2 à 3 semaines |
| 3. Mise à jour | Extension à 2026 avec gestion du changement de satellite, mode incrémental | 2 à 3 semaines |
| 4. Packaging | Package documenté, tests, rapport automatique, AOI quelconque | 2 semaines |

## Questions ouvertes

- [ ] Quelle AOI pilote, et quelle taille maximale d'AOI vise-t-on à terme ?
- [ ] L'objectif est-il de reproduire fidèlement la carte publiée, ou surtout d'obtenir des détections 2026 exploitables ?
- [ ] R strict, ou R avec une étape en conteneur Python pour le prétraitement ?
- [ ] Où tourne le calcul : poste de travail, serveur, cloud ?
- [ ] Usage prévu des résultats : interne, publication, commercial ? La réponse conditionne la question des licences.
- [ ] Dispose-t-on de données terrain ou d'orthophotos récentes sur l'AOI pour la validation ?
- [ ] GlobEO ou le CESBIO peuvent-ils partager les paramètres v3 et les polygones de référence ?

## Sources

- Mermoz S. et al. (2024), Submonthly Assessment of Temperate Forest Clear-Cuts in Mainland France, IEEE JSTARS vol. 17, p. 13743-13764 : [doi.org/10.1109/JSTARS.2024.3429012](https://doi.org/10.1109/JSTARS.2024.3429012). Lu pour les sections II et III.
- Jeu de données et historique des versions : [doi.theia.data-terra.org/Sufosat](https://doi.theia.data-terra.org/Sufosat/).
- Bouvet A. et al. (2018), Use of the SAR shadowing effect for deforestation detection with Sentinel-1 time series, Remote Sensing 10(8), 1250 : [doi.org/10.3390/rs10081250](https://doi.org/10.3390/rs10081250). Lu pour les sections 2.2, 2.3 et 4.
