# Séries synthétiques : niveau stable de forêt, en linéaire (environ -13 dB).
niveau <- 0.05
dates_12 <- function(n, debut = "2021-01-05") seq(as.Date(debut), by = 12, length.out = n)

# Référence naïve, pixel par pixel, écrite directement depuis la définition
# (Mb = xb dernières images valides jusqu'à d_i incluse, Ma = xa premières
# images valides après d_i), pour contrôler la version vectorisée.
rcr_naif <- function(serie, dates, xa, xb) {
  d <- dim(serie)
  ratio <- matrix(NA_real_, d[1], d[2])
  apres <- matrix(NA_integer_, d[1], d[2])
  avant <- matrix(NA_integer_, d[1], d[2])
  for (l in seq_len(d[1])) for (k in seq_len(d[2])) {
    v <- serie[l, k, ]
    v[!is.na(v) & v <= 0] <- NA
    idx <- which(!is.na(v))
    for (j in seq_along(idx)) {
      if (j + xa > length(idx)) break
      b <- idx[max(1, if (is.infinite(xb)) 1 else j - xb + 1):j]
      a <- idx[(j + 1):(j + xa)]
      r <- 10 * log10(mean(v[a]) / mean(v[b]))
      if (is.na(ratio[l, k]) || r < ratio[l, k]) {
        ratio[l, k] <- r
        apres[l, k] <- date_vers_yyddd(dates[idx[j + 1]])
        avant[l, k] <- date_vers_yyddd(dates[idx[j]])
      }
    }
  }
  list(ratio_min_db = ratio, date_min = apres, date_avant = avant)
}

test_that("une chute de 6 dB est retrouvée à la date injectée", {
  dates <- dates_12(20)
  serie <- array(niveau, dim = c(3, 4, 20))
  serie[2, 3, 11:20] <- niveau * db_vers_lineaire(-6)
  r <- rcr_compute(serie, dates)
  expect_equal(r$ratio_min_db[2, 3], -6)
  expect_identical(r$date_min[2, 3], date_vers_yyddd(dates[11]))
  expect_identical(r$date_avant[2, 3], date_vers_yyddd(dates[10]))
  # aller-retour date <-> YYDDD
  expect_identical(yyddd_vers_date(r$date_min[2, 3]), dates[11])
  expect_identical(yyddd_vers_date(r$date_avant[2, 3]), dates[10])
  # le ratio de -6 dB passe sous les deux seuils effectifs
  s <- seuils_db(r$parametres)
  expect_true(r$ratio_min_db[2, 3] < s[["ts"]])
  # passage linéaire <-> dB : le ratio retrouve le rapport des intensités
  expect_equal(db_vers_lineaire(r$ratio_min_db[2, 3]), db_vers_lineaire(-6))
})

test_that("une série stable donne un ratio de 0 dB, au-dessus des seuils", {
  dates <- dates_12(15)
  serie <- array(niveau, dim = c(2, 2, 15))
  r <- rcr_compute(serie, dates)
  expect_equal(r$ratio_min_db, matrix(0, 2, 2))
  s <- seuils_db(r$parametres)
  expect_true(all(r$ratio_min_db > s[["tp"]]))
  expect_true(all(r$ratio_min_db > s[["ts"]]))
})

test_that("un bruit modéré sur forêt stable reste au-dessus des seuils", {
  set.seed(1)
  dates <- dates_12(30)
  serie <- array(niveau * db_vers_lineaire(rnorm(5 * 5 * 30, sd = 0.5)), dim = c(5, 5, 30))
  r <- rcr_compute(serie, dates)
  expect_true(all(r$ratio_min_db > seuils_db(r$parametres)[["tp"]]))
})

test_that("le rendu a la forme annoncée", {
  dates <- dates_12(8)
  serie <- array(niveau, dim = c(2, 3, 8), dimnames = list(c("a", "b"), c("x", "y", "z"), NULL))
  r <- rcr_compute(serie, dates)
  expect_named(r, c("ratio_min_db", "date_min", "date_avant", "duree_xa_jours", "parametres"))
  expect_identical(dim(r$ratio_min_db), c(2L, 3L))
  expect_identical(dimnames(r$date_min), list(c("a", "b"), c("x", "y", "z")))
  expect_type(r$date_min, "integer")
  expect_type(r$date_avant, "integer")
  expect_type(r$duree_xa_jours, "integer")
  expect_s3_class(r$parametres, "parametres_sufosat")
})

test_that("la version vectorisée égale la définition pixel par pixel", {
  set.seed(42)
  nt <- 25
  dates <- sort(as.Date("2020-01-01") + sample(0:700, nt))
  serie <- array(niveau * db_vers_lineaire(rnorm(4 * 6 * nt, sd = 2)), dim = c(4, 6, nt))
  serie[sample(length(serie), 120)] <- NA
  serie[1, 1, ] <- NA # pixel jamais valide
  serie[1, 2, 4:nt] <- NA # trop peu d'images valides
  for (xa in c(1L, 3L)) for (xb in c(Inf, 1, 4)) {
    p <- parametres_sufosat(xa = xa, xb = xb)
    r <- rcr_compute(serie, dates, p)
    attendu <- rcr_naif(serie, dates, xa, xb)
    expect_equal(r$ratio_min_db, attendu$ratio_min_db)
    expect_identical(r$date_min, attendu$date_min)
    expect_identical(r$date_avant, attendu$date_avant)
  }
  expect_true(is.na(r$ratio_min_db[1, 1]))
  expect_true(is.na(r$date_min[1, 2]))
})

