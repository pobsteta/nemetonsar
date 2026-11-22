#' Comparer une carte recalculée à une carte de référence (SUFOSAT v3.0.1)
#'
#' Mesure l'accord entre la carte des coupes rases recalculée par
#' [nemetonsar_run()] et une carte de référence au même codage, typiquement
#' un extrait de la carte publiée SUFOSAT v3.0.1 (THEIA / CESBIO,
#' doi:10.71961/M18T-KB92 ; GeoTIFF Lambert-93, 10 m, entier `YYDDD`, `0` =
#' pas de coupe). Rend les chiffres du critère « Accord avec la v3.0.1 » du
#' brief (part de la surface publiée retrouvée, part de la surface
#' recalculée absente de la référence, écart médian sur la date) et les
#' métriques par objets du protocole des 75 % (Mermoz et al., 2024).
#'
#' @section Grille : La comparaison se fait **au pixel**, sur la grille de la
#'   carte recalculée. Si la référence est sur la même grille (même système,
#'   même origine, même résolution, [terra::compareGeom()]), elle est lue
#'   telle quelle. Sinon, elle est **reprojetée au plus proche voisin** sur
#'   la grille recalculée ([terra::project()], `method = "near"`), ce que dit
#'   l'élément `reprojection` du résultat. C'est le cas de la v3.0.1 et des
#'   sorties de [nemetonsar_run()] : toutes deux en Lambert-93 à 10 m, mais
#'   la grille publiée a pour origine (51639,69 ; 7150786,70) et celle du
#'   package des multiples de 10 m ; le plus proche voisin décale donc
#'   chaque pixel de la référence d'au plus un demi-pixel (≈ 5 m) et peut,
#'   au pixel près, souder ou couper des objets voisins.
#'
#' @section Pixels et objets comparés : Un pixel de la référence est
#'   **détecté** si sa valeur n'est ni `NA` ni `0` (nodata de la v3.0.1).
#'   Un pixel de la carte recalculée est détecté s'il appartient à un objet
#'   (`objets.tif`), ou, sans `objets.tif`, s'il a une date. Les **objets**
#'   de chaque carte sont les composantes connexes de ses pixels détectés,
#'   avec le voisinage `parametres$connexite` (le même pour les deux
#'   cartes). Un objet est gardé si sa **date médiane** (médiane basse des
#'   codes `YYDDD` de ses pixels datés, comme [postprocess()]) est dans
#'   `periode` ; un objet sans pixel daté est écarté. Les surfaces au pixel
#'   portent sur les pixels des objets gardés. **Choix du package, non
#'   sourcé, provisoire** : la v3.0.1 ne publie pas d'objets, seulement des
#'   pixels.
#'
#'   Si `aoi` est donnée, seuls comptent les pixels dont le centre est dans
#'   l'AOI ([terra::rasterize()]) ; sinon, toute l'emprise de la carte
#'   recalculée (hors de l'AOI de [nemetonsar_run()], ses pixels valent
#'   `NA` : la référence y serait comptée comme non retrouvée, d'où l'intérêt
#'   de donner l'AOI).
#'
#' @section Métriques : Au pixel, `s_pub`, `s_rec` et `s_com` sont les
#'   surfaces détectées par la référence, par la carte recalculée et par les
#'   deux :
#'   * `part_publiee_retrouvee = s_com / s_pub` ;
#'   * `part_recalculee_absente = (s_rec - s_com) / s_rec` ;
#'   * écart de date, sur les pixels communs datés dans les deux cartes :
#'     date recalculée moins date publiée, en jours ([yyddd_vers_date()]) ;
#'     `ecart_date_median_j` (signé : positif si la carte recalculée date
#'     plus tard) et `ecart_date_absolu_median_j`.
#'
#'   Par objets (règle des 75 % de Mermoz et al., 2024, reprise au brief,
#'   « Validation », point 2) : un objet de la référence est **retrouvé** si
#'   **plus de** `seuil_objet` de sa surface est détectée par la carte
#'   recalculée ; symétriquement, un objet recalculé est **confirmé** si plus
#'   de `seuil_objet` de sa surface est détectée par la référence. Alors
#'   `rappel` = objets de référence retrouvés / objets de référence,
#'   `precision` = objets recalculés confirmés / objets recalculés,
#'   `f1 = 2 * precision * rappel / (precision + rappel)`. **Écart au
#'   protocole de l'article** : celui-ci compte des polygones de référence
#'   photo-interprétés, coupes et forêts intactes ; ici les deux cartes
#'   sont des détections, et la précision est calculée sur les objets
#'   recalculés, faute de polygones intacts. L'**exactitude globale** du
#'   brief demande ces polygones intacts : elle n'est pas calculée.
#'
#' @param sorties La carte recalculée : le dossier de sortie de
#'   [nemetonsar_run()] (qui contient `dates.tif` et, s'il y a des objets,
#'   `objets.tif`), la liste qu'elle rend (élément `fichiers`), ou un
#'   `SpatRaster` d'une couche de dates `YYDDD`.
#' @param reference La carte de référence : chemin d'un raster ou
#'   `SpatRaster` d'une couche, dates `YYDDD`, `0` ou `NA` = pas de coupe.
#'   N'importe quel système de coordonnées (reprojetée au plus proche voisin
#'   si la grille diffère). Une carte nationale distante (`/vsicurl/`) est
#'   lue sur l'emprise de la carte recalculée seulement.
#' @param periode Deux dates (`Date` ou texte `"AAAA-MM-JJ"`), début et fin
#'   incluses : un objet est gardé si sa date médiane y tombe.
#' @param seuil_objet Part de la surface d'un objet au-delà de laquelle il
#'   est retrouvé (ou confirmé), strictement. Défaut 0,75 (Mermoz et al.,
#'   2024).
#' @param aoi `NULL`, ou l'AOI (chemin d'un fichier vecteur ou `SpatVector`
#'   de polygones) qui restreint la comparaison.
#' @param parametres Un objet créé par [parametres_sufosat()] : seul
#'   `connexite` sert ici.
#'
#' @return Une liste :
#'   * `resume` : `data.frame` d'une ligne : `surface_publiee_ha`,
#'     `surface_recalculee_ha`, `surface_commune_ha`,
#'     `part_publiee_retrouvee`, `part_recalculee_absente`,
#'     `nb_pixels_dates_communs`, `ecart_date_median_j`,
#'     `ecart_date_absolu_median_j`, `objets_reference`,
#'     `objets_retrouves`, `objets_recalcules`, `objets_confirmes`,
#'     `rappel`, `precision`, `f1` ;
#'   * `par_annee` : `data.frame`, une ligne par année : surface publiée
#'     (année de la date publiée), retrouvée, recalculée (année de la date
#'     recalculée ; `NA` pour les pixels comblés sans date), absente de la
#'     référence, parts, écart de date médian ;
#'   * `objets_reference`, `objets_recalcules` : une ligne par objet
#'     gardé : `identifiant`, `nb_pixels`, `surface_ha`, `date_mediane`
#'     (`YYDDD`), `date_mediane_date`, `part_detectee` (part de sa surface
#'     détectée par l'autre carte), `retrouve` (`part_detectee >
#'     seuil_objet`), `x`, `y` (centre d'un pixel de l'objet, le plus proche
#'     de son centre de gravité, dans le système de la grille) ;
#'   * `reprojection` : texte, ce qui a été fait de la grille de référence ;
#'   * `crs` : système de la grille de comparaison ; `seuil_objet`,
#'     `periode`.
#'
#' @section Licence : Une comparaison à la v3.0.1 en est un dérivé : ses
#'   résultats sont sous CC BY-NC 4.0 et vont dans un rapport de
#'   comparaison séparé (ADR 0002). Citer : CESBIO (2026), Sufosat :
#'   Submonthly Assessment of Temperate Forest Clear-Cuts in Mainland
#'   France, Data Terra, doi:10.71961/M18T-KB92.
#'
#' @seealso [nemetonsar_run()], [yyddd_vers_date()], [postprocess()].
#'
#' @examples
#' # Deux cartes synthétiques de 20 x 20 pixels de 10 m, en Lambert-93
#' gabarit <- terra::rast(nrows = 20, ncols = 20, xmin = 400000, xmax = 400200,
#'                        ymin = 6350000, ymax = 6350200, crs = "EPSG:2154")
#' pub <- terra::setValues(gabarit, 0L)
#' pub[3:8, 3:8] <- 24075L      # coupe publiée de 0,36 ha au 15 mars 2024
#' rec <- terra::setValues(gabarit, NA_integer_)
#' rec[3:8, 3:7] <- 24087L      # recalculée : 30 pixels sur 36, 12 jours plus tard
#' cmp <- compare_reference(rec, pub, c("2018-01-01", "2025-09-30"))
#' cmp$resume
#'
#' @export
compare_reference <- function(sorties, reference, periode, seuil_objet = 0.75,
                              aoi = NULL, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  if (length(periode) != 2L) {
    stop("`periode` doit contenir deux dates (d\u00e9but et fin).", call. = FALSE)
  }
  periode <- valide_periode(periode[[1]], periode[[2]])
  if (!est_scalaire_num(seuil_objet) || !is.finite(seuil_objet) ||
      seuil_objet < 0 || seuil_objet >= 1) {
    stop("`seuil_objet` doit \u00eatre un nombre dans [0, 1[.", call. = FALSE)
  }
  rec <- lire_carte_recalculee(sorties)
  grille <- rec$dates
  ref_brute <- lire_reference(reference)

  # Référence sur la grille recalculée.
  if (isTRUE(terra::compareGeom(grille, ref_brute, crs = TRUE, ext = TRUE, rowcol = TRUE,
                                res = TRUE, stopOnError = FALSE, messages = FALSE))) {
    ref <- ref_brute
    reprojection <- "aucune : m\u00eame grille"
  } else {
    emprise <- terra::project(terra::as.polygons(terra::ext(grille), crs = terra::crs(grille)),
                              terra::crs(ref_brute))
    marge <- 2 * max(terra::res(ref_brute))
    e <- terra::ext(emprise)
    e <- terra::ext(e$xmin - marge, e$xmax + marge, e$ymin - marge, e$ymax + marge)
    if (is.null(terra::intersect(e, terra::ext(ref_brute)))) {
      stop("`reference` ne recouvre pas la carte recalcul\u00e9e.", call. = FALSE)
    }
    ref_brute <- terra::crop(ref_brute, e, snap = "out")
    ref <- terra::project(ref_brute, grille, method = "near")
    reprojection <- paste0("plus proche voisin (terra::project, method = \"near\") de la grille de ",
                           "r\u00e9f\u00e9rence (", terra::crs(ref_brute, describe = TRUE)$code,
                           ", ", paste(signif(terra::res(ref_brute), 6), collapse = " x "),
                           ", origine ", paste(signif(terra::origin(ref_brute), 8), collapse = " ; "),
                           ") vers la grille recalcul\u00e9e (",
                           paste(signif(terra::origin(grille), 8), collapse = " ; "), ")")
  }

  # Valeurs en mémoire (AOI de taille pilote).
  date_rec <- as.numeric(terra::values(rec$dates, mat = FALSE))
  det_rec <- if (is.null(rec$objets)) !is.na(date_rec) else
    !is.na(terra::values(rec$objets, mat = FALSE))
  date_ref <- as.numeric(terra::values(ref, mat = FALSE))
  date_ref[!is.na(date_ref) & date_ref == 0] <- NA
  det_ref <- !is.na(date_ref)
  date_rec[!det_rec] <- NA
  dans <- rep(TRUE, terra::ncell(grille))
  if (!is.null(aoi)) {
    a <- lire_aoi_comparaison(aoi, grille)
    dans <- !is.na(terra::values(terra::rasterize(a, grille, field = 1), mat = FALSE))
  }
  det_rec <- det_rec & dans
  det_ref <- det_ref & dans

  # Objets des deux cartes, gardés selon la période.
  obj_rec <- objets_comparaison(grille, det_rec, date_rec, p$connexite, periode)
  obj_ref <- objets_comparaison(grille, det_ref, date_ref, p$connexite, periode)
  det_rec <- !is.na(obj_rec$etiquette)
  det_ref <- !is.na(obj_ref$etiquette)

  surface_px_ha <- prod(terra::res(grille)) / 1e4
  com <- det_rec & det_ref
  n_pub <- sum(det_ref)
  n_rec <- sum(det_rec)
  n_com <- sum(com)

  jours_rec <- as.numeric(yyddd_vers_date(date_rec[com]))
  jours_ref <- as.numeric(yyddd_vers_date(date_ref[com]))
  ecart <- jours_rec - jours_ref
  annee_ref_com <- as.integer(date_ref[com] %/% 1000) + 2000L
  datee <- !is.na(ecart)
  ecart_d <- ecart[datee]

  t_ref <- table_objets_comparaison(obj_ref, det_rec, grille, surface_px_ha, seuil_objet)
  t_rec <- table_objets_comparaison(obj_rec, det_ref, grille, surface_px_ha, seuil_objet)

  rappel <- if (nrow(t_ref) > 0L) mean(t_ref$retrouve) else NA_real_
  precision <- if (nrow(t_rec) > 0L) mean(t_rec$retrouve) else NA_real_
  f1 <- if (is.na(rappel) || is.na(precision) || rappel + precision == 0) NA_real_ else
    2 * precision * rappel / (precision + rappel)

  resume <- data.frame(
    surface_publiee_ha = n_pub * surface_px_ha,
    surface_recalculee_ha = n_rec * surface_px_ha,
    surface_commune_ha = n_com * surface_px_ha,
    part_publiee_retrouvee = if (n_pub > 0L) n_com / n_pub else NA_real_,
    part_recalculee_absente = if (n_rec > 0L) (n_rec - n_com) / n_rec else NA_real_,
    nb_pixels_dates_communs = length(ecart_d),
    ecart_date_median_j = if (length(ecart_d) > 0L) stats::median(ecart_d) else NA_real_,
    ecart_date_absolu_median_j = if (length(ecart_d) > 0L) stats::median(abs(ecart_d)) else NA_real_,
    objets_reference = nrow(t_ref),
    objets_retrouves = sum(t_ref$retrouve),
    objets_recalcules = nrow(t_rec),
    objets_confirmes = sum(t_rec$retrouve),
    rappel = rappel,
    precision = precision,
    f1 = f1
  )

  # Ventilation par année.
  annee_pub <- as.integer(date_ref[det_ref] %/% 1000) + 2000L
  annee_rec <- as.integer(date_rec[det_rec] %/% 1000) + 2000L
  absent_rec <- as.integer(date_rec[det_rec & !det_ref] %/% 1000) + 2000L
  annees <- sort(unique(c(annee_pub, annee_rec)), na.last = TRUE)
  compter <- function(x, a) if (is.na(a)) sum(is.na(x)) else sum(x == a, na.rm = TRUE)
  par_annee <- do.call(rbind, lapply(annees, function(a) {
    pub_a <- compter(annee_pub, a)
    com_a <- compter(annee_ref_com, a)
    rec_a <- compter(annee_rec, a)
    abs_a <- compter(absent_rec, a)
    e <- if (is.na(a)) numeric(0) else ecart[datee & annee_ref_com == a]
    data.frame(annee = a,
               surface_publiee_ha = pub_a * surface_px_ha,
               surface_retrouvee_ha = com_a * surface_px_ha,
               part_publiee_retrouvee = if (pub_a > 0L) com_a / pub_a else NA_real_,
               surface_recalculee_ha = rec_a * surface_px_ha,
               surface_absente_ha = abs_a * surface_px_ha,
               part_recalculee_absente = if (rec_a > 0L) abs_a / rec_a else NA_real_,
               ecart_date_median_j = if (length(e) > 0L) stats::median(e) else NA_real_)
  }))
  if (is.null(par_annee)) {
    par_annee <- data.frame(annee = integer(0), surface_publiee_ha = numeric(0),
                            surface_retrouvee_ha = numeric(0), part_publiee_retrouvee = numeric(0),
                            surface_recalculee_ha = numeric(0), surface_absente_ha = numeric(0),
                            part_recalculee_absente = numeric(0), ecart_date_median_j = numeric(0))
  }

  list(
    resume = resume,
    par_annee = par_annee,
    objets_reference = t_ref,
    objets_recalcules = t_rec,
    reprojection = reprojection,
    crs = terra::crs(grille, describe = TRUE)$code,
    seuil_objet = seuil_objet,
    periode = periode
  )
}

