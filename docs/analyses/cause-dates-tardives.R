# Mission 026 : cause non établie des dates tardives (suite de la mission 024)
# ---------------------------------------------------------------------------
# Script d'analyse reproductible, SANS modification du package. À lancer
# depuis la racine du dépôt :
#
#   Rscript docs/analyses/cause-dates-tardives.R <dossier> relever [cote_m]
#   Rscript docs/analyses/cause-dates-tardives.R <dossier> analyser <dates_v301.tif> <sorties_017> <sorties_024_premiere_detection>
#   Rscript docs/analyses/cause-dates-tardives.R <dossier> tracer
#   Rscript docs/analyses/cause-dates-tardives.R <dossier> persister <dates_v301.tif> <sorties_017>
#
#   <dossier> : dossier de travail HORS du dépôt.
#   relever   : relance nemetonsar_run() sur l'AOI pilote (mêmes AOI,
#               période, réglages, masque BD Forêt que la mission 017 ;
#               passe 1 en parallèle, un processus par orbite, mission 023)
#               en branchant rcr_compute() (utils::assignInNamespace) : pour
#               chaque bloc de la passe principale et chaque orbite, la
#               série filtrée (VH, dB) et les deux ratios (détection, xb =
#               Inf ; datation, xb_date = 5) à TOUTES les dates, rangés à la
#               date d_(i+1) (celle que rend le package), sont écrits en
#               entiers 16 bits (centièmes de dB) dans <dossier>/series/.
#               Le résultat du package n'est pas modifié. Contrôle à chaque
#               appel : le minimum du ratio de détection et la date de la
#               règle actuelle recalculés ici sont confrontés à
#               rcr_compute() (<dossier>/series/controle_*.txt).
#   analyser  : reprend les classes de la mission 024 (pixels tardifs,
#               « cause non établie »), lit pour chacun, orbite par orbite,
#               le ratio de détection autour de la date publiée par la
#               v3.0.1 et la date de premier passage sous tp ; questions 2
#               (8 acquisitions de fin d'hiver) et 3 (postes BD Forêt FF0,
#               FO0, lus par le WFS de la Géoplateforme). Chiffres agrégés
#               dans <dossier>/analyse_026.rds ; pixels à tracer dans
#               <dossier>/pixels_traces.rds.
#   tracer    : séries des pixels tirés (graine) par classe, depuis
#               <dossier>/series (pas de nouvelle lecture des images),
#               <dossier>/traces/*.png ; vignettes d'orthophoto par l'étape
#               « orthos » du script de la mission 024.
#   persister : (allers-retours 2/3 et 3/3) persistance aux 8 acquisitions
#               de fin d'hiver avec une base qui ne sert pas à la sélection :
#               VH moyen de ]X+60, X+240] moins VH moyen de [X-365, X-60[
#               PRIVÉ, pixel par pixel et par position, des 5 images valides
#               avant X (dénominateur du ratio de datation à X ; elles peuvent
#               tomber avant X-60 s'il y a un trou d'acquisition), et la même
#               mesure un an avant (Y = X-365, base privée des 5 images valides
#               avant Y) en témoin, depuis <dossier>/series (pas de nouvelle
#               lecture des images) ; la base de l'aller-retour 2/3 (sans
#               exclusion) est gardée pour mesurer l'écart, avec la part des
#               pixels dont la base a perdu au moins une image ; persistance
#               des pixels tracés à la date de la carte, même définition ;
#               l'ancienne base (5 images valides avant X) est recalculée
#               pixel par pixel pour mesurer le biais. Question 3 : pixels
#               FO0 et FF0 datés par l'une, l'autre ou les deux cartes.
#               Sortie : <dossier>/persistance_026.rds.
#
# La v3.0.1 est CC BY-NC 4.0 : l'extrait reste hors du dépôt ; les sorties
# qui en contiennent des valeurs de pixel restent dans <dossier>.
# Graine fixée.
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : Rscript docs/analyses/cause-dates-tardives.R <dossier> relever|analyser|tracer ...",
       call. = FALSE)
}
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
if (startsWith(DOSSIER, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de travail doit être hors du dépôt.", call. = FALSE)
}
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
set.seed(20261123L)

suppressMessages(pkgload::load_all(".", quiet = TRUE))
ns <- asNamespace("nemetonsar")

# AOI, période, réglages : ceux de pilote-landes.R (mission 017).
POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2025-09-30")
P <- parametres_sufosat()
TP <- seuils_db(P)[["tp"]]
D_SERIES <- file.path(DOSSIER, "series")
NA16 <- -32768L

aoi_pilote <- function(cote = COTE_M) {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                cote / 2, capstyle = "square")
}
grille_tuile <- function(cote = COTE_M) aoi_grille(aoi_preparer(aoi_pilote(cote), resolution_m = 10)$tuiles[1, ])

# Ratios d'une orbite, toutes dates (définition de rcr_compute(), écrite
# simplement, reprise du script de la mission 024) : par pixel, les deux
# ratios rangés à la colonne de d_(i+1), le minimum du ratio de détection et
# le rang du minimum du ratio de datation (règle actuelle).
ratios_series <- function(x, dates, p) {
  npix <- nrow(x)
  nt <- ncol(x)
  x[!is.na(x) & x <= 0] <- NA_real_
  xa <- p$xa
  admise <- dates >= as.Date(sprintf("%d-01-01", p$annee_noyau + 1L))
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
  k_min_dat <- rep(NA_integer_, npix)
  m_dat <- rep(Inf, npix)
  m_det <- rep(Inf, npix)
  r_det <- r_dat <- matrix(NA_real_, npix, nt)
  for (k in seq_len(max(max(total) - xa, 0L))) {
    pix <- which(total >= k + xa)
    if (length(pix) == 0L) next
    pix <- pix[admise[pos[pix, k]]]
    if (length(pix) == 0L) next
    ck <- cum[pix, k]
    ma <- (cum[pix, k + xa] - ck) / xa
    nb <- min(k, p$xb_date)
    avant <- if (k - nb == 0L) 0 else cum[pix, k - nb]
    rdet <- 10 * log10(ma / (ck / k))
    rdat <- 10 * log10(ma / ((ck - avant) / nb))
    mieux <- rdat < m_dat[pix]
    m_dat[pix[mieux]] <- rdat[mieux]
    k_min_dat[pix[mieux]] <- k
    m_det[pix] <- pmin(m_det[pix], rdet)
    col <- pos[cbind(pix, k + 1L)]
    r_det[cbind(pix, col)] <- rdet
    r_dat[cbind(pix, col)] <- rdat
  }
  date_min <- rep(NA_integer_, npix)
  ok <- which(!is.na(k_min_dat))
  date_min[ok] <- date_vers_yyddd(dates)[pos[cbind(ok, k_min_dat[ok] + 1L)]]
  m_det[!is.finite(m_det)] <- NA_real_
  list(r_det = r_det, r_dat = r_dat, m_det = m_det, date_min = date_min)
}

