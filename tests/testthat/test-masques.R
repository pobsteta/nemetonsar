skip_if_not_installed("terra")

p_def <- parametres_sufosat()

# Grille UTM 31N, 10 m, `nl` lignes x `nc` colonnes.
grille_m <- function(nl, nc, res = 10, x0 = 600000, y0 = 5000000) {
  terra::rast(nrows = nl, ncols = nc, xmin = x0, xmax = x0 + res * nc,
              ymin = y0, ymax = y0 + res * nl, crs = "EPSG:32631")
}

# Valeurs d'un raster logique en vecteur (cellules ligne par ligne).
vals <- function(r) as.vector(terra::values(r))

carre <- function(x0, y0, cx, cy = cx, crs = "EPSG:32631") {
  terra::vect(sprintf("POLYGON ((%.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f, %.6f %.6f))",
                      x0, y0, x0 + cx, y0, x0 + cx, y0 + cy, x0, y0 + cy, x0, y0),
              crs = crs)
}

# Masque forêt -------------------------------------------------------------

test_that("seuil TCD : 9,9 exclu, 10 gard\u00e9 (>= seuil, M24 'minimum 10 %')", {
  g <- grille_m(1, 5)
  tcd <- terra::rast(g, vals = c(0, 9.9, 10, 10.1, 100))
  f <- masque_foret(tcd, g)
  expect_true(terra::is.bool(f))
  expect_identical(names(f), "foret")
  expect_equal(vals(f), c(FALSE, FALSE, TRUE, TRUE, TRUE))
  # seuil réglable, toujours en %
  f20 <- masque_foret(tcd, g, parametres_sufosat(seuil_tcd = 10.1))
  expect_equal(vals(f20), c(FALSE, FALSE, FALSE, TRUE, TRUE))
})

test_that("codes hors 0-100 (254, 255) et NA sont sans donn\u00e9e", {
  g <- grille_m(1, 5)
  tcd <- terra::rast(g, vals = c(50, 254, 255, NA, -1))
  f <- masque_foret(tcd, g)
  expect_equal(vals(f), c(TRUE, NA, NA, NA, NA))
})

test_that("r\u00e9\u00e9chantillonnage d'un TCD \u00e0 20 m sur une grille \u00e0 10 m", {
  # TCD 2 x 2 pixels de 20 m ; grille 4 x 4 de 10 m sur la même emprise.
  tcd <- grille_m(2, 2, res = 20)
  terra::values(tcd) <- c(5, 50, 10, 255)
  g <- grille_m(4, 4)
  f <- masque_foret(tcd, g)
  expect_equal(terra::res(f), c(10, 10))
  expect_true(terra::compareGeom(f, g))
  m <- matrix(vals(f), 4, 4, byrow = TRUE)
  attendu <- rbind(c(FALSE, FALSE, TRUE, TRUE),
                   c(FALSE, FALSE, TRUE, TRUE),
                   c(TRUE, TRUE, NA, NA),
                   c(TRUE, TRUE, NA, NA))
  expect_equal(m, attendu)
})

test_that("m\u00e9thode average : moyenne des pixels couverts, puis seuil", {
  # TCD 10 m -> grille 20 m : chaque pixel de la grille moyenne 4 pixels.
  tcd <- grille_m(2, 4)
  terra::values(tcd) <- c(0, 20, 9, 9,
                          10, 10, 9, 13)
  g <- grille_m(1, 2, res = 20)
  f_avg <- masque_foret(tcd, g, methode = "average")
  expect_equal(vals(f_avg), c(TRUE, TRUE)) # moyennes 10 et 10
  # le code 255 n'entre pas dans la moyenne
  terra::values(tcd) <- c(255, 20, 9, 9,
                          10, 10, 9, 9)
  expect_equal(vals(masque_foret(tcd, g, methode = "average")), c(TRUE, FALSE)) # 13,3 et 9
})

