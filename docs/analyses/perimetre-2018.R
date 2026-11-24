# Mission 031 : le périmètre 2018, ce qu'un départ des ratios en 2018 change
# ---------------------------------------------------------------------------
# Script d'analyse reproductible, SANS modification du package. À lancer
# depuis la racine du dépôt :
#
#   Rscript docs/analyses/perimetre-2018.R <m031> executer
#   Rscript docs/analyses/perimetre-2018.R <m031> calculer <m026> <m027>
#   Rscript docs/analyses/perimetre-2018.R <m031> signal   <m026> <m027>
#   Rscript docs/analyses/perimetre-2018.R <m031> mesurer  <m026> <m027> <dates_v301.tif> <sorties_017>
#
#   Base des « gagnés / perdus » du rapport (332 / 603) : n = 49 617 pixels publiés en 2019 et après,
#   datés par les deux cartes (étape mesurer, journal A_hors18_a15).
#
#   Ordre : executer (76 min sur le poste de Pascal, réseau), calculer (4 min), signal (3 min),
#   puis mesurer (quelques secondes ; le journal est affiché et écrit dans mesures_031.rds).
#
#   <m031>  : dossier de travail HORS du dépôt.
#   <m026>  : dossier de la mission 026 (series/ : VH filtré et ratios relevés,
#             noyau 2018, images de 2018 à 2025).
#   <m027>  : dossier de la mission 027 (cibles.rds : pixels communs aux deux
#             cartes et pixels datés de la tuile, avec leur cellule).
#
#   executer : relance nemetonsar_run() sur l'AOI pilote (mêmes AOI, période
#              2018-01-01 / 2025-09-30, réglages et masque BD Forêt que la
#              mission 017) avec parametres_sufosat(annee_noyau = 2017) : le
#              noyau du filtre est calculé sur les images de 2017, les ratios
#              partent du 1er janvier 2018 (annee_noyau + 1). Seul l'argument
#              `annee_noyau` change : c'est le départ « noyau pris en 2017 ».
#              Sortie : <m031>/n2017/sorties (dates.tif, objets.tif, ...).
#   calculer : variante « noyau 2018 conservé, ratios dès le 1er janvier 2018 »
#              (aucune lecture Sentinel-1) : depuis le VH filtré relevé par 026
#              (noyau 2018 appliqué à toutes les images, 2018 comprises, ce que
#              le package fait déjà), les ratios de détection (xb = Inf) et de
#              datation (xb_date = 5) sont recalculés avec un premier ratio dès
#              la date de départ choisie, pour plusieurs nombres minimaux
#              d'images dans Mb (1, 3, 5, 10). La règle de date est la règle
#              actuelle (R0 de la mission 027) ; le contrôle redonne la carte
#              de 017 pour le départ 2019. Sortie : <m031>/variantes.rds.
#   signal   : pour les pixels communs aux deux cartes, minimum du ratio de détection à +-15 j de
#              la date publiée (3 orbites, noyau 2018), avec Mb d'au moins 1, 5 ou 10 images :
#              la chute existe-t-elle dans la série à la date publiée, quelle que soit la règle ?
#              Sortie : <m031>/signal.rds.
#   mesurer  : accord des cartes avec la v3.0.1 (écart de date = date moins
#              date publiée), par année publiée, pour le groupe « début de
#              série » de 027 et pour les autres années. Sortie : <m031>/mesures_031.rds.
#
# La v3.0.1 est CC BY-NC 4.0 : l'extrait reste hors du dépôt ; les sorties
# avec des valeurs de pixel restent dans <m031>. Graine fixée.
# ---------------------------------------------------------------------------

if (!(file.exists("DESCRIPTION") && dir.exists("R"))) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : Rscript docs/analyses/perimetre-2018.R <m031> executer|calculer|mesurer ...", call. = FALSE)
}
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
if (startsWith(DOSSIER, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de travail doit être hors du dépôt.", call. = FALSE)
}
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
set.seed(20261124L)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# AOI, période, réglages : ceux des missions 017, 026 et 027.
POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2025-09-30")
P <- parametres_sufosat()
NA16 <- -32768L
de16 <- function(v) { v <- as.numeric(v); v[v == NA16] <- NA_real_; v / 100 }

aoi_pilote <- function(cote = COTE_M) {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                cote / 2, capstyle = "square")
}
ecart_j <- function(a, b) as.numeric(yyddd_vers_date(a) - yyddd_vers_date(b))
annee_de <- function(d) as.integer(format(as.Date(d, origin = "1970-01-01"), "%Y"))

