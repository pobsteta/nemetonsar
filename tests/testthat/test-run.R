skip_if_not_installed("terra")

# Le dernier test (essai réel) interroge le Planetary Computer ; il ne tourne
# que si NEMETONSAR_TESTS_RESEAU vaut "true" :
#   NEMETONSAR_TESTS_RESEAU=true Rscript -e 'testthat::test_local(filter = "run")'

# Bout en bout sur entrées synthétiques, sans réseau : une AOI de
# 1 km x 0,55 km à cheval sur le méridien 0 (zones UTM 30 et 31, deux
# tuiles), des images lues par une fonction `lire_images` qui fabrique des
# GeoTIFF sur la grille de chaque tuile, un TCD et des surfaces brûlées
# EFFIS synthétiques.

rect_ll <- function(x1, x2, y1, y2) {
  terra::vect(sprintf("POLYGON ((%.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f))",
                      x1, y1, x2, y1, x2, y2, x1, y2, x1, y1), crs = "EPSG:4326")
}

aoi_2z <- rect_ll(-0.006, 0.006, 44.500, 44.505)
# Coupes (-6 dB à partir de la date) :
coupes_run <- list(
  # c1 : à cheval sur les deux zones UTM (deux tuiles)
  c1 = list(v = rect_ll(-0.0012, 0.0012, 44.5015, 44.5025), date = as.Date("2019-06-15")),
  # c2 : hors forêt (TCD 5 %), zone 30
  c2 = list(v = rect_ll(-0.0050, -0.0035, 44.5030, 44.5042), date = as.Date("2019-09-01")),
  # c3 : brûlée (EFFIS), zone 31
  c3 = list(v = rect_ll(0.0030, 0.0045, 44.5005, 44.5017), date = as.Date("2020-02-01")),
  # c4 : coupe ordinaire, zone 31
  c4 = list(v = rect_ll(0.0025, 0.0045, 44.5030, 44.5042), date = as.Date("2020-03-15"))
)
dates_asc <- seq(as.Date("2018-01-03"), as.Date("2020-06-30"), by = 12)
dates_desc <- seq(as.Date("2018-01-09"), as.Date("2020-06-30"), by = 12)

# Lecteur d'images injecté : deux orbites, fond 0,05 (linéaire) et bruit
# gamma faible, coupes rasterisées sur la grille de la tuile (centres des
# cellules), une pile GeoTIFF par orbite dans `dossier`. Note les appels.
# Chaque coupe baisse le signal de `db` dB (défaut -6) à partir de sa date ;
# des coupes qui se recouvrent cumulent leurs baisses.
appels <- new.env()
lecteur <- function(coupes) {
  function(grille, date_debut, date_fin, parametres, dossier) {
    appels$debut <- c(appels$debut, format(date_debut))
    appels$fin <- c(appels$fin, format(date_fin))
    dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
    series <- list(A030 = dates_asc, D008 = dates_desc)
    orbites <- list()
    dates <- list()
    items <- list()
    for (k in seq_along(series)) {
      s <- names(series)[k]
      d <- series[[s]]
      d <- d[d >= date_debut & d <= date_fin]
      set.seed(round(terra::xmin(grille)) %% 100000 + k)
      n <- terra::ncell(grille)
      v <- matrix(0.05 * stats::rgamma(n * length(d), 200, 200), nrow = n)
      for (cp in coupes) {
        dedans <- terra::values(terra::rasterize(terra::project(cp$v, terra::crs(grille)), grille,
                                                 background = 0, touches = FALSE),
                                mat = FALSE) == 1
        apres <- d >= cp$date
        db <- if (is.null(cp$db)) -6 else cp$db
        v[dedans, apres] <- v[dedans, apres] * 10^(db / 10)
      }
      r <- terra::rast(grille, nlyrs = length(d))
      terra::values(r) <- v
      names(r) <- format(d)
      f <- file.path(dossier, paste0("s1_", s, ".tif"))
      terra::writeRaster(r, f, overwrite = TRUE, datatype = "FLT4S")
      orbites[[s]] <- terra::rast(f)
      dates[[s]] <- d
      items[[s]] <- data.frame(id = paste0("SYNTH_", s, "_", format(d, "%Y%m%d")), date = d,
                               capteur = "S1A", orbite = as.integer(substr(s, 2, 4)),
                               direction = if (k == 1) "ascendante" else "descendante",
                               serie = s, stringsAsFactors = FALSE)
    }
    items <- do.call(rbind, items)
    rownames(items) <- NULL
    list(orbites = orbites, dates = dates, attribution = s1_attribution(items$date),
         items = items)
  }
}
lire_synthetique <- lecteur(coupes_run)

# TCD synthétique (EPSG:3035, 10 m) : 60 % partout, 5 % autour de c2.
tcd_run <- local({
  e <- terra::ext(terra::project(aoi_2z, "EPSG:3035")) + 200
  r <- terra::rast(e, resolution = 10, crs = "EPSG:3035")
  non_foret <- terra::buffer(terra::project(coupes_run$c2$v, "EPSG:3035"), 30)
  m <- terra::rasterize(non_foret, r, background = 0, touches = TRUE)
  f <- tempfile(fileext = ".tif")
  terra::writeRaster(terra::ifel(m == 1, 5, 60), f, datatype = "INT1U")
  terra::rast(f)
})

# EFFIS synthétique : c3 brûlée en 2019 (année précédant sa coupe : retirée),
# c1 brûlée en 2017 (hors appariement : gardée).
effis_run <- function(annee_c3 = 2019L) {
  v <- rbind(terra::buffer(terra::project(coupes_run$c3$v, "EPSG:3035"), 20),
             terra::project(coupes_run$c1$v, "EPSG:3035"))
  v$annee <- c(annee_c3, 2017L)
  v
}

# Objets de la carte finale qui touchent une coupe.
objets_sur <- function(res, nom) {
  if (nrow(res$objets) == 0L) return(integer(0))
  o <- terra::rast(res$fichiers[["objets_raster"]])
  v <- terra::extract(o, terra::project(coupes_run[[nom]]$v, "EPSG:2154"))
  sort(unique(stats::na.omit(v[[2]])))
}
candidats <- function(date) {
  c(dates_asc[dates_asc >= date][1], dates_desc[dates_desc >= date][1])
}

dossier_principal <- tempfile("run-")
appels$debut <- NULL
res <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", dossier_principal,
                      tcd = tcd_run, effis = effis_run(),
                      lire_images = lire_synthetique)

