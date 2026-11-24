# Mission 033 : decalage du ratio de changement entre Sentinel-1A et 1C/1D.
# Script reproductible, aucune modification du package. A lancer depuis la
# racine du depot :
#   Rscript docs/analyses/decalage-1a-1c1d.R DOSSIER ETAPE [TUILE]
#
# DOSSIER : dossier de travail, HORS du depot (une sous-dossier par tuile).
# ETAPE :
#   orbites   TUILE : s1_rechercher() sur la zone, 2026-06-01 a FIN : quelles
#                     orbites servent 1C et 1D ? (avant de lire quoi que ce soit) ;
#   fenetre   TUILE : masque BD Foret (WFS) sur 6 km x 6 km, choix de la
#                     fenetre de 300 x 300 pixels la plus riche en foret
#                     eloignee de 30 m de toute non-foret ;
#   lire      TUILE : images S1 RTC de 2018-01-01 a FIN sur cette fenetre
#                     (reprise : les images deja sur le disque sont relues) ;
#   mesurer   TUILE : ratio de changement par pixel, pixels de foret stable,
#                     statistiques par date (rds) ;
#   synthese        : tableaux de la mission (toutes les tuiles mesurees) ;
#   recouvrement TUILE : question 4 (ajoutee en cours de route, voir le rapport) :
#                     le catalogue sert Sentinel-1C depuis mars 2025, donc en
#                     meme temps que 1A : niveau VH de 1C contre 1A, meme orbite,
#                     meme mois, de 2025-03 a 2026-06 (et 1D contre 1A en
#                     2026-05 et 2026-06) ;
#   recouvrement-synthese : tableau de cette question ;
#   controle        : verifie le calcul sur des donnees synthetiques (sans reseau).
#
# TUILE : un nom de la table TUILES ci-dessous. Chiffres agreges seulement :
# aucune image n est ecrite au depot. Graine fixee.
#
# Ratio : 10 log10(Ma / Mb), Ma = moyenne lineaire des xa images suivantes de
# l orbite, Mb = moyenne lineaire de toutes les images precedentes (xb = Inf),
# comme dans la chaine (voir docs/analyses/continuite-s1c.R, ratio_pixels()).

args <- commandArgs(trailingOnly = TRUE)
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
TUILE <- args[3]
stopifnot(file.exists("DESCRIPTION"), dir.exists("R"))
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
set.seed(20261124L)
suppressMessages(pkgload::load_all(".", quiet = TRUE))

DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2026-11-21")
BASCULE <- as.Date("2026-06-30")
ANNEES_REF <- 2020:2025 # annees 1A de reference (Mb d au moins deux ans)
COTE_RECH <- 600L # pixels de 10 m : zone de recherche de la fenetre (6 km)
COTE <- 300L # pixels : fenetre mesuree (3 km)

# Zones d etude (longitude, latitude WGS 84, degres), choisies avant toute
# lecture : quatre regions forestieres de France (la BD Foret est le masque
# disponible), de climat, de relief et d essences differents.
TUILES <- list(
  landes = c(-0.80, 44.182), # pin maritime, plaine atlantique (30TXP, comme 029)
  vosges = c(7.00, 48.10), # sapin, epicea, hetre ; montagne moyenne, neige
  morvan = c(4.05, 47.12), # feuillus et douglas ; moyenne montagne
  cevennes = c(3.62, 44.12) # chene vert, chataignier, pin ; mediterraneen, relief
)

ll <- "EPSG:4326"
zone_utm <- function(lon) paste0("EPSG:", 32600L + floor((lon + 180) / 6) + 1L)

grille_de <- function(nom, cote = COTE_RECH, decalage = c(0, 0)) {
  pt <- TUILES[[nom]]
  crs <- zone_utm(pt[1])
  xy <- terra::crds(terra::project(terra::vect(rbind(pt), crs = ll), crs))
  x0 <- round(xy[1] / 10) * 10 - cote * 5 + decalage[1] * 10
  y0 <- round(xy[2] / 10) * 10 - cote * 5 + decalage[2] * 10
  terra::rast(xmin = x0, xmax = x0 + cote * 10, ymin = y0, ymax = y0 + cote * 10,
              resolution = 10, crs = crs)
}

dir_tuile <- function(nom) {
  d <- file.path(DOSSIER, nom)
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
  d
}

