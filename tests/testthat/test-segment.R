# Seuils effectifs par défaut (ts = -5,175 dB, tp = -3,45 dB), lus et non
# écrits en dur.
s_def <- seuils_db(parametres_sufosat())
sous_ts <- s_def[["ts"]] - 1   # graine
entre <- (s_def[["ts"]] + s_def[["tp"]]) / 2 # sous tp, pas graine
au_dessus <- s_def[["tp"]] + 1 # ni l'un ni l'autre

fond <- function(nr, nc) matrix(au_dessus, nr, nc)

# Référence naïve : parcours en largeur pixel par pixel, écrit depuis la
# définition (graine < ts ; zone = composante connexe des pixels <= tp ;
# gardée si elle contient une graine).
segment_naif <- function(ratio, ts, tp, connexite) {
  nr <- nrow(ratio)
  nc <- ncol(ratio)
  dans_tp <- !is.na(ratio) & ratio <= tp
  graine <- !is.na(ratio) & ratio < ts
  vu <- matrix(FALSE, nr, nc)
  det <- matrix(FALSE, nr, nc)
  if (connexite == 4L) {
    voisins <- rbind(c(-1, 0), c(1, 0), c(0, -1), c(0, 1))
  } else {
    voisins <- as.matrix(expand.grid(-1:1, -1:1))
    voisins <- voisins[!(voisins[, 1] == 0 & voisins[, 2] == 0), ]
  }
  for (i in seq_len(nr)) for (j in seq_len(nc)) {
    if (!dans_tp[i, j] || vu[i, j]) next
    file <- list(c(i, j))
    vu[i, j] <- TRUE
    membres <- list()
    while (length(file) > 0) {
      q <- file[[1]]
      file <- file[-1]
      membres[[length(membres) + 1]] <- q
      for (v in seq_len(nrow(voisins))) {
        y <- q[1] + voisins[v, 1]
        x <- q[2] + voisins[v, 2]
        if (y >= 1 && y <= nr && x >= 1 && x <= nc && dans_tp[y, x] && !vu[y, x]) {
          vu[y, x] <- TRUE
          file[[length(file) + 1]] <- c(y, x)
        }
      }
    }
    m <- do.call(rbind, membres)
    if (any(graine[m])) det[m] <- TRUE
  }
  det
}

test_that("une zone sous tp qui touche une graine est gardée en entier", {
  r <- fond(8, 8)
  r[2:4, 2:5] <- entre
  r[3, 4] <- sous_ts
  s <- rcr_segment(r)
  attendu <- matrix(FALSE, 8, 8)
  attendu[2:4, 2:5] <- TRUE
  expect_identical(s$detection, attendu)
  expect_identical(sum(s$graine), 1L)
  expect_identical(unique(s$zone[attendu]), 1L)
  expect_true(all(is.na(s$zone[!attendu])))
})

test_that("une zone sous tp sans graine est rejetée", {
  r <- fond(8, 8)
  r[2:4, 2:5] <- entre
  s <- rcr_segment(r)
  expect_false(any(s$detection))
  expect_true(all(is.na(s$zone)))
})

test_that("une graine isolée est gardée, seule", {
  r <- fond(5, 5)
  r[3, 3] <- sous_ts
  s <- rcr_segment(r)
  expect_identical(which(s$detection), 13L)
  expect_identical(s$zone[3, 3], 1L)
})

test_that("plusieurs zones : seules celles avec graine, numérotées par ordre", {
  r <- fond(10, 10)
  r[1:2, 1:2] <- entre            # sans graine : rejetée
  r[5:6, 1:3] <- entre
  r[6, 2] <- sous_ts              # zone A (première en colonne 1)
  r[2:3, 8:9] <- entre
  r[2, 9] <- sous_ts              # zone B
  r[9, 9] <- sous_ts              # graine isolée, zone C
  s <- rcr_segment(r)
  expect_false(any(s$detection[1:2, 1:2]))
  expect_true(all(s$zone[5:6, 1:3] == 1L))
  expect_true(all(s$zone[2:3, 8:9] == 2L))
  expect_identical(s$zone[9, 9], 3L)
  expect_identical(sum(s$detection), 6L + 4L + 1L)
})

