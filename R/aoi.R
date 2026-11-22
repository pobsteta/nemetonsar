# Préparation de l'AOI : lecture, validation, découpage en tuiles MGRS de
# 100 km dans leur système UTM, grille de calcul alignée.
#
# Sources des valeurs (relevées le 2026-11-22) :
# - Emprise de la France métropolitaine et surface du plus grand département :
#   IGN, Admin Express COG (couche ADMINEXPRESS-COG.LATEST:departement, service
#   WFS data.geopf.fr), 96 départements métropolitains ; emprise en EPSG:4326
#   arrondie vers l'extérieur au 1e-4 degré ; surface géodésique de la Gironde
#   calculée par terra::expanse() sur ce polygone : 10 380,876 km2 (l'INSEE
#   publie une superficie plus faible, de l'ordre de 9 976 km2 : la couche IGN
#   contient l'estuaire). Le test « dans l'emprise » est une approximation
#   provisoire de « en France métropolitaine » (pas de test sur le polygone).
# - MGRS : zone UTM, bande de latitude, carré de 100 km (schéma de lettres
#   « AA » de WGS 84). Norme : NGA.STND.0037_2.0.0_GRIDS (2014), « Universal
#   Grids and Grid Reference Systems » (non lue : site de la NGA inaccessible
#   depuis le conteneur) ; règles relevées dans des sources secondaires et
#   vérifiées sur la grille des tuiles Sentinel-2 de l'ESA
#   (S2A_OPER_GPR_TILE_DF__20110101T000000_99991231T235959_0007.kml) : voir
#   tests/testthat/test-aoi.R.
# - Alignement de la grille : les coins des tuiles Sentinel-2 de ce fichier
#   tombent tous sur des multiples de 20 m en UTM (134 tuiles sur la France
#   vérifiées) ; la grille de calcul est donc alignée sur les multiples de
#   `resolution_m` des coordonnées UTM.

# Emprise de la France métropolitaine (EPSG:4326) : xmin, xmax, ymin, ymax.
.aoi_emprise_france <- c(xmin = -5.1413, xmax = 9.5600, ymin = 41.3335, ymax = 51.0892)

# Surface maximale de l'AOI, en km2 (Gironde, IGN Admin Express COG).
.aoi_surface_max_km2 <- 10380.876

# Lettres MGRS (I et O exclus).
.mgrs_bandes <- "CDEFGHJKLMNPQRSTUVWX"
.mgrs_colonnes <- c("ABCDEFGH", "JKLMNPQR", "STUVWXYZ")
.mgrs_lignes <- "ABCDEFGHJKLMNPQRSTUV"

# Zone UTM d'un point, exceptions de Norvège (32V) et du Svalbard (31X à 37X)
# comprises.
mgrs_zone <- function(lon, lat) {
  zone <- (floor((lon + 180) / 6) %% 60) + 1
  norvege <- lat >= 56 & lat < 64 & lon >= 3 & lon < 12
  zone[norvege] <- 32
  svalbard <- lat >= 72 & lat <= 84
  zone[svalbard & lon >= 0 & lon < 9] <- 31
  zone[svalbard & lon >= 9 & lon < 21] <- 33
  zone[svalbard & lon >= 21 & lon < 33] <- 35
  zone[svalbard & lon >= 33 & lon < 42] <- 37
  as.integer(zone)
}

# Lettre de la bande de latitude (8 degrés de -80 à 72, 12 degrés de 72 à 84).
mgrs_bande <- function(lat) {
  i <- pmin(floor((lat + 80) / 8) + 1, 20)
  i[lat < -80 | lat > 84] <- NA
  substring(.mgrs_bandes, i, i)
}

# Lettres du carré de 100 km : colonne d'après l'abscisse UTM (trois jeux de
# huit lettres, selon la zone), ligne d'après l'ordonnée UTM (vingt lettres
# répétées tous les 2 000 km, décalées de cinq lettres dans les zones paires).
mgrs_carre <- function(zone, x, y) {
  col <- floor(x / 1e5)
  jeu <- .mgrs_colonnes[((zone - 1) %% 3) + 1]
  lettre_col <- substring(jeu, col, col)
  lig <- (floor(y / 1e5) + ifelse(zone %% 2 == 0, 5, 0)) %% 20 + 1
  paste0(lettre_col, substring(.mgrs_lignes, lig, lig))
}