test_that("TCD en EPSG:3035 projet\u00e9 sur une grille UTM", {
  # Grille UTM, TCD = la même grille reprojetée en 3035 (valeurs par moitié).
  g <- grille_m(20, 20)
  src <- terra::rast(g, vals = rep(c(80, 0), each = 200)) # haut forêt, bas non
  tcd <- terra::project(src, "EPSG:3035", method = "near", res = 10)
  f <- masque_foret(tcd, g)
  expect_true(terra::compareGeom(f, g))
  m <- matrix(vals(f), 20, 20, byrow = TRUE)
  # loin de la limite et des bords, le résultat est sans ambiguïté
  expect_true(all(m[3:8, 3:18]))
  expect_true(all(!m[13:18, 3:18]))
})

test_that("correction 2019 sur un cas connu (raster et polygones)", {
  g <- grille_m(5, 5)
  tcd <- terra::rast(g, vals = 60)
  # Détection 2019 : dates YYDDD sur 2 x 2 pixels, NA ailleurs.
  det <- terra::rast(g, vals = NA_real_)
  det[1:2, 1:2] <- 19180
  f <- masque_foret(tcd, g, detections_2019 = det)
  m <- matrix(vals(f), 5, 5, byrow = TRUE)
  attendu <- matrix(TRUE, 5, 5)
  attendu[1:2, 1:2] <- FALSE
  expect_equal(m, attendu)

  # Même chose avec un polygone (objets.gpkg) : 2 x 2 pixels en haut à gauche.
  poly <- carre(600000, 5000030, 20)
  f2 <- masque_foret(tcd, g, detections_2019 = poly)
  expect_equal(matrix(vals(f2), 5, 5, byrow = TRUE), attendu)

  # Polygone en Lambert-93 : reprojeté.
  f3 <- masque_foret(tcd, g, detections_2019 = terra::project(poly, "EPSG:2154"))
  expect_equal(matrix(vals(f3), 5, 5, byrow = TRUE), attendu)

  # Marge d'un pixel : carré 3 x 3 -> 3 x 3 pixels retirés.
  f4 <- masque_foret(tcd, g, detections_2019 = det, marge_2019 = 1)
  attendu4 <- matrix(TRUE, 5, 5)
  attendu4[1:3, 1:3] <- FALSE
  expect_equal(matrix(vals(f4), 5, 5, byrow = TRUE), attendu4)

  # Une valeur 0 ou FALSE n'est pas une détection.
  det0 <- terra::rast(g, vals = 0)
  expect_true(all(vals(masque_foret(tcd, g, detections_2019 = det0))))
})

test_that("masque_foret \u00e9crit un fichier si demand\u00e9", {
  g <- grille_m(1, 3)
  tcd <- terra::rast(g, vals = c(5, 50, 255))
  f <- tempfile(fileext = ".tif")
  r <- masque_foret(tcd, g, fichier = f)
  expect_true(file.exists(f))
  expect_equal(vals(r), c(FALSE, TRUE, NA))
  expect_equal(as.vector(terra::values(terra::rast(f))), c(0, 1, NA))
})

test_that("masque_foret refuse les entr\u00e9es invalides", {
  g <- grille_m(2, 2)
  tcd <- terra::rast(g, vals = 50)
  expect_error(masque_foret(1:4, g), "SpatRaster")
  expect_error(masque_foret(c(tcd, tcd), g), "une couche")
  expect_error(masque_foret(tcd, "grille"), "grille")
  expect_error(masque_foret(tcd, g, methode = "cubic"), "methode")
  expect_error(masque_foret(tcd, g, marge_2019 = 1.5), "marge_2019")
  expect_error(masque_foret(tcd, g, detections_2019 = 1), "detections_2019")
  expect_error(masque_foret(tcd, g, parametres = list()), "parametres_sufosat")
})

# Masque forêt BD Forêt v2 ---------------------------------------------------