# Étape 1 : la relance du package avec le noyau pris en 2017 ---------------------------

if (ETAPE == "executer") {
  # Réglages par défaut du package (passe 1 en parallèle, une orbite par processus), comme 026.
  t0 <- Sys.time()
  res <- nemetonsar_run(aoi_pilote(), DEBUT, FIN, dossier = file.path(DOSSIER, "n2017", "sorties"),
                        bdforet = "wfs", parametres = parametres_sufosat(annee_noyau = 2017L))
  t1 <- Sys.time()
  saveRDS(list(res = res, duree_h = as.numeric(difftime(t1, t0, units = "hours"))),
          file.path(DOSSIER, "n2017", "execution.rds"))
  print(res$tuiles)
  cat("Durée :", format(round(difftime(t1, t0, units = "mins"), 1)), "\n")
}

# Étape 2 : « noyau 2018 conservé, ratios dès 2018 » depuis les séries relevées -----------

# Ratios d'une orbite à TOUTES les dates (définition de rcr_compute() : voir
# cause-dates-tardives.R, mission 026, qui l'a contrôlée contre le package ; ici sans la
# restriction de début de série). x : pixels x dates, rétrodiffusion LINÉAIRE ; rangés à la
# colonne de d_(i+1). Rend aussi k (nombre d'images valides jusqu'à d_i incluse, soit la taille
# de Mb de la détection) et di (date de d_i) pour appliquer ensuite une date de départ et un
# nombre minimal d'images.
ratios_toutes_dates <- function(x, dates, p) {
  npix <- nrow(x)
  nt <- ncol(x)
  x[!is.na(x) & x <= 0] <- NA_real_
  xa <- p$xa
  cum <- matrix(NA_real_, npix, nt)
  pos <- matrix(NA_integer_, npix, nt)
  total <- integer(npix)
  somme <- numeric(npix)
  for (t in seq_len(nt)) {
    v <- which(!is.na(x[, t]))
    somme[v] <- somme[v] + x[v, t]
    total[v] <- total[v] + 1L
    cum[cbind(v, total[v])] <- somme[v]
    pos[cbind(v, total[v])] <- t
  }
  r_det <- r_dat <- di <- kk <- matrix(NA_real_, npix, nt)
  for (k in seq_len(max(max(total) - xa, 0L))) {
    pix <- which(total >= k + xa)
    if (length(pix) == 0L) next
    ck <- cum[pix, k]
    ma <- (cum[pix, k + xa] - ck) / xa
    nb <- min(k, p$xb_date)
    avant <- if (k - nb == 0L) 0 else cum[pix, k - nb]
    col <- pos[cbind(pix, k + 1L)]
    r_det[cbind(pix, col)] <- 10 * log10(ma / (ck / k))
    r_dat[cbind(pix, col)] <- 10 * log10(ma / ((ck - avant) / nb))
    di[cbind(pix, col)] <- as.numeric(dates[pos[cbind(pix, k)]])
    kk[cbind(pix, col)] <- k
  }
  list(r_det = r_det, r_dat = r_dat, di = di, k = kk)
}

# Règle actuelle (R0 de la mission 027) sur 3 orbites : orbite retenue = minimum du ratio de
# détection ; date = minimum du ratio de datation sur cette orbite (la plus ancienne en cas
# d'égalité). `coupe` : date de la première image de 2020 de chaque orbite (passe 2019 : ratios
# rangés après cette date écartés), NULL pour la série entière.
r0_bloc <- function(rdet, rdat, Dj, coupe = NULL) {
  n <- nrow(rdet[[1]])
  if (!is.null(coupe)) {
    for (j in 1:3) {
      hors <- as.numeric(Dj[[j]]) > coupe[j]
      rdet[[j]][, hors] <- NA_real_
      rdat[[j]][, hors] <- NA_real_
    }
  }
  mdet <- vapply(1:3, function(j) {
    v <- suppressWarnings(matrixStats::rowMins(rdet[[j]], na.rm = TRUE))
    v[!is.finite(v)] <- NA
    v
  }, numeric(n))
  mdet_i <- mdet; mdet_i[is.na(mdet_i)] <- Inf
  ret <- max.col(-mdet_i, ties.method = "first")
  ret[rowSums(!is.na(mdet)) == 0L] <- NA_integer_
  date_min <- function(m, D) {
    h <- rowSums(!is.na(m)) > 0
    mm <- m; mm[is.na(mm)] <- Inf
    d <- as.numeric(D)[max.col(-mm, ties.method = "first")]
    d[!h] <- NA_real_
    d
  }
  d <- vapply(1:3, function(j) date_min(rdat[[j]], Dj[[j]]), numeric(n))
  sel <- function(M) {
    v <- M[cbind(seq_len(n), ifelse(is.na(ret), 1L, ret))]
    v[is.na(ret)] <- NA_real_
    v
  }
  data.frame(mdet = sel(mdet), date = sel(d))
}

