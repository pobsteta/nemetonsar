# Mission 027 : deux règles de date essayées sur les séries relevées par la mission 026
# ---------------------------------------------------------------------------
# Script d'analyse reproductible, SANS modification du package ni nouvelle
# lecture Sentinel-1. À lancer depuis la racine du dépôt :
#
#   Rscript docs/analyses/regles-de-date.R <m027> calculer <m026> <dates_v301.tif> <sorties_017>
#   Rscript docs/analyses/regles-de-date.R <m027> mesurer  <m026>
#   Rscript docs/analyses/regles-de-date.R <m027> tracer   <m026>
#
#   <m027>  : dossier de travail HORS du dépôt (sorties de ce script).
#   <m026>  : dossier de la mission 026 (series/, pixels_026.rds, pixels_traces.rds,
#             sorties/ ; relevé par cause-dates-tardives.R, étape relever).
#   <sorties_017> : sorties de la mission 017 (dates.tif).
#
#   calculer : pour tous les pixels communs aux deux cartes et tous les pixels
#              datés de la tuile, depuis les séries relevées (ratios de
#              détection et de datation, toutes dates, 3 orbites) :
#                R0  règle actuelle : orbite retenue = minimum du ratio de
#                    détection ; date = minimum du ratio de datation sur cette
#                    orbite (recalculée, contrôlée contre la carte de 017) ;
#                R1  première date où le ratio de datation de l'orbite retenue
#                    est <= s (s = -3,0 dB : tp_db sans le facteur 1,15) ;
#                R2  première date où le ratio de datation de l'une quelconque
#                    des orbites est <= tp (-3,45 dB, seuil effectif de détection) ;
#                R3  première date où l'une quelconque des orbites est <= s ;
#              et, pour lire l'effet de « la première date » seule, R1 et R3 à
#              plusieurs seuils s (-2,5 ; -3,0 ; -3,45 ; -4,0 dB). R1 à -3,45 dB
#              est la « première datation » sur l'orbite retenue.
#              Sortie : <m027>/cibles.rds, <m027>/regles_cellules.rds.
#   mesurer  : écart à la v3.0.1 de chaque règle (écart = date de la règle -
#              date publiée), par groupe de la mission 026 et sur tous les
#              pixels communs (base non conditionnée par le résultat de la
#              règle actuelle) ; objets de la tuile (date médiane en 2019).
#              Sortie : <m027>/mesures_027.rds.
#   tracer   : séries des pixels tracés par 026 avec la date de chaque
#              règle ; <m027>/traces/*.png.
#
# La v3.0.1 est CC BY-NC 4.0 : l'extrait reste hors du dépôt ; les sorties
# avec des valeurs de pixel restent dans <m027>. Graine fixée.
# ---------------------------------------------------------------------------

if (!(file.exists("DESCRIPTION") && dir.exists("R"))) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3L) {
  stop("Usage : Rscript docs/analyses/regles-de-date.R dossier etape m026 ...", call. = FALSE)
}
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
M026 <- normalizePath(args[3], mustWork = TRUE)
if (startsWith(DOSSIER, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de travail doit être hors du dépôt.", call. = FALSE)
}
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
set.seed(20261124L)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# AOI, période, réglages : ceux de la mission 017 / 026.
POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
P <- parametres_sufosat()
TP <- seuils_db(P)[["tp"]]                  # -3,45 dB (facteur 1,15 compris)
S_DATE <- P$tp_db                           # -3,0 dB (sans le facteur)
SEUILS <- c(-2.5, S_DATE, TP, -4.0)         # essais de seuil (R1 et R3)
nom_seuil <- function(s) sprintf("%d", round(-s * 100))
D_SERIES <- file.path(M026, "series")
NA16 <- -32768L
de16 <- function(v) { v <- as.numeric(v); v[v == NA16] <- NA_real_; v / 100 }

aoi_pilote <- function(cote = COTE_M) {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                cote / 2, capstyle = "square")
}
grille_tuile <- function(cote = COTE_M) aoi_grille(aoi_preparer(aoi_pilote(cote), resolution_m = 10)$tuiles[1, ])
ecart_j <- function(a, b) as.numeric(yyddd_vers_date(a) - yyddd_vers_date(b))
lire_couple <- function(sorties, reference) {
  rec_d <- terra::rast(file.path(sorties, "dates.tif"))
  ref <- terra::project(terra::rast(reference), rec_d, method = "near")
  dans <- !is.na(terra::values(terra::rasterize(aoi_pilote(), rec_d, field = 1), mat = FALSE))
  vr <- terra::values(rec_d, mat = FALSE)
  vp <- terra::values(ref, mat = FALSE)
  vp[vp == 0] <- NA
  list(grille = rec_d, dans = dans, rec = vr, ref = vp)
}

