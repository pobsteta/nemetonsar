# Mission 023 — Parallélisme sans blocage sous GDAL récent

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (cycle 10), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Rendre la lecture parallèle des images (`s1_lire(flux)`) et la passe 1 par orbite (`nemetonsar_detecter(processus)`) sûres sous GDAL ≥ 3.11 et terra ≥ 1.9, où un fork après un accès réseau GDAL bloque les processus enfants sans fin ; et exposer `processus` dans `nemetonsar_run()`. Résultats identiques au bit près.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Constat (2026-11-23, poste de Pascal)

- Machine : 8 cœurs, R 4.6.2, terra 1.9.60, GDAL 3.11.4. Le cloud des missions 021 et 022 avait R 4.3.3, terra 1.7-65, GDAL 3.8.4 : le défaut n'y apparaissait pas.
- `Rscript docs/analyses/pilote-landes.R <dossier> executer` : 9 images lues en 1 min, puis plus rien pendant 1 h 47. Les 4 enfants de `mclapply` (flux = 4) restaient en `futex_do_wait`, 0 % CPU ; le parent restait en `poll`. Un socket HTTPS vers le Planetary Computer en CLOSE-WAIT était partagé par le parent et les 4 enfants (même descripteur, hérité du fork).
- Contournement vérifié hors dépôt : `flux = 1L` et `fork_disponible()` forcé à `FALSE` (série partout).

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | en partie : deux pistes à comparer, (a) processus neufs (`parallel::makePSOCKcluster`, sans état GDAL hérité), (b) fork gardé mais sans état GDAL ou réseau ouvert dans le parent au moment du fork | l'agent mesure les deux et propose ; l'orchestrateur tranche |
| A-t-il les moyens ? | oui : R, `parallel` (base R), terra, réseau vers le Planetary Computer ; un environnement GDAL ≥ 3.11 pour reproduire | sans GDAL récent, le défaut ne se reproduit pas : le dire et s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/s1.R`, `R/detecter.R`, `R/run.R`, leurs tests. `NAMESPACE` et `man/` par l'orchestrateur.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** changer un résultat (identité au bit près série/parallèle) ; affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle hors base R.

## Valeur provisoire (chiffre, réglage)

`processus` dans `nemetonsar_run()`, défaut `NULL` (règle de 021 inchangée) ; `flux = 4L` inchangé.

## Dépend de / rouge attendu jusqu'à

Dépend de : 021 et 022 (terminées). CI rouge attendue : aucune.

## Tests

- Identité au bit près série/parallèle pour `s1_lire()` et la passe 1 (cas synthétiques existants).
- Un test qui échouait avant le correctif : lecture parallèle après un accès GDAL dans le parent, avec délai maximal (pas de blocage silencieux : erreur claire au-delà du délai).
- Le passage effectif en parallèle prouvé (suite mineure de 021).

## Terrain

`docs/analyses/pilote-landes.R ... executer` sur le poste de Pascal (GDAL 3.11.4), en parallèle, sans blocage ; temps comparé à l'exécution en série du 2026-11-23.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.

## Aller-retour 2/3 (2026-11-23, remarques du relecteur, décision de l'orchestrateur)

1. Avertissement de terra 1.9 « [rasterize] unexpected additional argument(s): datatype » (`R/run.R:978`, `run_assembler`, 24 fois dans la suite) : le supprimer sans changer un résultat (type de sortie vérifié par un test), compatible avec terra 1.7 et 1.9.
2. `test-s1.R` : retirer la variable `fils`, calculée et jamais utilisée.
3. `r_avec_delai()` appelle `pkgload::load_all` : déclarer `pkgload` dans Suggests (DESCRIPTION, par l'orchestrateur si hors périmètre) ou s'en passer.
4. Titre de la fiche : la cause est terra 1.9, pas GDAL (journal) ; le titre reste pour la traçabilité.