# Départs essayés : année de départ des ratios (1er janvier) x nombre minimal d'images
# dans Mb. « 2019 / 1 » est le départ actuel (contrôle contre la carte de 017).
DEPARTS <- rbind(
  data.frame(depart = 2019L, nmin = 1L),
  expand.grid(depart = 2018L, nmin = c(1L, 3L, 5L, 10L))
)
nom_depart <- function(d, n) sprintf("d%d_n%d", d, n)

if (ETAPE == "calculer") {
  M026 <- normalizePath(args[3], mustWork = TRUE)
  M027 <- normalizePath(args[4], mustWork = TRUE)
  D_SERIES <- file.path(M026, "series")
  C <- readRDS(file.path(M027, "cibles.rds"))
  cibles_cel <- sort(unique(c(C$cibles$cel, C$tuile$cel)))
  metas <- list.files(D_SERIES, pattern = "\\.rds$", full.names = TRUE)
  metas <- metas[!grepl("controle_", metas)]
  suffixe <- sub("^[AD][0-9]+_", "", sub("\\.rds$", "", basename(metas)))
  out <- list()
  for (sf in unique(suffixe)) {
    fs <- metas[suffixe == sf]
    M <- lapply(fs, readRDS)
    orbs <- vapply(M, function(m) m$orbite, "")
    o <- order(orbs); fs <- fs[o]; M <- M[o]; orbs <- orbs[o]
    stopifnot(length(fs) == 3L, identical(orbs, c("A030", "D008", "D081")))
    m1 <- M[[1]]
    cel_bloc <- (rep(m1$lignes_tuile, each = m1$nc) - 1L) * m1$nc + rep(seq_len(m1$nc), length(m1$lignes_tuile))
    rows <- which(cel_bloc %in% cibles_cel)
    if (!length(rows)) next
    R <- lapply(1:3, function(j) {
      m <- M[[j]]
      con <- file(sub("\\.rds$", ".bin", fs[j]), "rb")
      vh <- matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
      close(con)
      x <- 10^(de16(vh[rows, , drop = FALSE]) / 10)          # linéaire, au centième de dB
      x <- matrix(x, nrow = length(rows))
      ratios_toutes_dates(x, m$dates, P)
    })
    Dj <- lapply(M, function(m) m$dates)
    coupe <- vapply(Dj, function(d) {
      p <- d[d >= as.Date("2020-01-01")]
      if (length(p)) as.numeric(min(p)) else Inf
    }, numeric(1))
    res <- data.frame(cel = cel_bloc[rows])
    for (i in seq_len(nrow(DEPARTS))) {
      s <- as.numeric(as.Date(sprintf("%d-01-01", DEPARTS$depart[i])))
      nm <- DEPARTS$nmin[i]
      rd <- lapply(R, function(r) { ok <- !is.na(r$di) & r$di >= s & r$k >= nm; ifelse(ok, r$r_det, NA_real_) })
      rt <- lapply(R, function(r) { ok <- !is.na(r$di) & r$di >= s & r$k >= nm; ifelse(ok, r$r_dat, NA_real_) })
      pl <- r0_bloc(rd, rt, Dj)
      a <- r0_bloc(rd, rt, Dj, coupe)
      nom <- nom_depart(DEPARTS$depart[i], nm)
      res[[paste0(nom, "_mdet")]] <- pl$mdet
      res[[paste0(nom, "_date")]] <- pl$date
      res[[paste0(nom, "_a_mdet")]] <- a$mdet
      res[[paste0(nom, "_a_date")]] <- a$date
    }
    out[[sf]] <- res
    cat(sf, length(rows), "\n")
  }
  res <- do.call(rbind, out)
  res <- res[!duplicated(res$cel), ]
  rownames(res) <- NULL
  saveRDS(res, file.path(DOSSIER, "variantes.rds"))
  cat("Cellules calculées :", nrow(res), "\n")
}