test_that("les seuils viennent de parametres_sufosat() et suivent le facteur", {
  # Pixel à -5 dB : au-dessus de ts effectif par défaut (-5,175 dB), donc pas
  # graine ; avec facteur_seuil = 1, ts = -4,5 dB : graine.
  r <- fond(3, 3)
  r[2, 2] <- -5
  defaut <- rcr_segment(r)
  expect_identical(defaut$seuils_db, seuils_db(parametres_sufosat()))
  expect_false(any(defaut$detection))

  p1 <- parametres_sufosat(facteur_seuil = 1)
  f1 <- rcr_segment(r, p1)
  expect_identical(f1$seuils_db, c(ts = -4.5, tp = -3))
  expect_true(f1$detection[2, 2])

  # Et tp : un pixel à -3,2 dB est dans la zone avec le facteur 1 (tp = -3),
  # hors zone avec le défaut (tp = -3,45).
  r[2, 3] <- -3.2
  expect_true(rcr_segment(r, p1)$detection[2, 3])
  r[2, 2] <- -6
  expect_false(rcr_segment(r)$detection[2, 3])
  expect_true(rcr_segment(r)$detection[2, 2])
})

test_that("connexité 4 contre 8 sur un cas diagonal", {
  r <- fond(4, 4)
  r[1, 1] <- sous_ts
  r[2, 2] <- entre
  r[3, 3] <- entre
  r[3, 4] <- entre
  s8 <- rcr_segment(r, parametres_sufosat(connexite = 8L))
  s4 <- rcr_segment(r, parametres_sufosat(connexite = 4L))
  expect_true(all(s8$detection[cbind(c(1, 2, 3, 3), c(1, 2, 3, 4))]))
  expect_identical(sum(s8$detection), 4L)
  expect_identical(which(s4$detection), 1L)
  # Défaut : 8 voisins (provisoire)
  expect_identical(rcr_segment(r)$detection, s8$detection)
  # Diagonale montante aussi
  r2 <- fond(3, 3)
  r2[3, 1] <- sous_ts
  r2[2, 2] <- entre
  r2[1, 3] <- entre
  expect_identical(sum(rcr_segment(r2, parametres_sufosat(connexite = 8L))$detection), 3L)
  expect_identical(sum(rcr_segment(r2, parametres_sufosat(connexite = 4L))$detection), 1L)
})