# Premier passage sous s (colonne), NA si aucun ; date numérique.
premiere <- function(m, D, s) {
  z <- !is.na(m) & m <= s + 1e-9
  h <- rowSums(z) > 0
  d <- as.numeric(D)[max.col(z * 1L, ties.method = "first")]
  d[!h] <- NA_real_
  d
}
# Date du minimum (première en cas d'égalité), NA si ligne vide.
date_du_min <- function(m, D) {
  h <- rowSums(!is.na(m)) > 0
  mm <- m; mm[is.na(mm)] <- Inf
  d <- as.numeric(D)[max.col(-mm, ties.method = "first")]
  d[!h] <- NA_real_
  d
}

# Étape 1 : les règles, pixel par pixel --------------------------------------------------

# Les cinq quantités d'un bloc de pixels, pour une série entière (coupe = NULL) ou pour la
# série de la passe 2019 de nemetonsar_run() (coupe = date de la première image de 2020 de
# chaque orbite : les ratios des dates d_i de 2019, rangés à d_(i+1), sont seuls gardés ;
# la moyenne Mb d'un ratio ne dépend que des images d'avant, donc ces ratios sont ceux de
# la série entière).
regles_bloc <- function(rdet, rdat, Dj, coupe = NULL) {
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
  sel <- function(L) {
    v <- L[[1]]
    for (j in 2:3) v[ret == j & !is.na(ret)] <- L[[j]][ret == j & !is.na(ret)]
    v[is.na(ret)] <- NA_real_
    v
  }
  res <- data.frame(orbite = c("A030", "D008", "D081")[ret], mdet = sel(lapply(1:3, function(j) mdet[, j])))
  res$r0 <- sel(lapply(1:3, function(j) date_du_min(rdat[[j]], Dj[[j]])))
  for (s in SEUILS) {
    pj <- lapply(1:3, function(j) premiere(rdat[[j]], Dj[[j]], s))
    res[[paste0("r1_", nom_seuil(s))]] <- sel(pj)
    tout <- do.call(cbind, pj); tout[is.na(tout)] <- Inf
    mn <- apply(tout, 1, min); mn[!is.finite(mn)] <- NA_real_
    res[[paste0("r3_", nom_seuil(s))]] <- mn
  }
  res
}

