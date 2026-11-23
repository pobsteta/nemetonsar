# Tests de compare_reference() sur des cartes synthétiques dont l'accord est
# connu. Pixels de 10 m (1 pixel = 0,01 ha), Lambert-93.

gabarit_cmp <- function(nl = 20, nc = 20, dx = 0, dy = 0, crs = "EPSG:2154") {
  terra::rast(nrows = nl, ncols = nc, xmin = 400000 + dx, xmax = 400000 + dx + 10 * nc,
              ymin = 6350000 + dy, ymax = 6350000 + dy + 10 * nl, crs = crs)
}
carte_pub <- function(g = gabarit_cmp()) terra::setValues(g, 0L)
carte_rec <- function(g = gabarit_cmp()) terra::setValues(g, NA_integer_)
PERIODE <- c("2018-01-01", "2025-09-30")

test_that("cas de base : surfaces, parts, \u00e9cart de date et objets connus", {
  pub <- carte_pub()
  pub[3:8, 3:8] <- 24075L            # 36 pixels, 15 mars 2024
  rec <- carte_rec()
  rec[3:8, 3:7] <- 24087L            # 30 pixels, 27 mars 2024 (+12 j)
  cmp <- compare_reference(rec, pub, PERIODE)
  r <- cmp$resume
  expect_equal(r$surface_publiee_ha, 0.36)
  expect_equal(r$surface_recalculee_ha, 0.30)
  expect_equal(r$surface_commune_ha, 0.30)
  expect_equal(r$part_publiee_retrouvee, 30 / 36)
  expect_equal(r$part_recalculee_absente, 0)
  expect_identical(r$nb_pixels_dates_communs, 30L)
  expect_equal(r$ecart_date_median_j, 12)
  expect_equal(r$ecart_date_absolu_median_j, 12)
  expect_identical(c(r$objets_reference, r$objets_retrouves, r$objets_recalcules,
                     r$objets_confirmes), c(1L, 1L, 1L, 1L))
  expect_equal(c(r$rappel, r$precision, r$f1), c(1, 1, 1))
  expect_match(cmp$reprojection, "^aucune")
  o <- cmp$objets_reference
  expect_equal(o$part_detectee, 30 / 36)
  expect_identical(o$date_mediane, 24075L)
  expect_equal(o$date_mediane_date, as.Date("2024-03-15"))
  # Le point de contrôle est le centre d'un pixel de l'objet.
  expect_identical(as.integer(terra::extract(pub, cbind(o$x, o$y))[[1]]), 24075L)
})

test_that("un objet est retrouv\u00e9 au-del\u00e0 de 75 % de sa surface, strictement", {
  pub <- carte_pub()
  pub[2:5, 2:6] <- 21100L            # objet A : 20 pixels
  pub[12:15, 2:6] <- 21100L          # objet B : 20 pixels
  rec <- carte_rec()
  rec[2:5, 2:4] <- 21100L            # A : 12 pixels...
  rec[2:4, 5] <- 21100L              # ... + 3 = 15 / 20 = 75 % : pas retrouvé
  rec[12:15, 2:5] <- 21100L          # B : 16 / 20 = 80 % : retrouvé
  cmp <- compare_reference(rec, pub, PERIODE)
  o <- cmp$objets_reference
  expect_equal(sort(o$part_detectee), c(0.75, 0.80))
  expect_identical(o$retrouve[order(o$part_detectee)], c(FALSE, TRUE))
  expect_equal(cmp$resume$rappel, 0.5)
  expect_equal(cmp$resume$precision, 1)
  expect_equal(cmp$resume$f1, 2 * 0.5 / 1.5)
  # Le seuil est un paramètre : à 0,7, les deux sont retrouvés.
  expect_equal(compare_reference(rec, pub, PERIODE, seuil_objet = 0.7)$resume$rappel, 1)
})

