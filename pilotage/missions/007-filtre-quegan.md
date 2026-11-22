# Mission 007 — Filtre multitemporel de Quegan et Yu

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 2), équipe validée par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `s1_filter_multitemp()`, le filtre multitemporel de Quegan et Yu dont le noyau est calculé sur l'année de référence puis appliqué aux images postérieures, pour réduire le speckle comme dans l'étape 2 de la méthode.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui, sous condition : la formule de Quegan et Yu (2001) n'a pas été relevée par l'acquereur ; l'agent la relève d'abord à une source citée (article, ou documentation S1Tiling/OTB du filtre multitemporel) et l'écrit dans son rendu avant de coder | |
| A-t-il les moyens ? | oui : R, testthat, séries synthétiques à speckle simulé (loi gamma) | |

**Temps de la main :** donner, avec la formule sourcée en première tâche.

**Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `dev`
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** La lecture d'images réelles.

## Harnais

- **Peut (périmètre) :** `R/filtre.R`, `tests/testthat/test-filtre.R`. `NAMESPACE` et `man/` sont régénérés par l'orchestrateur (roxygen) après le rendu : ils ne sont dans le périmètre d'aucune des missions du cycle 2, qui peuvent ainsi tourner ensemble.
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** sortir du périmètre ; ajouter une dépendance (aucune ADR ne l'autorise) ; inventer la formule ; appliquer un autre filtre spatial (M24 : aucun autre filtre).
- **Sources autorisées :** `docs/referentiels/parametres-sufosat.md` (§ filtre : M24 p. 13746, fenêtre 3×3, noyau 2018, application à partir du 1er janvier 2019 ; B18 p. 4), `docs/spec.md`, `R/parametres.R`. Ouvert : internet, pour Quegan et Yu (2001), IEEE TGRS 39(11), et la documentation S1Tiling / OTB.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

aucune nouvelle (fenêtre 3, `annee_noyau` 2018 viennent de 003).

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 (terminée). Indépendante de 006 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Série à speckle simulé (gamma, ENL connu) : l'ENL mesuré après filtre augmente et la moyenne est conservée (filtre sans biais) ; une marche de -6 dB après 2019 reste une marche (pas de fuite de la chute vers les dates antérieures) ; noyau calculé sur les seules images de `annee_noyau` ; images de l'année de référence elles-mêmes traitées comme la source le dit ; NA ; bords de la fenêtre ; une référence naïve pixel par pixel. Les objets `Date` se comparent avec `expect_equal` (CI sous R 4.6).

## Terrain

- **Échantillon que Pascal vérifiera :** Une série synthétique tracée avant/après filtre, et l'ENL avant/après.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal, ou l'orchestrateur par délégation.

## Comment saura-t-on que ça marche ?

Sur une série à speckle simulé, `rcr_compute()` sur la série filtrée retrouve la date de la coupe là où la série brute échoue.
