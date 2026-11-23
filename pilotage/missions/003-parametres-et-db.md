# Mission 003 — Paramètres exposés et conversions en dB

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `parametres_sufosat()` et les conversions linéaire ↔ dB et seuils (ts, tp × facteur), pour que toutes les fonctions de détection partagent les mêmes réglages sourcés.

**Redite par l'agent :** Écrire `parametres_sufosat()`, objet unique de réglages validés et sourcés, avec les conversions linéaire ↔ dB et les seuils effectifs ts et tp, pour que 004 et 005 n'aient aucune valeur en dur. *(Rendu du `dev`, reporté par l'orchestrateur.)*

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : spec « Paramètres exposés », table de la mission 001 | |
| A-t-il les moyens ? | oui : R, testthat, CI | |

**Temps de la main :** prendre : la forme de l'objet de paramètres engage tout le package ; l'agent rend d'abord un plan (signature, validation, noms), validé avant code.

**Degré de la main :** le chef tranche.

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `dev` (tests compris ; le `testeur` relit les cas limites)
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** Pas de lecture d'images, pas de ratio.

## Harnais

- **Peut (périmètre) :** `R/parametres.R`, `R/db.R`, `tests/testthat/test-parametres.R`, `tests/testthat/test-db.R`, `NAMESPACE`, `man/`
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul (hooks du plugin).
- **Ne doit pas (écrit) :** sortir du périmètre ; ajouter une dépendance (Imports) sans ADR ; une valeur par défaut absente de la table de la mission 001.
- **Sources autorisées :** `docs/spec.md`, `docs/referentiels/parametres-sufosat.md` (mission 001), `CLAUDE.md` (règles de test). Fermé : internet.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

les défauts de la spec, provisoires jusqu'à la fusion de 001 ; ils gèlent avec elle.

## Dépend de / rouge attendu jusqu'à

Dépend de : 001. Ordre de fusion : 001 → 003. PR en brouillon jusqu'à la fusion de 001. CI rouge attendue : aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Aller-retour linéaire ↔ dB ; ts = 1,15 × −4,5 dB et tp = 1,15 × −3 dB ; facteur modifiable ; paramètre invalide refusé avec un message clair.

## Terrain

- **Échantillon que Pascal vérifiera :** Pascal lance `parametres_sufosat()` et retrouve les valeurs du brief.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal.

## Comment saura-t-on que ça marche ?

R CMD check vert, et 004 et 005 utilisent `parametres_sufosat()` sans valeur en dur.
