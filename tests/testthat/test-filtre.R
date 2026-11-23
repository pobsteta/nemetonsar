# Référence naïve, pixel par pixel : moyenne locale sur fenêtre carrée, bord
# répliqué (indices bornés), NA ignorés ; noyau = moyenne des I_i / E[I_i] sur
# les images de l'année de référence ; J_t = E[I_t] * noyau.
moyenne_naive <- function(image, cote) {
  nr <- nrow(image)
  nc <- ncol(image)
  r <- (cote - 1) %/% 2
  sortie <- matrix(NA_real_, nr, nc)
  for (i in seq_len(nr)) {
    for (j in seq_len(nc)) {
      if (is.na(image[i, j])) next
      valeurs <- c()
      for (di in -r:r) {
        for (dj in -r:r) {
          ii <- min(max(i + di, 1), nr)
          jj <- min(max(j + dj, 1), nc)
          valeurs <- c(valeurs, image[ii, jj])
        }
      }
      sortie[i, j] <- mean(valeurs, na.rm = TRUE)
    }
  }
  sortie
}

filtre_naif <- function(serie, dates, cote, annee) {
  d <- dim(serie)
  ref <- which(as.integer(format(dates, "%Y")) == annee)
  sortie <- serie
  for (i in seq_len(d[1])) {
    for (j in seq_len(d[2])) {
      rapports <- c()
      for (t in ref) {
        e <- moyenne_naive(serie[, , t, drop = FALSE][, , 1], cote)[i, j]
        if (!is.na(serie[i, j, t])) rapports <- c(rapports, serie[i, j, t] / e)
      }
      noyau <- if (length(rapports) > 0) mean(rapports) else NA_real_
      for (t in seq_len(d[3])) {
        sortie[i, j, t] <- moyenne_naive(serie[, , t, drop = FALSE][, , 1], cote)[i, j] * noyau
      }
    }
  }
  sortie
}

enl <- function(x) mean(x)^2 / stats::var(as.vector(x))

dates_2018_2020 <- seq(as.Date("2018-01-04"), as.Date("2020-12-31"), by = 12)

test_that("le filtre égale la référence naïve pixel par pixel (NA, bords, fenêtres 3 et 5)", {
  set.seed(7)
  dates <- seq(as.Date("2017-11-02"), by = 30, length.out = 24) # 2017 à 2019
  serie <- array(stats::rgamma(6 * 5 * 24, shape = 4, rate = 80), dim = c(6, 5, 24))
  serie[sample(length(serie), 40)] <- NA
  serie[2, 3, ] <- NA # pixel jamais valide
  for (cote in c(3L, 5L)) {
    p <- parametres_sufosat(fenetre_filtre = cote)
    obtenu <- s1_filter_multitemp(serie, dates, p)
    attendu <- filtre_naif(serie, dates, cote, 2018L)
    expect_equal(as.vector(obtenu), as.vector(attendu), tolerance = 1e-10)
    expect_identical(dim(obtenu), dim(serie))
  }
})

test_that("la moyenne locale réplique le bord", {
  image <- matrix(c(1, 2, 3,
                    4, 5, 6,
                    7, 8, 9), nrow = 3, byrow = TRUE)
  m <- moyenne_locale(image, 3L)
  # Coin [1, 1] : fenêtre 3 x 3 bord répliqué = 4 x 1 + 2 x 2 + 2 x 4 + 5
  expect_equal(m[1, 1], (4 * 1 + 2 * 2 + 2 * 4 + 5) / 9)
  expect_equal(m[2, 2], mean(image))
  # Bord [1, 2] : la ligne 1 compte deux fois
  expect_equal(m[1, 2], (2 * (1 + 2 + 3) + 4 + 5 + 6) / 9)
  # Image d'une seule ligne, d'une seule colonne, d'un seul pixel
  expect_equal(moyenne_locale(matrix(c(1, 2, 3), nrow = 1), 3L),
               matrix(c(4 / 3, 2, 8 / 3), nrow = 1))
  expect_equal(moyenne_locale(matrix(c(1, 2, 3), ncol = 1), 3L),
               matrix(c(4 / 3, 2, 8 / 3), ncol = 1))
  expect_equal(moyenne_locale(matrix(5), 5L), matrix(5))
})

