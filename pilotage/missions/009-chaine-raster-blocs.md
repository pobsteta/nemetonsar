# Mission 009 — Chaîne de détection sur rasters, par blocs

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 3), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Écrire `nemetonsar_detecter()`, qui applique la chaîne filtre → ratio → combinaison des orbites → segmentation → post-traitement à des piles `terra::SpatRaster` (une par orbite) en les lisant par blocs de lignes avec bordure, et écrit les GeoTIFF des dates (`YYDDD`) et du ratio (dB) et le GeoPackage des objets, pour passer des tableaux synthétiques aux fichiers de la spec sans dépasser la mémoire d'un poste.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : ADR 0003 (terra seul, blocs avec bordure), spec (sorties), fonctions 003 à 007 | |
| A-t-il les moyens ? | oui : terra 1.7 installé dans le conteneur, rasters synthétiques écrits en fichiers temporaires | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `dev`
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** la recherche et le téléchargement d'images (STAC), les masques, l'AOI, le rapport.

## Harnais

- **Peut (périmètre) :** `R/detecter.R`, `tests/testthat/test-detecter.R`, `DESCRIPTION` (ajout de `terra` en Imports, et rien d'autre). `NAMESPACE` et `man/` régénérés par l'orchestrateur.
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier les fonctions 003 à 007 (une limite trouvée se remonte) ; ajouter une autre dépendance que `terra` ; écrire hors du dossier de sortie donné.
- **Sources autorisées :** `docs/adr/0003-dependances-r.md`, `docs/spec.md`, `docs/referentiels/`, `R/`, journal ; documentation de `terra`.

## Valeur provisoire (chiffre, réglage)

Taille de bloc (en lignes) : provisoire, mesurée par le pic de mémoire sur un raster d'essai ; bordure = rayon maximal des opérations spatiales (fenêtre du filtre, fermeture), à justifier.

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 à 007 (terminées), ADR 0003 (acceptée). CI : `terra` doit s'installer en CI (r-lib/actions lit `DESCRIPTION`) ; rouge attendu : aucun.

## Tests

- **Comment saura-t-on que c'est juste :** sur des rasters synthétiques écrits en GeoTIFF temporaires (deux orbites, une coupe connue, CRS UTM), le résultat par blocs (plusieurs tailles de bloc, dont une qui coupe la coupe en deux) est **identique** à celui de la chaîne appliquée au tableau entier ; les fichiers écrits ont le bon CRS, la bonne grille, le bon type (entier pour `YYDDD`, NA codé), et le GeoPackage un objet par coupe avec date, surface, ratio ; un objet coupé par une limite de bloc n'est compté qu'une fois. Les `Date` se comparent avec `expect_equal`. Tests sautés proprement si `terra` manque (`skip_if_not_installed`).

## Terrain

- **Échantillon que Pascal vérifiera :** ouvrir les deux GeoTIFF et le GeoPackage d'exemple dans QGIS.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Critère d'arrêt :** 3 allers-retours. **Qui tranche :** Pascal, ou l'orchestrateur par délégation.

## Comment saura-t-on que ça marche ?

Les sorties par blocs sont identiques aux sorties d'un seul tenant, et s'ouvrent dans un SIG.