# Ratio de changement par pixel (M : dates x pixels, lineaire) : meme calcul
# que la chaine (Ma = xa images suivantes, Mb = toutes les precedentes).
ratio_pixels <- function(M, xa) {
  nt <- nrow(M)
  V <- is.na(M) == FALSE & M > 0
  X <- M
  X[V == FALSE] <- 0
  cs <- X
  cn <- V + 0
  for (i in 2:nt) {
    cs[i, ] <- cs[i - 1L, ] + X[i, ]
    cn[i, ] <- cn[i - 1L, ] + V[i, ]
  }
  R <- matrix(NA_real_, nt, ncol(M))
  for (i in seq_len(nt - xa)) {
    ma <- (cs[i + xa, ] - cs[i, ]) / (cn[i + xa, ] - cn[i, ])
    mb <- cs[i, ] / cn[i, ]
    R[i, ] <- 10 * log10(ma / mb)
  }
  R
}

# Composition de la fenetre Ma de chaque date d une orbite : "1A", "1C/1D" ou "mixte"
composition_ma <- function(capteur, xa) {
  n <- length(capteur)
  out <- rep(NA_character_, n)
  for (i in seq_len(n - xa)) {
    v <- capteur[(i + 1L):(i + xa)] == "S1A"
    out[i] <- if (all(v)) "1A" else if (any(v)) "mixte" else "1C/1D"
  }
  out
}

if (ETAPE == "orbites") {
  g <- grille_de(TUILE, cote = COTE)
  it <- s1_rechercher(g, as.Date("2026-06-01"), FIN)
  u <- unique(it[, c("serie", "date", "capteur")])
  cat(TUILE, ": images (orbite, date) :", nrow(u), "\n")
  print(table(serie = u$serie, capteur = u$capteur))
}

if (ETAPE == "fenetre") {
  d <- dir_tuile(TUILE)
  g <- grille_de(TUILE)
  foret <- masque_foret_bdforet("wfs", g)
  foret_n <- terra::ifel(is.na(foret), 0, foret)
  # foret eloignee de 30 m de toute non-foret : minimum sur 7 x 7 pixels
  coeur <- terra::focal(foret_n, w = 7, fun = "min", na.rm = TRUE)
  m <- terra::as.matrix(coeur == 1, wide = TRUE)
  m[is.na(m)] <- FALSE
  cat(TUILE, ": part de foret (BD Foret) sur 6 km x 6 km :", round(mean(terra::values(foret_n)), 3),
      " ; part de foret a plus de 30 m d une non-foret :", round(mean(m), 3), "\n")
  best <- c(0, 1, 1)
  for (i in seq(1L, nrow(m) - COTE + 1L, by = 30L)) {
    for (j in seq(1L, ncol(m) - COTE + 1L, by = 30L)) {
      s <- mean(m[i:(i + COTE - 1L), j:(j + COTE - 1L)])
      if (s > best[1]) best <- c(s, i, j)
    }
  }
  cat("Fenetre", COTE, "x", COTE, ": ligne", best[2], "colonne", best[3], ", part de pixels de coeur de foret", round(best[1], 3), "\n")
  i0 <- best[2]
  j0 <- best[3]
  fen <- terra::rast(g)[i0:(i0 + COTE - 1L), j0:(j0 + COTE - 1L), drop = FALSE]
  fen <- terra::rast(fen)
  # le masque de coeur sur la fenetre, en 0/1
  stable <- m[i0:(i0 + COTE - 1L), j0:(j0 + COTE - 1L)]
  e <- as.vector(terra::ext(fen))
  saveRDS(list(crs = terra::crs(fen), ext = e, coeur = stable, part = best[1],
               part_foret_6km = mean(terra::values(foret_n)), ligne = i0, colonne = j0,
               bdforet = attr(foret, "bdforet")$nb_polygones),
          file.path(d, "fenetre.rds"))
  ll_c <- terra::crds(terra::project(terra::centroids(terra::as.polygons(terra::ext(fen), crs = terra::crs(fen))), ll))
  cat("Centre de la fenetre (lon, lat) :", round(ll_c[1, ], 4), "\n")
}

lire_fenetre <- function(d) {
  f <- readRDS(file.path(d, "fenetre.rds"))
  terra::rast(xmin = f$ext[["xmin"]], xmax = f$ext[["xmax"]], ymin = f$ext[["ymin"]],
              ymax = f$ext[["ymax"]], resolution = 10, crs = f$crs)
}

if (ETAPE == "lire") {
  d <- dir_tuile(TUILE)
  g <- lire_fenetre(d)
  it <- s1_rechercher(g, DEBUT, FIN)
  saveRDS(it, file.path(d, "items.rds"))
  rep <- file.path(d, "images")
  fichiers <- if (dir.exists(rep)) list.files(rep, pattern = "tif$", recursive = TRUE) else character(0)
  attendu <- nrow(unique(it[, c("serie", "date")]))
  cat(TUILE, ":", attendu, "images (orbite, date) a lire ;", length(fichiers), "deja sur le disque\n")
  if (length(fichiers) < attendu) {
    # reprise : on ne relit que ce qui manque
    deja <- file.path(sub("/[^/]*$", "", fichiers), "")
    cle_it <- paste0("s1_", it$serie, "/", format(it$date), ".tif")
    reste <- it[cle_it %in% fichiers == FALSE, ]
    if (nrow(reste) > 0L) s1_lire(reste, g, dossier = rep, flux = 4L)
  }
  cat("Images sur le disque :", length(list.files(rep, pattern = "tif$", recursive = TRUE)), "\n")
}

