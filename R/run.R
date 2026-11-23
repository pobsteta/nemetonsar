#' Carte des coupes rases d'une AOI sur une période, en une commande
#'
#' Enchaîne toute la méthode SUFOSAT sur une zone d'intérêt (AOI) et une
#' période : préparation de l'AOI et découpage en tuiles ([aoi_preparer()]),
#' puis, **par tuile** : recherche et lecture des images Sentinel-1
#' ([s1_rechercher()], [s1_lire()]), masque forêt ([masque_foret()] ou
#' [masque_foret_bdforet()]),
#' détection ([nemetonsar_detecter()], argument `foret`) ; enfin
#' assemblage des tuiles en Lambert-93, où la graine, la surface minimale et
#' la fermeture sont jugées sur les objets entiers, masque feu
#' ([masque_feu()]) et journal d'exécution.
#'
#' @section Déroulé par tuile :
#'   1. **Images.** Les images sont lues du 1er janvier de
#'      `parametres$annee_noyau` (ou de `date_debut` si elle est plus
#'      ancienne) jusqu'à `date_fin` : le noyau du filtre se calcule sur
#'      l'année `annee_noyau` ([s1_filter_multitemp()]) et `Mb` prend toutes
#'      les images antérieures (`xb = Inf`). Avec les défauts (noyau 2018),
#'      une période en 2025 lit donc toutes les images depuis 2018. Une
#'      orbite sans image de l'année du noyau est écartée (dit au journal).
#'      Les images sont lues **par bandes de lignes** de la tuile (voir
#'      « Lecture par bandes ») et effacées dès qu'elles ont servi : elles ne
#'      sont pas gardées d'une exécution à l'autre (décision du 2026-11-22).
#'   2. **Masque.** Le masque de la tuile est le masque forêt (TCD si
#'      `tcd` est donné, BD Forêt v2 de l'IGN si `bdforet` est donné, lue
#'      sur l'emprise de la tuile) **et** le morceau d'AOI de la tuile (cellules dont
#'      le centre est dans le morceau, [terra::rasterize()]). Il est passé à
#'      la détection de la tuile (option B : ratio et date à `NA` hors
#'      masque après la passe 1). Un objet est mesuré (0,1 ha, graine) sur
#'      sa partie dans l'AOI.
#'   3. **Détection.** [nemetonsar_detecter()] tourne une fois par passe,
#'      avec le seul masque forêt (toute la grille) et des paramètres
#'      **bruts** : les zones `ratio <= tp`, sans exiger de graine (seuil
#'      des graines porté à `tp`), sans surface minimale ni fermeture
#'      (`detection/brut/`, `passe_2019/brut/` : ratio en réel 64 bits,
#'      sans GeoPackage). La détection de la tuile (`detection/`,
#'      `passe_2019/`) en est tirée avec le masque de la tuile, par le même
#'      code que les passes 2 et 3 de [nemetonsar_detecter()] (graine,
#'      0,1 ha, fermeture) : mêmes résultats, aux pixels de forêt sans
#'      ratio près (voir l'assemblage). La carte finale, elle, est jugée
#'      après l'assemblage.
#'   4. **Correction 2019** (si `tcd` ou `bdforet` est donné, `correction_2019 = TRUE`,
#'      `annee_noyau` antérieure à 2019 et des images de 2019 lues) : une
#'      première détection, sur les images jusqu'au 31 décembre 2019 et les
#'      `xa` suivantes, avec le seul masque forêt ; ses pixels datés de 2019
#'      (codes `19xxx` de `dates.tif`) sont retirés de la forêt
#'      ([masque_foret()], [masque_foret_bdforet()], `detections_2019`) ; la détection principale
#'      tourne avec ce masque corrigé. On garde les objets de la première
#'      détection dont la date médiane est en 2019 et ceux de la détection
#'      principale dont elle ne l'est pas (M24 : la méthode est appliquée
#'      d'abord à 2019, puis aux années suivantes avec le masque mis à
#'      jour). **Provisoire : règle d'assemblage des deux détections non
#'      sourcée, gèle au jalon 2.**
#'   5. **Période.** Seuls sont gardés les objets dont la date médiane est
#'      dans `[date_debut, date_fin]`. Une coupe des `xa` dernières images
#'      n'a pas encore de ratio : elle n'est pas détectée (elle le sera en
#'      prolongeant la période).
#'
#' @section Lecture par bandes : Avec `hauteur_bande` (512 lignes par
#'   défaut, la hauteur des tuiles internes des COG RTC ; **provisoire, à
#'   mesurer**), la tuile est découpée en bandes de `hauteur_bande` lignes.
#'   Pour chaque bande : les images sont lues sur la bande bordée de
#'   `(fenetre_filtre - 1) / 2` lignes de chaque côté (le rayon du filtre,
#'   seule opération spatiale de la passe 1), la passe 1 (filtre, ratio,
#'   combinaison des orbites, masque forêt) est faite sur la bande, ses
#'   lignes centrales sont recollées dans le ratio et la date de la tuile,
#'   puis les images de la bande sont effacées. La segmentation brute
#'   (zones `ratio <= tp`) est faite ensuite une seule fois sur la tuile
#'   recollée. Le disque des images ne dépasse donc pas celui d'une bande
#'   (≈ 23 Go pour 512 lignes d'une tuile MGRS et 900 images, calcul de la
#'   mission 019), au prix d'un téléchargement plus lourd : les bandes ne
#'   tombent pas sur les tuiles internes des COG, qui sont relues par deux
#'   bandes voisines. S'y ajoutent, pour toute la tuile, le ratio (réel
#'   64 bits) et la date recollés, au plus 12 octets par cellule et par
#'   passe avant compression (≈ 1,45 Go par passe pour une tuile MGRS, deux
#'   passes avec la correction 2019 ; GeoTIFF compressé par `terra`, bien
#'   moins hors forêt), effacés en fin de tuile : `res$tuiles` donne les deux
#'   disques (`disque_images_mo`, `disque_max_mo`).
#'
#'   Les résultats sont **identiques au bit près** à ceux d'une lecture
#'   d'un seul tenant (`hauteur_bande = NULL`) : la reprojection des images
#'   est exacte, cellule par cellule ([s1_lire()]), et la passe 1 d'un pixel
#'   ne dépend que des pixels à moins du rayon du filtre. Avec le lecteur
#'   par défaut, la recherche STAC est faite une seule fois par tuile.
#'
#' @section Assemblage : Les sorties **brutes** de chaque tuile (UTM : zones
#'   `ratio <= tp`, ratio et date) et son masque forêt sont reprojetés au
#'   plus proche voisin sur une grille Lambert-93 (EPSG:2154, ADR 0003,
#'   **provisoire**) de même résolution, alignée sur les multiples de la
#'   résolution, qui couvre l'AOI. **Chaque pixel Lambert-93 est pris à une
#'   seule tuile : celle dont le morceau d'AOI, reprojeté, contient son
#'   centre** ([terra::rasterize()]) ; hors de l'AOI, aucun pixel (règle
#'   **provisoire**, mission 015). Aucun pixel n'est donc compté deux fois
#'   à la limite de deux tuiles.
#'
#'   Sur la carte assemblée, et non plus tuile par tuile, sont alors
#'   appliquées les règles de [nemetonsar_detecter()] : zones `ratio <= tp`
#'   (forêt de l'AOI), gardées si **l'objet entier** contient une graine
#'   (`ratio < ts`) et atteint `surface_min_ha`, puis fermeture (pixels
#'   hors forêt ou hors AOI neutres). Une coupe à cheval sur deux tuiles est
#'   ainsi **un seul objet**, gardée même si chaque partie fait moins de
#'   0,1 ha ou si sa graine est d'un seul côté. La correction 2019 (pixels
#'   datés de 2019 par la première détection retirés de la forêt de la
#'   détection principale) et le choix des objets (période ; objets de 2019
#'   pris de la première détection si toutes les tuiles l'ont faite) se
#'   font aussi sur la carte assemblée. Les objets gardés sont
#'   **réétiquetés** (composantes connexes, `parametres$connexite`) ; leur
#'   table (surface, date médiane, ratio moyen) suit les règles de
#'   [postprocess()].
#'
#'   **Limites** : un pixel de forêt sans ratio (images manquantes) n'est
#'   pas neutre pour la fermeture, contrairement à [nemetonsar_detecter()] ;
#'   le plus proche voisin peut, au
#'   pixel près, souder deux objets voisins ou couper un objet filiforme ;
#'   les surfaces sont celles de la grille Lambert-93 (nombre de pixels x
#'   100 m²).
#'
#' @section Masque feu : Appliqué aux objets assemblés : un objet dont la
#'   date médiane est de l'année `A` est rapproché des surfaces brûlées
#'   EFFIS des années `A` et `A - 1` (une coupe de récupération suit souvent
#'   le feu ; décision du 2026-11-22, **provisoire, non sourcé**), et retiré
#'   si sa part brûlée atteint `parametres$seuil_feu` ([masque_feu()]). Les
#'   identifiants des objets retirés ne sont pas réattribués (trous dans la
#'   numérotation, retrouvables au journal).
#'
#' @section Masque neige : **Non appliqué** (reporté le 2026-11-22 : MODIS en
#'   fin de vie, identifiants Earthdata). Le journal le dit.
#'
#' @section Sorties : Dans `dossier` (créé s'il manque ; les fichiers du même
#'   nom sont écrasés) :
#'   - `dates.tif` (`INT4S`, date en `YYDDD`), `ratio.tif` (`FLT4S`, dB),
#'     `objets.tif` (`INT4S`, identifiant), en Lambert-93 ;
#'   - `objets.gpkg` (couche `objets`) : un polygone par objet, colonnes de
#'     la table rendue ; pas écrit s'il n'y a aucun objet ;
#'   - `journal.txt` : journal d'exécution (texte UTF-8) : appel, AOI et
#'     tuiles, paramètres, images utilisées par tuile et par orbite,
#'     orbites écartées, masques, objets par étape, objets retirés par le
#'     feu, fichiers écrits, licences et attributions de chaque entrée lue
#'     (`docs/referentiels/licences.md`), durée. Il est écrit même si le
#'     calcul s'arrête sur une erreur (statut « interrompu ») ;
#'   - `tuiles/<mgrs>/` : par tuile, sur sa grille UTM (celle des fichiers
#'     SUFOSAT publiés) : `masque.tif` (1 forêt dans
#'     l'AOI, 0 sinon, `NA` sans donnée TCD), `foret.tif` (1 forêt, 0
#'     sinon, sur toute la grille), `detection/` (détection de la tuile,
#'     comme [nemetonsar_detecter()] ; `detection/brut/` : zones brutes,
#'     ratio en `FLT8S`, entrée de l'assemblage), `passe_2019/` (première détection, si
#'     faite, et `passe_2019/brut/`), et `dates.tif`, `ratio.tif`,
#'     `objets.tif` des objets gardés de la tuile (jugés dans la tuile : ils
#'     peuvent différer de la carte finale à la limite de deux tuiles).
#'
#'   Les images lues (`tuiles/<mgrs>/s1/`) et les fichiers des bandes sont
#'   effacés après usage, même sur erreur. Rien n'est écrit hors de
#'   `dossier`, sauf les fichiers temporaires de `terra`.
#'
#' @param aoi L'AOI : chemin d'un fichier vecteur ou `SpatVector` de
#'   polygones (voir [aoi_preparer()]).
#' @param date_debut,date_fin Première et dernière dates de la période
#'   (`Date` ou texte `"AAAA-MM-JJ"`), incluses.
#' @param dossier Dossier de sortie.
#' @param tcd `NULL` (pas de masque forêt : **toute l'AOI est traitée comme
#'   forêt**, dit au journal), ou le Tree Cover Density 2018 : chemin d'un
#'   raster ou `SpatRaster` (voir [masque_foret()]). Exclusif avec
#'   `bdforet`.
#' @param bdforet `NULL` (défaut), ou la BD Forêt v2 de l'IGN comme masque
#'   forêt (décision du 2026-11-22, à la place du TCD de M24) : chemin d'un
#'   fichier vecteur, `SpatVector` de polygones, ou `"wfs"` pour lire le
#'   service WFS de la Géoplateforme tuile par tuile, sur l'emprise de
#'   chaque tuile (voir [masque_foret_bdforet()], codes TFV par défaut).
#'   Exclusif avec `tcd`.
#' @param effis `NULL` (pas de masque feu, dit au journal), ou les surfaces
#'   brûlées EFFIS : chemin d'un fichier vecteur ou `SpatVector` de
#'   polygones, avec une colonne d'année (voir `effis_annee`).
#' @param parametres Un objet créé par [parametres_sufosat()].
#' @param effis_annee Nom de la colonne de `effis` qui donne l'année du feu :
#'   un entier (année), une `Date`, ou un texte qui commence par
#'   `"AAAA-MM-JJ"`. Défaut `"annee"`. **Provisoire** : le nom et le format
#'   des champs du fichier EFFIS ne sont pas relevés (à faire par
#'   l'acquereur).
#' @param correction_2019 Faire la correction 2019 du masque forêt (voir le
#'   déroulé). Défaut `TRUE`.
#' @param lignes_par_bloc Passé à [nemetonsar_detecter()] ; sert aussi à
#'   l'assemblage (`NULL` : environ 2,5e7 cellules par bloc).
#' @param lire_images `NULL` (défaut : [s1_rechercher()] sur la grille de
#'   la tuile, une fois, puis [s1_lire()] sur la grille de chaque bande), ou
#'   une fonction `function(grille, date_debut, date_fin, parametres,
#'   dossier)` qui rend une liste comme [s1_lire()] (`orbites`, `dates`,
#'   `attribution`, `items` avec au moins les colonnes `id`, `date`,
#'   `serie`), avec des piles **sur `grille`** : la tuile entière, ou une
#'   bande de lignes de la tuile (toute sa largeur). Pour une même tuile,
#'   elle doit rendre les mêmes orbites et les mêmes dates à chaque bande,
#'   et la valeur d'un pixel ne doit pas dépendre de la bande lue. Ce
#'   qu'elle écrit dans `dossier` est effacé après la bande. Sert aux
#'   tests et à des images déjà téléchargées.
#' @param hauteur_bande Hauteur des bandes de lecture, en lignes de la
#'   tuile (entier, défaut 512, **provisoire**), ou `NULL` pour lire chaque
#'   tuile d'un seul tenant (disque des images d'une tuile entière). Voir
#'   « Lecture par bandes ».
#' @param flux Nombre de processus qui lisent les images en même temps
#'   (passé à [s1_lire()] par le lecteur par défaut). Défaut 4,
#'   **provisoire**.
#' @param processus Nombre de processus de la passe 1 de la détection
#'   (passé à [nemetonsar_detecter()] ; voir sa section « Parallélisme »).
#'   `NULL` (défaut) : un processus par orbite, au plus le nombre de cœurs
#'   moins 1 ; `1` : calcul en série. Le résultat ne dépend pas de ce
#'   réglage.
#'
#' @return (invisible) Une liste : `fichiers` (chemins écrits, nommés),
#'   `objets` (table des objets gardés : `identifiant`, `nb_pixels`,
#'   `surface_ha`, `nb_pixels_dates`, `date_mediane` en `YYDDD`,
#'   `date_mediane_date`, `ratio_moyen_db`, et `part_brulee` si `effis` est
#'   donné), `tuiles` (une ligne par tuile : images, orbites, objets par
#'   étape, nombre de bandes `nb_bandes`, disque maximal des images d'une
#'   bande `disque_images_mo` et disque maximal de tous les fichiers
#'   temporaires de la tuile `disque_max_mo` (images, plus, par bandes, le
#'   ratio en réel 64 bits et la date de la tuile entière recollés pour
#'   chaque passe, au plus 12 octets par cellule et par passe, et les
#'   sorties d'une bande), en Mo ; sans les fichiers internes de
#'   [nemetonsar_detecter()]), `feu` (table de [masque_feu()], ou `NULL`), `journal` (chemin
#'   du journal).
#'
#' @seealso [aoi_preparer()], [s1_rechercher()], [s1_lire()],
#'   [masque_foret()], [masque_foret_bdforet()], [nemetonsar_detecter()],
#'   [masque_feu()].
#'
#' @examples
#' \dontrun{
#' # Un carré de 2 km x 2 km dans les Landes, premier semestre 2025 ; noyau
#' # du filtre sur 2024 pour ne pas lire les images depuis 2018.
#' centre <- terra::project(terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326"),
#'                          "EPSG:2154")
#' aoi <- terra::buffer(centre, 1000, capstyle = "square")
#' res <- nemetonsar_run(aoi, "2025-01-01", "2025-06-30",
#'                       dossier = file.path(tempdir(), "landes"),
#'                       parametres = parametres_sufosat(annee_noyau = 2024))
#' res$objets
#' cat(readLines(res$journal), sep = "\n")
#' }
#'
#' @export
nemetonsar_run <- function(aoi, date_debut, date_fin, dossier,
                           tcd = NULL, effis = NULL,
                           parametres = parametres_sufosat(),
                           effis_annee = "annee",
                           correction_2019 = TRUE,
                           lignes_par_bloc = NULL,
                           lire_images = NULL,
                           bdforet = NULL,
                           hauteur_bande = 512L,
                           flux = 4L,
                           processus = NULL) {
  debut_calcul <- Sys.time()
  p <- valide_parametres(parametres)
  periode <- valide_periode(date_debut, date_fin)
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier)) {
    stop("`dossier` doit \u00eatre un chemin (cha\u00eene de caract\u00e8res).", call. = FALSE)
  }
  if (!is.logical(correction_2019) || length(correction_2019) != 1L || is.na(correction_2019)) {
    stop("`correction_2019` doit valoir TRUE ou FALSE.", call. = FALSE)
  }
  source_tcd <- NA_character_
  if (!is.null(tcd)) {
    if (is.character(tcd) && length(tcd) == 1L && !is.na(tcd)) {
      source_tcd <- tcd
      tcd <- terra::rast(tcd)
    } else {
      source_tcd <- "SpatRaster fourni"
      if (inherits(tcd, "SpatRaster") && any(nzchar(terra::sources(tcd)))) {
        source_tcd <- paste(terra::sources(tcd), collapse = ", ")
      }
    }
    valide_raster_une_couche(tcd, "tcd")
  }
  source_bdforet <- NA_character_
  if (!is.null(bdforet)) {
    if (!is.null(tcd)) {
      stop("`tcd` et `bdforet` sont exclusifs : donner un seul masque for\u00eat.", call. = FALSE)
    }
    if (is.character(bdforet) && length(bdforet) == 1L && !is.na(bdforet)) {
      if (identical(tolower(bdforet), "wfs") && !file.exists(bdforet)) {
        bdforet <- "wfs"
        source_bdforet <- paste0("service WFS de la G\u00e9oplateforme (", .bdforet_wfs_url,
                                 ", couche ", .bdforet_wfs_couche, "), lu tuile par tuile le ",
                                 format(Sys.Date()))
      } else if (file.exists(bdforet)) {
        source_bdforet <- bdforet
      } else {
        stop("`bdforet` : fichier introuvable : ", bdforet, call. = FALSE)
      }
    } else if (inherits(bdforet, "SpatVector")) {
      if (nrow(bdforet) > 0L && terra::geomtype(bdforet) != "polygons") {
        stop("`bdforet` doit contenir des polygones.", call. = FALSE)
      }
      if (!nzchar(terra::crs(bdforet))) {
        stop("`bdforet` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
      }
      source_bdforet <- "SpatVector fourni"
    } else {
      stop("`bdforet` doit \u00eatre NULL, \"wfs\", un chemin ou un SpatVector de polygones.",
           call. = FALSE)
    }
  }
  source_effis <- NA_character_
  if (!is.null(effis)) {
    if (is.character(effis) && length(effis) == 1L && !is.na(effis)) {
      source_effis <- effis
      effis <- terra::vect(effis)
    } else {
      source_effis <- "SpatVector fourni"
    }
    effis <- valide_effis(effis, effis_annee)
  }
  if (!is.null(hauteur_bande) &&
      (!est_scalaire_num(hauteur_bande) || !is.finite(hauteur_bande) || hauteur_bande < 1 ||
       hauteur_bande != round(hauteur_bande))) {
    stop("`hauteur_bande` doit \u00eatre NULL ou un entier au moins \u00e9gal \u00e0 1.", call. = FALSE)
  }
  if (!est_scalaire_num(flux) || !is.finite(flux) || flux < 1 || flux != round(flux)) {
    stop("`flux` doit \u00eatre un entier au moins \u00e9gal \u00e0 1.", call. = FALSE)
  }
  # Même règle que nemetonsar_detecter() (nb_processus()), vérifiée avant
  # tout calcul.
  nb_processus(processus, 1L)
  if (is.null(lire_images)) {
    source_images <- paste0("s1_rechercher() + s1_lire() (STAC sentinel-1-rtc, Microsoft Planetary Computer), ",
                            flux, " flux ; reprojection exacte (terra::project(use_gdal = FALSE), ",
                            "d\u00e9cision du 2026-11-22) : valeurs diff\u00e9rentes de la version GDAL ",
                            "ant\u00e9rieure pour les orbites d'une autre zone UTM que la tuile")
  } else {
    if (!is.function(lire_images)) {
      stop("`lire_images` doit \u00eatre NULL ou une fonction (voir la documentation).", call. = FALSE)
    }
    source_images <- "fonction `lire_images` fournie par l'appelant"
  }
  debut_images <- min(periode[1], as.Date(sprintf("%d-01-01", p$annee_noyau)))

  prep <- aoi_preparer(aoi, resolution_m = 10)
  dir.create(dossier, showWarnings = FALSE, recursive = TRUE)

  # Journal : écrit à la sortie, même sur erreur.
  j <- new.env()
  j$lignes <- character(0)
  j$statut <- "interrompu (erreur)"
  ecrire <- function(...) j$lignes <- c(j$lignes, paste0(...))
  fichier_journal <- file.path(dossier, "journal.txt")
  on.exit({
    duree <- as.numeric(difftime(Sys.time(), debut_calcul, units = "secs"))
    tete <- c(
      "nemetonsar - journal d'ex\u00e9cution",
      paste0("Statut : ", j$statut),
      paste0("D\u00e9but : ", format(debut_calcul, "%Y-%m-%d %H:%M:%S %Z")),
      paste0("Fin : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
      paste0("Dur\u00e9e : ", format(round(duree, 1), nsmall = 1), " s"),
      ""
    )
    # Octets UTF-8 écrits tels quels : les chaînes "\u00e9" du package sont
    # déjà en UTF-8 (en locale C, R ne les marque pas : ne pas les convertir).
    lignes <- c(tete, j$lignes)
    if (!isTRUE(l10n_info()[["UTF-8"]]) && !Sys.getlocale("LC_CTYPE") %in% c("C", "POSIX")) {
      lignes <- enc2utf8(lignes)
    }
    con <- file(fichier_journal, open = "wb")
    writeLines(lignes, con, useBytes = TRUE)
    close(con)
  }, add = TRUE)

  version_pkg <- tryCatch(as.character(getNamespaceVersion("nemetonsar")),
                          error = function(e) "inconnue")
  ecrire("## Appel")
  ecrire("nemetonsar ", version_pkg, " ; ", R.version.string, " ; terra ",
         as.character(getNamespaceVersion("terra")), " ; GDAL ", terra::gdal())
  ecrire("P\u00e9riode : ", format(periode[1]), " au ", format(periode[2]), " (incluses)")
  ecrire("Images lues du ", format(debut_images), " au ", format(periode[2]),
         " (noyau du filtre : ann\u00e9e ", p$annee_noyau, " ; Mb : xb = ",
         texte_xb(p$xb), ")")
  ecrire("Source des images : ", source_images)
  ecrire("Lecture des images : ",
         if (is.null(hauteur_bande)) "d'un seul tenant par tuile" else
           paste0("par bandes de ", hauteur_bande, " lignes de la tuile (plus la bordure du filtre)"),
         " ; images effac\u00e9es apr\u00e8s usage (non gard\u00e9es d'une ex\u00e9cution \u00e0 l'autre)")
  ecrire("Passe 1 de la d\u00e9tection : ",
         if (is.null(processus)) "processus = NULL (un par orbite, au plus le nombre de c\u0153urs moins 1)"
         else paste0("processus = ", processus),
         " ; m\u00eame r\u00e9sultat qu'en s\u00e9rie")
  ecrire("Dossier : ", normalizePath(dossier))
  ecrire("")
  ecrire("## AOI")
  ecrire("Surface : ", format(round(prep$surface_km2, 3), nsmall = 3), " km2 ; ",
         nrow(prep$tuiles), " tuile(s) de calcul (MGRS, 10 m, UTM)")
  ecrire(capturer(prep$tuiles[, c("mgrs", "epsg", "xmin", "ymin", "xmax", "ymax",
                                 "ncol", "nrow", "surface_ha")], row.names = FALSE))
  ecrire("")
  ecrire("## Param\u00e8tres")
  ecrire(texte_parametres(p))
  ecrire("")
  ecrire("## Masques")
  ecrire("Masque neige : non appliqu\u00e9 (report\u00e9 le 2026-11-22 : MODIS en fin de vie, ",
         "identifiants Earthdata) ; images \u00e9cart\u00e9es pour neige : aucune.")
  if (!is.null(bdforet)) {
    ecrire("Masque for\u00eat : BD For\u00eat v2 de l'IGN (", source_bdforet, "), for\u00eat si le code TFV ",
           "est un des 30 postes du niveau I \u00ab For\u00eat \u00bb (FF..., FO..., FP ; LA4 et LA6 exclus) ; ",
           "cellule for\u00eat si son centre est dans un polygone forestier ; hors polygone = non-for\u00eat ; ",
           "appliqu\u00e9 au ratio et \u00e0 la date apr\u00e8s la passe 1 (option B). \u00c9cart \u00e0 M24 ",
           "(TCD 2018) : d\u00e9cision du 2026-11-22.")
    ecrire("Correction 2019 : ", if (correction_2019) "demand\u00e9e" else "non demand\u00e9e")
  } else if (is.null(tcd)) {
    ecrire("Masque for\u00eat : aucun (`tcd` et `bdforet` non fournis) : toute l'AOI est trait\u00e9e comme for\u00eat.")
  } else {
    ecrire("Masque for\u00eat : Tree Cover Density 2018 (", source_tcd, "), for\u00eat si couvert >= ",
           format(p$seuil_tcd), " % ; sans donn\u00e9e = non-for\u00eat ; appliqu\u00e9 au ratio et \u00e0 la date ",
           "apr\u00e8s la passe 1 (option B).")
    ecrire("Correction 2019 : ", if (correction_2019) "demand\u00e9e" else "non demand\u00e9e")
  }
  if (is.null(effis)) {
    ecrire("Masque feu : aucun (`effis` non fourni).")
  } else {
    ecrire("Masque feu : EFFIS (", source_effis, "), ", nrow(effis), " polygone(s), colonne d'ann\u00e9e `",
           effis_annee, "` ; objet retir\u00e9 si part br\u00fbl\u00e9e >= ", format(p$seuil_feu),
           " (surfaces de l'ann\u00e9e de sa date m\u00e9diane et de l'ann\u00e9e pr\u00e9c\u00e9dente).")
  }
  ecrire("")

  # Tuiles ---------------------------------------------------------------------
  resultats <- list()
  for (i in seq_len(nrow(prep$tuiles))) {
    tuile <- prep$tuiles[i, , drop = FALSE]
    resultats[[tuile$mgrs]] <- run_tuile(
      tuile, prep$aoi[[tuile$mgrs]], periode, debut_images, dossier, p,
      tcd, correction_2019, lignes_par_bloc, lire_images, ecrire, bdforet,
      hauteur_bande, flux, processus
    )
  }

  # Assemblage en Lambert-93, réétiquetage, feu --------------------------------
  ecrire("## Assemblage")
  assemblage <- run_assembler(resultats, prep, dossier, p, lignes_par_bloc, periode, ecrire)
  table <- assemblage$table
  ecrire("Grille : EPSG:2154 (Lambert-93, provisoire), ", terra::res(assemblage$modele)[1], " m, ",
         terra::ncol(assemblage$modele), " x ", terra::nrow(assemblage$modele),
         " pixels ; reprojection au plus proche voisin ; chaque pixel pris \u00e0 la seule tuile ",
         "dont le morceau d'AOI contient son centre")
  ecrire("Objets apr\u00e8s r\u00e9\u00e9tiquetage : ", nrow(table))

  feu <- NULL
  retires <- integer(0)
  if (!is.null(effis) && nrow(table) > 0L) {
    feu <- run_feu(assemblage$fichiers_tmp[["objets"]], table, effis, effis_annee, p)
    retires <- feu$identifiant[feu$retire]
    table$part_brulee <- feu$part_brulee[match(table$identifiant, feu$identifiant)]
    ecrire("Masque feu : ", length(retires), " objet(s) retir\u00e9(s)",
           if (length(retires) > 0L) paste0(" (identifiants ", paste(retires, collapse = ", "), ")") else "")
    if (length(retires) > 0L) {
      r <- feu[feu$retire, , drop = FALSE]
      ecrire(capturer(r, row.names = FALSE))
    }
  } else if (!is.null(effis)) {
    table$part_brulee <- numeric(0)
  }
  table <- table[!table$identifiant %in% retires, , drop = FALSE]
  rownames(table) <- NULL
  fichiers <- run_ecrire_sorties(assemblage, table, retires, dossier)
  ecrire("Objets finaux : ", nrow(table), " ; surface totale : ",
         format(round(sum(table$surface_ha), 2), nsmall = 2), " ha")
  ecrire("")

  # Sorties et licences ----------------------------------------------------------
  ecrire("## Sorties")
  for (n in names(fichiers)) ecrire(n, " : ", fichiers[[n]])
  ecrire("Par tuile (grille UTM des fichiers publi\u00e9s) : ", file.path(dossier, "tuiles"))
  ecrire("")
  ecrire("## Licences et attributions (docs/referentiels/licences.md)")
  attributions <- unique(unlist(lapply(resultats, `[[`, "attribution"), use.names = FALSE))
  attributions <- attributions[!is.na(attributions) & nzchar(attributions)]
  ecrire("Entr\u00e9e Sentinel-1 RTC (Planetary Computer, CC BY 4.0 ; donn\u00e9es Copernicus, avis l\u00e9gal Sentinel) :")
  if (length(attributions) == 0L) {
    ecrire("  [S1] aucune image lue")
  } else {
    for (a in attributions) ecrire("  [S1] ", a)
  }
  if (!is.null(tcd)) {
    ecrire("Entr\u00e9e Tree Cover Density 2018 (CLMS, politique de donn\u00e9es Copernicus) :")
    ecrire("  [FOR] ", attribution_tcd)
  }
  if (!is.null(bdforet)) {
    ecrire("Entr\u00e9e BD For\u00eat v2 (IGN, Licence Ouverte 2.0) :")
    ecrire("  [FOR] ", attribution_bdforet)
  }
  if (!is.null(effis)) {
    ecrire("Entr\u00e9e EFFIS, surfaces br\u00fbl\u00e9es (CC BY 4.0) :")
    ecrire("  [FEU] ", attribution_effis(p))
  }
  ecrire("Masque neige non appliqu\u00e9 : [NEI] sans objet.")
  ecrire("M\u00e9thode :")
  ecrire("  [MET] ", attribution_methode)
  ecrire("\u00c0 reproduire avec les rasters et le GeoPackage : [S1]",
         if (!is.null(tcd) || !is.null(bdforet)) " [FOR]" else "", if (!is.null(effis)) " [FEU]" else "",
         ". Aucune donn\u00e9e SUFOSAT v3.0.1 lue : pas de clause non commerciale h\u00e9rit\u00e9e (ADR 0002).")
  ecrire("")
  ecrire("## Valeurs provisoires")
  ecrire("Assemblage en Lambert-93 (ADR 0003), plus proche voisin, pixel attribu\u00e9 \u00e0 la tuile ",
         "dont le morceau d'AOI contient son centre ; r\u00e8gle de la correction 2019 ; ",
         "appariement EFFIS (ann\u00e9e et ann\u00e9e pr\u00e9c\u00e9dente) ; nom de la colonne d'ann\u00e9e EFFIS ; ",
         "masque for\u00eat apr\u00e8s la passe 1 ; ",
         if (!is.null(bdforet)) paste0("BD For\u00eat : rast\u00e9risation au centre des cellules, ",
                                       "postes FF0 et FO0 (sans couvert arbor\u00e9) compt\u00e9s for\u00eat ; ") else "",
         "hauteur des bandes de lecture, nombre de flux, compression DEFLATE + pr\u00e9dicteur 3 ",
         "des images lues ; ",
         "voir aussi les r\u00e9glages marqu\u00e9s provisoires de parametres_sufosat().")

  j$statut <- "termin\u00e9"
  tuiles <- do.call(rbind, lapply(resultats, `[[`, "resume"))
  rownames(tuiles) <- NULL
  invisible(list(
    fichiers = c(fichiers, journal = fichier_journal),
    objets = table,
    tuiles = tuiles,
    feu = feu,
    journal = fichier_journal
  ))
}

# Une tuile --------------------------------------------------------------------

# Lit les images (d'un seul tenant, ou par bandes de lignes si
# `hauteur_bande` est donné), prépare le masque, détecte (avec la correction
# 2019 si elle s'applique), garde les objets de la période ; écrit dans
# dossier/tuiles/<mgrs>/. Les images sont effacées après usage. Rend
# list(fichiers, resume, attribution, brut, foret, passe_2019).
run_tuile <- function(tuile, morceau, periode, debut_images, dossier, p, tcd,
                      correction_2019, lignes_par_bloc, lire_images, ecrire,
                      bdforet = NULL, hauteur_bande = NULL, flux = 4L,
                      processus = NULL) {
  mgrs <- tuile$mgrs
  dt <- file.path(dossier, "tuiles", mgrs)
  dir.create(dt, showWarnings = FALSE, recursive = TRUE)
  grille <- aoi_grille(tuile)
  ecrire("## Tuile ", mgrs, " (EPSG:", tuile$epsg, ", ", tuile$ncol, " x ", tuile$nrow, " pixels)")
  resume <- data.frame(mgrs = mgrs, nb_orbites = 0L, nb_images = 0L,
                       orbites_ecartees = 0L, passe_2019 = FALSE,
                       objets_2019 = NA_integer_, objets_detection = NA_integer_,
                       objets_gardes = 0L, nb_bandes = 0L, disque_images_mo = 0,
                       disque_max_mo = 0,
                       stringsAsFactors = FALSE)
  vide <- list(fichiers = NULL, resume = resume, attribution = NA_character_)

  # Images : jamais gardées au-delà de leur usage (décision du 2026-11-22).
  d_s1 <- file.path(dt, "s1")
  d_bandes <- file.path(dt, ".nemetonsar_tmp_bandes")
  on.exit(unlink(c(d_s1, d_bandes), recursive = TRUE), add = TRUE)
  lire <- if (is.null(lire_images)) lecteur_s1(grille, flux) else lire_images
  nl <- terra::nrow(grille)
  nc <- terra::ncol(grille)
  rf <- (p$fenetre_filtre - 1L) %/% 2L
  bandes <- NULL
  if (!is.null(hauteur_bande)) {
    h <- as.integer(min(hauteur_bande, nl))
    debuts <- seq(1L, nl, by = h)
    bandes <- data.frame(debut = debuts, n = pmin(h, nl - debuts + 1L))
  }
  taille_mo <- function(d) {
    f <- list.files(d, recursive = TRUE, full.names = TRUE, all.files = TRUE)
    sum(file.size(f), na.rm = TRUE) / 1e6
  }
  # Disque des fichiers temporaires de la tuile : images lues et, par
  # bandes, ratio et date recollés de la tuile et sorties d'une bande.
  noter_disque <- function() {
    resume$disque_max_mo <<- max(resume$disque_max_mo, taille_mo(d_s1) + taille_mo(d_bandes))
  }
  # Lit les images de la bande `b` (bordée de `rf` lignes) ou de la tuile.
  lire_images_bande <- function(b) {
    lu <- NULL
    g <- grille
    if (!is.null(bandes)) {
      lu <- bande_bordee(bandes$debut[b], bandes$n[b], rf, nl)
      g <- grille_lignes(grille, lu$debut, lu$n)
    }
    unlink(d_s1, recursive = TRUE)
    imgs <- lire(g, debut_images, periode[2], p, d_s1)
    if (!is.list(imgs) || !all(c("orbites", "dates") %in% names(imgs))) {
      stop("`lire_images` doit rendre une liste avec `orbites` et `dates` (comme s1_lire()).",
           call. = FALSE)
    }
    if (length(imgs$orbites) > 0L && is.null(names(imgs$orbites))) {
      names(imgs$orbites) <- paste0("orbite", seq_along(imgs$orbites))
    }
    names(imgs$dates) <- names(imgs$orbites)
    for (o in imgs$orbites) {
      if (!isTRUE(terra::compareGeom(o, g, stopOnError = FALSE))) {
        stop("`lire_images` doit rendre des piles sur la grille demand\u00e9e (celle de la tuile ",
             "ou de la bande).", call. = FALSE)
      }
    }
    resume$disque_images_mo <<- max(resume$disque_images_mo, taille_mo(d_s1))
    noter_disque()
    list(imgs = imgs, lu = lu, grille = g)
  }

  x1 <- lire_images_bande(1L)
  imgs <- x1$imgs
  attribution <- if (is.null(imgs$attribution)) NA_character_ else as.character(imgs$attribution)
  vide$attribution <- attribution
  orbites <- imgs$orbites
  dates <- imgs$dates
  items <- imgs$items

  # Orbites sans image de l'année du noyau : écartées.
  noyau <- vapply(dates, function(d) any(format(d, "%Y") == as.character(p$annee_noyau)),
                  logical(1))
  if (any(!noyau)) {
    ecrire("Orbite(s) \u00e9cart\u00e9e(s), sans image de l'ann\u00e9e du noyau (", p$annee_noyau, ") : ",
           paste(names(orbites)[!noyau], collapse = ", "))
  }
  resume$orbites_ecartees <- sum(!noyau)
  orbites <- orbites[noyau]
  dates <- dates[noyau]
  resume$nb_orbites <- length(orbites)
  resume$nb_images <- sum(lengths(dates))
  vide$resume <- resume

  ecrire("Images utilis\u00e9es : ", resume$nb_images, " sur ", length(orbites), " orbite(s)")
  for (s in names(orbites)) {
    d <- dates[[s]]
    ecrire("  ", s, " : ", length(d), " image(s), du ", format(min(d)), " au ", format(max(d)))
  }
  if (is.data.frame(items) && nrow(items) > 0L) {
    garde_items <- if ("serie" %in% names(items)) items$serie %in% names(orbites) else TRUE
    colonnes <- intersect(c("id", "date", "capteur", "orbite", "direction", "serie"), names(items))
    liste <- items[garde_items, colonnes, drop = FALSE]
    ecrire("  Liste des images (", nrow(liste), " tranche(s)) :")
    ecrire(paste0("    ", capturer(liste, row.names = FALSE)))
  }
  if (length(orbites) == 0L) {
    ecrire("Aucune image utilisable : tuile sans d\u00e9tection.")
    ecrire("")
    vide$resume$disque_images_mo <- resume$disque_images_mo
    vide$resume$disque_max_mo <- resume$disque_max_mo
    return(vide)
  }

  # Masque : forêt (TCD ou BD Forêt) et morceau d'AOI.
  modele <- if (is.null(bandes)) terra::rast(orbites[[1]], nlyrs = 1) else terra::rast(grille)
  dans_aoi <- terra::rasterize(morceau, modele, field = 1, background = 0, touches = FALSE) == 1
  masque_aoi <- function(foret) {
    m <- if (is.null(foret)) dans_aoi else foret & dans_aoi
    f <- file.path(dt, "masque.tif")
    terra::writeRaster(m, f, overwrite = TRUE, datatype = "INT1U", names = "masque")
    terra::rast(f)
  }
  foret0 <- if (is.null(tcd)) NULL else masque_foret(tcd, modele, p)
  if (!is.null(bdforet)) {
    foret0 <- masque_foret_bdforet(bdforet, modele)
    info <- attr(foret0, "bdforet")
    cod <- info$codes
    ecrire("Masque for\u00eat BD For\u00eat : ", info$nb_polygones, " polygone(s) lu(s) sur l'emprise",
           if (nrow(cod) > 0L) paste0(" ; codes TFV : ",
                                      paste0(ifelse(is.na(cod$code), "NA", cod$code), " (", cod$nb,
                                             ifelse(cod$foret, ", for\u00eat", ""), ")",
                                             collapse = ", ")) else "",
           " ; cellules for\u00eat : ", sum(terra::values(foret0, mat = FALSE) %in% TRUE),
           " sur ", terra::ncell(foret0))
  }
  a_foret <- !is.null(foret0)
  # Forêt de toute la grille (sans le morceau d'AOI), pour l'assemblage.
  f_foret <- file.path(dt, "foret.tif")
  terra::writeRaster(if (is.null(foret0)) terra::rast(modele, vals = 1L) else terra::ifel(is.na(foret0), 0L, foret0),
                     f_foret, overwrite = TRUE, datatype = "INT1U", names = "foret")
  pb <- parametres_bruts(p)

  passe_2019 <- a_foret && correction_2019 && p$annee_noyau < 2019L &&
    any(vapply(dates, function(d) any(format(d, "%Y") == "2019"), logical(1)))
  indices <- NULL
  dates_a <- NULL
  if (passe_2019) {
    fin19 <- as.Date("2019-12-31")
    indices <- lapply(dates, function(d) {
      apres <- which(d > fin19)[seq_len(p$xa)]
      sort(c(which(d <= fin19), apres[!is.na(apres)]))
    })
    dates_a <- Map(function(d, k) d[k], dates, indices)
  }
  sous_a <- function(orbs) Map(function(o, k) o[[k]], orbs, indices)

  # Détections brutes (passe 1, puis zones <= tp) : première détection (a)
  # et détection principale (b).
  brut_a <- NULL
  if (is.null(bandes)) {
    if (passe_2019) {
      brut_a <- detection_brute(sous_a(orbites), dates_a, file.path(dt, "passe_2019", "brut"), pb,
                                lignes_par_bloc, foret0, processus)
    }
    brut_b <- detection_brute(orbites, dates, file.path(dt, "detection", "brut"), pb,
                              lignes_par_bloc, foret0, processus)
    resume$nb_bandes <- 1L
    ecrire("Lecture d'un seul tenant ; disque des images : ",
           format(round(resume$disque_images_mo, 1), nsmall = 1), " Mo (effac\u00e9es ensuite)")
  } else {
    noms_1 <- names(imgs$orbites)
    dates_1 <- imgs$dates
    passes <- c(if (passe_2019) "a", "b")
    q <- parametres_tout_garder(pb)
    dir.create(d_bandes, showWarnings = FALSE, recursive = TRUE)
    brutes <- list()
    for (ps in passes) {
      f <- file.path(d_bandes, paste0("tuile_", ps, c("_ratio.tif", "_dates.tif")))
      brutes[[ps]] <- list(fichiers = f, ratio = ecrivain(modele, f[1], "FLT8S"),
                           dates = ecrivain(modele, f[2], "INT4S"))
    }
    for (b in seq_len(nrow(bandes))) {
      x <- if (b == 1L) x1 else lire_images_bande(b)
      if (b > 1L && (!identical(names(x$imgs$orbites), noms_1) ||
                     !identical(unname(x$imgs$dates), unname(dates_1)))) {
        stop("`lire_images` doit rendre les m\u00eames orbites et les m\u00eames dates pour chaque ",
             "bande de la tuile.", call. = FALSE)
      }
      orbs <- x$imgs$orbites[noyau]
      foret_b <- if (is.null(foret0)) NULL else terra::crop(foret0, terra::ext(x$grille))
      for (ps in passes) {
        db <- file.path(d_bandes, paste0("bande_", ps))
        r <- detecter_blocs(if (ps == "a") sous_a(orbs) else orbs,
                            if (ps == "a") dates_a else dates,
                            db, q, lignes_par_bloc, NULL, foret_b,
                            ecrire_objets = FALSE, type_ratio = "FLT8S",
                            processus = processus)
        for (champ in c("ratio", "dates")) {
          rr <- terra::rast(r$fichiers[[champ]])
          terra::readStart(rr)
          v <- terra::readValues(rr, row = x$lu$centre[1], nrows = bandes$n[b], col = 1,
                                 ncols = nc, mat = FALSE)
          terra::readStop(rr)
          terra::writeValues(brutes[[ps]][[champ]], v, bandes$debut[b], bandes$n[b])
        }
        noter_disque()
        unlink(db, recursive = TRUE)
      }
      rm(x, orbs, foret_b)
      if (b == 1L) {
        x1 <- NULL
        orbites <- NULL
        imgs <- NULL
      }
      unlink(d_s1, recursive = TRUE)
    }
    brut <- list()
    for (ps in passes) {
      terra::writeStop(brutes[[ps]]$ratio)
      terra::writeStop(brutes[[ps]]$dates)
    }
    noter_disque()
    for (ps in passes) {
      d_ps <- if (ps == "a") dates_a else dates
      # Taille de bloc de detecter_blocs() sur la tuile entière (le résultat
      # n'en dépend pas).
      lpb <- if (is.null(lignes_par_bloc)) {
        max(1L, as.integer(floor(2.5e8 / (8 * nc * max(lengths(d_ps))))))
      } else {
        lignes_par_bloc
      }
      res <- segmenter_blocs(terra::rast(brutes[[ps]]$fichiers[1]), terra::rast(brutes[[ps]]$fichiers[2]),
                             NULL, pb,
                             file.path(dt, if (ps == "a") "passe_2019" else "detection", "brut"),
                             lpb, gpkg = FALSE, type_ratio = "FLT8S")
      brut[[ps]] <- res$fichiers[c("dates", "ratio")]
    }
    brut_a <- brut$a
    brut_b <- brut$b
    resume$nb_bandes <- nrow(bandes)
    ecrire("Lecture par bandes : ", nrow(bandes), " bande(s) de ", bandes$n[1], " ligne(s) (bordure de ",
           rf, " ligne(s)) ; disque maximal des images d'une bande : ",
           format(round(resume$disque_images_mo, 1), nsmall = 1), " Mo (effac\u00e9es apr\u00e8s chaque bande) ; ",
           "disque maximal des fichiers temporaires de la tuile (images, ratio et date recoll\u00e9s, ",
           "sorties d'une bande) : ", format(round(resume$disque_max_mo, 1), nsmall = 1), " Mo")
  }
  unlink(d_s1, recursive = TRUE)
  if (is.null(lire_images)) avertir_sans_unite(environment(lire)$sans_unite)

  res_a <- NULL
  if (passe_2019) {
    m0 <- masque_aoi(foret0)
    res_a <- segmenter_blocs(terra::rast(brut_a[["ratio"]]), terra::rast(brut_a[["dates"]]), m0,
                             p, file.path(dt, "passe_2019"), lignes_par_bloc, gpkg = TRUE)
    d19 <- terra::rast(res_a$fichiers[["dates"]])
    det19 <- d19 >= 19000 & d19 <= 19999
    foret1 <- if (!is.null(tcd)) {
      masque_foret(tcd, modele, p, detections_2019 = det19)
    } else {
      corriger_2019(foret0, det19, modele) # même règle que masque_foret()
    }
    n19 <- sum(terra::values(det19, mat = FALSE) %in% TRUE)
    ecrire("Correction 2019 : premi\u00e8re d\u00e9tection sur ", sum(lengths(dates_a)),
           " image(s) (jusqu'au 2019-12-31 et ", p$xa, " suivantes), ", nrow(res_a$objets),
           " objet(s) ; ", n19, " pixel(s) dat\u00e9(s) de 2019 retir\u00e9(s) de la for\u00eat")
    resume$passe_2019 <- TRUE
    resume$objets_2019 <- nrow(res_a$objets)
  } else {
    foret1 <- foret0
    if (a_foret && correction_2019) {
      ecrire("Correction 2019 : non faite (aucune image de 2019 lue, ou noyau post\u00e9rieur \u00e0 2018).")
    }
  }
  m1 <- masque_aoi(foret1)
  res_b <- segmenter_blocs(terra::rast(brut_b[["ratio"]]), terra::rast(brut_b[["dates"]]), m1,
                           p, file.path(dt, "detection"), lignes_par_bloc, gpkg = TRUE)
  resume$objets_detection <- nrow(res_b$objets)

  # Objets gardés : date médiane dans la période ; 2019 de la première
  # détection, le reste de la détection principale.
  dans_periode <- function(tab) {
    d <- tab$date_mediane_date
    !is.na(d) & d >= periode[1] & d <= periode[2]
  }
  de_2019 <- function(tab) !is.na(tab$date_mediane) & tab$date_mediane %/% 1000L == 19L
  ids_b <- res_b$objets$identifiant[dans_periode(res_b$objets) &
                                      !(passe_2019 & de_2019(res_b$objets))]
  ids_a <- if (passe_2019) {
    res_a$objets$identifiant[dans_periode(res_a$objets) & de_2019(res_a$objets)]
  } else {
    integer(0)
  }
  ecrire("D\u00e9tection principale : ", nrow(res_b$objets), " objet(s) ; gard\u00e9s (date m\u00e9diane dans la p\u00e9riode",
         if (passe_2019) ", 2019 pris de la premi\u00e8re d\u00e9tection" else "", ") : ",
         length(ids_b) + length(ids_a))
  resume$objets_gardes <- length(ids_b) + length(ids_a)

  # Objets gardés, coupés au morceau d'AOI : la fermeture de
  # nemetonsar_detecter() peut étendre un objet d'un pixel dans les cellules
  # sans donnée (hors masque), donc hors de l'AOI, où la tuile voisine le
  # compterait aussi.
  garder <- function(res, ids, decalage) {
    if (length(ids) == 0L) return(NULL)
    o <- terra::subst(terra::rast(res$fichiers[["objets_raster"]]), from = ids,
                      to = ids + decalage, others = NA)
    o <- terra::mask(o, dans_aoi, maskvalues = FALSE)
    list(objets = o,
         dates = terra::mask(terra::rast(res$fichiers[["dates"]]), o),
         ratio = terra::mask(terra::rast(res$fichiers[["ratio"]]), o))
  }
  kb <- garder(res_b, ids_b, 0L)
  ka <- if (passe_2019) garder(res_a, ids_a, nrow(res_b$objets)) else NULL
  fichiers <- c(dates = file.path(dt, "dates.tif"), ratio = file.path(dt, "ratio.tif"),
                objets = file.path(dt, "objets.tif"))
  types <- c(dates = "INT4S", ratio = "FLT4S", objets = "INT4S")
  for (n in names(fichiers)) {
    r <- if (!is.null(kb) && !is.null(ka)) {
      terra::cover(kb[[n]], ka[[n]])
    } else if (!is.null(kb)) {
      kb[[n]]
    } else if (!is.null(ka)) {
      ka[[n]]
    } else {
      terra::rast(modele, vals = NA_real_)
    }
    terra::writeRaster(r, fichiers[[n]], overwrite = TRUE, datatype = types[[n]], names = n)
  }
  ecrire("")
  list(fichiers = fichiers, resume = resume, attribution = attribution,
       brut = list(a = brut_a, b = brut_b), foret = f_foret, passe_2019 = passe_2019)
}

# Détection brute d'une tuile : nemetonsar_detecter() (detecter_blocs())
# avec les paramètres de parametres_bruts() et le masque forêt de toute la
# grille (sans le morceau d'AOI), sans GeoPackage (pas de polygonisation),
# ratio écrit en réel 64 bits (`FLT8S`) : segmenter_blocs() le relit tel que
# la passe 1 l'a calculé. `processus` : voir nemetonsar_detecter(). Rend
# les chemins de `dates.tif` et `ratio.tif`.
detection_brute <- function(orbites, dates, dossier, pb, lignes_par_bloc, foret,
                            processus = NULL) {
  res <- detecter_blocs(orbites, dates, dossier, pb, lignes_par_bloc, NULL, foret,
                        ecrire_objets = FALSE, type_ratio = "FLT8S", processus = processus)
  res$fichiers[c("dates", "ratio")]
}

# Paramètres de la détection brute : la passe 1 de nemetonsar_detecter()
# (filtre, ratio, combinaison) est inchangée ; ses sorties gardent les zones
# <= tp, chacune comme sa propre graine, sans surface minimale ni
# fermeture. Seuil des graines = tp, seuil des zones relevé de 1e-9 en
# valeur relative (la règle ts < tp l'exige) : les pixels du ratio dans
# ]tp, tp (1 - 1e-9)] sont rendus aussi, et retirés par segmenter_blocs().
# Seule perte : une zone de la tuile dont aucun pixel n'est strictement
# sous tp (mesure nulle).
parametres_bruts <- function(p) {
  b <- p
  b$ts_db <- p$tp_db
  b$tp_db <- p$tp_db * (1 - 1e-9)
  b$surface_min_ha <- 0
  b$fermeture <- FALSE
  valide_parametres(b)
}

# Lecteur par défaut d'une tuile : recherche STAC une seule fois, sur la
# grille de la tuile, puis lecture sur la grille demandée (la tuile ou une
# de ses bandes).
# L'avertissement des fichiers sans métadonnées d'unité de s1_lire() est
# retenu (les mêmes fichiers reviennent à chaque bande) : son nombre est
# gardé dans `sans_unite`, et run_tuile() l'émet une fois par tuile.
lecteur_s1 <- function(grille_tuile, flux) {
  items <- NULL
  sans_unite <- 0L
  function(grille, date_debut, date_fin, parametres, dossier) {
    if (is.null(items)) {
      items <<- s1_rechercher(grille_tuile, date_debut, date_fin, parametres)
    }
    if (nrow(items) == 0L) {
      return(list(orbites = list(), dates = list(),
                  attribution = attr(items, "attribution"), items = items))
    }
    withCallingHandlers(
      s1_lire(items, grille, dossier = dossier, flux = flux),
      warning = function(w) {
        m <- conditionMessage(w)
        if (grepl("(SARPixelContent, Scale)", m, fixed = TRUE)) {
          sans_unite <<- max(sans_unite, suppressWarnings(as.integer(sub(" .*", "", m))), na.rm = TRUE)
          invokeRestart("muffleWarning")
        }
      }
    )
  }
}

# Grille des lignes [debut, debut + n - 1] de `grille`, toute sa largeur.
grille_lignes <- function(grille, debut, n) {
  r <- terra::yres(grille)
  haut <- terra::ymax(grille) - (debut - 1) * r
  terra::rast(nrows = n, ncols = terra::ncol(grille), xmin = terra::xmin(grille),
              xmax = terra::xmax(grille), ymin = haut - n * r, ymax = haut,
              crs = terra::crs(grille))
}

# Paramètres de la passe 1 d'une bande : ratio et date rendus pour tout
# pixel dont le ratio est <= au seuil des zones de `pb` (chacun est sa
# propre graine : seuil des graines porté entre les deux seuils de zones),
# sans surface minimale ni fermeture. La segmentation brute (pb) est ensuite
# faite une seule fois sur la tuile recollée : mêmes sorties que
# detection_brute() sur la tuile entière, même pour une zone dont la graine
# est dans une autre bande.
parametres_tout_garder <- function(pb) {
  q <- pb
  q$ts_db <- pb$tp_db / 2
  q$tp_db <- pb$tp_db / 4
  q$surface_min_ha <- 0
  q$fermeture <- FALSE
  valide_parametres(q)
}

# Assemblage -------------------------------------------------------------------

# Raster d'attribution `qui` : pour chaque pixel de `modele`, le rang (champ
# `tuile`) du morceau d'AOI qui contient son centre, NA ailleurs ; écrit en
# entier 32 bits (`INT4S`) dans `fichier`. Le type passe par `wopt` : terra
# (1.7 comme 1.9) n'applique pas un `datatype` passé à rasterize() hors de
# `wopt` (terra 1.9 l'ignore avec un avertissement).
run_rasteriser_qui <- function(morceaux, modele, fichier) {
  terra::rasterize(morceaux, modele, field = "tuile", touches = FALSE, filename = fichier,
                   overwrite = TRUE, wopt = list(datatype = "INT4S"))
  terra::rast(fichier)
}

# Assemble les sorties brutes des tuiles sur une grille Lambert-93, chaque
# pixel pris à une seule tuile (celle dont le morceau d'AOI contient son
# centre), puis y fait la segmentation, la surface minimale et la fermeture
# (segmenter_blocs()), la correction 2019 et la période, et réétiquette les
# objets gardés. Rend le modèle, les fichiers temporaires (dates, ratio,
# objets) et la table.
run_assembler <- function(resultats, prep, dossier, p, lignes_par_bloc, periode, ecrire) {
  l93 <- "EPSG:2154"
  r <- prep$tuiles$resolution_m[1]
  v <- prep$aoi_origine
  v <- terra::project(terra::densify(v, 100, flat = !isTRUE(terra::is.lonlat(v))), l93)
  e <- as.vector(terra::ext(v))
  modele <- terra::rast(xmin = floor(e[["xmin"]] / r) * r - r, xmax = ceiling(e[["xmax"]] / r) * r + r,
                        ymin = floor(e[["ymin"]] / r) * r - r, ymax = ceiling(e[["ymax"]] / r) * r + r,
                        resolution = r, crs = l93)
  noms <- c("qui", "foret", "donnee_a", "donnee_b", "a_ratio", "a_dates", "b_ratio", "b_dates",
            "presence", "dates", "ratio", "objets")
  tmp <- file.path(dossier, paste0(".nemetonsar_tmp_", noms, ".tif"))
  names(tmp) <- noms
  dossiers_seg <- file.path(dossier, paste0(".nemetonsar_tmp_seg_", c("a", "b")))
  gardes <- c("dates", "ratio", "objets")
  on.exit({
    unlink(tmp[!names(tmp) %in% gardes & file.exists(tmp)])
    unlink(dossiers_seg, recursive = TRUE)
  }, add = TRUE)

  # Attribution : la tuile dont le morceau d'AOI contient le centre du pixel.
  ordre <- match(names(resultats), prep$tuiles$mgrs)
  morceaux <- do.call(rbind, lapply(seq_along(ordre), function(k) {
    m <- terra::project(prep$aoi[[ordre[k]]], l93)
    terra::values(m) <- data.frame(tuile = k)
    m
  }))
  qui <- run_rasteriser_qui(morceaux, modele, tmp[["qui"]])

  # Une couche de chaque tuile, au plus proche voisin, sur ses seuls pixels.
  # Le ratio (`FLT8S`) reste en réel 64 bits, y compris dans les fichiers
  # temporaires de `terra` (dont le type par défaut est `FLT4S`).
  assembler <- function(fichiers, nom, type) {
    wopt <- if (type == "FLT8S") list(datatype = "FLT8S") else list()
    morceaux <- list()
    for (k in seq_along(fichiers)) {
      if (is.null(fichiers[[k]])) next
      ru <- terra::rast(fichiers[[k]])
      zone <- terra::project(terra::densify(terra::as.polygons(terra::ext(ru), crs = terra::crs(ru)),
                                            10 * r), l93)
      sous <- terra::crop(modele, terra::ext(zone), snap = "out")
      x <- terra::project(ru, sous, method = "near", wopt = wopt)
      morceaux[[length(morceaux) + 1L]] <- terra::ifel(terra::crop(qui, x) == k, x, NA,
                                                       wopt = wopt)
    }
    m <- if (length(morceaux) == 0L) {
      terra::rast(modele, vals = NA_real_)
    } else if (length(morceaux) == 1L) {
      morceaux[[1]]
    } else {
      terra::merge(terra::sprc(morceaux), wopt = wopt)
    }
    m <- terra::crop(terra::extend(m, modele, wopt = wopt), modele, wopt = wopt)
    terra::writeRaster(m, tmp[[nom]], overwrite = TRUE, datatype = type, names = nom)
    terra::rast(tmp[[nom]])
  }
  brut <- function(passe, champ) lapply(resultats, function(x) x$brut[[passe]][[champ]])
  foret <- assembler(lapply(resultats, `[[`, "foret"), "foret", "INT1U")
  avec_a <- vapply(resultats, function(x) !is.null(x$brut$a), logical(1))
  avec_b <- vapply(resultats, function(x) !is.null(x$brut$b), logical(1))
  donnee_a <- terra::writeRaster(!is.na(qui) & !is.na(foret) & foret == 1, tmp[["donnee_a"]],
                                 overwrite = TRUE, datatype = "INT1U", names = "donnee")

  dans_periode <- function(tab) {
    d <- tab$date_mediane_date
    !is.na(d) & d >= periode[1] & d <= periode[2]
  }
  de_2019 <- function(tab) !is.na(tab$date_mediane) & tab$date_mediane %/% 1000L == 19L
  res_a <- NULL
  donnee_b <- donnee_a
  if (any(avec_a)) {
    res_a <- segmenter_blocs(assembler(brut("a", "ratio"), "a_ratio", "FLT8S"),
                             assembler(brut("a", "dates"), "a_dates", "INT4S"),
                             donnee_a, p, dossiers_seg[1], lignes_par_bloc)
    # Correction 2019 sur la carte assemblée : pixels datés de 2019 par la
    # première détection retirés de la forêt de la détection principale.
    d19 <- terra::rast(res_a$fichiers[["dates"]])
    donnee_b <- terra::writeRaster(donnee_a == 1 & !(!is.na(d19) & d19 %/% 1000 == 19),
                                   tmp[["donnee_b"]], overwrite = TRUE, datatype = "INT1U",
                                   names = "donnee")
  }
  res_b <- NULL
  if (any(avec_b)) {
    res_b <- segmenter_blocs(assembler(brut("b", "ratio"), "b_ratio", "FLT8S"),
                             assembler(brut("b", "dates"), "b_dates", "INT4S"),
                             donnee_b, p, dossiers_seg[2], lignes_par_bloc)
  }
  # Objets gardés : date médiane dans la période ; ceux de 2019 pris de la
  # première détection si toutes les tuiles l'ont faite.
  tous_a <- any(avec_b) && all(avec_a[avec_b])
  ids_b <- if (is.null(res_b)) integer(0) else
    res_b$objets$identifiant[dans_periode(res_b$objets) & !(tous_a & de_2019(res_b$objets))]
  ids_a <- if (is.null(res_a)) integer(0) else
    res_a$objets$identifiant[dans_periode(res_a$objets) & de_2019(res_a$objets)]
  ecrire("Sur la carte assembl\u00e9e (zones <= tp, graine, surface minimale et fermeture jug\u00e9es sur l'objet entier) : ",
         if (!is.null(res_a)) paste0(nrow(res_a$objets), " objet(s) de la premi\u00e8re d\u00e9tection (", length(ids_a),
                                     " de 2019 gard\u00e9s), ") else "",
         if (is.null(res_b)) 0L else nrow(res_b$objets), " objet(s) de la d\u00e9tection principale (",
         length(ids_b), " gard\u00e9s)")
  garder <- function(res, ids, decalage) {
    if (length(ids) == 0L) return(NULL)
    o <- terra::subst(terra::rast(res$fichiers[["objets_raster"]]), from = ids,
                      to = ids + decalage, others = NA)
    list(presence = o,
         dates = terra::mask(terra::rast(res$fichiers[["dates"]]), o),
         ratio = terra::mask(terra::rast(res$fichiers[["ratio"]]), o))
  }
  kb <- if (is.null(res_b)) NULL else garder(res_b, ids_b, 0L)
  ka <- if (is.null(res_a)) NULL else garder(res_a, ids_a, nrow(res_b$objets))
  types <- c(presence = "INT4S", dates = "INT4S", ratio = "FLT4S")
  for (n in names(types)) {
    x <- if (!is.null(kb) && !is.null(ka)) {
      terra::cover(kb[[n]], ka[[n]])
    } else if (!is.null(kb)) {
      kb[[n]]
    } else if (!is.null(ka)) {
      ka[[n]]
    } else {
      terra::rast(modele, vals = NA_real_)
    }
    terra::writeRaster(x, tmp[[n]], overwrite = TRUE, datatype = types[[n]], names = n)
  }
  et <- reetiqueter_objets(terra::rast(tmp[["presence"]]), terra::rast(tmp[["dates"]]),
                           terra::rast(tmp[["ratio"]]), p$connexite, r, tmp[["objets"]],
                           lignes_par_bloc, dossier)
  list(modele = modele, fichiers_tmp = tmp[gardes], table = et$table)
}

# Composantes connexes de `presence` (non NA), étiquetées par blocs de
# lignes et fusionnées entre blocs comme dans nemetonsar_detecter(),
# numérotées par première cellule ; table des objets avec les règles de
# postprocess() (dates et ratios des pixels qui en ont). Écrit les
# identifiants dans `fichier`.
reetiqueter_objets <- function(presence, dates, ratio, connexite, resolution_m, fichier,
                               lignes_par_bloc, dossier) {
  nl <- terra::nrow(presence)
  nc <- terra::ncol(presence)
  if (is.null(lignes_par_bloc)) {
    lignes_par_bloc <- max(1L, as.integer(floor(2.5e7 / nc)))
  }
  lignes_par_bloc <- as.integer(min(lignes_par_bloc, nl))
  debuts <- seq(1L, nl, by = lignes_par_bloc)
  blocs <- data.frame(debut = debuts, n = pmin(lignes_par_bloc, nl - debuts + 1L))
  tmp_lab <- file.path(dossier, ".nemetonsar_tmp_etiquettes.tif")
  on.exit(unlink(tmp_lab), add = TRUE)
  modele <- terra::rast(presence, nlyrs = 1)
  ecr <- ecrivain(modele, tmp_lab, "INT4S")
  for (x in list(presence, dates, ratio)) terra::readStart(x)
  ob <- nouvelles_etiquettes()
  paires <- list()
  somme_lin <- list()
  for (b in seq_len(nrow(blocs))) {
    masque <- !is.na(lire_bande(presence, blocs$debut[b], blocs$n[b], nc))
    date <- lire_bande(dates, blocs$debut[b], blocs$n[b], nc)
    rat <- lire_bande(ratio, blocs$debut[b], blocs$n[b], nc)
    lab <- etiquette_bande(masque, connexite, ob, blocs$debut[b], nc)
    ob <- lab$etat
    l <- lab$matrice[masque]
    d <- date[masque]
    a_d <- !is.na(d)
    rl <- rle(sort(l[a_d] * 1e5 + d[a_d]))
    paires[[b]] <- list(cle = rl$values, n = rl$lengths)
    rr <- rat[masque]
    a_r <- !is.na(rr)
    somme_lin[[b]] <- list(lab = l[a_r], lin = db_vers_lineaire(rr[a_r]))
    terra::writeValues(ecr, as.vector(lab$matrice), blocs$debut[b], blocs$n[b])
  }
  for (x in list(presence, dates, ratio)) terra::readStop(x)
  terra::writeStop(ecr)
  racine <- racines_equivalences(ob$n, ob$a, ob$b)
  racines <- unique(racine[order(ob$premiere)])
  identifiant <- match(racine, racines)
  k <- length(racines)
  table <- table_objets_blocs(identifiant, k, ob$taille, resolution_m^2, paires, somme_lin)
  r_lab <- terra::rast(tmp_lab)
  ecr2 <- ecrivain(modele, fichier, "INT4S")
  terra::readStart(r_lab)
  for (b in seq_len(nrow(blocs))) {
    v <- terra::readValues(r_lab, row = blocs$debut[b], nrows = blocs$n[b],
                           col = 1, ncols = nc, mat = FALSE)
    a <- !is.na(v)
    v[a] <- identifiant[v[a]]
    terra::writeValues(ecr2, v, blocs$debut[b], blocs$n[b])
  }
  terra::readStop(r_lab)
  terra::writeStop(ecr2)
  list(table = table)
}

# Masque feu sur les objets assemblés, avec l'appariement des années : un
# objet de l'année A est rapproché des surfaces brûlées des années A et A-1.
run_feu <- function(fichier_objets, table, effis, effis_annee, p) {
  r_id <- terra::rast(fichier_objets)
  names(r_id) <- "identifiant"
  poly <- terra::as.polygons(r_id, dissolve = TRUE, values = TRUE, na.rm = TRUE)
  annee_objet <- 2000L + table$date_mediane[match(poly$identifiant, table$identifiant)] %/% 1000L
  annee_feu <- annee_effis(effis[[effis_annee]][[1]])
  sorties <- list()
  for (a in sort(unique(annee_objet[!is.na(annee_objet)]))) {
    sel <- which(annee_objet == a)
    brules <- effis[!is.na(annee_feu) & annee_feu %in% c(a, a - 1L), ]
    sorties[[length(sorties) + 1L]] <- masque_feu(poly[sel, "identifiant"], brules, p)$table
  }
  sans <- which(is.na(annee_objet))
  if (length(sans) > 0L) {
    sorties[[length(sorties) + 1L]] <- data.frame(
      identifiant = poly$identifiant[sans], surface_brulee_ha = 0, part_brulee = 0,
      retire = FALSE)
  }
  feu <- do.call(rbind, sorties)
  feu <- feu[order(feu$identifiant), , drop = FALSE]
  rownames(feu) <- NULL
  feu$annee_objet <- 2000L + table$date_mediane[match(feu$identifiant, table$identifiant)] %/% 1000L
  feu
}

# Écrit les sorties finales en Lambert-93 (objets retirés par le feu
# effacés) et le GeoPackage ; efface les fichiers temporaires.
run_ecrire_sorties <- function(assemblage, table, retires, dossier) {
  tmp <- assemblage$fichiers_tmp
  on.exit(unlink(tmp[file.exists(tmp)]), add = TRUE)
  fichiers <- c(dates = file.path(dossier, "dates.tif"), ratio = file.path(dossier, "ratio.tif"),
                objets_raster = file.path(dossier, "objets.tif"),
                objets = file.path(dossier, "objets.gpkg"))
  o <- terra::rast(tmp[["objets"]])
  if (length(retires) > 0L) {
    o <- terra::classify(o, cbind(retires, NA))
  }
  o <- terra::writeRaster(o, fichiers[["objets_raster"]], overwrite = TRUE, datatype = "INT4S",
                          names = "objets")
  terra::mask(terra::rast(tmp[["dates"]]), o, filename = fichiers[["dates"]], overwrite = TRUE,
              datatype = "INT4S", names = "dates")
  terra::mask(terra::rast(tmp[["ratio"]]), o, filename = fichiers[["ratio"]], overwrite = TRUE,
              datatype = "FLT4S", names = "ratio")
  if (nrow(table) > 0L) {
    r_id <- o
    names(r_id) <- "identifiant"
    poly <- terra::as.polygons(r_id, dissolve = TRUE, values = TRUE, na.rm = TRUE)
    attributs <- table
    attributs$date_mediane_date <- format(attributs$date_mediane_date, "%Y-%m-%d")
    attributs <- attributs[match(poly$identifiant, attributs$identifiant), , drop = FALSE]
    terra::values(poly) <- attributs
    poly <- poly[order(poly$identifiant), ]
    terra::writeVector(poly, fichiers[["objets"]], filetype = "GPKG", layer = "objets",
                       overwrite = TRUE)
  } else {
    if (file.exists(fichiers[["objets"]])) unlink(fichiers[["objets"]])
    fichiers <- fichiers[names(fichiers) != "objets"]
  }
  fichiers
}

# Texte imprimé par print(x), sans utils::capture.output().
capturer <- function(x, ...) {
  tc <- textConnection(NULL, "w")
  sink(tc)
  tryCatch(print(x, ...), finally = sink())
  out <- textConnectionValue(tc)
  close(tc)
  out
}

# Réglages, un par ligne (sans print(), dont la sortie dépend de la locale).
texte_parametres <- function(p) {
  valeur <- function(n) {
    x <- p[[n]]
    if (n == "capteurs") {
      return(paste(vapply(seq_along(x), function(i) {
        paste0(paste(x[[i]], collapse = "+"), " depuis le ", names(x)[i])
      }, character(1)), collapse = " ; "))
    }
    if (is.numeric(x) && is.infinite(x)) return("Inf")
    paste(format(x), collapse = ", ")
  }
  s <- seuils_db(p)
  c(paste0("  ", formatC(names(p), width = -20), ": ", vapply(names(p), valeur, character(1))),
    paste0("  ", formatC("ts, tp effectifs", width = -20), ": ", format(s[["ts"]]), " dB, ",
           format(s[["tp"]]), " dB"))
}

# EFFIS ------------------------------------------------------------------------

valide_effis <- function(effis, colonne) {
  if (!inherits(effis, "SpatVector") ||
      (nrow(effis) > 0L && terra::geomtype(effis) != "polygons")) {
    stop("`effis` doit \u00eatre NULL, un chemin de fichier vecteur ou un SpatVector de polygones.",
         call. = FALSE)
  }
  if (!nzchar(terra::crs(effis))) {
    stop("`effis` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  if (!is.character(colonne) || length(colonne) != 1L || !colonne %in% names(effis)) {
    stop("`effis` doit avoir la colonne d'ann\u00e9e `", colonne, "` (argument `effis_annee`).",
         call. = FALSE)
  }
  if (nrow(effis) > 0L && all(is.na(annee_effis(effis[[colonne]][[1]])))) {
    stop("La colonne `", colonne, "` de `effis` ne donne aucune ann\u00e9e lisible ",
         "(entier, Date, ou texte \"AAAA-MM-JJ\").", call. = FALSE)
  }
  effis
}

# Année d'une colonne EFFIS : entier, Date/POSIXct, ou texte "AAAA..." .
annee_effis <- function(x) {
  if (inherits(x, c("Date", "POSIXt"))) return(as.integer(format(x, "%Y")))
  if (is.numeric(x)) return(as.integer(x))
  x <- as.character(x)
  out <- rep(NA_integer_, length(x))
  ok <- !is.na(x) & grepl("^[0-9]{4}", x)
  out[ok] <- as.integer(substr(x[ok], 1L, 4L))
  out
}

# Attributions (docs/referentiels/licences.md) --------------------------------

attribution_tcd <- paste0(
  "Generated using European Union's Copernicus Land Monitoring Service information; ",
  "https://doi.org/10.2909/486f77da-d605-423e-93a9-680760ab6791 ",
  "(Tree Cover Density 2018, adapted)."
)

# BD Forêt v2 : Licence Ouverte 2.0 (fiche IGNF_BD-FORET de la
# Géoplateforme, lue le 2026-11-22) : mentionner la source (au moins le nom
# du concédant) et la date de dernière mise à jour ; ne pas suggérer d'aval.
# La date de mise à jour par département n'est pas lue ici : on reprend la
# période du titre de la couche WFS (« BD Forêt v2 (2006-2019) »).
attribution_bdforet <- paste0(
  "Source : IGN, BD For\u00eat\u00ae version 2.0 (2006-2019), Licence Ouverte 2.0 ; ",
  "https://cartes.gouv.fr/rechercher-une-donnee/dataset/IGNF_BD-FORET. ",
  "Donn\u00e9es modifi\u00e9es : codes TFV regroup\u00e9s en for\u00eat / non-for\u00eat, rast\u00e9ris\u00e9s sur la grille de calcul."
)

attribution_effis <- function(p) {
  paste0(
    "EFFIS, European Commission Joint Research Centre, licence CC BY 4.0 ",
    "(https://forest-fire.emergency.copernicus.eu/about-effis/data-license). ",
    "Donn\u00e9es modifi\u00e9es : seuil de ", format(100 * p$seuil_feu), " % de l'objet."
  )
}

attribution_methode <- paste0(
  "M\u00e9thode : Mermoz et al. (2024), IEEE JSTARS 17, 13743-13764, doi:10.1109/JSTARS.2024.3429012 ; ",
  "Bouvet et al. (2018), Remote Sensing 10(8), 1250, doi:10.3390/rs10081250."
)
