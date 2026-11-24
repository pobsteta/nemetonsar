# nemetonsar

[![CI](https://github.com/pobsteta/nemetonsar/actions/workflows/ci.yml/badge.svg)](https://github.com/pobsteta/nemetonsar/actions/workflows/ci.yml)
[![Release](https://github.com/pobsteta/nemetonsar/actions/workflows/release.yml/badge.svg)](https://github.com/pobsteta/nemetonsar/actions/workflows/release.yml)
[![Version](https://img.shields.io/github/v/release/pobsteta/nemetonsar?label=version)](https://github.com/pobsteta/nemetonsar/releases)
![Couverture](.github/badges/couverture.svg)
![R](https://img.shields.io/badge/R-%E2%89%A5%204.1-276DC3?logo=r&logoColor=white)
![terra](https://img.shields.io/badge/rasters-terra%20%C2%B7%20GDAL-4C8C2B)
![Sentinel-1](https://img.shields.io/badge/donn%C3%A9es-Sentinel--1%20RTC%20%C2%B7%20Planetary%20Computer-0078D4)
[![Méthode](https://img.shields.io/badge/m%C3%A9thode-SUFOSAT-2e7d32)](https://doi.org/10.1109/JSTARS.2024.3429012)
[![Méthode de l'Impératrice](https://img.shields.io/badge/pilotage-m%C3%A9thode%20de%20l%27Imp%C3%A9ratrice-8e44ad)](pilotage/kanban.md)
![Cycle de vie](https://img.shields.io/badge/cycle%20de%20vie-exp%C3%A9rimental-orange)
[![Licence](https://img.shields.io/badge/licence-GPL--3.0-blue)](LICENSE.md)

Package R de la famille [nemeton](https://github.com/pobsteta/nemeton) pour recalculer, sur une zone d'intérêt donnée, les cartes de coupes rases selon la méthode SUFOSAT (radar Sentinel-1).

La chaîne est complète, de l'AOI aux sorties en Lambert-93, avec une commande unique, `nemetonsar_run()`. Ses réglages restent provisoires jusqu'à la comparaison à la carte publiée v3.0.1 (mission 017). Voir le [brief projet](docs/brief.md) et le [kanban](pilotage/kanban.md).

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
2. Le workflow `Release` vérifie qu'une release est nécessaire : un fichier du package doit avoir changé depuis le dernier tag. Les changements limités à `pilotage/`, à `docs/`, aux fichiers `*.md`, au badge et aux tests ne publient rien.
3. Il calcule la version, pose le tag annoté, construit l'archive du package à cette version et crée la release GitHub avec ses notes.

Le champ `Version` de `DESCRIPTION` porte la dernière version publiée : après chaque release, le workflow l'y écrit par un commit `[skip ci]` sur `main`, qui ne déclenche pas de nouvelle release. Les règles sont dans `.github/scripts/`, avec leurs tests.

### Notation des commits et des pull requests

Comme dans marculus, le **titre de chaque pull request est un commit conventionnel**, en français, qui cite la mission quand il y en a une. La pull request est fusionnée **en squash** : son titre devient le message du commit sur `main`, suivi de son numéro.

| Préfixe | Pour | Exemple |
|---|---|---|
| `feat:` | une fonction nouvelle du package | `feat: compare_reference(), comparaison à la carte publiée (mission 017) (#12)` |
| `fix:` | une correction du package | `fix: lecture parallèle sans blocage sous GDAL 3.11 (mission 023) (#13)` |
| `perf:` | un gain de temps, à résultats identiques | `perf: orbites en parallèle (mission 021) (#10)` |
| `docs:` | la documentation, le README, une analyse | `docs: rapport de la tuile pilote des Landes (#14)` |
| `docs(pilotage):` | le pilotage : kanban, journal, fiches, cycles | `docs(pilotage): cycle 10 clos, mission 023 validée (#15)` |
| `ci:` | les workflows et les scripts de `.github/` | `ci: pilotage/ exclu de la décision de release (#16)` |
| `test:` | des tests seuls | `test: graine dans la bande voisine (mission 022) (#11)` |

Le préfixe ne fixe pas la version : elle reste calendaire. Il sert à lire l'historique et les notes de release.
