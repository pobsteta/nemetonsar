# Performance de `nemetonsar_detecter()` — mission 016

Développeur, 2026-11-22. Script : [`performance.R`](performance.R), à lancer
depuis la racine du dépôt (`Rscript docs/analyses/performance.R lignes colonnes
dates orbites [empreinte.rds|-] [lignes_par_bloc]`), graine fixée.

**Nature des chiffres.** Données de **simulation** (forêt à 0,05 en linéaire,
speckle gamma de 4,4 vues, 80 coupes rectangulaires de -6 dB, 300 dates à 6 jours
par orbite, 3 orbites, piles GeoTIFF FLT4S dans `tempdir()`), mesurées sur la
machine virtuelle de la session (4 cœurs, R 4.3.3, un seul cœur utilisé). Les
temps varient d'environ ±15 % d'une exécution à l'autre. Les durées « par tuile »
sont des **extrapolations linéaires** (temps mesuré × nombre de pixels de la tuile
/ nombre de pixels mesurés), pas des mesures sur une tuile.

## Ce qui a été mesuré

Deux géométries :

- **largeur de tuile** : 18 lignes × 10 980 colonnes × 300 dates × 3 orbites,
  blocs par défaut de 9 lignes (`floor(2.5e8 / (8 × 10 980 × 300))`), soit
  exactement la forme des blocs d'une tuile MGRS ; c'est la base de
  l'extrapolation ;
- **fenêtre étroite** : 200 lignes × 500 colonnes × 300 dates × 3 orbites (un
  seul bloc de 200 lignes : pas représentatif des blocs d'une tuile).

Temps par étape : `Rprof`, temps « total » de la fonction (elle et ce qu'elle
appelle). Mémoire : `gc()`, « max used » du tas R (déchets non encore collectés
compris), au-dessus de l'état après création des piles.

## Avant / après

### Largeur de tuile (18 × 10 980 × 300 × 3, blocs de 9 lignes)

| Étape | Avant (s) | Après (s) | Gain |
|---|---:|---:|---:|
| Passe 1 : lecture des piles (`terra::readValues`) | 10,2 | 7,2 | (bruit) |
| Passe 1 : filtre (`s1_filter_multitemp`) | 97,6 | 19,6 | × 5,0 |
| Passe 1 : ratio (`rcr_compute`) | 51,2 | 12,4 | × 4,1 |
| Passe 1 : combinaison des orbites | 0,1 | 0,1 | — |
| Passes 2 et 3 (étiquetage, fermeture, union-find, table, GPKG) | < 0,2 | < 0,2 | — |
| **Total** | **162,5** | **40,1** | **× 4,1** |
| Pic du tas R | 1 655 Mo | 1 695 Mo | inchangé |
| **Extrapolation à une tuile MGRS 10 980 × 10 980 × 300 dates × 3 orbites** | **≈ 27,5 h** | **≈ 6,8 h** | |

Une mesure intermédiaire (avant la dernière modification du ratio) donnait
45,0 s, soit 7,6 h par tuile ; une mesure sur 36 lignes à blocs de 9 lignes
donne 7,2 h. On retiendra **de 7 à 8 h par tuile** en base R, contre ≈ 27 h
avant (l'estimation de ≈ 10 h notée au journal pour la mission 009 était donc
optimiste).

### Fenêtre étroite (200 × 500 × 300 × 3, un bloc)

| Étape | Avant (s) | Après (s) |
|---|---:|---:|
| Lecture | 3,7 | 3,3 |
| Filtre | 22,4 | 8,8 |
| Ratio | 22,4 | 6,2 |
| **Total** | **49,8** | **19,0** |
| Pic du tas R | 1 524 Mo | 1 360 Mo |

### Noyaux seuls, un bloc d'une orbite (10 980 × 11 lignes bordées × 300 dates)

| | Avant | Après |
|---|---:|---:|
| `s1_filter_multitemp()` | 14,5 s | 3,3 à 4,0 s |
| `rcr_compute()` | 8,3 s | 2,6 s |
| Pic de `rcr_compute()` au-dessus de l'entrée (tableau de 276 Mo) | 5,1 × | 2,6 × |
| Pic de `s1_filter_multitemp()` au-dessus de l'entrée | 2,9 × | 2,7 × |

### Taille de bloc (36 × 10 980 × 300 × 3)

| `lignes_par_bloc` | Total | Extrapolation tuile | Pic du tas R |
|---:|---:|---:|---:|
| 4 | 98,5 s | 8,3 h | 1 469 Mo |
| 9 (défaut) | 85,3 s | 7,2 h | 2 223 Mo |
| 18 | 92,0 s | 7,8 h | 2 613 Mo |

Le défaut (9 lignes pour une tuile à 300 dates) reste le meilleur des trois ;
pas de raison de le changer.

### Table des objets (médiane des dates)

`table_objets_blocs()` sur 20 000 objets synthétiques (100 000 couples objet ×
date) : **7,1 s avant** (une recherche par objet, quadratique), **0,08 s après**
(un tri, puis comptes cumulés : linéaire après le tri).

## Où va le temps (après)

1. **Filtre (≈ 50 %)**. Le coût plancher est la somme cumulée le long de l'axe
   court (les 13 lignes d'une bande bordée et étendue) : pour rester identique
   au bit près, chaque somme cumulée doit être accumulée comme `cumsum()`, en
   *long double* (code C de R). En base R, la seule façon vectorisée de le
   faire est `.rowSums()` des j premières colonnes (même accumulateur), qui
   relit j colonnes pour la colonne j : ≈ 4 ms par image et par orbite, soit
   près de la moitié du filtre. Une addition en double (`x[, j - 1] + x[, j]`)
   serait plus rapide mais change le dernier bit de 42 % des sommes dans un
   essai à valeurs très dispersées : écartée (pas d'identité au bit près).
2. **Ratio (≈ 30 %)**. Somme cumulée sur les dates (300 opérations sur des
   vecteurs de 120 000 pixels) et un balayage des dates pour le rapport
   Ma / Mb. Le logarithme n'est plus pris qu'une fois par pixel (voir plus bas).
3. **Lecture (≈ 18 %)**. `terra::readValues()` de 11 lignes dans une pile de 300
   couches.
4. Passes 2 et 3, table, polygones : négligeables à cette échelle.

**Mémoire.** Le pic du tas R de la détection (≈ 1,6 à 1,7 Go à blocs de 9
lignes) n'a pas baissé : `rcr_compute()` ne garde plus que ≈ 2,6 fois son entrée
(contre 5,1), mais le pic est désormais tenu par la passe 1 dans son ensemble
(bande lue, copie filtrée, copie du ratio et déchets non encore collectés par
R). Il reste proportionnel à `lignes_par_bloc`.

## Ce qui a changé (aucune signature, aucun résultat)

- `R/filtre.R` : la moyenne locale d'une image de référence est calculée une
  fois (noyau et image filtrée) ; `apply(cumsum)` remplacé par une boucle de
  `cumsum()` sur l'axe long et par `.rowSums()` triangulaire sur l'axe court
  (≤ 20 colonnes ; au-delà, transposition et `cumsum()`) ; sans valeur
  manquante dans la fenêtre, le compte vaut `cote²` sans table ; sinon il est
  compté en entiers ; la recherche des valeurs ≤ 0 passe par `min()` (pas de
  masque construit si aucune).
- `R/rcr.R` : sommes cumulées écrites sur place dans la copie de la série
  (compactées par pixel seulement s'il y a des `NA`, par indices linéaires au
  lieu de `cbind`) ; boucle sur le rang de l'image valide plutôt que sur la
  date ; le ratio en dB étant `lineaire_vers_db()` du rapport Ma / Mb, on suit
  en linéaire le plus petit rapport, sa première position et le second plus
  petit : si l'écart dépasse un facteur 1 + 1e-6 (≈ 4e-6 dB, très au-delà de
  l'erreur d'arrondi du logarithme), le minimum et sa date sont ceux du calcul
  complet ; sinon (plateaux, égalités), le pixel repasse par la règle
  d'origine date par date ; en cas dégénéré (rapport nul ou `NaN`), tout est
  recalculé comme avant, avertissements compris. `valide_serie()` teste
  l'infini par `min()`/`max()` sans copie.
- `R/detecter.R` : la bande lue est mise en forme par `dim<-` (une copie de
  moins) ; médiane de `table_objets_blocs()` linéaire (un tri).

## Preuve d'identité des résultats

- **Empreintes** des sorties de `nemetonsar_detecter()` (valeurs des trois
  rasters et table) : identiques au bit près (`identical()`) avant et après,
  sur les deux géométries ci-dessus.
- **Tests** : référence figée du filtre et du ratio d'avant la mission (code
  d'avant recopié dans `test-filtre.R` et `test-rcr.R`, comparé par
  `expect_identical`, avertissements compris, NA, plateaux, cas dégénérés) ;
  empreintes MD5 de sorties calculées avec le code d'avant (filtre, ratio,
  détection, x86_64) ; tests existants (références naïves, identité blocs /
  tableau entier) inchangés et verts ; test diagonal entre bandes en
  connexité 8 (ajouté, il échoue si l'on retire les arêtes diagonales entre
  bandes ; aucun test existant ne le voyait).