# Grille UTM 30N, 10 m, dans les Landes (6 lignes x 8 colonnes).
grille_l <- function(nl = 6, nc = 8, x0 = 680000, y0 = 4900000) {
  terra::rast(nrows = nl, ncols = nc, xmin = x0, xmax = x0 + 10 * nc,
              ymin = y0, ymax = y0 + 10 * nl, crs = "EPSG:32630")
}
# Rectangle de cellules de grille_l() (colonnes c1..c2, lignes l1..l2,
# lignes comptées du haut), densifié et passé en Lambert-93 (comme la BD
# Forêt) : ses bords tombent sur des limites de cellules, loin des centres.
bloc_l93 <- function(c1, c2, l1, l2, g = grille_l()) {
  x1 <- terra::xmin(g) + 10 * (c1 - 1); x2 <- terra::xmin(g) + 10 * c2
  y2 <- terra::ymax(g) - 10 * (l1 - 1); y1 <- terra::ymax(g) - 10 * l2
  v <- carre(x1, y1, x2 - x1, y2 - y1, crs = "EPSG:32630")
  terra::project(terra::densify(v, 2), "EPSG:2154")
}
# Cinq polygones : FF2-51-51 (colonnes 1-2), LA4 (3-4), FP (5), LA6
# (6, lignes 1-3), code absent (6, lignes 4-6) ; colonnes 7-8 hors polygone.
bdf_l <- function() {
  v <- rbind(bloc_l93(1, 2, 1, 6), bloc_l93(3, 4, 1, 6), bloc_l93(5, 5, 1, 6),
             bloc_l93(6, 6, 1, 3), bloc_l93(6, 6, 4, 6))
  v$CODE_TFV <- c("FF2-51-51", "LA4", "FP", "LA6", NA)
  v$ESSENCE <- c("Pin maritime", "NC", "Peuplier", "NC", NA)
  v
}
matrice <- function(r) matrix(vals(r), terra::nrow(r), terra::ncol(r), byrow = TRUE)

test_that("BD For\u00eat : 32 postes, 30 rattach\u00e9s au niveau I For\u00eat (descriptif de contenu)", {
  expect_equal(nrow(.bdforet_tfv), 32L)
  expect_false(anyDuplicated(.bdforet_tfv$code) > 0)
  expect_equal(length(.bdforet_codes_foret), 30L)
  expect_setequal(setdiff(.bdforet_tfv$code, .bdforet_codes_foret), c("LA4", "LA6"))
  expect_true(all(grepl("^(FF|FO|FP)", .bdforet_codes_foret)))
})

test_that("BD For\u00eat en Lambert-93 sur une grille UTM 10 m : masque juste, trois \u00e9tats", {
  g <- grille_l()
  f <- masque_foret_bdforet(bdf_l(), g)
  expect_true(terra::is.bool(f))
  expect_identical(names(f), "foret")
  expect_true(terra::compareGeom(f, g))
  ligne_haut <- c(TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE)
  ligne_bas <- c(TRUE, TRUE, FALSE, FALSE, TRUE, NA, FALSE, FALSE)
  attendu <- rbind(ligne_haut, ligne_haut, ligne_haut, ligne_bas, ligne_bas, ligne_bas)
  dimnames(attendu) <- NULL
  expect_equal(matrice(f), attendu)
  info <- attr(f, "bdforet")
  expect_equal(info$source, "SpatVector fourni")
  expect_equal(info$nb_polygones, 5L)
  expect_equal(info$codes$foret[match(c("FF2-51-51", "LA4", "FP", "LA6"), info$codes$code)],
               c(TRUE, FALSE, TRUE, FALSE))
})