test_that("deux tuiles dans deux zones UTM, images lues depuis l'ann\u00e9e du noyau", {
  expect_equal(nrow(res$tuiles), 2L)
  expect_setequal(substr(res$tuiles$mgrs, 1, 2), c("30", "31"))
  expect_equal(res$tuiles$nb_orbites, c(2L, 2L))
  # Fenêtre des images : 1er janvier de annee_noyau (2018) -> date_fin.
  expect_equal(as.Date(appels$debut), rep(as.Date("2018-01-01"), 2))
  expect_equal(as.Date(appels$fin), rep(as.Date("2020-06-30"), 2))
  expect_true(all(res$tuiles$passe_2019))
})

test_that("sorties en Lambert-93 : fichiers, grille, types, codes YYDDD", {
  f <- res$fichiers
  expect_setequal(names(f), c("dates", "ratio", "objets_raster", "objets", "journal"))
  expect_true(all(file.exists(f)))
  for (n in c("dates", "ratio", "objets_raster")) {
    r <- terra::rast(f[[n]])
    expect_true(terra::same.crs(r, "EPSG:2154"))
    expect_equal(terra::res(r), c(10, 10))
    expect_equal(terra::xmin(r) %% 10, 0)
    expect_equal(terra::ymin(r) %% 10, 0)
  }
  expect_identical(terra::datatype(terra::rast(f[["dates"]])), "INT4S")
  expect_identical(terra::datatype(terra::rast(f[["objets_raster"]])), "INT4S")
  expect_identical(terra::datatype(terra::rast(f[["ratio"]])), "FLT4S")
  d <- terra::values(terra::rast(f[["dates"]]), mat = FALSE)
  codes <- unique(d[!is.na(d)])
  expect_true(length(codes) > 0L)
  expect_equal(date_vers_yyddd(yyddd_vers_date(codes)), codes)
  # L'AOI est couverte par la grille.
  e_aoi <- terra::ext(terra::project(aoi_2z, "EPSG:2154"))
  e_r <- terra::ext(terra::rast(f[["dates"]]))
  expect_true(e_r$xmin <= e_aoi$xmin && e_r$xmax >= e_aoi$xmax &&
                e_r$ymin <= e_aoi$ymin && e_r$ymax >= e_aoi$ymax)
  # Aucun fichier temporaire laissé.
  expect_length(list.files(dossier_principal, pattern = "nemetonsar_tmp", all.files = TRUE,
                           recursive = TRUE), 0L)
  # Par tuile : grille UTM, masque, détection.
  for (m in res$tuiles$mgrs) {
    dt <- file.path(dossier_principal, "tuiles", m)
    # Détection brute : ratio en réel 64 bits, aucun GeoPackage (mission 018).
    for (b in c("detection/brut", "passe_2019/brut")) {
      expect_setequal(list.files(file.path(dt, b), all.files = TRUE, no.. = TRUE),
                      c("dates.tif", "ratio.tif", "objets.tif"))
      expect_identical(terra::datatype(terra::rast(file.path(dt, b, "ratio.tif"))), "FLT8S")
    }
    expect_true(all(file.exists(file.path(dt, c("dates.tif", "ratio.tif", "objets.tif",
                                                 "masque.tif", "detection/dates.tif",
                                                 "passe_2019/dates.tif")))))
    epsg <- if (substr(m, 1, 2) == "30") "EPSG:32630" else "EPSG:32631"
    expect_true(terra::same.crs(terra::rast(file.path(dt, "dates.tif")), epsg))
  }
})

test_that("coupe \u00e0 cheval sur deux tuiles : un seul objet, entier", {
  ids <- objets_sur(res, "c1")
  expect_length(ids, 1L)
  o <- res$objets[res$objets$identifiant == ids, ]
  # Surface vraie : celle de la même coupe détectée sur une seule grille
  # Lambert-93, sans limite de tuile (nemetonsar_detecter(), mêmes images
  # synthétiques). Chaque pixel Lambert-93 étant pris à une seule tuile, la
  # carte assemblée la retrouve à l'échantillonnage près des deux grilles
  # (mesuré : 156 pixels contre 154). 014 tolérait 0,12 ha (un pixel en
  # double par ligne, 166 pixels). La tolérance de 2 pixels est une
  # non-régression (l'écart mesuré), pas une règle de la méthode.
  pl <- terra::project(coupes_run$c1$v, "EPSG:2154")
  g <- terra::crop(terra::rast(terra::rast(res$fichiers[["objets_raster"]])),
                   terra::ext(terra::buffer(pl, 100)), snap = "out")
  im <- lire_synthetique(g, as.Date("2018-01-01"), as.Date("2020-06-30"), parametres_sufosat(),
                         tempfile("img-"))
  ref <- nemetonsar_detecter(im$orbites, im$dates, tempfile("det-"))
  r_ref <- terra::rast(ref$fichiers[["objets_raster"]])
  id_ref <- unique(stats::na.omit(terra::extract(r_ref, pl)[[2]]))
  expect_length(id_ref, 1L)
  expect_lte(abs(o$nb_pixels - ref$objets$nb_pixels[id_ref]), 2)
  attendu_ha <- terra::expanse(coupes_run$c1$v, unit = "ha")
  expect_gt(o$surface_ha, 0.6 * attendu_ha)
  expect_lt(o$surface_ha, 1.05 * attendu_ha)
  expect_true(o$date_mediane_date %in% candidats(coupes_run$c1$date))
  # Les deux tuiles en ont chacune une partie.
  for (m in res$tuiles$mgrs) {
    r <- terra::rast(file.path(dossier_principal, "tuiles", m, "objets.tif"))
    v <- terra::extract(r, terra::project(coupes_run$c1$v, terra::crs(r)))
    expect_true(any(!is.na(v[[2]])))
  }
})

# Coupes à la limite de deux tuiles (mission 015) ----------------------------
# Sans TCD ni EFFIS. c5 : 0,18 ha détectés, 0,09 ha de chaque côté du
# méridien 0 ; c6 : zone à -4 dB à cheval (sans graine), graine (-7 dB)
# seulement à l'est.
coupes_lim <- list(
  c5 = list(v = rect_ll(-0.00032, 0.00032, 44.5010, 44.50150), date = as.Date("2019-06-15")),
  c6 = list(v = rect_ll(-0.0008, 0.0008, 44.5030, 44.5036), date = as.Date("2019-09-01"), db = -4),
  c6g = list(v = rect_ll(0.0002, 0.0006, 44.50310, 44.50350), date = as.Date("2019-09-01"), db = -3)
)
dossier_lim <- tempfile("run-lim-")
res_lim <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", dossier_lim,
                          lire_images = lecteur(coupes_lim))