test_that("les images manquantes (neige) sont ignorées", {
  dates <- dates_12(20)
  serie <- array(niveau, dim = c(1, 2, 20))
  serie[, , 11:20] <- niveau * db_vers_lineaire(-6)
  # pixel 2 : les deux premières images après la chute sont écartées
  serie[1, 2, 11:12] <- NA
  # et une image avant la chute aussi
  serie[1, 2, 5] <- NA
  r <- rcr_compute(serie, dates)
  expect_equal(r$ratio_min_db[1, ], c(-6, -6))
  expect_identical(r$date_min[1, 1], date_vers_yyddd(dates[11]))
  # la chute est datée à la première image valide qui la montre
  expect_identical(r$date_min[1, 2], date_vers_yyddd(dates[13]))
  expect_identical(r$date_avant[1, 2], date_vers_yyddd(dates[10]))
  # Xa sur les dates réelles : 3 images valides après le 10, soit 13, 14, 15
  expect_identical(r$duree_xa_jours[1, 2], as.integer(dates[15] - dates[10]))
})

test_that("xa compte des images, et sa durée suit les dates réelles", {
  dates <- dates_12(12)
  serie <- array(niveau, dim = c(1, 1, 12))
  serie[1, 1, 7:12] <- niveau * db_vers_lineaire(-6)
  p <- parametres_sufosat()
  r <- rcr_compute(serie, dates, p)
  expect_identical(r$duree_xa_jours[1, 1], as.integer(xa_en_jours(p, 12)))
  r1 <- rcr_compute(serie, dates, parametres_sufosat(xa = 1L))
  expect_identical(r1$duree_xa_jours[1, 1], 12L)
})

test_that("xa est paramétrable : une baisse brève compte moins avec xa grand", {
  dates <- dates_12(15)
  serie <- array(niveau, dim = c(1, 1, 15))
  serie[1, 1, 8] <- niveau * db_vers_lineaire(-6) # une seule image basse
  r1 <- rcr_compute(serie, dates, parametres_sufosat(xa = 1L))
  r3 <- rcr_compute(serie, dates, parametres_sufosat(xa = 3L))
  expect_equal(r1$ratio_min_db[1, 1], -6)
  attendu3 <- lineaire_vers_db((db_vers_lineaire(-6) + 2) / 3)
  expect_equal(r3$ratio_min_db[1, 1], attendu3)
  expect_true(r3$ratio_min_db[1, 1] > seuils_db(parametres_sufosat())[["ts"]])
})

test_that("xb est paramétrable : un xb fini change le résultat", {
  # Niveau 1 sur 6 images, puis 0,5 sur 6 images, puis 0,25 sur 6 images.
  dates <- dates_12(18)
  serie <- array(rep(c(1, 0.5, 0.25), each = 6), dim = c(1, 1, 18))
  p_inf <- parametres_sufosat(xa = 3L, xb = Inf)
  p_3 <- parametres_sufosat(xa = 3L, xb = 3)
  r_inf <- rcr_compute(serie, dates, p_inf)
  r_3 <- rcr_compute(serie, dates, p_3)
  # xb = Inf : Mb sur les 12 premières images (6 x 1 + 6 x 0,5) / 12 = 0,75
  expect_equal(r_inf$ratio_min_db[1, 1], lineaire_vers_db(0.25 / 0.75))
  expect_identical(r_inf$date_min[1, 1], date_vers_yyddd(dates[13]))
  # xb = 3 : chaque marche vaut -3,01 dB, la première l'emporte (égalité)
  expect_equal(r_3$ratio_min_db[1, 1], lineaire_vers_db(0.5))
  expect_identical(r_3$date_min[1, 1], date_vers_yyddd(dates[7]))
  expect_false(isTRUE(all.equal(r_inf$ratio_min_db, r_3$ratio_min_db)))
})

test_that("une série trop courte ne donne aucun ratio", {
  p <- parametres_sufosat()
  r <- rcr_compute(array(niveau, dim = c(2, 2, p$xa)), dates_12(p$xa), p)
  expect_true(all(is.na(r$ratio_min_db)))
  expect_true(all(is.na(r$date_min)))
  r1 <- rcr_compute(array(niveau, dim = c(1, 1, p$xa + 1L)), dates_12(p$xa + 1L), p)
  expect_equal(r1$ratio_min_db[1, 1], 0)
})

