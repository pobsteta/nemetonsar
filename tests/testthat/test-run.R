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
appels <- new.env()
lire_synthetique <- function(grille, date_debut, date_fin, parametres, dossier) {
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
    for (cp in coupes_run) {
      dedans <- terra::values(terra::rasterize(terra::project(cp$v, terra::crs(grille)), grille,
                                               background = 0, touches = FALSE),
                              mat = FALSE) == 1
      apres <- d >= cp$date
      v[dedans, apres] <- v[dedans, apres] * 10^(-6 / 10)
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
  # Surface : la somme des deux parties (grilles UTM), à la reprojection près ;
  # moins que la coupe vraie, dont le filtre 3 x 3 rogne le bord.
  parties <- vapply(res$tuiles$mgrs, function(m) {
    r <- terra::rast(file.path(dossier_principal, "tuiles", m, "objets.tif"))
    v <- terra::extract(r, terra::project(coupes_run$c1$v, terra::crs(r)))[[2]]
    sum(!is.na(v))
  }, numeric(1))
  # Au plus proche voisin, un pixel L93 de la limite peut prendre la valeur
  # des deux tuiles (limite dite) : au plus un pixel par ligne de la coupe.
  expect_lte(abs(o$surface_ha - sum(parties) * 100 / 1e4), 0.12)
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
  for (n in c("dates", "ratio", "objets")) {
    expect_equal(lire(file.path(dt, "detection", paste0(n, ".tif"))),
                 lire(direct$fichiers[[if (n == "objets") "objets_raster" else n]]))
  }
  # Tous les objets sont dans la période : la tuile garde tout.
  expect_equal(lire(file.path(dt, "dates.tif")), lire(direct$fichiers[["dates"]]))
  expect_equal(lire(file.path(dt, "objets.tif")), lire(direct$fichiers[["objets_raster"]]))
  # Carte finale (Lambert-93) : mêmes objets, mêmes dates, surfaces proches.
  expect_equal(nrow(r1$objets), nrow(direct$objets))
  expect_equal(sort(r1$objets$date_mediane_date), sort(direct$objets$date_mediane_date))
  expect_equal(sort(r1$objets$surface_ha), sort(direct$objets$surface_ha), tolerance = 0.1)
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