test_that("une série constante, même en marche, est rendue telle quelle", {
  dates <- dates_2018_2020
  nt <- length(dates)
  serie <- array(0.05, dim = c(8, 7, nt))
  apres <- dates >= as.Date("2020-03-01")
  serie[, , apres] <- 0.05 * db_vers_lineaire(-6)
  f <- s1_filter_multitemp(serie, dates)
  expect_equal(as.vector(f), as.vector(serie))
  expect_identical(attr(f, "nb_images_noyau"), matrix(sum(format(dates, "%Y") == "2018"), 8, 7))
})

test_that("le speckle diminue (ENL augmente) et la moyenne est conservée", {
  set.seed(2018)
  dates <- dates_2018_2020
  nt <- length(dates)
  L <- 4.4 # ENL avant filtre, B18 § 2.2.1, p. 4
  serie <- array(0.05 * stats::rgamma(40 * 40 * nt, shape = L, rate = L), dim = c(40, 40, nt))
  f <- s1_filter_multitemp(serie, dates)
  interieur <- 2:39
  apres <- which(dates >= as.Date("2019-01-01"))
  enl_avant <- mean(sapply(apres, function(t) enl(serie[interieur, interieur, t])))
  enl_apres <- mean(sapply(apres, function(t) enl(f[interieur, interieur, t])))
  expect_gt(enl_avant, 3.5)
  expect_lt(enl_avant, 5.5)
  expect_gt(enl_apres, 4 * enl_avant)
  # Filtre sans biais : moyenne conservée à 1 % près hors des bords
  expect_equal(mean(f[interieur, interieur, apres]) / mean(serie[interieur, interieur, apres]),
               1, tolerance = 0.01)
})

test_that("une marche de -6 dB reste une marche, sans fuite vers les dates antérieures", {
  set.seed(42)
  dates <- dates_2018_2020
  nt <- length(dates)
  k <- which(dates >= as.Date("2020-03-01"))[1]
  sans <- array(0.05 * stats::rgamma(20 * 20 * nt, shape = 4.4, rate = 4.4), dim = c(20, 20, nt))
  avec <- sans
  avec[, , k:nt] <- avec[, , k:nt] * db_vers_lineaire(-6)
  f_sans <- s1_filter_multitemp(sans, dates)
  f_avec <- s1_filter_multitemp(avec, dates)
  # Avant la marche : exactement les mêmes images filtrées (aucune fuite)
  expect_equal(f_avec[, , 1:(k - 1)], f_sans[, , 1:(k - 1)])
  # Après : la chute est de -6 dB exactement (le filtre est linéaire par image)
  expect_equal(f_avec[, , k:nt], f_sans[, , k:nt] * db_vers_lineaire(-6))
  ecart <- lineaire_vers_db(mean(f_avec[, , k:nt]) / mean(f_avec[, , 1:(k - 1)]))
  expect_equal(ecart, -6, tolerance = 0.05)
})

test_that("le noyau ne dépend que des images de annee_noyau", {
  set.seed(3)
  dates <- dates_2018_2020
  nt <- length(dates)
  serie <- array(0.05 * stats::rgamma(6 * 6 * nt, shape = 4, rate = 4), dim = c(6, 6, nt))
  f <- s1_filter_multitemp(serie, dates)
  annees <- as.integer(format(dates, "%Y"))
  # Modifier une image de 2020 ne change que cette image filtrée
  t2020 <- which(annees == 2020L)[5]
  modif <- serie
  modif[, , t2020] <- modif[, , t2020] * 3
  f2 <- s1_filter_multitemp(modif, dates)
  expect_equal(f2[, , -t2020], f[, , -t2020])
  # Modifier une image de 2018 change le noyau, donc les images de 2020
  t2018 <- which(annees == 2018L)[5]
  modif <- serie
  modif[3, 3, t2018] <- modif[3, 3, t2018] * 3
  f3 <- s1_filter_multitemp(modif, dates)
  expect_false(isTRUE(all.equal(f3[, , annees == 2020L], f[, , annees == 2020L])))
  # Avec annee_noyau = 2019, c'est l'image de 2018 qui n'a plus d'effet ailleurs
  p19 <- parametres_sufosat(annee_noyau = 2019L)
  g <- s1_filter_multitemp(serie, dates, p19)
  g3 <- s1_filter_multitemp(modif, dates, p19)
  expect_equal(g3[, , -t2018], g[, , -t2018])
  expect_identical(attr(g, "nb_images_noyau")[1, 1], sum(annees == 2019L))
})