# Lecture des entrées -----------------------------------------------------------

# Rend list(dates = SpatRaster, objets = SpatRaster ou NULL).
lire_carte_recalculee <- function(sorties) {
  if (inherits(sorties, "SpatRaster")) {
    valide_raster_une_couche(sorties, "sorties")
    return(list(dates = sorties, objets = NULL))
  }
  if (is.list(sorties) && !is.null(sorties$fichiers)) {
    f <- sorties$fichiers
    if (is.null(f[["dates"]]) || !file.exists(f[["dates"]])) {
      stop("`sorties` : fichier des dates introuvable dans `fichiers`.", call. = FALSE)
    }
    obj <- f[["objets"]]
    return(list(dates = terra::rast(f[["dates"]]),
                objets = if (!is.null(obj) && file.exists(obj) && grepl("\\.tif$", obj))
                  terra::rast(obj) else NULL))
  }
  if (is.character(sorties) && length(sorties) == 1L && !is.na(sorties)) {
    if (dir.exists(sorties)) {
      fd <- file.path(sorties, "dates.tif")
      if (!file.exists(fd)) {
        stop("`sorties` : pas de dates.tif dans ", sorties, call. = FALSE)
      }
      fo <- file.path(sorties, "objets.tif")
      return(list(dates = terra::rast(fd),
                  objets = if (file.exists(fo)) terra::rast(fo) else NULL))
    }
    if (file.exists(sorties)) {
      r <- terra::rast(sorties)
      valide_raster_une_couche(r, "sorties")
      return(list(dates = r, objets = NULL))
    }
    stop("`sorties` : chemin introuvable : ", sorties, call. = FALSE)
  }
  stop("`sorties` doit \u00eatre un dossier de sortie de nemetonsar_run(), sa liste de r\u00e9sultat, ",
       "un chemin de raster ou un SpatRaster.", call. = FALSE)
}

