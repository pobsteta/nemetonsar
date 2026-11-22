# Réglages par défaut lus, jamais écrits en dur.
p_def <- parametres_sufosat()
p_sans_fermeture <- parametres_sufosat(fermeture = FALSE)

vide <- function(nr, nc) matrix(FALSE, nr, nc)

# Référence naïve de la fermeture, écrite depuis la définition, pixel par
# pixel, sur un plan vide à l'infini : un point (dans l'image ou non) est
# dilaté si un pixel détecté (avec donnée) est dans son carré centré ; un
# pixel de l'image est gardé si tous les points de son carré centré, dans
# l'image ou non, sont dilatés ; jamais sur un pixel sans donnée.
fermeture_naive <- function(x, sans_donnee, k) {
  r <- (k - 1) %/% 2
  nr <- nrow(x)
  nc <- ncol(x)
  dilate <- function(y, z) {
    for (di in -r:r) for (dj in -r:r) {
      a <- y + di
      b <- z + dj
      if (a >= 1 && a <= nr && b >= 1 && b <= nc && !sans_donnee[a, b] && x[a, b]) {
        return(TRUE)
      }
    }
    FALSE
  }
  ero <- matrix(FALSE, nr, nc)
  for (i in seq_len(nr)) for (j in seq_len(nc)) {
    if (sans_donnee[i, j]) next
    ok <- TRUE
    for (di in -r:r) for (dj in -r:r) {
      if (!dilate(i + di, j + dj)) ok <- FALSE
    }
    ero[i, j] <- ok
  }
  ero
}

test_that("un objet de 9 pixels (0,09 ha) est retir\u00e9, un de 10 pixels (0,1 ha) gard\u00e9", {
  det <- vide(12, 12)
  det[2:4, 2:4] <- TRUE   # 9 pixels
  det[8:9, 2:6] <- TRUE   # 10 pixels
  pp <- postprocess(det, parametres = p_sans_fermeture)
  expect_false(any(pp$detection[2:4, 2:4]))
  expect_true(all(pp$detection[8:9, 2:6]))
  expect_equal(sum(pp$detection), 10L)
  expect_equal(nrow(pp$table), 1L)
  expect_equal(pp$table$nb_pixels, 10L)
  expect_equal(pp$table$surface_ha, p_def$surface_min_ha)
})

test_that("la surface minimale suit resolution_m et surface_min_ha", {
  det <- vide(10, 10)
  det[2:4, 2:4] <- TRUE   # 9 pixels
  # 9 pixels de 20 m = 0,36 ha : gardé
  pp <- postprocess(det, parametres = p_sans_fermeture, resolution_m = 20)
  expect_equal(sum(pp$detection), 9L)
  expect_equal(pp$table$surface_ha, 9 * 20^2 / 1e4)
  # Seuil 0,09 ha : 9 pixels de 10 m gardés (égalité gardée)
  p9 <- parametres_sufosat(fermeture = FALSE, surface_min_ha = 0.09)
  expect_equal(sum(postprocess(det, parametres = p9)$detection), 9L)
  # Seuil nul : tout est gardé, même un pixel
  p0 <- parametres_sufosat(fermeture = FALSE, surface_min_ha = 0)
  un <- vide(3, 3)
  un[2, 2] <- TRUE
  expect_equal(sum(postprocess(un, parametres = p0)$detection), 1L)
})

test_that("la surface suit la connexit\u00e9 (diagonales)", {
  # 10 pixels reliés seulement en diagonale : un objet en 8, dix en 4
  det <- vide(12, 12)
  for (i in 1:10) det[i, i] <- TRUE
  p8 <- parametres_sufosat(fermeture = FALSE, connexite = 8L)
  p4 <- parametres_sufosat(fermeture = FALSE, connexite = 4L)
  expect_equal(sum(postprocess(det, parametres = p8)$detection), 10L)
  expect_equal(sum(postprocess(det, parametres = p4)$detection), 0L)
})

test_that("la fermeture comble un trou d'un pixel", {
  det <- vide(10, 10)
  det[3:7, 3:7] <- TRUE
  det[5, 5] <- FALSE
  pp <- postprocess(det)
  expect_true(pp$detection[5, 5])
  expect_equal(sum(pp$detection), 25L)
  expect_equal(pp$table$nb_pixels, 25L)
  # Sans fermeture, le trou reste
  expect_false(postprocess(det, parametres = p_sans_fermeture)$detection[5, 5])
})