test_that("BD For\u00eat : codes non forestiers exclus, codes r\u00e9glables, champ sans casse", {
  g <- grille_l()
  v <- bdf_l()
  # Champ en minuscules (comme le WFS) : même résultat.
  w <- v
  names(w) <- tolower(names(w))
  expect_equal(vals(masque_foret_bdforet(w, g)), vals(masque_foret_bdforet(v, g)))
  # Peupleraie retirée des codes forêt.
  f <- masque_foret_bdforet(v, g, codes_foret = "FF2-51-51")
  expect_equal(matrice(f)[1, ], c(TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE))
  # Lande comptée forêt si on le demande.
  f <- masque_foret_bdforet(v, g, codes_foret = c("FF2-51-51", "LA4"))
  expect_equal(matrice(f)[1, 1:5], c(TRUE, TRUE, TRUE, TRUE, FALSE))
  # Code hors nomenclature : avertissement, non-forêt.
  v$CODE_TFV[1] <- "XX9"
  expect_warning(f <- masque_foret_bdforet(v, g), "XX9")
  expect_equal(matrice(f)[1, 1:2], c(FALSE, FALSE))
  # Champ des codes absent.
  expect_error(masque_foret_bdforet(v, g, champ_code = "TFV_INCONNU"), "TFV_INCONNU")
})

test_that("BD For\u00eat : couverture, aucun polygone, correction 2019 comme masque_foret()", {
  g <- grille_l()
  v <- bdf_l()
  # Couverture limitée aux colonnes 1-4 : le reste est sans donnée.
  cv <- bloc_l93(1, 4, 1, 6)
  f <- masque_foret_bdforet(v, g, couverture = cv)
  expect_true(all(is.na(matrice(f)[, 5:8])))
  expect_equal(matrice(f)[, 1:4], matrice(masque_foret_bdforet(v, g))[, 1:4])
  # Aucun polygone sur l'emprise : tout non-forêt.
  f0 <- masque_foret_bdforet(v[0], g)
  expect_true(terra::is.bool(f0))
  expect_true(all(vals(f0) %in% FALSE))
  # Correction 2019 : même règle et même résultat que masque_foret() sur le
  # TCD équivalent.
  f <- masque_foret_bdforet(v, g)
  tcd <- terra::ifel(is.na(f), 255, terra::ifel(f, 60, 5))
  det <- terra::rast(g, vals = 0)
  det[1, 1] <- 19150
  det[4, 5] <- 19200
  for (m in 0:1) {
    expect_equal(vals(masque_foret_bdforet(v, g, detections_2019 = det, marge_2019 = m)),
                 vals(masque_foret(tcd, g, detections_2019 = det, marge_2019 = m)))
  }
  expect_false(vals(masque_foret_bdforet(v, g, detections_2019 = det))[1])
})

test_that("BD For\u00eat lue d'un fichier sur la seule emprise de la grille", {
  g <- grille_l()
  loin <- terra::project(carre(700000, 4950000, 100, crs = "EPSG:32630"), "EPSG:2154")
  v <- rbind(bdf_l(), loin)
  v$CODE_TFV[6] <- "FF31"
  fich <- tempfile(fileext = ".gpkg")
  terra::writeVector(v, fich)
  f <- masque_foret_bdforet(fich, g)
  expect_equal(vals(f), vals(masque_foret_bdforet(bdf_l(), g)))
  expect_equal(attr(f, "bdforet")$nb_polygones, 5L) # le polygone lointain n'est pas lu
  expect_equal(attr(f, "bdforet")$source, fich)
  # Écriture.
  sortie <- tempfile(fileext = ".tif")
  f2 <- masque_foret_bdforet(fich, g, fichier = sortie)
  expect_true(file.exists(sortie))
  expect_equal(vals(f2), vals(f))
})

