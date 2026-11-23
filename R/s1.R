#' Rechercher les images Sentinel-1 corrigées du terrain (RTC)
#'
#' Interroge le catalogue STAC du Microsoft Planetary Computer (collection
#' `sentinel-1-rtc`, option B de l'ADR 0001) sur une emprise et une période,
#' et rend la liste des images utilisables par la méthode : capteurs actifs à
#' la date selon `parametres$capteurs` ([capteurs_a_la_date()]), polarisation
#' `parametres$polarisation`, regroupées par orbite relative.
#'
#' @section Règle des doublons : Une même acquisition (un passage d'un
#'   capteur sur une orbite relative, un jour) peut être découpée en plusieurs
#'   tranches (« slices ») qui se recouvrent, et une même tranche peut être
#'   publiée plusieurs fois (traitements successifs). La table rend :
#'   - **une seule ligne par tranche** : si deux items ont le même capteur, la
#'     même orbite relative et la même heure de début d'acquisition
#'     (`start_datetime`), seul celui au traitement le plus récent
#'     (`s1:processing_datetime`) est gardé ; un item sans date de
#'     traitement (les plus anciens du catalogue n'en ont pas) passe après
#'     ceux qui en ont une, puis l'ordre des identifiants départage ;
#'   - **plusieurs lignes par date et par orbite** quand l'emprise touche
#'     plusieurs tranches d'une même acquisition. Elles portent la même
#'     `serie` et la même `date` ; [s1_lire()] les assemble en **une seule
#'     couche** (la tranche la plus tôt d'abord, les suivantes comblent ses
#'     vides). Les piles rendues par [s1_lire()] n'ont donc jamais deux fois
#'     la même date pour une orbite.
#'
#'   La date est le jour **UTC** de `datetime` (milieu de l'acquisition) ; en
#'   France métropolitaine, les passages (vers 6 h et 18 h UTC) tombent le
#'   même jour en heure locale.
#'
#' @section Accès : Le catalogue se lit sans compte. La documentation de la
#'   collection dit qu'un compte Planetary Computer est requis pour obtenir les
#'   jetons de lecture (`msft:requires_account`) ; le 2026-11-22, l'API des
#'   jetons en a pourtant délivré un sans compte. Voir [s1_lire()].
#'
#' @param emprise Zone recherchée : un [terra::vect()] (`SpatVector`) ou un
#'   [terra::rast()] (`SpatRaster`, par exemple la grille d'une tuile) avec
#'   un système de coordonnées, ou un [terra::ext()] (`SpatExtent`, qui ne
#'   porte pas de système : il est lu en longitude et latitude WGS 84,
#'   degrés).
#' @param date_debut,date_fin Première et dernière dates incluses (`Date`,
#'   ou tout objet accepté par [as.Date()]).
#' @param parametres Un objet créé par [parametres_sufosat()] (réglages
#'   `capteurs` et `polarisation`).
#'
#' @return Un `data.frame`, une ligne par tranche d'image, trié par orbite
#'   relative, date puis heure, avec les colonnes :
#'   - `id` : identifiant de l'item STAC ;
#'   - `date` : date d'acquisition (`Date`, jour UTC) ;
#'   - `heure` : instant d'acquisition (`POSIXct`, UTC) ;
#'   - `capteur` : `"S1A"`, `"S1B"`, `"S1C"` ou `"S1D"` ;
#'   - `orbite` : orbite relative (entier) ;
#'   - `direction` : `"ascendante"` ou `"descendante"` ;
#'   - `serie` : nom de la série, lettre de la direction et orbite sur trois
#'     chiffres (`"A030"`, `"D008"`) : les noms des piles de [s1_lire()] ;
#'   - `url` : adresse (non signée) du fichier de la polarisation choisie.
#'
#'   L'attribut `"attribution"` porte le texte à reproduire avec toute sortie
#'   dérivée de ces images (`docs/referentiels/licences.md`, formule `[S1]`).
#'
#' @seealso [s1_lire()], [nemetonsar_detecter()].
#'
#' @examples
#' \dontrun{
#' # Un point des Landes de Gascogne, trois semaines de juin 2025.
#' pt <- terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326")
#' items <- s1_rechercher(pt, "2025-06-01", "2025-06-20")
#' items
#' attr(items, "attribution")
#' }
#'
#' @export
s1_rechercher <- function(emprise, date_debut, date_fin,
                          parametres = parametres_sufosat()) {
  exiger_rstac("s1_rechercher()")
  p <- valide_parametres(parametres)
  periode <- valide_periode(date_debut, date_fin)
  bbox <- emprise_vers_bbox(emprise)

  intervalle <- paste0(
    format(periode[1]), "T00:00:00Z/", format(periode[2]), "T23:59:59Z"
  )
  requete <- rstac::stac_search(
    rstac::stac(s1_url_stac),
    collections = s1_collection,
    bbox = bbox,
    datetime = intervalle,
    limit = 1000L
  )
  reponse <- rstac::post_request(requete)
  reponse <- rstac::items_fetch(reponse, progress = FALSE)

  table <- s1_table_items(reponse$features, periode[1], periode[2], p)
  attr(table, "attribution") <- s1_attribution(table$date)
  table
}

