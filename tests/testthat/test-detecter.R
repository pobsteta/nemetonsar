skip_if_not_installed("terra")

p_def <- parametres_sufosat()

# Grille UTM 31N, 10 m, `nl` lignes x `nc` colonnes.
grille_utm <- function(nl, nc) {
  terra::rast(nrows = nl, ncols = nc, xmin = 600000, xmax = 600000 + 10 * nc,
              ymin = 5000000, ymax = 5000000 + 10 * nl, crs = "EPSG:32631")
}

# Pile synthétique d'une orbite, écrite en GeoTIFF temporaire : fond à
# 0,05 (linéaire) avec un bruit gamma faible, et des coupes de -6 dB (ligne,
# colonne, date). `trous` : cellules sans donnée sur toute la série.
pile_synthetique <- function(nl, nc, dates, coupes, graine, trous = integer(0)) {
  set.seed(graine)
  v <- matrix(0.05 * stats::rgamma(nl * nc * length(dates), 200, 200),
              nrow = nl * nc)
  ligne <- rep(seq_len(nl), each = nc)
  colonne <- rep(seq_len(nc), nl)
  for (cp in coupes) {
    dedans <- ligne %in% cp$lignes & colonne %in% cp$colonnes
    apres <- dates >= cp$date
    v[dedans, apres] <- v[dedans, apres] * 10^(-6 / 10)
  }
  v[trous, ] <- NA
  r <- terra::rast(grille_utm(nl, nc), nlyrs = length(dates))
  terra::values(r) <- v
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(r, f, datatype = "FLT8S")
  terra::rast(f)
}

dates_a <- seq(as.Date("2018-01-03"), as.Date("2020-06-30"), by = 12)
dates_d <- seq(as.Date("2018-01-09"), as.Date("2020-06-30"), by = 12)
nl <- 30
nc <- 24
coupes <- list(
  # grande coupe, à cheval sur plusieurs limites de bloc
  list(lignes = 6:17, colonnes = 4:11, date = as.Date("2019-06-15")),
  # coupe en L touchant le bord bas
  list(lignes = 25:30, colonnes = 15:18, date = as.Date("2019-09-01")),
  list(lignes = 28:30, colonnes = 19:23, date = as.Date("2019-09-01")),
  # petite coupe (2 x 2 = 0,04 ha) : retirée par le post-traitement
  list(lignes = 3:4, colonnes = 20:21, date = as.Date("2019-11-01"))
)
# Une coupe vue par la seule orbite descendante, plus tard.
coupes_d <- c(coupes, list(list(lignes = 19:26, colonnes = 1:7, date = as.Date("2020-02-01"))))
trou <- (12 - 1) * nc + 14:16 # trois cellules sans donn\u00e9e, ligne 12
orbites <- list(
  asc = pile_synthetique(nl, nc, dates_a, coupes, 1, trous = trou),
  desc = pile_synthetique(nl, nc, dates_d, coupes_d, 2)
)
dates <- list(dates_a, dates_d)

# Chaîne de référence sur le tableau entier, en matrices [colonne, ligne].
reference <- function(orbites, dates, p) {
  res <- lapply(seq_along(orbites), function(k) {
    v <- terra::values(orbites[[k]])
    serie <- array(v, dim = c(terra::ncol(orbites[[k]]), terra::nrow(orbites[[k]]), ncol(v)))
    rcr_compute(s1_filter_multitemp(serie, dates[[k]], p), dates[[k]], p)
  })
  names(res) <- names(orbites)
  comb <- rcr_combine_orbites(res, p)
  seg <- rcr_segment(comb, p)
  post <- postprocess(seg, comb, p, resolution_m = 10)
  p_sf <- p
  p_sf$fermeture <- FALSE
  avant <- postprocess(seg, comb, p_sf, resolution_m = 10)$detection
  list(comb = comb, post = post, avant = avant)
}

ref <- reference(orbites, dates, p_def)

