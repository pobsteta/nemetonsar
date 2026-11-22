# Séries synthétiques : niveau stable de forêt, en linéaire (environ -13 dB).
niveau <- 0.05
dates_12 <- function(n, debut = "2021-01-05") seq(as.Date(debut), by = 12, length.out = n)

# Référence naïve, pixel par pixel, écrite directement depuis la définition
# (Mb = xb dernières images valides jusqu'à d_i incluse, Ma = xa premières
# images valides après d_i), pour contrôler la version vectorisée. Le ratio
# minimal est celui calculé avec `xb` ; les dates, celles du minimum du ratio
# calculé avec `xb_date`.
rcr_naif <- function(serie, dates, xa, xb, annee_noyau = 2018L, xb_date = xb) {
  debut <- as.Date(sprintf("%d-01-01", annee_noyau + 1L))
  d <- dim(serie)
  ratio <- matrix(NA_real_, d[1], d[2])
  ratio_date <- matrix(NA_real_, d[1], d[2])
  apres <- matrix(NA_integer_, d[1], d[2])
  avant <- matrix(NA_integer_, d[1], d[2])
  duree <- matrix(NA_integer_, d[1], d[2])
  rapport <- function(v, idx, j, nb) {
    b <- idx[max(1, if (is.infinite(nb)) 1 else j - nb + 1):j]
    a <- idx[(j + 1):(j + xa)]
    10 * log10(mean(v[a]) / mean(v[b]))
  }
  for (l in seq_len(d[1])) for (k in seq_len(d[2])) {
    v <- serie[l, k, ]
    v[!is.na(v) & v <= 0] <- NA
    idx <- which(!is.na(v))
    for (j in seq_along(idx)) {
      if (j + xa > length(idx)) break
      if (dates[idx[j]] < debut) next
      r <- rapport(v, idx, j, xb)
      if (is.na(ratio[l, k]) || r < ratio[l, k]) ratio[l, k] <- r
      r <- rapport(v, idx, j, xb_date)
      if (is.na(ratio_date[l, k]) || r < ratio_date[l, k]) {
        ratio_date[l, k] <- r
        apres[l, k] <- date_vers_yyddd(dates[idx[j + 1]])
        avant[l, k] <- date_vers_yyddd(dates[idx[j]])
        duree[l, k] <- as.integer(dates[idx[j + xa]] - dates[idx[j]])
      }
    }
  }
  list(ratio_min_db = ratio, date_min = apres, date_avant = avant, duree_xa_jours = duree)
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
  # expect_equal : selon la version de R, seq() rend des dates stockées en entiers ou en doubles
  expect_equal(yyddd_vers_date(r$date_min[2, 3]), dates[11])
  expect_equal(yyddd_vers_date(r$date_avant[2, 3]), dates[10])
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
  # dates à cheval sur le début des ratios (2019-01-01 par défaut)
  dates <- sort(as.Date("2018-06-01") + sample(0:900, nt))
  serie <- array(niveau * db_vers_lineaire(rnorm(4 * 6 * nt, sd = 2)), dim = c(4, 6, nt))
  serie[sample(length(serie), 120)] <- NA
  serie[1, 1, ] <- NA # pixel jamais valide
  serie[1, 2, 4:nt] <- NA # trop peu d'images valides
  for (xa in c(1L, 3L)) for (xb in c(Inf, 1, 4)) for (xb_date in c(Inf, 2, 5)) {
    for (an in c(2018L, 2017L)) {
      p <- parametres_sufosat(xa = xa, xb = xb, xb_date = xb_date, annee_noyau = an)
      r <- rcr_compute(serie, dates, p)
      attendu <- rcr_naif(serie, dates, xa, xb, an, xb_date = xb_date)
      expect_equal(r$ratio_min_db, attendu$ratio_min_db)
      expect_identical(r$date_min, attendu$date_min)
      expect_identical(r$date_avant, attendu$date_avant)
      expect_identical(r$duree_xa_jours, attendu$duree_xa_jours)
      # un pixel a une date si et seulement s'il a un ratio
      expect_identical(is.na(r$date_min), is.na(r$ratio_min_db))
    }
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
  # xb_date = xb : la date se lit sur le ratio de détection, ce que vérifie ce test
  p_inf <- parametres_sufosat(xa = 3L, xb = Inf, xb_date = Inf)
  p_3 <- parametres_sufosat(xa = 3L, xb = 3, xb_date = 3)
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

# Début des ratios : aucun ratio pour d_i avant le 1er janvier de annee_noyau + 1.
dates_2018 <- function(n = 70) dates_12(n, "2018-01-03")

test_that("aucun ratio n'est calculé avant le 1er janvier qui suit annee_noyau", {
  dates <- dates_2018()
  serie <- array(niveau, dim = c(1, 1, length(dates)))
  r <- rcr_compute(serie, dates)
  expect_true(yyddd_vers_date(r$date_avant[1, 1]) >= as.Date("2019-01-01"))
  # une série qui finit en 2018 n'a aucun ratio
  r18 <- rcr_compute(serie[, , 1:25, drop = FALSE], dates[1:25])
  expect_true(is.na(r18$ratio_min_db[1, 1]))
  expect_true(is.na(r18$date_min[1, 1]))
})

test_that("une coupe injectée en 2018 n'est pas retenue, une en 2019 l'est", {
  dates <- dates_2018()
  serie <- array(niveau, dim = c(1, 2, length(dates)))
  serie[1, 1, 5:70] <- niveau * db_vers_lineaire(-6) # coupe de février 2018
  serie[1, 2, 50:70] <- niveau * db_vers_lineaire(-6) # coupe de 2019
  expect_true(format(dates[4]) < "2019" && format(dates[50]) >= "2019-01-01")
  expect_true(format(dates[50]) < "2020")
  r <- rcr_compute(serie, dates)
  s <- seuils_db(r$parametres)
  # 2018 : pas de date en 2018, et le reliquat est au-dessus des seuils
  expect_true(yyddd_vers_date(r$date_min[1, 1]) >= as.Date("2019-01-01"))
  expect_true(r$ratio_min_db[1, 1] > s[["tp"]])
  # 2019 : retrouvée exactement
  expect_equal(r$ratio_min_db[1, 2], -6)
  expect_identical(r$date_min[1, 2], date_vers_yyddd(dates[50]))
  expect_equal(yyddd_vers_date(r$date_min[1, 2]), dates[50])
})

test_that("un faux minimum de speckle en début de série n'apparaît plus", {
  dates <- dates_2018()
  serie <- array(niveau, dim = c(1, 1, length(dates)))
  serie[1, 1, 1] <- niveau * db_vers_lineaire(10) # pic isolé sur la première image
  # avec un début des ratios en 2018, le pic donne un faux minimum de -10 dB
  r17 <- rcr_compute(serie, dates, parametres_sufosat(annee_noyau = 2017L))
  expect_equal(r17$ratio_min_db[1, 1], -10)
  expect_identical(r17$date_avant[1, 1], date_vers_yyddd(dates[1]))
  # avec le défaut (2019), il disparaît sous les seuils
  r <- rcr_compute(serie, dates)
  expect_true(r$ratio_min_db[1, 1] > seuils_db(r$parametres)[["tp"]])
  expect_true(yyddd_vers_date(r$date_avant[1, 1]) >= as.Date("2019-01-01"))
})

# Datation à part (mission 010) : ratio de détection avec xb, date au minimum
# du ratio calculé avec xb_date.
marches <- function() array(rep(c(1, 0.5, 0.25), each = 6), dim = c(1, 1, 18))

test_that("la date suit xb_date, le ratio de détection suit xb", {
  # Niveau 1, puis 0,5, puis 0,25 (6 images chacun).
  dates <- dates_12(18)
  p <- parametres_sufosat(xb = Inf, xb_date = 3)
  r <- rcr_compute(marches(), dates, p)
  # ratio de détection inchangé : celui de xb = Inf (Mb = 0,75 à la 12e image)
  r_inf <- rcr_compute(marches(), dates, parametres_sufosat(xb = Inf, xb_date = Inf))
  expect_identical(r$ratio_min_db, r_inf$ratio_min_db)
  expect_equal(r$ratio_min_db[1, 1], lineaire_vers_db(0.25 / 0.75))
  # date : minimum du ratio à xb = 3, première marche (égalité : la plus ancienne)
  expect_equal(yyddd_vers_date(r$date_min[1, 1]), dates[7])
  expect_equal(yyddd_vers_date(r$date_avant[1, 1]), dates[6])
  expect_identical(r$duree_xa_jours[1, 1], as.integer(dates[9] - dates[6]))
  # à xb_date = Inf, la date est celle du minimum de détection
  expect_equal(yyddd_vers_date(r_inf$date_min[1, 1]), dates[13])
  expect_equal(yyddd_vers_date(r_inf$date_avant[1, 1]), dates[12])
  expect_identical(r_inf$duree_xa_jours[1, 1], as.integer(dates[15] - dates[12]))
})

test_that("le défaut date avec xb_date = 5 et détecte avec xb = Inf", {
  dates <- dates_12(18)
  p <- parametres_sufosat()
  expect_identical(p$xb, Inf)
  expect_identical(p$xb_date, 5)
  r <- rcr_compute(marches(), dates, p)
  attendu <- rcr_naif(marches(), dates, 3L, Inf, xb_date = 5)
  expect_equal(r$ratio_min_db, attendu$ratio_min_db)
  expect_identical(r$date_min, attendu$date_min)
  expect_identical(r$date_avant, attendu$date_avant)
  expect_identical(r$duree_xa_jours, attendu$duree_xa_jours)
  expect_equal(r$ratio_min_db[1, 1], lineaire_vers_db(0.25 / 0.75))
})

test_that("xb_date = xb rend les dates du ratio de détection", {
  set.seed(7)
  dates <- dates_12(30)
  serie <- array(niveau * db_vers_lineaire(rnorm(3 * 4 * 30, sd = 2)), dim = c(3, 4, 30))
  serie[2, 2, 5] <- NA
  for (xb in c(Inf, 4)) {
    r <- rcr_compute(serie, dates, parametres_sufosat(xb = xb, xb_date = xb))
    attendu <- rcr_naif(serie, dates, 3L, xb)
    expect_equal(r$ratio_min_db, attendu$ratio_min_db)
    expect_identical(r$date_min, attendu$date_min)
    expect_identical(r$date_avant, attendu$date_avant)
    expect_identical(r$duree_xa_jours, attendu$duree_xa_jours)
  }
  # quel que soit xb_date, le ratio de détection ne bouge pas
  r_ref <- rcr_compute(serie, dates, parametres_sufosat(xb_date = Inf))
  for (xd in c(1, 5, 10)) {
    r <- rcr_compute(serie, dates, parametres_sufosat(xb_date = xd))
    expect_identical(r$ratio_min_db, r_ref$ratio_min_db)
  }
})

test_that("cas simulé de la mission 008 : date bien meilleure, détection identique", {
  # Reprise à petite échelle de docs/analyses/precision-date.R : forêt à
  # 0,05, speckle gamma (ENL 4,4), chute de -6 dB après le 2020-06-15,
  # cadence 12 j, filtre de fenêtre 3, xb = Inf. Simulation, pas une mesure.
  set.seed(20261122L)
  nr <- 20L
  nc <- 30L
  dates <- seq(as.Date("2018-01-03"), as.Date("2021-12-31"), by = 12)
  nt <- length(dates)
  k1 <- which(dates > as.Date("2020-06-15"))[1]
  serie <- array(0.05, c(nr, nc, nt))
  serie[, 1:15, k1:nt] <- 0.05 * db_vers_lineaire(-6)
  serie <- serie * array(rgamma(nr * nc * nt, shape = 4.4, rate = 4.4), c(nr, nc, nt))
  p_avant <- parametres_sufosat(xb_date = Inf)
  p_apres <- parametres_sufosat() # xb_date = 5
  filtree <- s1_filter_multitemp(serie, dates, p_apres)
  r_avant <- rcr_compute(filtree, dates, p_avant)
  r_apres <- rcr_compute(filtree, dates, p_apres)

  # pixels coupés à 3 pixels ou plus de la lisière, forêt intacte de même
  coupe <- matrix(FALSE, nr, nc)
  coupe[, 1:12] <- TRUE
  intact <- matrix(FALSE, nr, nc)
  intact[, 19:30] <- TRUE
  vraie <- dates[k1]
  exacte <- function(r) mean(yyddd_vers_date(r$date_min[coupe]) == vraie)
  # graine fixée : 25,0 % à xb_date = Inf, 93,3 % à xb_date = 5 (240 pixels)
  expect_lt(exacte(r_avant), 0.4)
  expect_gt(exacte(r_apres), 0.9)
  expect_gt(exacte(r_apres) - exacte(r_avant), 0.5)
  # aucune date en avance d'une acquisition ou plus
  expect_true(all(yyddd_vers_date(r_apres$date_min[coupe]) >= vraie))

  # détection identique
  expect_identical(r_apres$ratio_min_db, r_avant$ratio_min_db)
  s_avant <- rcr_segment(r_avant, p_avant)
  s_apres <- rcr_segment(r_apres, p_apres)
  expect_identical(s_apres$detection, s_avant$detection)
  expect_true(all(s_apres$detection[coupe]))
  expect_false(any(s_apres$detection[intact]))
})

test_that("deux orbites : l'orbite au ratio de détection le plus bas donne ses dates", {
  p <- parametres_sufosat(xb = Inf, xb_date = 3)
  dates_asc <- dates_12(18)
  dates_desc <- dates_asc + 5
  # asc : marches 1 / 0,5 / 0,25 ; détection -4,77 dB, ratio de datation -3,01 dB (image 7)
  asc <- marches()
  # desc : une marche de -4 dB à l'image 12 ; détection et datation -4 dB
  desc <- array(1, dim = c(1, 1, 18))
  desc[1, 1, 12:18] <- db_vers_lineaire(-4)
  ra <- rcr_compute(asc, dates_asc, p)
  rd <- rcr_compute(desc, dates_desc, p)
  comb <- rcr_combine_orbites(list(asc = ra, desc = rd), p)
  # l'ascendante l'emporte par son ratio de détection, bien que son ratio de
  # datation (-3,01 dB) soit plus haut que celui de la descendante (-4 dB)
  expect_identical(comb$orbite[1, 1], "asc")
  expect_equal(comb$ratio_min_db[1, 1], lineaire_vers_db(0.25 / 0.75))
  expect_equal(yyddd_vers_date(comb$date_min[1, 1]), dates_asc[7])
  expect_equal(yyddd_vers_date(comb$date_avant[1, 1]), dates_asc[6])
  expect_identical(comb$duree_xa_jours[1, 1], ra$duree_xa_jours[1, 1])
  expect_equal(yyddd_vers_date(rd$date_min[1, 1]), dates_desc[12])
  # des résultats calculés avec un autre xb_date sont refusés
  rx <- rcr_compute(desc, dates_desc, parametres_sufosat(xb = Inf, xb_date = 5))
  expect_error(rcr_combine_orbites(list(ra, rx), p), "autres r")
})

# Mission 016 (performance) ------------------------------------------------------
# Référence figée : rcr_compute() tel qu'écrit avant la mission 016 (sommes
# cumulées par matrice d'indices, un logarithme par date et par pixel). Le
# calcul rapide doit la rendre au bit près, avertissements compris.
rcr_016 <- function(serie, dates, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  serie <- valide_serie(serie)
  d <- dim(serie)
  nt <- d[3]
  codes <- valide_dates_serie(dates, nt)
  npix <- d[1] * d[2]
  xa <- p$xa
  xb <- p$xb
  xb_date <- p$xb_date
  # Un seul calcul si la date se lit sur le ratio de détection.
  dater_a_part <- !identical(xb_date, xb)
  # Dates d_i admises pour un ratio (voir la section « Début des ratios »).
  debut <- as.Date(sprintf("%d-01-01", p$annee_noyau + 1L))
  admise <- dates >= debut

  x <- matrix(serie, nrow = npix, ncol = nt)
  noms <- dimnames(serie)[1:2]
  rm(serie)
  negatif <- !is.na(x) & x <= 0
  if (any(negatif)) {
    warning(
      sum(negatif), " valeur(s) lin\u00e9aire(s) nulle(s) ou n\u00e9gative(s) ",
      "trait\u00e9e(s) comme images \u00e9cart\u00e9es (NA).",
      call. = FALSE
    )
    x[negatif] <- NA_real_
  }
  rm(negatif)

  # Passe 1 : pour chaque pixel, somme cumulée des k premières images valides
  # (colonne k + 1 de `cumul`) et position (index de date) de la k-ième.
  cumul <- matrix(0, nrow = npix, ncol = nt + 1L)
  position <- matrix(NA_integer_, nrow = npix, ncol = nt + 1L)
  somme <- numeric(npix)
  compte <- integer(npix)
  for (t in seq_len(nt)) {
    v <- which(!is.na(x[, t]))
    if (length(v) == 0L) next
    somme[v] <- somme[v] + x[v, t]
    compte[v] <- compte[v] + 1L
    cle <- cbind(v, compte[v] + 1L)
    cumul[cle] <- somme[v]
    position[cle] <- t
  }
  total <- compte
  rm(somme)

  lire <- function(m, pix, k) m[cbind(pix, k + 1L)]

  # Ratio en dB à la k-ième image valide des pixels `pix`, Mb sur `nb_avant`
  # images (Inf : toutes), à partir des sommes cumulées.
  ratio_k <- function(pix, k, s_apres, nb_avant) {
    nb <- if (is.infinite(nb_avant)) k else pmin(k, as.integer(nb_avant))
    mb <- (lire(cumul, pix, k) - lire(cumul, pix, k - nb)) / nb
    lineaire_vers_db((s_apres / xa) / mb)
  }

  # Passe 2 : ratio à chaque date valide suivie d'au moins xa images valides.
  # `meilleur` : minimum du ratio de détection (xb) ; `meilleur_date` et
  # `k_avant` : minimum du ratio de datation (xb_date) et sa position.
  meilleur <- rep(Inf, npix)
  meilleur_date <- if (dater_a_part) rep(Inf, npix) else NULL
  k_avant <- rep(NA_integer_, npix)
  compte <- integer(npix)
  for (i in seq_len(nt)) {
    v <- !is.na(x[, i])
    compte[v] <- compte[v] + 1L
    if (!admise[i]) next
    pix <- which(v & compte + xa <= total)
    if (length(pix) == 0L) next
    k <- compte[pix]
    s_apres <- lire(cumul, pix, k + xa) - lire(cumul, pix, k)
    r <- ratio_k(pix, k, s_apres, xb)
    mieux <- r < meilleur[pix]
    meilleur[pix[mieux]] <- r[mieux]
    if (dater_a_part) {
      r <- ratio_k(pix, k, s_apres, xb_date)
      mieux <- r < meilleur_date[pix]
      meilleur_date[pix[mieux]] <- r[mieux]
    }
    k_avant[pix[mieux]] <- k[mieux]
  }
  rm(meilleur_date)

  trouve <- which(!is.na(k_avant))
  ratio <- rep(NA_real_, npix)
  date_min <- rep(NA_integer_, npix)
  date_avant <- rep(NA_integer_, npix)
  duree <- rep(NA_integer_, npix)
  if (length(trouve) > 0L) {
    k <- k_avant[trouve]
    i_avant <- lire(position, trouve, k)
    i_apres <- lire(position, trouve, k + 1L)
    i_fin <- lire(position, trouve, k + xa)
    ratio[trouve] <- meilleur[trouve]
    date_avant[trouve] <- codes[i_avant]
    date_min[trouve] <- codes[i_apres]
    duree[trouve] <- as.integer(dates[i_fin] - dates[i_avant])
  }

  en_matrice <- function(v) {
    m <- matrix(v, nrow = d[1], ncol = d[2])
    if (!is.null(noms)) dimnames(m) <- noms
    m
  }
  list(
    ratio_min_db = en_matrice(ratio),
    date_min = en_matrice(date_min),
    date_avant = en_matrice(date_avant),
    duree_xa_jours = en_matrice(duree),
    parametres = p
  )
}

avec_avertissements <- function(expr) {
  messages <- character(0)
  valeur <- withCallingHandlers(expr, warning = function(w) {
    messages <<- c(messages, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  list(valeur = valeur, avertissements = messages)
}

test_that("mission 016 : rcr_compute() identique au bit près au calcul d'avant", {
  set.seed(163)
  for (cas in 1:12) {
    nt <- sample(8:50, 1)
    dates <- sort(as.Date("2018-03-01") + sample(0:1500, nt))
    serie <- array(0.05 * stats::rgamma(7 * 3 * nt, 4.4, 4.4), dim = c(7, 3, nt))
    j <- sample(nt, 1):nt
    serie[2:5, 2, j] <- serie[2:5, 2, j] / 4
    if (cas %% 3 == 0) serie[, 3, ] <- 0.05 # plateaux : ratios égaux
    if (cas %% 2 == 1) serie[sample(length(serie), length(serie) %/% 5)] <- NA
    if (cas %% 4 == 2) serie[sample(length(serie), 2)] <- 0
    for (p in list(
      parametres_sufosat(),
      parametres_sufosat(xb = 4, xb_date = 4),
      parametres_sufosat(xa = 1L, xb = 2, xb_date = Inf)
    )) {
      expect_identical(avec_avertissements(rcr_compute(serie, dates, p)),
                       avec_avertissements(rcr_016(serie, dates, p)))
    }
  }
  # Cas dégénéré : Ma nulle par annulation (valeurs infimes après de grandes),
  # un ratio sans valeur et son avertissement, comme avant.
  dates <- seq(as.Date("2019-01-05"), by = 12, length.out = 12)
  serie <- array(1, dim = c(2, 3, 12))
  serie[1, 1, 7:12] <- 1e-20
  expect_identical(avec_avertissements(rcr_compute(serie, dates)),
                   avec_avertissements(rcr_016(serie, dates)))
})

test_that("mission 016 : sorties figées avant optimisation (empreinte)", {
  skip_if_not(R.version$arch == "x86_64", "empreinte calculée sur x86_64")
  empreinte <- function(...) {
    f <- tempfile()
    con <- file(f, "wb")
    for (x in list(...)) writeBin(as.vector(x), con, endian = "little")
    close(con)
    on.exit(unlink(f))
    unname(tools::md5sum(f))
  }
  set.seed(17)
  dates <- seq(as.Date("2018-06-03"), by = 12, length.out = 60)
  serie <- array(0.05 * stats::rgamma(6 * 4 * 60, shape = 4.4, rate = 4.4), dim = c(6, 4, 60))
  serie[2:4, 2:3, 40:60] <- serie[2:4, 2:3, 40:60] / 4
  serie[c(5, 99, 100, 101, 1000)] <- NA
  attendu <- c("8240f20ac3e9ab31456dde80ed51cd84", "80e5ac4169b5fa0f233c6dd698148da7")
  reglages <- list(parametres_sufosat(), parametres_sufosat(xb = 10, xb_date = Inf, xa = 2L))
  for (i in 1:2) {
    r <- rcr_compute(serie, dates, reglages[[i]])
    expect_identical(empreinte(r$ratio_min_db, r$date_min, r$date_avant, r$duree_xa_jours),
                     attendu[i])
  }
})