vers16 <- function(v) {
  v <- round(v * 100)
  v[!is.na(v) & v > 32767] <- 32767
  v[!is.na(v) & v < -32767] <- -32767
  v[is.na(v)] <- NA16
  as.integer(v)
}
de16 <- function(v) { v <- as.numeric(v); v[v == NA16] <- NA_real_; v / 100 }

# Étape 1 : relevé des séries -----------------------------------------------------

if (ETAPE == "relever") {
  dir.create(D_SERIES, showWarnings = FALSE, recursive = TRUE)
  # Jeton SAS neuf à chaque lecture de bande (contournement de la mission 024,
  # tant que la mission 025 n'est pas faite).
  s1_lire_origine <- get("s1_lire", envir = ns)
  utils::assignInNamespace("s1_lire", function(...) {
    jetons <- get("ms_token", envir = asNamespace("rstac"))
    rm(list = ls(jetons, all.names = TRUE), envir = jetons)
    s1_lire_origine(...)
  }, "nemetonsar")
  # [cote_m] : AOI réduite, pour un essai du branchement seulement.
  COTE <- if (length(args) >= 3L) as.numeric(args[3]) else COTE_M
  G <- grille_tuile(COTE)
  NL <- terra::nrow(G); NC <- terra::ncol(G); YMAX <- terra::ymax(G); RES <- terra::res(G)[2]
  RF <- (P$fenetre_filtre - 1L) %/% 2L
  # État courant, lu par les processus enfants (hérité au fork) :
  # grille et orbites de l'appel de detecter_blocs(), bloc de la passe 1.
  ETAT <- new.env()
  db_origine <- get("detecter_blocs", envir = ns)
  utils::assignInNamespace("detecter_blocs", function(orbites, dates, ...) {
    ETAT$decalage <- as.integer(round((YMAX - terra::ymax(orbites[[1]])) / RES))
    ETAT$nl_grille <- terra::nrow(orbites[[1]])
    ETAT$dates <- dates
    ETAT$noms <- names(orbites)
    db_origine(orbites, dates, ...)
  }, "nemetonsar")
  bb_origine <- get("bande_bordee", envir = ns)
  utils::assignInNamespace("bande_bordee", function(debut, n, bord, nl) {
    lu <- bb_origine(debut, n, bord, nl)
    ETAT$lu <- lu
    lu
  }, "nemetonsar")
  rcr_origine <- get("rcr_compute", envir = ns)
  utils::assignInNamespace("rcr_compute", function(serie, dates, parametres = parametres_sufosat()) {
    res <- rcr_origine(serie, dates, parametres)
    if (max(dates) < as.Date("2020-06-01")) return(res)   # passe de 2019 : non relevée
    k <- which(vapply(ETAT$dates, function(d) identical(d, dates), logical(1)))
    orb <- if (length(k) == 1L) ETAT$noms[k] else paste0("orbite_", format(dates[1]), "_", length(dates))
    d <- dim(serie)
    nc <- d[1]; n <- d[2]; nt <- d[3]
    lu <- ETAT$lu
    stopifnot(n == lu$n, nc == NC)
    # Lignes de la tuile couvertes par ce bloc ; on ne garde que le centre
    # du bloc (lu$centre) et, dans la bande de lecture, ni sa bordure haute
    # ni sa bordure basse (sauf au bord de la tuile) : chaque ligne de la
    # tuile est relevée une fois, là où le package la garde.
    lig_grille <- lu$debut - 1L + lu$centre
    lig_tuile <- ETAT$decalage + lig_grille
    garder <- (lig_grille > RF | ETAT$decalage == 0L) &
      (lig_grille <= ETAT$nl_grille - RF | ETAT$decalage + ETAT$nl_grille == NL)
    lignes <- lu$centre[garder]
    if (length(lignes) == 0L) return(res)
    x <- serie[, lignes, , drop = FALSE]
    dim(x) <- c(nc * length(lignes), nt)
    r <- ratios_series(x, dates, parametres)
    # Contrôle contre rcr_compute() sur les mêmes pixels.
    rm_db <- as.vector(res$ratio_min_db[, lignes, drop = FALSE])
    dm <- as.vector(res$date_min[, lignes, drop = FALSE])
    a <- !is.na(rm_db)
    id <- sprintf("%s_l%04d", orb, lig_tuile[garder][1])
    cat(id, sum(a), sum(a & !is.na(r$date_min) & r$date_min == dm),
        signif(max(c(0, abs(r$m_det[a] - rm_db[a]))), 3),
        sum(xor(a, !is.na(r$m_det))), "\n",
        file = file.path(D_SERIES, paste0("controle_", id, ".txt")))
    vh <- x
    vh[!is.na(vh) & vh <= 0] <- NA_real_
    con <- file(file.path(D_SERIES, paste0(id, ".bin")), "wb")
    writeBin(vers16(10 * log10(vh)), con, size = 2L)
    writeBin(vers16(r$r_det), con, size = 2L)
    writeBin(vers16(r$r_dat), con, size = 2L)
    close(con)
    saveRDS(list(orbite = orb, dates = dates, lignes_tuile = lig_tuile[garder], nc = nc,
                 npix = nrow(x), nt = nt),
            file.path(D_SERIES, paste0(id, ".rds")))
    res
  }, "nemetonsar")
  t0 <- Sys.time()
  res <- nemetonsar_run(aoi_pilote(COTE), DEBUT, FIN, dossier = file.path(DOSSIER, "sorties"),
                        bdforet = "wfs", parametres = P, hauteur_bande = if (COTE < COTE_M) 40L else 512L)
  t1 <- Sys.time()
  saveRDS(list(res = res, duree_h = as.numeric(difftime(t1, t0, units = "hours"))),
          file.path(DOSSIER, "execution.rds"))
  print(res$tuiles)
  cat("Durée :", format(round(difftime(t1, t0, units = "mins"), 1)), "\n")
}

# Lecture des séries relevées, pour des cellules de la tuile -----------------------