lire <- function(f) terra::values(terra::rast(f), mat = FALSE)

test_that("la r\u00e9f\u00e9rence contient bien les objets attendus", {
  # grande coupe, coupe en L, coupe de l'orbite descendante ; la petite est retirée
  expect_equal(nrow(ref$post$table), 3L)
})

for (lpb in c(1L, 2L, 5L, 7L, 11L, 30L)) {
  test_that(paste("r\u00e9sultat par blocs de", lpb, "lignes identique au tableau entier"), {
    dossier <- tempfile("detecter-")
    res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = lpb)
    expect_identical(res$lignes_par_bloc, lpb)
    avant <- as.vector(ref$avant)
    # Dates : YYDDD sur les pixels détectés avant la fermeture, NA ailleurs.
    attendu_date <- ifelse(avant, as.vector(ref$comb$date_min), NA_integer_)
    expect_equal(lire(res$fichiers[["dates"]]), attendu_date)
    # Ratio (stocké en réel 32 bits).
    attendu_ratio <- ifelse(avant, as.vector(ref$comb$ratio_min_db), NA_real_)
    expect_equal(lire(res$fichiers[["ratio"]]), attendu_ratio, tolerance = 1e-6)
    # Objets : mêmes identifiants, même ordre.
    expect_equal(lire(res$fichiers[["objets_raster"]]), as.vector(ref$post$objet))
    # Table.
    expect_equal(res$objets, ref$post$table)
    unlink(dossier, recursive = TRUE)
  })
}

test_that("fichiers : CRS, grille, type, NA cod\u00e9", {
  dossier <- tempfile("detecter-")
  res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = 4)
  expect_setequal(names(res$fichiers), c("dates", "ratio", "objets_raster", "objets"))
  expect_true(all(file.exists(res$fichiers)))
  # Aucun fichier intermédiaire laissé, rien d'autre écrit.
  expect_setequal(list.files(dossier, all.files = TRUE, no.. = TRUE),
                  basename(res$fichiers))
  for (nom in c("dates", "ratio", "objets_raster")) {
    r <- terra::rast(res$fichiers[[nom]])
    expect_true(terra::compareGeom(r, orbites[[1]], stopOnError = FALSE))
    expect_true(terra::same.crs(r, "EPSG:32631"))
    expect_equal(terra::nlyr(r), 1)
  }
  expect_identical(terra::datatype(terra::rast(res$fichiers[["dates"]])), "INT4S")
  expect_identical(terra::datatype(terra::rast(res$fichiers[["objets_raster"]])), "INT4S")
  expect_identical(terra::datatype(terra::rast(res$fichiers[["ratio"]])), "FLT4S")
  # La valeur de non-donnée est déclarée dans le fichier (GDAL).
  info <- terra::describe(res$fichiers[["dates"]])
  expect_true(any(grepl("NoData Value", info)))
  d <- lire(res$fichiers[["dates"]])
  expect_true(anyNA(d))
  # Les codes sont des YYDDD valides, qui reviennent à des dates.
  codes <- unique(d[!is.na(d)])
  expect_true(all(codes %/% 1000 %in% 19:20))
  expect_equal(date_vers_yyddd(yyddd_vers_date(codes)), codes)
  # Sans donnée en entrée -> NA en sortie.
  expect_true(all(is.na(d[trou])))
  unlink(dossier, recursive = TRUE)
})