# Code EPSG UTM WGS 84 d'une zone et d'un hémisphère.
epsg_utm <- function(zone, nord = TRUE) {
  as.integer(ifelse(nord, 32600L, 32700L) + zone)
}

# Identifiant MGRS (zone, bande, carré de 100 km) de points en degrés WGS 84.
mgrs_point <- function(lon, lat) {
  stopifnot(length(lon) == length(lat))
  zone <- mgrs_zone(lon, lat)
  bande <- mgrs_bande(lat)
  epsg <- epsg_utm(zone, lat >= 0)
  x <- y <- rep(NA_real_, length(lon))
  for (e in unique(epsg[!is.na(bande)])) {
    i <- which(epsg == e & !is.na(bande))
    p <- terra::vect(cbind(lon[i], lat[i]), crs = "EPSG:4326")
    xy <- terra::crds(terra::project(p, paste0("EPSG:", e)))
    x[i] <- xy[, 1]
    y[i] <- xy[, 2]
  }
  id <- sprintf("%02d%s%s", zone, bande, mgrs_carre(zone, x, y))
  id[is.na(bande)] <- NA_character_
  data.frame(mgrs = id, zone = zone, bande = bande, epsg = epsg,
             stringsAsFactors = FALSE)
}

# Rectangle en degrés, densifié (un sommet tous les `pas` degrés) pour que
# ses côtés restent des méridiens et des parallèles une fois projetés.
rectangle_lonlat <- function(xmin, xmax, ymin, ymax, pas = 0.01) {
  cote <- function(a, b) {
    n <- max(2, ceiling(abs(b - a) / pas) + 1)
    seq(a, b, length.out = n)
  }
  bas <- cote(xmin, xmax)
  droite <- cote(ymin, ymax)
  haut <- cote(xmax, xmin)
  gauche <- cote(ymax, ymin)
  xy <- rbind(cbind(bas, ymin), cbind(xmax, droite), cbind(haut, ymax),
              cbind(xmin, gauche))
  terra::vect(xy, type = "polygons", crs = "EPSG:4326")
}

# Lecture et contrôle de forme de l'AOI ; rend un SpatVector d'un seul
# polygone (union), sans attributs.
aoi_lire <- function(aoi, couche = NULL) {
  if (is.character(aoi)) {
    if (length(aoi) != 1L || is.na(aoi) || !file.exists(aoi)) {
      stop("`aoi` : fichier introuvable.", call. = FALSE)
    }
    v <- tryCatch(
      if (is.null(couche)) terra::vect(aoi) else terra::vect(aoi, layer = couche),
      error = function(e) {
        stop("`aoi` : fichier vecteur illisible (GeoPackage, GeoJSON ou shapefile attendu) : ",
             conditionMessage(e), call. = FALSE)
      })
  } else if (inherits(aoi, "SpatVector")) {
    v <- aoi
  } else {
    stop("`aoi` doit être un chemin de fichier vecteur ou un SpatVector.", call. = FALSE)
  }
  if (nrow(v) < 1L) {
    stop("`aoi` ne contient aucune géométrie.", call. = FALSE)
  }
  if (terra::geomtype(v) != "polygons") {
    stop("`aoi` doit contenir des polygones (lu : ", terra::geomtype(v), ").", call. = FALSE)
  }
  if (is.na(terra::crs(v)) || terra::crs(v) == "") {
    stop("`aoi` n'a pas de système de coordonnées.", call. = FALSE)
  }
  valide <- terra::is.valid(v)
  if (anyNA(valide) || !all(valide)) {
    v <- terra::makeValid(v)
    valide <- terra::is.valid(v)
    if (nrow(v) < 1L || terra::geomtype(v) != "polygons" || anyNA(valide) || !all(valide)) {
      stop("`aoi` : géométrie invalide, non réparable par terra::makeValid().",
           call. = FALSE)
    }
    warning("`aoi` : géométrie invalide, réparée par terra::makeValid().",
            call. = FALSE)
  }
  terra::values(v) <- NULL
  v <- terra::aggregate(v, dissolve = TRUE)
  terra::values(v) <- NULL
  if (sum(terra::expanse(v)) <= 0) {
    stop("`aoi` a une surface nulle.", call. = FALSE)
  }
  v
}