test_that("les images de l'année de référence et d'avant reçoivent le même noyau", {
  set.seed(11)
  dates <- seq(as.Date("2017-06-01"), as.Date("2019-06-30"), by = 12)
  nt <- length(dates)
  serie <- array(0.05 * stats::rgamma(5 * 5 * nt, shape = 4, rate = 4), dim = c(5, 5, nt))
  f <- s1_filter_multitemp(serie, dates)
  ref <- which(format(dates, "%Y") == "2018")
  e <- lapply(seq_len(nt), function(t) moyenne_locale(serie[, , t], 3L))
  noyau <- Reduce(`+`, lapply(ref, function(t) serie[, , t] / e[[t]])) / length(ref)
  for (t in c(1L, ref[1], nt)) { # 2017, 2018, 2019
    expect_equal(f[, , t], e[[t]] * noyau)
  }
})

test_that("les NA et les valeurs nulles ou négatives sont écartés", {
  dates <- seq(as.Date("2018-01-04"), by = 30, length.out = 20)
  serie <- array(0.04, dim = c(4, 4, 20))
  serie[2, 2, 3] <- NA
  serie[3, 3, 15] <- NaN
  f <- s1_filter_multitemp(serie, dates)
  expect_true(is.na(f[2, 2, 3]))
  expect_true(is.na(f[3, 3, 15]))
  # Les voisins d'un NA gardent une moyenne sur les seuls pixels valides
  expect_equal(f[1, 1, 3], 0.04)
  expect_identical(sum(is.na(f)), 2L)
  expect_identical(attr(f, "nb_images_noyau")[2, 2], 12L) # 13 images en 2018, une NA
  # Pixel sans aucune image de référence valide : NA à toutes les dates
  serie[4, 1, 1:13] <- NA
  expect_true(all(is.na(s1_filter_multitemp(serie, dates)[4, 1, ])))
  # Valeurs nulles ou négatives : NA et un seul avertissement
  serie2 <- array(0.04, dim = c(3, 3, 20))
  serie2[1, 1, 2] <- 0
  serie2[2, 2, 5] <- -1
  expect_warning(f2 <- s1_filter_multitemp(serie2, dates), "2 valeur")
  expect_true(is.na(f2[1, 1, 2]) && is.na(f2[2, 2, 5]))
})

test_that("fenetre_filtre = 1 rend la série brute", {
  set.seed(5)
  dates <- seq(as.Date("2018-01-04"), by = 30, length.out = 20)
  serie <- array(stats::rgamma(3 * 4 * 20, shape = 4, rate = 80), dim = c(3, 4, 20))
  f <- s1_filter_multitemp(serie, dates, parametres_sufosat(fenetre_filtre = 1L))
  expect_equal(as.vector(f), as.vector(serie))
})

test_that("noms de dimensions gardés, une seule ligne acceptée", {
  dates <- seq(as.Date("2018-01-04"), by = 30, length.out = 15)
  serie <- array(0.03, dim = c(1, 3, 15),
                 dimnames = list("l1", c("a", "b", "c"), NULL))
  f <- s1_filter_multitemp(serie, dates)
  expect_identical(dimnames(f), dimnames(serie))
  expect_identical(dimnames(attr(f, "nb_images_noyau")), list("l1", c("a", "b", "c")))
  expect_equal(as.vector(f), as.vector(serie))
})