test_that("GeoPackage : un objet par coupe, avec date, surface, ratio", {
  dossier <- tempfile("detecter-")
  res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = 5)
  v <- terra::vect(res$fichiers[["objets"]], layer = "objets")
  expect_equal(nrow(v), 3L)
  expect_true(terra::same.crs(v, "EPSG:32631"))
  expect_equal(v$identifiant, 1:3)
  expect_equal(v$surface_ha, res$objets$surface_ha)
  expect_equal(v$date_mediane, res$objets$date_mediane)
  expect_equal(as.Date(v$date_mediane_date), res$objets$date_mediane_date)
  expect_equal(v$ratio_moyen_db, res$objets$ratio_moyen_db)
  # Surface du polygone = surface de la table (pixels de 10 m).
  expect_equal(terra::expanse(v, unit = "ha", transform = FALSE), v$surface_ha)
  # Dates médianes : première acquisition après chaque coupe.
  coupe <- c(as.Date("2019-06-15"), as.Date("2020-02-01"), as.Date("2019-09-01"))
  ecart <- as.numeric(res$objets$date_mediane_date - coupe)
  expect_true(all(ecart >= 0 & ecart <= 24))
  # Ratio moyen proche de -6 dB, sous le seuil ts.
  expect_true(all(res$objets$ratio_moyen_db < seuils_db(p_def)[["ts"]]))
  unlink(dossier, recursive = TRUE)
})

test_that("sans aucune coupe : rasters tout NA, table vide, pas de GeoPackage", {
  o <- list(a = pile_synthetique(8, 6, dates_a, list(), 3))
  dossier <- tempfile("detecter-")
  res <- nemetonsar_detecter(o, list(dates_a), dossier, lignes_par_bloc = 3)
  expect_equal(nrow(res$objets), 0L)
  expect_false("objets" %in% names(res$fichiers))
  expect_true(all(is.na(lire(res$fichiers[["dates"]]))))
  expect_false(file.exists(file.path(dossier, "objets.gpkg")))
  unlink(dossier, recursive = TRUE)
})

test_that("autres r\u00e9glages : connexit\u00e9 4, fermeture 5, filtre 5, sans fermeture", {
  for (p in list(
    parametres_sufosat(connexite = 4L, taille_fermeture = 5L),
    parametres_sufosat(fenetre_filtre = 5L),
    parametres_sufosat(fermeture = FALSE)
  )) {
    r <- reference(orbites, dates, p)
    for (lpb in c(1L, 4L)) {
      dossier <- tempfile("detecter-")
      res <- nemetonsar_detecter(orbites, dates, dossier, parametres = p,
                                 lignes_par_bloc = lpb)
      expect_equal(lire(res$fichiers[["objets_raster"]]), as.vector(r$post$objet))
      expect_equal(res$objets, r$post$table)
      expect_equal(lire(res$fichiers[["dates"]]),
                   ifelse(as.vector(r$avant), as.vector(r$comb$date_min), NA_integer_))
      unlink(dossier, recursive = TRUE)
    }
  }
})

test_that("taille de bloc par d\u00e9faut et r\u00e9solution lue dans le raster", {
  dossier <- tempfile("detecter-")
  res <- nemetonsar_detecter(orbites, dates, dossier)
  expect_identical(res$lignes_par_bloc, as.integer(nl))
  expect_equal(res$objets, ref$post$table)
  # Résolution donnée : surfaces recalculées en conséquence.
  res20 <- nemetonsar_detecter(orbites, dates, dossier, resolution_m = 20,
                               lignes_par_bloc = 6)
  expect_equal(res20$objets$surface_ha, res20$objets$nb_pixels * 400 / 1e4)
  unlink(dossier, recursive = TRUE)
})

test_that("entr\u00e9es invalides refus\u00e9es", {
  d <- tempfile("detecter-")
  expect_error(nemetonsar_detecter(list(1), dates[1], d), "SpatRaster")
  expect_error(nemetonsar_detecter(orbites, dates[1], d), "longueur")
  expect_error(nemetonsar_detecter(orbites, list(dates_a[-1], dates_d), d), "dimension")
  autre <- terra::rast(grille_utm(nl, nc + 1), nlyrs = length(dates_d))
  terra::values(autre) <- 0.05
  expect_error(nemetonsar_detecter(list(orbites[[1]], autre), dates, d), "grille")
  geo <- terra::rast(nrows = 5, ncols = 5, nlyrs = length(dates_a), crs = "EPSG:4326")
  terra::values(geo) <- 0.05
  expect_error(nemetonsar_detecter(list(geo), list(dates_a), d), "degr")
  expect_error(nemetonsar_detecter(orbites, dates, d, lignes_par_bloc = 0), "lignes_par_bloc")
  expect_error(nemetonsar_detecter(orbites, dates, d, lignes_par_bloc = 2.5), "lignes_par_bloc")
  expect_error(nemetonsar_detecter(orbites, dates, d, resolution_m = -1), "resolution_m")
  expect_false(dir.exists(d))
})

