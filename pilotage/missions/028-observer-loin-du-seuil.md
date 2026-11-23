# Mission 028 — Observer ce que datent les pixels « loin du seuil »

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (fin du cycle 11), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Sur une vingtaine de pixels de la classe « loin du seuil » de la mission 026, et sur l'objet FO0 daté par la seule carte recalculée, dire avec Sentinel-2 et les dates de vol des orthophotos IGN si chaque carte (v3.0.1 et recalcul) date la coupe des arbres ou un travail du sol postérieur, pour que Pascal sache ce que la carte doit dater et revoie, s'il le faut, sa décision du 2026-11-22 sur FF0 et FO0.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de 026 : `docs/analyses/cause-dates-tardives.md` (CC BY-NC 4.0) : classe « loin du seuil » (rien à la date publiée), orthos montrant herbe ou jeune plantation en 2018 puis sol travaillé en 2021, objet FO0 daté en 2019 par la seule carte recalculée, réserve sur la date de vol de l'ortho 2021.
- Données, **sur le poste de Pascal seulement** : `/home/pascal/dev/nemetonsar-donnees/m026/` (pixels_026.rds, traces, orthos), extrait v3.0.1, sorties du pilote.

## Questions à trancher par l'observation

1. Pour chaque pixel : à quelle date les arbres disparaissent (Sentinel-2 : indice de végétation, série avant / après), à quelle date le sol est travaillé, et quelle date donne chaque carte.
2. Dates de vol des orthophotos utilisées (métadonnées IGN), pour lever la réserve de 026.
3. L'objet FO0 : coupe réelle en 2019, jeune peuplement sans coupe, ou autre.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | en partie : Sentinel-2 L2A par le Planetary Computer (STAC, jeton par l'API publique comme dans `s1_lire()`), métadonnées des orthophotos IGN (Géoplateforme) | il choisit l'indice et le masque nuages, et le dit |
| A-t-il les moyens ? | oui en session locale : réseau, R, terra, rstac | hors du poste de Pascal : s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal tranche ce que la carte doit dater, et FF0/FO0).

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/observer-loin-du-seuil.R` (script), `docs/analyses/observer-loin-du-seuil.md` (rapport, **CC BY-NC 4.0**, mention « usage non commercial » en tête, attributions [S1] [S2] [FOR] [MET] [SUF] [ORT]). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m028/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package ; mettre une donnée ou un extrait de la v3.0.1, ni une image Sentinel-2 ou une orthophoto, au dépôt ; recopier des valeurs de la v3.0.1 au journal ; utiliser un objet interne de rstac ; conclure au-delà de ce qui est observé. Le rapport dit exactement ce qu'il contient, et nomme ses pixels (coordonnées) pour le contrôle de Pascal.

## Valeur provisoire (chiffre, réglage)

Une vingtaine de pixels, tirés au hasard avec graine dans la classe « loin du seuil », plus les pixels tracés par 026 et l'objet FO0 ; provisoire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 026 (terminée). Indépendante de 027 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument, graine) ; tirage des pixels reproductible ; observations recontrôlables par le relecteur sur quelques pixels.

## Terrain

Les pixels nommés du rapport, sur orthophoto et Sentinel-2, par Pascal.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal.