# Rend, par orbite, les dates et trois matrices (pixels x dates) : vh (dB),
# r_det, r_dat ; `cellules` : cellules de la grille de la tuile. Si
# `par_date` est une fonction(orbite, dates, vh, r_det, r_dat, cellules_bloc),
# elle est aussi appelée sur chaque bloc entier (agrégats).
lire_series <- function(cellules, par_date = NULL) {
  metas <- list.files(D_SERIES, pattern = "\\.rds$", full.names = TRUE)
  out <- list()
  agg <- list()
  for (f in metas) {
    m <- readRDS(f)
    con <- file(sub("\\.rds$", ".bin", f), "rb")
    lire <- function() matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
    vh <- lire(); rdet <- lire(); rdat <- lire()
    close(con)
    cel_bloc <- (rep(m$lignes_tuile, each = m$nc) - 1L) * m$nc + rep(seq_len(m$nc), length(m$lignes_tuile))
    o <- m$orbite
    if (is.null(out[[o]])) {
      out[[o]] <- list(dates = m$dates,
                       vh = matrix(NA_real_, length(cellules), m$nt),
                       r_det = matrix(NA_real_, length(cellules), m$nt),
                       r_dat = matrix(NA_real_, length(cellules), m$nt))
    }
    j <- match(cellules, cel_bloc)
    ok <- which(!is.na(j))
    if (length(ok)) {
      out[[o]]$vh[ok, ] <- de16(vh[j[ok], , drop = FALSE])
      out[[o]]$r_det[ok, ] <- de16(rdet[j[ok], , drop = FALSE])
      out[[o]]$r_dat[ok, ] <- de16(rdat[j[ok], , drop = FALSE])
    }
    if (is.function(par_date)) agg[[length(agg) + 1L]] <- par_date(o, m$dates, vh, rdet, rdat, cel_bloc)
  }
  list(series = out, agregats = agg)
}

# Classes de la mission 024 (reprises de son script) --------------------------------

lire_couple <- function(sorties, reference) {
  rec_d <- terra::rast(file.path(sorties, "dates.tif"))
  rec_o <- terra::rast(file.path(sorties, "objets.tif"))
  ref <- terra::project(terra::rast(reference), rec_d, method = "near")
  dans <- !is.na(terra::values(terra::rasterize(aoi_pilote(), rec_d, field = 1), mat = FALSE))
  vr <- terra::values(rec_d, mat = FALSE)
  vo <- terra::values(rec_o, mat = FALSE)
  vp <- terra::values(ref, mat = FALSE)
  vp[vp == 0] <- NA
  list(grille = rec_d, ref_rast = ref, dans = dans, rec = vr, obj = vo, ref = vp)
}
ecart_j <- function(a, b) as.numeric(yyddd_vers_date(a) - yyddd_vers_date(b))

# Mesures sur la série d'un pixel et d'une orbite --------------------------------------

# Moyenne linéaire des images valides d'indices `i`, en dB.
moy_db <- function(v, i) { w <- v[i]; w <- w[!is.na(w)]; if (!length(w)) NA_real_ else 10 * log10(mean(10^(w / 10))) }
# Persistance de la chute à la date X : moyenne (lin.) des images de ]X+60 j,
# X+240 j] rapportée aux 5 dernières images valides avant X (dB).
persistance <- function(vh, dates, X) {
  if (is.na(X)) return(NA_real_)
  av <- which(dates < X & !is.na(vh)); av <- utils::tail(av, 5L)
  ap <- which(dates > X + 60 & dates <= X + 240)
  if (length(av) < 3L) return(NA_real_)
  moy_db(vh, ap) - moy_db(vh, av)
}

WINDOW <- 15
PROCHE_DB <- 1