test_that("WFS BD For\u00eat : URL de la couche IGN, pages lues jusqu'\u00e0 la derni\u00e8re", {
  e <- terra::ext(400000, 402000, 6350000, 6352000)
  u <- bdforet_wfs_url(e, debut = 10L, nb = 5L)
  expect_match(u, "^https://data\\.geopf\\.fr/wfs/ows\\?")
  expect_match(u, "TYPENAMES=LANDCOVER.FORESTINVENTORY.V2:formation_vegetale", fixed = TRUE)
  expect_match(u, "BBOX=400000.00,6350000.00,402000.00,6352000.00,urn:ogc:def:crs:EPSG::2154",
               fixed = TRUE)
  expect_match(u, "SRSNAME=EPSG:2154", fixed = TRUE)
  expect_match(u, "COUNT=5&STARTINDEX=10&SORTBY=id", fixed = TRUE)
  # Lecteur simulé : 5 objets, pages de 2 ; un doublon entre pages.
  tous <- rbind(bdf_l())
  tous$id <- c("a", "b", "c", "d", "e")
  appels <- character(0)
  lecteur <- function(url) {
    appels <<- c(appels, url)
    debut <- as.integer(sub(".*STARTINDEX=([0-9]+).*", "\\1", url))
    k <- seq(debut + 1L, length.out = 2L)
    k <- k[k <= 5L]
    if (debut == 2L) k <- c(2L, 3L) # doublon "b"
    tous[k]
  }
  v <- lire_bdforet_wfs(e, nb = 2L, lecteur = lecteur)
  expect_length(appels, 3L)
  expect_equal(v$id, c("a", "b", "c", "e"))
  # Réponse vide : SpatVector vide.
  vide <- lire_bdforet_wfs(e, nb = 2L, lecteur = function(url) tous[0])
  expect_equal(nrow(vide), 0L)
  # Erreur du service : message clair avec l'URL.
  expect_error(lire_bdforet_wfs(e, lecteur = function(url) stop("HTTP 400")),
               "Lecture du WFS BD For")
})

test_that("masque_foret_bdforet refuse les entr\u00e9es invalides", {
  g <- grille_l()
  v <- bdf_l()
  expect_error(masque_foret_bdforet(v, "grille"), "grille")
  expect_error(masque_foret_bdforet(42, g), "bdforet")
  expect_error(masque_foret_bdforet(tempfile(fileext = ".gpkg"), g), "introuvable")
  expect_error(masque_foret_bdforet(terra::centroids(v), g), "polygones")
  expect_error(masque_foret_bdforet(v, g, codes_foret = c("FF0", NA)), "codes_foret")
  expect_error(masque_foret_bdforet(v, g, codes_foret = character(0)), "codes_foret")
  expect_error(masque_foret_bdforet(v, g, marge_2019 = -1), "marge_2019")
  expect_error(masque_foret_bdforet(v, g, couverture = "x"), "couverture")
  sans_crs <- v
  terra::crs(sans_crs) <- ""
  expect_error(masque_foret_bdforet(sans_crs, g), "coordonn")
})

test_that("essai r\u00e9el : BD For\u00eat v2 par le WFS sur 1 km2 des Landes", {
  skip_if(Sys.getenv("NEMETONSAR_TESTS_RESEAU") != "true",
          "test r\u00e9seau : d\u00e9finir NEMETONSAR_TESTS_RESEAU=true")
  skip_on_cran()
  skip_if_offline("data.geopf.fr")
  centre <- terra::crds(terra::project(terra::vect(cbind(-0.80, 44.20), crs = "EPSG:4326"),
                                       "EPSG:32630"))
  x0 <- floor(centre[1] / 10) * 10 - 500
  y0 <- floor(centre[2] / 10) * 10 - 500
  g <- terra::rast(xmin = x0, xmax = x0 + 1000, ymin = y0, ymax = y0 + 1000,
                   resolution = 10, crs = "EPSG:32630")
  f <- masque_foret_bdforet(NULL, g)
  info <- attr(f, "bdforet")
  expect_gt(info$nb_polygones, 0L)
  expect_match(info$source, "LANDCOVER.FORESTINVENTORY.V2:formation_vegetale", fixed = TRUE)
  expect_true(all(info$codes$code %in% .bdforet_tfv$code))
  # Massif landais : la forêt domine.
  expect_gt(mean(vals(f) %in% TRUE), 0.5)
})

