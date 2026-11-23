# Mission 024 : d'où viennent les dates tardives par rapport à la v3.0.1
# ---------------------------------------------------------------------------
# Script d'analyse reproductible, SANS modification du package : la règle de
# date essayée est branchée à l'exécution (utils::assignInNamespace) autour de
# rcr_compute(), comme pilote-landes.R force fork_disponible(). À lancer
# depuis la racine du dépôt :
#
#   Rscript docs/analyses/ecarts-date-v301.R <dossier> recalculer <regle> [hauteur_bande]
#   Rscript docs/analyses/ecarts-date-v301.R <dossier> comparer <dates_v301.tif> <sorties_017>
#   Rscript docs/analyses/ecarts-date-v301.R <dossier> tracer <x_l93> <y_l93> <sorties_017>
#   Rscript docs/analyses/ecarts-date-v301.R <dossier> orthos <x_l93,y_l93> [<x,y> ...]
#
#   <dossier>     : dossier de travail HORS du dépôt.
#   recalculer    : relance nemetonsar_run() sur l'AOI pilote (mêmes AOI,
#                   période, réglages et lecture en série que la mission 017)
#                   avec une autre règle de date, dans <dossier>/<regle>/sorties.
#                   <regle> :
#                     premiere_detection : d_(i+1) de la PREMIÈRE date d_i
#                       admise où le ratio de détection (xb = Inf) est <= tp ;
#                     premiere_datation  : idem sur le ratio de datation
#                       (xb_date = 5).
#                   [hauteur_bande] : 512 par défaut ; plus petit, chaque
#                   lecture d'une bande est plus courte que la vie du jeton
#                   SAS du Planetary Computer (403 sinon, vu le 2026-11-23) ;
#                   sans effet sur les résultats (identiques au bit près,
#                   documentation de nemetonsar_run()).
#                   Le minimum du ratio de détection (ce qui est détecté, et
#                   l'orbite retenue) est inchangé : seule la date change.
#                   Contrôle : la règle actuelle (minimum du ratio de
#                   datation) est recalculée à part et confrontée, pixel à
#                   pixel, à rcr_compute() ; le décompte va dans
#                   <dossier>/<regle>/controle.txt.
#   comparer      : hypothèses 1 et 2, chiffres agrégés seulement (la v3.0.1
#                   est CC BY-NC 4.0 : l'extrait reste hors du dépôt) ;
#                   résultats dans <dossier>/comparaison_024.rds.
#   tracer        : série du ratio (deux ratios, trois orbites) d'un pixel,
#                   relue sur une AOI de 210 m centrée sur lui, et dates des
#                   règles ; <dossier>/trace_<x>_<y>.rds et .png.
#   orthos        : pour chaque point, vignettes de 300 m x 300 m des
#                   orthophotos IGN (WMS de la Géoplateforme) de 2018, 2020,
#                   2021, 2024 et 2025, croix au centre ; <dossier>/orthos/.
#
# Lecture en série (flux = 1, fork désactivé) : le fork se bloque sous
# GDAL 3.11 (mission 023). Graine fixée.
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : Rscript docs/analyses/ecarts-date-v301.R <dossier> recalculer|comparer|tracer ...",
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
utils::assignInNamespace("fork_disponible", function() FALSE, "nemetonsar")
# Jeton SAS neuf à chaque lecture (chaque bande) : rstac garde le jeton tant
# qu'il lui reste plus de 5 min ; une lecture de bande plus longue que ce
# reste échoue en 403 (vu le 2026-11-23, deux exécutions simultanées).
s1_lire_origine <- get("s1_lire", envir = ns)
utils::assignInNamespace("s1_lire", function(...) {
  jetons <- get("ms_token", envir = asNamespace("rstac"))
  rm(list = ls(jetons, all.names = TRUE), envir = jetons)
  s1_lire_origine(...)
}, "nemetonsar")

# AOI, période, réglages : ceux de pilote-landes.R (mission 017).
POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2025-09-30")
P <- parametres_sufosat()
TP <- seuils_db(P)[["tp"]]
REGLES <- c("premiere_detection", "premiere_datation")

aoi_pilote <- function() {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                COTE_M / 2, capstyle = "square")
}