test_that("une d\u00e9tection absente de la r\u00e9f\u00e9rence baisse la pr\u00e9cision", {
  pub <- carte_pub()
  pub[2:5, 2:6] <- 22150L            # 20 pixels
  rec <- carte_rec()
  rec[2:5, 2:6] <- 22150L
  rec[12:16, 12:17] <- 23010L        # 30 pixels absents de la référence
  r <- compare_reference(rec, pub, PERIODE)$resume
  expect_equal(r$surface_recalculee_ha, 0.5)
  expect_equal(r$part_publiee_retrouvee, 1)
  expect_equal(r$part_recalculee_absente, 30 / 50)
  expect_identical(c(r$objets_recalcules, r$objets_confirmes), c(2L, 1L))
  expect_equal(r$precision, 0.5)
  expect_equal(r$rappel, 1)
})

test_that("\u00e9cart de date sign\u00e9 et m\u00e9dian sur les pixels communs", {
  pub <- carte_pub()
  pub[2:3, 2:6] <- 24100L            # 10 pixels
  rec <- carte_rec()
  rec[2, 2:6] <- 24090L              # 5 pixels à -10 j
  rec[3, 2:4] <- 24130L              # 3 pixels à +30 j
  rec[3, 5:6] <- 24070L              # 2 pixels à -30 j
  r <- compare_reference(rec, pub, PERIODE)$resume
  # écarts : -30 -30 -10 -10 -10 -10 -10 30 30 30 ; médiane -10 ;
  # absolus : 10 x 5 et 30 x 5, médiane 20
  expect_equal(r$ecart_date_median_j, -10)
  expect_equal(r$ecart_date_absolu_median_j, 20)
  # Décembre / janvier : 24366 (31/12/2024) contre 25001 (01/01/2025) = 1 jour.
  pub2 <- carte_pub(); pub2[2:5, 2:5] <- 24366L
  rec2 <- carte_rec(); rec2[2:5, 2:5] <- 25001L
  expect_equal(compare_reference(rec2, pub2, PERIODE)$resume$ecart_date_median_j, 1)
})

test_that("la p\u00e9riode filtre les objets sur leur date m\u00e9diane, des deux c\u00f4t\u00e9s", {
  pub <- carte_pub()
  pub[2:4, 2:5] <- 17284L            # 2017 : hors période
  pub[8:10, 2:5] <- 25273L           # 30/09/2025 : dans la période (incluse)
  pub[14:16, 2:5] <- 25274L          # 01/10/2025 : hors période
  rec <- carte_rec()
  rec[14:16, 2:5] <- 25280L          # recalculée après la période : écartée
  rec[8:10, 2:5] <- 25270L
  cmp <- compare_reference(rec, pub, PERIODE)
  expect_identical(cmp$resume$objets_reference, 1L)
  expect_identical(cmp$resume$objets_recalcules, 1L)
  expect_equal(cmp$resume$surface_publiee_ha, 0.12)
  expect_equal(cmp$resume$part_publiee_retrouvee, 1)
  expect_identical(cmp$objets_reference$date_mediane, 25273L)
})

test_that("0 et NA de la r\u00e9f\u00e9rence valent pas de coupe", {
  pub <- carte_pub()
  pub[2:4, 2:5] <- 20200L
  pub[10:12, 2:5] <- NA
  rec <- carte_rec()
  rec[10:12, 2:5] <- 20200L
  r <- compare_reference(rec, pub, PERIODE)$resume
  expect_equal(r$surface_publiee_ha, 0.12)
  expect_equal(r$surface_commune_ha, 0)
  expect_equal(r$part_recalculee_absente, 1)
  expect_true(is.na(r$ecart_date_median_j))
  expect_equal(c(r$rappel, r$precision, r$f1), c(0, 0, 0))
})

