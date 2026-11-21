# nemetonsar

[![CI](https://github.com/pobsteta/nemetonsar/actions/workflows/ci.yml/badge.svg)](https://github.com/pobsteta/nemetonsar/actions/workflows/ci.yml)
[![Release](https://github.com/pobsteta/nemetonsar/actions/workflows/release.yml/badge.svg)](https://github.com/pobsteta/nemetonsar/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/pobsteta/nemetonsar?label=version)](https://github.com/pobsteta/nemetonsar/releases)
![Couverture](.github/badges/couverture.svg)
![R](https://img.shields.io/badge/R-%E2%89%A5%204.1-276DC3?logo=r&logoColor=white)
![Cycle de vie](https://img.shields.io/badge/cycle%20de%20vie-exp%C3%A9rimental-orange)
[![Licence](https://img.shields.io/badge/licence-GPL--3.0-blue)](LICENSE.md)

Package R de la famille [nemeton](https://github.com/pobsteta/nemeton) pour recalculer, sur une zone d'intérêt donnée, les cartes de coupes rases selon la méthode SUFOSAT (radar Sentinel-1).

Le projet est au stade du cadrage : voir le [brief projet](docs/brief.md). Le package ne contient pour l'instant que le codage des dates de coupe au format `YYDDD` des cartes publiées.

## Installation

```r
# install.packages("remotes")
remotes::install_github("pobsteta/nemetonsar")
```

Chaque [release](https://github.com/pobsteta/nemetonsar/releases) fournit aussi l'archive `nemetonsar_AAAA.MM.N.tar.gz`, installable avec `install.packages("<archive>", repos = NULL)`.

## Exemple

```r
library(nemetonsar)

date_vers_yyddd(as.Date("2024-03-15"))
#> [1] 24075
yyddd_vers_date(24075L)
#> [1] "2024-03-15"
```

## Développement

- **Jamais de push direct sur `main`** : tout passe par une pull request.
- **Pas de code sans tests** : `devtools::test()` en local ; la CI lance `R CMD check`, tests compris, sur chaque pull request et chaque push de `main`.
- La CI mesure la couverture avec `covr` et met à jour le badge sur `main`.

## Versions et releases

Les versions sont **calendaires** : `vAAAA.MM.N`, où `N` est le compteur des releases du mois (UTC) et repart à 1 chaque mois.

Il n'y a rien à faire à la main. Après la fusion d'une pull request sur `main` :

1. La CI doit finir verte.
2. Le workflow `Release` vérifie qu'une release est nécessaire : un fichier du package doit avoir changé depuis le dernier tag. Les changements limités à `docs/`, aux fichiers `*.md`, au badge et aux tests ne publient rien.
3. Il calcule la version, pose le tag annoté, construit l'archive du package à cette version et crée la release GitHub avec ses notes.

Le champ `Version` de `DESCRIPTION` reste une version de développement dans le dépôt ; seule l'archive publiée porte la version du tag. Les règles sont dans `.github/scripts/`, avec leurs tests.
