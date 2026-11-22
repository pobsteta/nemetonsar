# ADR 0004 — Noyau compilé pour le filtre et le ratio

- **Date :** 2026-11-22
- **Statut :** proposée
- **Proposée par :** Claude (orchestrateur), d'après la mission 016 (`docs/analyses/performance.md`)
- **Tranchée par :** Pascal

## La décision en une phrase

Écrire en C, appelé par `.Call` sans Rcpp, les deux boucles chaudes de la passe 1
(moyenne locale du filtre de Quegan et Yu, sommes cumulées et minimum du ratio),
avec le même accumulateur *long double* que `cumsum()`, en gardant les versions
en base R comme références de test, pour ramener une tuile d'environ 7 h à
environ 2 à 2,5 h sans changer un résultat.

## Contexte

La mission 016 a mesuré, sur données simulées, environ 27 h par tuile MGRS
(300 dates, 3 orbites) avant optimisation et environ 7 h après, à résultats
identiques au bit près (extrapolations à partir de blocs de la largeur d'une
tuile). La passe 1 (filtre 60 %, ratio 32 % avant 016) domine. En base R, le
plancher vient des cumuls *long double* de l'axe court du filtre.

Un prototype C jetable (hors package, cas sans `NA`) rend les mêmes valeurs au
bit près sur un bloc 10 980 × 11 × 300 : filtre 0,5 s contre 3,3 à 4 s, ratio
1,1 s contre 2,6 s par bloc et par orbite ; environ 2 à 2,5 h par tuile
estimées, dont environ 1,2 h de lecture (non compressible ici).

Options envisagées :

| Option | Principe |
|---|---|
| 0 | Rester en base R (≈ 7 h par tuile) |
| 1 | C via `.Call`, sans dépendance R nouvelle (retenue) |
| 2 | Rcpp (C++), dépendance `Rcpp` en Imports et LinkingTo |
| 3 | Paralléliser la base R par tuile ou par orbite (`parallel`, base R) |
| 4 | Option 1 et option 3 ensemble |

## Le crible FRANCE

| Lettre | Question | Réponse (une ligne) | Ce que ça coûte | Prêts à payer ? |
|---|---|---|---|---|
| **F**rugale | La plus simple qui tienne ? | Deux fonctions C courtes, sans paquet de plus ; la base R reste la référence | Une chaîne de compilation (gcc ; Rtools sous Windows) | À trancher par Pascal |
| **R**esponsable | Qui fait quoi ? | Le C calcule, R valide et orchestre ; chaque fonction C est testée contre sa version R au bit près | Deux implémentations à maintenir | À trancher par Pascal |
| **A**nticiper | Si l'imprévu arrive ? | La version R reste appelable (option ou repli si la compilation manque) ; identité au bit près vraie sur une même plateforme, pas entre plateformes (*long double*) | Résultats qui peuvent différer au dernier bit d'une machine à l'autre | À trancher par Pascal |
| **N**ovateur | Toutes les idées ? | Cinq options écrites, dont le parallélisme sans compilation | — | — |
| **C**oût | Coût complet ? | inconnu (temps de développement et de relecture du C) ; gain mesuré sur prototype : ≈ 5 h par tuile | Relecture d'un code moins lisible pour un successeur R | À trancher par Pascal |
| **É**cologique | Que réutilise-t-on ? | Le mécanisme `.Call` de R, sans dépendance ; moins de calcul, moins d'énergie par tuile | — | — |

Questions « Choisir » (fiche n° 11) : format ouvert, oui ; code corrigeable par
d'autres, oui (C standard, GPL-3) ; fonctionne d'un poste à l'autre, oui sous
réserve d'un compilateur (CRAN fournit des binaires) ; communauté, celle de R.

## Valeurs sacrifiées

- **Simplicité pour un successeur R** : une partie du calcul passe en C.
- **Installation sans compilateur** depuis les sources (Windows sans Rtools) ;
  à compenser par un repli automatique sur la base R.
- **Identité au bit près entre plateformes** (déjà vraie en base R : `cumsum()`
  dépend du *long double* de la machine).

## Sources

- `docs/analyses/performance.md` (mission 016) et son script `performance.R`.
- *Writing R Extensions*, « System and foreign language interfaces » (`.Call`) :
  https://cran.r-project.org/doc/manuals/r-release/R-exts.html
- ADR 0003 (dépendances : `terra` seul en Imports).

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?

## Critique du `contradicteur` (2026-11-22) et amendement proposé

1. **La lecture réelle n'est pas mesurée.** Les 1,2 h viennent de piles GeoTIFF
   locales ; les vraies données sont environ 300 COG distants par orbite, lus par
   bandes de 9 lignes. Une fois le calcul accéléré, la lecture dominera.
   → Mesurer d'abord la lecture d'une orbite réelle (distante, puis copiée en
   local) ; aligner la hauteur des blocs sur les tuiles internes des COG ou
   rapatrier les images. « 2 à 2,5 h » devient une **valeur provisoire**.
2. **Pas de repli à l'installation.** Un package avec `src/` se compile à
   l'installation depuis les sources : sous Windows, `remotes::install_github()`
   exige Rtools. Le repli sur la base R ne joue qu'à l'exécution.
   → L'écrire ; binaires par r-universe à vérifier.
3. **Identité au bit près fausse sur macOS arm64** (`long double` = `double`,
   *R Installation and Administration*). → Au bit près sur une même plateforme,
   tolérance stricte entre plateformes ; les empreintes MD5 restent x86_64.
4. **Sécurité mémoire et contrôle CRAN** : `PROTECT`, enregistrement des
   routines, `R_CheckUserInterrupt`, sanitizers et valgrind (*Writing R
   Extensions* 4.3, 5.4). → Critères : `R CMD check --as-cran` propre, CI Linux,
   macOS arm64 et Windows, une tâche avec sanitizers. Le compromis `.Call` contre
   Rcpp (protection mémoire contre dépendance) est à trancher avec le reste.
5. **Le parallélisme est sous-évalué.** Trois orbites en parallèle : environ ×3
   sur le calcul, environ 5 Go de mémoire, sans compilateur (PSOCK sous
   Windows). Environ 2,5 à 3 h par tuile possibles sans C (non mesuré).

**Recommandation de l'orchestrateur, après critique :** ne pas trancher le C
maintenant. Une mission de mesure d'abord : lecture réelle d'une orbite (COG
distants contre copie locale) et option 3 (orbites en parallèle). Le C ne se
décide qu'ensuite, si la lecture n'est pas le goulot et si le parallélisme ne
suffit pas.
