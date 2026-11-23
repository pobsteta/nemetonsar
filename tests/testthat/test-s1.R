# Mission 013 : recherche et lecture des images Sentinel-1 RTC.
#
# Le test reel (dernier test du fichier) interroge le Planetary Computer. Il
# ne tourne que si la variable d'environnement NEMETONSAR_TESTS_RESEAU vaut
# "true", en plus de skip_on_cran(), skip_if_not_installed("rstac") et
# skip_if_offline(). Pour le lancer :
#   NEMETONSAR_TESTS_RESEAU=true Rscript -e 'testthat::test_local(filter = "s1")'

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

test_that("s1_lire() \u00e9crit un fichier par date dans `dossier`, DEFLATE + pr\u00e9dicteur 3", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  sortie <- file.path(d, "piles")
  grille <- terra::rast(xmin = 0, xmax = 100, ymin = 0, ymax = 100,
                        resolution = 10, crs = "EPSG:32630")
  f <- image_locale(0.03, 0, d, "x.tif", "linear")
  g <- image_locale(0.05, 0, d, "y.tif", "linear")
  items <- data.frame(date = as.Date(c("2025-06-13", "2025-06-01")),
                      heure = as.POSIXct(c("2025-06-13 06:00:00", "2025-06-01 06:00:00"), tz = "UTC"),
                      serie = "D008", url = c(g, f), stringsAsFactors = FALSE)
  s <- s1_lire(items, grille, signer = FALSE, dossier = sortie)
  attendus <- file.path(sortie, "s1_D008", c("2025-06-01.tif", "2025-06-13.tif"))
  expect_true(all(file.exists(attendus)))
  expect_equal(terra::sources(s$orbites$D008), normalizePath(attendus))
  expect_equal(names(s$orbites$D008), c("2025-06-01", "2025-06-13"))
  expect_equal(unname(colMeans(terra::values(s$orbites$D008))), c(0.03, 0.05), tolerance = 1e-6)
  info <- terra::describe(attendus[1])
  expect_true(any(grepl("COMPRESSION=DEFLATE", info, fixed = TRUE)))
  expect_true(any(grepl("PREDICTOR=3", info, fixed = TRUE)))
  expect_true(any(grepl("Type=Float32", info, fixed = TRUE)))
})

test_that("s1_lire() : m\u00eames piles avec 1 ou plusieurs flux ; erreur d'un processus remont\u00e9e", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  urls <- vapply(1:6, function(i) image_locale(0.01 * i, 0, d, paste0("i", i, ".tif"), "linear"),
                 character(1))
  items <- data.frame(date = as.Date("2025-06-01") + 12 * (0:5),
                      heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC") + 12 * 86400 * (0:5),
                      serie = rep(c("A030", "D008"), 3), url = urls, stringsAsFactors = FALSE)
  s1 <- s1_lire(items, grille, signer = FALSE, flux = 1L, dossier = file.path(d, "f1"))
  s3 <- s1_lire(items, grille, signer = FALSE, flux = 3L, dossier = file.path(d, "f3"))
  expect_equal(s1$dates, s3$dates)
  for (o in names(s1$orbites)) {
    expect_identical(terra::values(s1$orbites[[o]]), terra::values(s3$orbites[[o]]))
  }
  # Sans `dossier` : fichiers temporaires, mêmes valeurs.
  s0 <- s1_lire(items, grille, signer = FALSE, flux = 2L)
  expect_identical(terra::values(s0$orbites$A030), terra::values(s1$orbites$A030))
  bizarre <- image_locale(0.2, 0, d, "biz.tif", "log")
  items$url[4] <- bizarre
  expect_error(s1_lire(items, grille, signer = FALSE, flux = 3L), "Scale=log")
  expect_error(s1_lire(items, grille, signer = FALSE, flux = 0), "flux")
  expect_error(s1_lire(items, grille, signer = FALSE, flux = 1.5), "flux")
})

# Mission 023 : parallélisme sans blocage sous terra >= 1.9 -------------------