#' Lire les images Sentinel-1 RTC sur une grille
#'
#' Lit, pour chaque image rendue par [s1_rechercher()], la polarisation
#' choisie sur l'emprise de `grille` seulement (lecture partielle des
#' GeoTIFF optimisés pour le nuage), la rééchantillonne sur `grille` et
#' range les couches en une pile par orbite relative : l'entrée attendue par
#' [nemetonsar_detecter()].
#'
#' @section Signature des adresses : Les fichiers du Planetary Computer ne
#'   se lisent qu'avec un jeton SAS ajouté à l'adresse. Avec `signer = TRUE`
#'   (il faut `rstac`, comme pour [s1_rechercher()]), le jeton est demandé à
#'   l'API publique des jetons,
#'   `https://planetarycomputer.microsoft.com/api/sas/v1/token/sentinel-1-rtc`
#'   (champ `token` de la réponse JSON), et chaque tranche est signée **juste
#'   avant d'être ouverte**, pas une fois pour toute la lecture : une adresse
#'   signée garde le jeton du moment de la signature, et un jeton ne vaut que
#'   45 min (relevé le 2026-11-23), moins qu'une lecture longue. Le jeton en
#'   cours est gardé et partagé entre les processus de la session (fichier
#'   du dossier temporaire de la session) ; il est remplacé par un neuf quand
#'   il lui reste moins de 15 min. Si le stockage répond 403 pendant la
#'   lecture d'une tranche, elle est relue **une fois** avec un jeton neuf ;
#'   un second refus arrête la lecture sur une erreur (jeton refusé de façon
#'   durable). **Provisoire (mission 025)** : la marge de 15 min et la
#'   relecture unique. Repli sans `rstac` : signer soi-même les adresses
#'   (ajouter le jeton après un `?`), lire `"/vsicurl/<adresse signée>"` avec
#'   [terra::rast()] et passer ces adresses avec `signer = FALSE` (le jeton
#'   n'est alors pas renouvelé). Avec `signer = FALSE`, une adresse qui
#'   désigne un fichier local est lue telle quelle.
#'
#' @section Tranches d'une même acquisition : Quand l'emprise touche
#'   plusieurs tranches d'une même acquisition (même `serie`, même `date`),
#'   elles sont assemblées en une couche par [terra::cover()] : la tranche la
#'   plus tôt (`heure`) l'emporte là où elles se recouvrent, les suivantes ne
#'   comblent que ses vides. **Provisoire, non sourcé, gèle au jalon 2.**
#'
#' @section Unité : Les images RTC sont des gamma0 (γ0) corrigés du
#'   terrain, en **puissance linéaire** : la documentation de la collection
#'   (`sentinel-1-rtc`, « Methodology ») dit que le GRD est « converted to
#'   calibrated intensity », et chaque fichier déclare, pour sa bande,
#'   `SARPixelContent=intensity` et `Scale=linear` (relevé le 2026-11-22 sur
#'   une image de juin 2025 ; médiane de -14,2 dB sur 1 km² de pins des
#'   Landes). La fonction lit ces deux métadonnées pour chaque fichier :
#'   `Scale=db` est converti par `10^(x / 10)` ([db_vers_lineaire()]),
#'   `SARPixelContent=amplitude` par `x^2` ; toute autre valeur arrête la
#'   lecture. Un fichier sans ces métadonnées est lu comme γ0 linéaire en
#'   puissance (documentation de la collection), avec un avertissement. La
#'   valeur de non-donnée (-32768, déclarée dans les fichiers) devient `NA`.
#'
#' @section Rééchantillonnage : Méthode `"bilinear"` par défaut, sur les
#'   valeurs linéaires. **Provisoire, gèle au jalon 2** : ni M24 ni B18 ne
#'   la donnent pour ce cas (S1Tiling projette lui-même sur la grille MGRS) ;
#'   à mesurer contre l'option A (ADR 0001).
#'
#'   La reprojection est **exacte** : chaque cellule de `grille` reçoit la
#'   valeur interpolée au point exact où son centre tombe dans l'image
#'   ([terra::project()] avec `use_gdal = FALSE`), indépendamment des autres
#'   cellules. Une image lue sur une grille ou sur une bande de lignes de
#'   cette grille donne donc les mêmes valeurs au bit près, ce qui permet la
#'   lecture par bandes de [nemetonsar_run()]. Décision de Pascal du
#'   2026-11-22 (mission 022) : la reprojection de GDAL, utilisée
#'   auparavant, interpole les coordonnées (erreur tolérée de 0,125 pixel)
#'   et dépend du découpage de la grille. **Les valeurs changent donc par
#'   rapport aux versions antérieures pour les images d'une autre zone UTM
#'   que la grille** (mesuré sur l'orbite D008, UTM 31N, lue sur une tuile
#'   en UTM 30N : écart médian 0,9 %, jusqu'à 9 % du gamma0) ; elles ne
#'   changent pas pour les images de la même zone (simple
#'   rééchantillonnage). Coût mesuré : 0,70 s par million de pixels sur un
#'   fil, contre 0,22 s pour GDAL en multi-fil : le parallélisme vient des
#'   `flux`.
#'
#' @section Téléchargements en parallèle et fichiers : Chaque date d'une
#'   orbite (toutes ses tranches) est lue, reprojetée et écrite par un
#'   processus parmi `flux` ([parallel::mclapply()], fork ; en série là où
#'   le fork n'existe pas, sous Windows ; au plus 2 processus sous
#'   `R CMD check`, quand `_R_CHECK_LIMIT_CORES_` est posée). Chaque
#'   processus calcule sans le groupe de fils d'exécution de terra
#'   (`terra::terraOptions(parallel = FALSE)`, dans le processus enfant
#'   seulement) : avec terra 1.9, un enfant qui l'utilise après le fork
#'   attend sans fin (mission 023). Chaque date est écrite dans son
#'   fichier, `<dossier>/s1_<serie>/<AAAA-MM-JJ>.tif`, en réel 32 bits
#'   (`FLT4S`), compression DEFLATE avec prédicteur flottant
#'   (`PREDICTOR=3`), comme les fichiers RTC sources. La pile d'une orbite
#'   est faite de ces fichiers. **Provisoire, à mesurer** : `flux = 4`,
#'   DEFLATE et prédicteur 3 (mission 022).
#'
#' @param items Un `data.frame` rendu par [s1_rechercher()] (au moins les
#'   colonnes `date`, `heure`, `serie`, `url`).
#' @param grille Un `SpatRaster` modèle dans un système projeté en mètres
#'   (par exemple la tuile MGRS en UTM, 10 m) : étendue, résolution et
#'   système des piles rendues.
#' @param signer Signer les adresses par un jeton SAS du Planetary Computer
#'   (`TRUE`, il faut `rstac`) ou les lire telles quelles (`FALSE`).
#' @param methode Méthode de rééchantillonnage passée à [terra::project()].
#' @param dossier `NULL` (fichiers écrits dans un dossier temporaire de la
#'   session R) ou un dossier où écrire un fichier par date et par orbite,
#'   `s1_<serie>/<AAAA-MM-JJ>.tif` (fichiers existants écrasés).
#' @param flux Nombre de processus qui lisent les images en même temps
#'   (entier, au moins 1). Défaut 4, **provisoire**.
#'
#' @return Une liste :
#'   - `orbites` : liste nommée par `serie` de `SpatRaster`, une couche par
#'     date (nommée `"AAAA-MM-JJ"`), γ0 linéaire en puissance sur `grille` ;
#'   - `dates` : liste parallèle de vecteurs `Date` croissants, sans doublon ;
#'   - `attribution` : texte à reproduire avec toute sortie dérivée ;
#'   - `items` : les lignes de `items` lues.
#'
#'   `orbites` et `dates` se passent telles quelles à [nemetonsar_detecter()].
#'
#' @seealso [s1_rechercher()], [nemetonsar_detecter()].
#'
#' @examples
#' \dontrun{
#' pt <- terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326")
#' items <- s1_rechercher(pt, "2025-06-01", "2025-06-20")
#' centre <- terra::geom(terra::project(pt, "EPSG:32630"))[1, c("x", "y")]
#' grille <- terra::rast(
#'   xmin = centre[["x"]] - 500, xmax = centre[["x"]] + 500,
#'   ymin = centre[["y"]] - 500, ymax = centre[["y"]] + 500,
#'   resolution = 10, crs = "EPSG:32630"
#' )
#' s1 <- s1_lire(items, grille)
#' s1$dates
#' terra::plot(10 * log10(s1$orbites[[1]][[1]]))
#' }
#'
#' @export
s1_lire <- function(items, grille, signer = TRUE, methode = "bilinear",
                    dossier = NULL, flux = 4L) {
  colonnes <- c("date", "heure", "serie", "url")
  if (!is.data.frame(items) || !all(colonnes %in% names(items))) {
    stop("`items` doit \u00eatre un data.frame rendu par s1_rechercher() ",
         "(colonnes ", paste(colonnes, collapse = ", "), ").", call. = FALSE)
  }
  if (nrow(items) == 0L) {
    stop("`items` ne contient aucune image.", call. = FALSE)
  }
  if (!inherits(grille, "SpatRaster") || !nzchar(terra::crs(grille))) {
    stop("`grille` doit \u00eatre un SpatRaster avec un syst\u00e8me de coordonn\u00e9es.",
         call. = FALSE)
  }
  if (isTRUE(terra::is.lonlat(grille))) {
    stop("`grille` doit \u00eatre dans un syst\u00e8me projet\u00e9 en m\u00e8tres (par exemple UTM), pas en degr\u00e9s.",
         call. = FALSE)
  }
  if (!is.logical(signer) || length(signer) != 1L || is.na(signer)) {
    stop("`signer` doit valoir TRUE ou FALSE.", call. = FALSE)
  }
  if (!is.character(methode) || length(methode) != 1L || is.na(methode)) {
    stop("`methode` doit \u00eatre une m\u00e9thode de terra::project(), par exemple \"bilinear\".",
         call. = FALSE)
  }
  if (!is.null(dossier)) {
    if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier)) {
      stop("`dossier` doit \u00eatre NULL ou un chemin (cha\u00eene de caract\u00e8res).",
           call. = FALSE)
    }
  } else {
    dossier <- tempfile("nemetonsar_s1_")
  }
  if (!est_scalaire_num(flux) || !is.finite(flux) || flux < 1 || flux != round(flux)) {
    stop("`flux` doit \u00eatre un entier au moins \u00e9gal \u00e0 1.", call. = FALSE)
  }
  dir.create(dossier, showWarnings = FALSE, recursive = TRUE)

  items <- items[order(items$serie, items$date, items$heure), , drop = FALSE]
  rownames(items) <- NULL
  adresses <- as.character(items$url)
  jeton <- NULL
  if (signer) {
    exiger_rstac("s1_lire(signer = TRUE)")
    # Un jeton SAS par lecture de tranche, juste avant de l'ouvrir (voir
    # « Signature des adresses ») ; le premier est demandé ici, dans le
    # processus principal, avant les processus enfants.
    jeton <- s1_jetons(s1_fichier_jeton())
    jeton()
  }

  # Lecture distante : ne pas lister le dossier du fichier (inutile et lent
  # sur un stockage objet). Pas pour les fichiers locaux, dont GDAL doit
  # pouvoir lire les fichiers annexes (.aux.xml).
  if (signer || !all(file.exists(adresses))) {
    ancien <- terra::getGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN")
    terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
    on.exit(terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", ancien), add = TRUE)
  }

  # Une tâche par orbite et par date : ses tranches, son fichier.
  series <- unique(items$serie)
  taches <- list()
  for (s in series) {
    lignes <- which(items$serie == s)
    jours <- sort(unique(items$date[lignes]))
    dir.create(file.path(dossier, paste0("s1_", s)), showWarnings = FALSE)
    for (j in seq_along(jours)) {
      taches[[length(taches) + 1L]] <- list(
        serie = s, jour = jours[j],
        tranches = lignes[items$date[lignes] == jours[j]],
        fichier = file.path(dossier, paste0("s1_", s), paste0(format(jours[j]), ".tif"))
      )
    }
  }
  une_date <- function(t) {
    couche <- NULL
    sans <- 0L
    for (k in t$tranches) {
      lu <- s1_lire_tranche(adresses[k], grille, methode, jeton)
      sans <- sans + lu$sans_unite
      couche <- if (is.null(couche)) lu$raster else terra::cover(couche, lu$raster)
    }
    terra::writeRaster(couche, t$fichier, overwrite = TRUE, datatype = "FLT4S",
                       names = format(t$jour), gdal = s1_options_gtiff)
    sans
  }
  sans_par_tache <- s1_appliquer(taches, une_date, flux)
  sans_unite <- sum(sans_par_tache)

  orbites <- list()
  dates <- list()
  for (s in series) {
    t <- taches[vapply(taches, `[[`, character(1), "serie") == s]
    jours <- do.call(c, lapply(t, `[[`, "jour"))
    pile <- terra::rast(vapply(t, `[[`, character(1), "fichier"))
    names(pile) <- format(jours)
    orbites[[s]] <- pile
    dates[[s]] <- jours
  }
  avertir_sans_unite(sans_unite)

  list(
    orbites = orbites,
    dates = dates,
    attribution = s1_attribution(items$date),
    items = items
  )
}