# Masque forêt (option B) -----------------------------------------------------

# Référence sur le tableau entier : ratio et date mis à NA hors forêt après
# la combinaison des orbites, puis segmentation et post-traitement.
reference_foret <- function(orbites, dates, p, garde) {
  res <- lapply(seq_along(orbites), function(k) {
    v <- terra::values(orbites[[k]])
    serie <- array(v, dim = c(terra::ncol(orbites[[k]]), terra::nrow(orbites[[k]]), ncol(v)))
    rcr_compute(s1_filter_multitemp(serie, dates[[k]], p), dates[[k]], p)
  })
  names(res) <- names(orbites)
  comb <- rcr_combine_orbites(res, p)
  comb$ratio_min_db[!garde] <- NA_real_
  comb$date_min[!garde] <- NA_integer_
  seg <- rcr_segment(comb, p)
  post <- postprocess(seg, comb, p, resolution_m = 10)
  p_sf <- p
  p_sf$fermeture <- FALSE
  avant <- postprocess(seg, comb, p_sf, resolution_m = 10)$detection
  list(comb = comb, post = post, avant = avant)
}

# Masque à trois états : non-forêt (FALSE) sur les colonnes 1 à 7, sans
# donnée (NA) sur les lignes 25 à 30, forêt ailleurs.
ligne_c <- rep(seq_len(nl), each = nc)
colonne_c <- rep(seq_len(nc), nl)
etat <- ifelse(colonne_c <= 7, 0, 1)
etat[ligne_c >= 25] <- NA
foret_3 <- terra::rast(grille_utm(nl, nc), vals = etat) == 1
garde_3 <- matrix(!is.na(etat) & etat == 1, nrow = nc)

test_that("foret : tout TRUE donne exactement le r\u00e9sultat sans masque", {
  tout <- terra::rast(grille_utm(nl, nc), vals = TRUE)
  d1 <- tempfile("detecter-")
  d2 <- tempfile("detecter-")
  sans <- nemetonsar_detecter(orbites, dates, d1, lignes_par_bloc = 7)
  avec <- nemetonsar_detecter(orbites, dates, d2, lignes_par_bloc = 7, foret = tout)
  expect_equal(avec$objets, sans$objets)
  for (nom in c("dates", "ratio", "objets_raster")) {
    expect_equal(lire(avec$fichiers[[nom]]), lire(sans$fichiers[[nom]]))
  }
  unlink(c(d1, d2), recursive = TRUE)
})

for (lpb in c(1L, 4L, 30L)) {
  test_that(paste("foret \u00e0 trois \u00e9tats, blocs de", lpb, "lignes : identique au tableau entier masqu\u00e9"), {
    r <- reference_foret(orbites, dates, p_def, garde_3)
    dossier <- tempfile("detecter-")
    res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = lpb,
                               foret = foret_3)
    expect_equal(res$objets, r$post$table)
    expect_equal(lire(res$fichiers[["objets_raster"]]), as.vector(r$post$objet))
    d <- lire(res$fichiers[["dates"]])
    expect_equal(d, ifelse(as.vector(r$avant), as.vector(r$comb$date_min), NA_integer_))
    # Rien hors forêt : ni date, ni ratio, ni objet (NA du masque = non-forêt).
    hors <- !as.vector(garde_3)
    expect_true(all(is.na(d[hors])))
    expect_true(all(is.na(lire(res$fichiers[["ratio"]])[hors])))
    expect_true(all(is.na(lire(res$fichiers[["objets_raster"]])[hors])))
    unlink(dossier, recursive = TRUE)
  })
}