test_that("les entrées invalides sont refusées", {
  dates <- seq(as.Date("2019-01-04"), by = 30, length.out = 6)
  serie <- array(0.05, dim = c(2, 2, 6))
  expect_error(s1_filter_multitemp(serie, dates), "annee_noyau")
  dates18 <- dates - 365
  expect_error(s1_filter_multitemp(serie[, , 1], dates18), "trois dimensions")
  expect_error(s1_filter_multitemp(serie, dates18[-1]), "autant")
  expect_error(s1_filter_multitemp(serie, rev(dates18)), "croissant")
  expect_error(s1_filter_multitemp(serie, as.character(dates18)), "Date")
  serie[1] <- Inf
  expect_error(s1_filter_multitemp(serie, dates18), "infinie")
  expect_error(s1_filter_multitemp(array(0.05, c(2, 2, 6)), dates18, list()), "parametres_sufosat")
})

test_that("signe : rcr_compute() sur la série filtrée retrouve mieux la date de coupe", {
  set.seed(2020)
  dates <- dates_2018_2020
  nt <- length(dates)
  n <- 40
  k <- which(dates >= as.Date("2020-03-01"))[1]
  vrai <- array(0.05, dim = c(n, n, nt))
  coupe <- 11:30
  vrai[coupe, coupe, k:nt] <- 0.05 * db_vers_lineaire(-6)
  brute <- vrai * stats::rgamma(length(vrai), shape = 4.4, rate = 4.4)
  filtree <- s1_filter_multitemp(brute, dates)
  rb <- rcr_compute(brute, dates)
  rf <- rcr_compute(filtree, dates)
  ts <- seuils_db(parametres_sufosat())[["ts"]]
  dedans <- 13:28 # coeur de la coupe, loin de sa lisière
  hors <- matrix(TRUE, n, n)
  hors[9:32, 9:32] <- FALSE # forêt intacte, loin de la lisière
  cible <- date_vers_yyddd(dates[k])
  exacte_brute <- mean(rb$date_min[dedans, dedans] == cible)
  exacte_filtree <- mean(rf$date_min[dedans, dedans] == cible)
  # La date exacte est retrouvée nettement plus souvent après filtre
  expect_gt(exacte_filtree, 1.5 * exacte_brute)
  # Les fausses alertes de la série brute (minima de speckle sous ts) disparaissent
  expect_gt(mean(rb$ratio_min_db[hors] < ts), 0.005)
  expect_identical(sum(rf$ratio_min_db[hors] < ts), 0L)
  # La coupe reste détectée sous le seuil des ombres
  expect_true(all(rf$ratio_min_db[dedans, dedans] < ts))
})

# Mission 016 (performance) ------------------------------------------------------
# Référence figée : la moyenne locale telle qu'écrite avant la mission 016
# (table de sommes de zone par apply(cumsum) en deux passes, compte des
# valeurs valides par la même table). Le calcul rapide doit la rendre au bit
# près, et non à une tolérance près.
moyenne_locale_016 <- function(image, cote) {
  nr <- nrow(image)
  nc <- ncol(image)
  r <- (cote - 1L) %/% 2L
  etendue <- image[c(rep(1L, r), seq_len(nr), rep(nr, r)),
                   c(rep(1L, r), seq_len(nc), rep(nc, r)), drop = FALSE]
  valide <- !is.na(etendue)
  etendue[!valide] <- 0
  cumuls <- function(m) {
    m[] <- apply(m, 2L, cumsum)
    m
  }
  somme <- function(m) {
    cumul <- matrix(0, nrow = nrow(m) + 1L, ncol = ncol(m) + 1L)
    cumul[-1L, -1L] <- t(cumuls(t(cumuls(m))))
    i <- seq_len(nr)
    j <- seq_len(nc)
    cumul[i + cote, j + cote, drop = FALSE] - cumul[i, j + cote, drop = FALSE] -
      cumul[i + cote, j, drop = FALSE] + cumul[i, j, drop = FALSE]
  }
  s <- somme(etendue)
  n <- somme(valide * 1)
  moyenne <- s / n
  moyenne[n == 0 | is.na(image)] <- NA_real_
  moyenne
}