# Étape 2 bis : le signal à la date publiée -------------------------------------------------

# Pour chaque pixel commun, le minimum, sur les 3 orbites, du ratio de détection des dates à
# +-15 j de la date publiée (la fenêtre de 024 et 026), avec Mb d'au moins `nmin` images, sans
# date de départ (VH relevé à partir de 2018, noyau 2018). Dit si la chute existe dans la série à
# la date publiée, quelle que soit la règle de date.
if (ETAPE == "signal") {
  M026 <- normalizePath(args[3], mustWork = TRUE)
  M027 <- normalizePath(args[4], mustWork = TRUE)
  D_SERIES <- file.path(M026, "series")
  C <- readRDS(file.path(M027, "cibles.rds"))
  cib <- C$cibles
  metas <- list.files(D_SERIES, pattern = "\\.rds$", full.names = TRUE)
  metas <- metas[!grepl("controle_", metas)]
  suffixe <- sub("^[AD][0-9]+_", "", sub("\\.rds$", "", basename(metas)))
  NMIN <- c(1L, 5L, 10L)
  out <- list()
  for (sf in unique(suffixe)) {
    fs <- metas[suffixe == sf]
    M <- lapply(fs, readRDS)
    orbs <- vapply(M, function(m) m$orbite, "")
    o <- order(orbs); fs <- fs[o]; M <- M[o]
    m1 <- M[[1]]
    cel_bloc <- (rep(m1$lignes_tuile, each = m1$nc) - 1L) * m1$nc + rep(seq_len(m1$nc), length(m1$lignes_tuile))
    rows <- which(cel_bloc %in% cib$cel)
    if (!length(rows)) next
    pub <- cib$pub[match(cel_bloc[rows], cib$cel)]
    res <- data.frame(cel = cel_bloc[rows])
    for (nm in NMIN) res[[paste0("m_n", nm)]] <- Inf
    for (j in 1:3) {
      m <- M[[j]]
      con <- file(sub("\\.rds$", ".bin", fs[j]), "rb")
      vh <- matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
      close(con)
      r <- ratios_toutes_dates(matrix(10^(de16(vh[rows, , drop = FALSE]) / 10), nrow = length(rows)), m$dates, P)
      dd <- matrix(as.numeric(m$dates), length(rows), m$nt, byrow = TRUE)
      dans <- abs(dd - pub) <= 15
      for (nm in NMIN) {
        v <- ifelse(dans & !is.na(r$k) & r$k >= nm, r$r_det, NA_real_)
        mn <- suppressWarnings(matrixStats::rowMins(v, na.rm = TRUE))
        res[[paste0("m_n", nm)]] <- pmin(res[[paste0("m_n", nm)]], mn)
      }
    }
    out[[sf]] <- res
    cat(sf, length(rows), "\n")
  }
  res <- do.call(rbind, out)
  res <- res[!duplicated(res$cel), ]
  for (nm in NMIN) res[[paste0("m_n", nm)]][!is.finite(res[[paste0("m_n", nm)]])] <- NA_real_
  saveRDS(res, file.path(DOSSIER, "signal.rds"))
  cat("Cellules : ", nrow(res), "\n")
}

# Étape 3 : mesures -----------------------------------------------------------------------

resume <- function(e) {
  e <- e[!is.na(e)]
  c(n = length(e), a15 = mean(abs(e) <= 15), a60 = mean(abs(e) <= 60), tardif = mean(e > 180),
    precoce = mean(e < -180), med = stats::median(e), med_abs = stats::median(abs(e)))
}