if (ETAPE == "analyser") {
  reference <- normalizePath(args[3]); base <- normalizePath(args[4]); pdet_dir <- normalizePath(args[5])
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  out <- list(seuils = c(tp = TP, fenetre_j = WINDOW, proche_db = PROCHE_DB))
  # Contrôles du relevé.
  ctrl <- do.call(rbind, lapply(list.files(D_SERIES, "^controle_", full.names = TRUE), function(f) {
    v <- scan(f, what = "", quiet = TRUE)
    data.frame(id = v[1], pixels = as.integer(v[2]), dates_identiques = as.integer(v[3]),
               ecart_ratio_max = as.numeric(v[4]), presence_differente = as.integer(v[5]))
  }))
  out$controle <- ctrl
  out$controle_total <- colSums(ctrl[, -1])
  # Sorties du relevé contre celles de la mission 017 (même carte ?).
  m017 <- terra::values(terra::rast(file.path(base, "dates.tif")), mat = FALSE)
  m026 <- terra::values(terra::rast(file.path(DOSSIER, "sorties", "dates.tif")), mat = FALSE)
  out$carte_identique_017 <- c(cellules = length(m017), datees_017 = sum(!is.na(m017)),
                               datees_026 = sum(!is.na(m026)),
                               differentes = sum(xor(is.na(m017), is.na(m026)) |
                                                   (!is.na(m017) & !is.na(m026) & m017 != m026)))

  # Classes de la mission 024.
  b <- lire_couple(base, reference)
  commun_b <- b$dans & !is.na(b$rec) & !is.na(b$ref)
  e_b <- ecart_j(b$rec[commun_b], b$ref[commun_b])
  idx_tardif <- which(commun_b)[e_b > 180]
  idx_proche <- which(commun_b)[abs(e_b) <= 15]
  pdet <- lire_couple(pdet_dir, reference)
  e_pd <- ecart_j(pdet$rec[idx_tardif], pdet$ref[idx_tardif])
  annee_ref <- as.integer(b$ref %/% 1000L) + 2000L
  r18 <- annee_ref[idx_tardif] == 2018L
  classe <- ifelse(r18, "debut_serie",
            ifelse(!is.na(e_pd) & abs(e_pd) <= 15, "regle_15j",
            ifelse(!is.na(e_pd) & abs(e_pd) <= 60, "regle_60j",
            ifelse(is.na(e_pd), "plus_datee", "reste"))))
  out$pareto_024 <- table(classe)
  idx_reste <- idx_tardif[classe == "reste"]

  # Pixels étudiés : tardifs (toutes classes) et, en témoin, pixels à date
  # retrouvée (|écart| <= 15 j) ; cellule de la tuile.
  G <- grille_tuile()
  idx <- c(idx_tardif, idx_proche)
  grp <- c(paste0("tardif_", classe), rep("temoin_retrouve", length(idx_proche)))
  xy <- terra::xyFromCell(b$grille, idx)
  xy_utm <- terra::crds(terra::project(terra::vect(xy, crs = "EPSG:2154"), terra::crs(G)))
  cel <- terra::cellFromXY(G, xy_utm)
  pub <- yyddd_vers_date(b$ref[idx])
  date_carte <- yyddd_vers_date(b$rec[idx])
  date_pdet <- yyddd_vers_date(pdet$rec[idx])
  ratio_carte <- terra::values(terra::rast(file.path(base, "ratio.tif")), mat = FALSE)[idx]

  # Agrégats par date (question 2) : pixels forêt de l'AOI (masque de la
  # tuile, après la correction 2019), et parmi eux les pixels sans coupe ni
  # dans la carte recalculée ni dans la v3.0.1.
  masque <- terra::values(terra::rast(file.path(DOSSIER, "sorties", "tuiles", "30TXP", "masque.tif")), mat = FALSE) %in% 1
  obj_t <- terra::values(terra::rast(file.path(DOSSIER, "sorties", "tuiles", "30TXP", "objets.tif")), mat = FALSE)
  ref_t <- terra::values(terra::project(terra::rast(reference), G, method = "near"), mat = FALSE)
  sans_coupe <- masque & is.na(obj_t) & (is.na(ref_t) | ref_t == 0)
  ref_t[!is.na(ref_t) & ref_t == 0] <- NA
  date_ref_t <- yyddd_vers_date(ref_t)
  # Les 8 acquisitions qui portent le plus de pixels tardifs (carte actuelle).
  est_tardif <- startsWith(grp, "tardif_")
  t8 <- sort(table(format(date_carte[est_tardif])), decreasing = TRUE)[1:8]
  d8 <- as.Date(names(t8))
  cel_t8 <- lapply(d8, function(d) cel[est_tardif & date_carte == d])
  BORNES <- seq(-15, 10, by = 0.1)
  par_date <- function(o, dates, vh, rdet, rdat, cel_bloc) {
    f <- masque[cel_bloc]; s <- sans_coupe[cel_bloc]
    cpt <- function(m, sel) colSums(m[sel, , drop = FALSE] != NA16 & m[sel, , drop = FALSE] <= round(TP * 100))
    val <- function(m, sel) colSums(m[sel, , drop = FALSE] != NA16)
    # Forêt déjà coupée (date publiée par la v3.0.1 plus de 60 j avant la date).
    dc <- date_ref_t[cel_bloc]
    deja_n <- deja_tp <- numeric(length(dates))
    for (t in seq_along(dates)) {
      w <- f & !is.na(dc) & dc < dates[t] - 60
      deja_n[t] <- sum(rdat[w, t] != NA16); deja_tp[t] <- sum(rdat[w, t] != NA16 & rdat[w, t] <= round(TP * 100))
    }
    # Aux 8 dates : persistance (VH moyen de ]D+60, D+240] moins VH moyen des
    # 5 images précédentes, en linéaire, NA ignorés) par groupe, en histogramme.
    pers <- list()
    for (j in which(d8 %in% dates)) {
      t <- match(d8[j], dates)
      lin <- function(cols) { m <- vh[, cols, drop = FALSE]; m <- ifelse(m == NA16, NA, 10^(m / 1000)); rowMeans(m, na.rm = TRUE) }
      av <- lin(max(1, t - 5):(t - 1)); ap <- lin(which(dates > dates[t] + 60 & dates <= dates[t] + 240))
      pr <- 10 * log10(ap / av)
      grp8 <- list(sans_coupe = s, deja_coupee = f & !is.na(dc) & dc < dates[t] - 60,
                   tardifs_a_D = cel_bloc %in% cel_t8[[j]])
      for (g in names(grp8)) {
        w <- grp8[[g]] & is.finite(pr)
        pers[[length(pers) + 1L]] <- data.frame(date = d8[j], groupe = g, n = sum(w),
          dat_tp = sum(w & rdat[, t] != NA16 & rdat[, t] <= round(TP * 100)),
          pers_tp = sum(w & pr <= TP),
          classe = seq_along(BORNES[-1]),
          h = tabulate(findInterval(pmin(pmax(pr[w], -14.99), 9.99), BORNES), length(BORNES) - 1L))
      }
    }
    list(dates = data.frame(orbite = o, date = dates,
               foret_n = val(rdat, f), foret_dat_tp = cpt(rdat, f), foret_det_tp = cpt(rdet, f),
               sans_n = val(rdat, s), sans_dat_tp = cpt(rdat, s), sans_det_tp = cpt(rdet, s),
               deja_n = deja_n, deja_dat_tp = deja_tp),
         pers = do.call(rbind, pers))
  }
  lu <- lire_series(cel, par_date)
  S <- lu$series
  orbs <- names(S)
  agg <- do.call(rbind, lapply(lu$agregats, `[[`, "dates"))
  agg <- stats::aggregate(. ~ orbite + date, data = agg, FUN = sum)
  agg$deja_dat_part <- agg$deja_dat_tp / agg$deja_n
  ph <- do.call(rbind, lapply(lu$agregats, `[[`, "pers"))
  ph <- stats::aggregate(cbind(n, dat_tp, pers_tp, h) ~ date + groupe + classe, data = ph, FUN = sum)
  # Médiane de la persistance par date et groupe, depuis l'histogramme (0,1 dB).
  out$q2_persistance <- do.call(rbind, lapply(split(ph, list(ph$date, ph$groupe), drop = TRUE), function(z) {
    z <- z[order(z$classe), ]; cs <- cumsum(z$h)
    data.frame(date = z$date[1], groupe = z$groupe[1], n = z$n[1], part_dat_tp = z$dat_tp[1] / z$n[1],
               part_pers_tp = z$pers_tp[1] / z$n[1],
               mediane_pers_db = BORNES[z$classe[which(cs >= cs[length(cs)] / 2)[1]]] + 0.05)
  }))
  agg$foret_dat_part <- agg$foret_dat_tp / agg$foret_n
  agg$foret_det_part <- agg$foret_det_tp / agg$foret_n
  agg$sans_dat_part <- agg$sans_dat_tp / agg$sans_n
  agg$sans_det_part <- agg$sans_det_tp / agg$sans_n
  out$par_date <- agg
  out$forets <- c(foret = sum(masque), sans_coupe = sum(sans_coupe))

  # Mesures par pixel et par orbite.
  n <- length(idx)
  mes <- list()
  for (o in orbs) {
    D <- S[[o]]$dates
    rd <- S[[o]]$r_det
    rt <- S[[o]]$r_dat
    fen <- abs(outer(as.numeric(pub), as.numeric(D), "-")) <= WINDOW
    fen60 <- abs(outer(as.numeric(pub), as.numeric(D), "-")) <= 60
    mn <- function(m, w) { m[!w] <- NA; r <- suppressWarnings(apply(m, 1, min, na.rm = TRUE)); r[!is.finite(r)] <- NA; r }
    premier <- function(m) { z <- !is.na(m) & m <= TP; h <- rowSums(z) > 0; d <- D[max.col(z, ties.method = "first")]; d[!h] <- NA; d }
    w_apres <- outer(as.numeric(pub), as.numeric(D), function(a, d) d >= a - WINDOW)
    rd_ap <- rd; rd_ap[!w_apres] <- NA
    m_det <- suppressWarnings(apply(rd, 1, min, na.rm = TRUE)); m_det[!is.finite(m_det)] <- NA
    k_dat <- apply(rt, 1, function(v) if (all(is.na(v))) NA_integer_ else which.min(v))
    mes[[o]] <- data.frame(
      n_fen = rowSums(fen & !is.na(rd)),
      rdet_fen = mn(rd, fen), rdat_fen = mn(rt, fen), rdet_fen60 = mn(rd, fen60),
      premier_det = premier(rd), premier_det_apres = premier(rd_ap),
      m_det = m_det, date_min_dat = D[k_dat],
      pers_pub = vapply(seq_len(n), function(i) persistance(S[[o]]$vh[i, ], D, pub[i]), 0),
      vh_avant_pub = vapply(seq_len(n), function(i) {
        a <- utils::tail(which(D < pub[i] & !is.na(S[[o]]$vh[i, ])), 5L); moy_db(S[[o]]$vh[i, ], a) }, 0),
      stringsAsFactors = FALSE)
  }
  # Orbite retenue : ratio de détection minimal (combinaison « minimum »).
  M <- sapply(mes, function(m) m$m_det)
  ret <- apply(M, 1, function(v) if (all(is.na(v))) NA_integer_ else which.min(v))
  get_ret <- function(ch) vapply(seq_len(n), function(i) if (is.na(ret[i])) NA_real_ else as.numeric(mes[[ret[i]]][[ch]][i]), 0)
  tab <- data.frame(idx = idx, groupe = grp, cel = cel, pub = pub, date_carte = date_carte,
                    date_pdet = date_pdet, ratio_carte = ratio_carte, orbite_ret = orbs[ret],
                    m_det_ret = get_ret("m_det"),
                    date_min_dat_ret = as.Date(get_ret("date_min_dat"), origin = "1970-01-01"),
                    premier_ret = as.Date(get_ret("premier_det"), origin = "1970-01-01"),
                    rdet_fen_ret = get_ret("rdet_fen"), rdat_fen_ret = get_ret("rdat_fen"),
                    n_fen_ret = get_ret("n_fen"), rdet_fen60_ret = get_ret("rdet_fen60"),
                    pers_pub_ret = get_ret("pers_pub"), vh_avant_pub_ret = get_ret("vh_avant_pub"))
  # Meilleure des autres orbites, dans la fenêtre.
  for (ch in c("rdet_fen", "rdat_fen")) {
    A <- sapply(mes, function(m) m[[ch]])
    tab[[paste0(ch, "_autre")]] <- vapply(seq_len(n), function(i) {
      v <- A[i, -ret[i]]; if (is.na(ret[i]) || all(is.na(v))) NA_real_ else min(v, na.rm = TRUE) }, 0)
    tab[[paste0(ch, "_toutes")]] <- suppressWarnings(apply(A, 1, min, na.rm = TRUE))
    tab[[paste0(ch, "_toutes")]][!is.finite(tab[[paste0(ch, "_toutes")]])] <- NA
  }
  tab$pers_carte_ret <- vapply(seq_len(n), function(i) {
    if (is.na(ret[i])) NA_real_ else persistance(S[[ret[i]]]$vh[i, ], S[[ret[i]]]$dates, tab$date_carte[i]) }, 0)
  # Contrôles d'appariement : orbite retenue et date de la règle actuelle.
  out$appariement <- c(pixels = n, sans_serie = sum(is.na(ret)),
                       ratio_egal_001 = sum(abs(tab$m_det_ret - tab$ratio_carte) <= 0.006, na.rm = TRUE),
                       date_carte_egale = sum(tab$date_min_dat_ret == tab$date_carte, na.rm = TRUE))

  # Classement des pixels (exclusif, dans cet ordre), autour de la date publiée P :
  cl <- with(tab, ifelse(is.na(orbite_ret) | n_fen_ret == 0, "pas_d_image",
           ifelse(rdet_fen_ret <= TP, ifelse(!is.na(premier_ret) & premier_ret < pub - 60,
                                             "sous_tp_a_P_mais_passage_anterieur", "sous_tp_a_P_orbite_retenue"),
           ifelse(!is.na(rdet_fen_autre) & rdet_fen_autre <= TP, "sous_tp_a_P_autre_orbite",
           ifelse(rdet_fen_toutes <= TP + PROCHE_DB, "proche_du_seuil_a_P",
                  "loin_du_seuil_a_P")))))
  tab$classe_026 <- cl
  tab$premier_apres_P <- as.numeric(tab$premier_ret - tab$pub)
  tab$mois_carte <- as.integer(format(tab$date_carte, "%m"))
  tab$mois_premier <- as.integer(format(tab$premier_ret, "%m"))
  out$classes <- table(groupe = tab$groupe, classe = tab$classe_026)
  # Distributions par groupe.
  q <- function(v) stats::quantile(v, c(0.1, 0.25, 0.5, 0.75, 0.9), na.rm = TRUE)
  out$distrib <- lapply(split(tab, tab$groupe), function(t) list(
    n = nrow(t),
    rdet_fen_ret = q(t$rdet_fen_ret), rdet_fen_toutes = q(t$rdet_fen_toutes),
    rdat_fen_toutes = q(t$rdat_fen_toutes),
    m_det_ret = q(t$m_det_ret), pers_pub = q(t$pers_pub_ret), pers_carte = q(t$pers_carte_ret),
    vh_avant_pub = q(t$vh_avant_pub_ret),
    part_carte_plus_persistante = mean(t$pers_carte_ret < t$pers_pub_ret - 1, na.rm = TRUE),
    part_mois_carte_fev_mars = mean(t$mois_carte %in% 2:3),
    part_pers_pub_tp = mean(t$pers_pub_ret <= TP, na.rm = TRUE),
    part_pers_carte_tp = mean(t$pers_carte_ret <= TP, na.rm = TRUE),
    premier_moins_P = q(t$premier_apres_P),
    rdet_fen60_sous_tp = mean(t$rdet_fen60_ret <= TP, na.rm = TRUE)))
  # Le reste, détaillé : premier passage après P (classes de jours), mois
  # du premier passage, persistance à P et à la date de la carte.
  rr <- tab[tab$groupe == "tardif_reste", ]
  out$reste_detail <- list(
    par_classe = lapply(split(rr, rr$classe_026), function(t) list(
      n = nrow(t),
      ecart_premier = table(cut(t$premier_apres_P, c(-Inf, -60, 60, 180, 365, Inf))),
      mois_premier = table(factor(t$mois_premier, 1:12)),
      mois_carte = table(factor(t$mois_carte, 1:12)),
      pers_pub_tp = c(oui = sum(t$pers_pub_ret <= TP, na.rm = TRUE), non = sum(t$pers_pub_ret > TP, na.rm = TRUE),
                      na = sum(is.na(t$pers_pub_ret))),
      pers_carte_tp = c(oui = sum(t$pers_carte_ret <= TP, na.rm = TRUE), non = sum(t$pers_carte_ret > TP, na.rm = TRUE),
                        na = sum(is.na(t$pers_carte_ret))),
      annee_pub = table(format(t$pub, "%Y")))))

  # Question 2 : les 8 acquisitions de fin d'hiver (carte actuelle).
  ta <- tab[startsWith(tab$groupe, "tardif_"), ]
  q2 <- do.call(rbind, lapply(seq_along(d8), function(j) {
    a <- agg[agg$date == d8[j], ]
    o <- a$orbite[1]
    ao <- agg[agg$orbite == o & agg$date >= as.Date("2019-02-01"), ]
    t <- ta[ta$date_carte == d8[j], ]
    data.frame(date = d8[j], orbite = o, tardifs = as.integer(t8[j]),
               part_tardifs = as.numeric(t8[j]) / nrow(ta),
               foret_dat_part = a$foret_dat_part[1], sans_dat_part = a$sans_dat_part[1],
               sans_det_part = a$sans_det_part[1], deja_dat_part = a$deja_dat_part[1],
               mediane_deja_dat_orbite = stats::median(ao$deja_dat_part, na.rm = TRUE),
               mediane_sans_dat_orbite = stats::median(ao$sans_dat_part, na.rm = TRUE),
               q90_sans_dat_orbite = stats::quantile(ao$sans_dat_part, 0.9, na.rm = TRUE),
               tardifs_persistants = mean(t$pers_carte_ret <= TP, na.rm = TRUE),
               tardifs_classe_reste = mean(t$groupe == "tardif_reste"))
  }))
  out$q2_8_dates <- q2
  out$q2_part_8_dates <- sum(t8) / nrow(ta)
  # Rang des 8 dates parmi toutes les dates de leur orbite (part « sans coupe »).
  out$q2_rang <- vapply(seq_along(d8), function(j) {
    o <- q2$orbite[j]; ao <- agg[agg$orbite == o & agg$date >= as.Date("2019-02-01"), ]
    rank(-ao$sans_dat_part)[ao$date == d8[j]] }, 0)
  out$q2_mois <- stats::aggregate(sans_dat_part ~ mois, FUN = stats::median, na.rm = TRUE,
                                  data = transform(agg[agg$date >= as.Date("2019-02-01"), ],
                                                   mois = as.integer(format(date, "%m"))))

  # Question 3 : postes BD Forêt FF0, FO0 (WFS, rastérisation au centre).
  lu_bdf <- ns$bdforet_lire("wfs", b$grille)
  v <- lu_bdf$v
  champ <- names(v)[tolower(names(v)) == "code_tfv"]
  v$code <- trimws(as.character(v[[champ]][[1]]))
  codes <- sort(unique(v$code))
  v$k <- match(v$code, codes)
  rk <- terra::rasterize(v, b$grille, field = "k", touches = FALSE)
  code_px <- codes[terra::values(rk, mat = FALSE)]
  dans <- b$dans
  tfv_groupe <- function(cells) {
    cd <- code_px[cells]
    c(n = length(cells), FF0 = sum(cd %in% "FF0"), FO0 = sum(cd %in% "FO0"),
      autre_foret = sum(!is.na(cd) & !cd %in% c("FF0", "FO0", "LA4", "LA6")),
      lande = sum(cd %in% c("LA4", "LA6")), sans_poste = sum(is.na(cd)))
  }
  out$q3 <- rbind(
    aoi = tfv_groupe(which(dans)),
    v301_aoi = tfv_groupe(which(dans & !is.na(b$ref))),
    recalcul_aoi = tfv_groupe(which(dans & !is.na(b$rec))),
    communs = tfv_groupe(which(commun_b)),
    retrouves = tfv_groupe(idx_proche),
    tardifs = tfv_groupe(idx_tardif),
    t(sapply(split(idx_tardif, classe), tfv_groupe)),
    t(sapply(split(rr$idx, rr$classe_026), tfv_groupe)))
  out$q3_source <- lu_bdf$source
  out$q3_codes_aoi <- table(code_px[which(dans)], useNA = "ifany")
  tab$tfv <- code_px[tab$idx]

  # Pixels à tracer : 2 par classe du reste et 2 témoins, tirés (graine).
  tire <- function(g, k = 2L) { i <- which(g); if (length(i) <= k) i else sample(i, k) }
  sel <- c(unlist(lapply(sort(unique(rr$classe_026)), function(c0) {
             tire(tab$groupe == "tardif_reste" & tab$classe_026 == c0) })),
           tire(tab$groupe == "temoin_retrouve"))
  pts <- tab[sel, ]
  pts$x <- xy[sel, 1]; pts$y <- xy[sel, 2]
  saveRDS(list(pixels = pts, series = lapply(S, function(s) list(dates = s$dates,
            vh = s$vh[sel, , drop = FALSE], r_det = s$r_det[sel, , drop = FALSE],
            r_dat = s$r_dat[sel, , drop = FALSE]))), file.path(DOSSIER, "pixels_traces.rds"))
  saveRDS(tab, file.path(DOSSIER, "pixels_026.rds"))  # valeurs de pixel : hors dépôt
  saveRDS(out, file.path(DOSSIER, "analyse_026.rds"))
  str(out, max.level = 2)
}