# Ratios d'une orbite, toutes dates -------------------------------------------
# Même définition que rcr_compute() (moyennes des images valides en linéaire,
# ratio en dB, d_i admise à partir du 1er janvier annee_noyau + 1, suivie de
# xa images valides), écrite simplement. Rend, par pixel, l'indice de rang
# (k : k-ième image valide) du minimum du ratio de datation (règle actuelle),
# de la première date sous tp de chaque ratio, la position des images
# valides et, si `garder`, les deux ratios à toutes les dates.
ratios_orbite <- function(serie, dates, p, tp, garder = FALSE) {
  d <- dim(serie)
  nt <- d[3]
  npix <- d[1] * d[2]
  x <- serie
  dim(x) <- c(npix, nt)
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
  k_prem_det <- rep(NA_integer_, npix)
  k_prem_dat <- rep(NA_integer_, npix)
  r_det <- r_dat <- if (garder) matrix(NA_real_, npix, nt) else NULL
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
    a <- is.na(k_prem_det[pix]) & rdet <= tp
    k_prem_det[pix[a]] <- k
    a <- is.na(k_prem_dat[pix]) & rdat <= tp
    k_prem_dat[pix[a]] <- k
    if (garder) {
      r_det[cbind(pix, pos[pix, k])] <- rdet
      r_dat[cbind(pix, pos[pix, k])] <- rdat
    }
  }
  list(k_min_dat = k_min_dat, k_prem_det = k_prem_det, k_prem_dat = k_prem_dat,
       m_det = m_det, pos = pos, xa = xa, r_det = r_det, r_dat = r_dat)
}

# Dates (codes YYDDD) d_(i+1) et d_i, et durée de Xa, au rang k.
dates_au_rang <- function(r, k, dates) {
  npix <- length(k)
  codes <- date_vers_yyddd(dates)
  ok <- which(!is.na(k))
  lire <- function(j) r$pos[cbind(ok, j)]
  out <- list(date_min = rep(NA_integer_, npix), date_avant = rep(NA_integer_, npix),
              duree = rep(NA_integer_, npix))
  if (length(ok)) {
    out$date_avant[ok] <- codes[lire(k[ok])]
    out$date_min[ok] <- codes[lire(k[ok] + 1L)]
    out$duree[ok] <- as.integer(dates[lire(k[ok] + r$xa)] - dates[lire(k[ok])])
  }
  out
}

# Étape 1 : recalcul avec une autre règle de date -------------------------------

if (ETAPE == "recalculer") {
  regle <- args[3]
  if (!regle %in% REGLES) stop("Règle inconnue : ", regle, call. = FALSE)
  d_regle <- file.path(DOSSIER, regle)
  dir.create(d_regle, showWarnings = FALSE, recursive = TRUE)
  f_ctrl <- file.path(d_regle, "controle.txt")
  cat("appel pixels_ratio date_min_identique date_min_differente ecart_ratio_det_max_db",
      "remplacees\n", file = f_ctrl)
  rcr_origine <- get("rcr_compute", envir = ns)
  n_appel <- 0L
  rcr_regle <- function(serie, dates, parametres = parametres_sufosat()) {
    res <- rcr_origine(serie, dates, parametres)
    n_appel <<- n_appel + 1L
    r <- ratios_orbite(serie, dates, parametres, TP)
    # Contrôle : la règle actuelle, recalculée ici, rend-elle la même date ?
    actuelle <- dates_au_rang(r, r$k_min_dat, dates)
    a_ratio <- !is.na(res$ratio_min_db)
    same <- a_ratio & actuelle$date_min == as.vector(res$date_min)
    ecart <- if (any(a_ratio)) max(abs(r$m_det[a_ratio] - as.vector(res$ratio_min_db)[a_ratio])) else NA
    k <- if (regle == "premiere_detection") r$k_prem_det else r$k_prem_dat
    nouv <- dates_au_rang(r, k, dates)
    remplace <- a_ratio & !is.na(k)
    cat(n_appel, sum(a_ratio), sum(same, na.rm = TRUE), sum(a_ratio) - sum(same, na.rm = TRUE),
        signif(ecart, 3), sum(remplace), "\n", file = f_ctrl, append = TRUE)
    res$date_min[remplace] <- nouv$date_min[remplace]
    res$date_avant[remplace] <- nouv$date_avant[remplace]
    res$duree_xa_jours[remplace] <- nouv$duree[remplace]
    res
  }
  utils::assignInNamespace("rcr_compute", rcr_regle, "nemetonsar")
  t0 <- Sys.time()
  hb <- if (length(args) >= 4L) as.integer(args[4]) else 512L
  res <- nemetonsar_run(aoi_pilote(), DEBUT, FIN, dossier = file.path(d_regle, "sorties"),
                        bdforet = "wfs", parametres = P, flux = 1L, hauteur_bande = hb)
  t1 <- Sys.time()
  saveRDS(list(res = res, regle = regle, duree_h = as.numeric(difftime(t1, t0, units = "hours"))),
          file.path(d_regle, "execution.rds"))
  print(res$tuiles)
  cat("Durée :", format(round(difftime(t1, t0, units = "mins"), 1)), "\n")
}