# Identifiants des objets de la carte finale qui touchent un polygone.
objets_dans <- function(res, v) {
  if (nrow(res$objets) == 0L) return(integer(0))
  o <- terra::rast(res$fichiers[["objets_raster"]])
  sort(unique(stats::na.omit(terra::extract(o, terra::project(v, "EPSG:2154"))[[2]])))
}
# Longitudes des centres des pixels d'un objet de la carte finale.
longitudes <- function(res, id) {
  o <- terra::rast(res$fichiers[["objets_raster"]])
  xy <- terra::xyFromCell(o, which(terra::values(o, mat = FALSE) %in% id))
  terra::crds(terra::project(terra::vect(xy, crs = "EPSG:2154"), "EPSG:4326"))[, 1]
}
# Pixels d'un polygone dans les objets de la détection d'une tuile.
pixels_tuile <- function(dossier, m, v) {
  r <- terra::rast(file.path(dossier, "tuiles", m, "detection", "objets.tif"))
  sum(!is.na(terra::extract(r, terra::project(v, terra::crs(r)))[[2]]))
}

test_that("coupe de 0,18 ha en deux parties de 0,09 ha : un seul objet", {
  # Chaque tuile n'en voit que 0,09 ha : sa détection la perd.
  for (m in res_lim$tuiles$mgrs) expect_equal(pixels_tuile(dossier_lim, m, coupes_lim$c5$v), 0)
  ids <- objets_dans(res_lim, coupes_lim$c5$v)
  expect_length(ids, 1L)
  o <- res_lim$objets[res_lim$objets$identifiant == ids, ]
  expect_gte(o$surface_ha, 0.1)
  expect_true(o$date_mediane_date %in% candidats(coupes_lim$c5$date))
  lon <- longitudes(res_lim, ids)
  expect_true(any(lon < 0) && any(lon > 0))
})

test_that("coupe dont la seule graine est d'un c\u00f4t\u00e9 : sortie enti\u00e8re", {
  ouest <- res_lim$tuiles$mgrs[substr(res_lim$tuiles$mgrs, 1, 2) == "30"]
  est <- res_lim$tuiles$mgrs[substr(res_lim$tuiles$mgrs, 1, 2) == "31"]
  # La tuile ouest n'a pas de graine : elle ne garde rien ; la tuile est garde sa partie.
  expect_equal(pixels_tuile(dossier_lim, ouest, coupes_lim$c6$v), 0)
  expect_gt(pixels_tuile(dossier_lim, est, coupes_lim$c6$v), 0)
  ids <- objets_dans(res_lim, coupes_lim$c6$v)
  expect_length(ids, 1L)
  o <- res_lim$objets[res_lim$objets$identifiant == ids, ]
  expect_true(o$date_mediane_date %in% candidats(coupes_lim$c6$date))
  # Les deux moitiés : autant de pixels à l'ouest qu'à l'est, à la graine près.
  lon <- longitudes(res_lim, ids)
  expect_gte(sum(lon < 0), 25L)
  expect_lte(abs(sum(lon < 0) - sum(lon > 0)), 0.25 * length(lon))
  expect_length(objets_dans(res_lim, coupes_lim$c5$v), 1L)
  expect_equal(nrow(res_lim$objets), 2L)
})

test_that("aucun pixel compt\u00e9 deux fois : AOI enti\u00e8rement coup\u00e9e, \u00e0 cheval", {
  aoi_p <- rect_ll(-0.0015, 0.0015, 44.5000, 44.5015)
  tout <- list(t = list(v = rect_ll(-0.01, 0.01, 44.49, 44.51), date = as.Date("2019-06-15")))
  r <- nemetonsar_run(aoi_p, "2019-01-01", "2020-06-30", tempfile("run-"),
                      lire_images = lecteur(tout))
  expect_equal(nrow(r$tuiles), 2L)
  expect_equal(nrow(r$objets), 1L)
  o <- terra::rast(r$fichiers[["objets_raster"]])
  # Pixels Lambert-93 dont le centre est dans l'AOI : chacun une fois, aucun autre.
  dans <- terra::values(terra::rasterize(terra::project(terra::densify(aoi_p, 10), "EPSG:2154"),
                                         o, background = 0, touches = FALSE), mat = FALSE) == 1
  v <- terra::values(o, mat = FALSE)
  expect_true(all(!is.na(v[dans])))
  expect_true(all(is.na(v[!dans])))
  expect_equal(r$objets$nb_pixels, sum(dans))
})

test_that("coupe hors for\u00eat absente, coupe br\u00fbl\u00e9e retir\u00e9e, coupe ordinaire gard\u00e9e", {
  expect_length(objets_sur(res, "c2"), 0L)
  expect_length(objets_sur(res, "c3"), 0L)
  expect_length(objets_sur(res, "c4"), 1L)
  expect_equal(nrow(res$objets), 2L)
  # c3 a bien été détectée puis retirée par le feu (EFFIS 2019, objet 2020).
  expect_equal(sum(res$feu$retire), 1L)
  r <- res$feu[res$feu$retire, ]
  expect_gte(r$part_brulee, 0.75)
  expect_equal(r$annee_objet, 2020L)
  # c1 : brûlée en 2017, hors appariement (2019 et 2018) : gardée.
  expect_false(any(res$feu$retire[res$feu$identifiant %in% objets_sur(res, "c1")]))
  expect_true(all(res$objets$part_brulee < 0.75))
  o4 <- res$objets[res$objets$identifiant == objets_sur(res, "c4"), ]
  expect_true(o4$date_mediane_date %in% candidats(coupes_run$c4$date))
})

test_that("GeoPackage : un polygone par objet, m\u00eames attributs que la table", {
  v <- terra::vect(res$fichiers[["objets"]], layer = "objets")
  expect_true(terra::same.crs(v, "EPSG:2154"))
  expect_equal(v$identifiant, res$objets$identifiant)
  expect_equal(v$surface_ha, res$objets$surface_ha)
  expect_equal(as.Date(v$date_mediane_date), res$objets$date_mediane_date)
  expect_equal(v$date_mediane, res$objets$date_mediane)
})

test_that("correction 2019 : pixels dat\u00e9s de 2019 retir\u00e9s de la for\u00eat, objet 2019 gard\u00e9", {
  m <- res$tuiles$mgrs[substr(res$tuiles$mgrs, 1, 2) == "31"]
  masque <- terra::rast(file.path(dossier_principal, "tuiles", m, "masque.tif"))
  d19 <- terra::values(terra::rast(file.path(dossier_principal, "tuiles", m, "passe_2019",
                                              "dates.tif")), mat = FALSE)
  v <- terra::values(masque, mat = FALSE)
  # Les pixels datés de 2019 par la première détection (codes 19xxx) ne sont
  # plus forêt pour la détection principale ; les autres pixels le restent.
  de_2019 <- !is.na(d19) & d19 %/% 1000 == 19
  expect_gt(sum(de_2019), 50)
  expect_true(all(v[de_2019] == 0))
  expect_true(sum(v == 1, na.rm = TRUE) > 0)
  det <- terra::rast(file.path(dossier_principal, "tuiles", m, "detection", "dates.tif"))
  d <- terra::extract(det, terra::project(coupes_run$c1$v, terra::crs(det)))[[2]]
  expect_true(all(is.na(d)))
  # c1 vient de la première détection : date de 2019.
  o <- res$objets[res$objets$identifiant == objets_sur(res, "c1"), ]
  expect_equal(o$date_mediane %/% 1000L, 19L)
})

