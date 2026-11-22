# Mission 006 — Post-traitement : surface minimale et fermeture

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 2), équipe validée par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `postprocess()` qui retire les objets de moins de 0,1 ha puis applique une fermeture morphologique à la détection de `rcr_segment()`, et rend la table des objets (surface, date, ratio moyen), pour livrer l'étape 6 de la méthode sans dépendance.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : table 001 (M24 § II-D.1 p. 13748 : objets < 0,1 ha écartés puis fermeture ; résolution 10 m, Table I) | |
| A-t-il les moyens ? | oui : R, testthat, matrices synthétiques | |

**Temps de la main :** donner.

**Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `dev`
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** La vectorisation, les masques.

## Harnais

- **Peut (périmètre) :** `R/postprocess.R`, `tests/testthat/test-postprocess.R`. `NAMESPACE` et `man/` sont régénérés par l'orchestrateur (roxygen) après le rendu : ils ne sont dans le périmètre d'aucune des missions du cycle 2, qui peuvent ainsi tourner ensemble.
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** sortir du périmètre ; ajouter une dépendance (aucune ADR ne l'autorise) ; vectoriser en polygones (attend l'ADR des dépendances) ; inventer la forme de l'élément structurant (carré de `taille_fermeture`, provisoire).
- **Sources autorisées :** `docs/referentiels/parametres-sufosat.md`, `docs/spec.md`, `R/parametres.R`, `R/segment.R`, `R/rcr.R`, journal (décisions 003 à 005). Fermé : internet.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

`taille_fermeture = 3` (carré), déjà provisoire ; taille du pixel = 10 m (Table I de M24), en argument `resolution_m`.

## Dépend de / rouge attendu jusqu'à

Dépend de : 005 (terminée). CI rouge attendue : aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Objet de 9 pixels (0,09 ha) retiré, de 10 pixels gardé ; fermeture qui comble un trou d'un pixel et ne fusionne pas deux objets éloignés ; ordre « surface puis fermeture » vérifié ; table des objets (identifiant, pixels, surface en ha, date médiane en YYDDD, ratio moyen en dB) juste sur un cas connu ; NA et bords ; une référence naïve pour la fermeture. Les objets `Date` se comparent avec `expect_equal` (CI sous R 4.6).

## Terrain

- **Échantillon que Pascal vérifiera :** Un exemple avant/après à afficher avec `image()`.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal, ou l'orchestrateur par délégation.

## Comment saura-t-on que ça marche ?

La table des objets d'un cas synthétique donne les surfaces et les dates attendues.