# Étape 2 : comparaisons --------------------------------------------------------

# Écarts de date (jours) aux pixels datés dans les deux cartes, sur la grille
# recalculée, dans l'AOI ; NA ailleurs.
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

classes_ecart <- function(e) {
  # Bornes du rapport de la mission 017 : ]a, b], sauf ]-Inf, -365] et ]365, Inf[ ;
  # la classe centrale est [-15, 15] (|e| <= 15), comme « date retrouvée ».
  e <- ifelse(e == -15, -14.5, e)
  cut(e, c(-Inf, -365, -180, -60, -15, 15, 60, 180, 365, Inf),
      labels = c("<= -365", "-365 a -180", "-180 a -60", "-60 a -15", "-15 a +15",
                 "+15 a +60", "+60 a +180", "+180 a +365", "> +365"), right = TRUE)
}

ecart_j <- function(a, b) as.numeric(yyddd_vers_date(a) - yyddd_vers_date(b))

if (ETAPE == "comparer") {
  reference <- normalizePath(args[3])
  base <- normalizePath(args[4])
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  cartes <- c(actuelle = base,
              stats::setNames(file.path(DOSSIER, REGLES, "sorties"), REGLES))
  cartes <- cartes[file.exists(file.path(cartes, "dates.tif"))]
  out <- list()

  # Hypothèse 1 : pixels communs datés, écarts sous chaque règle.
  b <- lire_couple(cartes[["actuelle"]], reference)
  commun_b <- b$dans & !is.na(b$rec) & !is.na(b$ref)
  e_b <- ecart_j(b$rec[commun_b], b$ref[commun_b])
  tardif <- e_b > 180
  idx_tardif <- which(commun_b)[tardif]
  idx_proche <- which(commun_b)[abs(e_b) <= 15]
  h1 <- list()
  for (n in names(cartes)) {
    cc <- lire_couple(cartes[[n]], reference)
    commun <- cc$dans & !is.na(cc$rec) & !is.na(cc$ref)
    e <- ecart_j(cc$rec[commun], cc$ref[commun])
    # Devenir des pixels tardifs et des pixels proches de la carte actuelle.
    et <- ecart_j(cc$rec[idx_tardif], cc$ref[idx_tardif])
    ep <- ecart_j(cc$rec[idx_proche], cc$ref[idx_proche])
    cmp <- compare_reference(cartes[[n]], reference, periode = c(DEBUT, FIN),
                             aoi = aoi_pilote(), seuil_objet = 0.75)
    h1[[n]] <- list(
      resume = cmp$resume, par_annee = cmp$par_annee,
      n_communs = length(e),
      distribution = table(classes_ecart(e)),
      quantiles = stats::quantile(e, c(0.05, 0.25, 0.5, 0.75, 0.95), type = 1),
      tardifs_annees = table(publiee = as.integer(cc$ref[idx_tardif] %/% 1000L) + 2000L,
                             recalculee = as.integer(cc$rec[idx_tardif] %/% 1000L) + 2000L,
                             reste_tardif = et > 180, useNA = "ifany"),
      tardifs = c(n = length(idx_tardif), encore_dates = sum(!is.na(et)),
                  moins_15 = sum(abs(et) <= 15, na.rm = TRUE),
                  moins_60 = sum(abs(et) <= 60, na.rm = TRUE),
                  encore_tardifs = sum(et > 180, na.rm = TRUE),
                  devenus_tot = sum(et < -180, na.rm = TRUE)),
      proches = c(n = length(idx_proche), encore_dates = sum(!is.na(ep)),
                  moins_15 = sum(abs(ep) <= 15, na.rm = TRUE),
                  devenus_tot = sum(ep < -15, na.rm = TRUE))
    )
  }
  out$h1 <- h1

  # Hypothèse 2 : début de série.
  annee_ref <- as.integer(b$ref %/% 1000L) + 2000L
  annee_rec <- as.integer(b$rec %/% 1000L) + 2000L
  ref18 <- b$dans & !is.na(b$ref) & annee_ref == 2018L
  # Part des pixels tardifs dont la date publiée est en 2018.
  out$h2_tardifs_ref2018 <- c(tardifs = length(idx_tardif), ref2018 = sum(ref18[idx_tardif]))
  # Comparaison 2019-2025 : pixels publiés en 2018 écartés des deux côtés.
  masquer <- function(sorties) {
    d <- terra::rast(file.path(sorties, "dates.tif"))
    o <- terra::rast(file.path(sorties, "objets.tif"))
    v <- terra::values(d, mat = FALSE); v[ref18] <- NA; d <- terra::setValues(d, v)
    w <- terra::values(o, mat = FALSE); w[ref18] <- NA; o <- terra::setValues(o, w)
    f <- file.path(DOSSIER, "h2", basename(dirname(sorties)))
    dir.create(f, showWarnings = FALSE, recursive = TRUE)
    terra::writeRaster(d, file.path(f, "dates.tif"), overwrite = TRUE, datatype = "INT4S")
    terra::writeRaster(o, file.path(f, "objets.tif"), overwrite = TRUE, datatype = "INT4S")
    f
  }
  r19 <- b$ref_rast
  v <- terra::values(r19, mat = FALSE); v[ref18] <- 0L; r19 <- terra::setValues(r19, v)
  f_ref19 <- file.path(DOSSIER, "h2", "reference_sans_2018.tif")
  dir.create(dirname(f_ref19), showWarnings = FALSE, recursive = TRUE)
  terra::writeRaster(r19, f_ref19, overwrite = TRUE, datatype = "INT2S", NAflag = -32768)
  out$h2 <- lapply(cartes, function(s) {
    cmp <- compare_reference(masquer(s), f_ref19, periode = c(as.Date("2019-01-01"), FIN),
                             aoi = aoi_pilote(), seuil_objet = 0.75)
    cc <- lire_couple(s, reference)
    commun <- cc$dans & !is.na(cc$rec) & !is.na(cc$ref) & !ref18
    e <- ecart_j(cc$rec[commun], cc$ref[commun])
    list(resume = cmp$resume, distribution = table(classes_ecart(e)),
         part_tardifs = mean(e > 180), part_15 = mean(abs(e) <= 15))
  })
  # Surface recalculée datée de 2019 (carte actuelle) : d'où vient-elle ?
  # Commune avec une coupe publiée en 2018, commune avec une autre année,
  # absente de la référence mais à moins de 30 m d'un pixel publié en 2018,
  # absente ailleurs.
  rec19 <- b$dans & !is.na(b$obj) & !is.na(annee_rec) & annee_rec == 2019L
  pres_ref <- b$dans & !is.na(b$ref)
  r18 <- terra::setValues(b$grille, ifelse(ref18, 1L, NA_integer_))
  pres18_30m <- !is.na(terra::values(terra::focal(r18, w = 7, fun = "max", na.rm = TRUE), mat = FALSE))
  out$h2_rec2019 <- c(
    pixels = sum(rec19),
    commune_ref2018 = sum(rec19 & ref18),
    commune_ref_autre = sum(rec19 & pres_ref & !ref18),
    absente = sum(rec19 & !pres_ref),
    absente_30m_ref2018 = sum(rec19 & !pres_ref & pres18_30m),
    absente_ailleurs = sum(rec19 & !pres_ref & !pres18_30m)
  )
  # Pixels publiés en 2018 : devenir dans la carte actuelle.
  out$h2_ref2018 <- c(pixels = sum(ref18), recalcules = sum(ref18 & !is.na(b$obj)),
                      dates_2019 = sum(ref18 & annee_rec %in% 2019L),
                      dates_apres_2019 = sum(ref18 & annee_rec > 2019L, na.rm = TRUE))
  # Pixels tardifs : année recalculée et année publiée (agrégés).
  out$tardifs_annees <- table(publiee = annee_ref[idx_tardif], recalculee = annee_rec[idx_tardif])
  # Pixels tardifs à contrôler sur orthophoto : centre des 5 plus grands
  # groupes connexes de pixels tardifs (coordonnées seulement).
  m <- terra::setValues(b$grille, NA_integer_)
  vv <- rep(NA_integer_, terra::ncell(m)); vv[idx_tardif] <- 1L
  m <- terra::setValues(m, vv)
  pa <- terra::patches(m, directions = 8)
  tb <- table(terra::values(pa, mat = FALSE))
  gros <- as.integer(names(sort(tb, decreasing = TRUE))[1:5])
  pts <- do.call(rbind, lapply(gros, function(g) {
    cel <- which(terra::values(pa, mat = FALSE) == g)
    xy <- terra::xyFromCell(pa, cel)
    j <- cel[which.min((xy[, 1] - mean(xy[, 1]))^2 + (xy[, 2] - mean(xy[, 2]))^2)]
    data.frame(groupe = g, pixels = length(cel), x = terra::xFromCell(pa, j), y = terra::yFromCell(pa, j))
  }))
  ll <- terra::crds(terra::project(terra::vect(as.matrix(pts[, c("x", "y")]), crs = "EPSG:2154"), "EPSG:4326"))
  pts$lon <- round(ll[, 1], 5); pts$lat <- round(ll[, 2], 5)
  out$controle_tardifs <- pts
  # Pareto des pixels tardifs de la carte actuelle, causes exclusives, dans
  # l'ordre : début de série (date publiée en 2018), règle de date (à 15 j,
  # puis à 60 j, avec la première date sous tp du ratio de détection), reste.
  if ("premiere_detection" %in% names(cartes)) {
    pdet <- lire_couple(cartes[["premiere_detection"]], reference)
    e_pd <- ecart_j(pdet$rec[idx_tardif], pdet$ref[idx_tardif])
    r18 <- ref18[idx_tardif]
    classe <- ifelse(r18, "debut_serie",
              ifelse(!is.na(e_pd) & abs(e_pd) <= 15, "regle_15j",
              ifelse(!is.na(e_pd) & abs(e_pd) <= 60, "regle_60j",
              ifelse(is.na(e_pd), "plus_datee", "reste"))))
    out$pareto_tardifs <- table(classe)
    # Le reste : mois de la date (première détection) et ratio de détection minimal.
    reste <- idx_tardif[classe == "reste"]
    mois <- function(v) table(factor(as.integer(format(yyddd_vers_date(v), "%m")), levels = 1:12))
    out$reste_mois <- mois(pdet$rec[reste])
    out$tardifs_mois_actuelle <- mois(b$rec[idx_tardif])
    t8 <- sort(table(b$rec[idx_tardif]), decreasing = TRUE)
    out$tardifs_8_dates <- c(part = sum(t8[1:8]) / sum(t8), nb_dates = length(t8),
                             fevrier_mars = sum(out$tardifs_mois_actuelle[2:3]) / length(idx_tardif))
    ratio <- terra::values(terra::rast(file.path(cartes[["actuelle"]], "ratio.tif")), mat = FALSE)
    grp <- list(proches = idx_proche,
                tardifs_regle = idx_tardif[classe %in% c("regle_15j", "regle_60j")],
                tardifs_reste = reste)
    out$ratio_min_db <- t(sapply(grp, function(i) {
      v <- ratio[i]
      c(n = length(i), stats::quantile(v, c(0.25, 0.5, 0.75), na.rm = TRUE),
        part_au_dessus_ts = mean(v > seuils_db(P)[["ts"]], na.rm = TRUE))
    }))
  }
  # Indication, sans exécution : la plus ancienne des deux « premières dates »
  # (pixel par pixel, sur les deux cartes recalculées). Approximation de la
  # règle « premier passage sous tp de l'un ou l'autre ratio » : les objets
  # des deux cartes diffèrent un peu (passe 2019, période).
  if (all(REGLES %in% names(cartes))) {
    pa <- lire_couple(cartes[["premiere_detection"]], reference)
    pb <- lire_couple(cartes[["premiere_datation"]], reference)
    cc <- commun_b & !is.na(pa$rec) & !is.na(pb$rec)
    dd <- pmin(as.numeric(yyddd_vers_date(pa$rec[cc])), as.numeric(yyddd_vers_date(pb$rec[cc])))
    e <- dd - as.numeric(yyddd_vers_date(b$ref[cc]))
    e0 <- ecart_j(b$rec[cc], b$ref[cc])
    out$plus_ancienne_des_deux <- c(n = sum(cc), part_15 = mean(abs(e) <= 15),
                                    part_tardifs = mean(e > 180), part_tot = mean(e < -180),
                                    mediane = stats::median(e),
                                    tardifs_vers_15 = mean(abs(e[e0 > 180]) <= 15),
                                    proches_gardes = mean(abs(e[abs(e0) <= 15]) <= 15))
  }
  saveRDS(out, file.path(DOSSIER, "comparaison_024.rds"))
  str(out, max.level = 3)
}