if (ETAPE == "mesurer") {
  M026 <- normalizePath(args[3], mustWork = TRUE)
  M027 <- normalizePath(args[4], mustWork = TRUE)
  reference <- normalizePath(args[5], mustWork = TRUE)
  base <- normalizePath(args[6], mustWork = TRUE)
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  out <- list()

  ## A. Les deux cartes complètes (package relancé), sur toute l'AOI -----------------------
  r0 <- terra::rast(file.path(base, "dates.tif"))
  r1 <- terra::rast(file.path(DOSSIER, "n2017", "sorties", "dates.tif"))
  stopifnot(terra::compareGeom(r0, r1, stopOnError = FALSE))
  ref <- terra::project(terra::rast(reference), r0, method = "near")
  dans <- !is.na(terra::values(terra::rasterize(aoi_pilote(), r0, field = 1), mat = FALSE))
  v0 <- terra::values(r0, mat = FALSE); v1 <- terra::values(r1, mat = FALSE)
  vp <- terra::values(ref, mat = FALSE); vp[vp == 0] <- NA
  v0[!dans] <- NA; v1[!dans] <- NA; vp[!dans] <- NA
  an_p <- annee_de(yyddd_vers_date(vp)); an_0 <- annee_de(yyddd_vers_date(v0)); an_1 <- annee_de(yyddd_vers_date(v1))
  out$A_taille <- c(aoi = sum(dans), dates_017 = sum(!is.na(v0)), dates_n2017 = sum(!is.na(v1)),
                    dates_v301 = sum(!is.na(vp)))
  out$A_par_annee <- data.frame(annee = 2018:2025,
    carte_017 = sapply(2018:2025, function(a) sum(an_0 == a, na.rm = TRUE)),
    carte_n2017 = sapply(2018:2025, function(a) sum(an_1 == a, na.rm = TRUE)),
    v301 = sapply(2018:2025, function(a) sum(an_p == a, na.rm = TRUE)))
  # Accord avec la v3.0.1 sur les pixels communs, par année publiée.
  accord <- function(v, nom) {
    com <- !is.na(v) & !is.na(vp)
    e <- ecart_j(v, vp)
    g <- function(w, lab) data.frame(carte = nom, groupe = lab, t(resume(e[com & w])))
    rbind(g(rep(TRUE, length(v)), "tous"), g(an_p == 2018, "publie_2018"), g(an_p == 2019, "publie_2019"),
          g(an_p >= 2020, "publie_2020_plus"), g(an_p >= 2019, "publie_2019_plus"))
  }
  out$A_accord <- rbind(accord(v0, "017"), accord(v1, "n2017"))
  # Pixels publiés en 2018 : part datée par la carte, et leur accord.
  pub18 <- !is.na(an_p) & an_p == 2018
  out$A_pub2018 <- data.frame(carte = c("017", "n2017"),
    pixels_pub_2018 = sum(pub18),
    dates_par_la_carte = c(sum(pub18 & !is.na(v0)), sum(pub18 & !is.na(v1))),
    dont_annee_2018 = c(sum(pub18 & an_0 == 2018, na.rm = TRUE), sum(pub18 & an_1 == 2018, na.rm = TRUE)))
  # Pixels que la carte date en 2018 : la v3.0.1 les date-t-elle ?
  out$A_dates_2018 <- data.frame(carte = c("017", "n2017"),
    pixels_2018 = c(sum(an_0 == 2018, na.rm = TRUE), sum(an_1 == 2018, na.rm = TRUE)),
    absents_v301 = c(sum(an_0 == 2018 & is.na(vp), na.rm = TRUE), sum(an_1 == 2018 & is.na(vp), na.rm = TRUE)),
    v301_2018 = c(sum(an_0 == 2018 & an_p == 2018, na.rm = TRUE), sum(an_1 == 2018 & an_p == 2018, na.rm = TRUE)),
    v301_autre_annee = c(sum(an_0 == 2018 & an_p != 2018, na.rm = TRUE), sum(an_1 == 2018 & an_p != 2018, na.rm = TRUE)))
  # Effet sur les autres années : pixels datés par les deux cartes.
  both <- !is.na(v0) & !is.na(v1)
  d01 <- ecart_j(v1, v0)
  out$A_effet_autres_annees <- data.frame(
    pixels_017 = sum(!is.na(v0)), pixels_n2017 = sum(!is.na(v1)), communs_aux_deux = sum(both),
    perdus_par_n2017 = sum(!is.na(v0) & is.na(v1)), gagnes_par_n2017 = sum(is.na(v0) & !is.na(v1)),
    gagnes_dates_2018 = sum(is.na(v0) & an_1 == 2018, na.rm = TRUE),
    date_changee = sum(both & d01 != 0), date_changee_plus_15j = sum(both & abs(d01) > 15),
    devenus_2018_alors_que_017_datait_apres = sum(both & an_1 == 2018 & an_0 >= 2019))
  # Pixels communs aux trois cartes ou aux deux, hors année publiée 2018 : l'accord change-t-il ?
  hors18 <- !is.na(vp) & an_p >= 2019
  e0 <- ecart_j(v0, vp); e1 <- ecart_j(v1, vp)
  w <- hors18 & both
  out$A_hors18_a15 <- c(n = sum(w), a15_017 = mean(abs(e0[w]) <= 15), a15_n2017 = mean(abs(e1[w]) <= 15),
                        gagnes = sum(w & abs(e0) > 15 & abs(e1) <= 15), perdus = sum(w & abs(e0) <= 15 & abs(e1) > 15))

  ## B. Noyau 2018 conservé, ratios dès 2018 : règle actuelle sur les pixels des cartes --------
  C <- readRDS(file.path(M027, "cibles.rds"))
  V <- readRDS(file.path(DOSSIER, "variantes.rds"))
  cib <- C$cibles
  # Date de la variante : passe 2019 si elle date en 2019, sinon passe principale si elle ne date pas en 2019.
  # Un pixel n'est daté que si son minimum du ratio de détection est sous tp (seuil effectif,
  # -3,45 dB) : approximation au pixel de « la détection ».
  TPE <- seuils_db(P)[["tp"]]
  date_variante <- function(V, nom) {
    a <- V[[paste0(nom, "_a_date")]]; am <- V[[paste0(nom, "_a_mdet")]]
    b <- V[[paste0(nom, "_date")]]; bm <- V[[paste0(nom, "_mdet")]]
    va <- !is.na(a) & annee_de(a) == 2019L & !is.na(am) & am <= TPE
    vb <- !is.na(b) & annee_de(b) != 2019L & !is.na(bm) & bm <= TPE
    ifelse(va, a, ifelse(vb, b, NA_real_))
  }
  noms <- nom_depart(DEPARTS$depart, DEPARTS$nmin)
  # Contrôle : le départ actuel redonne la carte de 017 sur les pixels datés de la tuile.
  Tt <- C$tuile
  kt <- match(Tt$cel, V$cel)
  d_t <- date_variante(V, "d2019_n1")[kt]
  carte_t <- as.numeric(yyddd_vers_date(Tt$date_tuile))
  out$B_controle <- c(pixels = nrow(Tt), sans_serie = sum(is.na(kt)), datees = sum(!is.na(d_t)),
                      identiques = sum(d_t == carte_t, na.rm = TRUE), a15j = sum(abs(d_t - carte_t) <= 15, na.rm = TRUE))
  # Pixels communs : écart à la date publiée, par groupe de 027 et par année publiée.
  k <- match(cib$cel, V$cel)
  Xc <- cbind(cib[, c("idx", "cel", "groupe", "pub", "carte")], V[k, setdiff(names(V), "cel")])
  an_pub <- annee_de(Xc$pub)
  groupes <- list(communs = rep(TRUE, nrow(Xc)), debut_serie = Xc$groupe == "tardif_debut_serie",
                  publie_2018 = an_pub == 2018, publie_2019 = an_pub == 2019,
                  publie_2020_plus = an_pub >= 2020, publie_2019_plus = an_pub >= 2019)
  tab <- do.call(rbind, lapply(noms, function(nm) {
    d <- date_variante(Xc, nm)
    do.call(rbind, lapply(names(groupes), function(g) {
      w <- groupes[[g]]
      data.frame(variante = nm, groupe = g, t(resume(d[w] - Xc$pub[w])),
                 sans_date = sum(w & is.na(d)), annee_2018 = sum(w & annee_de(d) == 2018, na.rm = TRUE))
    }))
  }))
  out$B_tab <- tab
  d_ref <- date_variante(Xc, "d2019_n1")
  out$B_mouvements <- do.call(rbind, lapply(noms, function(nm) {
    d <- date_variante(Xc, nm)
    e0 <- d_ref - Xc$pub; e1 <- d - Xc$pub
    w19 <- an_pub >= 2019
    data.frame(variante = nm, dates_changees = sum(d != d_ref, na.rm = TRUE),
               passent_en_2018 = sum(annee_de(d) == 2018 & annee_de(d_ref) >= 2019, na.rm = TRUE),
               passent_en_2018_publie_2018 = sum(annee_de(d) == 2018 & annee_de(d_ref) >= 2019 & an_pub == 2018, na.rm = TRUE),
               passent_en_2018_publie_apres = sum(annee_de(d) == 2018 & annee_de(d_ref) >= 2019 & w19, na.rm = TRUE),
               gagnes_a15 = sum(abs(e0) > 15 & abs(e1) <= 15, na.rm = TRUE),
               perdus_a15 = sum(abs(e0) <= 15 & abs(e1) > 15, na.rm = TRUE),
               gagnes_a15_publie_2018 = sum(an_pub == 2018 & abs(e0) > 15 & abs(e1) <= 15, na.rm = TRUE),
               perdus_a15_publie_2019_plus = sum(w19 & abs(e0) <= 15 & abs(e1) > 15, na.rm = TRUE))
  }))
  # Tous les pixels datés de la tuile : combien changent de date, combien passent en 2018.
  d_t0 <- date_variante(V, "d2019_n1")
  out$B_tuile <- do.call(rbind, lapply(noms, function(nm) {
    d <- date_variante(V, nm)
    data.frame(variante = nm, pixels = sum(!is.na(d_t0)), changent = sum(d != d_t0, na.rm = TRUE),
               passent_en_2018 = sum(annee_de(d) == 2018 & annee_de(d_t0) >= 2019, na.rm = TRUE),
               plus_de_60j = sum(abs(d - d_t0) > 60, na.rm = TRUE))
  }))
  # Mois de la première année : où tombent les dates de 2018 ? (agrégé au mois)
  out$B_mois_2018 <- sapply(noms, function(nm) {
    d <- date_variante(V, nm)
    table(factor(format(as.Date(d[annee_de(d) == 2018], origin = "1970-01-01"), "%m"), levels = sprintf("%02d", 1:12)))
  })
  # Signal à la date publiée (étape signal) : part des pixels dont le ratio de détection passe
  # sous tp (et sous -3,0 dB) à +-15 j de la date publiée, selon le nombre minimal d'images dans Mb.
  f_sig <- file.path(DOSSIER, "signal.rds")
  if (file.exists(f_sig)) {
    S <- readRDS(f_sig)
    ks <- match(cib$cel, S$cel)
    an_c <- annee_de(cib$pub)
    gr <- list(publie_2018 = an_c == 2018, debut_serie = cib$groupe == "tardif_debut_serie",
               publie_2019 = an_c == 2019, publie_2020_plus = an_c >= 2020)
    out$S_signal <- do.call(rbind, lapply(names(gr), function(g) {
      w <- gr[[g]]
      do.call(rbind, lapply(grep("^m_n", names(S), value = TRUE), function(cn) {
        v <- S[[cn]][ks][w]
        data.frame(groupe = g, mb_min_images = sub("m_n", "", cn), pixels = length(v), sans_ratio = sum(is.na(v)),
                   sous_tp = mean(v <= TPE, na.rm = TRUE), sous_moins3 = mean(v <= -3, na.rm = TRUE),
                   mediane_db = stats::median(v, na.rm = TRUE))
      }))
    }))
  }
  # Par mois de 2018 (agrégé au mois) : pixels que la carte relancée (noyau 2017) date en 2018, pixels
  # publiés en 2018, et, pour les communs publiés en 2018, part au signal sous tp à la date publiée.
  mois <- function(d) factor(format(as.Date(d, origin = "1970-01-01"), "%m"), levels = sprintf("%02d", 1:12))
  d_1 <- as.numeric(yyddd_vers_date(v1)); d_p <- as.numeric(yyddd_vers_date(vp))
  out$M_mois_2018 <- data.frame(mois = levels(mois(0)),
    carte_n2017 = as.integer(table(mois(d_1[!is.na(an_1) & an_1 == 2018]))),
    v301 = as.integer(table(mois(d_p[!is.na(an_p) & an_p == 2018]))))
  if (file.exists(f_sig)) {
    w <- an_c == 2018
    v <- S$m_n1[ks][w]
    m <- mois(cib$pub[w])
    out$M_signal_mois <- data.frame(mois = levels(m), pixels = as.integer(table(m)),
      sous_tp = as.numeric(tapply(v <= TPE, m, mean, na.rm = TRUE)))
  }
  saveRDS(out, file.path(DOSSIER, "mesures_031.rds"))
  options(width = 200, digits = 4)
  for (n in names(out)) { cat("\n##", n, "\n"); print(out[[n]]) }
}