# Étape 4 (allers-retours 2/3 et 3/3) : persistance sans biais de sélection ---------------

if (ETAPE == "persister") {
  reference <- normalizePath(args[3]); base <- normalizePath(args[4])
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  a26 <- readRDS(file.path(DOSSIER, "analyse_026.rds"))
  tab <- readRDS(file.path(DOSSIER, "pixels_026.rds"))
  d8 <- a26$q2_8_dates$date; o8 <- a26$q2_8_dates$orbite
  G <- grille_tuile()
  masque <- terra::values(terra::rast(file.path(DOSSIER, "sorties", "tuiles", "30TXP", "masque.tif")), mat = FALSE) %in% 1
  obj_t <- terra::values(terra::rast(file.path(DOSSIER, "sorties", "tuiles", "30TXP", "objets.tif")), mat = FALSE)
  ref_t <- terra::values(terra::project(terra::rast(reference), G, method = "near"), mat = FALSE)
  sans_coupe <- masque & is.na(obj_t) & (is.na(ref_t) | ref_t == 0)
  ref_t[!is.na(ref_t) & ref_t == 0] <- NA
  date_ref_t <- yyddd_vers_date(ref_t)
  N_BASE_MIN <- 5L; N_APRES_MIN <- 3L
  # Moyenne linéaire (dB) des colonnes `cols` ; NA si moins de `nmin` images valides.
  moy_cols <- function(lin, cols, nmin) {
    if (!length(cols)) return(rep(NA_real_, nrow(lin)))
    m <- lin[, cols, drop = FALSE]
    k <- rowSums(!is.na(m)); r <- 10 * log10(rowMeans(m, na.rm = TRUE)); r[k < nmin] <- NA; r
  }
  # Moyenne des 5 dernières images VALIDES avant X (ancienne base, définition du rapport).
  moy_5_valides <- function(lin, dates, X) {
    s <- numeric(nrow(lin)); k <- integer(nrow(lin))
    for (t in rev(which(dates < X))) {
      v <- !is.na(lin[, t]) & k < 5L
      s[v] <- s[v] + lin[v, t]; k[v] <- k[v] + 1L
      if (all(k >= 5L)) break
    }
    r <- 10 * log10(s / k); r[k < 3L] <- NA; r
  }
  apres <- function(lin, dates, X) moy_cols(lin, which(dates > X + 60 & dates <= X + 240), N_APRES_MIN)
  base365 <- function(lin, dates, X) moy_cols(lin, which(dates >= X - 365 & dates < X - 60), N_BASE_MIN)
  # Aller-retour 3/3 : base [X-365, X-60[ privée, pixel par pixel et par
  # position, des 5 images valides avant X (celles du dénominateur du ratio de
  # datation à X). Rend la base (NA si moins de N_BASE_MIN images restent) et
  # le nombre d'images retirées par pixel.
  base365_hors5 <- function(lin, dates, X) {
    cols <- which(dates >= X - 365 & dates < X - 60)
    if (!length(cols)) return(list(v = rep(NA_real_, nrow(lin)), nexcl = integer(nrow(lin))))
    excl <- matrix(FALSE, nrow(lin), length(cols)); k <- integer(nrow(lin))
    for (t in rev(which(dates < X))) {
      v <- !is.na(lin[, t]) & k < 5L
      j <- match(t, cols); if (!is.na(j)) excl[v, j] <- TRUE
      k[v] <- k[v] + 1L
      if (all(k >= 5L)) break
    }
    m <- lin[, cols, drop = FALSE]; m[excl] <- NA
    n <- rowSums(!is.na(m)); r <- 10 * log10(rowMeans(m, na.rm = TRUE)); r[n < N_BASE_MIN] <- NA
    list(v = r, nexcl = rowSums(excl))
  }
  est_t <- startsWith(tab$groupe, "tardif_")
  vals <- list()
  metas <- list.files(D_SERIES, pattern = "\\.rds$", full.names = TRUE)
  for (f in metas) {
    m <- readRDS(f)
    if (!m$orbite %in% o8) next
    con <- file(sub("\\.rds$", ".bin", f), "rb")
    vh <- matrix(readBin(con, "integer", m$npix * m$nt, size = 2L), m$npix, m$nt)
    close(con)
    lin <- ifelse(vh == NA16, NA_real_, 10^(vh / 1000)); rm(vh)
    cel_bloc <- (rep(m$lignes_tuile, each = m$nc) - 1L) * m$nc + rep(seq_len(m$nc), length(m$lignes_tuile))
    for (j in which(o8 == m$orbite)) {
      X <- d8[j]; Y <- X - 365
      ap <- apres(lin, m$dates, X)
      bx <- base365_hors5(lin, m$dates, X); by <- base365_hors5(lin, m$dates, Y)
      p_new <- ap - bx$v
      p_an <- apres(lin, m$dates, Y) - by$v
      p_ar2 <- ap - base365(lin, m$dates, X)
      p_old <- ap - moy_5_valides(lin, m$dates, X)
      dc <- date_ref_t[cel_bloc]
      grp <- list(
        tardifs_a_D = cel_bloc %in% tab$cel[est_t & tab$date_carte == X],
        reste_a_D = cel_bloc %in% tab$cel[tab$groupe == "tardif_reste" & tab$date_carte == X],
        retrouves_a_D = cel_bloc %in% tab$cel[tab$groupe == "temoin_retrouve" & tab$date_carte == X],
        deja_coupee = masque[cel_bloc] & !is.na(dc) & dc < X - 60,
        sans_coupe = sans_coupe[cel_bloc])
      for (g in names(grp)) {
        key <- paste(format(X), g)
        w <- grp[[g]]
        vals[[key]] <- rbind(vals[[key]], cbind(p_old = p_old[w], p_ar2 = p_ar2[w], p_new = p_new[w],
                                                p_an = p_an[w], exclu_x = bx$nexcl[w], exclu_y = by$nexcl[w]))
      }
    }
    cat(basename(f), "\n")
  }
  q <- function(v) stats::quantile(v, c(0.25, 0.5, 0.75), na.rm = TRUE)
  pers <- do.call(rbind, lapply(names(vals), function(key) {
    v <- vals[[key]]
    exclu <- mean(v[, "exclu_x"] > 0); exclu_y <- mean(v[, "exclu_y"] > 0)
    ok <- stats::complete.cases(v[, c("p_old", "p_new", "p_an")]); v <- v[ok, , drop = FALSE]
    d <- v[, "p_new"] - v[, "p_an"]
    data.frame(date = as.Date(sub(" .*", "", key)), groupe = sub(".* ", "", key),
               n_cellules = length(ok), n = nrow(v),
               part_base_amputee = exclu, part_base_amputee_an = exclu_y,
               med_old5 = stats::median(v[, "p_old"]), med_ar2 = stats::median(v[, "p_ar2"], na.rm = TRUE),
               med_new = stats::median(v[, "p_new"]),
               q25_new = q(v[, "p_new"])[1], q75_new = q(v[, "p_new"])[3],
               med_an = stats::median(v[, "p_an"]), med_diff = stats::median(d),
               part_new_tp = mean(v[, "p_new"] <= TP), part_an_tp = mean(v[, "p_an"] <= TP),
               part_diff_tp = mean(d <= TP))
  }))
  rownames(pers) <- NULL
  out <- list(persistance = pers, n_base_min = N_BASE_MIN, n_apres_min = N_APRES_MIN)

  # Pixels tracés : persistance à la date de la carte (orbite retenue) et un an
  # avant, même définition, depuis les séries de pixels_traces.rds.
  tr <- readRDS(file.path(DOSSIER, "pixels_traces.rds"))
  pt <- tr$pixels
  pers_trace <- function(i, X) {
    s <- tr$series[[pt$orbite_ret[i]]]
    lin <- matrix(10^(s$vh[i, ] / 10), 1L)
    c(apres(lin, s$dates, X) - base365_hors5(lin, s$dates, X)$v,
      apres(lin, s$dates, X) - base365(lin, s$dates, X),
      apres(lin, s$dates, X) - moy_5_valides(lin, s$dates, X))
  }
  out$traces <- do.call(rbind, lapply(seq_len(nrow(pt)), function(i) {
    a <- pers_trace(i, pt$date_carte[i]); b <- pers_trace(i, pt$date_carte[i] - 365)
    data.frame(x = round(pt$x[i]), y = round(pt$y[i]), classe = pt$classe_026[i], orbite = pt$orbite_ret[i],
               date_carte = pt$date_carte[i], pers = a[1], pers_ar2 = a[2], pers_old5 = a[3], pers_an = b[1])
  }))

  # Question 3 : FO0 et FF0, datés par l'une, l'autre ou les deux cartes.
  b <- lire_couple(base, reference)
  lu_bdf <- ns$bdforet_lire("wfs", b$grille)
  v <- lu_bdf$v
  champ <- names(v)[tolower(names(v)) == "code_tfv"]
  v$code <- trimws(as.character(v[[champ]][[1]]))
  codes <- sort(unique(v$code)); v$k <- match(v$code, codes)
  code_px <- codes[terra::values(terra::rasterize(v, b$grille, field = "k", touches = FALSE), mat = FALSE)]
  rec <- b$dans & !is.na(b$rec); refd <- b$dans & !is.na(b$ref)
  par_code <- function(cd) {
    w <- b$dans & code_px %in% cd
    c(aoi = sum(w), recalcul = sum(w & rec), v301 = sum(w & refd), communs = sum(w & rec & refd),
      recalcul_seul = sum(w & rec & !refd), v301_seule = sum(w & refd & !rec))
  }
  out$q3_postes <- rbind(FF0 = par_code("FF0"), FO0 = par_code("FO0"),
                         tous = c(aoi = sum(b$dans), recalcul = sum(rec), v301 = sum(refd),
                                  communs = sum(rec & refd), recalcul_seul = sum(rec & !refd),
                                  v301_seule = sum(refd & !rec)))
  fo0 <- which(b$dans & code_px %in% "FO0" & rec)
  out$q3_fo0_annee <- table(format(yyddd_vers_date(b$rec[fo0]), "%Y"))
  out$q3_fo0_objets <- length(unique(b$obj[fo0]))
  saveRDS(out, file.path(DOSSIER, "persistance_026.rds"))
  print(pers, digits = 3); print(out$traces, digits = 3); print(out$q3_postes); print(out$q3_fo0_annee); print(out$q3_fo0_objets)
}