if (ETAPE == "mesurer") {
  d <- dir_tuile(TUILE)
  f <- readRDS(file.path(d, "fenetre.rds"))
  it <- readRDS(file.path(d, "items.rds"))
  rep <- file.path(d, "images")
  p <- parametres_sufosat()
  xa <- p$xa
  seuils <- seuils_db(p)
  capt <- unique(it[, c("serie", "date", "capteur")])
  coeur <- as.vector(t(f$coeur))
  series <- sort(unique(it$serie))
  R <- list()
  info <- list()
  for (s in series) {
    fs <- sort(list.files(file.path(rep, paste0("s1_", s)), pattern = "tif$", full.names = TRUE))
    dates <- as.Date(sub("[.]tif$", "", basename(fs)))
    A <- terra::values(terra::rast(fs), mat = TRUE)[coeur, , drop = FALSE]
    M <- t(A)
    cp <- capt$capteur[match(paste(s, dates), paste(capt$serie, capt$date))]
    R[[s]] <- ratio_pixels(M, xa)
    niv <- 10 * log10(apply(M, 1, median, na.rm = TRUE))
    info[[s]] <- data.frame(serie = s, date = dates, capteur = cp, comp = composition_ma(cp, xa),
                            niveau_db = niv)
    cat(s, ":", length(dates), "dates,", sum(coeur), "pixels de coeur de foret\n")
    rm(A, M)
  }
  # Pixels stables. Une detection = ratio sous ts a deux dates successives
  # d une orbite (approximation du seuil de segmentation, sans filtre, sans
  # surface minimale). Variante A : exclusion sur toute la serie (facon 029,
  # retire aussi les pixels qui franchissent ts apres la bascule : sous-estime
  # la queue 1C/1D). Variante B : exclusion sur les seules dates avant la
  # bascule (ne retire aucun pixel pour ce qui se passe apres : garde les
  # vraies coupes de juillet a novembre 2026, surestime la queue).
  detecte <- function(jusqu_a) {
    out <- rep(FALSE, sum(coeur))
    for (s in series) {
      k <- info[[s]]$date <= jusqu_a
      Rs <- R[[s]][k, , drop = FALSE]
      b <- Rs < seuils[["ts"]]
      b[is.na(b)] <- FALSE
      if (nrow(b) > 1L) out <- out | colSums(b[-1L, , drop = FALSE] & b[-nrow(b), , drop = FALSE]) > 0
    }
    out
  }
  stable <- list(A = detecte(FIN) == FALSE, B = detecte(BASCULE - 1L) == FALSE)
  cat("Pixels de coeur de foret :", sum(coeur), " ; stables A :", sum(stable$A), " ; stables B :", sum(stable$B), "\n")
  res <- list()
  for (s in series) {
    x <- info[[s]]
    for (v in names(stable)) {
      Rv <- R[[s]][, stable[[v]], drop = FALSE]
      q <- t(apply(Rv, 1, function(z) quantile(z, c(0.25, 0.5, 0.75), na.rm = TRUE, names = FALSE)))
      x[[paste0("med_", v)]] <- q[, 2]
      x[[paste0("sd_", v)]] <- (q[, 3] - q[, 1]) / 1.349
      x[[paste0("tp_", v)]] <- rowMeans(Rv < seuils[["tp"]], na.rm = TRUE)
      x[[paste0("ts_", v)]] <- rowMeans(Rv < seuils[["ts"]], na.rm = TRUE)
      # pour l essai de recalage (question 3) : part sous tp apres retrait de c dB
      # (c en dB, valeurs negatives du decalage mesure) : on garde les quantiles
      # fins du ratio pour pouvoir recalculer la part sous tp a tout recalage
      if (v == "A") {
        qq <- t(apply(Rv, 1, function(z) quantile(z, seq(0.001, 0.2, by = 0.001), na.rm = TRUE, names = FALSE)))
        x$quant_A <- I(split(qq, row(qq)))
      }
    }
    res[[s]] <- x
  }
  df <- do.call(rbind, res)
  rownames(df) <- NULL
  saveRDS(list(df = df, seuils = seuils, xa = xa, npix = sum(coeur), stables = lapply(stable, sum),
               part_coeur = f$part, part_foret_6km = f$part_foret_6km),
          file.path(d, "mesure.rds"))
  cat("Ecrit :", file.path(d, "mesure.rds"), "\n")
}