test_that("foret : la coupe hors for\u00eat dispara\u00eet, la coupe en for\u00eat reste", {
  dossier <- tempfile("detecter-")
  sans <- nemetonsar_detecter(orbites, dates, tempfile("detecter-"), lignes_par_bloc = 5)
  res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = 5, foret = foret_3)
  # Sans masque : 3 objets ; la coupe en L (lignes 25-30, NA du masque) et
  # la coupe de l'orbite descendante (colonnes 1-7, non-forêt) disparaissent ;
  # la grande coupe (colonnes 4-11) garde sa partie en forêt (colonnes 8-11).
  expect_equal(nrow(sans$objets), 3L)
  expect_equal(nrow(res$objets), 1L)
  ecart <- abs(as.numeric(res$objets$date_mediane_date - as.Date("2019-06-15")))
  expect_lte(ecart, 24)
  o <- matrix(lire(res$fichiers[["objets_raster"]]), nrow = nc)
  expect_true(all(is.na(o[1:7, ])))
  expect_true(any(!is.na(o[8:11, 6:17])))
  unlink(dossier, recursive = TRUE)
})

test_that("foret : FALSE partout et NA partout donnent le m\u00eame r\u00e9sultat vide", {
  for (v in list(FALSE, NA)) {
    f <- terra::rast(grille_utm(nl, nc), vals = v)
    if (isFALSE(v)) f <- f == 1
    dossier <- tempfile("detecter-")
    res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = 6, foret = f)
    expect_equal(nrow(res$objets), 0L)
    expect_true(all(is.na(lire(res$fichiers[["dates"]]))))
    expect_false("objets" %in% names(res$fichiers))
    unlink(dossier, recursive = TRUE)
  }
})

test_that("foret : entr\u00e9es invalides refus\u00e9es", {
  d <- tempfile("detecter-")
  expect_error(nemetonsar_detecter(orbites, dates, d, foret = TRUE), "foret")
  deux <- terra::rast(grille_utm(nl, nc), nlyrs = 2, vals = 1)
  expect_error(nemetonsar_detecter(orbites, dates, d, foret = deux), "une couche")
  autre <- terra::rast(grille_utm(nl, nc + 1), vals = 1)
  expect_error(nemetonsar_detecter(orbites, dates, d, foret = autre), "grille")
  expect_false(dir.exists(d))
})

# Mission 016 -------------------------------------------------------------------

test_that("connexité 8 : deux coupes qui ne se touchent qu'en diagonale, de part et d'autre d'une limite de bloc", {
  # Coupe A : lignes 5 à 10, colonnes 3 à 8 ; coupe B : lignes 11 à 16,
  # colonnes 9 à 14. Elles ne se touchent que par le coin (10, 8)-(11, 9).
  # Avec des blocs de 10 lignes, ce coin est à cheval sur la limite des
  # deux premiers blocs : seule l'arête diagonale entre bandes les relie.
  coupes_diag <- list(
    list(lignes = 5:10, colonnes = 3:8, date = as.Date("2019-06-15")),
    list(lignes = 11:16, colonnes = 9:14, date = as.Date("2019-06-15"))
  )
  o <- list(
    asc = pile_synthetique(20, 16, dates_a, coupes_diag, 11),
    desc = pile_synthetique(20, 16, dates_d, coupes_diag, 12)
  )
  for (cx in c(8L, 4L)) {
    # Sans filtre spatial (fenêtre 1), les bords des coupes restent nets.
    p <- parametres_sufosat(connexite = cx, fenetre_filtre = 1L)
    r <- reference(o, list(dates_a, dates_d), p)
    for (lpb in c(10L, 3L, 20L)) {
      dossier <- tempfile("detecter-")
      res <- nemetonsar_detecter(o, list(dates_a, dates_d), dossier, parametres = p,
                                 lignes_par_bloc = lpb)
      expect_equal(nrow(res$objets), if (cx == 8L) 1L else 2L)
      expect_equal(lire(res$fichiers[["objets_raster"]]), as.vector(r$post$objet))
      expect_equal(res$objets, r$post$table)
      unlink(dossier, recursive = TRUE)
    }
  }
  # En connexité 8, l'objet unique couvre les deux coupes (2 x 36 pixels).
  res <- nemetonsar_detecter(o, list(dates_a, dates_d), tempfile("detecter-"),
                             parametres = parametres_sufosat(fenetre_filtre = 1L),
                             lignes_par_bloc = 10L)
  expect_identical(res$objets$nb_pixels, 72L)
})

