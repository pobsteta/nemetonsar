# Mission 032 — Dire ce que la carte date sur FF0/FO0, et avertir après la bascule Sentinel-1C/1D

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-24 (après le cycle 12), sur les décisions de Pascal du même jour (journal, lignes 028 « FF0 et FO0 » et 029 « publication »).

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire clairement dans la documentation du package que, sur les postes BD Forêt FF0 et FO0 (sans couvert arboré au relevé), la carte peut dater des événements qui ne sont pas des coupes d'arbres, et ajouter à la documentation et aux sorties de `nemetonsar_run()` un avertissement pour les détections postérieures au 2026-06-30 (bascule Sentinel-1A → 1C/1D), pour que l'utilisateur sache ce qu'il lit, puisque Pascal a choisi de garder FF0/FO0 et de publier après la bascule.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Décisions de Pascal du 2026-11-24 : la carte date la coupe des arbres seulement ; FF0 et FO0 restent dans le masque par défaut, documentation claire ; détections postérieures au 2026-06-30 publiées avec avertissement.
- Rapport de 028 : `docs/analyses/observer-loin-du-seuil.md` (FF0 sans arbre en 2018 dans le lot, FO0 déjà coupé en 2018 ; un seul AOI).
- Rapport de 029 : `docs/analyses/continuite-s1c.md` (rupture du ratio sur forêt sans coupe, 67 des 80 objets postérieurs à la bascule dans les 30 jours qui suivent, cause non isolée).
- Code : `masque_foret_bdforet()` et `codes_foret` (`R/masques.R`), `nemetonsar_run()` (`R/run.R`), `capteurs_sufosat()` (`R/parametres.R`), `README.md`.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : roxygen, `warning()` ou message, champ dans les sorties | il propose la forme de l'avertissement dans les sorties (message, colonne, métadonnée) et la dit |
| A-t-il les moyens ? | oui | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal relit le texte des avertissements).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/masques.R` et `R/run.R` (documentation roxygen ; dans `R/run.R`, l'avertissement seulement), `R/parametres.R` (documentation de `capteurs_sufosat()`), `man/`, `README.md`, les tests de l'avertissement (`tests/testthat/test-run.R`).
- **Câblé :** pas de `main`, journal en ajout seul, pas de code sans tests.
- **Ne doit pas (écrit) :** changer `codes_foret` ni le masque ; changer la détection ou la datation ; suspendre ou filtrer les détections postérieures au 2026-06-30 (Pascal a choisi de publier) ; donner dans la documentation des valeurs de la v3.0.1.

## Valeur provisoire (chiffre, réglage)

Date de la bascule : 2026-06-30, celle de `capteurs_sufosat()` ; l'avertissement la lit là, sans la recopier.

## Dépend de / rouge attendu jusqu'à

Dépend de : **030** (même fichier `R/run.R`) : part après la fusion de 030. CI rouge attendue : aucune.

## Tests

- Une période qui dépasse la date de bascule produit l'avertissement ; une période qui s'arrête avant n'en produit pas.
- La date de bascule est lue dans `capteurs_sufosat()` (changer la date déclarée déplace l'avertissement).
- La documentation de `masque_foret_bdforet()` et de `nemetonsar_run()` nomme FF0 et FO0 et dit ce qu'ils datent.

## Terrain

Pascal lit les deux textes (FF0/FO0 et bascule) dans l'aide du package et le README.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal.