# Question 4 : 1C (puis 1D) et 1A en meme temps, meme orbite
if (ETAPE == "recouvrement") {
  d <- dir_tuile(TUILE)
  f <- readRDS(file.path(d, "fenetre.rds"))
  g <- lire_fenetre(d)
  tous <- parametres_sufosat(capteurs = list("2014-04-03" = c("S1A", "S1C", "S1D")))
  it <- s1_rechercher(g, as.Date("2025-03-01"), BASCULE - 1L, parametres = tous)
  saveRDS(it, file.path(d, "items-recouvrement.rds"))
  neuf <- it[it$capteur != "S1A", ]
  rep <- file.path(d, "images-recouvrement")
  fich <- if (dir.exists(rep)) list.files(rep, pattern = "tif$", recursive = TRUE) else character(0)
  cle <- paste0("s1_", neuf$serie, "/", format(neuf$date), ".tif")
  if (any(cle %in% fich == FALSE)) s1_lire(neuf[cle %in% fich == FALSE, ], g, dossier = rep, flux = 4L)
  coeur <- as.vector(t(f$coeur))
  capt <- unique(it[, c("serie", "date", "capteur")])
  its <- readRDS(file.path(d, "items.rds"))
  out <- list()
  for (s in sort(unique(capt$serie))) {
    cs <- capt[capt$serie == s, ]
    cs <- cs[order(cs$date), ]
    cs$fichier <- ifelse(cs$capteur == "S1A", file.path(d, "images", paste0("s1_", s), paste0(format(cs$date), ".tif")),
                         file.path(rep, paste0("s1_", s), paste0(format(cs$date), ".tif")))
    cs <- cs[file.exists(cs$fichier), ]
    A <- terra::values(terra::rast(cs$fichier), mat = TRUE)[coeur, , drop = FALSE]
    cs$mois <- format(cs$date, "%Y-%m")
    for (mo in unique(cs$mois)) {
      k <- cs$mois == mo
      ma <- rowMeans(A[, k & cs$capteur == "S1A", drop = FALSE], na.rm = TRUE)
      for (c2 in c("S1C", "S1D")) {
        kk <- k & cs$capteur == c2
        if (sum(kk) < 2L || sum(k & cs$capteur == "S1A") < 2L) next
        mc <- rowMeans(A[, kk, drop = FALSE], na.rm = TRUE)
        r <- 10 * log10(mc / ma)
        q <- quantile(r, c(0.25, 0.5, 0.75), na.rm = TRUE, names = FALSE)
        out[[length(out) + 1L]] <- data.frame(tuile = TUILE, serie = s, mois = mo, capteur = c2,
                                              n_A = sum(k & cs$capteur == "S1A"), n_C = sum(kk),
                                              med_db = q[2], sd_db = (q[3] - q[1]) / 1.349)
      }
    }
    cat(s, ":", nrow(cs), "images\n")
    rm(A)
  }
  saveRDS(do.call(rbind, out), file.path(d, "recouvrement.rds"))
}

if (ETAPE == "recouvrement-synthese") {
  noms <- names(TUILES)[file.exists(file.path(DOSSIER, names(TUILES), "recouvrement.rds"))]
  R4 <- do.call(rbind, lapply(noms, function(n) readRDS(file.path(DOSSIER, n, "recouvrement.rds"))))
  cat("\n## Question 4 : VH moyen du mois de 1C (ou 1D) moins celui de 1A, meme orbite, pixels de coeur de foret (dB)\n")
  cat("(au moins deux images de chaque capteur dans le mois ; mediane des pixels ; par tuile-orbite : moyenne des mois, ecart-type des mois, nombre de mois)\n")
  for (c2 in c("S1C", "S1D")) {
    x <- R4[R4$capteur == c2, ]
    if (nrow(x) == 0L) next
    ag <- aggregate(med_db ~ tuile + serie, x, function(z) c(moy = mean(z), sd = sd(z), n = length(z)))
    ag <- cbind(ag[, 1:2], as.data.frame(ag$med_db))
    ag$erreur_std <- ag$sd / sqrt(ag$n)
    cat("\n", c2, "contre S1A\n")
    print(transform(ag, moy = round(moy, 3), sd = round(sd, 3), erreur_std = round(erreur_std, 3)), row.names = FALSE)
    cat("Toutes tuile-orbites, ", c2, " : moyenne des moyennes ", round(mean(ag$moy), 3), " dB ; ecart-type entre tuile-orbites ",
        round(sd(ag$moy), 3), " ; min ", round(min(ag$moy), 3), " ; max ", round(max(ag$moy), 3), " ; ecart robuste des pixels (mediane) ",
        round(median(x$sd_db), 3), "\n", sep = "")
  }
  x <- R4[R4$capteur == "S1C", ]
  cat("\n## S1C moins S1A par mois (toutes tuile-orbites : moyenne, ecart-type)\n")
  print(aggregate(med_db ~ mois, x, function(z) round(c(moy = mean(z), sd = sd(z), n = length(z)), 3)), row.names = FALSE)
}

