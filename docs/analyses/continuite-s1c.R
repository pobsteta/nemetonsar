# Mission 029 : detections 2026 et continuite Sentinel-1A vers 1C/1D.
# Script reproductible, aucune modification du package. A lancer depuis la
# racine du depot : Rscript docs/analyses/continuite-s1c.R DOSSIER ETAPE ARG
#
# DOSSIER : dossier de travail, HORS du depot.
# ETAPE :
#   orbites  : s1_rechercher() sur l AOI, 2025-01-01 a FIN (question 1) ;
#   executer : nemetonsar_run(), reglages par defaut, du 2018-01-01 a FIN
#              (question 2). Le debut est 2018 et non 2025 : la reference Mb du
#              ratio est la moyenne de TOUTES les images anterieures (xb = Inf)
#              et le noyau du filtre est 2018 ; une serie commencee en 2025 ne
#              reproduirait pas l execution de la mission 017 ;
#   resumer  : objets par trimestre, delai de detection (question 4), trois
#              coupes a controler apres le 2026-06-30 ;
#   signal   : niveau VH et dispersion du ratio sur des pixels de foret sans
#              coupe, avant et apres le 2026-06-30 (question 3) ;
#   controle : ARG = dossier des sorties de 017 ; objets de 2025-01 a 2025-09.
#   synthese : tableaux de la question 3 depuis signal.rds (niveau par saison
#              et par annee, saut au 30 juin, ratio selon les capteurs de la
#              fenetre Ma) ; sans reseau. signal relit les images deja lues
#              sur le disque si elles y sont (dossier signal-images).
#
# AOI et masque BD Foret WFS : ceux de la mission 017
# (docs/analyses/pilote-landes.R). Aucune image Sentinel-1 n est ecrite au
# depot. Graine fixee.

args <- commandArgs(trailingOnly = TRUE)
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
ARG <- args[3]
stopifnot(file.exists("DESCRIPTION"), dir.exists("R"))
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
SORTIES <- file.path(DOSSIER, "sorties")
set.seed(20261124L)
suppressMessages(pkgload::load_all(".", quiet = TRUE))

POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2026-11-21")
DEBUT_ANALYSE <- as.Date("2025-01-01")
BASCULE <- as.Date("2026-06-30")
FIN_017 <- as.Date("2025-09-30")

ll <- "EPSG:4326"
l93 <- "EPSG:2154"
pt <- terra::vect(rbind(POINT), crs = ll)
p <- terra::project(pt, l93)
xy <- terra::crds(p)
centre <- terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = l93)
AOI <- terra::buffer(centre, COTE_M / 2, capstyle = "square")

# Question 1 : capteurs et orbites servis par le STAC
if (ETAPE == "orbites") {
  it <- s1_rechercher(AOI, DEBUT_ANALYSE, FIN)
  saveRDS(it, file.path(DOSSIER, "items-2025-2026.rds"))
  it <- unique(it[, c("serie", "date", "capteur")])
  it$mois <- format(it$date, "%Y-%m")
  cat("Images (une par orbite et par date) :", nrow(it), " ; derniere date :", format(max(it$date)), "\n")
  cat("\n## Capteur par annee\n")
  print(table(it$capteur, format(it$date, "%Y")))
  cat("\n## Orbite relative par capteur\n")
  print(table(it$serie, it$capteur))
  cat("\n## Capteur par mois\n")
  print(table(it$mois, it$capteur))
  cat("\n## Premiere et derniere date par capteur\n")
  print(aggregate(date ~ capteur, it, function(d) format(range(d))))
  it <- it[order(it$serie, it$date), ]
  it$ecart_j <- ave(as.numeric(it$date), it$serie, FUN = function(x) c(NA, diff(x)))
  it$periode <- ifelse(it$date >= BASCULE, "apres", "avant")
  cat("\n## Ecart (jours) entre images successives, par orbite\n")
  print(aggregate(ecart_j ~ serie + periode, it,
                  function(x) c(n = length(x), moy = round(mean(x), 1), max = max(x))))
}

