# Mission 019 — Mesurer la lecture réelle et le parallélisme

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 8), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Mesurer, sur l'AOI pilote des Landes, le temps de lecture d'une orbite réelle (COG distants du Planetary Computer, puis copie locale) par bandes de lignes, et le gain du traitement des orbites en parallèle (base R, `parallel`), pour que Pascal tranche l'ADR 0004 sur des chiffres et non sur une extrapolation.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : ADR 0004 et sa critique, `docs/analyses/performance.md`, `R/s1.R`, `R/detecter.R` | |
| A-t-il les moyens ? | oui : réseau vers le Planetary Computer (vérifié en 013), `parallel` (base R) ; disque à surveiller (copie locale limitée à une fenêtre et un nombre d'images dits) | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/lecture-parallele.md`, `docs/analyses/lecture-parallele.R`. `NAMESPACE` et `man/` par l'orchestrateur. Les missions 019 et 020 ont des périmètres disjoints.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle sans ADR ; modifier `R/` ou `tests/` (mesure seule ; une optimisation trouvée se remonte).

## Valeur provisoire (chiffre, réglage)

aucune ; la mesure remplace l'estimation de 2 à 2,5 h et celle de 2,5 à 3 h par tuile.

## Dépend de / rouge attendu jusqu'à

Dépend de : 018 (terminée). CI rouge attendue : aucune.

## Tests

Script reproductible (graine, chemins relatifs) ; mesures répétées au moins 2 fois ; taille des tuiles internes des COG relevée (`terra::describe`) ; lecture distante vs locale par bande de 9 lignes et par hauteur alignée sur les tuiles internes ; parallélisme 1, 2, 3 processus (fork) avec pic mémoire ; extrapolation à une tuile dite telle ; conclusion : le goulot, et ce que chaque option de l'ADR 0004 apporterait.

## Terrain

Le tableau de synthèse du rapport.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (ADR 0004), l'orchestrateur par délégation pour le reste.