# Resume d un groupe de dates : moyenne par date de la mediane, de l ecart
# robuste et de la part sous tp
if (ETAPE == "synthese") {
  noms <- names(TUILES)[file.exists(file.path(DOSSIER, names(TUILES), "mesure.rds"))]
  cat("Tuiles mesurees :", paste(noms, collapse = ", "), "\n")
  tout <- list()
  for (n in noms) {
    m <- readRDS(file.path(DOSSIER, n, "mesure.rds"))
    x <- m$df
    x$tuile <- n
    tout[[n]] <- x
  }
  df <- do.call(rbind, tout)
  rownames(df) <- NULL
  df$annee <- as.integer(format(df$date, "%Y"))
  df$doy <- as.integer(format(df$date, "%j"))
  df$mois <- as.integer(format(df$date, "%m"))
  tp <- m$seuils[["tp"]]
  ts <- m$seuils[["ts"]]
  cat("\nSeuils effectifs : ts =", ts, "dB ; tp =", tp, "dB\n")

  cat("\n## Tuiles : pixels\n")
  print(do.call(rbind, lapply(noms, function(n) {
    m <- readRDS(file.path(DOSSIER, n, "mesure.rds"))
    data.frame(tuile = n, foret_6km = round(m$part_foret_6km, 3), coeur_fenetre = round(m$part_coeur, 3),
               pixels_coeur = m$npix, stables_A = m$stables$A, stables_B = m$stables$B)
  })), row.names = FALSE)

  cat("\n## Orbites, dates par capteur depuis le 2026-06-30\n")
  ap <- df[df$date >= BASCULE, ]
  print(table(tuile = ap$tuile, serie = ap$serie, capteur = ap$capteur))

  # Groupe 1C/1D : dates dont la fenetre Ma ne contient que du 1C/1D.
  # Reference : dates 1A seul, memes jours de l annee, annees ANNEES_REF.
  grp <- df[is.na(df$comp) == FALSE & df$comp == "1C/1D", ]
  cat("\n## Fenetres Ma tout-1C/1D : dates par tuile et orbite\n")
  print(aggregate(date ~ tuile + serie, grp, function(x) paste(format(min(x)), format(max(x)), length(x), sep = " | ")), row.names = FALSE)

  cle <- unique(grp[, c("tuile", "serie")])
  stat <- function(x, v) c(med = mean(x[[paste0("med_", v)]]), sd = mean(x[[paste0("sd_", v)]]),
                           tp = mean(x[[paste0("tp_", v)]]), n = nrow(x))
  lig <- list()
  for (k in seq_len(nrow(cle))) {
    t <- cle$tuile[k]
    s <- cle$serie[k]
    x <- df[df$tuile == t & df$serie == s, ]
    g <- x[x$comp == "1C/1D" & is.na(x$comp) == FALSE, ]
    d0 <- min(g$doy)
    d1 <- max(g$doy)
    ref <- x[x$comp == "1A" & is.na(x$comp) == FALSE & x$annee %in% ANNEES_REF & x$doy >= d0 & x$doy <= d1, ]
    for (v in c("A", "B")) {
      a26 <- stat(g, v)
      par_an <- sapply(ANNEES_REF, function(y) stat(ref[ref$annee == y, ], v))
      colnames(par_an) <- ANNEES_REF
      lig[[length(lig) + 1L]] <- data.frame(
        tuile = t, orbite = s, variante = v, jours = paste0(d0, "-", d1), n26 = a26[["n"]],
        med_1cd = a26[["med"]], med_1a = mean(par_an["med", ]), sd_an_med = sd(par_an["med", ]),
        decalage_med = a26[["med"]] - mean(par_an["med", ]),
        sd_1cd = a26[["sd"]], sd_1a = mean(par_an["sd", ]), rapport_sd = a26[["sd"]] / mean(par_an["sd", ]),
        tp_1cd = a26[["tp"]], tp_1a = mean(par_an["tp", ]), tp_1a_max = max(par_an["tp", ]), tp_1a_min = min(par_an["tp", ]),
        z_med = (a26[["med"]] - mean(par_an["med", ])) / sd(par_an["med", ]),
        rang_med = sum(par_an["med", ] < a26[["med"]]) + 1L,
        rang_tp = sum(par_an["tp", ] > a26[["tp"]]) + 1L
      )
    }
  }
  T1 <- do.call(rbind, lig)
  rownames(T1) <- NULL
  saveRDS(T1, file.path(DOSSIER, "table1.rds"))
  cat("\n## Question 1 : par tuile et orbite, fenetres tout-1C/1D contre tout-1A (memes jours de l annee, 2020-2025)\n")
  cat("(med en dB ; sd = ecart robuste en dB ; tp = part des pixels sous tp ; decalage = med 1C/1D - moyenne des annees 1A ;",
      "sd_an = ecart-type des moyennes annuelles 1A ; z = decalage / sd_an ; rang_med = rang de la mediane 2026 parmi 7 annees, 1 = la plus basse ; rang_tp = rang de la part sous tp 2026, 1 = la plus haute)\n")
  print(transform(T1[T1$variante == "A", ], med_1cd = round(med_1cd, 3), med_1a = round(med_1a, 3),
                  sd_an_med = round(sd_an_med, 3), decalage_med = round(decalage_med, 3),
                  sd_1cd = round(sd_1cd, 3), sd_1a = round(sd_1a, 3), rapport_sd = round(rapport_sd, 3),
                  tp_1cd = round(tp_1cd, 4), tp_1a = round(tp_1a, 4), tp_1a_min = round(tp_1a_min, 4),
                  tp_1a_max = round(tp_1a_max, 4), z_med = round(z_med, 2)), row.names = FALSE)
  cat("\n## Variante B (stabilite jugee avant la bascule seulement)\n")
  print(transform(T1[T1$variante == "B", c("tuile", "orbite", "n26", "med_1cd", "med_1a", "decalage_med", "rapport_sd",
                                           "tp_1cd", "tp_1a", "tp_1a_max")],
                  med_1cd = round(med_1cd, 3), med_1a = round(med_1a, 3), decalage_med = round(decalage_med, 3),
                  rapport_sd = round(rapport_sd, 3), tp_1cd = round(tp_1cd, 4), tp_1a = round(tp_1a, 4),
                  tp_1a_max = round(tp_1a_max, 4)), row.names = FALSE)

  cat("\n## Question 2 : constance du decalage (variante A)\n")
  TA <- T1[T1$variante == "A", ]
  cat("Decalage de la mediane (dB) : min", round(min(TA$decalage_med), 3), " ; mediane", round(median(TA$decalage_med), 3),
      " ; max", round(max(TA$decalage_med), 3), " ; ecart-type entre tuile-orbites", round(sd(TA$decalage_med), 3),
      " ; n =", nrow(TA), "\n")
  cat("Orbites dont le decalage depasse 2,57 ecarts-types entre annees (t a 5 ddl, 5 %) :", sum(abs(TA$z_med) > 2.57), "sur", nrow(TA),
      " ; negatifs :", sum(TA$decalage_med < 0), " ; positifs :", sum(TA$decalage_med > 0), "\n")
  cat("Part sous tp 2026 (1C/1D) au-dessus de toutes les annees 1A :", sum(TA$rang_tp == 1L), "orbites sur", nrow(TA),
      " ; dans la fourchette des annees 1A :", sum(TA$tp_1cd <= TA$tp_1a_max), "\n")
  cat("Ecart-type entre annees 1A (meme tuile-orbite, meme saison), mediane des tuile-orbites :", round(median(TA$sd_an_med), 3), "dB\n")
  cat("Par tuile (moyenne des orbites) :\n")
  print(round(tapply(TA$decalage_med, TA$tuile, mean), 3))
  cat("Par orbite relative, toutes tuiles :\n")
  print(round(tapply(TA$decalage_med, TA$orbite, mean), 3))
  cat("Ecart entre orbites d une meme tuile (max - min), par tuile :\n")
  print(round(tapply(TA$decalage_med, TA$tuile, function(z) max(z) - min(z)), 3))

  # Temoin : meme calcul sur les fenetres tout-1A de janvier a mai 2026 (avant la
  # bascule), contre les memes jours des annees 2020-2025. Si le temoin n est
  # pas proche de 0, le decalage a la reference des annees precedentes contient
  # une derive qui n est pas due au capteur.
  tem <- list()
  for (k in seq_len(nrow(cle))) {
    x <- df[df$tuile == cle$tuile[k] & df$serie == cle$serie[k] & is.na(df$comp) == FALSE, ]
    a <- x[x$comp == "1A" & x$annee == 2026L & x$doy <= 150L, ]
    ref <- sapply(ANNEES_REF, function(y) mean(x$med_A[x$comp == "1A" & x$annee == y & x$doy <= 150L]))
    reftp <- sapply(ANNEES_REF, function(y) mean(x$tp_A[x$comp == "1A" & x$annee == y & x$doy <= 150L]))
    tem[[k]] <- data.frame(tuile = cle$tuile[k], orbite = cle$serie[k], n = nrow(a),
                           decalage_temoin = mean(a$med_A) - mean(ref), sd_an = sd(ref),
                           tp_2026 = mean(a$tp_A), tp_ref = mean(reftp))
  }
  TEM <- do.call(rbind, tem)
  TEM$decalage_moins_temoin <- vapply(seq_len(nrow(TEM)), function(i)
    T1$decalage_med[T1$variante == "A" & T1$tuile == TEM$tuile[i] & T1$orbite == TEM$orbite[i]] - TEM$decalage_temoin[i], 0)
  cat("\n## Temoin : fenetres tout-1A de janvier a mai 2026 contre les memes jours de 2020-2025 (dB)\n")
  TEM[, 4:8] <- round(TEM[, 4:8], 4)
  print(TEM, row.names = FALSE)
  cat("Temoin : moyenne", round(mean(TEM$decalage_temoin), 3), " ; min", round(min(TEM$decalage_temoin), 3),
      " ; max", round(max(TEM$decalage_temoin), 3), "\n")
  cat("Decalage 1C/1D moins temoin : moyenne", round(mean(TEM$decalage_moins_temoin), 3), " ; min", round(min(TEM$decalage_moins_temoin), 3),
      " ; max", round(max(TEM$decalage_moins_temoin), 3), " ; ecart-type", round(sd(TEM$decalage_moins_temoin), 3), "\n")

  # Par mois de 2026 : decalage a la moyenne des annees 1A du meme mois
  cat("\n## Decalage de la mediane par mois (fenetres tout-1C/1D du mois contre tout-1A du meme mois, 2020-2025), dB\n")
  mm <- list()
  for (k in seq_len(nrow(cle))) {
    x <- df[df$tuile == cle$tuile[k] & df$serie == cle$serie[k] & is.na(df$comp) == FALSE, ]
    for (mo in 7:11) {
      g <- x[x$comp == "1C/1D" & x$annee == 2026L & x$mois == mo, ]
      if (nrow(g) < 2L) next
      ref <- sapply(ANNEES_REF, function(y) {
        r <- x[x$comp == "1A" & x$annee == y & x$mois == mo, ]
        if (nrow(r) == 0L) NA_real_ else mean(r$med_A)
      })
      mm[[length(mm) + 1L]] <- data.frame(tuile = cle$tuile[k], orbite = cle$serie[k], mois = mo, n = nrow(g),
                                          decalage = mean(g$med_A) - mean(ref, na.rm = TRUE), sd_an = sd(ref, na.rm = TRUE))
    }
  }
  MM <- do.call(rbind, mm)
  saveRDS(MM, file.path(DOSSIER, "table_mois.rds"))
  W <- reshape(MM[, c("tuile", "orbite", "mois", "decalage")], idvar = c("tuile", "orbite"), timevar = "mois", direction = "wide")
  W[, -(1:2)] <- round(W[, -(1:2)], 2)
  print(W, row.names = FALSE)
  cat("Ecart-type des decalages mensuels au sein d une meme tuile-orbite (moyenne) :",
      round(mean(tapply(MM$decalage, paste(MM$tuile, MM$orbite), sd), na.rm = TRUE), 3), "dB\n")
  cat("Ecart-type des annees 1A (meme mois) :", round(mean(MM$sd_an, na.rm = TRUE), 3), "dB\n")
  cat("Tendance du decalage avec le mois (pente par mois, dB), par tuile-orbite :\n")
  print(round(tapply(seq_len(nrow(MM)), paste(MM$tuile, MM$orbite), function(i) if (length(i) > 2L) coef(lm(decalage ~ mois, MM[i, ]))[["mois"]] else NA), 3))

  # Niveau VH par capteur (1C, 1D) apres la bascule contre 1A le meme jour de l annee
  cat("\n## Niveau VH median des pixels de coeur de foret (dB) : 1C, 1D depuis 2026-07-01 contre 1A aux memes jours, 2020-2025\n")
  nv <- list()
  for (k in seq_len(nrow(cle))) {
    x <- df[df$tuile == cle$tuile[k] & df$serie == cle$serie[k], ]
    a <- x[x$date >= as.Date("2026-07-01"), ]
    d0 <- min(a$doy)
    d1 <- max(a$doy)
    r <- x[x$capteur == "S1A" & x$annee %in% ANNEES_REF & x$doy >= d0 & x$doy <= d1, ]
    a1 <- mean(tapply(r$niveau_db, r$annee, mean))
    sda <- sd(tapply(r$niveau_db, r$annee, mean))
    nv[[k]] <- data.frame(tuile = cle$tuile[k], orbite = cle$serie[k],
                          ecart_1C = mean(a$niveau_db[a$capteur == "S1C"]) - a1,
                          ecart_1D = mean(a$niveau_db[a$capteur == "S1D"]) - a1, sd_an = sda,
                          n_1C = sum(a$capteur == "S1C"), n_1D = sum(a$capteur == "S1D"))
  }
  NV <- do.call(rbind, nv)
  NV[, 3:5] <- round(NV[, 3:5], 3)
  print(NV, row.names = FALSE)

  # Question 3 : part sous tp apres recalage constant
  cat("\n## Question 3 : part de foret stable sous tp (variante A) apres retrait d un recalage constant du ratio 1C/1D\n")
  cat("(essai de sensibilite : le ratio 1C/1D est decale de -c dB ; c = decalage mesure, soit propre a la tuile-orbite,",
      "soit la mediane des decalages de toutes les tuile-orbites ; reference = part 1A)\n")
  c_commun <- median(TA$decalage_med)
  q3 <- list()
  for (k in seq_len(nrow(cle))) {
    x <- df[df$tuile == cle$tuile[k] & df$serie == cle$serie[k] & is.na(df$comp) == FALSE, ]
    g <- x[x$comp == "1C/1D", ]
    ta <- TA[TA$tuile == cle$tuile[k] & TA$orbite == cle$serie[k], ]
    part <- function(c) {
      mean(vapply(seq_len(nrow(g)), function(i) {
        q <- g$quant_A[[i]]
        # part des pixels dont ratio - c < tp, depuis les quantiles 0,1 % a 20 % (interpolation)
        pr <- seq(0.001, 0.2, by = 0.001)
        s <- tp + c
        if (s <= q[1]) 0 else if (s >= q[length(q)]) 0.2 else approx(q, pr, xout = s, ties = "ordered")$y
      }, 0))
    }
    q3[[k]] <- data.frame(tuile = cle$tuile[k], orbite = cle$serie[k], decalage = ta$decalage_med,
                          tp_1a = ta$tp_1a, tp_1cd_sans = part(0), tp_1cd_recal_propre = part(ta$decalage_med),
                          tp_1cd_recal_commun = part(c_commun))
  }
  Q3 <- do.call(rbind, q3)
  cat("Recalage commun (mediane des decalages) :", round(c_commun, 3), "dB\n")
  Q3[, 3:7] <- round(Q3[, 3:7], 4)
  print(Q3, row.names = FALSE)
  cat("Rapport tp 1C/1D / tp 1A : sans recalage mediane", round(median(Q3$tp_1cd_sans / Q3$tp_1a), 2),
      "; recalage propre", round(median(Q3$tp_1cd_recal_propre / Q3$tp_1a), 2),
      "; recalage commun", round(median(Q3$tp_1cd_recal_commun / Q3$tp_1a), 2), "\n")
}