# Question 2 : la chaine va-t-elle au bout
if (ETAPE == "executer") {
  terra::writeVector(AOI, file.path(DOSSIER, "aoi.gpkg"), overwrite = TRUE)
  t0 <- Sys.time()
  res <- tryCatch(
    nemetonsar_run(AOI, DEBUT, FIN, dossier = SORTIES, bdforet = "wfs",
                   parametres = parametres_sufosat()),
    error = function(e) e
  )
  t1 <- Sys.time()
  echec <- inherits(res, "error")
  erreur <- NA_character_
  if (echec) erreur <- conditionMessage(res)
  mesures <- list(debut = t0, fin = t1, duree_h = as.numeric(difftime(t1, t0, units = "hours")),
                  periode = c(DEBUT, FIN), erreur = erreur)
  if (echec) res <- NULL
  saveRDS(list(res = res, mesures = mesures), file.path(DOSSIER, "execution.rds"))
  str(mesures)
  if (echec) stop(erreur, call. = FALSE)
  print(res$tuiles)
}

# Question 4 : objets par trimestre, delai de detection, trois coupes a controler
if (ETAPE == "resumer") {
  ex <- readRDS(file.path(DOSSIER, "execution.rds"))
  res <- ex$res
  tab <- res$objets
  d <- tab$date_mediane_date
  tab$annee <- as.integer(format(d, "%Y"))
  tab$trimestre <- paste0(tab$annee, "T", (as.integer(format(d, "%m")) - 1L) %/% 3L + 1L)
  nb <- tapply(tab$surface_ha, tab$trimestre, length)
  ha <- tapply(tab$surface_ha, tab$trimestre, sum)
  par_tri <- data.frame(trimestre = names(nb), objets = as.integer(nb), surface_ha = round(as.numeric(ha), 1))
  cat("\n## Objets par trimestre (date mediane)\n")
  print(par_tri, row.names = FALSE)
  ancien <- tab$annee >= 2019L & tab$annee <= 2024L
  cat("\nMoyenne par trimestre 2019-2024 :", round(sum(ancien) / 24, 1), "objets,",
      round(sum(tab$surface_ha[ancien]) / 24, 1), "ha\n")
  apres_sep <- d > FIN_017
  apres_bascule <- d >= BASCULE
  cat("\nObjets apres 2025-09-30 :", sum(apres_sep), "(", round(sum(tab$surface_ha[apres_sep]), 1), "ha )\n")
  cat("Objets a partir du 2026-06-30 :", sum(apres_bascule), "(", round(sum(tab$surface_ha[apres_bascule]), 1), "ha )\n")
  cat("\n## Objets par mois, 2025-10 a la fin\n")
  mois <- format(d[apres_sep], "%Y-%m")
  print(data.frame(mois = names(table(mois)), objets = as.integer(table(mois)),
                   surface_ha = round(as.numeric(tapply(tab$surface_ha[apres_sep], mois, sum)), 1)),
        row.names = FALSE)
  cat("\n## Nature des objets : ratio moyen (dB) et surface mediane, par periode de la date\n")
  tab$periode <- ifelse(d >= BASCULE & d < BASCULE + 30, "30 jours apres la bascule",
                  ifelse(d >= BASCULE, "plus de 30 jours apres la bascule",
                   ifelse(d > FIN_017, "2025-10 a 2026-06-29",
                    ifelse(d >= as.Date("2019-01-01"), "2019 a 2025-09", "avant"))))
  g <- split(tab, tab$periode)
  print(data.frame(periode = names(g), objets = vapply(g, nrow, 0L),
                   ratio_moyen_mediane = vapply(g, function(x) round(median(x$ratio_moyen_db), 2), 0),
                   surface_mediane_ha = vapply(g, function(x) round(median(x$surface_ha), 2), 0),
                   part_sous_1_ha = vapply(g, function(x) round(mean(x$surface_ha < 1), 2), 0)), row.names = FALSE)
  # Delai de detection : jours entre la date de l objet et la xa-ieme image
  # (a partir de cette date) de la meilleure orbite (combinaison minimum)
  it <- readRDS(file.path(DOSSIER, "items-2025-2026.rds"))
  jours <- lapply(split(as.Date(it$date), it$serie), function(x) sort(unique(x)))
  xa <- parametres_sufosat()$xa
  rang <- function(dd, x) x[which(x >= dd)[xa]]
  delai <- function(dd) suppressWarnings(min(vapply(jours, function(x) as.numeric(rang(dd, x) - dd), 0), na.rm = TRUE))
  cat("\nDernier jour detectable (xa-ieme image avant la fin, meilleure orbite) :",
      format(max(vapply(jours, function(x) as.numeric(x[length(x) - xa + 1L]), 0)) + as.Date(0)), "\n")
  apres <- tab[apres_sep, ]
  apres$delai_j <- vapply(apres$date_mediane_date, delai, 0)
  apres$periode <- ifelse(apres$date_mediane_date >= BASCULE, "apres 2026-06-30", "2025-10 a 2026-06-29")
  cat("\n## Delai (jours) jusqu a la xa-ieme image, par periode\n")
  for (p in unique(apres$periode)) {
    x <- apres$delai_j[apres$periode == p]
    cat(p, ": n =", length(x), " ; moyenne", round(mean(x), 1), " ; mediane", median(x), " ; max", max(x), "\n")
  }
  cat("\n## Delai theorique par orbite et periode (jours de la 1re a la xa-ieme image, moyenne)\n")
  for (s in names(jours)) {
    x <- jours[[s]]
    n <- length(x)
    dl <- as.numeric(x[xa:n] - x[1:(n - xa + 1L)])
    av <- x[1:(n - xa + 1L)] < BASCULE
    cat(s, ": avant", round(mean(dl[av]), 1), " ; apres", round(mean(dl[av == FALSE]), 1), "\n")
  }
  poly <- terra::vect(file.path(SORTIES, "objets.gpkg"), layer = "objets")
  # Un objet qui mele des pixels dates avant et apres la bascule est un mauvais
  # candidat : on garde ceux dont 75 % des pixels dates au moins le sont
  # a partir du 2026-06-30.
  idm <- terra::values(terra::rast(file.path(SORTIES, "objets.tif")), mat = FALSE)
  dtm <- terra::values(terra::rast(file.path(SORTIES, "dates.tif")), mat = FALSE)
  dtm[is.na(dtm)] <- 0
  code_bascule <- as.integer(format(BASCULE, "%y%j"))
  part_apres <- function(id) {
    k <- which(idm == id & dtm > 0)
    mean(dtm[k] >= code_bascule)
  }
  cand30 <- tab[d >= BASCULE & d < BASCULE + 30, ]
  cand30$part_apres <- vapply(cand30$identifiant, part_apres, 0)
  cat("\n## Objets des 30 jours apres la bascule : part des pixels dates apres la bascule\n")
  print(utils::head(cand30[order(-cand30$surface_ha), c("identifiant", "surface_ha", "date_mediane_date", "part_apres")], 5), row.names = FALSE)
  cand30 <- cand30[cand30$part_apres >= 0.75, ]
  cand_apres <- tab[d >= BASCULE + 30, ]
  choix <- c(head(cand30$identifiant[order(-cand30$surface_ha)], 2), head(cand_apres$identifiant[order(-cand_apres$surface_ha)], 1))
  sel <- poly[poly$identifiant %in% choix, ]
  ctr <- terra::centroids(sel, inside = TRUE)
  ll <- terra::crds(terra::project(ctr, "EPSG:4326"))
  l93 <- terra::crds(ctr)
  controle <- data.frame(identifiant = sel$identifiant, surface_ha = round(sel$surface_ha, 2),
                         date_mediane = format(as.Date(sel$date_mediane_date)),
                         lon = round(ll[, 1], 5), lat = round(ll[, 2], 5),
                         x_l93 = round(l93[, 1]), y_l93 = round(l93[, 2]))
  controle$part_apres <- round(vapply(controle$identifiant, part_apres, 0), 2)
  k_ctr <- terra::cells(terra::rast(file.path(SORTIES, "dates.tif")), ctr)[, 2]
  controle$date_au_centroide <- format(as.Date(paste0("20", dtm[k_ctr] %/% 1000, "-01-01")) + (dtm[k_ctr] %% 1000) - 1)
  cat("\n## Trois coupes datees apres le 2026-06-30, a controler\n")
  print(controle, row.names = FALSE)
  saveRDS(list(par_tri = par_tri, apres = apres, controle = controle), file.path(DOSSIER, "resume.rds"))
}