filtre_016 <- function(serie, dates, cote, annee = 2018L) {
  d <- dim(serie)
  ref <- which(as.integer(format(dates, "%Y")) == annee)
  somme <- matrix(0, d[1], d[2])
  compte <- matrix(0L, d[1], d[2])
  for (t in ref) {
    image <- matrix(serie[, , t], d[1], d[2])
    r <- image / moyenne_locale_016(image, cote)
    ok <- !is.na(r)
    somme[ok] <- somme[ok] + r[ok]
    compte[ok] <- compte[ok] + 1L
  }
  noyau <- somme / compte
  noyau[compte == 0L] <- NA_real_
  for (t in seq_len(d[3])) {
    serie[, , t] <- moyenne_locale_016(matrix(serie[, , t], d[1], d[2]), cote) * noyau
  }
  serie
}

test_that("mission 016 : moyenne locale identique au bit près au calcul d'avant", {
  set.seed(161)
  # Formes : une ligne, une colonne, bandes larges et courtes (somme cumulée
  # triangulaire, <= 20 colonnes étendues) et plus hautes (transposition).
  for (forme in list(c(1, 9), c(9, 1), c(300, 7), c(250, 17), c(40, 19), c(30, 40))) {
    for (cote in c(1L, 3L, 5L)) {
      image <- matrix(stats::rgamma(prod(forme), 4.4, 88) * 10^stats::runif(prod(forme), -4, 4),
                      forme[1], forme[2])
      expect_identical(moyenne_locale(image, cote), moyenne_locale_016(image, cote))
      image[sample(length(image), ceiling(length(image) / 6))] <- NA
      expect_identical(moyenne_locale(image, cote), moyenne_locale_016(image, cote))
    }
  }
})

test_that("mission 016 : filtre identique au bit près au calcul d'avant", {
  set.seed(162)
  dates <- seq(as.Date("2017-10-01"), by = 12, length.out = 50)
  for (forme in list(c(120, 9), c(8, 30), c(1, 6))) {
    serie <- array(stats::rgamma(prod(forme) * 50, 4.4, 88), dim = c(forme, 50))
    serie[sample(length(serie), length(serie) %/% 9)] <- NA
    for (cote in c(3L, 5L)) {
      obtenu <- s1_filter_multitemp(serie, dates, parametres_sufosat(fenetre_filtre = cote))
      attr(obtenu, "nb_images_noyau") <- NULL
      expect_identical(obtenu, filtre_016(serie, dates, cote))
    }
  }
})

# Empreinte MD5 des octets (petit-boutiste) des valeurs.
empreinte_016 <- function(...) {
  f <- tempfile()
  con <- file(f, "wb")
  for (x in list(...)) writeBin(as.vector(x), con, endian = "little")
  close(con)
  on.exit(unlink(f))
  unname(tools::md5sum(f))
}

test_that("mission 016 : sorties figées avant optimisation (empreinte)", {
  # cumsum() accumule en long double : l'empreinte n'est figée que sur la
  # plateforme où elle a été calculée (x86_64, R 4.3.3, code d'avant 016).
  skip_if_not(R.version$arch == "x86_64", "empreinte calculée sur x86_64")
  set.seed(16)
  dates <- seq(as.Date("2017-11-02"), by = 30, length.out = 24)
  serie <- array(stats::rgamma(7 * 5 * 24, shape = 4.4, rate = 88), dim = c(7, 5, 24))
  serie[c(3, 50, 51, 400, 700)] <- NA
  f3 <- s1_filter_multitemp(serie, dates)
  f5 <- s1_filter_multitemp(serie, dates, parametres_sufosat(fenetre_filtre = 5L))
  expect_identical(empreinte_016(f3, attr(f3, "nb_images_noyau"), f5),
                   "a70696bf533df701171cddd224fec6a7")
})
