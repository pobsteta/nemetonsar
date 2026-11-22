# Mission 013 : recherche et lecture des images Sentinel-1 RTC.

fixture_s1 <- function() {
  skip_if_not_installed("rstac")
  chemin <- test_path("fixtures", "stac-s1-rtc-landes-2025-06.json")
  rstac::read_stac(chemin)$features
}

debut_fixture <- as.Date("2025-06-01")
fin_fixture <- as.Date("2025-06-20")

# Conversions des champs STAC ----------------------------------------------

test_that("les noms de plateforme STAC donnent les codes de capteur", {
  expect_equal(
    capteur_stac(c("SENTINEL-1A", "sentinel-1a", "sentinel-1c", "Sentinel-1D", "landsat-8", NA)),
    c("S1A", "S1A", "S1C", "S1D", NA, NA)
  )
  expect_equal(
    direction_stac(c("ascending", "DESCENDING", "autre", NA)),
    c("ascendante", "descendante", NA, NA)
  )
})

# Table des items (fixture) -------------------------------------------------

test_that("la fixture est lue et ne contient aucun jeton", {
  f <- fixture_s1()
  expect_length(f, 13L)
  texte <- readLines(test_path("fixtures", "stac-s1-rtc-landes-2025-06.json"), warn = FALSE)
  expect_false(any(grepl("sig=|se=20|token", texte)))
})

test_that("par d\u00e9faut, seules les images de 1A de la p\u00e9riode sont gard\u00e9es (2025)", {
  t <- s1_table_items(fixture_s1(), debut_fixture, fin_fixture, parametres_sufosat())
  expect_named(t, c("id", "date", "heure", "capteur", "orbite", "direction", "serie", "url"))
  expect_true(all(t$capteur == "S1A"))
  expect_false(any(grepl("HORS_PERIODE|VV_SEUL|ANCIEN", t$id)))
  expect_true(all(t$date >= debut_fixture & t$date <= fin_fixture))
  expect_equal(
    t$date,
    as.Date(c("2025-06-10", "2025-06-11", "2025-06-11", "2025-06-03", "2025-06-15"))
  )
  expect_equal(t$orbite, c(8L, 30L, 30L, 81L, 81L))
  expect_equal(t$serie, c("D008", "A030", "A030", "D081", "D081"))
  expect_equal(t$direction, c("descendante", "ascendante", "ascendante", "descendante", "descendante"))
  expect_s3_class(t$heure, "POSIXct")
  expect_equal(attr(t$heure, "tzone"), "UTC")
  expect_true(all(grepl("/iw-vh", t$url)))
})

test_that("une republication d'une m\u00eame tranche est \u00e9cart\u00e9e (traitement le plus r\u00e9cent)", {
  deux <- parametres_sufosat(capteurs = list("2014-04-03" = c("S1A", "S1C")))
  t <- s1_table_items(fixture_s1(), debut_fixture, fin_fixture, deux)
  c030 <- t[t$capteur == "S1C" & t$date == as.Date("2025-06-17"), ]
  expect_equal(nrow(c030), 1L)
  expect_false(grepl("ancien", c030$url))
  expect_false(any(grepl("ANCIEN", t$id)))
})

test_that("deux tranches d'une m\u00eame acquisition restent deux lignes, tri\u00e9es par heure", {
  t <- s1_table_items(fixture_s1(), debut_fixture, fin_fixture, parametres_sufosat())
  a030 <- t[t$serie == "A030", ]
  expect_equal(nrow(a030), 2L)
  expect_equal(a030$date, as.Date(c("2025-06-11", "2025-06-11")))
  expect_true(a030$heure[1] < a030$heure[2])
  expect_match(a030$id[2], "TRANCHE2")
  # Une fois les tranches assemblées, pas de doublon de date par orbite.
  expect_equal(anyDuplicated(unique(t[c("serie", "date")])), 0L)
})

test_that("les capteurs suivent capteurs_a_la_date()", {
  f <- fixture_s1()
  deux <- parametres_sufosat(capteurs = list("2014-04-03" = c("S1A", "S1C")))
  t <- s1_table_items(f, debut_fixture, fin_fixture, deux)
  expect_setequal(unique(t$capteur), c("S1A", "S1C"))
  expect_equal(sum(t$capteur == "S1C"), 5L)

  # Bascule au 2025-06-12 : 1A avant, 1C à partir de ce jour.
  bascule <- parametres_sufosat(capteurs = list("2014-04-03" = "S1A", "2025-06-12" = "S1C"))
  t <- s1_table_items(f, debut_fixture, fin_fixture, bascule)
  expect_true(all(t$capteur[t$date < as.Date("2025-06-12")] == "S1A"))
  expect_true(all(t$capteur[t$date >= as.Date("2025-06-12")] == "S1C"))
  expect_equal(sort(t$date[t$capteur == "S1C"]), as.Date(c("2025-06-16", "2025-06-17")))
  expect_equal(sum(t$capteur == "S1C"), 2L)

  # Aucun capteur actif avant la première période.
  tard <- parametres_sufosat(capteurs = list("2026-01-01" = "S1A"))
  expect_equal(nrow(s1_table_items(f, debut_fixture, fin_fixture, tard)), 0L)
})