test_that("journal d'ex\u00e9cution complet : images, param\u00e8tres, masques, licences", {
  j <- readLines(res$journal, encoding = "UTF-8")
  texte <- paste(j, collapse = "\n")
  expect_match(texte, "Statut : termin\u00e9", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "Dur\u00e9e : ", fixed = TRUE, useBytes = TRUE)
  # Toutes les images, par leur identifiant.
  ids <- paste0("SYNTH_A030_", format(dates_asc, "%Y%m%d"))
  expect_true(all(vapply(ids, grepl, logical(1), x = texte, fixed = TRUE)))
  # Paramètres.
  expect_match(texte, "xb_date", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "annee_noyau", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "2019-01-01 au 2020-06-30", fixed = TRUE, useBytes = TRUE)
  # Masques.
  expect_match(texte, "Masque neige : non appliqu\u00e9", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "Correction 2019 : premi\u00e8re d\u00e9tection", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "Masque feu : 1 objet(s) retir\u00e9(s)", fixed = TRUE, useBytes = TRUE)
  # Licences et attributions.
  expect_match(texte, "[S1] Contains modified Copernicus Sentinel data 2018-2020", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "[FOR] Generated using European Union's Copernicus Land Monitoring Service",
               fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "[FEU] EFFIS", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "[MET] M\u00e9thode : Mermoz et al. (2024)", fixed = TRUE, useBytes = TRUE)
  expect_match(texte, "[NEI] sans objet", fixed = TRUE, useBytes = TRUE)
  # Sorties.
  expect_match(texte, file.path(dossier_principal, "dates.tif"), fixed = TRUE, useBytes = TRUE)
})

test_that("identit\u00e9 avec nemetonsar_detecter() sur une seule tuile", {
  aoi_1 <- rect_ll(0.001, 0.006, 44.500, 44.505)
  dossier <- tempfile("run-")
  r1 <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", dossier, tcd = tcd_run,
                       correction_2019 = FALSE, lire_images = lire_synthetique,
                       lignes_par_bloc = 7)
  expect_equal(nrow(r1$tuiles), 1L)
  prep <- aoi_preparer(aoi_1)
  grille <- aoi_grille(prep)
  # Mêmes images, masque construit à part : TCD et morceau d'AOI.
  imgs <- lire_synthetique(grille, as.Date("2018-01-01"), as.Date("2020-06-30"),
                           parametres_sufosat(), tempfile("img-"))
  foret <- masque_foret(tcd_run, grille) &
    (terra::rasterize(prep$aoi[[1]], grille, background = 0) == 1)
  direct <- nemetonsar_detecter(imgs$orbites, imgs$dates, tempfile("det-"),
                                lignes_par_bloc = 7, foret = foret)
  dt <- file.path(dossier, "tuiles", prep$tuiles$mgrs)
  lire <- function(f) terra::values(terra::rast(f), mat = FALSE)
  # Identité exacte (mission 018 : ratio brut relu en double).
  for (n in c("dates", "ratio", "objets")) {
    expect_identical(lire(file.path(dt, "detection", paste0(n, ".tif"))),
                     lire(direct$fichiers[[if (n == "objets") "objets_raster" else n]]))
  }
  # Tous les objets sont dans la période : la tuile garde tout.
  expect_identical(lire(file.path(dt, "dates.tif")), lire(direct$fichiers[["dates"]]))
  expect_identical(lire(file.path(dt, "ratio.tif")), lire(direct$fichiers[["ratio"]]))
  expect_identical(lire(file.path(dt, "objets.tif")), lire(direct$fichiers[["objets_raster"]]))
  # Carte finale (Lambert-93) : mêmes objets, mêmes dates, surfaces proches.
  expect_equal(nrow(r1$objets), nrow(direct$objets))
  expect_equal(sort(r1$objets$date_mediane_date), sort(direct$objets$date_mediane_date))
  expect_equal(sort(r1$objets$surface_ha), sort(direct$objets$surface_ha), tolerance = 0.1)
})

test_that("d\u00e9tection brute puis segmenter_blocs() : identique \u00e0 nemetonsar_detecter()", {
  prep <- aoi_preparer(rect_ll(0.0005, 0.006, 44.500, 44.505))
  grille <- aoi_grille(prep)
  imgs <- lire_synthetique(grille, as.Date("2018-01-01"), as.Date("2020-06-30"),
                           parametres_sufosat(), tempfile("img-"))
  # Masque à trous (TCD, morceau d'AOI, une colonne de non-forêt d'un pixel
  # au milieu de c4 : la fermeture ne doit pas la combler).
  c4 <- terra::cells(grille, terra::project(coupes_run$c4$v, terra::crs(grille)))[, 2]
  colonne <- stats::median(terra::colFromCell(grille, c4))
  trou <- terra::rast(grille, vals = 0L)
  trou[intersect(c4, which(terra::colFromCell(grille, seq_len(terra::ncell(grille))) == colonne))] <- 1L
  trou <- trou == 1
  foret <- masque_foret(tcd_run, grille) & !trou &
    (terra::rasterize(prep$aoi[[1]], grille, background = 0) == 1)
  p <- parametres_sufosat()
  dossier_brut <- tempfile("brut-")
  brut <- detection_brute(imgs$orbites, imgs$dates, dossier_brut, parametres_bruts(p),
                          NULL, masque_foret(tcd_run, grille))
  # Mission 018 : ratio brut en réel 64 bits, aucun GeoPackage écrit.
  expect_identical(terra::datatype(terra::rast(brut[["ratio"]])), "FLT8S")
  expect_setequal(list.files(dossier_brut, all.files = TRUE, no.. = TRUE),
                  c("dates.tif", "ratio.tif", "objets.tif"))
  lire <- function(f) terra::values(terra::rast(f), mat = FALSE)
  for (lpb in list(NULL, 1L, 7L)) {
    direct <- nemetonsar_detecter(imgs$orbites, imgs$dates, tempfile("det-"), p,
                                  lignes_par_bloc = lpb, foret = foret)
    seg <- segmenter_blocs(terra::rast(brut[["ratio"]]), terra::rast(brut[["dates"]]), foret,
                           p, tempfile("seg-"), lpb, gpkg = TRUE)
    expect_gt(nrow(seg$objets), 0L)
    for (n in c("dates", "ratio", "objets_raster")) {
      expect_identical(lire(seg$fichiers[[n]]), lire(direct$fichiers[[n]]))
    }
    # Table identique, ratio moyen compris (plus de tolérance liée au FLT4S).
    sans_date <- function(t) t[, names(t) != "date_mediane_date"]
    expect_identical(sans_date(seg$objets), sans_date(direct$objets))
    expect_equal(seg$objets$date_mediane_date, direct$objets$date_mediane_date)
    expect_true(file.exists(seg$fichiers[["objets"]]))
  }
  # Paramètres bruts : seuils, surface et fermeture.
  pb <- parametres_bruts(p)
  expect_equal(seuils_db(pb)[["ts"]], seuils_db(p)[["tp"]])
  expect_gt(seuils_db(pb)[["tp"]], seuils_db(p)[["tp"]])
  expect_lt(seuils_db(pb)[["tp"]] - seuils_db(p)[["tp"]], 1e-8)
  expect_equal(pb$surface_min_ha, 0)
  expect_false(pb$fermeture)
})