test_that("la fermeture ne fusionne pas deux objets \u00e9loign\u00e9s, et relie deux objets proches", {
  k <- p_def$taille_fermeture
  # Deux carrés 4x4 (0,16 ha) séparés par k colonnes vides : pas de fusion
  det <- vide(8, 8 + k + 2)
  det[2:5, 2:5] <- TRUE
  det[2:5, (6 + k):(9 + k)] <- TRUE
  pp <- postprocess(det)
  expect_equal(nrow(pp$table), 2L)
  expect_identical(pp$detection, det)
  # Séparés par k - 1 colonnes : la fermeture les relie
  det2 <- vide(8, 8 + k + 2)
  det2[2:5, 2:5] <- TRUE
  det2[2:5, (5 + k):(8 + k)] <- TRUE
  pp2 <- postprocess(det2)
  expect_equal(nrow(pp2$table), 1L)
  expect_true(all(pp2$detection[2:5, 2:(8 + k)]))
})

test_that("l'ordre est surface puis fermeture", {
  # Bloc 4 x 3 (12 pixels) privé de ses deux pixels centraux et de deux
  # coins opposés : 8 pixels (0,08 ha). Fermé d'abord, il retrouverait ses
  # deux trous et passerait à 10 pixels (0,1 ha), donc serait gardé.
  det <- vide(10, 10)
  det[3:6, 3:5] <- TRUE
  det[4:5, 4] <- FALSE
  det[3, 3] <- FALSE
  det[6, 5] <- FALSE
  expect_equal(sum(det), 8L)
  ferme_d_abord <- fermeture_naive(det, matrix(FALSE, 10, 10), p_def$taille_fermeture)
  expect_gte(sum(ferme_d_abord), 10L) # l'ordre inverse l'aurait gardé
  pp <- postprocess(det)
  expect_equal(sum(pp$detection), 0L)  # surface d'abord : retiré
  expect_equal(nrow(pp$table), 0L)
})

test_that("la fermeture vectoris\u00e9e \u00e9gale la r\u00e9f\u00e9rence na\u00efve", {
  set.seed(6)
  for (essai in 1:30) {
    nr <- sample(1:15, 1)
    nc <- sample(1:15, 1)
    k <- sample(c(1L, 3L, 5L), 1)
    x <- matrix(runif(nr * nc) < 0.4, nr, nc)
    nd <- matrix(runif(nr * nc) < 0.1, nr, nc)
    attendu <- fermeture_naive(x, nd, k)
    obtenu <- if (k > 1L) fermeture_carre(x, nd, k) else x & !nd
    expect_identical(obtenu, attendu)
    # Et par postprocess(), surface nulle, NA = sans donnée
    seg <- x
    seg[nd] <- NA
    p <- parametres_sufosat(surface_min_ha = 0, taille_fermeture = k)
    expect_identical(postprocess(seg, parametres = p)$detection, attendu)
  }
})

test_that("bords : rien de rogn\u00e9, rien de reli\u00e9 au bord, rien hors de l'image", {
  det <- vide(8, 8)
  det[1:4, 1:4] <- TRUE
  det[1, 2] <- FALSE     # échancrure d'un pixel contre le bord
  pp <- postprocess(det)
  # Objet au bord : aucun pixel retiré ; l'échancrure d'un pixel, entre deux
  # pixels détectés, est comblée comme à l'intérieur
  expect_true(all(pp$detection[det]))
  expect_true(pp$detection[1, 2])
  expect_equal(sum(pp$detection), 16L)
  expect_identical(dim(pp$detection), dim(det))
  # Objet à un pixel du bord : la bande de bord n'est pas remplie
  det2 <- vide(8, 8)
  det2[2:6, 2:6] <- TRUE
  pp2 <- postprocess(det2)
  expect_identical(pp2$detection, det2)
  # Image entièrement détectée : inchangée
  plein <- matrix(TRUE, 5, 5)
  expect_identical(postprocess(plein)$detection, plein)
})