if (ETAPE == "calculer") {
  reference <- normalizePath(args[4]); base <- normalizePath(args[5])
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  G <- grille_tuile()
  # Pixels communs aux deux cartes (comme 024 et 026) : cellule de la tuile.
  b <- lire_couple(base, reference)
  commun <- which(b$dans & !is.na(b$rec) & !is.na(b$ref))
  xy <- terra::xyFromCell(b$grille, commun)
  xy_utm <- terra::crds(terra::project(terra::vect(xy, crs = "EPSG:2154"), terra::crs(G)))
  cel_c <- terra::cellFromXY(G, xy_utm)
  p26 <- readRDS(file.path(M026, "pixels_026.rds"))
  groupe <- p26$groupe[match(commun, p26$idx)]
  groupe[is.na(groupe)] <- "autre_commun"
  e0 <- ecart_j(b$rec[commun], b$ref[commun])
  cibles <- data.frame(idx = commun, cel = cel_c, groupe = groupe,
                       pub = as.numeric(yyddd_vers_date(b$ref[commun])),
                       carte = as.numeric(yyddd_vers_date(b$rec[commun])), x = xy[, 1], y = xy[, 2])
  # Contrôle : les groupes de 026 se retrouvent à l'unité.
  stopifnot(identical(sum(grepl("^tardif_", cibles$groupe)), sum(e0 > 180)))
  # Pixels datés de la tuile (pour les objets et le contrôle de la carte).
  dt <- terra::values(terra::rast(file.path(M026, "sorties", "tuiles", "30TXP", "dates.tif")), mat = FALSE)
  ot <- terra::values(terra::rast(file.path(M026, "sorties", "tuiles", "30TXP", "objets.tif")), mat = FALSE)
  cel_t <- which(!is.na(dt))
  tuile <- data.frame(cel = cel_t, date_tuile = dt[cel_t], objet = ot[cel_t])
  saveRDS(list(cibles = cibles, tuile = tuile, nl = terra::nrow(G), nc = terra::ncol(G)),
          file.path(DOSSIER, "cibles.rds"))
  cat("Pixels communs :", nrow(cibles), "; pixels datés de la tuile :", nrow(tuile), "\n")

  cibles_cel <- sort(unique(c(cibles$cel, tuile$cel)))
  metas <- list.files(D_SERIES, pattern = "\\.rds$", full.names = TRUE)
  metas <- metas[!grepl("controle_", metas)]
  suffixe <- sub("^[AD][0-9]+_", "", sub("\\.rds$", "", basename(metas)))
  out <- list()
  for (sf in unique(suffixe)) {
    fs <- metas[suffixe == sf]
    M <- lapply(fs, readRDS)
    orbs <- vapply(M, function(m) m$orbite, "")
    o <- order(orbs); fs <- fs[o]; M <- M[o]; orbs <- orbs[o]
    stopifnot(length(fs) == 3L, identical(orbs, c("A030", "D008", "D081")),
              identical(M[[1]]$lignes_tuile, M[[2]]$lignes_tuile),
              identical(M[[1]]$lignes_tuile, M[[3]]$lignes_tuile))
    m1 <- M[[1]]
    cel_bloc <- (rep(m1$lignes_tuile, each = m1$nc) - 1L) * m1$nc + rep(seq_len(m1$nc), length(m1$lignes_tuile))
    rows <- which(cel_bloc %in% cibles_cel)
    if (!length(rows)) next
    rdet <- rdat <- list()
    for (j in 1:3) {
      m <- M[[j]]
      con <- file(sub("\\.rds$", ".bin", fs[j]), "rb")
      seek(con, where = as.numeric(m$npix) * m$nt * 2)          # saute le VH
      a <- matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
      d <- matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
      close(con)
      rdet[[j]] <- matrix(de16(a[rows, , drop = FALSE]), nrow = length(rows))
      rdat[[j]] <- matrix(de16(d[rows, , drop = FALSE]), nrow = length(rows))
    }
    Dj <- lapply(M, function(m) m$dates)
    coupe <- vapply(Dj, function(d) {
      p <- d[d >= as.Date("2020-01-01")]
      if (length(p)) as.numeric(min(p)) else Inf
    }, numeric(1))
    plein <- regles_bloc(rdet, rdat, Dj)
    passe19 <- regles_bloc(rdet, rdat, Dj, coupe)
    names(passe19) <- paste0("a_", names(passe19))
    out[[sf]] <- cbind(cel = cel_bloc[rows], plein, passe19)
    cat(sf, length(rows), "\n")
  }
  res <- do.call(rbind, out)
  res <- res[!duplicated(res$cel), ]
  rownames(res) <- NULL
  saveRDS(res, file.path(DOSSIER, "regles_cellules.rds"))
  cat("Cellules calculées :", nrow(res), "\n")
}

# Étape 2 : mesures ------------------------------------------------------------------------