test_that("p\u00e9riode, sans masque for\u00eat, appariement EFFIS hors ann\u00e9es", {
  dossier <- tempfile("run-")
  # Sans TCD : c2 est détectée. c3 brûlée en 2021 (après sa coupe de 2020) : gardée.
  r2 <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", dossier,
                       effis = effis_run(2021L), lire_images = lire_synthetique)
  for (n in c("c1", "c2", "c3", "c4")) expect_length(objets_sur(r2, n), 1L)
  expect_false(any(r2$feu$retire))
  expect_false(any(r2$tuiles$passe_2019))
  expect_match(paste(readLines(r2$journal), collapse = "\n"),
               "Masque for\u00eat : aucun", fixed = TRUE, useBytes = TRUE)
  # Période 2020 seule : les coupes de 2019 sortent.
  r3 <- nemetonsar_run(aoi_2z, "2020-01-01", "2020-06-30", tempfile("run-"),
                       lire_images = lire_synthetique)
  expect_length(objets_sur(r3, "c1"), 0L)
  expect_length(objets_sur(r3, "c2"), 0L)
  expect_length(objets_sur(r3, "c3"), 1L)
  expect_length(objets_sur(r3, "c4"), 1L)
  expect_true(all(r3$objets$date_mediane_date >= as.Date("2020-01-01")))
})

test_that("journal \u00e9crit m\u00eame si le calcul s'arr\u00eate", {
  dossier <- tempfile("run-")
  casse <- function(...) stop("lecture impossible")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", dossier,
                              lire_images = casse), "lecture impossible")
  j <- readLines(file.path(dossier, "journal.txt"), encoding = "UTF-8")
  expect_true(any(grepl("Statut : interrompu", j, fixed = TRUE, useBytes = TRUE)))
})

test_that("orbite sans image de l'ann\u00e9e du noyau \u00e9cart\u00e9e, tuile sans image", {
  sans_noyau <- function(grille, date_debut, date_fin, parametres, dossier) {
    x <- lire_synthetique(grille, date_debut, date_fin, parametres, dossier)
    garde <- x$dates$D008 >= as.Date("2019-01-01")
    x$orbites$D008 <- x$orbites$D008[[which(garde)]]
    x$dates$D008 <- x$dates$D008[garde]
    x
  }
  dossier <- tempfile("run-")
  r <- nemetonsar_run(rect_ll(0.001, 0.006, 44.500, 44.505), "2019-01-01", "2020-06-30",
                      dossier, lire_images = sans_noyau)
  expect_equal(r$tuiles$orbites_ecartees, 1L)
  expect_equal(r$tuiles$nb_orbites, 1L)
  expect_match(paste(readLines(r$journal), collapse = "\n"), "D008", fixed = TRUE, useBytes = TRUE)
  rien <- function(...) list(orbites = list(), dates = list(), attribution = NULL, items = NULL)
  r0 <- nemetonsar_run(rect_ll(0.001, 0.006, 44.500, 44.505), "2019-01-01", "2020-06-30",
                       tempfile("run-"), lire_images = rien)
  expect_equal(nrow(r0$objets), 0L)
  expect_false("objets" %in% names(r0$fichiers))
  expect_true(all(is.na(terra::values(terra::rast(r0$fichiers[["dates"]])))))
})

test_that("entr\u00e9es invalides refus\u00e9es", {
  d <- tempfile("run-")
  expect_error(nemetonsar_run(aoi_2z, "2020-01-01", "2019-01-01", d,
                              lire_images = lire_synthetique), "date_debut")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", NA_character_,
                              lire_images = lire_synthetique), "dossier")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d,
                              lire_images = "non"), "lire_images")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d,
                              correction_2019 = NA, lire_images = lire_synthetique),
               "correction_2019")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, effis = effis_run(),
                              effis_annee = "ANNEE", lire_images = lire_synthetique),
               "ANNEE")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d,
                              tcd = terra::rast(nrows = 2, ncols = 2, nlyrs = 2),
                              lire_images = lire_synthetique), "tcd")
  expect_false(dir.exists(d))
})

test_that("ann\u00e9e EFFIS lue d'un entier, d'une Date ou d'un texte", {
  expect_equal(annee_effis(c(2019, NA)), c(2019L, NA))
  expect_equal(annee_effis(as.Date(c("2019-07-01", NA))), c(2019L, NA))
  expect_equal(annee_effis(c("2018-08-12 00:00:00", "x", NA)), c(2018L, NA, NA))
})

# BD Forêt v2 comme masque forêt (mission 020) ---------------------------------

# BD Forêt synthétique en Lambert-93 : pin maritime pur sur toute l'AOI,
# lande (LA4) sur c2 élargie de 30 m (même rôle que le TCD à 5 % de tcd_run).
bdforet_run <- local({
  e <- terra::ext(terra::project(aoi_2z, "EPSG:2154")) + 200
  tout <- terra::as.polygons(e, crs = "EPSG:2154")
  lande <- terra::buffer(terra::project(coupes_run$c2$v, "EPSG:2154"), 30)
  foret <- terra::erase(tout, lande)
  v <- rbind(foret, lande)
  v$CODE_TFV <- c("FF2-51-51", "LA4")
  v
})