test_that("la polarisation choisit l'asset ; un item sans cet asset est \u00e9cart\u00e9", {
  f <- fixture_s1()
  vv <- s1_table_items(f, debut_fixture, fin_fixture, parametres_sufosat(polarisation = "VV"))
  expect_true(all(grepl("/iw-vv", vv$url)))
  expect_true(any(grepl("VV_SEUL", vv$id)))
  vh <- s1_table_items(f, debut_fixture, fin_fixture, parametres_sufosat())
  expect_false(any(grepl("VV_SEUL", vh$id)))
})

test_that("une p\u00e9riode resserr\u00e9e filtre les dates, bornes incluses", {
  t <- s1_table_items(fixture_s1(), as.Date("2025-06-10"), as.Date("2025-06-11"), parametres_sufosat())
  expect_equal(t$date, as.Date(c("2025-06-10", "2025-06-11", "2025-06-11")))
})

test_that("une r\u00e9ponse vide donne une table vide aux bonnes colonnes", {
  t <- s1_table_items(list(), debut_fixture, fin_fixture, parametres_sufosat())
  expect_equal(nrow(t), 0L)
  expect_named(t, c("id", "date", "heure", "capteur", "orbite", "direction", "serie", "url"))
  expect_s3_class(t$date, "Date")
})

# Attribution ---------------------------------------------------------------

test_that("l'attribution reprend la formule [S1] et les ann\u00e9es des sc\u00e8nes", {
  expect_equal(
    s1_attribution(as.Date(c("2025-06-03", "2025-06-15"))),
    paste0("Contains modified Copernicus Sentinel data 2025. ",
           "Sentinel-1 RTC processed by Catalyst, hosted by Microsoft Planetary Computer, CC BY 4.0.")
  )
  expect_match(s1_attribution(as.Date(c("2019-01-01", "2025-06-15", "2021-03-01"))),
               "Copernicus Sentinel data 2019-2025\\.")
})

# Arguments -----------------------------------------------------------------

test_that("l'emprise est convertie en bo\u00eete en degr\u00e9s", {
  expect_equal(emprise_vers_bbox(terra::ext(-1, 0, 44, 45)), c(-1, 44, 0, 45))
  expect_error(emprise_vers_bbox(terra::ext(600000, 700000, 4800000, 4900000)), "degr")

  pt <- terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326")
  expect_equal(emprise_vers_bbox(pt), c(-0.80, 44.20, -0.80, 44.20))

  # Un carré de 10 km en Lambert-93 : la boîte contient ses quatre coins.
  l93 <- terra::project(pt, "EPSG:2154")
  carre <- terra::as.polygons(terra::ext(terra::buffer(l93, 5000)), crs = "EPSG:2154")
  b <- emprise_vers_bbox(carre)
  coins <- terra::crds(terra::project(terra::as.points(carre), "EPSG:4326"))
  expect_true(all(coins[, 1] >= b[1] - 1e-9 & coins[, 1] <= b[3] + 1e-9))
  expect_true(all(coins[, 2] >= b[2] - 1e-9 & coins[, 2] <= b[4] + 1e-9))
  expect_true(b[1] < -0.80 && b[3] > -0.80 && b[2] < 44.20 && b[4] > 44.20)

  g <- terra::rast(carre, resolution = 1000)
  expect_equal(emprise_vers_bbox(g), b)

  expect_error(emprise_vers_bbox(terra::vect(cbind(1, 2))), "coordonn")
  expect_error(emprise_vers_bbox(c(-1, 44, 0, 45)), "SpatVector")
})

test_that("la p\u00e9riode est valid\u00e9e", {
  expect_equal(valide_periode("2025-01-01", as.Date("2025-02-01")),
               as.Date(c("2025-01-01", "2025-02-01")))
  expect_error(valide_periode("2025-02-01", "2025-01-01"), "date_fin`")
  expect_error(valide_periode("pas une date", "2025-01-01"), "date_debut")
  expect_error(valide_periode("2025-01-01", NA), "date_fin")
})