resume <- function(e, n_sans = 0L) {
  e <- e[!is.na(e)]
  c(n = length(e), a15 = mean(abs(e) <= 15), a60 = mean(abs(e) <= 60), tardif = mean(e > 180),
    precoce = mean(e < -180), med = stats::median(e), med_abs = stats::median(abs(e)),
    sans_date = n_sans)
}

if (ETAPE == "mesurer") {
  C <- readRDS(file.path(DOSSIER, "cibles.rds"))
  R <- readRDS(file.path(DOSSIER, "regles_cellules.rds"))
  cib <- C$cibles
  k <- match(cib$cel, R$cel)
  out <- list(taille = c(communs = nrow(cib), sans_serie = sum(is.na(k))))
  X <- R[k, ]
  X$pub <- cib$pub; X$carte <- cib$carte; X$groupe <- cib$groupe
  # Source de la date : les pixels que la carte date de 2019 viennent de la passe 2019
  # (série coupée, colonnes a_*) ; les autres de la passe principale (série entière).
  X$a19 <- format(as.Date(X$carte, origin = "1970-01-01"), "%Y") == "2019"
  cols <- grep("^(r0|r1_|r3_)", names(R), value = TRUE)
  for (ch in cols) X[[ch]] <- ifelse(X$a19, X[[paste0("a_", ch)]], X[[ch]])
  X$orbite <- ifelse(X$a19, X$a_orbite, X$orbite)
  X$mdet <- ifelse(X$a19, X$a_mdet, X$mdet)
  # Contrôle de la règle actuelle : date recalculée = date de la carte de 017.
  out$controle_r0 <- c(pixels = sum(!is.na(X$r0)), egale = sum(X$r0 == X$carte, na.rm = TRUE),
                       diff_15j = sum(abs(X$r0 - X$carte) > 15, na.rm = TRUE))
  # Règles retenues pour la mesure : date de la règle, ou, faute de passage sous le
  # seuil, la règle actuelle (le package doit rendre une date à tout pixel détecté).
  regles <- c(R0 = "r0", R1 = "r1_300", R2 = "r3_345", R3 = "r3_300",
              R1_345 = "r1_345", R1_250 = "r1_250", R1_400 = "r1_400",
              R3_250 = "r3_250", R3_400 = "r3_400")
  date_regle <- lapply(regles, function(ch) {
    d <- X[[ch]]
    list(d = ifelse(is.na(d), X$r0, d), sans = is.na(d) & !is.na(X$r0))
  })
  names(date_regle) <- names(regles)
  tarde <- startsWith(X$groupe, "tardif_")
  groupes <- list(tardifs = tarde, tardif_debut_serie = X$groupe == "tardif_debut_serie",
                  tardif_regle_15j = X$groupe == "tardif_regle_15j", tardif_regle_60j = X$groupe == "tardif_regle_60j",
                  tardif_plus_datee = X$groupe == "tardif_plus_datee", tardif_reste = X$groupe == "tardif_reste",
                  temoin = X$groupe == "temoin_retrouve", autre_commun = X$groupe == "autre_commun",
                  communs = rep(TRUE, nrow(X)))
  tab <- do.call(rbind, lapply(names(date_regle), function(r) {
    do.call(rbind, lapply(names(groupes), function(g) {
      w <- groupes[[g]]
      v <- resume(date_regle[[r]]$d[w] - X$pub[w], sum(date_regle[[r]]$sans[w]))
      data.frame(regle = r, groupe = g, t(v))
    }))
  }))
  out$tab <- tab
  out$devenir <- do.call(rbind, lapply(names(date_regle), function(r) {
    d <- date_regle[[r]]$d; e <- d - X$pub; e0 <- X$r0 - X$pub
    t_ <- tarde; m_ <- X$groupe == "temoin_retrouve"
    data.frame(regle = r,
      tardifs_a15 = sum(t_ & abs(e) <= 15, na.rm = TRUE), tardifs_a60 = sum(t_ & abs(e) <= 60, na.rm = TRUE),
      tardifs_encore_tardifs = sum(t_ & e > 180, na.rm = TRUE), tardifs_deviennent_precoces = sum(t_ & e < -180, na.rm = TRUE),
      temoins_perdus_15 = sum(m_ & abs(e) > 15, na.rm = TRUE), temoins_perdus_60 = sum(m_ & abs(e) > 60, na.rm = TRUE),
      temoins_precoces_15 = sum(m_ & e < -15, na.rm = TRUE), temoins_tardifs_15 = sum(m_ & e > 15, na.rm = TRUE),
      communs_a15_gagnes = sum(abs(e0) > 15 & abs(e) <= 15, na.rm = TRUE),
      communs_a15_perdus = sum(abs(e0) <= 15 & abs(e) > 15, na.rm = TRUE),
      avance_mediane_j = stats::median((d - X$r0)[which(d != X$r0)]), dates_changees = sum(d != X$r0, na.rm = TRUE))
  }))
  out$sans_date <- sapply(regles, function(ch) sum(is.na(X[[ch]]) & !is.na(X$r0)))
  an <- function(d) format(as.Date(d, origin = "1970-01-01"), "%Y")
  out$part_2019 <- sapply(regles, function(ch) mean(an(ifelse(is.na(X[[ch]]), X$r0, X[[ch]])) == "2019", na.rm = TRUE))
  out$part_2019_publiee <- mean(an(X$pub) == "2019")

  # Objets de la tuile : la correction 2019 lit la date médiane de chaque objet.
  # On refait la médiane des dates pixel (YYDDD) par objet sous chaque règle, pour les
  # pixels datés de la tuile ; les objets de la passe 2019 (date de la tuile en 2019)
  # ne se recalculent pas depuis la série principale et sont comptés à part.
  Tt <- C$tuile
  kt <- match(Tt$cel, R$cel)
  Y <- R[kt, ]
  a19t <- Tt$date_tuile %/% 1000L == 19L
  for (ch in cols) Y[[ch]] <- ifelse(a19t, Y[[paste0("a_", ch)]], Y[[ch]])
  Y$mdet <- ifelse(a19t, Y$a_mdet, Y$mdet)
  yy <- function(d) date_vers_yyddd(as.Date(d, origin = "1970-01-01"))
  out$tuile_controle <- c(pixels = nrow(Tt), sans_serie = sum(is.na(kt)),
                          r0_egale_carte = sum(yy(Y$r0) == Tt$date_tuile, na.rm = TRUE),
                          carte_2019 = sum(Tt$date_tuile %/% 1000L == 19L),
                          r0_differente_hors_2019 = sum(yy(Y$r0) != Tt$date_tuile & Tt$date_tuile %/% 1000L != 19L, na.rm = TRUE))
  Tt$annee_carte <- Tt$date_tuile %/% 1000L + 2000L
  princ <- !is.na(Tt$objet)
  med_obj <- function(code, obj) tapply(code, obj, stats::median, na.rm = TRUE)
  objs <- sort(unique(Tt$objet[princ]))
  cmp <- data.frame(objet = objs,
    carte = as.numeric(med_obj(Tt$date_tuile[princ], Tt$objet[princ])[as.character(objs)]))
  for (r in c("R0", "R1", "R2", "R3")) {
    d <- ifelse(is.na(Y[[regles[[r]]]]), Y$r0, Y[[regles[[r]]]])
    code <- yy(d)
    cmp[[r]] <- as.numeric(med_obj(code[princ], Tt$objet[princ])[as.character(objs)])
  }
  cmp$npix <- as.integer(table(Tt$objet[princ])[as.character(objs)])
  out$objets <- cmp
  out$objets_resume <- sapply(c("carte", "R0", "R1", "R2", "R3"), function(r) c(
    objets = nrow(cmp), en_2019 = sum(cmp[[r]] %/% 1000L == 19L, na.rm = TRUE),
    pixels_en_2019 = sum(cmp$npix[which(cmp[[r]] %/% 1000L == 19L)], na.rm = TRUE)))
  out$objets_changent_2019 <- sapply(c("R1", "R2", "R3"), function(r)
    c(entrent_2019 = sum(cmp[[r]] %/% 1000L == 19L & cmp$R0 %/% 1000L != 19L, na.rm = TRUE),
      sortent_2019 = sum(cmp[[r]] %/% 1000L != 19L & cmp$R0 %/% 1000L == 19L, na.rm = TRUE)))
  out$pixels_par_annee <- sapply(c("R0", "R1", "R2", "R3"), function(r) {
    d <- ifelse(is.na(Y[[regles[[r]]]]), Y$r0, Y[[regles[[r]]]])
    table(factor(an(d[princ & Tt$annee_carte != 2019]), 2019:2025))
  })
  # Détection : le ratio de détection ne dépend pas de la date ; tous les pixels
  # datés de la tuile gardent un ratio.
  out$detection <- c(pixels_tuile = nrow(Tt), avec_ratio = sum(!is.na(Y$mdet)),
                     sans_ratio = sum(is.na(Y$mdet)))
  # Le reste de 026 (13 104 pixels), par situation à la date publiée : quelle règle traite quelle classe.
  p26 <- readRDS(file.path(M026, "pixels_026.rds"))
  X$classe_026 <- p26$classe_026[match(cib$idx, p26$idx)]
  reste <- which(X$groupe == "tardif_reste")
  out$reste_par_classe <- do.call(rbind, lapply(names(date_regle)[1:4], function(r) {
    e <- date_regle[[r]]$d - X$pub
    do.call(rbind, lapply(split(reste, X$classe_026[reste]), function(w) {
      data.frame(regle = r, classe = X$classe_026[w[1]], n = length(w), a15 = sum(abs(e[w]) <= 15),
                 a60 = sum(abs(e[w]) <= 60), precoce = sum(e[w] < -180), sans_date = sum(date_regle[[r]]$sans[w]))
    }))
  }))
  # Pareto des tardifs qui restent à plus de 60 j de la date publiée, par cause connue
  # (groupes de 024 ; situation de 026 pour le reste), sous chaque règle.
  cause <- ifelse(X$groupe == "tardif_reste", paste0("reste : ", X$classe_026), X$groupe)
  out$pareto_residuel <- do.call(cbind, lapply(names(date_regle)[1:4], function(r) {
    e <- date_regle[[r]]$d - X$pub
    table(cause[tarde & abs(e) > 60])
  }))
  colnames(out$pareto_residuel) <- names(date_regle)[1:4]
  # Stabilité : la même mesure sur les deux moitiés de la tuile (nord, sud), pixels communs.
  moitie <- ifelse(cib$cel <= stats::median(cib$cel), "nord", "sud")
  out$moities <- do.call(rbind, lapply(c("nord", "sud"), function(h) {
    do.call(rbind, lapply(names(date_regle)[1:4], function(r) {
      w <- moitie == h
      data.frame(moitie = h, regle = r, t(resume(date_regle[[r]]$d[w] - X$pub[w])))
    }))
  }))
  # Détection inchangée : le minimum du ratio de détection recalculé (commun aux règles)
  # égale le ratio.tif de la tuile, hors pixels de la passe 2019.
  rt <- terra::values(terra::rast(file.path(M026, "sorties", "tuiles", "30TXP", "ratio.tif")), mat = FALSE)
  out$ratio_tuile <- c(pixels = sum(!a19t), egaux_001 = sum(abs(Y$mdet - rt[Tt$cel])[!a19t] <= 0.006, na.rm = TRUE))
  saveRDS(out, file.path(DOSSIER, "mesures_027.rds"))
  options(width = 200)
  print(out$controle_r0); print(out$tuile_controle); print(out$detection)
  print(out$sans_date); print(out$part_2019); print(out$part_2019_publiee)
  print(out$objets_resume); print(out$objets_changent_2019); print(out$pixels_par_annee)
  print(out$devenir, digits = 4)
  print(out$reste_par_classe); print(out$ratio_tuile)
  print(out$pareto_residuel)
  print(out$moities, digits = 4)
  print(out$tab, digits = 4, row.names = FALSE)
}