test_that("NA : sans donn\u00e9e, jamais d\u00e9tect\u00e9, ni ajout\u00e9 par la fermeture, ni \u00e9rodant", {
  det <- vide(10, 10)
  det[3:7, 3:7] <- TRUE
  det[5, 5] <- NA        # trou sans donnée : reste non détecté
  pp <- postprocess(det)
  expect_false(pp$detection[5, 5])
  expect_true(is.na(pp$objet[5, 5]))
  expect_equal(sum(pp$detection), 24L)
  # Un pixel NA dans le ratio protège le pixel quand rcr est fourni
  det2 <- vide(10, 10)
  det2[3:7, 3:7] <- TRUE
  det2[5, 5] <- FALSE
  rcr <- list(ratio_min_db = matrix(-6, 10, 10), date_min = matrix(21100L, 10, 10))
  rcr$ratio_min_db[5, 5] <- NA
  rcr$date_min[5, 5] <- NA
  pp2 <- postprocess(det2, rcr = rcr)
  expect_false(pp2$detection[5, 5])
  expect_equal(pp2$table$nb_pixels, 24L)
  # Sans rcr, le même trou est comblé
  expect_true(postprocess(det2)$detection[5, 5])
  # Tout NA : aucune détection, table vide
  tout_na <- matrix(NA, 4, 4)
  pp3 <- postprocess(tout_na)
  expect_false(any(pp3$detection))
  expect_equal(nrow(pp3$table), 0L)
})

test_that("r\u00e9\u00e9tiquetage dans l'ordre du premier pixel, colonne par colonne", {
  det <- vide(12, 12)
  det[8:9, 1:5] <- TRUE    # premier pixel : (8, 1)
  det[1:2, 8:12] <- TRUE   # premier pixel : (1, 8)
  det[1:2, 1] <- TRUE      # 2 pixels : retiré
  pp <- postprocess(det, parametres = p_sans_fermeture)
  expect_equal(pp$objet[8, 1], 1L)
  expect_equal(pp$objet[1, 8], 2L)
  expect_true(is.na(pp$objet[1, 1]))
  expect_equal(sort(unique(as.vector(pp$objet))), 1:2)
  expect_identical(!is.na(pp$objet), pp$detection)
})

test_that("table des objets juste sur un cas connu", {
  det <- vide(10, 10)
  det[1:2, 1:5] <- TRUE    # objet 1 : 10 pixels
  det[6:9, 6:8] <- TRUE    # objet 2 : 12 pixels
  ratio <- matrix(0, 10, 10)
  ratio[1:2, 1:5] <- -6
  ratio[1, 1] <- -10
  ratio[6:9, 6:8] <- -4
  date_min <- matrix(NA_integer_, 10, 10)
  # Objet 1 : 10 dates, 5 au 21100 puis 5 au 21112 : médiane basse 21100
  date_min[1, 1:5] <- 21100L
  date_min[2, 1:5] <- 21112L
  # Objet 2 : 12 pixels dont 3 sans date ; 9 dates : 4 x 22001, 5 x 22030
  d2 <- c(rep(22001L, 4), rep(22030L, 5), NA, NA, NA)
  date_min[6:9, 6:8] <- d2
  rcr <- list(ratio_min_db = ratio, date_min = date_min)
  pp <- postprocess(det, rcr = rcr, parametres = p_sans_fermeture)
  tb <- pp$table
  expect_equal(tb$identifiant, 1:2)
  expect_equal(tb$nb_pixels, c(10L, 12L))
  expect_equal(tb$surface_ha, c(0.1, 0.12))
  expect_equal(tb$nb_pixels_dates, c(10L, 9L))
  expect_equal(tb$date_mediane, c(21100L, 22030L))
  expect_equal(tb$date_mediane_date, as.Date(c("2021-04-10", "2022-01-30")))
  expect_equal(tb$date_mediane_date, yyddd_vers_date(tb$date_mediane))
  # Ratio moyen : moyenne linéaire puis dB
  lin1 <- c(db_vers_lineaire(-10), rep(db_vers_lineaire(-6), 9))
  expect_equal(tb$ratio_moyen_db[1], lineaire_vers_db(mean(lin1)))
  expect_equal(tb$ratio_moyen_db[2], -4)
  # Aller-retour date <-> code
  expect_equal(date_vers_yyddd(tb$date_mediane_date), tb$date_mediane)
})

test_that("m\u00e9diane d'un nombre pair : la plus ancienne des deux dates du milieu", {
  det <- vide(4, 6)
  det[1:2, 1:5] <- TRUE   # 10 pixels
  date_min <- matrix(NA_integer_, 4, 6)
  date_min[1:2, 1:5] <- c(21010L, 21020L, 21030L, 21040L, 21050L,
                         21060L, 21070L, 21080L, 21090L, 21100L)
  rcr <- list(ratio_min_db = matrix(-6, 4, 6), date_min = date_min)
  tb <- postprocess(det, rcr = rcr, parametres = p_sans_fermeture)$table
  expect_equal(tb$date_mediane, 21050L)
  # Objet sans aucune date : NA
  rcr$date_min[] <- NA_integer_
  tb2 <- postprocess(det, rcr = rcr, parametres = p_sans_fermeture)$table
  expect_true(is.na(tb2$date_mediane))
  expect_equal(tb2$nb_pixels_dates, 0L)
})