test_that("mission 016 : sorties figées avant optimisation (empreinte)", {
  # Empreinte des sorties calculée avec le code d'avant la mission 016 (x86_64,
  # R 4.3.3) ; cumsum() accumule en long double, d'où la restriction.
  skip_if_not(R.version$arch == "x86_64", "empreinte calculée sur x86_64")
  empreinte <- function(...) {
    f <- tempfile()
    con <- file(f, "wb")
    for (x in list(...)) writeBin(as.vector(x), con, endian = "little")
    close(con)
    on.exit(unlink(f))
    unname(tools::md5sum(f))
  }
  attendu <- c("7" = "1331e266ee09802e51d7ef3502b8a073", "30" = "dcb3811021ea89a0485800510704d14b")
  for (lpb in c(7L, 30L)) {
    dossier <- tempfile("detecter-")
    res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = lpb)
    expect_identical(
      empreinte(lire(res$fichiers[["dates"]]), lire(res$fichiers[["ratio"]]),
                lire(res$fichiers[["objets_raster"]]), res$objets$nb_pixels,
                res$objets$nb_pixels_dates, res$objets$date_mediane,
                res$objets$ratio_moyen_db),
      attendu[[as.character(lpb)]]
    )
    unlink(dossier, recursive = TRUE)
  }
})

test_that("mission 016 : médiane des dates par objet, cas limites", {
  # Comptes agrégés à la main : objet 1 = dates 19100 (x2), 19200 (x3) ;
  # objet 2 = 19050 (x1), 19300 (x1) -> médiane basse 19050 ; objet 3 sans
  # date ; deux étiquettes de bande pour l'objet 1, réparties sur deux blocs.
  paires <- list(
    list(cle = c(1 * 1e5 + 19100, 1 * 1e5 + 19200, 3 * 1e5 + 19050), n = c(2L, 1L, 1L)),
    list(cle = c(2 * 1e5 + 19200, 3 * 1e5 + 19300), n = c(2L, 1L))
  )
  somme_lin <- list(list(lab = integer(0), lin = numeric(0)))
  tab <- table_objets_blocs(c(1L, 1L, 2L, 3L), 3L, c(4, 3, 2, 5), 100, paires, somme_lin)
  expect_identical(tab$nb_pixels_dates, c(5L, 2L, 0L))
  expect_identical(tab$date_mediane, c(19200L, 19050L, NA))
  expect_equal(tab$date_mediane_date, yyddd_vers_date(c(19200L, 19050L, NA)))
})

# Mission 018 -------------------------------------------------------------------

# Arrondi d'un réel double au réel 32 bits le plus proche (celui d'un FLT4S).
en_flt4s <- function(x) readBin(writeBin(x, raw(), size = 4), "double", size = 4, n = length(x))