# Étape 3 : tracés ----------------------------------------------------------------------------

if (ETAPE == "tracer") {
  R <- readRDS(file.path(DOSSIER, "regles_cellules.rds"))
  C <- readRDS(file.path(DOSSIER, "cibles.rds"))
  tr <- readRDS(file.path(M026, "pixels_traces.rds"))
  pts <- tr$pixels
  a_tracer <- rbind(c(398525, 6351825), c(398595, 6348385), c(394175, 6352425), c(394465, 6350145),
                    c(394475, 6350815), c(393725, 6349945), c(393975, 6349765))
  sel <- which(paste(round(pts$x), round(pts$y)) %in% paste(a_tracer[, 1], a_tracer[, 2]))
  cib <- C$cibles
  d_t <- file.path(DOSSIER, "traces"); dir.create(d_t, showWarnings = FALSE)
  lignes <- list()
  couleurs <- c(R0 = "red", R1 = "orange", R2 = "purple", R3 = "darkgreen")
  mois <- function(d) format(as.Date(d, origin = "1970-01-01"), "%Y-%m")
  for (i in sel) {
    ic <- match(pts$idx[i], cib$idx)
    r <- R[match(cib$cel[ic], R$cel), ]
    dr <- c(R0 = r$r0, R1 = ifelse(is.na(r$r1_300), r$r0, r$r1_300),
            R2 = ifelse(is.na(r$r3_345), r$r0, r$r3_345), R3 = ifelse(is.na(r$r3_300), r$r0, r$r3_300))
    pub <- as.numeric(pts$pub[i])
    lignes[[length(lignes) + 1L]] <- data.frame(x = round(pts$x[i]), y = round(pts$y[i]),
      classe = pts$classe_026[i], orbite = r$orbite, mois_publiee = format(pts$pub[i], "%Y-%m"),
      mois_R0 = mois(dr[["R0"]]), mois_R1 = mois(dr[["R1"]]), mois_R2 = mois(dr[["R2"]]), mois_R3 = mois(dr[["R3"]]),
      ecart_R0 = dr[["R0"]] - pub, ecart_R1 = dr[["R1"]] - pub, ecart_R2 = dr[["R2"]] - pub, ecart_R3 = dr[["R3"]] - pub)
    f <- file.path(d_t, sprintf("%d_%d.png", round(pts$x[i]), round(pts$y[i])))
    grDevices::png(f, width = 1500, height = 1000)
    op <- graphics::par(mfrow = c(length(tr$series), 1), mar = c(3, 4, 2, 2))
    for (o in names(tr$series)) {
      s <- tr$series[[o]]
      graphics::plot(s$dates, s$r_dat[i, ], type = "l", col = "grey50", ylim = c(-10, 6), ylab = "ratio (dB)", xlab = "",
                     main = sprintf("%s | x=%d y=%d | retenue : %s", o, round(pts$x[i]), round(pts$y[i]), r$orbite))
      graphics::lines(s$dates, s$r_det[i, ], col = "blue", lwd = 2)
      graphics::abline(h = c(TP, S_DATE), lty = c(2, 3))
      graphics::abline(v = pts$pub[i], col = "black", lwd = 3)
      for (n in names(dr)) graphics::abline(v = as.Date(dr[[n]], origin = "1970-01-01"), col = couleurs[[n]], lwd = 2, lty = 2)
      if (o == names(tr$series)[1]) graphics::legend("bottomleft", c("publiée", names(couleurs)), col = c("black", couleurs), lwd = 2, horiz = TRUE)
    }
    graphics::par(op); grDevices::dev.off()
  }
  tab <- do.call(rbind, lignes)
  saveRDS(tab, file.path(DOSSIER, "traces_027.rds"))
  print(tab, row.names = FALSE)
}