# Étape 3 : tracés -------------------------------------------------------------------

if (ETAPE == "tracer") {
  tr <- readRDS(file.path(DOSSIER, "pixels_traces.rds"))
  d_t <- file.path(DOSSIER, "traces"); dir.create(d_t, showWarnings = FALSE)
  pts <- tr$pixels
  for (i in seq_len(nrow(pts))) {
    f <- file.path(d_t, sprintf("%s_%d_%d.png", pts$classe_026[i], round(pts$x[i]), round(pts$y[i])))
    grDevices::png(f, width = 1500, height = 1000)
    op <- graphics::par(mfrow = c(length(tr$series), 1), mar = c(3, 4, 2, 4))
    for (o in names(tr$series)) {
      s <- tr$series[[o]]
      graphics::plot(s$dates, s$r_dat[i, ], type = "l", col = "grey50", ylim = c(-10, 6),
                     ylab = "ratio (dB)", xlab = "",
                     main = sprintf("%s %s | x=%d y=%d | retenue : %s", pts$groupe[i], o, round(pts$x[i]),
                                    round(pts$y[i]), pts$orbite_ret[i]))
      graphics::lines(s$dates, s$r_det[i, ], col = "blue", lwd = 2)
      graphics::abline(h = TP, lty = 2)
      graphics::abline(v = pts$pub[i], col = "black", lwd = 2)
      graphics::abline(v = pts$date_carte[i], col = "red", lwd = 2)
      graphics::abline(v = pts$premier_ret[i], col = "blue", lty = 3, lwd = 2)
      graphics::par(new = TRUE)
      graphics::plot(s$dates, s$vh[i, ], type = "p", pch = 20, cex = 0.6, col = "darkgreen",
                     axes = FALSE, xlab = "", ylab = "", ylim = c(-30, -5))
      graphics::axis(4, col.axis = "darkgreen")
    }
    graphics::par(op); grDevices::dev.off()
  }
  utils::write.csv(pts[, c("groupe", "classe_026", "x", "y", "orbite_ret", "tfv")],
                   file.path(d_t, "pixels.csv"), row.names = FALSE)
  cat("Tracés dans", d_t, "\n")
  cat("Orthophotos : Rscript docs/analyses/ecarts-date-v301.R", DOSSIER, "orthos",
      paste(sprintf("%d,%d", round(pts$x), round(pts$y)), collapse = " "), "\n")
}