- Hors suite : 480 cas aléatoires de `rcr_compute()` et 54 de
  `s1_filter_multitemp()` (formes, fenêtres, NA, réglages) comparés par
  `identical(serialize())` au code d'avant : tous identiques.

## Proposition : noyau compilé (à décider par ADR)

Un prototype C jetable (hors package, compilé par `R CMD SHLIB`, cas sans `NA`)
du filtre et du ratio, avec le même accumulateur *long double* que `cumsum()`,
rend **les mêmes valeurs au bit près** (vérifié sur un bloc 10 980 × 11 × 300)
et mesure, par bloc et par orbite :

| | Base R après 016 | C (prototype) |
|---|---:|---:|
| Filtre | 3,3 à 4,0 s | 0,5 s |
| Ratio (un logarithme par date) | 2,6 s | 1,1 s |

Avec la même astuce du minimum en linéaire, le ratio en C devrait descendre
vers 0,2 s (estimation, non mesurée).
Extrapolé à une tuile : passe 1 de ≈ 6 h à ≈ 1 h de calcul, plus la lecture
(≈ 1,2 h mesurée ici), soit **≈ 2 à 2,5 h par tuile au lieu de ≈ 7 h**. Le
coût : Rcpp (ou C via `.Call`) en dépendance de compilation, une chaîne de
compilation chez les utilisateurs Windows (Rtools), et l'identité au bit près
qui ne vaut que là où `long double` est le même que celui de R (vrai par
construction sur une même plateforme). À trancher par ADR.

## Limites

- Lecture mesurée sur des piles GeoTIFF multi-couches locales ; les données
  réelles (un fichier par date, éventuellement compressé) peuvent lire plus
  lentement.
- Une seule exécution par configuration, sur une machine virtuelle partagée.
- Peu d'objets dans les simulations : le temps des passes 2 et 3 sur une tuile
  réelle (beaucoup de composantes) n'est pas mesuré ici.