#' Préparer l'AOI : validation et tuiles de calcul
#'
#' Lit l'aire d'intérêt (AOI), la valide, et la découpe en **tuiles de
#' calcul** : une par carré MGRS de 100 km qu'elle touche, dans le système UTM
#' (WGS 84) de sa zone, avec l'emprise de l'AOI dans ce carré alignée sur une
#' grille de `resolution_m` mètres. Le calcul se fait ensuite tuile par tuile
#' (ADR 0003) ; [aoi_grille()] rend la grille de calcul d'une tuile.
#'
#' @section Validation :
#' - le fichier se lit avec [terra::vect()] (GeoPackage, GeoJSON, shapefile)
#'   et contient des polygones dans un système de coordonnées déclaré ;
#' - une géométrie invalide est **réparée** par [terra::makeValid()], avec un
#'   avertissement ; elle est refusée si la réparation échoue ;
#' - les polygones sont réunis en un seul (union) ; les attributs sont
#'   abandonnés ;
#' - l'AOI doit tenir dans l'emprise de la France métropolitaine (Corse
#'   comprise) : longitude de -5,1413 à 9,5600, latitude de 41,3335 à 51,0892
#'   (EPSG:4326 ; emprise des 96 départements d'IGN Admin Express COG,
#'   arrondie vers l'extérieur). C'est une approximation **provisoire** : une
#'   AOI en mer ou dans un pays voisin mais dans cette emprise est acceptée ;
#' - sa surface géodésique doit être au plus celle du plus grand département
#'   métropolitain, la Gironde : 10 380,876 km2, calculée par
#'   [terra::expanse()] sur le polygone d'IGN Admin Express COG (le
#'   2026-11-22 ; estuaire compris).
#'
#' @section Tuiles :
#' L'AOI est coupée par les zones de grille MGRS (zone UTM de 6 degrés et
#' bande de latitude de 8 degrés, côtés densifiés tous les 0,01 degré pour
#' suivre méridiens et parallèles), puis, dans le système UTM de chaque zone,
#' par les carrés de 100 km. L'identifiant suit la norme MGRS (schéma de
#' lettres de WGS 84, NGA.STND.0037_2.0.0_GRIDS) : par exemple `"31UDQ"` pour
#' Paris. Il est vérifié sur les tuiles Sentinel-2 de l'ESA, qui portent les
#' mêmes noms. Les tuiles Sentinel-2 débordent de leur carré (109,8 km) et
#' certains carrés coupés par une limite de zone n'en ont pas (par exemple
#' `31TBN`) : ici, les tuiles ne se recouvrent pas.
#'
#' L'emprise d'une tuile (`xmin`, `ymin`, `xmax`, `ymax`, en mètres UTM) est
#' l'emprise de la partie de l'AOI dans le carré, élargie aux multiples de
#' `resolution_m` : les coins des tuiles Sentinel-2 de l'ESA sont tous sur
#' des multiples de 20 m. Une partie d'AOI de part et d'autre d'une limite de
#' bande (48 degrés N) donne deux tuiles dans le même carré, d'emprises
#' voisines.
#'
#' @param aoi Chemin d'un fichier vecteur (GeoPackage, GeoJSON, shapefile)
#'   ou `SpatVector` de polygones.
#' @param resolution_m Côté du pixel de la grille de calcul, en mètres ; doit
#'   diviser 100 000 (10 par défaut, la grille de sortie de SUFOSAT).
#' @param couche Nom de la couche à lire dans un fichier qui en contient
#'   plusieurs (GeoPackage) ; `NULL` : la première.
#'
#' @return Une liste de classe `nemetonsar_aoi` :
#'   - `tuiles` : `data.frame`, une ligne par tuile, triée par identifiant :
#'     `mgrs` (par exemple `"31UDQ"`), `zone`, `bande`, `carre` (deux
#'     lettres), `epsg` (UTM WGS 84, par exemple 32631), `xmin`, `ymin`,
#'     `xmax`, `ymax` (emprise alignée, en mètres UTM), `resolution_m`,
#'     `ncol`, `nrow`, `surface_ha` (surface géodésique de l'AOI dans la
#'     tuile) ;
#'   - `aoi` : liste nommée par `mgrs` de `SpatVector`, la partie de l'AOI
#'     dans chaque tuile, dans le système UTM de la tuile ;
#'   - `aoi_origine` : l'AOI validée (union), dans son système d'origine ;
#'   - `surface_km2` : surface géodésique de l'AOI.
#'
#'   Les `SpatVector` ne survivent pas à `saveRDS()` (voir [terra::wrap()]).
#'
#' @seealso [aoi_grille()]
#' @examples
#' aoi <- terra::vect(
#'   "POLYGON ((2.30 48.80, 2.40 48.80, 2.40 48.88, 2.30 48.88, 2.30 48.80))",
#'   crs = "EPSG:4326"
#' )
#' p <- aoi_preparer(aoi)
#' p$tuiles
#' aoi_grille(p, "31UDQ")
#' @export
aoi_preparer <- function(aoi, resolution_m = 10, couche = NULL) {
  if (!is.numeric(resolution_m) || length(resolution_m) != 1L || is.na(resolution_m) ||
      resolution_m <= 0 || abs(1e5 / resolution_m - round(1e5 / resolution_m)) > 1e-9) {
    stop("`resolution_m` doit être un nombre positif qui divise 100 000 (en mètres).",
         call. = FALSE)
  }
  v <- aoi_lire(aoi, couche)
  ll <- terra::project(v, "EPSG:4326")
  e <- as.vector(terra::ext(ll))
  fr <- .aoi_emprise_france
  if (e[["xmin"]] < fr[["xmin"]] || e[["xmax"]] > fr[["xmax"]] ||
      e[["ymin"]] < fr[["ymin"]] || e[["ymax"]] > fr[["ymax"]]) {
    stop("`aoi` sort de l'emprise de la France métropolitaine (longitude ",
         fr[["xmin"]], " à ", fr[["xmax"]], ", latitude ", fr[["ymin"]], " à ",
         fr[["ymax"]], ").", call. = FALSE)
  }
  surface_km2 <- sum(terra::expanse(ll, unit = "km"))
  if (surface_km2 > .aoi_surface_max_km2) {
    stop("`aoi` trop grande : ", format(round(surface_km2, 1), nsmall = 1),
         " km2, pour au plus ", .aoi_surface_max_km2,
         " km2 (plus grand département métropolitain, la Gironde).", call. = FALSE)
  }

  # Zones de grille MGRS touchées (pas d'exception de zone en France).
  zones <- seq(mgrs_zone(e[["xmin"]], 45), mgrs_zone(e[["xmax"]], 45))
  bandes <- seq(floor((e[["ymin"]] + 80) / 8), floor((e[["ymax"]] + 80) / 8))
  lignes <- list()
  morceaux <- list()
  for (z in zones) {
    epsg <- epsg_utm(z)
    crs_utm <- paste0("EPSG:", epsg)
    for (b in bandes) {
      lat0 <- -80 + 8 * b
      gzd <- rectangle_lonlat(-180 + 6 * (z - 1), -180 + 6 * z, lat0, lat0 + 8)
      p <- terra::intersect(ll, gzd)
      if (nrow(p) < 1L || sum(terra::expanse(p)) <= 0) next
      p <- terra::project(p, crs_utm)
      bande <- substring(.mgrs_bandes, b + 1, b + 1)
      ep <- as.vector(terra::ext(p))
      for (cx in seq(floor(ep[["xmin"]] / 1e5), floor(ep[["xmax"]] / 1e5))) {
        for (cy in seq(floor(ep[["ymin"]] / 1e5), floor(ep[["ymax"]] / 1e5))) {
          carre <- terra::as.polygons(
            terra::ext(cx * 1e5, (cx + 1) * 1e5, cy * 1e5, (cy + 1) * 1e5),
            crs = crs_utm)
          m <- terra::intersect(p, carre)
          if (nrow(m) < 1L) next
          surface_ha <- sum(terra::expanse(m, unit = "ha"))
          if (surface_ha <= 0) next
          terra::values(m) <- NULL
          em <- as.vector(terra::ext(m))
          r <- resolution_m
          xmin <- max(floor(em[["xmin"]] / r) * r, cx * 1e5)
          xmax <- min(ceiling(em[["xmax"]] / r) * r, (cx + 1) * 1e5)
          ymin <- max(floor(em[["ymin"]] / r) * r, cy * 1e5)
          ymax <- min(ceiling(em[["ymax"]] / r) * r, (cy + 1) * 1e5)
          lettres <- mgrs_carre(z, cx * 1e5, cy * 1e5)
          id <- sprintf("%02d%s%s", z, bande, lettres)
          lignes[[id]] <- data.frame(
            mgrs = id, zone = as.integer(z), bande = bande, carre = lettres,
            epsg = epsg, xmin = xmin, ymin = ymin, xmax = xmax, ymax = ymax,
            resolution_m = r, ncol = as.integer(round((xmax - xmin) / r)),
            nrow = as.integer(round((ymax - ymin) / r)), surface_ha = surface_ha,
            stringsAsFactors = FALSE)
          morceaux[[id]] <- m
        }
      }
    }
  }
  if (length(lignes) == 0L) {
    stop("`aoi` : aucune tuile de calcul (surface nulle après découpage).", call. = FALSE)
  }
  ordre <- sort(names(lignes))
  tuiles <- do.call(rbind, lignes[ordre])
  rownames(tuiles) <- NULL
  structure(
    list(tuiles = tuiles, aoi = morceaux[ordre], aoi_origine = v,
         surface_km2 = surface_km2),
    class = "nemetonsar_aoi")
}