test_that("nemetonsar_run(bdforet = ...) : lande exclue, journal et attribution IGN", {
  dossier <- tempfile("run-bdf-")
  r <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", dossier,
                      bdforet = bdforet_run, effis = effis_run(),
                      lire_images = lire_synthetique)
  expect_length(objets_sur(r, "c2"), 0L)  # dans la lande : hors forêt
  expect_length(objets_sur(r, "c3"), 0L)  # brûlée
  expect_length(objets_sur(r, "c4"), 1L)
  expect_length(objets_sur(r, "c1"), 1L)
  expect_true(all(r$tuiles$passe_2019))   # correction 2019 faite
  j <- paste(readLines(r$journal, encoding = "UTF-8"), collapse = "\n")
  expect_match(j, "BD For\u00eat v2 de l'IGN (SpatVector fourni)", fixed = TRUE, useBytes = TRUE)
  expect_match(j, "LA4 (", fixed = TRUE, useBytes = TRUE)
  expect_match(j, "Correction 2019 : premi\u00e8re d\u00e9tection", fixed = TRUE, useBytes = TRUE)
  expect_match(j, "[FOR] Source : IGN, BD For\u00eat\u00ae version 2.0", fixed = TRUE, useBytes = TRUE)
  expect_match(j, "Licence Ouverte 2.0", fixed = TRUE, useBytes = TRUE)
  expect_false(grepl("Copernicus Land Monitoring", j, fixed = TRUE, useBytes = TRUE))
  expect_match(j, "reproduire avec les rasters et le GeoPackage : [S1] [FOR] [FEU]", fixed = TRUE,
               useBytes = TRUE)
})

test_that("nemetonsar_run(bdforet = ...) \u00e9quivaut \u00e0 un TCD qui donne le m\u00eame masque", {
  aoi_1 <- rect_ll(0.001, 0.006, 44.500, 44.505)
  # Lande sur c4 : exclue par les deux masques.
  lande <- terra::buffer(terra::project(coupes_run$c4$v, "EPSG:2154"), 20)
  tout <- terra::as.polygons(terra::ext(terra::project(aoi_1, "EPSG:2154")) + 200,
                             crs = "EPSG:2154")
  bdf <- rbind(terra::erase(tout, lande), lande)
  bdf$CODE_TFV <- c("FF1-00-00", "LA6")
  # TCD sur la grille de la tuile : 60 % là où la BD Forêt dit forêt, 5 % ailleurs.
  g <- aoi_grille(aoi_preparer(aoi_1))
  m <- masque_foret_bdforet(bdf, g)
  tcd <- terra::ifel(m, 60, 5)
  d_b <- tempfile("run-bdf-")
  d_t <- tempfile("run-tcd-")
  rb <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", d_b, bdforet = bdf,
                       lire_images = lire_synthetique)
  rt <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", d_t, tcd = tcd,
                       lire_images = lire_synthetique)
  expect_equal(rb$objets, rt$objets)
  expect_length(objets_sur(rb, "c4"), 0L)
  expect_length(objets_sur(rb, "c3"), 1L)
  for (n in c("dates", "ratio", "objets_raster")) {
    expect_equal(terra::values(terra::rast(rb$fichiers[[n]])),
                 terra::values(terra::rast(rt$fichiers[[n]])))
  }
  mgrs <- rb$tuiles$mgrs
  for (f in c("masque.tif", "foret.tif")) {
    expect_equal(terra::values(terra::rast(file.path(d_b, "tuiles", mgrs, f))),
                 terra::values(terra::rast(file.path(d_t, "tuiles", mgrs, f))))
  }
  # Fichier vecteur : même résultat que le SpatVector.
  fich <- tempfile(fileext = ".gpkg")
  terra::writeVector(bdf, fich)
  rf <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", tempfile("run-bdf-"), bdforet = fich,
                       lire_images = lire_synthetique)
  expect_equal(rf$objets, rb$objets)
  expect_match(paste(readLines(rf$journal), collapse = "\n"), fich, fixed = TRUE, useBytes = TRUE)
})

test_that("tcd et bdforet exclusifs ; bdforet invalide refus\u00e9", {
  d <- tempfile("run-")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, tcd = tcd_run,
                              bdforet = bdforet_run, lire_images = lire_synthetique),
               "exclusifs")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, bdforet = 42,
                              lire_images = lire_synthetique), "bdforet")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d,
                              bdforet = tempfile(fileext = ".gpkg"),
                              lire_images = lire_synthetique), "introuvable")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d,
                              bdforet = terra::centroids(bdforet_run),
                              lire_images = lire_synthetique), "polygones")
  expect_false(dir.exists(d))
})

# Lecture par bandes (mission 022) -----------------------------------------------

# Lecteur synthétique dont chaque valeur ne dépend que des coordonnées du
# centre de la cellule, de la date et de l'orbite (pas de la grille lue) :
# une bande lit exactement les valeurs de la tuile entière. Note la hauteur
# des grilles demandées.
lecteur_coord <- function(coupes, journal = new.env()) {
  function(grille, date_debut, date_fin, parametres, dossier) {
    journal$lignes <- c(journal$lignes, terra::nrow(grille))
    dir.create(dossier, showWarnings = FALSE, recursive = TRUE)
    series <- list(A030 = dates_asc, D008 = dates_desc)
    xy <- terra::xyFromCell(grille, seq_len(terra::ncell(grille)))
    i <- round(xy[, 1] / 5)
    j <- round(xy[, 2] / 5)
    orbites <- list()
    dates <- list()
    for (k in seq_along(series)) {
      s <- names(series)[k]
      d <- series[[s]]
      d <- d[d >= date_debut & d <= date_fin]
      v <- vapply(seq_along(d), function(t) {
        h <- (i * 7919 + j * 104729 + as.numeric(d[t]) * 15485863 + k * 49979687) %% 999983
        0.05 * stats::qgamma((h + 0.5) / 999983, 200, 200)
      }, numeric(length(i)))
      for (cp in coupes) {
        dedans <- terra::values(terra::rasterize(terra::project(cp$v, terra::crs(grille)), grille,
                                                 background = 0, touches = FALSE),
                                mat = FALSE) == 1
        apres <- d >= cp$date
        db <- if (is.null(cp$db)) -6 else cp$db
        v[dedans, apres] <- v[dedans, apres] * 10^(db / 10)
      }
      r <- terra::rast(grille, nlyrs = length(d))
      terra::values(r) <- v
      f <- file.path(dossier, paste0("s1_", s, ".tif"))
      terra::writeRaster(r, f, overwrite = TRUE, datatype = "FLT4S")
      orbites[[s]] <- terra::rast(f)
      dates[[s]] <- d
    }
    items <- data.frame(id = paste0("C_", rep(names(dates), lengths(dates)), "_",
                                    format(do.call(c, unname(dates)), "%Y%m%d")),
                        date = do.call(c, unname(dates)),
                        serie = rep(names(dates), lengths(dates)), stringsAsFactors = FALSE)
    list(orbites = orbites, dates = dates, attribution = s1_attribution(items$date), items = items)
  }
}

# Fichiers d'un dossier de sortie (chemins relatifs), fichiers cachés compris.
fichiers_de <- function(d) sort(list.files(d, recursive = TRUE, all.files = TRUE))

valeurs <- function(f) terra::values(terra::rast(f), mat = FALSE)

