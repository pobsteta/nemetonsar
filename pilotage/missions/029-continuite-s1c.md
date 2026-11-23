# Mission 029 — Détections 2026 et continuité Sentinel-1A → 1C/1D

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (après le cycle 11), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Lancer le pilote Landes sur 2025-2026 jusqu'au dernier mois disponible et vérifier que la chaîne passe sans rupture de Sentinel-1A (arrêté le 29 juin 2026) à Sentinel-1C et 1D, pour tenir l'arbitrage n° 3 du brief (les détections postérieures à septembre 2025 d'abord) et la vérification de continuité promise au jalon 1.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- `capteurs_sufosat()` (`R/parametres.R:139`) déclare S1A jusqu'au 2026-06-29, puis S1C et S1D à partir du 2026-06-30. Ce passage n'a jamais tourné : le pilote de 017 s'arrêtait au 2025-09-30.
- Brief, arbitrages du 22 novembre 2026 : n° 2 (S1A puis S1C et S1D), n° 3 (détections postérieures à septembre 2025 d'abord ; la continuité 1A → 1C/1D se vérifie dès le jalon 1).
- AOI pilote : celle de 017 (`docs/analyses/pilote-landes.R`), dans la tuile 30TXP.
- Le parallèle (023) et le renouvellement du jeton (025) sont faits : l'exécution peut être longue.

## Questions à trancher par les chiffres

1. Le Planetary Computer sert-il des RTC Sentinel-1C et 1D sur la tuile, depuis quand, et sur quelles orbites relatives (les mêmes que S1A ou non) ?
2. La chaîne va-t-elle au bout sur 2025-2026 avec le changement de capteur, sans erreur ni série coupée ?
3. Continuité du signal : sur des forêts sans coupe, le niveau VH et la dispersion du ratio sont-ils les mêmes avant et après le 2026-06-30 (pas de saut d'étalonnage) ? Faux positifs au passage de capteur ?
4. Combien de coupes sont détectées et datées après septembre 2025, et après le 2026-06-30 ? Le délai de détection (Xa = 3 images) est-il tenu à la reprise ?

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : `nemetonsar_run()`, `s1_rechercher()`, script du pilote de 017 | |
| A-t-il les moyens ? | oui en session locale : réseau vers le Planetary Computer, R, terra, rstac ; Quarto et XeLaTeX installés pour le PDF | hors du poste de Pascal : s'arrêter ; si le Planetary Computer ne sert pas S1C/S1D, s'arrêter et le dire |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/continuite-s1c.R` (script), `docs/analyses/continuite-s1c.qmd` (rapport, rendu en **Markdown et en PDF** : `continuite-s1c.md` et `continuite-s1c.pdf`, demandés par Pascal le 2026-11-23). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m029/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package (un défaut trouvé est décrit et proposé en mission `dev`) ; mettre une image Sentinel-1 au dépôt ; utiliser un objet interne de rstac ; changer un réglage par défaut. Pas de donnée de la v3.0.1 (elle s'arrête en septembre 2025) : le rapport n'hérite pas de la clause NC ; s'il en cite une, il passe sous CC BY-NC 4.0 et le dit. Le rapport dit exactement ce qu'il contient.

## Valeur provisoire (chiffre, réglage)

Période 2025-01-01 → dernier mois disponible ; AOI de 017 ; réglages par défaut ; provisoires.

## Dépend de / rouge attendu jusqu'à

Dépend de : 023 et 025 (terminées). Indépendante de 027 et 028 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument) ; contrôle : sur 2025-01 → 2025-09, les détections sont celles de l'exécution de 017 sur la même période ; le PDF se construit sans erreur depuis le `.qmd`.

## Terrain

Trois coupes datées après le 2026-06-30, à contrôler par Pascal sur Sentinel-2 ou orthophoto récente.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation (Pascal pour un changement de réglage).