#' Grille de calcul d'une tuile
#'
#' Rend un `SpatRaster` sans valeurs : la grille de calcul d'une tuile
#' préparée par [aoi_preparer()] (emprise alignée, résolution, système UTM de
#' la tuile). Les images et les masques sont rééchantillonnés sur cette
#' grille.
#'
#' @param tuile Une ligne de `aoi_preparer(...)$tuiles` (un `data.frame` d'une
#'   ligne), ou le résultat de [aoi_preparer()] lui-même, avec `mgrs`.
#' @param mgrs Identifiant de la tuile, si `tuile` est le résultat de
#'   [aoi_preparer()] ; inutile s'il n'a qu'une tuile.
#'
#' @return Un `SpatRaster` d'une couche, sans valeurs.
#' @seealso [aoi_preparer()]
#' @examples
#' aoi <- terra::vect(
#'   "POLYGON ((2.30 48.80, 2.40 48.80, 2.40 48.88, 2.30 48.88, 2.30 48.80))",
#'   crs = "EPSG:4326"
#' )
#' p <- aoi_preparer(aoi)
#' aoi_grille(p$tuiles[1, ])
#' @export
aoi_grille <- function(tuile, mgrs = NULL) {
  if (inherits(tuile, "nemetonsar_aoi")) {
    t <- tuile$tuiles
    if (is.null(mgrs)) {
      if (nrow(t) != 1L) {
        stop("`mgrs` est requis : l'AOI a ", nrow(t), " tuiles (",
             paste(t$mgrs, collapse = ", "), ").", call. = FALSE)
      }
      tuile <- t
    } else {
      if (!is.character(mgrs) || length(mgrs) != 1L || !mgrs %in% t$mgrs) {
        stop("`mgrs` doit être l'identifiant d'une des tuiles : ",
             paste(t$mgrs, collapse = ", "), ".", call. = FALSE)
      }
      tuile <- t[t$mgrs == mgrs, , drop = FALSE]
    }
  }
  colonnes <- c("epsg", "xmin", "ymin", "xmax", "ymax", "resolution_m")
  if (!is.data.frame(tuile) || nrow(tuile) != 1L || !all(colonnes %in% names(tuile))) {
    stop("`tuile` doit être une ligne de `aoi_preparer(...)$tuiles` ou le résultat de aoi_preparer().",
         call. = FALSE)
  }
  r <- tuile$resolution_m
  terra::rast(xmin = tuile$xmin, xmax = tuile$xmax, ymin = tuile$ymin, ymax = tuile$ymax,
              resolution = r, crs = paste0("EPSG:", tuile$epsg))
}

#' @export
print.nemetonsar_aoi <- function(x, ...) {
  cat("AOI préparée : ", format(round(x$surface_km2, 3), nsmall = 3), " km2, ",
      nrow(x$tuiles), " tuile(s) de calcul\n", sep = "")
  print(x$tuiles[, c("mgrs", "epsg", "xmin", "ymin", "xmax", "ymax", "ncol", "nrow",
                     "surface_ha")], row.names = FALSE)
  invisible(x)
}