test_that("par bandes ou d'un seul tenant : r\u00e9sultats identiques au bit pr\u00e8s", {
  lec <- lecteur_coord(coupes_run)
  executer <- function(h) {
    d <- tempfile("run-bandes-")
    r <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, tcd = tcd_run,
                        effis = effis_run(), lire_images = lec, hauteur_bande = h)
    list(r = r, d = d)
  }
  ref <- executer(NULL)
  expect_true(all(ref$r$tuiles$passe_2019))
  expect_equal(ref$r$tuiles$nb_bandes, c(1L, 1L))
  expect_gt(nrow(ref$r$objets), 1L)
  for (h in c(7L, 23L, 1000L)) {
    x <- executer(h)
    expect_identical(x$r$objets, ref$r$objets)
    expect_identical(x$r$feu, ref$r$feu)
    garde <- setdiff(names(ref$r$tuiles), c("nb_bandes", "disque_images_mo", "disque_max_mo"))
    expect_identical(x$r$tuiles[garde], ref$r$tuiles[garde])
    expect_equal(x$r$tuiles$nb_bandes, rep(ceiling(58 / min(h, 58)), 2))
    # Mêmes fichiers, mêmes valeurs (sorties finales et par tuile, brutes comprises).
    expect_identical(fichiers_de(x$d), fichiers_de(ref$d))
    rasters <- grep("\\.tif$", fichiers_de(ref$d), value = TRUE)
    expect_true(all(c("dates.tif", "tuiles/30TYQ/detection/brut/ratio.tif",
                      "tuiles/31TBK/passe_2019/brut/dates.tif") %in% rasters))
    for (f in rasters) {
      expect_identical(valeurs(file.path(x$d, f)), valeurs(file.path(ref$d, f)), label = f)
    }
    g1 <- terra::vect(file.path(x$d, "objets.gpkg"))
    g0 <- terra::vect(file.path(ref$d, "objets.gpkg"))
    expect_identical(as.data.frame(g1), as.data.frame(g0))
    expect_identical(terra::geom(g1), terra::geom(g0))
  }
})

test_that("bandes : grilles demand\u00e9es, disque par bande, images et fichiers de bande effac\u00e9s", {
  j <- new.env()
  d <- tempfile("run-bandes-")
  r <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, tcd = tcd_run,
                      lire_images = lecteur_coord(coupes_run, j), hauteur_bande = 10L)
  # Deux tuiles de 58 lignes : 6 bandes chacune, de 10 lignes + 1 ligne de
  # bordure de chaque côté (rayon du filtre 3 x 3), rognées au bord.
  expect_equal(j$lignes, rep(c(11L, 12L, 12L, 12L, 12L, 9L), 2))
  expect_equal(r$tuiles$nb_bandes, c(6L, 6L))
  j0 <- new.env()
  d0 <- tempfile("run-bandes-")
  r0 <- nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d0, tcd = tcd_run,
                       lire_images = lecteur_coord(coupes_run, j0), hauteur_bande = NULL)
  expect_equal(j0$lignes, c(58L, 58L))
  # Disque maximal des images : celui d'une bande, bien moindre que la tuile.
  expect_true(all(r$tuiles$disque_images_mo > 0))
  expect_true(all(r$tuiles$disque_images_mo < r0$tuiles$disque_images_mo / 3))
  # Disque total : les images d'une bande plus le ratio et la date de la
  # tuile entière recollés (deux passes, correction 2019) et les sorties
  # d'une bande ; d'un seul tenant, les seules images.
  expect_true(all(r$tuiles$disque_max_mo > r$tuiles$disque_images_mo))
  expect_equal(r0$tuiles$disque_max_mo, r0$tuiles$disque_images_mo)
  # Rien ne reste des images ni des fichiers temporaires.
  for (x in c(d, d0)) {
    f <- fichiers_de(x)
    expect_false(any(grepl("(^|/)s1(/|$)", f)), label = x)
    expect_false(any(grepl(".nemetonsar_tmp", f, fixed = TRUE)), label = x)
    expect_false(any(dir.exists(file.path(x, "tuiles", r$tuiles$mgrs, "s1"))))
  }
  jt <- paste(readLines(r$journal), collapse = "\n")
  expect_match(jt, "Lecture par bandes : 6 bande(s) de 10 ligne(s)", fixed = TRUE, useBytes = TRUE)
  expect_match(jt, "disque maximal des images d'une bande", fixed = TRUE, useBytes = TRUE)
  expect_match(jt, "par bandes de 10 lignes de la tuile", fixed = TRUE, useBytes = TRUE)
  expect_match(paste(readLines(r0$journal), collapse = "\n"), "d'un seul tenant", fixed = TRUE,
               useBytes = TRUE)
})

test_that("bandes : une zone dont la seule graine est dans la bande voisine sort enti\u00e8re", {
  aoi_1 <- rect_ll(0.001, 0.006, 44.500, 44.505)
  # Graine (-6 dB, ratio < ts) sur 4 lignes ; au nord, collée, une baisse de
  # -4,2 dB (tp < ratio < ts : zone sans graine) sur environ 11 lignes, qui
  # couvre des bandes de 4 lignes entières sans aucune graine.
  coupes <- list(
    graine = list(v = rect_ll(0.0025, 0.0045, 44.5020, 44.5024), date = as.Date("2020-02-01")),
    zone = list(v = rect_ll(0.0025, 0.0045, 44.5024, 44.5034), date = as.Date("2020-02-01"),
                db = -4.2)
  )
  lec <- lecteur_coord(coupes)
  d0 <- tempfile("run-graine-")
  d1 <- tempfile("run-graine-")
  r0 <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", d0, lire_images = lec,
                       hauteur_bande = NULL)
  r1 <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", d1, lire_images = lec,
                       hauteur_bande = 4L)
  expect_gt(r1$tuiles$nb_bandes, 10L)
  expect_identical(r1$objets, r0$objets)
  for (f in grep("\\.tif$", fichiers_de(d0), value = TRUE)) {
    expect_identical(valeurs(file.path(d1, f)), valeurs(file.path(d0, f)), label = f)
  }
  # Un seul objet, qui couvre la graine et toute la zone sans graine.
  o <- terra::rast(r1$fichiers[["objets_raster"]])
  ids <- function(v) stats::na.omit(terra::extract(o, terra::project(v, "EPSG:2154"))[[2]])
  expect_equal(nrow(r1$objets), 1L)
  dans_zone <- ids(terra::buffer(coupes$zone$v, -15))
  expect_gt(length(dans_zone), 40L)
  expect_true(all(dans_zone == 1L))
  expect_true(all(ids(terra::buffer(coupes$graine$v, -5)) == 1L))
  expect_gt(r1$objets$nb_pixels, 150L)
})