# Masquer hors forêt -------------------------------------------------------

test_that("masquer_hors_foret met NA hors for\u00eat et sans donn\u00e9e, sur toutes les couches", {
  g <- grille_m(1, 3)
  pile <- terra::rast(g, nlyrs = 2, vals = 0.05)
  names(pile) <- c("d1", "d2")
  foret <- masque_foret(terra::rast(g, vals = c(50, 5, 255)), g)
  r <- masquer_hors_foret(pile, foret)
  expect_identical(names(r), c("d1", "d2"))
  v <- terra::values(r)
  expect_equal(unname(v[, 1]), c(0.05, NA, NA))
  expect_equal(unname(v[, 2]), c(0.05, NA, NA))
  expect_error(masquer_hors_foret(pile, masque_foret(terra::rast(grille_m(1, 4), vals = 50),
                                                       grille_m(1, 4))), "grille")
})

test_that("cha\u00eene : piles masqu\u00e9es -> aucune d\u00e9tection hors for\u00eat", {
  # Une coupe de -6 dB de 10 x 8 pixels ; les colonnes 8 à 12 sont non forestières.
  g <- grille_m(12, 12)
  dates <- seq(as.Date("2018-01-03"), as.Date("2019-12-31"), by = 12)
  set.seed(3)
  v <- matrix(0.05 * stats::rgamma(144 * length(dates), 200, 200), nrow = 144)
  ligne <- rep(1:12, each = 12)
  colonne <- rep(1:12, 12)
  coupe <- ligne %in% 2:11 & colonne %in% 3:10
  apres <- dates >= as.Date("2019-06-15")
  v[coupe, apres] <- v[coupe, apres] * 10^(-6 / 10)
  pile <- terra::rast(g, nlyrs = length(dates))
  terra::values(pile) <- v
  foret <- masque_foret(terra::rast(g, vals = ifelse(colonne <= 7, 70, 0)), g)
  pile_m <- masquer_hors_foret(pile, foret)
  dos <- file.path(tempdir(), "masques-chaine")
  res <- nemetonsar_detecter(list(a = pile_m), list(dates), dos)
  d <- terra::values(terra::rast(res$fichiers[["dates"]]))[, 1]
  expect_true(any(!is.na(d)))
  expect_true(all(is.na(d[colonne > 7])))
  unlink(dos, recursive = TRUE)
})

# Masque feu ---------------------------------------------------------------

objets_test <- function() {
  # quatre objets de 100 m x 100 m (1 ha), espacés
  o <- rbind(carre(0, 0, 100), carre(200, 0, 100), carre(400, 0, 100), carre(600, 0, 100))
  o$identifiant <- 1:4
  o$surface_ha <- 1
  o
}

test_that("objet br\u00fbl\u00e9 \u00e0 75 % retir\u00e9, \u00e0 74 % gard\u00e9 (>= seuil, M24 '75 % or more')", {
  o <- objets_test()
  brules <- rbind(
    carre(0, 0, 100, 75),    # objet 1 : 75 %
    carre(200, 0, 100, 74),  # objet 2 : 74 %
    carre(400, 0, 100, 100)  # objet 3 : 100 %
  )                          # objet 4 : 0 %
  res <- masque_feu(o, brules)
  expect_equal(res$table$identifiant, 1:4)
  expect_equal(res$table$part_brulee, c(0.75, 0.74, 1, 0), tolerance = 1e-9)
  expect_equal(res$table$surface_brulee_ha, c(0.75, 0.74, 1, 0), tolerance = 1e-9)
  expect_equal(res$table$retire, c(TRUE, FALSE, TRUE, FALSE))
  expect_equal(res$objets$identifiant, c(2L, 4L))
  expect_equal(res$retires$identifiant, c(1L, 3L))
  # colonnes d'origine gardées, part brûlée ajoutée (table des objets mise à jour)
  expect_true(all(c("identifiant", "surface_ha", "part_brulee") %in% names(res$objets)))
  expect_equal(res$objets$part_brulee, c(0.74, 0), tolerance = 1e-9)
  expect_null(res$raster)
  # seuil réglable (fraction)
  res2 <- masque_feu(o, brules, parametres_sufosat(seuil_feu = 0.74))
  expect_equal(res2$table$retire, c(TRUE, TRUE, TRUE, FALSE))
})