# Lance `code` (texte R) dans un nouveau processus R où nemetonsar est
# chargé comme dans cette session (sources par pkgload, ou paquet installé),
# évalué dans l'espace de noms du paquet, avec un délai maximal de `delai`
# secondes. Rend list(statut, sortie) ; statut 124 : délai dépassé (le
# processus est arrêté). Depuis les sources, le nouveau processus charge le
# paquet par pkgload (Suggests), comme testthat::test_local() ; sans pkgload,
# le test est sauté.
r_avec_delai <- function(code, delai) {
  chemin <- getNamespaceInfo("nemetonsar", "path")
  sources <- file.exists(file.path(chemin, "R", "s1.R"))
  if (sources) skip_if_not_installed("pkgload")
  charger <- if (sources) {
    sprintf("suppressMessages(pkgload::load_all(%s, quiet = TRUE))", deparse(chemin))
  } else {
    sprintf("suppressMessages(library(nemetonsar, lib.loc = %s))", deparse(dirname(chemin)))
  }
  script <- tempfile("m023-", fileext = ".R")
  sortie <- tempfile("m023-", fileext = ".txt")
  on.exit(unlink(c(script, sortie)), add = TRUE)
  writeLines(c(sprintf(".libPaths(%s)", paste(deparse(.libPaths()), collapse = "")),
               charger,
               "local({", code, "}, envir = new.env(parent = asNamespace(\"nemetonsar\")))"),
             script)
  statut <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                     c("--vanilla", shQuote(script)),
                                     stdout = sortie, stderr = sortie, timeout = delai))
  list(statut = statut, sortie = if (file.exists(sortie)) readLines(sortie, warn = FALSE) else "")
}