# Controle : 2025-01 a 2025-09 de cette execution contre l execution de 017
# ARG = dossier des sorties de 017 (le dates.tif de 017 reste hors du depot)
if (ETAPE == "controle") {
  ref <- terra::values(terra::rast(file.path(ARG, "dates.tif")), mat = FALSE)
  neuf <- terra::values(terra::rast(file.path(SORTIES, "dates.tif")), mat = FALSE)
  bas <- as.integer(format(DEBUT_ANALYSE, "%y%j"))
  haut <- as.integer(format(FIN_017, "%y%j"))
  dans <- function(v) is.na(v) == FALSE & v >= bas & v <= haut
  a <- dans(ref)
  b <- dans(neuf)
  cat("\nPixels dates entre", bas, "et", haut, "(YYDDD)\n")
  cat("  017 :", sum(a), " ; 029 :", sum(b), "\n")
  cat("  dans les deux, meme date :", sum(a & b & ref == neuf, na.rm = TRUE), "\n")
  cat("  dans les deux, date differente :", sum(a & b & ref != neuf, na.rm = TRUE), "\n")
  cat("  seulement 017 :", sum(a & b == FALSE), " ; seulement 029 :", sum(b & a == FALSE), "\n")
  seul <- neuf[b & a == FALSE]
  if (length(seul) > 0L) print(summary(seul))
  seul <- ref[a & b == FALSE]
  if (length(seul) > 0L) print(summary(seul))
  o17 <- readRDS(file.path(dirname(ARG), "execution.rds"))$res$objets
  o29 <- readRDS(file.path(DOSSIER, "execution.rds"))$res$objets
  f17 <- o17$date_mediane_date >= DEBUT_ANALYSE & o17$date_mediane_date <= FIN_017
  f29 <- o29$date_mediane_date >= DEBUT_ANALYSE & o29$date_mediane_date <= FIN_017
  cat("\nObjets dates du", format(DEBUT_ANALYSE), "au", format(FIN_017), ":\n")
  cat("  017 :", sum(f17), "objets,", round(sum(o17$surface_ha[f17]), 2), "ha\n")
  cat("  029 :", sum(f29), "objets,", round(sum(o29$surface_ha[f29]), 2), "ha\n")
  cat("  ensemble de la serie, jusqu au 2025-09-30 : 017", sum(o17$date_mediane_date <= FIN_017),
      "; 029", sum(o29$date_mediane_date <= FIN_017), "\n")
}