# Constantes ----------------------------------------------------------------

s1_url_stac <- "https://planetarycomputer.microsoft.com/api/stac/v1"
# Fichiers locaux : DEFLATE et prédicteur flottant, comme les COG RTC
# (provisoire, mission 022).
s1_options_gtiff <- c("COMPRESS=DEFLATE", "PREDICTOR=3")
s1_collection <- "sentinel-1-rtc"

# Internes ------------------------------------------------------------------

rstac_disponible <- function() {
  requireNamespace("rstac", quietly = TRUE)
}

exiger_rstac <- function(appel) {
  if (!rstac_disponible()) {
    stop("Le paquet 'rstac' est n\u00e9cessaire pour ", appel, " : ",
         "install.packages(\"rstac\").", call. = FALSE)
  }
  invisible(TRUE)
}

valide_periode <- function(date_debut, date_fin) {
  lire <- function(x, nom) {
    d <- tryCatch(as.Date(x), error = function(e) as.Date(NA))
    if (length(d) != 1L || is.na(d)) {
      stop("`", nom, "` doit \u00eatre une date (par exemple \"2025-06-01\").", call. = FALSE)
    }
    d
  }
  debut <- lire(date_debut, "date_debut")
  fin <- lire(date_fin, "date_fin")
  if (debut > fin) {
    stop("`date_debut` doit \u00eatre ant\u00e9rieure ou \u00e9gale \u00e0 `date_fin`.", call. = FALSE)
  }
  c(debut, fin)
}

