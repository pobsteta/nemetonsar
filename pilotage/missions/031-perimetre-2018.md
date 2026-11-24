# Mission 031 — Le périmètre 2018 : comment SUFOSAT date la première année

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-24 (après le cycle 12), sur décision de Pascal du même jour (journal, ligne 027 « périmètre 2018 »).

## Mission

**En une phrase (quoi, et pourquoi) :** Lire dans Mermoz et al. (2024) comment la méthode SUFOSAT date les coupes de 2018 (noyau du filtre, premières images), puis chiffrer sur la tuile pilote ce qu'un départ des ratios en 2018 changerait, pour que Pascal décide si 2018 est dans le périmètre du recalcul.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de 027 : `docs/analyses/regles-de-date.md`, groupe « Début de série » (2 822 tardifs dont la date publiée est en 2018, alors que nos ratios commencent en 2019 par construction, `annee_noyau + 1`).
- Code : `annee_noyau` dans `R/parametres.R`, son usage dans `R/run.R` (noyau du filtre multitemporel, `R/filtre.R`).
- Référence : Mermoz et al. (2024), IEEE JSTARS 17, p. 13743-13764, section II — doi:10.1109/JSTARS.2024.3429012 ; Bouvet et al. (2018), Remote Sensing 10(8), 1250.
- Données, **sur le poste de Pascal seulement** : `/home/pascal/dev/nemetonsar-donnees/pilote/`, `m027/`, extrait v3.0.1.

## Questions à trancher par la lecture et les chiffres

1. Que dit l'article (page et section citées) du noyau du filtre, de la première année datée et des images de 2017 ou 2018 utilisées ?
2. Un départ des ratios en 2018 (noyau pris en 2017, ou noyau plus court) est-il permis par la méthode telle qu'écrite ? Si non, ce que la v3.0.1 fait autrement, au sens de ce qui est publié.
3. Sur la tuile pilote, ce que ce départ change : pixels de 2018 datés, accord avec la date publiée pour ce groupe, effet sur les autres années.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | en partie : la lecture de l'article d'abord ; le chiffrage demande de relire Sentinel-1 à partir de 2017 | il dit ce qu'il a lu avant de calculer |
| A-t-il les moyens ? | oui en session locale : réseau, R, terra, rstac ; l'article (accès ouvert IEEE JSTARS) | hors du poste de Pascal : s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal tranche le périmètre).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus _(analyse seulement, package non touché ; `dev` plutôt qu'`analyste`, qui ne peut pas écrire ses scripts : leçon de 028)_

## Harnais

- **Peut (périmètre) :** `docs/analyses/perimetre-2018.R` (script), `docs/analyses/perimetre-2018.md` (rapport, **CC BY-NC 4.0**, mention « usage non commercial » en tête, attributions [S1] [SUF] et celles qu'il emploie). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m031/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package ; mettre une donnée ou un extrait de la v3.0.1 au dépôt ; recopier des valeurs de la v3.0.1 au journal ; donner une date de la v3.0.1 plus fine que le mois ; conclure au-delà de ce qui est lu ou mesuré.

## Valeur provisoire (chiffre, réglage)

Aucune : la mission lit et chiffre, elle ne règle rien.

## Dépend de / rouge attendu jusqu'à

Dépend de : 027 (terminée). Indépendante de 030 (périmètres disjoints) ; ses chiffres se font sous R0 et R2 si 030 est livrée avant, sous R0 sinon (le dire). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument) ; citations de l'article avec page ; chiffres recontrôlables par le relecteur.

## Terrain

Aucun : décision de périmètre.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal.