test_that("lecteur par d\u00e9faut : un seul avertissement d'unit\u00e9 par tuile, pas par bande", {
  aoi_1 <- rect_ll(0.001, 0.006, 44.500, 44.505)
  g <- aoi_grille(aoi_preparer(aoi_1))
  d <- tempfile("s1-local-")
  dir.create(d)
  img <- terra::rast(terra::ext(g) + 200, resolution = 10, crs = terra::crs(g))
  terra::values(img) <- 0.05
  f <- file.path(d, "sans_unite.tif")
  terra::writeRaster(img, f)
  dts <- seq(as.Date("2018-01-05"), as.Date("2020-06-30"), by = 60)
  items <- data.frame(id = paste0("L", seq_along(dts)), date = dts,
                      heure = as.POSIXct(paste(dts, "06:00:00"), tz = "UTC"), capteur = "S1A",
                      orbite = 8L, direction = "descendante", serie = "D008", url = f,
                      stringsAsFactors = FALSE)
  vrai_s1_lire <- s1_lire
  testthat::local_mocked_bindings(
    s1_rechercher = function(...) structure(items, attribution = s1_attribution(items$date)),
    s1_lire = function(items, grille, ..., dossier, flux) {
      vrai_s1_lire(items, grille, signer = FALSE, dossier = dossier, flux = flux)
    }
  )
  w <- testthat::capture_warnings(
    r <- nemetonsar_run(aoi_1, "2019-01-01", "2020-06-30", tempfile("run-"), hauteur_bande = 10L)
  )
  expect_gt(r$tuiles$nb_bandes, 1L)
  w <- w[grepl("SARPixelContent", w, fixed = TRUE)]
  expect_length(w, 1L)
  expect_match(w, paste0("^", nrow(items), " fichier"))
})

test_that("bandes : lecteur incoh\u00e9rent ou hors grille refus\u00e9, images effac\u00e9es sur erreur", {
  lec <- lecteur_coord(coupes_run)
  n <- 0L
  change <- function(grille, date_debut, date_fin, parametres, dossier) {
    n <<- n + 1L
    x <- lec(grille, date_debut, date_fin, parametres, dossier)
    if (n > 1L) {
      x$orbites$D008 <- x$orbites$D008[[-1]]
      x$dates$D008 <- x$dates$D008[-1]
    }
    x
  }
  d <- tempfile("run-bandes-")
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", d, lire_images = change,
                              hauteur_bande = 20L), "orbites et les")
  expect_false(any(grepl("(^|/)s1(/|$)", fichiers_de(d))))
  expect_false(any(grepl(".nemetonsar_tmp", fichiers_de(d), fixed = TRUE)))
  tuile_entiere <- function(grille, date_debut, date_fin, parametres, dossier) {
    g <- terra::rast(terra::ext(grille) + c(0, 0, 10, 10), resolution = 10, crs = terra::crs(grille))
    lec(g, date_debut, date_fin, parametres, dossier)
  }
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", tempfile("run-"),
                              lire_images = tuile_entiere, hauteur_bande = 20L), "grille demand")
  for (h in list(0L, 2.5, "a", c(1L, 2L), NA)) {
    expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", tempfile("run-"),
                                lire_images = lec, hauteur_bande = h), "hauteur_bande")
  }
  expect_error(nemetonsar_run(aoi_2z, "2019-01-01", "2020-06-30", tempfile("run-"),
                              lire_images = lec, flux = 0), "flux")
})

# Essai réel (réseau) -----------------------------------------------------------

test_that("essai r\u00e9el : 1 km x 1 km dans les Landes, premier trimestre 2025", {
  skip_if(Sys.getenv("NEMETONSAR_TESTS_RESEAU") != "true",
          "test r\u00e9seau : d\u00e9finir NEMETONSAR_TESTS_RESEAU=true")
  skip_on_cran()
  skip_if_not_installed("rstac")
  skip_if_offline("planetarycomputer.microsoft.com")
  centre <- terra::crds(terra::project(terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326"),
                                       "EPSG:2154"))
  aoi <- terra::as.polygons(terra::ext(centre[1] - 500, centre[1] + 500,
                                       centre[2] - 500, centre[2] + 500), crs = "EPSG:2154")
  dossier <- tempfile("run-reel-")
  # Noyau sur 2024 : les images sont lues depuis le 2024-01-01.
  r <- nemetonsar_run(aoi, "2025-01-01", "2025-03-31", dossier,
                      parametres = parametres_sufosat(annee_noyau = 2024L))
  expect_equal(nrow(r$tuiles), 1L)
  expect_gt(r$tuiles$nb_images, 50L)
  expect_true(all(file.exists(r$fichiers[c("dates", "ratio", "objets_raster", "journal")])))
  j <- paste(readLines(r$journal), collapse = "\n")
  expect_match(j, "Contains modified Copernicus Sentinel data 2024-2025", fixed = TRUE,
               useBytes = TRUE)
  unlink(dossier, recursive = TRUE)
})

test_that("essai r\u00e9el : bandes de 64 lignes et lecture d'un seul tenant identiques", {
  skip_if(Sys.getenv("NEMETONSAR_TESTS_RESEAU") != "true",
          "test r\u00e9seau : d\u00e9finir NEMETONSAR_TESTS_RESEAU=true")
  skip_on_cran()
  skip_if_not_installed("rstac")
  skip_if_offline("planetarycomputer.microsoft.com")
  centre <- terra::crds(terra::project(terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326"),
                                       "EPSG:2154"))
  aoi <- terra::as.polygons(terra::ext(centre[1] - 500, centre[1] + 500,
                                       centre[2] - 500, centre[2] + 500), crs = "EPSG:2154")
  p <- parametres_sufosat(annee_noyau = 2024L)
  d0 <- tempfile("run-reel-")
  d1 <- tempfile("run-reel-")
  on.exit(unlink(c(d0, d1), recursive = TRUE), add = TRUE)
  r0 <- nemetonsar_run(aoi, "2025-01-01", "2025-03-31", d0, parametres = p, hauteur_bande = NULL)
  r1 <- nemetonsar_run(aoi, "2025-01-01", "2025-03-31", d1, parametres = p, hauteur_bande = 64L)
  expect_gt(r1$tuiles$nb_bandes, 1L)
  expect_identical(r1$objets, r0$objets)
  rasters <- grep("\\.tif$", fichiers_de(d0), value = TRUE)
  expect_identical(fichiers_de(d1), fichiers_de(d0))
  for (f in rasters) {
    expect_identical(valeurs(file.path(d1, f)), valeurs(file.path(d0, f)), label = f)
  }
  expect_false(any(grepl("(^|/)s1(/|$)", fichiers_de(d1))))
  expect_match(paste(readLines(r1$journal), collapse = "\n"), "reprojection exacte", fixed = TRUE,
               useBytes = TRUE)
})