test_that("cha\u00eene compl\u00e8te : rcr_compute, rcr_segment, postprocess", {
  dates <- seq(as.Date("2021-01-05"), by = 12, length.out = 10)
  det <- vide(12, 12)
  det[2:6, 2:6] <- TRUE
  det[4, 4] <- FALSE       # trou
  det[10:12, 2:4] <- TRUE  # 9 pixels : retiré
  serie <- array(0.05, dim = c(12, 12, 10))
  for (t in 6:10) {
    couche <- serie[, , t]
    couche[det] <- 0.05 * db_vers_lineaire(-7)
    serie[, , t] <- couche
  }
  r <- rcr_compute(serie, dates)
  s <- rcr_segment(r)
  pp <- postprocess(s, rcr = r)
  expect_equal(nrow(pp$table), 1L)
  expect_equal(pp$table$nb_pixels, 25L)
  expect_true(pp$detection[4, 4])
  expect_equal(pp$table$date_mediane_date, dates[6])
  # Le pixel comblé compte dans la surface, pas dans le ratio ni la date
  expect_equal(pp$table$nb_pixels_dates, 24L)
  expect_equal(pp$table$ratio_moyen_db, -7, tolerance = 1e-9)
})

test_that("pixels combl\u00e9s : dans la surface, hors date et ratio", {
  det <- vide(10, 10)
  det[3:7, 3:7] <- TRUE
  det[5, 5] <- FALSE                    # trou comblé par la fermeture
  ratio <- matrix(0, 10, 10)
  ratio[det] <- -6                      # le trou garde 0 dB
  date_min <- matrix(21200L, 10, 10)    # date du trou et du fond
  date_min[det] <- 21100L
  pp <- postprocess(det, rcr = list(ratio_min_db = ratio, date_min = date_min))
  expect_true(pp$detection[5, 5])
  expect_equal(pp$table$nb_pixels, 25L)
  expect_equal(pp$table$surface_ha, 0.25)
  expect_equal(pp$table$nb_pixels_dates, 24L)
  expect_equal(pp$table$date_mediane, 21100L)
  expect_equal(pp$table$date_mediane_date, as.Date("2021-04-10"))
  expect_equal(pp$table$ratio_moyen_db, -6)
  # Sans fermeture, même table pour la date et le ratio, surface 0,24 ha
  pp0 <- postprocess(det, rcr = list(ratio_min_db = ratio, date_min = date_min),
                     parametres = p_sans_fermeture)
  expect_equal(pp0$table$nb_pixels, 24L)
  expect_equal(pp0$table$ratio_moyen_db, -6)
})

test_that("sans rcr, les colonnes de date et de ratio valent NA", {
  det <- vide(5, 5)
  det[1:2, 1:5] <- TRUE
  tb <- postprocess(det)$table
  expect_named(tb, c("identifiant", "nb_pixels", "surface_ha", "nb_pixels_dates",
                     "date_mediane", "date_mediane_date", "ratio_moyen_db"))
  expect_true(is.na(tb$date_mediane))
  expect_true(is.na(tb$ratio_moyen_db))
  expect_s3_class(tb$date_mediane_date, "Date")
})

test_that("noms de dimensions gard\u00e9s, aucune d\u00e9tection", {
  det <- vide(3, 4)
  dimnames(det) <- list(paste0("l", 1:3), paste0("c", 1:4))
  pp <- postprocess(det)
  expect_identical(dimnames(pp$detection), dimnames(det))
  expect_identical(dimnames(pp$objet), dimnames(det))
  expect_equal(nrow(pp$table), 0L)
  expect_identical(pp$resolution_m, 10)
})

test_that("entr\u00e9es invalides refus\u00e9es", {
  det <- vide(3, 3)
  expect_error(postprocess(matrix(0, 3, 3)), "logique")
  expect_error(postprocess(list(a = 1)), "rcr_segment")
  expect_error(postprocess(det, resolution_m = 0), "resolution_m")
  expect_error(postprocess(det, resolution_m = c(10, 20)), "resolution_m")
  expect_error(postprocess(det, rcr = list(ratio_min_db = matrix(0, 3, 3))), "rcr")
  expect_error(
    postprocess(det, rcr = list(ratio_min_db = matrix(0, 2, 3), date_min = matrix(1L, 2, 3))),
    "dimensions"
  )
  expect_error(postprocess(det, parametres = list()), "parametres_sufosat")
})