# Emprise -> c(xmin, ymin, xmax, ymax) en degrés WGS 84.
emprise_vers_bbox <- function(emprise) {
  if (inherits(emprise, "SpatExtent")) {
    e <- as.vector(emprise)
    if (any(!is.finite(e)) || e[["xmin"]] < -180 || e[["xmax"]] > 180 ||
        e[["ymin"]] < -90 || e[["ymax"]] > 90) {
      stop("Un SpatExtent `emprise` est lu en longitude et latitude (degr\u00e9s WGS 84) : ",
           "valeurs hors bornes. Donner un SpatVector avec son syst\u00e8me.", call. = FALSE)
    }
    return(unname(e[c("xmin", "ymin", "xmax", "ymax")]))
  }
  if (inherits(emprise, "SpatRaster")) {
    if (!nzchar(terra::crs(emprise))) {
      stop("`emprise` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
    }
    emprise <- terra::as.polygons(terra::ext(emprise), crs = terra::crs(emprise))
  }
  if (!inherits(emprise, "SpatVector")) {
    stop("`emprise` doit \u00eatre un SpatVector, un SpatRaster ou un SpatExtent (degr\u00e9s).",
         call. = FALSE)
  }
  if (!nzchar(terra::crs(emprise))) {
    stop("`emprise` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  if (nrow(emprise) == 0L) {
    stop("`emprise` est vide.", call. = FALSE)
  }
  if (!isTRUE(terra::is.lonlat(emprise))) {
    # Le rectangle de l'emprise, densifié pour que ses bords courbes en
    # degrés restent dans la boîte.
    e <- terra::ext(emprise)
    cote <- max(e$xmax - e$xmin, e$ymax - e$ymin)
    emprise <- terra::as.polygons(e, crs = terra::crs(emprise))
    if (cote > 0) {
      emprise <- terra::densify(emprise, cote / 50)
    }
    emprise <- terra::project(emprise, "EPSG:4326")
  }
  e <- as.vector(terra::ext(emprise))
  unname(e[c("xmin", "ymin", "xmax", "ymax")])
}

# Liste de features STAC (listes R) -> table des tranches à lire.
s1_table_items <- function(features, date_debut, date_fin, parametres) {
  p <- valide_parametres(parametres)
  asset <- tolower(p$polarisation)
  champ <- function(f, nom, defaut = NA) {
    v <- f$properties[[nom]]
    if (is.null(v) || length(v) == 0L) defaut else v[[1]]
  }
  # Les items les plus anciens du catalogue écrivent "2025-06-15 06:17:05",
  # les plus récents "2025-06-15T06:17:05.123Z" : on lit les deux.
  instant <- function(x) {
    x <- sub(" ", "T", substr(as.character(x), 1L, 19L), fixed = TRUE)
    as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  }
  n <- length(features)
  table <- data.frame(
    id = vapply(features, function(f) as.character(f$id), character(1)),
    heure = instant(vapply(features, function(f) as.character(champ(f, "datetime")), character(1))),
    capteur = capteur_stac(vapply(features, function(f) as.character(champ(f, "platform")), character(1))),
    orbite = vapply(features, function(f) as.integer(champ(f, "sat:relative_orbit")), integer(1)),
    direction = direction_stac(vapply(features, function(f) as.character(champ(f, "sat:orbit_state")), character(1))),
    url = vapply(features, function(f) {
      h <- f$assets[[asset]]$href
      if (is.null(h)) NA_character_ else as.character(h)
    }, character(1)),
    debut = vapply(features, function(f) as.character(champ(f, "start_datetime")), character(1)),
    traitement = instant(vapply(features, function(f) as.character(champ(f, "s1:processing_datetime")), character(1))),
    stringsAsFactors = FALSE
  )
  if (n == 0L) {
    table$heure <- as.POSIXct(character(0), tz = "UTC")
  }
  table$date <- as.Date(format(table$heure, "%Y-%m-%d", tz = "UTC"))

  garde <- !is.na(table$date) & table$date >= date_debut & table$date <= date_fin &
    !is.na(table$url) & !is.na(table$capteur) & !is.na(table$orbite) &
    !is.na(table$direction)
  table <- table[garde, , drop = FALSE]
  if (nrow(table) > 0L) {
    actifs <- capteurs_a_la_date(p, table$date)
    table <- table[mapply(`%in%`, table$capteur, actifs), , drop = FALSE]
  }

  # Une ligne par tranche : même capteur, orbite et début d'acquisition ->
  # le traitement le plus récent.
  # Sans s1:processing_datetime (items anciens), l'item passe après ceux qui
  # en ont une, puis l'ordre des identifiants départage.
  debut <- instant(table$debut)
  debut[is.na(debut)] <- table$heure[is.na(debut)]
  cle <- paste(table$capteur, table$orbite, format(debut, "%Y-%m-%dT%H:%M:%S", tz = "UTC"))
  ordre <- order(cle, -as.numeric(table$traitement), table$id, na.last = TRUE)
  table <- table[ordre, , drop = FALSE]
  table <- table[!duplicated(cle[ordre]), , drop = FALSE]

  table$serie <- paste0(ifelse(table$direction == "ascendante", "A", "D"),
                        sprintf("%03d", table$orbite))
  table <- table[order(table$orbite, table$date, table$heure, table$id), , drop = FALSE]
  table <- table[, c("id", "date", "heure", "capteur", "orbite", "direction",
                     "serie", "url")]
  rownames(table) <- NULL
  table
}

# "SENTINEL-1A", "sentinel-1c" -> "S1A", "S1C" ; NA si inconnu.
capteur_stac <- function(platform) {
  x <- toupper(platform)
  out <- sub("^SENTINEL-1([A-D])$", "S1\\1", x)
  out[is.na(x) | !grepl("^SENTINEL-1[A-D]$", x)] <- NA_character_
  out
}

direction_stac <- function(etat) {
  x <- tolower(etat)
  out <- rep(NA_character_, length(x))
  out[x %in% "ascending"] <- "ascendante"
  out[x %in% "descending"] <- "descendante"
  out
}

# Texte d'attribution (docs/referentiels/licences.md, formule [S1]).
s1_attribution <- function(dates) {
  annees <- sort(unique(format(as.Date(dates), "%Y")))
  annees <- annees[!is.na(annees)]
  periode <- if (length(annees) == 0L) {
    ""
  } else if (length(annees) == 1L) {
    paste0(" ", annees)
  } else {
    paste0(" ", annees[1], "-", annees[length(annees)])
  }
  paste0(
    "Contains modified Copernicus Sentinel data", periode, ". ",
    "Sentinel-1 RTC processed by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0."
  )
}

# Unité déclarée d'un fichier RTC, d'après ses métadonnées de bande.
s1_unite <- function(source) {
  info <- tryCatch(terra::describe(source), error = function(e) character(0))
  valeur <- function(cle) {
    l <- grep(paste0("^\\s*", cle, "="), info, value = TRUE)
    if (length(l) == 0L) NA_character_ else tolower(trimws(sub("^[^=]*=", "", l[1])))
  }
  list(contenu = valeur("SARPixelContent"), echelle = valeur("Scale"))
}

# Lit une tranche sur la grille ; rend list(raster, sans_unite).
s1_lire_un <- function(adresse, grille, methode) {
  source <- if (file.exists(adresse) || grepl("^/vsi", adresse)) adresse else paste0("/vsicurl/", adresse)
  r <- terra::rast(source)
  unite <- s1_unite(source)
  sans_unite <- as.integer(is.na(unite$contenu) && is.na(unite$echelle))

  vide <- terra::rast(grille, nlyrs = 1L)
  terra::values(vide) <- NA_real_
  # Emprise de la grille dans le système de l'image, avec deux pixels de
  # marge pour le rééchantillonnage.
  zone <- terra::project(terra::as.polygons(terra::ext(grille), crs = terra::crs(grille)),
                         terra::crs(r))
  zone <- terra::ext(zone) + 2 * max(terra::res(r))
  commun <- terra::intersect(terra::ext(r), zone)
  if (is.null(commun)) {
    return(list(raster = vide, sans_unite = sans_unite))
  }
  morceau <- terra::crop(r, commun, snap = "out")
  if (!is.na(unite$echelle) && unite$echelle %in% c("db", "decibel")) {
    morceau <- 10^(morceau / 10)
  } else if (!is.na(unite$echelle) && unite$echelle != "linear") {
    stop("Unit\u00e9 inconnue (Scale=", unite$echelle, ") : ", basename(sub("\\?.*$", "", adresse)), call. = FALSE)
  }
  if (!is.na(unite$contenu) && unite$contenu == "amplitude") {
    morceau <- morceau^2
  } else if (!is.na(unite$contenu) && !unite$contenu %in% c("intensity", "power")) {
    stop("Contenu inconnu (SARPixelContent=", unite$contenu, ") : ", basename(sub("\\?.*$", "", adresse)), call. = FALSE)
  }
  # Reprojection exacte, cellule par cellule (voir s1_lire(), « Rééchantillonnage »).
  sortie <- terra::project(morceau, grille, method = methode, use_gdal = FALSE)
  list(raster = sortie, sans_unite = sans_unite)
}

# Jetons SAS (mission 025) ------------------------------------------------------

# Un jeton SAS du Planetary Computer vaut 45 min (relevé le 2026-11-23 :
# `se` = heure de la demande + 45 min). Une adresse signée garde le jeton du
# moment de la signature : chaque tranche est donc signée juste avant d'être
# ouverte, avec un jeton à qui il reste au moins `s1_marge_jeton` secondes,
# et relue `s1_relectures_403` fois avec un jeton neuf si le stockage répond
# 403. Valeurs provisoires (mission 025).
s1_url_jeton <- "https://planetarycomputer.microsoft.com/api/sas/v1/token/sentinel-1-rtc"
s1_marge_jeton <- 15 * 60
s1_relectures_403 <- 1L

# Demande un jeton à l'API publique des jetons ; rend list(jeton, expiration).
s1_demander_jeton <- function(adresse = s1_url_jeton) {
  texte <- tryCatch({
    con <- url(adresse, open = "rb")
    on.exit(close(con))
    paste(readLines(con, warn = FALSE), collapse = "")
  }, error = function(e) {
    stop("Impossible d'obtenir un jeton SAS du Planetary Computer (", adresse, ") : ",
         conditionMessage(e), call. = FALSE)
  })
  s1_lire_reponse_jeton(texte)
}

# Réponse JSON de l'API des jetons -> list(jeton, expiration). Lecture par
# expressions régulières (pas de dépendance JSON) : les deux champs sont des
# chaînes sans guillemet ; le jeton peut porter des `&` échappés en &.
s1_lire_reponse_jeton <- function(texte) {
  champ <- function(nom) {
    m <- regmatches(texte, regexpr(paste0("\"", nom, "\"\\s*:\\s*\"[^\"]*\""), texte))
    if (length(m) == 0L) return(NA_character_)
    sub("\"$", "", sub(paste0("^\"", nom, "\"\\s*:\\s*\""), "", m))
  }
  jeton <- champ("token")
  jeton <- gsub("\\u0026", "&", jeton, fixed = TRUE)
  jeton <- gsub("\\/", "/", jeton, fixed = TRUE)
  expiration <- s1_instant_utc(champ("msft:expiry"))
  if (is.na(jeton) || !nzchar(jeton) || !grepl("sig=", jeton, fixed = TRUE) || is.na(expiration)) {
    stop("R\u00e9ponse inattendue de l'API des jetons SAS du Planetary Computer ",
         "(champs `token` et `msft:expiry` attendus).", call. = FALSE)
  }
  list(jeton = jeton, expiration = expiration)
}

s1_instant_utc <- function(x) {
  as.POSIXct(substr(as.character(x), 1L, 19L), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
}

# Fichier où les processus d'une session partagent le jeton en cours : un
# processus enfant qui en demande un neuf le laisse aux suivants.
s1_fichier_jeton <- function() {
  file.path(tempdir(), "nemetonsar_jeton_sas")
}

# Fournisseur de jetons : rend une fonction `jeton(refuse = NULL)`.
# Sans `refuse`, elle rend le plus récent des jetons connus (le sien, celui
# du `fichier`, que les autres processus ont pu renouveler) s'il lui reste
# au moins `marge` secondes, sinon un jeton demandé par `demander()`. Avec
# `refuse` (un jeton qui vient d'être refusé, 403), elle demande toujours un
# jeton neuf. Tout jeton demandé est écrit dans `fichier`.
s1_jetons <- function(fichier, demander = s1_demander_jeton, marge = s1_marge_jeton,
                      maintenant = Sys.time) {
  courant <- NULL
  reste <- function(j) as.numeric(difftime(j$expiration, maintenant(), units = "secs"))
  lire <- function() {
    l <- tryCatch(suppressWarnings(readLines(fichier, warn = FALSE)),
                  error = function(e) character(0))
    if (length(l) != 2L || !nzchar(l[2])) return(NULL)
    e <- s1_instant_utc(l[1])
    if (is.na(e)) NULL else list(jeton = l[2], expiration = e)
  }
  ecrire <- function(j) {
    # Écriture puis renommage : un autre processus ne lit jamais un fichier
    # à moitié écrit.
    tmp <- paste0(fichier, ".", Sys.getpid())
    ok <- tryCatch({
      writeLines(c(format(j$expiration, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), j$jeton), tmp)
      Sys.chmod(tmp, "0600")
      file.rename(tmp, fichier)
    }, error = function(e) FALSE, warning = function(w) FALSE)
    if (!isTRUE(ok)) unlink(tmp)
    invisible(ok)
  }
  function(refuse = NULL) {
    if (is.null(refuse)) {
      f <- lire()
      if (!is.null(f) && (is.null(courant) || f$expiration > courant$expiration)) {
        courant <<- f
      }
      if (!is.null(courant) && reste(courant) >= marge) return(courant$jeton)
    }
    j <- demander()
    ecrire(j)
    courant <<- j
    j$jeton
  }
}

s1_signer_adresse <- function(adresse, jeton) {
  paste0(adresse, if (grepl("?", adresse, fixed = TRUE)) "&" else "?", jeton)
}

# Le stockage a-t-il répondu 403 ? (messages de GDAL : « failed with
# response_code=403 » en cours de lecture, « HTTP response code: 403 » à
# l'ouverture).
s1_est_403 <- function(message) {
  grepl("response_code=403|HTTP response code: 403", message)
}

# Lit une tranche (s1_lire_un()). Avec un fournisseur de jetons `jeton`
# (s1_jetons()), signe l'adresse juste avant de l'ouvrir ; si le stockage
# répond 403 (erreur, ou avertissement de GDAL même sans erreur : les
# valeurs lues ne sont alors pas sûres), relit la tranche avec un jeton neuf,
# au plus `relectures` fois, puis s'arrête sur une erreur claire. Les
# avertissements d'un essai refusé sont écartés ; ceux de l'essai gardé
# sont rendus.
s1_lire_tranche <- function(adresse, grille, methode, jeton = NULL,
                            relectures = s1_relectures_403) {
  if (is.null(jeton)) {
    return(s1_lire_un(adresse, grille, methode))
  }
  refuse <- NULL
  for (essai in 0:relectures) {
    j <- jeton(refuse)
    avertissements <- list()
    vu_403 <- FALSE
    res <- withCallingHandlers(
      tryCatch(s1_lire_un(s1_signer_adresse(adresse, j), grille, methode),
               error = function(e) e),
      warning = function(w) {
        if (s1_est_403(conditionMessage(w))) vu_403 <<- TRUE
        avertissements[[length(avertissements) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    )
    erreur <- inherits(res, "error")
    if (erreur && s1_est_403(conditionMessage(res))) vu_403 <- TRUE
    if (!vu_403) {
      for (w in avertissements) warning(w)
      if (erreur) stop(res)
      return(res)
    }
    refuse <- j
  }
  stop("Lecture refus\u00e9e par le Planetary Computer (HTTP 403) malgr\u00e9 ",
       relectures, " jeton(s) SAS neuf(s) : ", basename(sub("\\?.*$", "", adresse)),
       ". Le jeton est refus\u00e9 de fa\u00e7on durable (acc\u00e8s retir\u00e9, ",
       "compte exig\u00e9 ?) : voir s1_lire(), \u00ab Signature des adresses \u00bb.",
       call. = FALSE)
}

# Avertissement des fichiers lus sans métadonnées d'unité (`n` fichiers).
avertir_sans_unite <- function(n) {
  if (n > 0L) {
    warning(n, " fichier(s) sans m\u00e9tadonn\u00e9es d'unit\u00e9 ",
            "(SARPixelContent, Scale) : lus comme gamma0 lin\u00e9aire en puissance ",
            "(documentation de la collection sentinel-1-rtc).", call. = FALSE)
  }
  invisible(n)
}

# Applique `f` à chaque tâche, en `flux` processus (fork, sans le groupe de
# fils de terra : enfant_sans_fils_terra(), R/detecter.R) si possible ; une
# erreur d'un processus arrête la lecture avec son message. Rend un vecteur
# d'entiers.
s1_appliquer <- function(taches, f, flux) {
  # Même règle que la passe 1 (nb_processus(), R/detecter.R) : au plus le
  # nombre de tâches, 2 sous R CMD check (`_R_CHECK_LIMIT_CORES_`), 1 sans
  # fork.
  n <- nb_processus(flux, length(taches))
  if (n > 1L) {
    res <- parallel::mclapply(taches, function(t) {
      enfant_sans_fils_terra()
      tryCatch(f(t), error = function(e) structure(conditionMessage(e), class = "s1_erreur"))
    }, mc.cores = n, mc.preschedule = FALSE)
    for (r in res) {
      if (inherits(r, "s1_erreur")) stop(unclass(r), call. = FALSE)
      if (inherits(r, "try-error")) stop(as.character(r), call. = FALSE)
    }
    return(vapply(res, as.integer, integer(1)))
  }
  vapply(taches, function(t) as.integer(f(t)), integer(1))
}