test_that("polygones qui se recouvrent compt\u00e9s une fois ; plusieurs polygones par objet", {
  o <- objets_test()[1]
  brules <- rbind(carre(0, 0, 100, 50), carre(0, 0, 100, 50), carre(0, 50, 100, 25))
  res <- masque_feu(o, brules)
  expect_equal(res$table$part_brulee, 0.75, tolerance = 1e-9)
  expect_true(res$table$retire)
})

test_that("polygones EFFIS dans un autre syst\u00e8me : reprojet\u00e9s", {
  o <- objets_test()
  # grand carré brûlé sur les objets 1 et 2 seulement, en EPSG:4326 et 3035
  zone <- carre(-50, -50, 400, 200)
  for (crs in c("EPSG:4326", "EPSG:3035")) {
    res <- masque_feu(o, terra::project(zone, crs))
    expect_equal(res$table$retire, c(TRUE, TRUE, FALSE, FALSE))
    expect_equal(res$table$part_brulee[1:2], c(1, 1), tolerance = 1e-6)
  }
})

test_that("aucun polygone br\u00fbl\u00e9, ou sans intersection : rien n'est retir\u00e9", {
  o <- objets_test()
  vide <- carre(5000, 5000, 10)[0]
  res <- masque_feu(o, vide)
  expect_equal(res$table$part_brulee, rep(0, 4))
  expect_equal(nrow(res$objets), 4)
  expect_equal(nrow(res$retires), 0)
  res2 <- masque_feu(o, carre(5000, 5000, 10))
  expect_false(any(res2$table$retire))
})

test_that("objets en raster (objets.tif) : identifiants retir\u00e9s mis \u00e0 NA", {
  g <- grille_m(10, 20, x0 = 0, y0 = 0)
  r <- terra::rast(g, vals = NA_real_)
  r[2:5, 2:5] <- 1      # 16 pixels
  r[2:5, 12:15] <- 2    # 16 pixels
  # objet 1 brûlé sur 12 pixels de 16 (75 %), objet 2 sur 11 (68,75 %)
  # ligne 2 = y de 80 à 90 ; colonnes 2:5 = x de 10 à 50
  brules <- rbind(carre(10, 60, 40, 30), carre(110, 60, 30, 30), carre(140, 60, 10, 20))
  res <- masque_feu(r, brules)
  expect_equal(res$table$identifiant, c(1, 2))
  expect_equal(res$table$part_brulee, c(0.75, 11 / 16), tolerance = 1e-9)
  expect_equal(res$table$retire, c(TRUE, FALSE))
  v <- as.vector(terra::values(res$raster))
  expect_false(any(v == 1, na.rm = TRUE))
  expect_equal(sum(v == 2, na.rm = TRUE), 16)
})

test_that("masque_feu refuse les entr\u00e9es invalides", {
  o <- objets_test()
  b <- carre(0, 0, 10)
  expect_error(masque_feu(data.frame(identifiant = 1), b), "SpatVector")
  sans_id <- o
  sans_id$identifiant <- NULL
  expect_error(masque_feu(sans_id, b), "identifiant")
  double <- o
  double$identifiant <- c(1L, 1L, 2L, 3L)
  expect_error(masque_feu(double, b), "doublon")
  expect_error(masque_feu(o, terra::vect(cbind(0, 0), crs = "EPSG:32631")), "polygones")
  expect_error(masque_feu(o, "effis"), "SpatVector")
})