test_that("les valeurs nulles ou négatives sont écartées avec un avertissement", {
  dates <- dates_12(20)
  serie <- array(niveau, dim = c(1, 2, 20))
  serie[, , 11:20] <- niveau * db_vers_lineaire(-6)
  serie[1, 2, 11] <- 0
  serie[1, 2, 12] <- -0.01
  expect_warning(r <- rcr_compute(serie, dates), "2 valeur")
  attendu <- serie
  attendu[1, 2, 11:12] <- NA
  expect_equal(r$ratio_min_db, rcr_compute(attendu, dates)$ratio_min_db)
  expect_identical(r$date_min[1, 2], date_vers_yyddd(dates[13]))
  expect_no_warning(rcr_compute(attendu, dates))
})

test_that("les entrées incohérentes sont refusées", {
  dates <- dates_12(6)
  serie <- array(niveau, dim = c(2, 2, 6))
  expect_error(rcr_compute(serie[, , 1], dates), "trois dimensions")
  expect_error(rcr_compute(array("a", dim = c(2, 2, 6)), dates), "tableau num")
  expect_error(rcr_compute(serie, dates[-1]), "autant d")
  expect_error(rcr_compute(serie, as.character(dates)), "classe Date")
  expect_error(rcr_compute(serie, rev(dates)), "strictement croissant")
  expect_error(rcr_compute(serie, replace(dates, 2, dates[1])), "strictement croissant")
  expect_error(rcr_compute(serie, replace(dates, 3, NA)), "NA")
  inf <- serie
  inf[1, 1, 1] <- Inf
  expect_error(rcr_compute(inf, dates), "infinie")
  expect_error(rcr_compute(array(numeric(0), dim = c(0, 2, 6)), dates), "vide")
  expect_error(rcr_compute(serie, dates, parametres = list(xa = 3)), "parametres_sufosat")
  expect_error(rcr_compute(serie, dates_12(6, "1990-01-01")), "hors de la plage")
})

test_that("deux orbites combinées : le minimum l'emporte avec sa date", {
  p <- parametres_sufosat()
  dates_asc <- dates_12(20)
  dates_desc <- dates_asc + 5
  asc <- array(niveau, dim = c(2, 2, 20))
  desc <- array(niveau, dim = c(2, 2, 20))
  # pixel [1, 1] : -4 dB en ascendante (image 9), -6 dB en descendante (image 12)
  asc[1, 1, 9:20] <- niveau * db_vers_lineaire(-4)
  desc[1, 1, 12:20] <- niveau * db_vers_lineaire(-6)
  # pixel [2, 1] : -7 dB en ascendante seulement
  asc[2, 1, 10:20] <- niveau * db_vers_lineaire(-7)
  # pixel [2, 2] : aucune donnée en descendante
  desc[2, 2, ] <- NA
  ra <- rcr_compute(asc, dates_asc, p)
  rd <- rcr_compute(desc, dates_desc, p)
  comb <- rcr_combine_orbites(list(asc = ra, desc = rd), p)

  expect_equal(comb$ratio_min_db[1, 1], -6)
  expect_identical(comb$date_min[1, 1], date_vers_yyddd(dates_desc[12]))
  expect_identical(comb$date_avant[1, 1], date_vers_yyddd(dates_desc[11]))
  expect_identical(comb$orbite[1, 1], "desc")
  expect_equal(comb$ratio_min_db[2, 1], -7)
  expect_identical(comb$date_min[2, 1], date_vers_yyddd(dates_asc[10]))
  expect_identical(comb$orbite[2, 1], "asc")
  # pixel sans donnée en descendante : l'ascendante seule
  expect_equal(comb$ratio_min_db[2, 2], 0)
  expect_identical(comb$orbite[2, 2], "asc")
  expect_identical(comb$parametres, p)
  expect_identical(comb$ratio_min_db, pmin(ra$ratio_min_db, rd$ratio_min_db, na.rm = TRUE))

  # liste non nommée : l'orbite est donnée par son rang
  comb2 <- rcr_combine_orbites(list(ra, rd), p)
  expect_identical(comb2$orbite[1, 1], 2L)
  # une seule orbite : rendu inchangé
  seule <- rcr_combine_orbites(list(ra), p)
  expect_identical(seule$ratio_min_db, ra$ratio_min_db)
  expect_identical(seule$date_min, ra$date_min)
})

test_that("combiner des résultats incohérents est refusé", {
  p <- parametres_sufosat()
  dates <- dates_12(8)
  ra <- rcr_compute(array(niveau, dim = c(2, 2, 8)), dates, p)
  rb <- rcr_compute(array(niveau, dim = c(2, 3, 8)), dates, p)
  rx <- rcr_compute(array(niveau, dim = c(2, 2, 8)), dates, parametres_sufosat(xb = 4))
  expect_error(rcr_combine_orbites(list(ra, rb), p), "mes dimensions")
  expect_error(rcr_combine_orbites(list(ra, rx), p), "autres r")
  expect_error(rcr_combine_orbites(list(), p), "au moins un")
  expect_error(rcr_combine_orbites(list(ra, list(a = 1)), p), "est pas un r")
  expect_error(rcr_combine_orbites(ra, p), "est pas un r")
})
