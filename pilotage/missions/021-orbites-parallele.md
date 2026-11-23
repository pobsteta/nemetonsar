# Mission 021 — Orbites en parallèle (option 3 de l'ADR 0004)

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 9), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Traiter la passe 1 des orbites en parallèle dans `nemetonsar_detecter()` (fork par `parallel::mclapply`, repli en série là où le fork manque), à résultats identiques au bit près, pour appliquer l'option 3 de l'ADR 0004 tranchée par Pascal.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : ADR 0004 (décision de Pascal), `docs/analyses/lecture-parallele.md` § 3 (gain × 2,2 mesuré, pic ≈ 4,6 Go pour 3 orbites) | |
| A-t-il les moyens ? | oui : R, `parallel` (base R), terra, réseau vers le Planetary Computer | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/detecter.R`, `tests/testthat/test-detecter.R`. `NAMESPACE` et `man/` par l'orchestrateur. Les missions 021 et 022 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** changer un résultat (identité au bit près) ; affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle ; toucher `R/run.R` ou `R/s1.R` (mission 022).

## Valeur provisoire (chiffre, réglage)

nombre de processus par défaut : min(nombre d'orbites, cœurs disponibles − 1), réglable par un argument à défaut neutre ; provisoire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 019 (terminée), ADR 0004 (tranchée). CI rouge attendue : aucune.

## Tests

Identité au bit près série / parallèle (1, 2, 3 orbites ; plusieurs tailles de bloc) ; repli en série forcé (simulation de l'absence de fork) identique ; un processus enfant en erreur remonte une erreur claire ; temps mesuré dans le rendu.

## Terrain

Le temps avant/après sur le cas de mesure de 019.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