test_that("mission 018 : ratio à moins de 1e-6 dB d'un seuil, détection brute puis segmenter_blocs() identique", {
  # Un pixel détecté dont le ratio double r arrondi en réel 32 bits monte
  # (f > r) ; le seuil tp est placé entre les deux (et ts 0,1 dB dessous) :
  # en double le pixel est dans la zone, en réel 32 bits il n'y est plus.
  r <- as.vector(ref$comb$ratio_min_db)
  f <- en_flt4s(r)
  cand <- which(as.vector(ref$avant) & !is.na(r) & f > r)
  expect_gt(length(cand), 0L)
  i <- cand[which.max(r[cand])]
  tp_eff <- (r[i] + f[i]) / 2
  p <- parametres_sufosat(tp_db = tp_eff / p_def$facteur_seuil,
                          ts_db = (tp_eff - 0.1) / p_def$facteur_seuil)
  s <- seuils_db(p)
  expect_true(r[i] <= s[["tp"]] && f[i] > s[["tp"]])
  expect_lt(abs(r[i] - s[["tp"]]), 1e-6)
  # Donnée : les pixels qui ont un ratio (comme dans nemetonsar_detecter()).
  donnee <- terra::rast(grille_utm(nl, nc), vals = as.integer(!is.na(r)))
  for (lpb in c(1L, 7L, 30L)) {
    direct <- nemetonsar_detecter(orbites, dates, tempfile("det-"), p, lignes_par_bloc = lpb)
    # Le pixel est bien dans un objet, avec sa date.
    expect_false(is.na(lire(direct$fichiers[["dates"]])[i]))
    brut <- detection_brute(orbites, dates, tempfile("brut-"), parametres_bruts(p), lpb, NULL)
    seg <- segmenter_blocs(terra::rast(brut[["ratio"]]), terra::rast(brut[["dates"]]), donnee,
                           p, tempfile("seg-"), lpb, gpkg = TRUE)
    for (n in c("dates", "ratio", "objets_raster")) {
      expect_identical(lire(seg$fichiers[[n]]), lire(direct$fichiers[[n]]))
    }
    expect_identical(seg$objets[, names(seg$objets) != "date_mediane_date"],
                     direct$objets[, names(direct$objets) != "date_mediane_date"])
    expect_equal(seg$objets$date_mediane_date, direct$objets$date_mediane_date)
  }
})

# Mission 021 : orbites en parallèle dans la passe 1 ---------------------------

# Troisième orbite (ascendante, autre bruit) pour les essais à trois orbites.
orbites3 <- c(orbites, list(asc2 = pile_synthetique(nl, nc, dates_a, coupes, 3)))
dates3 <- c(dates, list(dates_a))

# Toutes les sorties d'un appel, pour une comparaison au bit près.
sorties_detecter <- function(res) {
  c(lapply(res$fichiers[c("dates", "ratio", "objets_raster")], lire),
    list(objets = res$objets, lignes_par_bloc = res$lignes_par_bloc))
}

test_that("mission 021 : nombre de processus (d\u00e9faut, bornes, entr\u00e9es invalides)", {
  ancien <- Sys.getenv("_R_CHECK_LIMIT_CORES_", NA)
  on.exit(if (is.na(ancien)) Sys.unsetenv("_R_CHECK_LIMIT_CORES_") else
    Sys.setenv("_R_CHECK_LIMIT_CORES_" = ancien), add = TRUE)
  Sys.unsetenv("_R_CHECK_LIMIT_CORES_")
  local_mocked_bindings(fork_disponible = function() TRUE)
  coeurs <- parallel::detectCores()
  attendu <- if (is.na(coeurs)) 1L else min(3L, max(1L, coeurs - 1L))
  expect_identical(nb_processus(NULL, 3L), attendu)
  expect_identical(nb_processus(NULL, 1L), 1L)
  expect_identical(nb_processus(8, 3L), 3L)
  expect_identical(nb_processus(1L, 3L), 1L)
  Sys.setenv("_R_CHECK_LIMIT_CORES_" = "TRUE")
  expect_identical(nb_processus(8, 3L), 2L)
  Sys.setenv("_R_CHECK_LIMIT_CORES_" = "false")
  expect_identical(nb_processus(8, 3L), 3L)
  local_mocked_bindings(fork_disponible = function() FALSE)
  expect_identical(nb_processus(8, 3L), 1L)
  for (mauvais in list(0, -1, 1.5, NA, "2", c(1, 2), Inf)) {
    expect_error(nb_processus(mauvais, 3L), "processus")
  }
  expect_error(nemetonsar_detecter(orbites, dates, tempfile("det-"), processus = 0),
               "processus")
})

