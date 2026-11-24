# Mission 030 — Coder la date « première date sous le seuil, toutes orbites » (R2)

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-24 (après le cycle 12), sur les décisions de Pascal du même jour (journal, lignes 027 et 029).

## Mission

**En une phrase (quoi, et pourquoi) :** Coder dans le package la règle de date R2 de la mission 027 (chaque pixel détecté est daté à la première date où l'une des orbites a un ratio de datation ≤ `seuil_datation`, repli sur la règle actuelle s'il n'y en a pas), avec un test de stabilité quand la série est prolongée, puis vérifier par une exécution réelle de la tuile pilote ce que la règle change à la surface et à la correction 2019, parce que la règle actuelle (minimum du ratio de l'orbite retenue) date trop tard et re-date des pixels déjà publiés.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de 027 : `docs/analyses/regles-de-date.md` (définition de R0 à R3, repli, effets attendus, point « Détection et surface » non vérifié). Script : `docs/analyses/regles-de-date.R`.
- Rapport de 029 : `docs/analyses/continuite-s1c.md`, section « Stabilité des dates » (re-datage sous R0 quand la série est prolongée).
- Code actuel : ratio de datation et date au minimum dans `R/rcr.R` (`rcr_compute()`, `rcr_combine_orbites()`) ; seuils dans `R/parametres.R` (`parametres_sufosat()`, `seuils_db()`) ; correction 2019 et assemblage dans `R/run.R` (`nemetonsar_run()`, date médiane des objets).
- Décisions de Pascal du 2026-11-24 : R2 ; repli sur R0 ; seuil de datation = seuil de détection effectif (tp × 1,15 = −3,45 dB), exposé comme paramètre distinct avec cette valeur par défaut ; re-datage = défaut, testé ici.
- Données du pilote, **sur le poste de Pascal seulement** : `/home/pascal/dev/nemetonsar-donnees/pilote/` (sorties de 017), `m027/`.

## À trancher par Pascal à la validation de la fiche

**R2 devient-elle la règle par défaut, ou une option à côté de R0 ?** (Proposition de 027 : R0 reste le défaut tant que Pascal n'a pas tranché.) La réponse est écrite ici avant le lancement.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : la règle est définie et chiffrée par 027, le code de datation est isolé dans `R/rcr.R` | |
| A-t-il les moyens ? | oui en session locale : R, terra, rstac, réseau pour l'exécution de la tuile pilote (environ 45 min) | hors du poste de Pascal : faire le code et les tests, s'arrêter avant l'exécution réelle et le dire |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (Pascal tranche la règle par défaut, et ce que l'écart de surface éventuel implique).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/rcr.R`, `R/parametres.R`, `R/run.R` (seulement ce que la règle de date et le nouveau paramètre demandent), leurs tests (`tests/testthat/test-rcr.R`, `test-parametres.R`, `test-run.R`), la documentation roxygen et `man/` qui en découlent, `NEWS.md` s'il existe. Script et note d'exécution de la tuile pilote : `docs/analyses/regle-r2-pilote.R` et `.md` (**CC BY-NC 4.0** si une valeur ou une comparaison à la v3.0.1 y figure, mention en tête, attributions). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m030/`).
- **Câblé :** pas de `main`, journal en ajout seul, pas de code sans tests.
- **Ne doit pas (écrit) :** changer la détection (ratio de détection, seuils de détection, segmentation) ; inventer un seuil ; mettre une donnée de la v3.0.1 au dépôt ; recopier des valeurs de la v3.0.1 au journal ; toucher `R/masques.R` ni la documentation de FF0/FO0 et de l'avertissement 1C/1D (mission 032).

## Valeur provisoire (chiffre, réglage)

`seuil_datation` = seuil de détection effectif (−3,45 dB) par défaut ; provisoire, gèle au jalon 2 comme les autres réglages.

## Dépend de / rouge attendu jusqu'à

Dépend de : 027 et 029 (terminées). La mission 032 attend celle-ci (même fichier `R/run.R`). CI rouge attendue : aucune.

## Tests

- R2 sur des séries simulées : première date sous le seuil, toutes orbites ; égalités (date la plus ancienne) ; repli sur R0 quand aucune orbite ne passe sous le seuil.
- `seuil_datation` : valeur par défaut égale au seuil de détection effectif ; passage linéaire ↔ dB testé ; paramètre validé (refus d'une valeur absurde).
- Aller-retour `YYDDD` des dates produites.
- **Stabilité :** prolonger une série simulée de N images après la date ne change pas la date déjà sortie, sauf effets de bord de fenêtre, que le test nomme et chiffre.
- Exécution réelle de la tuile pilote : surface assemblée, objets dont la date médiane passe en 2019 (027 en annonce 14 sous R2), dates 2025-01 à 2025-09 stables entre une série qui s'arrête au 2025-09-30 et une série prolongée.

## Terrain

Les sept pixels tracés de 027 (tableau « Pixels tracés »), sous R2, par Pascal.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal.