# Controle du calcul (sans reseau) : ratio_pixels() contre la definition
# ecrite a la main, composition_ma() sur un cas connu, aller-retour dB.
if (ETAPE == "controle") {
  set.seed(1L)
  M <- matrix(rexp(12 * 5, rate = 1 / 0.04), 12, 5)
  M[3, 2] <- NA
  R <- ratio_pixels(M, 3L)
  naif <- function(j, i) {
    ma <- mean(M[(i + 1L):(i + 3L), j], na.rm = TRUE)
    mb <- mean(M[1:i, j], na.rm = TRUE)
    10 * log10(ma / mb)
  }
  ecart <- max(abs(vapply(1:5, function(j) max(abs(vapply(1:9, function(i) R[i, j] - naif(j, i), 0))), 0)))
  cat("Ecart maximal ratio_pixels() / definition (dB) :", ecart, "\n")
  stopifnot(ecart < 1e-9, all(is.na(R[10:12, ])))
  cp <- c("S1A", "S1A", "S1A", "S1A", "S1C", "S1D", "S1C", "S1D")
  stopifnot(identical(composition_ma(cp, 3L), c("1A", "mixte", "mixte", "1C/1D", "1C/1D", NA, NA, NA)))
  stopifnot(abs(db_vers_lineaire(lineaire_vers_db(0.25)) - 0.25) < 1e-12, abs(lineaire_vers_db(db_vers_lineaire(-3.45)) + 3.45) < 1e-12)
  cat("Controle : ok\n")
}
