# Mission 020 — Masque forêt à partir de la BD Forêt v2

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 8), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `masque_foret_bdforet()` qui construit le masque forêt sur la grille d'une tuile à partir des polygones de la BD Forêt v2 de l'IGN (fichier local ou service WFS de la Géoplateforme), et l'accepter dans `nemetonsar_run()` à la place du TCD, pour appliquer la décision de Pascal du 2026-11-22.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : décision de Pascal (journal, `cap`), `R/masques.R`, `R/run.R` ; à relever : schéma de la BD Forêt v2 (champs `TFV`, `CODE_TFV`, `ESSENCE`), nomenclature des formations végétales, couche WFS sur data.geopf.fr, licence (Licence Ouverte 2.0, à vérifier) | |
| A-t-il les moyens ? | oui : terra, réseau vers data.geopf.fr | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/masques.R`, `R/run.R`, `tests/testthat/test-masques.R`, `tests/testthat/test-run.R`, `docs/referentiels/licences.md` (ligne BD Forêt v2 seulement). `NAMESPACE` et `man/` par l'orchestrateur. Les missions 019 et 020 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle sans ADR ; changer le comportement avec `tcd` ; télécharger plus que l'AOI.

## Valeur provisoire (chiffre, réglage)

liste des codes TFV comptés comme forêt (formations boisées fermées et ouvertes ; landes et formations herbacées exclues) : provisoire, à sourcer sur la documentation IGN ; rastérisation au centre du pixel ; correction 2019 inchangée (pixels 19xxx retirés).

## Dépend de / rouge attendu jusqu'à

Dépend de : 018 (terminée). CI rouge attendue : aucune.

## Tests

Polygones synthétiques avec plusieurs codes TFV : masque juste sur une grille 10 m en UTM depuis du Lambert-93 ; codes non forestiers exclus ; `nemetonsar_run(bdforet = …)` équivalent à un TCD qui donnerait le même masque ; un test réseau (sous `NEMETONSAR_TESTS_RESEAU`) qui lit la BD Forêt v2 sur 1 km² des Landes ; `tcd` et `bdforet` exclusifs (erreur claire si les deux).

## Terrain

Le masque BD Forêt sur l'AOI de l'essai des Landes, superposé à l'objet de 0,97 ha.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (ADR 0004), l'orchestrateur par délégation pour le reste.