lire_reference <- function(reference) {
  if (is.character(reference) && length(reference) == 1L && !is.na(reference)) {
    if (!file.exists(reference) && !startsWith(reference, "/vsi")) {
      stop("`reference` : fichier introuvable : ", reference, call. = FALSE)
    }
    reference <- terra::rast(reference)
  }
  if (!inherits(reference, "SpatRaster")) {
    stop("`reference` doit \u00eatre un chemin de raster ou un SpatRaster.", call. = FALSE)
  }
  valide_raster_une_couche(reference, "reference")
  if (!nzchar(terra::crs(reference))) {
    stop("`reference` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  reference
}

lire_aoi_comparaison <- function(aoi, grille) {
  if (is.character(aoi) && length(aoi) == 1L && !is.na(aoi)) {
    if (!file.exists(aoi)) stop("`aoi` : fichier introuvable : ", aoi, call. = FALSE)
    aoi <- terra::vect(aoi)
  }
  if (!inherits(aoi, "SpatVector") || terra::geomtype(aoi) != "polygons") {
    stop("`aoi` doit \u00eatre NULL, un chemin de fichier vecteur ou un SpatVector de polygones.",
         call. = FALSE)
  }
  if (!nzchar(terra::crs(aoi))) {
    stop("`aoi` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  terra::project(aoi, terra::crs(grille))
}

# Objets ------------------------------------------------------------------------

# Composantes connexes des pixels détectés ; garde celles dont la médiane
# basse des codes YYDDD est dans la période. Rend list(etiquette (vecteur
# par cellule, NA hors objet gardé), table (identifiant, nb_pixels,
# date_mediane)).
objets_comparaison <- function(grille, detecte, dates, connexite, periode) {
  vide <- list(etiquette = rep(NA_integer_, length(detecte)),
               table = data.frame(identifiant = integer(0), nb_pixels = integer(0),
                                  date_mediane = integer(0)))
  if (!any(detecte)) return(vide)
  r <- terra::rast(grille, nlyrs = 1)
  v <- rep(NA_real_, length(detecte))
  v[detecte] <- 1
  r <- terra::setValues(r, v)
  et <- as.integer(terra::values(terra::patches(r, directions = connexite), mat = FALSE))
  et[!detecte] <- NA_integer_
  ids <- sort(unique(et[!is.na(et)]))
  nb <- tabulate(match(et[!is.na(et)], ids), nbins = length(ids))
  med <- mediane_basse_groupe(et, dates, ids)
  bornes <- date_vers_yyddd(periode)
  garde <- !is.na(med) & med >= bornes[1] & med <= bornes[2]
  ids_g <- ids[garde]
  et[!is.na(et) & !et %in% ids_g] <- NA_integer_
  nouv <- match(et, ids_g)
  list(etiquette = nouv,
       table = data.frame(identifiant = seq_along(ids_g), nb_pixels = nb[garde],
                          date_mediane = as.integer(med[garde])))
}

# Médiane basse des valeurs non NA de chaque groupe (ordre de `ids`).
mediane_basse_groupe <- function(groupe, valeur, ids) {
  res <- rep(NA_real_, length(ids))
  ok <- !is.na(groupe) & !is.na(valeur)
  if (!any(ok)) return(res)
  g <- groupe[ok]
  v <- valeur[ok]
  o <- order(g, v)
  g <- g[o]
  v <- v[o]
  r <- rle(g)
  fin <- cumsum(r$lengths)
  debut <- fin - r$lengths + 1L
  res[match(r$values, ids)] <- v[debut + ceiling(r$lengths / 2) - 1L]
  res
}

# Table des objets d'une carte avec la part détectée par l'autre carte.
table_objets_comparaison <- function(obj, det_autre, grille, surface_px_ha, seuil) {
  t <- obj$table
  if (nrow(t) == 0L) {
    return(data.frame(identifiant = integer(0), nb_pixels = integer(0), surface_ha = numeric(0),
                      date_mediane = integer(0), date_mediane_date = as.Date(character(0)),
                      part_detectee = numeric(0), retrouve = logical(0),
                      x = numeric(0), y = numeric(0)))
  }
  cel <- which(!is.na(obj$etiquette))
  g <- obj$etiquette[cel]
  vus <- tabulate(g[det_autre[cel]], nbins = nrow(t))
  xy <- terra::xyFromCell(grille, cel)
  mx <- as.numeric(rowsum(xy[, 1], g, reorder = TRUE)) / t$nb_pixels
  my <- as.numeric(rowsum(xy[, 2], g, reorder = TRUE)) / t$nb_pixels
  d <- (xy[, 1] - mx[g])^2 + (xy[, 2] - my[g])^2
  o <- order(g, d)
  premier <- o[!duplicated(g[o])]
  premier <- premier[order(g[premier])]
  part <- vus / t$nb_pixels
  data.frame(identifiant = t$identifiant,
             nb_pixels = t$nb_pixels,
             surface_ha = t$nb_pixels * surface_px_ha,
             date_mediane = t$date_mediane,
             date_mediane_date = yyddd_vers_date(t$date_mediane),
             part_detectee = part,
             retrouve = part > seuil,
             x = xy[premier, 1],
             y = xy[premier, 2])
}
