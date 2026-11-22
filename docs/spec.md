# nemetonsar — spécification v1

22 novembre 2026 · rédigée par Claude (orchestrateur) à partir de `docs/brief.md`
(arbitrages du 22 novembre compris). **Statut : proposée, à valider par Pascal**
(porte n° 1). Un lien plutôt qu'une copie : les paramètres de la méthode et leurs
sources sont dans le brief, rubrique « Méthode à reproduire ».

## Pour qui, et ce qu'il fait avec

Pascal, sur son poste de travail, choisit une AOI en France métropolitaine (au plus un
département) et une période depuis 2018 ; il obtient la carte des coupes rases de cette
AOI sur cette période, au format des fichiers SUFOSAT publiés, et peut la prolonger mois
par mois.

## Parcours

1. **Préparer** : Pascal fournit un fichier vecteur d'AOI (GeoPackage, GeoJSON,
   shapefile) et une période. Le package vérifie l'AOI (géométrie valide, en France
   métropolitaine, surface au plus celle d'un département) et la reprojette sur la grille
   MGRS 10 m des tuiles qu'elle touche.
2. **Lancer** : `nemetonsar_run(aoi, date_debut, date_fin, dossier, parametres)`.
   L'inventaire des images, leur récupération, le filtrage, les masques, le ratio, la
   segmentation et le post-traitement s'enchaînent ; chaque étape est mise en cache.
3. **Prolonger** : relancé avec une `date_fin` plus tardive, le pipeline ne traite que
   les images nouvelles et les dates qu'elles touchent (Xa = 3 images après chaque date).
4. **Lire** : Pascal ouvre les rasters et les polygones dans un SIG, et le rapport HTML.
5. **Contrôler** : sur 2018 – septembre 2025, le rapport compare à la v3.0.1 ; après
   septembre 2025, à la référence locale de l'AOI.

## Données manipulées

| Donnée | Rôle | Format en sortie de son étape |
|---|---|---|
| AOI | Emprise du calcul | `sf`, reprojeté sur la grille MGRS |
| Images Sentinel-1 VH, par orbite relative et par capteur (1A, 1C, 1D) | Détection | Pile de rasters 10 m, valeurs linéaires (rétrodiffusion), dates d'acquisition |
| Noyau de filtrage multitemporel | Quegan et Yu | Raster, recalculable par capteur ou par période |
| Masque forêt (TCD 2018 ≥ 10 %, corrigé 2019) | Exclusion hors forêt | Raster binaire 10 m |
| Masque neige (MOD10A1) | Images écartées par mois | Liste d'images écartées, au journal d'exécution |
| Masque feu (EFFIS) | Objets retirés (≥ 75 % brûlés) | Polygones |
| Ratio (RCR), en dB | Détection | Raster du minimum et de sa date, par orbite |
| Sorties | Voir le brief, « Sorties attendues » | GeoTIFF (dates `YYDDD`, ratio en dB), GeoPackage, HTML, texte |

## Paramètres exposés (valeur par défaut = SUFOSAT)

`polarisation = "VH"`, `xa = 3`, `xb = Inf` (tout l'historique), `facteur_seuil = 1.15`,
`ts_db = -4.5`, `tp_db = -3` (avant facteur), `surface_min_ha = 0.1`,
`fermeture = TRUE`, `seuil_tcd = 10`, `seuil_feu = 0.75`, `annee_noyau = 2018`,
`capteurs = c("S1A", "S1C", "S1D")`. Les écarts avec Bouvet et al. (2018) (polarisation,
filtre, Xb, nettoyage, contour) sont des valeurs possibles de ces paramètres.

## Hors périmètre v1

Voir le brief, « Périmètre », et l'arbitrage n° 2 : France entière, hors Europe,
améliorations v2/v3 non documentées, analyses par essence ou propriété, interface en
ligne, probabilité reconstruite, éclaircies et coupes de moins de 0,1 ha, tout usage
commercial.

## Critères d'acceptation

1. `nemetonsar_run()` produit, sur l'AOI pilote, les quatre sorties du brief, au format
   des fichiers publiés (dates en `YYDDD`, même grille).
2. Relancé avec un mois de plus, il ne recalcule que ce mois et les dates qu'il touche
   (vérifié par le cache, et par un temps de calcul mesuré).
3. Sur l'AOI pilote, 2018 – septembre 2025 : part de surface v3.0.1 retrouvée, part
   recalculée absente, écart de date médian, rapportés. **Cibles : valeurs provisoires**
   (proposition du brief : 85 %, moins d'un mois), à fixer avant le premier essai.
4. Après septembre 2025 : rappel, précision, F1 et exactitude sur la référence locale,
   protocole des 75 % de l'article. Cibles à fixer avant le premier essai.
5. Continuité 1A → 1C/1D : sur forêt stable, l'écart de rétrodiffusion moyen entre
   capteurs sur la période de recouvrement est mesuré et rapporté ; un écart au-delà
   d'un seuil à fixer déclenche le recalcul du noyau.
6. Sensibilité au facteur de seuil, 0,8 à 1,2 par pas de 0,05, rapportée.
7. Chaque fonction a ses tests ; les noyaux (filtre de Quegan, ratio, croissance de
   région) sont testés sur des données synthétiques dont le résultat est connu.
8. Chaque entrée et chaque sortie porte sa licence dans le journal d'exécution.

## Valeurs provisoires

| Valeur | Mesurée par | Gèle à |
|---|---|---|
| Cibles d'accord avec la v3.0.1 | premier essai sur l'AOI pilote, Pascal juge | jalon 2 |
| Cibles sur la référence locale | taille de la référence constituée | jalon 2 |
| Délai entre coupe et détection | prototype, AOI pilote | jalon 1 |
| Seuils en dB si le prétraitement n'est pas S1Tiling | mesure A contre B sur forêt stable (ADR 0001) | jalon 0 |

## Besoins en référentiels (pour l'`acquereur`)

- Paramètres de la section II de Mermoz et al. (2024), à relire à la source.
- Spécification du fichier SUFOSAT v3.0.1 (codage, valeurs absentes, grille, licence).
- Accès et licences : Copernicus Data Space (Sentinel-1), CLMS (TCD 2018), NASA Earthdata
  (MOD10A1), EFFIS ; statut de S1Tiling pour 1C/1D ; orbites relatives de 1C/1D.
- Limites administratives des départements (pour la taille maximale d'AOI) : source à
  nommer (IGN Admin Express).