# Étape 3 : trace d'un pixel --------------------------------------------------------

if (ETAPE == "tracer") {
  x0 <- as.numeric(args[3]); y0 <- as.numeric(args[4]); base <- normalizePath(args[5])
  aoi <- terra::buffer(terra::vect(cbind(x0, y0), crs = "EPSG:2154"), 105, capstyle = "square")
  traces <- list()
  rcr_origine <- get("rcr_compute", envir = ns)
  utils::assignInNamespace("rcr_compute", function(serie, dates, parametres = parametres_sufosat()) {
    traces[[length(traces) + 1L]] <<- list(serie = serie, dates = dates)
    rcr_origine(serie, dates, parametres)
  }, "nemetonsar")
  d_tr <- file.path(DOSSIER, sprintf("trace_%d_%d", round(x0), round(y0)))
  res <- nemetonsar_run(aoi, DEBUT, FIN, dossier = file.path(d_tr, "sorties"),
                        bdforet = "wfs", parametres = P, flux = 1L, hauteur_bande = NULL)
  # Le pixel : position dans la grille UTM de la tuile.
  g <- aoi_grille(aoi_preparer(aoi, resolution_m = 10)$tuiles[1, ])
  xy <- terra::crds(terra::project(terra::vect(cbind(x0, y0), crs = "EPSG:2154"), terra::crs(g)))
  cel <- terra::cellFromXY(g, xy)
  ligne <- terra::rowFromCell(g, cel); colonne <- terra::colFromCell(g, cel)
  # Appels de la passe principale (b) : séries complètes (dernières images).
  nmax <- max(vapply(traces, function(t) length(t$dates), 1L))
  princ <- Filter(function(t) length(t$dates) > 0 && max(t$dates) > as.Date("2020-06-01"), traces)
  princ <- princ[seq_len(min(3L, length(princ)))]  # une bande : trois orbites
  orb <- lapply(princ, function(t) {
    s <- t$serie
    # dim = (colonnes, lignes de la bande bordée, dates)
    sp <- s[colonne, min(ligne, dim(s)[2]), , drop = FALSE]
    r <- ratios_orbite(sp, t$dates, P, TP, garder = TRUE)
    list(dates = t$dates, vh_db = 10 * log10(as.vector(sp)), r_det = as.vector(r$r_det),
         r_dat = as.vector(r$r_dat), m_det = r$m_det,
         actuelle = dates_au_rang(r, r$k_min_dat, t$dates)$date_min,
         premiere_detection = dates_au_rang(r, r$k_prem_det, t$dates)$date_min,
         premiere_datation = dates_au_rang(r, r$k_prem_dat, t$dates)$date_min)
  })
  ref_base <- terra::extract(terra::rast(file.path(base, "dates.tif")), cbind(x0, y0))[1, 1]
  ref_trace <- terra::extract(terra::rast(file.path(d_tr, "sorties", "dates.tif")), cbind(x0, y0))[1, 1]
  saveRDS(list(x = x0, y = y0, orbites = orb, date_carte_017 = ref_base, date_trace = ref_trace,
               tp = TP), paste0(d_tr, ".rds"))
  grDevices::png(paste0(d_tr, ".png"), width = 1400, height = 900)
  op <- graphics::par(mfrow = c(length(orb), 1), mar = c(3, 4, 2, 1))
  for (o in orb) {
    graphics::plot(o$dates, o$r_dat, type = "l", col = "grey40", ylim = c(-10, 6),
                   ylab = "ratio (dB)", xlab = "", main = sprintf("min ratio detection %.2f dB", o$m_det))
    graphics::lines(o$dates, o$r_det, col = "blue")
    graphics::abline(h = TP, lty = 2)
    for (n in c("actuelle", "premiere_detection", "premiere_datation")) {
      if (!is.na(o[[n]])) graphics::abline(v = yyddd_vers_date(o[[n]]),
                                           col = c(actuelle = "red", premiere_detection = "blue",
                                                   premiere_datation = "darkgreen")[[n]])
    }
  }
  graphics::par(op); grDevices::dev.off()
  print(lapply(orb, function(o) o[c("m_det", "actuelle", "premiere_detection", "premiere_datation")]))
  cat("Date carte 017 :", ref_base, " ; date de la trace :", ref_trace, "\n")
}