# Question 3 : continuite du signal sur des pixels de foret sans coupe
# ARG (facultatif) = dossier des sorties qui donnent masque et objets
# (par defaut celles de cette execution)
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

if (ETAPE == "signal") {
  src <- SORTIES
  if (is.na(ARG) == FALSE) src <- ARG
  tu <- file.path(src, "tuiles", "30TXP")
  masque <- terra::rast(file.path(tu, "masque.tif"))
  obj <- terra::rast(file.path(tu, "objets.tif"))
  obj <- terra::ifel(is.na(obj), 0, obj)
  proche <- terra::focal(obj > 0, w = 7, fun = "max", na.rm = TRUE)
  m <- terra::as.matrix(masque == 1 & proche == 0, wide = TRUE)
  m[is.na(m)] <- FALSE
  cote <- 300L
  best <- c(0, 1, 1)
  for (i in seq(1L, nrow(m) - cote + 1L, by = 50L)) {
    for (j in seq(1L, ncol(m) - cote + 1L, by = 50L)) {
      s <- mean(m[i:(i + cote - 1L), j:(j + cote - 1L)])
      if (s > best[1]) best <- c(s, i, j)
    }
  }
  i0 <- best[2]
  j0 <- best[3]
  cat("Fenetre", cote, "x", cote, "pixels, ligne", i0, "colonne", j0, ": part de pixels stables", round(best[1], 3), "\n")
  stable <- m[i0:(i0 + cote - 1L), j0:(j0 + cote - 1L)]
  grille <- masque[i0:(i0 + cote - 1L), j0:(j0 + cote - 1L), drop = FALSE]
  grille <- terra::rast(grille)
  debut_signal <- as.Date(Sys.getenv("M029_DEBUT_SIGNAL", "2018-01-01"))
  it <- s1_rechercher(AOI, debut_signal, FIN)
  saveRDS(it, file.path(DOSSIER, "items-signal.rds"))
  rep <- file.path(DOSSIER, "signal-images")
  fichiers <- list.files(rep, pattern = "tif$", recursive = TRUE, full.names = TRUE)
  lect <- NULL
  if (length(fichiers) == 0L) lect <- s1_lire(it, grille, dossier = rep, flux = 4L)
  if (is.null(lect)) {
    # images deja lues (une execution precedente) : relues sur le disque
    sr <- basename(dirname(fichiers))
    lect <- list(orbites = list(), dates = list())
    for (s in unique(sr)) {
      f <- sort(fichiers[sr == s])
      lect$orbites[[sub("^s1_", "", s)]] <- terra::rast(f)
      lect$dates[[sub("^s1_", "", s)]] <- as.Date(sub("[.]tif$", "", basename(f)))
    }
  }
  seuils <- seuils_db(parametres_sufosat())
  xa <- parametres_sufosat()$xa
  capt <- unique(it[, c("date", "capteur")])
  cap_date <- setNames(capt$capteur, as.character(capt$date))
  tous <- list()
  for (s in names(lect$orbites)) {
    dates <- lect$dates[[s]]
    A <- terra::values(lect$orbites[[s]], mat = TRUE)
    A <- A[as.vector(t(stable)), , drop = FALSE]
    M <- t(A)
    R <- ratio_pixels(M, xa)
    niveau <- 10 * log10(rowMeans(M, na.rm = TRUE))
    sd_db <- apply(10 * log10(ifelse(M > 0, M, NA)), 1, sd, na.rm = TRUE)
    q <- t(apply(R, 1, function(x) quantile(x, c(0.25, 0.5, 0.75), na.rm = TRUE, names = FALSE)))
    tous[[s]] <- data.frame(serie = s, date = dates, capteur = unname(cap_date[as.character(dates)]),
                            niveau_db = niveau, sd_db = sd_db, ratio_med = q[, 2], ratio_sd = (q[, 3] - q[, 1]) / 1.349,
                            part_ts = rowMeans(R < seuils[["ts"]], na.rm = TRUE),
                            part_tp = rowMeans(R < seuils[["tp"]], na.rm = TRUE))
    cat(s, ":", length(dates), "dates lues\n")
  }
  df <- do.call(rbind, tous)
  rownames(df) <- NULL
  saveRDS(df, file.path(DOSSIER, "signal.rds"))
  write.csv(df, file.path(DOSSIER, "signal.csv"), row.names = FALSE)
}