for (k in 1:3) {
  test_that(paste("mission 021 :", k, "orbite(s), s\u00e9rie et parall\u00e8le identiques au bit pr\u00e8s"), {
    skip_on_os("windows")
    o <- orbites3[seq_len(k)]
    d <- dates3[seq_len(k)]
    for (lpb in c(1L, 7L, 30L)) {
      serie <- nemetonsar_detecter(o, d, tempfile("det-"), lignes_par_bloc = lpb,
                                   processus = 1L)
      for (np in unique(c(2L, k))) {
        para <- nemetonsar_detecter(o, d, tempfile("det-"), lignes_par_bloc = lpb,
                                    processus = np)
        expect_identical(sorties_detecter(para), sorties_detecter(serie))
      }
      # Le défaut (NULL) donne aussi le même résultat.
      defaut <- nemetonsar_detecter(o, d, tempfile("det-"), lignes_par_bloc = lpb)
      expect_identical(sorties_detecter(defaut), sorties_detecter(serie))
    }
  })
}

test_that("mission 021 : parall\u00e8le avec masque for\u00eat identique \u00e0 la s\u00e9rie", {
  skip_on_os("windows")
  set.seed(21)
  foret <- terra::rast(grille_utm(nl, nc),
                       vals = sample(c(TRUE, FALSE, NA), nl * nc, replace = TRUE,
                                     prob = c(0.7, 0.2, 0.1)))
  for (lpb in c(2L, 11L)) {
    serie <- nemetonsar_detecter(orbites3, dates3, tempfile("det-"), lignes_par_bloc = lpb,
                                 foret = foret, processus = 1L)
    para <- nemetonsar_detecter(orbites3, dates3, tempfile("det-"), lignes_par_bloc = lpb,
                                foret = foret, processus = 3L)
    expect_identical(sorties_detecter(para), sorties_detecter(serie))
  }
})

test_that("mission 021 : sans fork, repli en s\u00e9rie, identique", {
  serie <- nemetonsar_detecter(orbites3, dates3, tempfile("det-"), lignes_par_bloc = 7L,
                               processus = 1L)
  local_mocked_bindings(
    fork_disponible = function() FALSE,
    orbites_en_parallele = function(...) stop("le repli en s\u00e9rie n'a pas jou\u00e9")
  )
  for (np in list(NULL, 3L)) {
    repli <- nemetonsar_detecter(orbites3, dates3, tempfile("det-"), lignes_par_bloc = 7L,
                                 processus = np)
    expect_identical(sorties_detecter(repli), sorties_detecter(serie))
  }
})

test_that("mission 021 : une erreur dans un processus enfant remonte clairement", {
  skip_on_os("windows")
  local_mocked_bindings(rcr_compute = function(...) stop("panne simul\u00e9e"))
  expect_error(
    nemetonsar_detecter(orbites, dates, tempfile("det-"), lignes_par_bloc = 7L, processus = 2L),
    "Orbite asc \\(lignes 1 .+ 8\\) : erreur dans le processus enfant.*panne simul"
  )
})

test_that("mission 021 : un processus enfant mort sans r\u00e9sultat remonte clairement", {
  skip_on_os("windows")
  local_mocked_bindings(rcr_compute = function(...) tools::pskill(Sys.getpid(), tools::SIGKILL))
  expect_error(
    nemetonsar_detecter(orbites, dates, tempfile("det-"), lignes_par_bloc = 7L, processus = 2L),
    "Orbite asc \\(lignes 1 .+ 8\\) : le processus enfant .*sans r"
  )
})
