# Mission 033 — Mesurer le décalage du ratio entre Sentinel-1A et Sentinel-1C/1D

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-24 (après le cycle 12), sur décision de Pascal du même jour (journal, ligne 029 « mission d'analyse »).

## Mission

**En une phrase (quoi, et pourquoi) :** Mesurer, sur au moins trois tuiles de forêt stable de régions différentes, le décalage médian du ratio de changement entre les fenêtres Sentinel-1A et Sentinel-1C/1D, orbite par orbite, et dire s'il est constant, pour que Pascal sache si un recalage exposé (valeur par défaut 0) peut corriger la rupture vue par 029 ou si sa cause est ailleurs.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de 029 : `docs/analyses/continuite-s1c.md` et `continuite-s1c.R` (méthode de la question 3 : forêt sans coupe, part sous tp, écart robuste, médiane du ratio par fenêtre ; une tuile, 30TXP, une année).
- `capteurs_sufosat()` (`R/parametres.R`) : S1A jusqu'au 2026-06-29, S1C et S1D à partir du 2026-06-30.
- Masque forêt : TCD 2018 seuil 10 % ou BD Forêt ; « forêt stable » = sans détection sur la période et sans coupe connue (l'agent dit son critère).

## Questions à trancher par les chiffres

1. Par tuile et par orbite : décalage médian du ratio (fenêtres tout-1A contre tout-1C/1D), part sous tp, écart robuste, comparés à la variation saisonnière des années 1A (même mois, années précédentes).
2. Le décalage est-il constant d'une tuile, d'une orbite et d'une date à l'autre (au sens d'un écart chiffré, pas d'un test unique) ?
3. Si un recalage constant était appliqué, que deviendrait la part de forêt stable sous tp après la bascule ? (Essai de sensibilité, pas un réglage.)

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : la méthode de 029, étendue à d'autres tuiles | il choisit les tuiles (régions forestières différentes, orbites servies par 1C/1D) et le dit avant de lire |
| A-t-il les moyens ? | oui en session locale : réseau, R, terra, rstac ; environ 40 min de lecture Sentinel-1 par tuile | hors du poste de Pascal : s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal tranche s'il faut un recalage, et sa valeur).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus _(analyse seulement, package non touché ; `dev` plutôt qu'`analyste`, leçon de 028)_

## Harnais

- **Peut (périmètre) :** `docs/analyses/decalage-1a-1c1d.R` (script), `docs/analyses/decalage-1a-1c1d.md` (rapport, attributions [S1] et celles qu'il emploie ; **CC BY-NC 4.0** seulement s'il utilise la v3.0.1). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m033/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package (le recalage, s'il vient, est une autre mission) ; mettre une image Sentinel-1 au dépôt ; proposer une valeur de recalage comme réglage ; conclure au-delà de ce qui est mesuré.

## Valeur provisoire (chiffre, réglage)

Au moins trois tuiles ; fenêtres de 2025-2026 ; provisoire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 029 (terminée). Indépendante de 030, 031 et 032 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

Script reproductible (tuiles et chemins en argument) ; chiffres recontrôlables par le relecteur sur une tuile.

## Terrain

Aucun : mesure sur forêt stable.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal.