test_that("un NA n'est pas détecté et coupe une zone", {
  r <- fond(1, 5)
  r[1, ] <- c(sous_ts, entre, NA, entre, entre)
  s <- rcr_segment(r)
  expect_identical(as.vector(s$detection), c(TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_true(is.na(s$zone[1, 3]))
  r[1, 3] <- NaN
  expect_identical(as.vector(rcr_segment(r)$detection), c(TRUE, TRUE, FALSE, FALSE, FALSE))
  # Matrice entièrement NA (logique ou numérique)
  tout_na <- matrix(NA, 3, 3)
  expect_false(any(rcr_segment(tout_na)$detection))
  expect_false(any(rcr_segment(tout_na * 1)$detection))
})

test_that("les bords et les coins de la matrice sont traités", {
  r <- fond(5, 6)
  r[, 1] <- entre
  r[5, 1] <- sous_ts            # coin bas-gauche : la colonne 1 entière
  r[1, 6] <- sous_ts            # coin haut-droit isolé
  r[5, 5:6] <- entre            # bord bas sans graine
  s <- rcr_segment(r)
  expect_true(all(s$detection[, 1]))
  expect_true(s$detection[1, 6])
  expect_false(any(s$detection[5, 5:6]))
  # Une seule ligne, une seule colonne, un seul pixel
  expect_identical(as.vector(rcr_segment(matrix(c(entre, sous_ts, entre, au_dessus, entre), 1))$detection),
                   c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_identical(as.vector(rcr_segment(matrix(c(entre, sous_ts, entre, au_dessus, entre), ncol = 1))$detection),
                   c(TRUE, TRUE, TRUE, FALSE, FALSE))
  expect_true(rcr_segment(matrix(sous_ts))$detection[1, 1])
  expect_false(rcr_segment(matrix(entre))$detection[1, 1])
  # Matrice vide
  vide <- rcr_segment(matrix(numeric(0), 0, 3))
  expect_identical(dim(vide$detection), c(0L, 3L))
})

test_that("ratio exactement égal aux seuils : ts strict (B18), tp inclus (provisoire)", {
  r <- fond(1, 3)
  r[1, 2] <- s_def[["ts"]]       # égal à ts : pas une graine
  s <- rcr_segment(r)
  expect_false(s$graine[1, 2])
  expect_false(s$detection[1, 2])

  r <- fond(1, 3)
  r[1, 1] <- sous_ts
  r[1, 2] <- s_def[["tp"]]       # égal à tp : dans la zone
  s <- rcr_segment(r)
  expect_identical(as.vector(s$detection), c(TRUE, TRUE, FALSE))
})

test_that("dimnames gardés et résultat de rcr_compute() accepté", {
  r <- fond(2, 3)
  r[1, 2] <- sous_ts
  dimnames(r) <- list(c("a", "b"), c("x", "y", "z"))
  s <- rcr_segment(r)
  expect_identical(dimnames(s$detection), dimnames(r))
  expect_identical(dimnames(s$zone), dimnames(r))
  expect_identical(dimnames(s$graine), dimnames(r))
  expect_type(s$zone, "integer")

  dates <- seq(as.Date("2021-01-05"), by = 12, length.out = 10)
  serie <- array(0.05, dim = c(3, 3, 10))
  serie[2, 2, 6:10] <- 0.05 * db_vers_lineaire(-7)
  serie[2, 3, 6:10] <- 0.05 * db_vers_lineaire(-4)
  rc <- rcr_compute(serie, dates)
  depuis_liste <- rcr_segment(rc)
  expect_identical(depuis_liste, rcr_segment(rc$ratio_min_db))
  expect_identical(which(depuis_liste$detection), c(5L, 8L))
})

test_that("les entrées invalides sont refusées", {
  expect_error(rcr_segment(1:3), "matrice", class = "error")
  expect_error(rcr_segment(matrix("a", 2, 2)), "matrice")
  expect_error(rcr_segment(matrix(c(-Inf, 0, 0, 0), 2)), "infinie")
  expect_error(rcr_segment(list(a = 1)), "rcr_compute")
  expect_error(rcr_segment(matrix(0, 2, 2), parametres = list()), "parametres_sufosat")
})

test_that("égal à la référence naïve sur des matrices aléatoires", {
  set.seed(5)
  for (k in 1:40) {
    nr <- sample(1:15, 1)
    nc <- sample(1:15, 1)
    r <- matrix(stats::runif(nr * nc, -7, 0), nr, nc)
    r[sample(length(r), floor(length(r) * 0.1))] <- NA
    con <- if (k %% 2 == 0) 4L else 8L
    p <- parametres_sufosat(connexite = con, facteur_seuil = sample(c(0.8, 1, 1.15), 1))
    s <- seuils_db(p)
    attendu <- segment_naif(r, s[["ts"]], s[["tp"]], con)
    obtenu <- rcr_segment(r, p)
    expect_identical(obtenu$detection, attendu)
    # Les identifiants sont cohérents : même zone <=> même composante
    expect_identical(!is.na(obtenu$zone), attendu)
  }
})

test_that("étiquetage juste sur des formes difficiles (spirale, peigne)", {
  # Spirale : un long chemin qui force de nombreux tours d'union-find.
  n <- 41
  m <- matrix(FALSE, n, n)
  haut <- 1; bas <- n; g <- 1; d <- n
  while (haut <= bas && g <= d) {
    m[haut, g:d] <- TRUE
    m[haut:bas, d] <- TRUE
    if (haut + 2 <= bas) m[bas, g:d] <- TRUE
    if (g + 2 <= d && haut + 2 <= bas) m[(haut + 2):bas, g] <- TRUE
    if (g + 2 <= d) m[haut + 2, g:(d - 2)] <- TRUE
    haut <- haut + 2; bas <- bas - 2; g <- g + 2; d <- d - 2
  }
  r <- ifelse(m, entre, au_dessus)
  r[n, n] <- if (m[n, n]) sous_ts else r[n, n]
  for (con in c(4L, 8L)) {
    p <- parametres_sufosat(connexite = con)
    expect_identical(rcr_segment(r, p)$detection,
                     segment_naif(r, s_def[["ts"]], s_def[["tp"]], con))
  }
  # Peigne : dents verticales reliées par le bas, graine au bout d'une dent
  r <- fond(20, 21)
  r[, seq(1, 21, 2)] <- entre
  r[20, ] <- entre
  r[1, 21] <- sous_ts
  expect_identical(sum(rcr_segment(r, parametres_sufosat(connexite = 4L))$detection),
                   sum(r <= s_def[["tp"]]))
})
