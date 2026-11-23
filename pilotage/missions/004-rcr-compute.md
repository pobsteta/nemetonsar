# Mission 004 — Ratio de changement radar et date du minimum

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `rcr_compute()` sur une série temporelle en tableau R (lignes × colonnes × dates, une orbite), qui rend le ratio minimal en dB et sa date en `YYDDD`, pour poser le cœur de la détection sans dépendre encore d'un format d'image.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : brief (méthode, étape 4), table 001, `date_vers_yyddd()` | |
| A-t-il les moyens ? | oui : séries synthétiques dont la coupe est connue | |

**Temps de la main :** donner.

**Degré de la main :** le chef tranche.

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `dev`
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** Pas de lecture de fichiers, pas de terra ; la combinaison des orbites attend la table 001.

## Harnais

- **Peut (périmètre) :** `R/rcr.R`, `tests/testthat/test-rcr.R`, `NAMESPACE`, `man/`
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul (hooks du plugin).
- **Ne doit pas (écrit) :** sortir du périmètre ; inventer la règle de combinaison des orbites ; ajouter une dépendance.
- **Sources autorisées :** `docs/brief.md`, `docs/spec.md`, `docs/referentiels/parametres-sufosat.md`, `R/dates.R`, `R/parametres.R`.

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

aucune nouvelle (Xa, Xb viennent de 003).

## Dépend de / rouge attendu jusqu'à

Dépend de : 003. Ordre : 003 → 004. PR en brouillon jusqu'à la fusion de 003. CI rouge attendue : aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Série synthétique : chute de 6 dB à une date connue → minimum ≈ −6 dB à cette date ; série stable → pas de minimum sous les seuils ; valeurs manquantes (neige) ignorées ; Xa et Xb paramétrables.

## Terrain

- **Échantillon que Pascal vérifiera :** Sur une série synthétique tracée, Pascal voit la date retrouvée.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal.

## Comment saura-t-on que ça marche ?

La date retrouvée est la date injectée, à une acquisition près.