test_that("une erreur explicite si rstac manque", {
  local_mocked_bindings(rstac_disponible = function() FALSE)
  expect_error(
    s1_rechercher(terra::ext(-1, 0, 44, 45), "2025-01-01", "2025-01-31"),
    "rstac.*install.packages"
  )
  items <- data.frame(date = as.Date("2025-01-01"), heure = Sys.time(),
                      serie = "A030", url = "x")
  g <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100, resolution = 10,
                   crs = "EPSG:32630")
  expect_error(s1_lire(items, g, signer = TRUE), "rstac")
})

# Lecture sur fichiers locaux (sans réseau) ----------------------------------

# Écrit une image 10 m en UTM 30N, valeur constante (puissance linéaire),
# avec, si demandé, les métadonnées de bande des fichiers RTC (fichier
# .aux.xml lu par GDAL).
image_locale <- function(valeur, xmin, dossier, nom, echelle = NULL,
                         contenu = "intensity") {
  r <- terra::rast(xmin = xmin, xmax = xmin + 400, ymin = 0, ymax = 400,
                   resolution = 10, crs = "EPSG:32630")
  terra::values(r) <- valeur
  f <- file.path(dossier, nom)
  terra::writeRaster(r, f, overwrite = TRUE)
  if (!is.null(echelle)) {
    writeLines(c(
      "<PAMDataset>", "<PAMRasterBand band=\"1\">", "<Metadata>",
      paste0("<MDI key=\"SARPixelContent\">", contenu, "</MDI>"),
      paste0("<MDI key=\"Scale\">", echelle, "</MDI>"),
      "</Metadata>", "</PAMRasterBand>", "</PAMDataset>"
    ), paste0(f, ".aux.xml"))
  }
  f
}

test_that("s1_lire() range les images en piles par orbite, pr\u00eates pour la d\u00e9tection", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  # Grille : 30 x 30 pixels de 10 m, décalée de 5 m (rééchantillonnage).
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  f1 <- image_locale(0.04, 0, d, "a1.tif", "linear")
  f2 <- image_locale(0.02, 0, d, "a2.tif", "linear")
  # Deux tranches du 2025-06-11 : la première couvre x < 200, la seconde tout.
  f3a <- image_locale(0.05, -200, d, "b1a.tif", "linear")
  f3b <- image_locale(0.01, 0, d, "b1b.tif", "linear")
  # Une image en dB : -20 dB -> 0,01.
  f4 <- image_locale(-20, 0, d, "b2.tif", "db")

  items <- data.frame(
    date = as.Date(c("2025-06-15", "2025-06-03", "2025-06-11", "2025-06-11", "2025-06-23")),
    heure = as.POSIXct(c("2025-06-15 06:17:17", "2025-06-03 06:17:18", "2025-06-11 17:56:20",
                         "2025-06-11 17:56:45", "2025-06-23 17:56:20"), tz = "UTC"),
    serie = c("D081", "D081", "A030", "A030", "A030"),
    url = c(f2, f1, f3a, f3b, f4),
    stringsAsFactors = FALSE
  )
  s <- s1_lire(items, grille, signer = FALSE)

  expect_named(s, c("orbites", "dates", "attribution", "items"))
  expect_named(s$orbites, c("A030", "D081"))
  expect_equal(s$dates, list(A030 = as.Date(c("2025-06-11", "2025-06-23")),
                             D081 = as.Date(c("2025-06-03", "2025-06-15"))))
  expect_equal(names(s$orbites$D081), c("2025-06-03", "2025-06-15"))
  expect_true(terra::compareGeom(s$orbites$A030, grille))
  expect_true(terra::compareGeom(s$orbites$D081, grille))

  v <- terra::values(s$orbites$D081)
  expect_equal(unname(colMeans(v)), c(0.04, 0.02), tolerance = 1e-6)
  b <- terra::values(s$orbites$A030)
  # Tranches assemblées : la plus tôt d'abord, la seconde comble.
  x <- terra::xFromCell(grille, seq_len(terra::ncell(grille)))
  expect_equal(unique(b[x < 195, 1]), 0.05, tolerance = 1e-6)
  expect_equal(unique(b[x > 205, 1]), 0.01, tolerance = 1e-6)
  expect_false(anyNA(b[, 1]))
  # dB converti en linéaire.
  expect_equal(unique(b[, 2]), 0.01, tolerance = 1e-6)
  expect_match(s$attribution, "Copernicus Sentinel data 2025\\.")

  # Entrée acceptée par nemetonsar_detecter().
  expect_true(valide_orbites(s$orbites, s$dates))
})