# Étape 4 : orthophotos IGN ---------------------------------------------------------

if (ETAPE == "orthos") {
  # Couches couvrant l'AOI (sondé le 2026-11-23 : les autres années sont vides ici).
  couches <- c("2018" = "ORTHOIMAGERY.ORTHOPHOTOS2018",
               "2020" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-ASP_PAC2020",
               "2021" = "ORTHOIMAGERY.ORTHOPHOTOS2021",
               "2024" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-EXPRESS.2024",
               "2025" = "ORTHOIMAGERY.ORTHOPHOTOS.ORTHO-ASP_PAC2025")
  d_o <- file.path(DOSSIER, "orthos")
  dir.create(d_o, showWarnings = FALSE)
  for (pt in args[-(1:2)]) {
    xy <- as.numeric(strsplit(pt, ",")[[1]])
    bbox <- paste(xy[1] - 150, xy[2] - 150, xy[1] + 150, xy[2] + 150, sep = ",")
    imgs <- lapply(names(couches), function(a) {
      f <- file.path(d_o, sprintf("%d_%d_%s.jpg", round(xy[1]), round(xy[2]), a))
      if (!file.exists(f)) {
        u <- paste0("https://data.geopf.fr/wms-r/wms?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap",
                    "&LAYERS=", couches[[a]], "&STYLES=&CRS=EPSG:2154&BBOX=", bbox,
                    "&WIDTH=300&HEIGHT=300&FORMAT=image/jpeg")
        utils::download.file(u, f, mode = "wb", quiet = TRUE)
      }
      jpeg::readJPEG(f)
    })
    grDevices::png(file.path(d_o, sprintf("%d_%d.png", round(xy[1]), round(xy[2]))),
                   width = 300 * length(imgs), height = 330)
    op <- graphics::par(mfrow = c(1, length(imgs)), mar = c(0, 0, 2, 0))
    for (i in seq_along(imgs)) {
      graphics::plot(0, 0, type = "n", xlim = c(0, 300), ylim = c(0, 300), axes = FALSE,
                     xlab = "", ylab = "", asp = 1, main = names(couches)[i])
      graphics::rasterImage(imgs[[i]], 0, 0, 300, 300)
      graphics::points(150, 150, pch = 3, col = "red", cex = 2, lwd = 2)
      graphics::rect(145, 145, 155, 155, border = "red")
    }
    graphics::par(op); grDevices::dev.off()
  }
  cat("Vignettes dans", d_o, "\n")
}
