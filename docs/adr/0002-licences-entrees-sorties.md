# ADR 0002 — Une licence par entrée et par sortie

- **Date :** 2026-11-22
- **Statut :** acceptée par Pascal le 2026-11-22
- **Proposée par :** Claude (orchestrateur), d'après l'arbitrage n° 4 du brief
- **Tranchée par :** Pascal

## La décision en une phrase

Le package reste sous GPL-3 ; chaque donnée d'entrée et chaque sortie porte sa licence
et ses attributions (journal d'exécution, métadonnées des GeoTIFF), et seules les
sorties de `compare_reference()`, dans un rapport de comparaison séparé du rapport
principal, héritent de la clause non commerciale de la v3.0.1.

## Contexte

L'usage v1 est interne et non commercial (arbitrage n° 4). Les données SUFOSAT sont sous
CC BY-NC 4.0, les produits Sentinel-1 sous licence Copernicus, ouverte ; les RTC du
Planetary Computer sous CC BY 4.0. Un rapport qui intègre la v3.0.1 en est un dérivé.
Licences à établir par l'`acquereur`, une ligne par source avec son lien : Sentinel-1
(mention « Copernicus Sentinel data »), RTC Planetary Computer (CC BY 4.0), TCD 2018
(CLMS), MOD10A1 (NASA), EFFIS (conditions d'usage à vérifier), SUFOSAT v3.0.1
(CC BY-NC 4.0), article Mermoz et al. (à vérifier).
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

La simplicité : « tout en non commercial » et un seul rapport auraient été plus simples ; on les sacrifie pour garder
réutilisables les cartes recalculées.

## Sources

- SUFOSAT, licence et historique : https://doi.theia.data-terra.org/Sufosat/
- Sentinel-1 RTC, Planetary Computer : https://planetarycomputer.microsoft.com/api/stac/v1/collections/sentinel-1-rtc
- Licence de l'article Mermoz et al. (2024) : à vérifier (`acquereur`).

## Question de contrôle

Cette décision tient-elle nos six valeurs, et que sommes-nous prêts à payer pour cela ?