test_that("une r\u00e9f\u00e9rence sur une autre grille est reprojet\u00e9e au plus proche voisin, et dit", {
  pub <- carte_pub()
  pub[3:8, 3:8] <- 24075L
  rec <- carte_rec()
  rec[3:8, 3:7] <- 24087L
  attendu <- compare_reference(rec, pub, PERIODE)
  # Même contenu sur une grille décalée de 3 m (comme l'origine de la v3.0.1) et
  # plus large : le plus proche voisin rend les mêmes pixels.
  g <- gabarit_cmp(nl = 30, nc = 30, dx = -47, dy = -53)
  pub_dec <- terra::project(pub, g, method = "near")
  pub_dec <- terra::subst(pub_dec, NA, 0L)
  cmp <- compare_reference(rec, pub_dec, PERIODE)
  expect_match(cmp$reprojection, "plus proche voisin")
  expect_equal(cmp$resume, attendu$resume)
  # Une référence en UTM est aussi lue sur la grille recalculée.
  pub_utm <- terra::project(pub, "EPSG:32630", method = "near", res = 10)
  cmp_utm <- compare_reference(rec, pub_utm, PERIODE)
  expect_gt(cmp_utm$resume$surface_commune_ha, 0)
  expect_match(cmp_utm$reprojection, "32630")
  # Une référence qui ne recouvre pas la carte est refusée.
  loin <- terra::setValues(gabarit_cmp(dx = 1e5), 0L)
  expect_error(compare_reference(rec, loin, PERIODE), "ne recouvre pas")
})

test_that("l'AOI restreint la comparaison aux pixels dont le centre y est", {
  pub <- carte_pub()
  pub[2:5, 2:5] <- 21050L             # dans la moitié ouest
  pub[2:5, 15:18] <- 21050L           # dans la moitié est
  rec <- carte_rec()
  rec[2:5, 2:5] <- 21050L
  ouest <- terra::vect(terra::ext(400000, 400100, 6350000, 6350200), crs = "EPSG:2154")
  r <- compare_reference(rec, pub, PERIODE, aoi = ouest)$resume
  expect_equal(r$surface_publiee_ha, 0.16)
  expect_equal(r$part_publiee_retrouvee, 1)
  r2 <- compare_reference(rec, pub, PERIODE)$resume
  expect_equal(r2$part_publiee_retrouvee, 0.5)
})

test_that("la connexit\u00e9 vient des param\u00e8tres et vaut pour les deux cartes", {
  pub <- carte_pub()
  pub[2:4, 2:4] <- 22010L
  pub[5:7, 5:7] <- 22010L             # touche le premier par un coin
  rec <- carte_rec()
  rec[2:4, 2:4] <- 22010L
  c8 <- compare_reference(rec, pub, PERIODE)
  expect_identical(c8$resume$objets_reference, 1L)      # 9 / 18 : pas retrouvé
  expect_equal(c8$resume$rappel, 0)
  c4 <- compare_reference(rec, pub, PERIODE, parametres = parametres_sufosat(connexite = 4L))
  expect_identical(c4$resume$objets_reference, 2L)
  expect_equal(c4$resume$rappel, 0.5)
})

test_that("ventilation par ann\u00e9e", {
  pub <- carte_pub()
  pub[2:3, 2:6] <- 19100L             # 2019 : 10 pixels
  pub[10:13, 2:6] <- 22100L           # 2022 : 20 pixels
  rec <- carte_rec()
  rec[2:3, 2:6] <- 19110L             # 2019 retrouvée, +10 j
  rec[16:18, 10:13] <- 23200L         # 2023 : 12 pixels absents
  pa <- compare_reference(rec, pub, PERIODE)$par_annee
  expect_identical(pa$annee, c(2019L, 2022L, 2023L))
  expect_equal(pa$surface_publiee_ha, c(0.10, 0.20, 0))
  expect_equal(pa$surface_retrouvee_ha, c(0.10, 0, 0))
  expect_equal(pa$part_publiee_retrouvee, c(1, 0, NA))
  expect_equal(pa$surface_absente_ha, c(0, 0, 0.12))
  expect_equal(pa$part_recalculee_absente, c(0, NA, 1))
  expect_equal(pa$ecart_date_median_j, c(10, NA, NA))
})