# Synthese de la question 3 : niveau et ratio, meme saison, avant et apres
if (ETAPE == "synthese") {
  df <- readRDS(file.path(DOSSIER, "signal.rds"))
  df$annee <- as.integer(format(df$date, "%Y"))
  df$mois <- as.integer(format(df$date, "%m"))
  df$saison <- ifelse(df$mois >= 7L | df$date >= BASCULE, "S2", "S1")
  an <- 2022:2026
  cat("\n## Niveau VH moyen (dB) par orbite, annee et saison (S1 : janvier a juin ; S2 : juillet a novembre ; 2022-2025 : 1A seul)\n")
  for (s in unique(df$serie)) {
    t1 <- tapply(df$niveau_db[df$serie == s & df$saison == "S1"], df$annee[df$serie == s & df$saison == "S1"], mean)
    t2 <- tapply(df$niveau_db[df$serie == s & df$saison == "S2"], df$annee[df$serie == s & df$saison == "S2"], mean)
    tab <- data.frame(annee = an, S1 = round(t1[as.character(an)], 3), S2 = round(t2[as.character(an)], 3))
    tab$S2_moins_S1 <- round(tab$S2 - tab$S1, 3)
    cat("\n", s, "\n")
    print(tab, row.names = FALSE)
    ant <- tab[tab$annee <= 2025L, ]
    cat("  2026 contre 2022-2025 : S1 ", round(tab$S1[5] - mean(ant$S1), 3), " (sd des annees ", round(sd(ant$S1), 3), ") ; S2 ",
        round(tab$S2[5] - mean(ant$S2), 3), " (sd ", round(sd(ant$S2), 3), ") ; S2 - S1 ",
        round(tab$S2_moins_S1[5] - mean(ant$S2_moins_S1), 3), " (sd ", round(sd(ant$S2_moins_S1), 3), ")\n")
  }
  cat("\n## Niveau VH (dB), 2026 saison S2, par capteur\n")
  x2 <- df[df$annee == 2026L & df$saison == "S2", ]
  print(aggregate(niveau_db ~ serie + capteur, x2, function(x) round(mean(x), 3)), row.names = FALSE)
  cat("\n## Saut au 30 juin : moyenne des 6 premieres dates a partir du 30 juin moins celle des 6 dernieres avant (dB)\n")
  for (s in unique(df$serie)) {
    sa <- vapply(2019:2026, function(y) {
      x <- df[df$serie == s, ]
      lim <- as.Date(paste0(y, "-06-30"))
      mean(x$niveau_db[which(x$date >= lim)[1:6]]) - mean(x$niveau_db[rev(which(x$date < lim))[1:6]])
    }, 0)
    cat(s, ":", paste(2019:2026, round(sa, 2), sep = "=", collapse = " "), "\n")
  }
  cat("\n## Ratio de changement sur pixels stables (dates avec ratio defini) : mediane, ecart robuste, part sous tp et sous ts\n")
  rat <- df[is.na(df$ratio_med) == FALSE & df$annee >= 2022L, ]
  rat$groupe <- paste0(rat$annee, rat$saison)
  print(aggregate(cbind(ratio_med, ratio_sd, part_tp, part_ts) ~ serie + groupe, rat, function(x) round(mean(x), 4)), row.names = FALSE)
  cat("\n## Dispersion spatiale du niveau VH d une image (ecart-type en dB sur les pixels stables), par capteur, a partir de 2025\n")
  rec <- df[df$annee >= 2025L, ]
  print(aggregate(sd_db ~ serie + capteur, rec, function(x) round(mean(x), 3)), row.names = FALSE)
  cat("\n## Ratio selon les capteurs de la fenetre Ma (les xa images suivantes), dates de 2025-07 a 2026-11\n")
  df$comp <- NA_character_
  for (s in unique(df$serie)) {
    k <- which(df$serie == s)
    cp <- df$capteur[k]
    for (i in seq_len(length(k) - 3L)) {
      v <- cp[(i + 1L):(i + 3L)] == "S1A"
      df$comp[k[i]] <- ifelse(all(v), "Ma 1A", ifelse(any(v), "Ma mixte", "Ma 1C/1D"))
    }
  }
  cmp <- df[df$date >= as.Date("2025-07-01") & is.na(df$comp) == FALSE, ]
  cmp$comp <- paste(cmp$comp, ifelse(cmp$annee == 2025L, "(2025)", "(2026)"))
  print(aggregate(cbind(ratio_med, ratio_sd, part_tp, part_ts) ~ serie + comp, cmp, function(x) round(mean(x), 4)), row.names = FALSE)
  print(aggregate(date ~ serie + comp, cmp, length), row.names = FALSE)
  cat("\n## Autour de la bascule : 6 dernieres images 1A et 6 premieres images 1C/1D par orbite\n")
  for (s in unique(df$serie)) {
    x <- df[df$serie == s, ]
    k <- which(x$date >= BASCULE)[1]
    y <- x[(k - 6L):(k + 5L), c("serie", "date", "capteur", "niveau_db", "ratio_med", "ratio_sd", "part_ts")]
    y[, 4:7] <- round(y[, 4:7], 3)
    print(y, row.names = FALSE)
  }
}
