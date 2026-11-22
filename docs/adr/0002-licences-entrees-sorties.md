# ADR 0002 — Une licence par entrée et par sortie

- **Date :** 2026-11-22
- **Statut :** proposée
- **Proposée par :** Claude (orchestrateur), d'après l'arbitrage n° 4 du brief
- **Tranchée par :** Pascal

## La décision en une phrase

Le package reste sous GPL-3 ; chaque donnée d'entrée et chaque sortie porte sa licence
dans le journal d'exécution, et seules les sorties de `compare_reference()`, qui
contiennent la carte SUFOSAT v3.0.1, héritent de sa clause non commerciale.

## Contexte

L'usage v1 est interne et non commercial (arbitrage n° 4). Les données SUFOSAT sont sous
CC BY-NC 4.0, les produits Sentinel-1 sous licence Copernicus, ouverte ; les RTC du
Planetary Computer sous CC BY 4.0. Un rapport qui intègre la v3.0.1 en est un dérivé.
Options envisagées : tout marquer non commercial (simple, mais ferme inutilement les
cartes recalculées) ; séparer par sortie (retenue) ; ne rien noter (exclu).

## Le crible FRANCE

| Lettre | Question | Réponse (une ligne) | Ce que ça coûte | Prêts à payer ? |
|---|---|---|---|---|
| **F**rugale | La plus simple qui tienne ? | Une table de licences et une ligne par sortie au journal | Un peu de code | Oui |
| **R**esponsable | Qui fait quoi ? | Le package écrit la licence ; Pascal décide de l'usage | — | Oui |
| **A**nticiper | Si l'usage change ? | Les cartes recalculées restent réutilisables sans la clause NC | Une séparation à tenir dans le code | Oui |
| **N**ovateur | Toutes les idées ? | Trois options écrites | — | Oui |
| **C**oût | Coût complet ? | inconnu, faible | — | Oui |
| **É**cologique | Qui pourra réutiliser ? | Toute personne, pour les sorties sans la v3.0.1 | — | Oui |

## Valeurs sacrifiées

Aucune nommée : la simplicité de « tout en non commercial » est sacrifiée pour garder
réutilisables les cartes recalculées.

## Sources

- SUFOSAT, licence et historique : https://doi.theia.data-terra.org/Sufosat/
- Sentinel-1 RTC, Planetary Computer : https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-1-rtc
- Licence de l'article Mermoz et al. (2024) : à vérifier (`acquereur`).

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?
