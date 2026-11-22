# Mission 014 — Une commande unique : `nemetonsar_run()`

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 5), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `nemetonsar_run(aoi, date_debut, date_fin, dossier, tcd = NULL, effis = NULL, parametres)`, qui enchaîne `aoi_preparer()` → par tuile : `s1_rechercher()`, `s1_lire()`, `masque_foret()`, `nemetonsar_detecter()` (avec le nouvel argument `foret`), masque par le morceau d'AOI → `masque_feu()` → assemblage des tuiles en Lambert-93, et écrit un journal d'exécution, pour tenir le premier critère de réussite du brief (« une commande unique »).

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : fonctions 003 à 013, décisions du journal (option B du masque forêt, appariement EFFIS année et année précédente, filtre 19xxx pour la correction 2019, masquage par morceau d'AOI, Lambert-93 provisoire) | |
| A-t-il les moyens ? | oui : terra, rstac, réseau ; tests sur entrées locales synthétiques (images en GeoTIFF, `s1_rechercher` remplaçable) | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/run.R`, `tests/testthat/test-run.R`, `R/detecter.R` et `tests/testthat/test-detecter.R` (seulement l'argument `foret` : ratio et date à NA hors forêt après la passe 1, sans changer le reste). `NAMESPACE` et `man/` par l'orchestrateur.
- **Ne doit pas (écrit) :** modifier les autres fonctions ; télécharger plus qu'une petite fenêtre dans les tests ; écrire hors de `dossier` ; chaînes non ASCII ; casser un test existant.

## Valeur provisoire (chiffre, réglage)

Sortie assemblée en Lambert-93 (EPSG:2154, ADR 0003) ; méthode de reprojection des rasters de sortie (plus proche voisin pour les dates et les objets) ; journal d'exécution au format texte (spec) ; correction 2019 du masque forêt : la détection de 2019 se fait dans le même appel si la période la couvre (à proposer et dire).

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 à 013 (terminées). CI rouge attendue : aucune ; le test réseau éventuel sous `NEMETONSAR_TESTS_RESEAU`.

## Tests

Bout en bout sur entrées synthétiques (deux tuiles dans deux zones UTM, images GeoTIFF locales injectées à la place de la recherche STAC, TCD et EFFIS synthétiques) : sorties Lambert-93 écrites, une coupe à cheval sur deux tuiles comptée une fois (ou dire la limite), coupe hors forêt absente, objet brûlé retiré, journal d'exécution complet (images utilisées, paramètres, licences et attributions), identité avec `nemetonsar_detecter()` sur une seule tuile ; `foret` dans `nemetonsar_detecter()` testé. `Date` en `expect_equal`.

## Terrain

Un dossier de sortie à ouvrir dans QGIS, sur l'AOI synthétique.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
