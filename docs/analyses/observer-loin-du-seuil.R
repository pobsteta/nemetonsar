# Mission 028 : observer ce que datent les pixels « loin du seuil »
# ---------------------------------------------------------------------------
# Script d'analyse reproductible, SANS modification du package. À lancer
# depuis la racine du dépôt (le package est chargé par pkgload pour lire la
# BD Forêt et convertir les codes YYDDD) :
#
#   Rscript docs/analyses/observer-loin-du-seuil.R <donnees> tirer
#   Rscript docs/analyses/observer-loin-du-seuil.R <donnees> vols
#   Rscript docs/analyses/observer-loin-du-seuil.R <donnees> s2 [limite_s] [processus]
#   Rscript docs/analyses/observer-loin-du-seuil.R <donnees> analyser
#   Rscript docs/analyses/observer-loin-du-seuil.R <donnees> orthos
#
#   <donnees> : dossier des données, HORS du dépôt (ici
#               /home/pascal/dev/nemetonsar-donnees). Entrées lues :
#               <donnees>/m026/{pixels_026.rds, pixels_traces.rds, sorties/dates.tif,
#               sorties/objets.tif} et <donnees>/sufosat_v301_dates_aoi.tif.
#               Sorties écrites dans <donnees>/m028/.
#
#   tirer    : tirage (graine fixée) de 20 pixels de la classe « loin du seuil »
#              (tardif_reste de 026), union avec les 14 pixels tracés par 026,
#              20 pixels témoins (forêt BD Forêt non datée par aucune carte),
#              et tous les pixels FO0 de l'AOI ; m028/points_028.rds.
#   vols     : dates de vol des orthophotos IGN (graphes de mosaïquage de la
#              Géoplateforme, WFS), au pixel ; m028/vols_028.rds.
#   s2       : Sentinel-2 L2A (Planetary Computer, STAC, tuile T30TXP), lecture
#              de SCL, B04, B08, B11 aux points, une scène par fichier dans
#              m028/s2/ (reprise possible). [limite_s] : durée maximale en
#              secondes avant arrêt propre (520 par défaut, le délai d'une
#              commande au premier plan est de 600 s) ; relancer jusqu'à
#              « toutes les scènes sont lues ».
#   analyser : séries NDVI, marches, comparaison aux dates des deux cartes et
#              aux dates de vol ; m028/analyse_028.rds, m028/figures/.
#   orthos   : vignettes d'orthophoto (WMS de la Géoplateforme) des pixels
#              tirés, hors dépôt, pour lecture à l'œil ; m028/orthos/.
#
# Graine du tirage : 20261124.
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : Rscript docs/analyses/observer-loin-du-seuil.R <donnees> tirer|vols|s2|analyser|orthos",
       call. = FALSE)
}
DONNEES <- normalizePath(args[1], mustWork = TRUE)
ETAPE <- args[2]
if (startsWith(DONNEES, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de données doit être hors du dépôt.", call. = FALSE)
}
M026 <- file.path(DONNEES, "m026")
M028 <- file.path(DONNEES, "m028")
V301 <- file.path(DONNEES, "sufosat_v301_dates_aoi.tif")
dir.create(M028, showWarnings = FALSE, recursive = TRUE)

GRAINE <- 20261124L
N_TIRES <- 20L
N_TEMOINS <- 20L
TUILE_S2 <- "30TXP"          # l'AOI (10 km x 10 km) est entièrement dans T30TXP
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2025-09-30")
NUAGES_MAX <- 90             # % de nuages de la scène entière ; provisoire
SCL_VALIDE <- c(4L, 5L)      # végétation, sol nu (SCL de Sen2Cor)

suppressMessages(pkgload::load_all(".", quiet = TRUE))
ns <- asNamespace("nemetonsar")
# Attention : `ns$bdforet_lire` et `ns$yyddd_vers_date` sont des fonctions INTERNES du package,
# lues par asNamespace() (non exportées pour bdforet_lire) ; leur signature peut changer.

# Étape 1 : tirage --------------------------------------------------------------------

if (ETAPE == "tirer") {
  tab <- readRDS(file.path(M026, "pixels_026.rds"))
  tr <- readRDS(file.path(M026, "pixels_traces.rds"))$pixels
  G <- terra::rast(file.path(M026, "sorties", "dates.tif"))
  OBJ <- terra::rast(file.path(M026, "sorties", "objets.tif"))
  vrec <- terra::values(G, mat = FALSE)
  vobj <- terra::values(OBJ, mat = FALSE)
  ref <- terra::project(terra::rast(V301), G, method = "near")
  vref <- terra::values(ref, mat = FALSE); vref[vref %in% 0] <- NA

  # 20 pixels de la classe « loin du seuil » (idx triés avant le tirage : reproductible)
  loin <- sort(tab$idx[tab$groupe == "tardif_reste" & tab$classe_026 == "loin_du_seuil_a_P"])
  set.seed(GRAINE)
  tires <- sort(sample(loin, N_TIRES))
  idx <- sort(union(tires, tr$idx))
  pts <- tab[match(idx, tab$idx), c("idx", "groupe", "classe_026", "pub", "date_carte", "tfv", "orbite_ret")]
  pts$source <- ifelse(idx %in% tires & idx %in% tr$idx, "tiré et tracé",
                       ifelse(idx %in% tires, "tiré", "tracé"))
  pts$role <- "etude"
  xy <- terra::xyFromCell(G, pts$idx); pts$x <- xy[, 1]; pts$y <- xy[, 2]

  # BD Forêt : poste (code_tfv) de chaque cellule de la grille de la carte
  lu <- ns$bdforet_lire("wfs", G)
  v <- lu$v
  champ <- names(v)[tolower(names(v)) == "code_tfv"]
  v$code <- trimws(as.character(v[[champ]][[1]]))
  codes <- sort(unique(v$code)); v$k <- match(v$code, codes)
  code_px <- codes[terra::values(terra::rasterize(v, G, field = "k", touches = FALSE), mat = FALSE)]

  # Témoins : forêt (poste FF*, hors FF0) qu'aucune des deux cartes ne date
  cand <- which(!is.na(code_px) & grepl("^FF", code_px) & code_px != "FF0" & is.na(vrec) & is.na(vref))
  cand <- sort(cand)
  set.seed(GRAINE + 1L)
  temo <- sort(sample(cand, N_TEMOINS))
  xt <- terra::xyFromCell(G, temo)
  pt_t <- data.frame(idx = temo, groupe = "temoin_sans_coupe", classe_026 = NA_character_,
                     pub = as.Date(NA), date_carte = as.Date(NA), tfv = code_px[temo],
                     orbite_ret = NA_character_, source = "témoin forêt non datée", role = "temoin",
                     x = xt[, 1], y = xt[, 2])

  # FO0 : toutes les cellules du poste, datées ou non par la carte recalculée
  fo0 <- which(code_px %in% "FO0")
  xf <- terra::xyFromCell(G, fo0)
  pt_f <- data.frame(idx = fo0, groupe = "FO0", classe_026 = NA_character_,
                     pub = ns$yyddd_vers_date(vref[fo0]), date_carte = ns$yyddd_vers_date(vrec[fo0]),
                     tfv = "FO0", orbite_ret = NA_character_, source = "FO0", role = "fo0",
                     x = xf[, 1], y = xf[, 2], objet = vobj[fo0])
  pts$objet <- NA_real_; pt_t$objet <- NA_real_
  pts <- rbind(pts, pt_t, pt_f)
  pts$id <- seq_len(nrow(pts))
  # Coordonnées UTM 30N (EPSG:32630), la grille de la tuile Sentinel-2 T30TXP
  u <- terra::crds(terra::project(terra::vect(cbind(pts$x, pts$y), crs = "EPSG:2154"), "EPSG:32630"))
  pts$xu <- u[, 1]; pts$yu <- u[, 2]
  saveRDS(list(points = pts, graine = GRAINE, tires = tires, n_loin = length(loin)),
          file.path(M028, "points_028.rds"))
  cat("Points :", nrow(pts), "\n"); print(table(pts$role, pts$source))
  cat("Classe « loin du seuil » dans le tirage :", sum(pts$idx[pts$role == "etude"] %in% loin), "\n")
  cat("FO0 : ", length(fo0), "cellules, dont datées par la carte recalculée :", sum(!is.na(pt_f$date_carte)),
      ", par la v3.0.1 :", sum(!is.na(pt_f$pub)), ", objets :",
      paste(sort(unique(pt_f$objet[!is.na(pt_f$date_carte)])), collapse = ","), "\n")
}

# Étape 2 : dates de vol des orthophotos IGN ---------------------------------------------

if (ETAPE == "vols") {
  suppressMessages({library(httr2); library(sf)})
  sf::sf_use_s2(FALSE)
  P <- readRDS(file.path(M028, "points_028.rds"))$points
  # Graphes de mosaïquage de la BD ORTHO : un polygone par vol (champ date_vol).
  # 2016-2020 : géométrie `geom` ; 2021-2023 : géométrie `st_snaptogrid`. Aucun
  # graphe n'est publié pour l'ortho PAC 2020, l'Ortho Express 2024 et l'ortho PAC 2025.
  couches <- c("2018" = "ORTHOIMAGERY.ORTHOPHOTOS.GRAPHE.2016-2020:graphe_bdortho",
               "2021" = "ORTHOIMAGERY.ORTHOPHOTOS.GRAPHE.2021-2023:graphe_bdortho")
  pt4326 <- sf::st_transform(sf::st_as_sf(P, coords = c("x", "y"), crs = 2154), 4326)
  e <- sf::st_bbox(sf::st_buffer(sf::st_as_sf(P, coords = c("x", "y"), crs = 2154), 50) |> sf::st_transform(4326))
  boite <- sf::st_transform(sf::st_buffer(sf::st_as_sf(P, coords = c("x", "y"), crs = 2154), 5,
                                           endCapStyle = "SQUARE"), 4326)
  res <- list()
  graphes <- list()
  for (an in names(couches)) {
    # BBOX WFS 2.0 avec l'URN de EPSG:4326 : ordre latitude, longitude
    r <- httr2::request("https://data.geopf.fr/wfs/ows") |>
      httr2::req_url_query(SERVICE = "WFS", VERSION = "2.0.0", REQUEST = "GetFeature",
                           TYPENAMES = couches[[an]], OUTPUTFORMAT = "application/json",
                           BBOX = sprintf("%.6f,%.6f,%.6f,%.6f,urn:ogc:def:crs:EPSG::4326",
                                          e[["ymin"]], e[["xmin"]], e[["ymax"]], e[["xmax"]])) |>
      httr2::req_perform()
    g <- sf::read_sf(httr2::resp_body_string(r))
    g$date_vol <- substr(as.character(g$date_vol), 1, 10)
    sf::st_geometry(g) <- "geometry"
    # Le CRS est celui du GeoJSON (2016-2020 : EPSG:3857 ; 2021-2023 : lon/lat) ; on ramène en EPSG:4326.
    if (is.na(sf::st_crs(g))) sf::st_crs(g) <- 4326
    g <- sf::st_transform(g, 4326)
    g <- sf::st_make_valid(g)
    graphes[[an]] <- g
    cat(an, ":", nrow(g), "polygones de vol dans l'emprise ; dates :",
        paste(sort(unique(g$date_vol)), collapse = ", "), "\n")
    hc <- sf::st_intersects(pt4326, g)
    hb <- sf::st_intersects(boite, g)
    res[[an]] <- data.frame(
      id = P$id,
      annee = an,
      vols_centre = vapply(hc, function(i) paste(sort(unique(g$date_vol[i])), collapse = " | "), ""),
      vols_boite = vapply(hb, function(i) paste(sort(unique(g$date_vol[i])), collapse = " | "), ""),
      n_centre = vapply(hc, function(i) length(unique(g$date_vol[i])), 1L),
      n_boite = vapply(hb, function(i) length(unique(g$date_vol[i])), 1L),
      stringsAsFactors = FALSE)
  }
  vols <- do.call(rbind, res)
  saveRDS(list(vols = vols, couches = couches,
               graphes = lapply(graphes, function(g) sf::st_drop_geometry(g))),
          file.path(M028, "vols_028.rds"))
  print(table(vols$annee, vols$n_centre))
  print(table(vols$annee, vols$vols_centre))
}

# Étape 3 : Sentinel-2 L2A ------------------------------------------------------------------

S2_URL_STAC <- "https://planetarycomputer.microsoft.com/api/stac/v1"
S2_URL_JETON <- "https://planetarycomputer.microsoft.com/api/sas/v1/token/sentinel-2-l2a"

# Décalage de 3x3 pixels de 10 m autour de chaque point (milieu = le pixel Sentinel-2
# qui contient le centre du pixel de la carte)
DEC9 <- as.matrix(expand.grid(dx = c(-10, 0, 10), dy = c(-10, 0, 10)))

if (ETAPE == "s2") {
  limite <- if (length(args) >= 3L) as.numeric(args[3]) else 520
  nproc <- if (length(args) >= 4L) as.integer(args[4]) else 8L
  t_debut <- Sys.time()
  P <- readRDS(file.path(M028, "points_028.rds"))$points
  d_s2 <- file.path(M028, "s2"); dir.create(d_s2, showWarnings = FALSE)
  f_items <- file.path(M028, "s2_items.rds")

  if (!file.exists(f_items)) {
    suppressMessages(library(rstac))
    bb <- terra::project(terra::vect(cbind(range(P$x), range(P$y)), crs = "EPSG:2154"), "EPSG:4326")
    bb <- as.vector(terra::ext(bb))
    rech <- rstac::stac_search(rstac::stac(S2_URL_STAC), collections = "sentinel-2-l2a",
                               bbox = c(bb[["xmin"]], bb[["ymin"]], bb[["xmax"]], bb[["ymax"]]),
                               datetime = sprintf("%sT00:00:00Z/%sT23:59:59Z", DEBUT, FIN), limit = 500)
    f <- rstac::items_fetch(rstac::post_request(rech), progress = FALSE)$features
    it <- lapply(f, function(i) list(
      id = i$id, datetime = i$properties$datetime, tuile = i$properties$`s2:mgrs_tile`,
      nuages = i$properties$`eo:cloud_cover`, base = i$properties$`s2:processing_baseline`,
      href = lapply(i$assets[c("B04", "B08", "B11", "SCL")], function(a) a$href)))
    saveRDS(it, f_items)
  }
  it <- readRDS(f_items)
  tuile <- vapply(it, `[[`, "", "tuile")
  it <- it[tuile == TUILE_S2]
  dt <- vapply(it, `[[`, "", "datetime")
  base <- vapply(it, function(i) as.numeric(i$base), 1)
  # Une même acquisition peut exister en deux versions (retraitement de 2024) :
  # on garde la ligne de base la plus récente.
  ord <- order(dt, -base)
  it <- it[ord]; dt <- dt[ord]
  garde <- !duplicated(dt)
  cat("Scènes de", TUILE_S2, ":", length(garde), "; sans doublon d'acquisition :", sum(garde), "\n")
  it <- it[garde]
  nua <- vapply(it, function(i) as.numeric(i$nuages), 1)
  it <- it[!is.na(nua) & nua <= NUAGES_MAX]
  cat("Scènes à moins de", NUAGES_MAX, "% de nuages :", length(it), "\n")
  fait <- file.exists(file.path(d_s2, paste0(vapply(it, `[[`, "", "id"), ".rds")))
  cat("Déjà lues :", sum(fait), "\n")
  reste <- it[!fait]
  if (length(reste)) {
    # Points : 3 x 3 pixels de 10 m autour de chaque point (UTM 30N)
    pu <- cbind(rep(P$xu, each = 9L) + rep(DEC9[, 1], times = nrow(P)),
                rep(P$yu, each = 9L) + rep(DEC9[, 2], times = nrow(P)))
    # Les pixels FO0 n'ont besoin que du pixel central (5e ligne de DEC9)
    centre <- rep(seq_len(9L) == 5L, times = nrow(P))
    garde_pt <- centre | !(rep(P$role, each = 9L) %in% "fo0")
    pu <- pu[garde_pt, , drop = FALSE]
    num_pt <- rep(P$id, each = 9L)[garde_pt]
    num_dec <- rep(seq_len(9L), times = nrow(P))[garde_pt]

    lire_scene <- function(i, pu, num_pt, num_dec, d_s2, deadline, scl_valide, url_jeton) {
      if (Sys.time() > deadline) return("reporte")
      if (!exists(".jeton", envir = globalenv()) || is.null(get(".jeton", globalenv())) ||
          Sys.time() > get(".jeton", globalenv())$fin) {
        j <- jsonlite::fromJSON(paste(readLines(url_jeton, warn = FALSE), collapse = ""))
        assign(".jeton", list(tok = j$token, fin = Sys.time() + 40 * 60), globalenv())
        terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")
        terra::setGDALconfig("CPL_VSIL_CURL_ALLOWED_EXTENSIONS", ".tif")
        terra::setGDALconfig("GDAL_HTTP_MAX_RETRY", "3")
        terra::setGDALconfig("GDAL_HTTP_RETRY_DELAY", "2")
      }
      tok <- get(".jeton", globalenv())$tok
      sortie <- file.path(d_s2, paste0(i$id, ".rds"))
      lire <- function(b) {
        r <- terra::rast(paste0("/vsicurl/", i$href[[b]], "?", tok))
        # Une seule lecture de la fenêtre qui contient tous les points, puis extraction en mémoire
        w <- terra::crop(r, terra::ext(min(pu[, 1]) - 30, max(pu[, 1]) + 30, min(pu[, 2]) - 30, max(pu[, 2]) + 30))
        m <- terra::values(w, mat = FALSE)
        as.numeric(m[terra::cellFromXY(w, pu)])
      }
      res <- tryCatch({
        scl <- lire("SCL")
        v <- data.frame(id = num_pt, dec = num_dec, scl = scl, b04 = NA_real_, b08 = NA_real_, b11 = NA_real_)
        if (any(scl %in% scl_valide)) {
          v$b04 <- lire("B04"); v$b08 <- lire("B08"); v$b11 <- lire("B11")
        }
        saveRDS(list(id = i$id, datetime = i$datetime, base = i$base, nuages = i$nuages, v = v), sortie)
        "ok"
      }, error = function(e) paste("erreur:", conditionMessage(e)))
      res
    }
    deadline <- t_debut + limite
    cl <- parallel::makeCluster(min(nproc, length(reste)))
    on.exit(parallel::stopCluster(cl), add = TRUE)
    out <- parallel::parLapplyLB(cl, reste, lire_scene, pu = pu, num_pt = num_pt, num_dec = num_dec,
                                 d_s2 = d_s2, deadline = deadline, scl_valide = SCL_VALIDE,
                                 url_jeton = S2_URL_JETON)
    out <- unlist(out)
    cat("Résultat :", paste(names(table(substr(out, 1, 7))), table(substr(out, 1, 7)), collapse = " ; "), "\n")
    if (any(grepl("^erreur", out))) print(head(unique(out[grepl("^erreur", out)]), 5))
    cat("Durée :", round(as.numeric(Sys.time() - t_debut, units = "secs")), "s\n")
  }
  nf <- length(list.files(d_s2, pattern = "\\.rds$"))
  cat(if (nf >= length(it)) "toutes les scènes sont lues" else "scènes restantes : relancer",
      "(", nf, "sur", length(it), ")\n")
}

# Étape 4 : analyse des séries NDVI ----------------------------------------------------------

# Réflectance de surface : les produits de ligne de base >= 04.00 portent un décalage
# de +1000 DN (BOA_ADD_OFFSET = -1000) ; DN = 0 est « sans donnée ». Vérifié sur les
# données par l'étape `analyser` (médiane du B04 des témoins sous végétation, hiver :
# ~250 DN avant 04.00, ~1220 après, soit ~1000 d'écart ; plancher du B04 à 1000 après).
refl_s2 <- function(dn, base) {
  dn[dn %in% 0] <- NA_real_
  (dn - ifelse(base >= 4, 1000, 0)) / 10000
}

# Marches d'une série : pour chaque date t, médiane des observations valides des
# `fen` jours qui précèdent t moins médiane de celles des `fen` jours qui suivent
# (au moins `nmin` de chaque côté). Retient la plus forte marche en valeur absolue,
# puis les suivantes à plus de `sep` jours. `marche` > 0 : baisse du NDVI.
# `avant` : dernière observation avant la marche ; `apres` : première après.
marches <- function(t, v, fen = 120, nmin = 3L, sep = 120, kmax = 3L) {
  o <- order(t); t <- as.numeric(t[o]); v <- v[o]
  n <- length(t)
  sc <- av <- ap <- rep(NA_real_, n)
  for (i in seq_len(n)) {
    a <- v[t < t[i] & t >= t[i] - fen]; b <- v[t >= t[i] & t <= t[i] + fen]
    if (length(a) >= nmin && length(b) >= nmin) {
      av[i] <- stats::median(a); ap[i] <- stats::median(b); sc[i] <- av[i] - ap[i]
    }
  }
  out <- NULL
  for (k in seq_len(kmax)) {
    if (all(is.na(sc))) break
    i <- which.max(abs(sc))
    out <- rbind(out, data.frame(avant = as.Date(max(t[t < t[i]]), origin = "1970-01-01"),
                                 apres = as.Date(t[i], origin = "1970-01-01"),
                                 ndvi_av = av[i], ndvi_ap = ap[i], marche = sc[i]))
    sc[abs(t - t[i]) < sep] <- NA
  }
  if (is.null(out)) out <- data.frame(avant = as.Date(character()), apres = as.Date(character()),
                                      ndvi_av = numeric(), ndvi_ap = numeric(), marche = numeric())
  out
}

# Chute locale L(t) : médiane du NDVI des `fen` jours qui précèdent t moins médiane de celui
# des `fen` jours qui suivent (t compris), au moins `nmin` observations de chaque côté ;
# L > 0 : baisse. Une valeur par observation.
chute_L <- function(t, v, fen = 45, nmin = 2L) {
  t <- as.numeric(t)
  vapply(seq_along(t), function(i) {
    a <- v[t < t[i] & t >= t[i] - fen]; b <- v[t >= t[i] & t <= t[i] + fen]
    if (length(a) >= nmin && length(b) >= nmin) stats::median(a) - stats::median(b) else NA_real_
  }, 1)
}
# Plus forte chute locale pour les t dans [X - h, X + h] (valeur et date)
chute_autour <- function(t, L, X, h = 60) {
  i <- which(as.numeric(t) >= as.numeric(X) - h & as.numeric(t) <= as.numeric(X) + h & !is.na(L))
  if (!length(i)) return(c(L = NA_real_, t = NA_real_))
  j <- i[which.max(L[i])]
  c(L = L[j], t = as.numeric(t[j]))
}

# Baisses nettes : parmi les six plus fortes marches (fenêtres de 120 j), celles dont la baisse
# du NDVI est >= `seuil` (0,30 : au-dessus de la plus forte marche médiane des témoins, 0,24,
# et de leur 3e quartile, 0,28 ; des témoins en ont pourtant, voir le rapport).
# DATE : `marches()` place la marche au maximum d'un écart de médianes sur 120 j, donc souvent
# une acquisition ou plus (jusqu'à ~2 mois) après la chute. La date est donc ramenée à la
# PREMIÈRE observation, dans les 120 j qui précèdent la date de la marche, à partir de laquelle
# toutes les observations jusqu'à la marche restent <= milieu de (NDVI avant, NDVI après) + 0,05
# et dont les 3 observations suivantes (elle comprise) ont une médiane <= à ce milieu. `avant` : l'observation valide qui la précède (la baisse a eu lieu
# entre `avant` et `date`) ; précision = `date - avant`.
chutes_nettes <- function(t, v, seuil = 0.30) {
  m <- marches(t, v, kmax = 6L)
  m <- m[m$marche >= seuil, ]
  m <- m[order(m$apres), ]
  o <- order(t); tn <- as.numeric(t[o]); vn <- v[o]
  date <- avant <- as.Date(rep(NA_real_, nrow(m)), origin = "1970-01-01")
  for (i in seq_len(nrow(m))) {
    mid <- (m$ndvi_av[i] + m$ndvi_ap[i]) / 2; ap <- as.numeric(m$apres[i])
    date[i] <- m$apres[i]; avant[i] <- m$avant[i]
    ia <- which(tn == ap)[1]
    for (j in which(tn >= ap - 120 & tn <= ap)) {
      # toutes les observations de j à la date de la marche restent sous le milieu (à 0,05 près) :
      # écarte un creux saisonnier suivi d'une remontée avant la marche
      if (j > 1L && all(vn[j:ia] <= mid + 0.05) && stats::median(vn[j:min(j + 2L, length(vn))]) <= mid) {
        date[i] <- as.Date(tn[j], origin = "1970-01-01"); avant[i] <- as.Date(tn[j - 1L], origin = "1970-01-01"); break
      }
    }
  }
  data.frame(date = date, avant = avant, L = m$marche)
}
# Classe d'écart (jours) pour une date de carte : le rapport ne donne jamais l'écart exact de P.
classe_ecart <- function(dj) {
  # deux classes seulement hors ±60 j : une classe plus fine laisserait, avec le mois de P, un
  # intervalle de quelques jours (vérifié par calcul, voir le rapport)
  ifelse(is.na(dj), "-", ifelse(abs(dj) <= 60, "dans ±60 j",
         ifelse(dj > 0, "plus de 2 mois après", "plus de 2 mois avant")))
}

mediane_fen <- function(t, v, d0, d1) {   # médiane des v pour t dans [d0, d1] ; NA si aucune
  w <- v[t >= d0 & t <= d1]
  if (length(w)) stats::median(w) else NA_real_
}
fmt_d <- function(d) ifelse(is.na(d), "-", format(d, "%Y-%m-%d"))

if (ETAPE == "analyser") {
  t0 <- Sys.time()
  PT <- readRDS(file.path(M028, "points_028.rds"))$points
  VO <- readRDS(file.path(M028, "vols_028.rds"))$vols
  fs <- list.files(file.path(M028, "s2"), "\\.rds$", full.names = TRUE)
  obs <- do.call(rbind, lapply(fs, function(f) {
    s <- readRDS(f); v <- s$v
    v$date <- as.Date(substr(s$datetime, 1, 10)); v$base <- as.numeric(s$base); v
  }))
  cat("Scènes lues :", length(fs), "; observations :", nrow(obs), "\n")

  # Contrôle du décalage de réflectance (témoins sous végétation, B04, pixel central)
  tt <- obs[obs$id %in% PT$id[PT$role == "temoin"] & obs$dec == 5 & obs$scl == 4 & !is.na(obs$b04) & obs$b04 > 0, ]
  hiver <- as.integer(format(tt$date, "%m")) %in% c(12, 1, 2)
  ctl <- data.frame(
    ligne_de_base = c("< 04.00", ">= 04.00"),
    b04_dn_median_hiver = c(stats::median(tt$b04[hiver & tt$base < 4]), stats::median(tt$b04[hiver & tt$base >= 4])),
    b04_dn_min = c(min(tt$b04[tt$base < 4]), min(tt$b04[tt$base >= 4])),
    b04_refl_mediane_hiver = c(stats::median(refl_s2(tt$b04, tt$base)[hiver & tt$base < 4]),
                               stats::median(refl_s2(tt$b04, tt$base)[hiver & tt$base >= 4])))
  print(ctl)

  obs$r04 <- refl_s2(obs$b04, obs$base); obs$r08 <- refl_s2(obs$b08, obs$base); obs$r11 <- refl_s2(obs$b11, obs$base)
  obs$ok <- obs$scl %in% SCL_VALIDE & !is.na(obs$r04) & !is.na(obs$r08) & obs$r08 > 0 & (obs$r08 + obs$r04) > 0
  obs$ndvi <- ifelse(obs$ok, (obs$r08 - obs$r04) / (obs$r08 + obs$r04), NA_real_)
  obs <- obs[order(obs$id, obs$date), ]

  # Série d'un point : pixel central, et médiane du 3 x 3 (au moins 5 pixels valides)
  serie <- function(id) {
    o <- obs[obs$id == id, ]
    c5 <- o[o$dec == 5 & !is.na(o$ndvi), c("date", "ndvi", "r11", "scl")]
    m9 <- stats::aggregate(ndvi ~ date, o[!is.na(o$ndvi), ], function(x) if (length(x) >= 5) stats::median(x) else NA_real_)
    m9 <- m9[!is.na(m9$ndvi), ]
    list(c5 = c5, m9 = m9)
  }

  # Témoins : chute locale L(t) de chaque série (pixel central), pour calibrer ce qu'une
  # série de forêt non datée fait toute seule (cycle saisonnier du sous-bois, voiles, etc.).
  tem <- PT[PT$role == "temoin", ]
  L_tem <- lapply(tem$id, function(i) { s <- serie(i)$c5; list(t = s$date, L = chute_L(s$date, s$ndvi)) })
  # Distribution nulle de la plus forte chute locale à ±60 j d'une date X : mêmes jour et
  # mois que X, toutes les années 2018-2025, décalages de -20 à +20 j (pas de 5 j), tous
  # les témoins. Exclut X + décalage hors [DEBUT + 60, FIN - 60].
  nul_chute <- function(X) {
    dec <- seq(-20, 20, by = 5); an <- 2018:2025
    vals <- c()
    for (a in an) {
      Xa <- as.Date(round(as.numeric(X) + 365.25 * (a - as.integer(format(X, "%Y")))), origin = "1970-01-01")
      for (d in dec) {
        Xp <- Xa + d
        if (Xp < DEBUT + 60 || Xp > FIN - 60) next
        vals <- c(vals, vapply(L_tem, function(z) chute_autour(z$t, z$L, Xp)[["L"]], 1))
      }
    }
    vals[!is.na(vals)]
  }
  # Distribution globale (une date par mois de l'année) pour l'en-tête du rapport
  nul_mois <- do.call(rbind, lapply(1:12, function(m) {
    z <- nul_chute(as.Date(sprintf("2021-%02d-15", m)))
    data.frame(mois = m, n = length(z), q50 = stats::quantile(z, 0.5), q90 = stats::quantile(z, 0.9),
               q95 = stats::quantile(z, 0.95), q99 = stats::quantile(z, 0.99), row.names = NULL)
  }))
  cat("Chute locale à ±60 j d'une date, forêt non datée (témoins) : par mois\n"); print(round(nul_mois, 3))
  # Témoins : plus forte marche (120 j) et baisses nettes (>= 0,30) par série
  tem_marche <- vapply(tem$id, function(i) {
    s <- serie(i)$c5; m <- marches(s$date, s$ndvi, kmax = 1L); if (nrow(m)) abs(m$marche) else NA_real_ }, 1)
  tem_nettes <- vapply(tem$id, function(i) { s <- serie(i)$c5; nrow(chutes_nettes(s$date, s$ndvi)) }, 1L)
  cat("Témoins : plus forte marche (quantiles 0, 25, 50, 75, 100 %) :", round(stats::quantile(tem_marche, c(0, .25, .5, .75, 1), na.rm = TRUE), 2),
      "\nTémoins avec au moins une baisse nette >= 0,30 :", sum(tem_nettes > 0), "sur", length(tem_nettes),
      "; nombre de baisses nettes par témoin :", tem_nettes, "\n")

  # Pixels d'étude -----------------------------------------------------------------
  ET <- PT[PT$role == "etude", ]
  v18 <- VO[VO$annee == "2018", ]; v21 <- VO[VO$annee == "2021", ]
  D18 <- as.Date(v18$vols_centre[match(ET$id, v18$id)]); D21 <- as.Date(v21$vols_centre[match(ET$id, v21$id)])
  ligne <- function(k) {
    p <- ET[k, ]; s <- serie(p$id)
    out <- list()
    for (mode in c("c5", "m9")) {
      z <- s[[mode]]; m <- marches(z$date, z$ndvi)
      out[[mode]] <- m
    }
    z <- s$c5
    etat <- function(X, a, b) mediane_fen(z$date, z$ndvi, X + a, X + b)
    Lz <- chute_L(z$date, z$ndvi)
    rel <- function(X) {   # plus forte chute locale à ±60 j de la date X d'une carte, et sa place parmi les témoins
      if (is.na(X)) return(c(L = NA_real_, quand = NA_real_, delta = NA_real_, q95 = NA_real_, rang = NA_real_))
      a <- chute_autour(z$date, Lz, X); nu <- nul_chute(X)
      c(L = a[["L"]], quand = a[["t"]], delta = as.numeric(X) - a[["t"]], q95 = unname(stats::quantile(nu, 0.95)),
        rang = if (is.na(a[["L"]])) NA_real_ else mean(nu >= a[["L"]]))
    }
    rp <- rel(p$pub); rd <- rel(p$date_carte)
    jg <- which.max(Lz)   # plus forte chute de toute la série
    ev <- chutes_nettes(z$date, z$ndvi)
    proche <- function(X) {   # écart signé X - date de la chute nette la plus proche
      if (is.na(X) || !nrow(ev)) return(NA_real_)
      dj <- as.numeric(X - ev$date); dj[which.min(abs(dj))]
    }
    sous <- function() {  # première date de 3 observations valides consécutives <= 0,30
      i <- which(z$ndvi <= 0.30)
      for (j in i) if (j + 2 <= nrow(z) && all(z$ndvi[j:(j + 2)] <= 0.30)) return(z$date[j])
      as.Date(NA)
    }
    data.frame(id = p$id, x = p$x, y = p$y, source = p$source, classe = p$classe_026, tfv = p$tfv,
               pub = p$pub, date_carte = p$date_carte, n_obs = nrow(z),
               vol2018 = D18[k], vol2021 = D21[k],
               ndvi_vol2018 = mediane_fen(z$date, z$ndvi, D18[k] - 30, D18[k] + 30),
               ndvi_vol2021 = mediane_fen(z$date, z$ndvi, D21[k] - 30, D21[k] + 30),
               av_pub = etat(p$pub, -90, -1), ap_pub = etat(p$pub, 1, 90),
               av_carte = etat(p$date_carte, -90, -1), ap_carte = etat(p$date_carte, 1, 90),
               L_pub = rp[["L"]], t_pub = as.Date(rp[["quand"]], origin = "1970-01-01"), delta_pub = rp[["delta"]],
               q95_pub = rp[["q95"]], rang_pub = rp[["rang"]],
               L_carte = rd[["L"]], t_carte = as.Date(rd[["quand"]], origin = "1970-01-01"), delta_carte = rd[["delta"]],
               q95_carte = rd[["q95"]], rang_carte = rd[["rang"]],
               L_max = Lz[jg], t_max = z$date[jg], sous030 = sous(),
               n_nettes = nrow(ev), nettes = paste(sprintf("%s (%.2f ; trou %d j)", fmt_d(ev$date), ev$L, as.integer(ev$date - ev$avant)), collapse = " ; "),
               nette_proche_pub = proche(p$pub), nette_proche_carte = proche(p$date_carte),
               marches = paste(sprintf("%s..%s %+.2f (%.2f>%.2f)", fmt_d(out$c5$avant), fmt_d(out$c5$apres),
                                       -out$c5$marche, out$c5$ndvi_av, out$c5$ndvi_ap), collapse = " ; "),
               marches_3x3 = paste(sprintf("%s..%s %+.2f", fmt_d(out$m9$avant), fmt_d(out$m9$apres), -out$m9$marche),
                                   collapse = " ; "),
               stringsAsFactors = FALSE)
  }
  TAB <- do.call(rbind, lapply(seq_len(nrow(ET)), ligne))
  rownames(TAB) <- NULL

  # FO0 : toutes les cellules du poste -------------------------------------------------
  FO <- PT[PT$role == "fo0", ]
  FO$date_ok <- !is.na(FO$date_carte)
  of <- obs[obs$id %in% FO$id & obs$dec == 5 & !is.na(obs$ndvi), c("id", "date", "ndvi")]
  fo_n <- tapply(of$ndvi, of$date, length)
  fo_med <- tapply(of$ndvi, of$date, stats::median)
  fo_q1 <- tapply(of$ndvi, of$date, stats::quantile, 0.25)
  fo_q3 <- tapply(of$ndvi, of$date, stats::quantile, 0.75)
  fo <- data.frame(date = as.Date(names(fo_med)), n = as.integer(fo_n[names(fo_med)]), med = as.numeric(fo_med),
                   q1 = as.numeric(fo_q1), q3 = as.numeric(fo_q3))
  fo <- fo[fo$n >= 0.3 * nrow(FO), ]      # dates où au moins 30 % des cellules sont valides
  fo_marches <- marches(fo$date, fo$med, kmax = 4L)
  # marche de chaque cellule (la plus forte), pour la dispersion des dates
  fo_pix <- do.call(rbind, lapply(FO$id, function(i) {
    z <- of[of$id == i, ]; m <- marches(z$date, z$ndvi, kmax = 1L)
    data.frame(id = i, n_obs = nrow(z), apres = if (nrow(m)) m$apres else as.Date(NA),
               marche = if (nrow(m)) m$marche else NA_real_)
  }))
  fo_pix$date_ok <- FO$date_ok[match(fo_pix$id, FO$id)]
  fo_pix$date_carte <- FO$date_carte[match(fo_pix$id, FO$id)]
  # Chute locale à ±60 j de la date de la carte recalculée : cellule par cellule, et sur la
  # série médiane, contre les témoins à la date médiane de l'objet
  D_fo <- stats::median(FO$date_carte[FO$date_ok])
  nu_fo <- nul_chute(D_fo)
  fo_pix$L_carte <- vapply(seq_len(nrow(fo_pix)), function(k) {
    if (!fo_pix$date_ok[k]) return(NA_real_)
    z <- of[of$id == fo_pix$id[k], ]
    chute_autour(z$date, chute_L(z$date, z$ndvi), fo_pix$date_carte[k])[["L"]]
  }, 1)
  fo_L <- chute_autour(fo$date, chute_L(fo$date, fo$med), D_fo)
  fo_test <- data.frame(date_mediane = D_fo, L_serie_mediane = fo_L[["L"]],
                        quand = as.Date(fo_L[["t"]], origin = "1970-01-01"),
                        q95_temoins = unname(stats::quantile(nu_fo, 0.95)),
                        part_cellules_au_dessus_q95 = mean(fo_pix$L_carte[fo_pix$date_ok] >= stats::quantile(nu_fo, 0.95), na.rm = TRUE),
                        n_cellules = sum(fo_pix$date_ok & !is.na(fo_pix$L_carte)))
  print(fo_test)
  # niveau de NDVI par année civile (médiane de la médiane des cellules)
  fo$an <- as.integer(format(fo$date, "%Y"))
  fo_an <- stats::aggregate(med ~ an, fo, stats::median)
  # Témoins : niveau par année, pour comparer
  ot <- obs[obs$id %in% tem$id & obs$dec == 5 & !is.na(obs$ndvi), ]
  ot$an <- as.integer(format(ot$date, "%Y"))
  tem_an <- stats::aggregate(ndvi ~ an, ot, stats::median)

  res <- list(controle_decalage = ctl, nul_par_mois = nul_mois, temoins_marche = tem_marche, temoins_nettes = tem_nettes,
              etude = TAB,
              fo0_serie = fo, fo0_marches = fo_marches, fo0_pixels = fo_pix, fo0_annees = fo_an, fo0_test = fo_test,
              temoins_annees = tem_an, nuages_max = NUAGES_MAX, scl_valide = SCL_VALIDE)
  saveRDS(res, file.path(M028, "analyse_028.rds"))

  cat("\n== Pixels d'étude ==\n")
  print(TAB[, c("id", "x", "y", "source", "classe", "pub", "date_carte", "n_obs")], row.names = FALSE)
  options(width = 220)
  print(data.frame(id = TAB$id, pub = TAB$pub, L = round(TAB$L_pub, 2), t = TAB$t_pub, dj = TAB$delta_pub,
                   q95 = round(TAB$q95_pub, 2), rang = round(TAB$rang_pub, 3), carte = TAB$date_carte,
                   Lc = round(TAB$L_carte, 2), tc = TAB$t_carte, djc = TAB$delta_carte, q95c = round(TAB$q95_carte, 2),
                   rangc = round(TAB$rang_carte, 3), Lmax = round(TAB$L_max, 2), tmax = TAB$t_max, sous030 = TAB$sous030),
        row.names = FALSE)
  cat("\n== Marches (trois plus fortes), NDVI central ==\n")
  for (k in seq_len(nrow(TAB))) cat(TAB$id[k], round(TAB$x[k]), round(TAB$y[k]), "|", TAB$marches[k], "\n")
  cat("\n== Baisses nettes (NDVI >= 0,30), écart de P et de la carte à la plus proche (j, + : date après la baisse) ==\n")
  for (k in seq_len(nrow(TAB))) cat(TAB$id[k], "| P", TAB$nette_proche_pub[k], "| carte", TAB$nette_proche_carte[k],
                                    "|", TAB$nettes[k], "\n")
  cat("\n== FO0 ==\n"); print(fo_marches); print(fo_an); print(tem_an)
  print(table(format(FO$date_carte[FO$date_ok], "%Y-%m")))
  cat("Durée :", round(as.numeric(Sys.time() - t0, units = "secs")), "s\n")

  # Lecture à l'œil des vignettes d'orthophoto (étape `orthos`) : lecture de l'analyste, à
  # contrôler par Pascal. 2018 = vol du 2018-08-02/03 ; 2020 = même image que 2018 sur tous
  # les pixels vus ; 2021 = vol du 2021-08-31 ; 2024 et 2025 : dates de vol inconnues.
  # nature : A arbres présents en 2018, absents ensuite (coupe) ; S herbe ou lande sans arbre au
  # pixel en 2018, puis sol travaillé ; L pixel de lisière ; H herbe puis plantation, sans sol nu
  # vu ; C coupe rase déjà faite en 2018, puis culture ; R aucun changement visible.
  # vu2021 : l'événement (arbres coupés ou sol travaillé) est déjà visible sur l'ortho de 2021.
  LECT <- data.frame(
    id = 1:34,
    nature = c("A", "A", "A", "A", "A", "A", "L", "A", "A", "S", "S", "H", "A", "S", "S", "S", "S", "S",
               "S", "S", "S", "S", "S", "S", "S", "A", "S", "R", "A", "C", "A", "A", "A", "A"),
    vu2021 = c(TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE,
               TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
               TRUE, FALSE),
    o2018 = c("couvert ligneux dense", "bosquet arboré", "pinède fermée", "pinède", "pinède", "pinède",
              "bois, lisière", "pinède claire, lande", "pinède", "lande herbeuse, arbres épars", "herbe",
              "herbe", "pinède (bord)", "herbe", "herbe", "herbe", "herbe", "herbe", "herbe", "herbe",
              "herbe", "herbe", "herbe", "herbe", "herbe", "forêt mélangée fermée", "herbe (clairière)",
              "pinède (lisière)", "bosquet de pins", "coupe rase ancienne", "pinède plantée",
              "peuplement mélangé", "pinède", "bosquet de pins, lande"),
    o2021 = c("sol dégagé nu", "sol nu (andains)", "pinède fermée", "coupe rase nue", "coupe rase nue",
              "coupe rase nue", "bord d'une coupe (rémanents)", "pinède (feuillage roux)", "pinède",
              "sol travaillé", "sol travaillé", "jeune plantation sombre", "pinède (bord)", "sol travaillé",
              "sol travaillé", "sol travaillé", "sol travaillé", "sol travaillé", "sol travaillé", "sol travaillé",
              "sol travaillé", "sol travaillé", "sol travaillé", "sol travaillé", "sol travaillé",
              "trouée de coupe au pixel", "sol travaillé", "pinède", "bosquet", "friche arbustive", "pinède",
              "peuplement", "coupe fraîche, sol nu", "bosquet encore présent"),
    o2024 = c("plantation", "plantation", "coupe rase", "plantation", "plantation", "plantation",
              "bande plantée au bord", "coupe, sol nu", "coupe rase", "plantation", "plantation", "plantation",
              "parcelle voisine coupée", "plantation", "plantation", "plantation", "plantation", "plantation",
              "plantation", "plantation", "plantation", "plantation", "plantation", "plantation", "plantation",
              "trouée en reprise", "plantation", "pinède", "coupé, planté", "culture", "coupe rase, sol dégagé",
              "coupé, sol dégagé", "sol nu travaillé", "bosquet disparu, plantation"),
    stringsAsFactors = FALSE)
  TAB <- merge(TAB, LECT, by = "id", sort = TRUE)
  # Une date de carte est « confirmée » par Sentinel-2 si la chute locale à ±60 j dépasse le 95e
  # centile des témoins à la même saison (rang <= 0,05), OU si une baisse nette du NDVI
  # (marche >= 0,30 sur 120 j) tombe à ±60 j d'elle. Le second critère rattrape les hivers
  # nuageux, où la chute locale (45 j, 2 observations de chaque côté) sous-estime.
  TAB$P_conf <- (!is.na(TAB$rang_pub) & TAB$rang_pub <= 0.05) | (!is.na(TAB$nette_proche_pub) & abs(TAB$nette_proche_pub) <= 60)
  TAB$D_conf <- (!is.na(TAB$rang_carte) & TAB$rang_carte <= 0.05) | (!is.na(TAB$nette_proche_carte) & abs(TAB$nette_proche_carte) <= 60)
  TAB$P_mes <- !is.na(TAB$rang_pub) | TAB$P_conf
  TAB$D_mes <- !is.na(TAB$rang_carte) | TAB$D_conf
  P_OK <- TAB$P_conf; D_OK <- TAB$D_conf
  TAB$loin <- TAB$classe %in% "loin_du_seuil_a_P"
  bilan <- function(d) {
    m <- d$P_mes & d$D_mes
    data.frame(n = nrow(d), P_mesure = sum(d$P_mes), P_chute = sum(d$P_conf),
               D_mesure = sum(d$D_mes), D_chute = sum(d$D_conf),
               P_seule = sum(m & d$P_conf & !d$D_conf), D_seule = sum(m & !d$P_conf & d$D_conf),
               les_deux = sum(m & d$P_conf & d$D_conf), aucune = sum(m & !d$P_conf & !d$D_conf))
  }
  bil <- rbind(tires20 = bilan(TAB[TAB$source == "tiré", ]), loin = bilan(TAB[TAB$loin, ]),
               autres = bilan(TAB[!TAB$loin, ]), tous = bilan(TAB))
  cat("\n== Bilan : une chute du NDVI à ±60 j de la date (rang <= 0,05 parmi les témoins) ==\n"); print(bil)
  wilson <- function(k, n, z = 1.96) {   # intervalle de Wilson à 95 %
    p <- k / n; c(p = p, bas = (p + z^2 / (2 * n) - z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / (1 + z^2 / n),
                  haut = (p + z^2 / (2 * n) + z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / (1 + z^2 / n))
  }
  t20 <- bil["tires20", ]
  cat("Tirage de 20 : P confirmée", t20$P_chute, "/", t20$P_mesure, "= ", round(wilson(t20$P_chute, t20$P_mesure), 2),
      "; D confirmée", t20$D_chute, "/", t20$D_mesure, "= ", round(wilson(t20$D_chute, t20$D_mesure), 2), "\n")
  bil_ic <- list(P = wilson(t20$P_chute, t20$P_mesure), D = wilson(t20$D_chute, t20$D_mesure))
  # Pixels où l'ortho du 2021-08-31 montre déjà l'événement : où tombent les dates des cartes ?
  V <- TAB[TAB$vu2021 & TAB$nature %in% c("A", "S"), ]
  vol21 <- as.Date("2021-08-31")
  apres21 <- data.frame(
    n = nrow(V), loin = sum(V$loin),
    P_avant_vol = sum(V$pub <= vol21), P_apres_vol = sum(V$pub > vol21),
    D_avant_vol = sum(V$date_carte <= vol21), D_apres_vol = sum(V$date_carte > vol21),
    loin_D_apres_vol = sum(V$loin & V$date_carte > vol21), loin_D_avant_vol = sum(V$loin & V$date_carte <= vol21),
    loin_P_avant_vol = sum(V$loin & V$pub <= vol21), loin_P_apres_vol = sum(V$loin & V$pub > vol21))
  cat("\n== Événement déjà visible sur l'ortho du 2021-08-31 (nature A ou S) ==\n"); print(apres21)
  cat("\n== Nature (lecture à l'œil) x classe, et poste BD Forêt ==\n")
  print(table(TAB$nature, TAB$loin)); print(table(TAB$tfv, TAB$nature))
  nat_P <- table(nature = TAB$nature[TAB$loin], P_chute = P_OK[TAB$loin]); print(nat_P)
  nat_D <- table(nature = TAB$nature[TAB$loin], D_chute = D_OK[TAB$loin]); print(nat_D)
  res$etude <- TAB; res$bilan <- bil; res$bilan_ic <- bil_ic; res$apres_vol_2021 <- apres21; res$lectures <- LECT
  saveRDS(res, file.path(M028, "analyse_028.rds"))

  # Tableau des pixels, prêt pour le rapport (écrit hors dépôt)
  cel_s2 <- function(rang, L, delta, nette) {
    ifelse(!is.na(rang) & rang <= 0.05, sprintf("chute à %+d j (%.2f)", round(delta), L),
           ifelse(!is.na(nette) & abs(nette) <= 60, sprintf("baisse nette à %+d j", round(nette)),
                  ifelse(is.na(rang), "n/d", sprintf("aucune (%.2f)", L))))
  }
  # P (v3.0.1, CC BY-NC) : jamais d'écart exact en jours, seulement une classe
  cel_p <- function(rang, L, conf, nette) {
    par_nette <- !is.na(nette) & abs(nette) <= 60
    ifelse(par_nette, "dans ±60 j d'une baisse nette listée",
           ifelse(conf, ifelse(is.na(nette), "dans ±60 j d'une chute locale (date non publiée)",
                               sprintf("dans ±60 j d'une chute locale (date non publiée) ; baisse nette la plus proche : %s", classe_ecart(nette))),
                  ifelse(is.na(rang) & is.na(nette), "n/d",
                         ifelse(is.na(nette), "aucune à ±60 j ; pas de baisse nette dans la série",
                                sprintf("aucune à ±60 j ; baisse nette la plus proche : %s", classe_ecart(nette))))))
  }
  md <- sprintf("| %d | %d ; %d | %s | %s | %s | %s | %s | %s | %s | %s |",
                TAB$id, round(TAB$x), round(TAB$y), ifelse(TAB$loin, "loin", sub("sous_tp_a_P_", "", sub("_du_seuil_a_P", "", TAB$classe))),
                format(TAB$pub, "%Y-%m"),   # la v3.0.1 est CC BY-NC : le mois seulement, comme en 026
                cel_p(TAB$rang_pub, TAB$L_pub, TAB$P_conf, TAB$nette_proche_pub),
                fmt_d(TAB$date_carte), cel_s2(TAB$rang_carte, TAB$L_carte, TAB$delta_carte, TAB$nette_proche_carte),
                sub("\\s+$", "", ifelse(TAB$n_nettes > 0, gsub("\\(0\\.[0-9]+ ; trou ([0-9]+) j\\)", "(trou \\1 j)", TAB$nettes), "-")),
                TAB$o2018, TAB$o2021)
  writeLines(md, file.path(M028, "tableau_pixels.md"))

  # Figures -------------------------------------------------------------------------
  d_f <- file.path(M028, "figures"); dir.create(d_f, showWarnings = FALSE)
  col_scl <- c("4" = "darkgreen", "5" = "sienna")
  fig_pixel <- function(k) {
    p <- ET[k, ]; s <- serie(p$id); z <- s$c5
    graphics::plot(z$date, z$ndvi, pch = 20, col = col_scl[as.character(z$scl)], ylim = c(-0.1, 1),
                   xlim = c(DEBUT, FIN), xlab = "", ylab = "NDVI",
                   main = sprintf("pixel %d (%d ; %d) %s | %s", p$id, round(p$x), round(p$y), p$tfv,
                                  if (is.na(p$classe)) "" else p$classe), cex.main = 0.9)
    graphics::lines(s$m9$date, s$m9$ndvi, col = "grey60")
    graphics::abline(v = p$pub, lwd = 2); graphics::abline(v = p$date_carte, lwd = 2, col = "red")
    graphics::abline(v = c(D18[k], D21[k]), lty = 3, col = "blue", lwd = 2)
    # baisses nettes du rapport : de l'observation précédente (trou) à la date retenue
    mm <- chutes_nettes(z$date, z$ndvi)
    if (nrow(mm)) graphics::rect(mm$avant, -0.1, mm$date, 0, col = "orange", border = NA)
    graphics::abline(h = c(0.3, 0.6), lty = 2, col = "grey85")
  }
  for (g in split(seq_len(nrow(ET)), ceiling(seq_len(nrow(ET)) / 4))) {
    grDevices::png(file.path(d_f, sprintf("etude_%02d.png", g[1])), width = 1400, height = 1100)
    op <- graphics::par(mfrow = c(4, 1), mar = c(2, 4, 2.2, 1))
    for (k in g) fig_pixel(k)
    graphics::par(op); grDevices::dev.off()
  }
  grDevices::png(file.path(d_f, "fo0.png"), width = 1400, height = 700)
  graphics::plot(fo$date, fo$med, type = "n", ylim = c(-0.1, 1), xlim = c(DEBUT, FIN), xlab = "", ylab = "NDVI",
                 main = sprintf("FO0 : médiane et quartiles des %d cellules (datées : %d)", nrow(FO), sum(FO$date_ok)))
  graphics::polygon(c(fo$date, rev(fo$date)), c(fo$q1, rev(fo$q3)), col = "grey85", border = NA)
  graphics::lines(fo$date, fo$med, type = "o", pch = 20, cex = 0.5)
  dd <- FO$date_carte[FO$date_ok];graphics::rug(dd, col = "red", lwd = 2)
  graphics::abline(v = c(as.Date(unique(VO$vols_centre[VO$annee == "2018"]))[1], as.Date("2021-08-31")),
                   lty = 3, col = "blue", lwd = 2)
  grDevices::dev.off()
  grDevices::png(file.path(d_f, "temoins.png"), width = 1400, height = 1100)
  op <- graphics::par(mfrow = c(4, 1), mar = c(2, 4, 2.2, 1))
  for (i in tem$id[1:4]) {
    s <- serie(i)$c5
    graphics::plot(s$date, s$ndvi, pch = 20, col = col_scl[as.character(s$scl)], ylim = c(-0.1, 1), xlim = c(DEBUT, FIN),
                   xlab = "", ylab = "NDVI", main = sprintf("témoin %d", i))
  }
  graphics::par(op); grDevices::dev.off()
  cat("Figures dans", d_f, "\n")
}

# Étape 5 : vignettes d'orthophoto (lecture à l'œil) ----------------------------------------

if (ETAPE == "orthos") {
  P <- readRDS(file.path(M028, "points_028.rds"))$points
  # Couches WMS (sondées en 026 : les autres années sont vides sur l'AOI)
  couches <- c("2018" = "ORTHOIMAGERY.ORTHOPHOTOS2018",
               "2020" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-ASP_PAC2020",
               "2021" = "ORTHOIMAGERY.ORTHOPHOTOS2021",
               "2024" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-EXPRESS.2024",
               "2025" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-ASP_PAC2025")
  d_o <- file.path(M028, "orthos"); dir.create(d_o, showWarnings = FALSE)
  # Pixels d'étude, et pour FO0 le pixel daté le plus proche du centre de l'objet
  fo <- P[P$role == "fo0" & !is.na(P$date_carte), ]
  cfo <- fo[which.min((fo$x - mean(fo$x))^2 + (fo$y - mean(fo$y))^2), ]
  E <- rbind(P[P$role == "etude", ], cfo)
  vignette <- function(x, y, a) {
    f <- file.path(d_o, sprintf("%d_%d_%s.jpg", round(x), round(y), a))
    if (!file.exists(f)) {
      bbox <- paste(x - 150, y - 150, x + 150, y + 150, sep = ",")
      u <- paste0("https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
                  "&LAYERS=", couches[[a]], "&STYLES=&CRS=EPSG:2154&BBOX=", bbox,
                  "&WIDTH=300&HEIGHT=300&FORMAT=image/jpeg")
      utils::download.file(u, f, mode = "wb", quiet = TRUE)
    }
    jpeg::readJPEG(f)
  }
  feuille <- function(lignes, fichier) {
    grDevices::png(fichier, width = 300 * length(couches), height = 330 * nrow(lignes))
    op <- graphics::par(mfrow = c(nrow(lignes), length(couches)), mar = c(0, 0, 2, 0))
    for (k in seq_len(nrow(lignes))) for (a in names(couches)) {
      im <- vignette(lignes$x[k], lignes$y[k], a)
      graphics::plot(0, 0, type = "n", xlim = c(0, 300), ylim = c(0, 300), axes = FALSE,
                     xlab = "", ylab = "", asp = 1,
                     main = sprintf("%s | pixel %d (%d ; %d)", a, lignes$id[k], round(lignes$x[k]), round(lignes$y[k])))
      graphics::rasterImage(im, 0, 0, 300, 300)
      graphics::rect(145, 145, 155, 155, border = "red")
    }
    graphics::par(op); grDevices::dev.off()
  }
  for (g in split(seq_len(nrow(E)), ceiling(seq_len(nrow(E)) / 2))) {
    feuille(E[g, ], file.path(d_o, sprintf("feuille_%03d.png", E$id[g[1]])))
  }
  cat("Feuilles dans", d_o, "\n")
}
