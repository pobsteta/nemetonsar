# Mission 024 — D'où viennent les dates tardives par rapport à la v3.0.1

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (cycle 10), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Sur la tuile pilote des Landes, tester les deux hypothèses qui expliqueraient pourquoi près de la moitié des pixels communs avec la v3.0.1 sont datés plus de 180 jours plus tard (règle de date, début de série), en chiffrant ce que chacune explique, pour que Pascal décide quoi changer avant de geler les réglages au jalon 2.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de comparaison : `docs/analyses/pilote-landes-comparaison.md` (CC BY-NC 4.0). Rapport principal : `docs/analyses/pilote-landes.md`.
- La distribution des écarts a deux modes : 26 % des pixels communs à moins de 15 j, 46,5 % datés plus de 180 j plus tard, 3,9 % plus de 180 j plus tôt.
- Données, **sur le poste de Pascal seulement**, hors dépôt : `/home/pascal/dev/nemetonsar-donnees/` (extrait v3.0.1 `sufosat_v301_dates_aoi.tif`, sorties `pilote/sorties/`, script en série `pilote-landes-serie.R`). La mission tourne donc en session locale.

## Hypothèses à tester

1. **Règle de date.** La chaîne date au minimum du ratio (`R/rcr.R`, `xb_date`), la v3.0.1 garderait la première détection. Recalculer les dates sur l'AOI avec une règle « première date sous le seuil » (sans toucher au package : script d'analyse), et comparer de nouveau. Chiffrer la part des pixels tardifs qui redeviennent à moins de 15 j.
2. **Début de série.** Pas de ratio avant `annee_noyau + 1` (2019). Comparer sur 2019-2025 seulement (pixels publiés datés de 2018 écartés des deux côtés), et dire quelle part de la surface recalculée de 2019 absente de la référence correspond à des coupes publiées en 2018.
3. Si les deux n'expliquent pas l'essentiel : regarder sur orthophoto IGN quelques pixels tardifs (avant / après les deux dates), et dire ce qu'on voit, sans conclure au-delà.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : `compare_reference()`, sorties de `nemetonsar_run()`, `docs/analyses/precision-date.md` (mission 008) | |
| A-t-il les moyens ? | oui en session locale : données ci-dessus, R, terra, réseau vers le Planetary Computer si une relecture des images est nécessaire (en série : mission 023 non faite) | hors du poste de Pascal : pas de données, s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (touche la justesse des dates).

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/ecarts-date-v301.R` (script), `docs/analyses/ecarts-date-v301.md` (rapport, **CC BY-NC 4.0**, mention « usage non commercial » en tête, attributions [S1] [FOR] [MET] [SUF]). Fichiers de travail hors dépôt.
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package (`R/`, `tests/`) ; mettre une donnée ou un extrait de la v3.0.1 au dépôt (seulement des chiffres agrégés dans le rapport NC) ; recopier des valeurs de la v3.0.1 au journal ; changer un réglage par défaut (il propose, Pascal tranche).

## Valeur provisoire (chiffre, réglage)

Seuil de 15 j pour « date retrouvée » et de 180 j pour « tardive » : repris du rapport de comparaison, provisoires.

## Dépend de / rouge attendu jusqu'à

Dépend de : 017 (comparaison faite). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument, graine) ; chiffres recalculés par le relecteur ; la règle « première détection » vérifiée sur un ou deux pixels tracés (série du ratio et dates des deux règles).

## Terrain

Les 3 coupes en désaccord du rapport de comparaison, et quelques pixels tardifs, sur orthophoto IGN.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (changement de règle de date).

## Aller-retour 2/3 (2026-11-23, remarques du relecteur, décision de l'orchestrateur par délégation de Pascal)

1. En-tête du rapport : il dit « aucune valeur de pixel de la v3.0.1 », alors que la section des pixels tracés situe la date publiée de deux pixels nommés par leurs coordonnées. Décision : **garder les coordonnées** (licence NC, utiles au contrôle de Pascal sur orthophoto) et **corriger l'en-tête** pour dire exactement ce que le rapport contient (chiffres agrégés, plus la date publiée de deux pixels tracés).
2. Corriger la phrase sur le pixel n° 2 : il est retenu comme objet (21063, trace2.log) ; seul le n° 1 ne l'est pas.
3. Pareto : dire clairement que la tranche 16-60 j comptée sous « règle de date » ne redevient pas « date retrouvée » ; le chiffre principal est 19,4 % des tardifs ramenés à 15 j ou moins.
4. Nit : trace1.log se termine sur une erreur d'une version antérieure du script ; régénérer ou le signaler dans le rapport.