test_that("une image hors de la grille donne une couche vide ; sans m\u00e9tadonn\u00e9es, un avertissement", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  grille <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                        resolution = 10, crs = "EPSG:32630")
  loin <- image_locale(0.03, 100000, d, "loin.tif", "linear")
  sans <- image_locale(0.03, 0, d, "sans.tif")
  items <- data.frame(
    date = as.Date(c("2025-06-01", "2025-06-13")),
    heure = as.POSIXct(c("2025-06-01 06:00:00", "2025-06-13 06:00:00"), tz = "UTC"),
    serie = "D008", url = c(loin, sans), stringsAsFactors = FALSE
  )
  expect_warning(s <- s1_lire(items, grille, signer = FALSE), "1 fichier")
  v <- terra::values(s$orbites$D008)
  expect_true(all(is.na(v[, 1])))
  expect_equal(unique(v[, 2]), 0.03, tolerance = 1e-6)
})

test_that("l'amplitude est mise au carr\u00e9 ; une unit\u00e9 inconnue arr\u00eate", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  grille <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                        resolution = 10, crs = "EPSG:32630")
  amp <- image_locale(0.2, 0, d, "amp.tif", "linear", contenu = "amplitude")
  bizarre <- image_locale(0.2, 0, d, "biz.tif", "log")
  items <- data.frame(date = as.Date("2025-06-01"),
                      heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC"),
                      serie = "D008", url = amp, stringsAsFactors = FALSE)
  s <- s1_lire(items, grille, signer = FALSE)
  expect_equal(unique(terra::values(s$orbites$D008)[, 1]), 0.04, tolerance = 1e-6)
  items$url <- bizarre
  expect_error(s1_lire(items, grille, signer = FALSE), "Scale=log")
})

test_that("s1_lire() \u00e9crit une pile par orbite dans `dossier`", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  sortie <- file.path(d, "piles")
  grille <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                        resolution = 10, crs = "EPSG:32630")
  f <- image_locale(0.03, 0, d, "x.tif", "linear")
  items <- data.frame(date = as.Date("2025-06-01"),
                      heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC"),
                      serie = "D008", url = f, stringsAsFactors = FALSE)
  s <- s1_lire(items, grille, signer = FALSE, dossier = sortie)
  expect_true(file.exists(file.path(sortie, "s1_D008.tif")))
  expect_equal(terra::sources(s$orbites$D008), normalizePath(file.path(sortie, "s1_D008.tif")))
})

test_that("s1_lire() refuse les entr\u00e9es mal form\u00e9es", {
  g <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100, resolution = 10,
                   crs = "EPSG:32630")
  items <- data.frame(date = as.Date("2025-06-01"),
                      heure = as.POSIXct("2025-06-01", tz = "UTC"),
                      serie = "D008", url = "x.tif")
  expect_error(s1_lire(list(), g), "data.frame")
  expect_error(s1_lire(items[0, ], g), "aucune image")
  expect_error(s1_lire(items, terra::rast()), "projet")
  expect_error(s1_lire(items, g, signer = NA), "signer")
  expect_error(s1_lire(items, g, signer = FALSE, methode = 1), "methode")
})

# Essai réel (réseau) -----------------------------------------------------------

test_that("essai r\u00e9el : images de 2025 sur un point des Landes, une petite fen\u00eatre lue", {
  skip_on_cran()
  skip_if_not_installed("rstac")
  skip_if_offline("planetarycomputer.microsoft.com")

  pt <- terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326")
  items <- s1_rechercher(pt, "2025-06-01", "2025-06-20")
  expect_gt(nrow(items), 0L)
  expect_true(all(items$capteur == "S1A"))
  expect_true(all(items$date >= as.Date("2025-06-01") & items$date <= as.Date("2025-06-20")))
  expect_match(attr(items, "attribution"), "Contains modified Copernicus Sentinel data 2025")

  # Une seule image, 200 m x 200 m autour du point, en UTM 30N.
  centre <- round(terra::geom(terra::project(pt, "EPSG:32630"))[1, c("x", "y")] / 10) * 10
  grille <- terra::rast(xmin = centre[["x"]] - 100, xmax = centre[["x"]] + 100,
                        ymin = centre[["y"]] - 100, ymax = centre[["y"]] + 100,
                        resolution = 10, crs = "EPSG:32630")
  s <- s1_lire(items[1, ], grille)
  expect_length(s$orbites, 1L)
  expect_equal(s$dates[[1]], items$date[1])
  v <- terra::values(s$orbites[[1]])[, 1]
  expect_false(anyNA(v))
  # gamma0 linéaire en puissance : une forêt en VH est autour de -14 dB.
  db <- 10 * log10(stats::median(v))
  expect_true(db > -25 && db < -5)
})