test_that("mission 023 : lecture parall\u00e8le apr\u00e8s un calcul de terra dans le processus principal, sans blocage", {
  skip_on_os("windows")
  skip_on_cran()
  resultat <- tempfile("m023-", fileext = ".rds")
  on.exit(unlink(resultat), add = TRUE)
  # Le processus principal écrit des images d'au moins 10 000 cellules
  # (writeRaster) avant le fork : avec terra 1.9-60, cela crée le groupe de
  # fils d'exécution de terra. Les processus enfants de s1_lire() écrivent
  # chacun une date de 14 400 cellules. Sans le correctif, ils attendent sans
  # fin (constat du 2026-11-23, GDAL 3.11.4, terra 1.9-60).
  code <- sprintf('
    d <- tempfile("m023-")
    dir.create(d)
    grille <- terra::rast(nrows = 120, ncols = 120, xmin = 600000, xmax = 601200,
                          ymin = 5000000, ymax = 5001200, crs = "EPSG:32631")
    image <- function(i) {
      r <- terra::rast(terra::ext(grille) + 105, resolution = 10, crs = "EPSG:32631")
      set.seed(i)
      terra::values(r) <- 0.05 * stats::rgamma(terra::ncell(r), 200, 200)
      f <- file.path(d, paste0("i", i, ".tif"))
      terra::writeRaster(r, f)
      f
    }
    urls <- vapply(1:6, image, character(1))
    items <- data.frame(date = as.Date("2025-06-01") + 12 * (0:5),
                        heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC") + 12 * 86400 * (0:5),
                        serie = rep(c("A030", "D008"), 3), url = urls, stringsAsFactors = FALSE)
    s2 <- suppressWarnings(s1_lire(items, grille, signer = FALSE, flux = 2L,
                                   dossier = file.path(d, "f2")))
    s1 <- suppressWarnings(s1_lire(items, grille, signer = FALSE, flux = 1L,
                                   dossier = file.path(d, "f1")))
    saveRDS(list(dates = identical(s1$dates, s2$dates),
                 valeurs = lapply(names(s1$orbites), function(o)
                   identical(terra::values(s1$orbites[[o]]), terra::values(s2$orbites[[o]])))),
            %s)
  ', deparse(resultat))
  delai <- 120
  x <- r_avec_delai(code, delai)
  if (x$statut == 124L) {
    fail(paste0("blocage : la lecture parall\u00e8le n'a pas fini en ", delai, " s"))
  } else {
    expect_identical(x$statut, 0L, label = paste(x$sortie, collapse = "\n"))
    r <- readRDS(resultat)
    expect_true(r$dates)
    expect_identical(r$valeurs, list(TRUE, TRUE))
  }
})

test_that("mission 023 : la lecture passe bien par des processus enfants, sans les fils de terra", {
  skip_on_os("windows")
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  urls <- vapply(1:6, function(i) image_locale(0.01 * i, 0, d, paste0("i", i, ".tif"), "linear"),
                 character(1))
  items <- data.frame(date = as.Date("2025-06-01") + 12 * (0:5),
                      heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC") + 12 * 86400 * (0:5),
                      serie = rep(c("A030", "D008"), 3), url = urls, stringsAsFactors = FALSE)
  trace <- file.path(d, "trace.txt")
  vrai <- s1_lire_un
  local_mocked_bindings(s1_lire_un = function(...) {
    opt <- terra::terraOptions(print = FALSE)$parallel
    cat(Sys.getpid(), if (is.null(opt)) "absent" else opt, "\n", file = trace, append = TRUE)
    vrai(...)
  })
  avant <- terra::terraOptions(print = FALSE)$parallel
  s1_lire(items, grille, signer = FALSE, flux = 2L, dossier = file.path(d, "f"))
  t <- utils::read.table(trace, col.names = c("pid", "parallel"), colClasses = "character")
  expect_equal(nrow(t), 6L)
  expect_false(any(t$pid == as.character(Sys.getpid())))
  expect_gte(length(unique(t$pid)), 2L)
  expect_true(all(t$parallel %in% c("FALSE", "absent")))
  # Le réglage de terra du processus principal n'est pas touché.
  expect_identical(terra::terraOptions(print = FALSE)$parallel, avant)
})

test_that("reprojection exacte : valeur bilin\u00e9aire au centre exact, identique par bandes", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  # Image en UTM 31N (comme l'orbite D008), grille en UTM 30N : vraie
  # reprojection (rotation).
  centre <- terra::crds(terra::project(terra::vect(cbind(-0.2, 44.2), crs = "EPSG:4326"),
                                       "EPSG:32631"))
  img <- terra::rast(xmin = round(centre[1], -1) - 1500, xmax = round(centre[1], -1) + 1500,
                     ymin = round(centre[2], -1) - 1500, ymax = round(centre[2], -1) + 1500,
                     resolution = 10, crs = "EPSG:32631")
  set.seed(3)
  terra::values(img) <- 0.05 * stats::rgamma(terra::ncell(img), 5, 5)
  f <- file.path(d, "img31.tif")
  terra::writeRaster(img, f, datatype = "FLT4S")
  writeLines(c("<PAMDataset>", "<PAMRasterBand band=\"1\">", "<Metadata>",
               "<MDI key=\"SARPixelContent\">intensity</MDI>", "<MDI key=\"Scale\">linear</MDI>",
               "</Metadata>", "</PAMRasterBand>", "</PAMDataset>"), paste0(f, ".aux.xml"))
  c30 <- round(terra::crds(terra::project(terra::vect(cbind(-0.2, 44.2), crs = "EPSG:4326"),
                                          "EPSG:32630")), -1)
  grille <- terra::rast(xmin = c30[1] - 800, xmax = c30[1] + 800, ymin = c30[2] - 800,
                        ymax = c30[2] + 800, resolution = 10, crs = "EPSG:32630")
  items <- data.frame(date = as.Date("2025-06-01"), heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC"),
                      serie = "D008", url = f, stringsAsFactors = FALSE)
  v <- terra::values(s1_lire(items, grille, signer = FALSE, flux = 1L)$orbites$D008, mat = FALSE)
  # Valeur attendue : interpolation bilinéaire au centre de chaque cellule,
  # projeté exactement dans le système de l'image.
  centres <- terra::project(terra::vect(terra::xyFromCell(grille, seq_len(terra::ncell(grille))),
                                        crs = terra::crs(grille)), "EPSG:32631")
  attendu <- terra::extract(terra::rast(f), centres, method = "bilinear")[[2]]
  expect_equal(v, as.numeric(as.vector(attendu)), tolerance = 1e-6)
  # Bandes de 23 lignes : mêmes valeurs au bit près.
  nl <- terra::nrow(grille)
  for (de in seq(1L, nl, by = 23L)) {
    n <- min(23L, nl - de + 1L)
    gb <- grille_lignes(grille, de, n)
    vb <- terra::values(s1_lire(items, gb, signer = FALSE, flux = 1L)$orbites$D008, mat = FALSE)
    expect_identical(vb, v[(de - 1L) * terra::ncol(grille) + seq_len(n * terra::ncol(grille))])
  }
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

# Mission 025 : jetons SAS renouvelés pendant la lecture ----------------------

test_that("la r\u00e9ponse de l'API des jetons est lue (jeton, expiration en UTC)", {
  # Forme de la réponse relevée le 2026-11-23 (signature remplacée).
  texte <- paste0('{"msft:expiry":"2026-11-23T18:47:12Z","token":"st=2026-11-22T18%3A02%3A12Z',
                  '\\u0026se=2026-11-23T18%3A47%3A12Z\\u0026sp=rl\\u0026sr=c\\u0026sig=ABC%2Fd%3D"}')
  j <- s1_lire_reponse_jeton(texte)
  expect_identical(j$jeton, "st=2026-11-22T18%3A02%3A12Z&se=2026-11-23T18%3A47%3A12Z&sp=rl&sr=c&sig=ABC%2Fd%3D")
  expect_identical(j$expiration, as.POSIXct("2026-11-23 18:47:12", tz = "UTC"))
  expect_error(s1_lire_reponse_jeton('{"message":"Too Many Requests"}'), "API des jetons")
  expect_error(s1_lire_reponse_jeton('{"msft:expiry":"x","token":"st=1&sig=2"}'), "API des jetons")
  expect_identical(s1_signer_adresse("https://h/f.tif", "a=1&sig=2"), "https://h/f.tif?a=1&sig=2")
  expect_identical(s1_signer_adresse("https://h/f.tif?x=0", "sig=2"), "https://h/f.tif?x=0&sig=2")
})

test_that("un jeton est renouvel\u00e9 avant d'expirer, neuf apr\u00e8s un refus, partag\u00e9 par fichier", {
  fichier <- tempfile("jeton-")
  on.exit(unlink(fichier), add = TRUE)
  t0 <- as.POSIXct("2026-11-23 12:00:00", tz = "UTC")
  horloge <- t0
  n <- 0L
  demander <- function() {
    n <<- n + 1L
    list(jeton = paste0("sig=", n), expiration = horloge + 45 * 60)
  }
  a <- s1_jetons(fichier, demander, marge = 15 * 60, maintenant = function() horloge)
  expect_identical(a(), "sig=1")
  horloge <- t0 + 29 * 60
  expect_identical(a(), "sig=1")
  expect_identical(n, 1L)
  # Il reste moins de 15 min : jeton neuf.
  horloge <- t0 + 31 * 60
  expect_identical(a(), "sig=2")
  # Après un refus : toujours un jeton neuf, même si le refusé semble valable.
  expect_identical(a(refuse = "sig=2"), "sig=3")
  expect_identical(n, 3L)
  # Un autre processus (même fichier) reprend le jeton en cours sans en demander.
  b <- s1_jetons(fichier, demander, marge = 15 * 60, maintenant = function() horloge)
  expect_identical(b(), "sig=3")
  expect_identical(n, 3L)
  # Le jeton plus récent demandé par b est pris par a, sans nouvelle demande.
  horloge <- t0 + 40 * 60
  expect_identical(b(refuse = "sig=3"), "sig=4")
  expect_identical(a(), "sig=4")
  expect_identical(n, 4L)
  expect_identical(readLines(fichier), c("2026-11-23T13:25:00Z", "sig=4"))
  # Un fichier abîmé est ignoré.
  writeLines("n'importe quoi", fichier)
  c2 <- s1_jetons(fichier, demander, marge = 15 * 60, maintenant = function() horloge)
  expect_identical(c2(), "sig=5")
  # Fichier impossible à écrire : le jeton est gardé en mémoire.
  d <- s1_jetons(file.path(fichier, "absent", "jeton"), demander, marge = 15 * 60,
                 maintenant = function() horloge)
  expect_identical(d(), "sig=6")
  expect_identical(d(), "sig=6")
})

# Images locales et lecteur simulé du Planetary Computer. Horloge : le nombre
# de lectures de tranche faites (tous processus). Un jeton demandé quand
# l'horloge vaut h « expire » après la lecture h + `n_lectures` : les
# lectures suivantes avec ce jeton reçoivent un 403, comme le 2026-11-23
# (m024) ; un jeton neuf a toujours `n_lectures` lectures devant lui. `mode` :
# "erreur" (403 puis erreur, comme les journaux de m024), "silence" (403 sans
# erreur, valeurs vides), "toujours" (tout jeton refusé). Lectures et
# demandes sont comptées dans des fichiers (processus enfants). Les images
# sont lues en local, avec leur .aux.xml (que la lecture distante n'ouvre
# pas : GDAL_DISABLE_READDIR_ON_OPEN).
jetons_simules <- function(d, n_lectures, mode = "erreur", env = parent.frame()) {
  compteur <- file.path(d, "lectures.txt")
  demandes <- file.path(d, "demandes.txt")
  lignes <- function(f) if (file.exists(f)) readLines(f) else character(0)
  vrai <- s1_lire_un
  vrai_local <- function(adresse, grille, methode) {
    ancien <- terra::getGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN")
    terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "FALSE")
    on.exit(terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", ancien))
    vrai(sub("\\?.*$", "", adresse), grille, methode)
  }
  local_mocked_bindings(
    rstac_disponible = function() TRUE,
    s1_fichier_jeton = function() file.path(d, "jeton_sas"),
    s1_demander_jeton = function(...) {
      cat(length(lignes(compteur)), "\n", file = demandes, append = TRUE, sep = "")
      list(jeton = paste0("sig=", length(lignes(demandes))),
           expiration = Sys.time() + 45 * 60)
    },
    s1_lire_un = function(adresse, grille, methode) {
      cat("x\n", file = compteur, append = TRUE)
      horloge <- length(lignes(compteur))
      k <- as.integer(sub("^.*sig=", "", adresse))
      emis <- as.integer(lignes(demandes)[k])
      if (mode == "toujours" || horloge > emis + n_lectures) {
        warning("GDAL Message 1: Request for 1573011831-1575562032 failed with response_code=403",
                call. = FALSE)
        if (mode != "silence") stop("[crop] too few values for writing: 0 < 900", call. = FALSE)
        lu <- vrai_local(adresse, grille, methode)
        terra::values(lu$raster) <- NA_real_
        return(lu)
      }
      vrai_local(adresse, grille, methode)
    },
    .env = env
  )
  list(
    lectures = function() length(lignes(compteur)),
    demandes = function() length(lignes(demandes))
  )
}

images_025 <- function(d) {
  urls <- vapply(1:8, function(i) image_locale(0.01 * i, 0, d, paste0("i", i, ".tif"), "linear"),
                 character(1))
  data.frame(date = as.Date("2025-06-01") + 12 * (0:7),
             heure = as.POSIXct("2025-06-01 06:00:00", tz = "UTC") + 12 * 86400 * (0:7),
             serie = rep(c("A030", "D008"), 4), url = urls, stringsAsFactors = FALSE)
}

# Lecture avec des jetons qui expirent après 3 lectures, comparée à la
# lecture sans signature (sans expiration) des mêmes fichiers.
essai_025 <- function(flux) {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  items <- images_025(d)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  ref <- s1_lire(items, grille, signer = FALSE, flux = 1L, dossier = file.path(d, "ref"))
  sim <- jetons_simules(d, n_lectures = 3L)
  expect_no_warning(
    s <- s1_lire(items, grille, signer = TRUE, flux = flux, dossier = file.path(d, "sas"))
  )
  expect_equal(s$dates, ref$dates)
  for (o in names(ref$orbites)) {
    expect_identical(terra::values(s$orbites[[o]]), terra::values(ref$orbites[[o]]))
  }
  # Des jetons ont bien expiré (403) et des tranches ont été relues.
  expect_gt(sim$demandes(), 1L)
  expect_gt(sim$lectures(), nrow(items))
}

test_that("mission 025 : un jeton qui expire en cours de lecture ne fait plus tomber s1_lire(), r\u00e9sultat identique au bit pr\u00e8s", {
  essai_025(flux = 1L)
})

test_that("mission 025 : idem avec des processus enfants qui se passent le jeton neuf", {
  skip_on_os("windows")
  essai_025(flux = 2L)
})

test_that("mission 025 : sans relecture, le m\u00eame lecteur simul\u00e9 tombe en 403 (le test mord)", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  items <- images_025(d)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  jetons_simules(d, n_lectures = 3L)
  local_mocked_bindings(s1_relectures_403 = 0L)
  expect_error(suppressWarnings(s1_lire(items, grille, signer = TRUE, flux = 1L)), "HTTP 403")
})

test_that("mission 025 : un 403 sans erreur (valeurs douteuses) est aussi relu", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  items <- images_025(d)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  ref <- s1_lire(items, grille, signer = FALSE, flux = 1L)
  sim <- jetons_simules(d, n_lectures = 2L, mode = "silence")
  s <- s1_lire(items, grille, signer = TRUE, flux = 1L)
  for (o in names(ref$orbites)) {
    expect_identical(terra::values(s$orbites[[o]]), terra::values(ref$orbites[[o]]))
  }
  expect_gt(sim$demandes(), 1L)
})