test_that("un dossier de sortie est lu (dates.tif et objets.tif, pixels combl\u00e9s sans date)", {
  d <- tempfile("cmp-")
  dir.create(d)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  rec <- carte_rec()
  rec[3:8, 3:8] <- 24087L
  rec[5, 5] <- NA                     # comblé par la fermeture : objet sans date
  obj <- carte_rec()
  obj[3:8, 3:8] <- 1L
  terra::writeRaster(rec, file.path(d, "dates.tif"), datatype = "INT4S")
  terra::writeRaster(obj, file.path(d, "objets.tif"), datatype = "INT4S")
  pub <- carte_pub()
  pub[3:8, 3:8] <- 24075L
  cmp <- compare_reference(d, pub, PERIODE)
  expect_equal(cmp$resume$surface_recalculee_ha, 0.36)
  expect_equal(cmp$resume$part_publiee_retrouvee, 1)
  expect_identical(cmp$resume$nb_pixels_dates_communs, 35L)
  # Même chose par la liste rendue par nemetonsar_run().
  res <- list(fichiers = c(dates = file.path(d, "dates.tif"), objets = file.path(d, "objets.tif")))
  expect_equal(compare_reference(res, pub, PERIODE)$resume, cmp$resume)
  # Et par un chemin de raster (référence en fichier) ; sans objets.tif, le pixel
  # sans date n'est pas détecté.
  terra::writeRaster(pub, file.path(d, "pub.tif"), datatype = "INT2S")
  r3 <- compare_reference(file.path(d, "dates.tif"), file.path(d, "pub.tif"), PERIODE)$resume
  expect_equal(r3$surface_recalculee_ha, 0.35)
})

test_that("aucune d\u00e9tection : z\u00e9ros et NA, sans erreur", {
  cmp <- compare_reference(carte_rec(), carte_pub(), PERIODE)
  expect_equal(cmp$resume$surface_publiee_ha, 0)
  expect_true(is.na(cmp$resume$part_publiee_retrouvee))
  expect_true(is.na(cmp$resume$rappel))
  expect_identical(nrow(cmp$objets_reference), 0L)
  expect_identical(nrow(cmp$par_annee), 0L)
  expect_s3_class(cmp$objets_recalcules$date_mediane_date, "Date")
})

test_that("les entr\u00e9es invalides sont refus\u00e9es", {
  rec <- carte_rec()
  pub <- carte_pub()
  expect_error(compare_reference(rec, pub, "2018-01-01"), "deux dates")
  expect_error(compare_reference(rec, pub, c("2025-01-01", "2018-01-01")), "date_debut", fixed = TRUE)
  expect_error(compare_reference(rec, pub, PERIODE, seuil_objet = 1), "seuil_objet")
  expect_error(compare_reference(rec, pub, PERIODE, seuil_objet = NA), "seuil_objet")
  expect_error(compare_reference(42, pub, PERIODE), "sorties")
  expect_error(compare_reference("/nulle/part", pub, PERIODE), "introuvable")
  expect_error(compare_reference(rec, "/nulle/part.tif", PERIODE), "introuvable")
  expect_error(compare_reference(rec, pub, PERIODE, aoi = 3), "aoi")
  vide <- tempfile("vide-")
  dir.create(vide)
  on.exit(unlink(vide, recursive = TRUE), add = TRUE)
  expect_error(compare_reference(vide, pub, PERIODE), "dates.tif")
})

test_that("r\u00e9seau : la carte des dates v3.0.1 est lue et compar\u00e9e \u00e0 elle-m\u00eame", {
  skip_if(Sys.getenv("NEMETONSAR_TESTS_RESEAU") != "true",
          "test r\u00e9seau : d\u00e9finir NEMETONSAR_TESTS_RESEAU=true")
  url <- paste0("/vsicurl/https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/sufosat/",
                "forest-clearcuts_mainland-france_sufosat_dates_v3_set25.tif")
  v3 <- tryCatch(suppressWarnings(terra::rast(url)), error = function(e) NULL)
  skip_if(is.null(v3), "carte v3.0.1 inaccessible (403 depuis la session du 2026-11-22)")
  fen <- terra::crop(v3, terra::ext(395000, 396000, 6349000, 6350000))
  rec <- terra::classify(fen, cbind(0, NA))
  cmp <- compare_reference(rec, url, PERIODE)
  expect_match(cmp$reprojection, "plus proche voisin")
  if (cmp$resume$surface_publiee_ha > 0) expect_equal(cmp$resume$part_publiee_retrouvee, 1)
})