test_that("mission 025 : un jeton refus\u00e9 de fa\u00e7on durable donne une erreur claire, apr\u00e8s une seule relecture", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  items <- images_025(d)
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  sim <- jetons_simules(d, n_lectures = Inf, mode = "toujours")
  expect_error(s1_lire(items, grille, signer = TRUE, flux = 1L),
               "HTTP 403.*1 jeton\\(s\\) SAS neuf\\(s\\) : i1\\.tif.*refus\u00e9 de fa\u00e7on durable")
  # Le premier jeton, puis un seul neuf ; deux lectures de la première tranche.
  expect_identical(sim$demandes(), 2L)
  expect_identical(sim$lectures(), 2L)
})

test_that("mission 025 : une erreur qui n'est pas un 403 n'est pas relue", {
  d <- tempfile("s1-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  items <- images_025(d)
  items$url[1] <- image_locale(0.2, 0, d, "biz.tif", "log")
  grille <- terra::rast(xmin = 55, xmax = 355, ymin = 55, ymax = 355,
                        resolution = 10, crs = "EPSG:32630")
  sim <- jetons_simules(d, n_lectures = Inf)
  expect_error(s1_lire(items, grille, signer = TRUE, flux = 1L), "Scale=log")
  expect_identical(sim$demandes(), 1L)
  expect_identical(sim$lectures(), 1L)
})

# Essai réel (réseau) -----------------------------------------------------------

test_that("essai r\u00e9el : images de 2025 sur un point des Landes, une petite fen\u00eatre lue", {
  skip_if(Sys.getenv("NEMETONSAR_TESTS_RESEAU") != "true",
          "test r\u00e9seau : d\u00e9finir NEMETONSAR_TESTS_RESEAU=true")
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
