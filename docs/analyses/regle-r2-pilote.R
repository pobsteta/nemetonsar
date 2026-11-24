# Mission 030 : règle de date R2 sur la tuile pilote des Landes
# ---------------------------------------------------------------------------
# Usage non commercial : la comparaison à la carte SUFOSAT v3.0.1 (CC BY-NC 4.0)
# hérite de la clause (ADR 0002). Aucune donnée de la v3.0.1 n'est versée au dépôt.
#
# Script reproductible, à lancer depuis la racine du dépôt :
#
#   Rscript docs/analyses/regle-r2-pilote.R <dossier> executer court
#   Rscript docs/analyses/regle-r2-pilote.R <dossier> executer long
#   Rscript docs/analyses/regle-r2-pilote.R <dossier> mesurer <ref_017> <ref_029> <dates_v301.tif>
#
#   <dossier>   : dossier de travail HORS du dépôt (sorties de nemetonsar_run()).
#   executer    : nemetonsar_run() avec les réglages par défaut (règle de date R2,
#                 seuil de datation -3,45 dB), sur l'AOI et la période des missions
#                 017 (court : 2018-01-01 au 2025-09-30) ou 029 (long : jusqu'au
#                 2026-11-21). Environ 45 min chacun ; lit Sentinel-1 (réseau).
#   mesurer     : sans réseau. Compare les sorties R2 aux sorties de la règle
#                 d'avant (R0) des missions 017 (série courte) et 029 (série longue),
#                 dont les dossiers `sorties` sont donnés en <ref_017> et <ref_029> ;
#                 compare à la v3.0.1 (compare_reference) pour la série courte.
#
# Mesures : surface assemblée ; pixels datés ; correction 2019 (objets de la première
# détection, objets de la détection principale, objets gardés) ; stabilité des dates
# de 2025-01 à 2025-09 entre série courte et série longue, sous R2 et sous R0 ; sept
# pixels tracés par la mission 027 (L93).

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : voir l'en-tête du script.", call. = FALSE)
}
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
if (startsWith(DOSSIER, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de travail doit être hors du dépôt.", call. = FALSE)
}
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
set.seed(20261124L)
suppressMessages(pkgload::load_all(".", quiet = TRUE))

POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN_COURT <- as.Date("2025-09-30")
FIN_LONG <- as.Date("2026-11-21")

aoi_pilote <- function() {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                COTE_M / 2, capstyle = "square")
}

sorties <- function(serie) file.path(DOSSIER, paste0("sorties_", serie))

# Étape 1 : exécution ----------------------------------------------------------

if (ETAPE == "executer") {
  serie <- args[3]
  if (!serie %in% c("court", "long")) stop("executer court|long", call. = FALSE)
  fin <- if (serie == "court") FIN_COURT else FIN_LONG
  aoi <- aoi_pilote()
  terra::writeVector(aoi, file.path(DOSSIER, "aoi.gpkg"), overwrite = TRUE)
  t0 <- Sys.time()
  res <- tryCatch(
    nemetonsar_run(aoi, DEBUT, fin, dossier = sorties(serie), bdforet = "wfs",
                   parametres = parametres_sufosat()),
    error = function(e) e
  )
  t1 <- Sys.time()
  mesures <- list(debut = t0, fin = t1, duree_h = as.numeric(difftime(t1, t0, units = "hours")),
                  periode = c(DEBUT, fin),
                  erreur = if (inherits(res, "error")) conditionMessage(res) else NA_character_)
  saveRDS(list(res = if (inherits(res, "error")) NULL else res, mesures = mesures),
          file.path(DOSSIER, paste0("execution_", serie, ".rds")))
  str(mesures)
  if (!inherits(res, "error")) print(res$tuiles)
  if (inherits(res, "error")) stop(conditionMessage(res), call. = FALSE)
}

# Étape 2 : mesures --------------------------------------------------------------

if (ETAPE == "mesurer") {
  ref17 <- normalizePath(args[3])
  ref29 <- normalizePath(args[4])
  v301 <- normalizePath(args[5])
  if (startsWith(v301, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  cartes <- list(R0_court = ref17, R0_long = ref29,
                 R2_court = sorties("court"), R2_long = sorties("long"))
  lire_dates <- function(d) terra::rast(file.path(d, "dates.tif"))
  lire_objets <- function(d) {
    o <- terra::values(terra::vect(file.path(d, "objets.gpkg"), layer = "objets"), dataframe = TRUE)
    o$annee <- as.integer(format(as.Date(o$date_mediane_date), "%Y"))
    o
  }
  cat("\n## Surface assemblée et objets, par carte\n")
  obj <- lapply(cartes, lire_objets)
  resume <- do.call(rbind, lapply(names(cartes), function(n) {
    o <- obj[[n]]
    data.frame(carte = n, objets = nrow(o), surface_ha = round(sum(o$surface_ha), 1),
               objets_2019 = sum(o$annee == 2019L), surface_2019_ha = round(sum(o$surface_ha[o$annee == 2019L]), 1),
               stringsAsFactors = FALSE)
  }))
  print(resume, row.names = FALSE)

  # Même période : série courte, R0 contre R2 ; objets jusqu'au 2025-09-30
  cat("\n## Objets par année (date médiane), série courte puis série longue\n")
  par_annee <- function(o) {
    a <- aggregate(surface_ha ~ annee, data = o, FUN = function(x) round(sum(x), 1))
    n <- aggregate(surface_ha ~ annee, data = o, FUN = length)
    data.frame(annee = a$annee, objets = n$surface_ha, surface_ha = a$surface_ha)
  }
  for (n in names(cartes)) { cat("\n", n, "\n"); print(par_annee(obj[[n]]), row.names = FALSE) }

  # Correction 2019 : colonnes des tuiles (execution.rds de 017, 029 ; ceux d'ici)
  cat("\n## Correction 2019 (table des tuiles)\n")
  exec <- list(R0_court = file.path(dirname(ref17), "execution.rds"),
               R0_long = file.path(dirname(ref29), "execution.rds"),
               R2_court = file.path(DOSSIER, "execution_court.rds"),
               R2_long = file.path(DOSSIER, "execution_long.rds"))
  tuiles <- do.call(rbind, lapply(names(exec), function(n) {
    t <- readRDS(exec[[n]])$res$tuiles
    cbind(carte = n, t[, c("nb_images", "passe_2019", "objets_2019", "objets_detection", "objets_gardes")])
  }))
  print(tuiles, row.names = FALSE)

  # Stabilité : dates de 2025-01-01 à 2025-09-30 de la série courte, relues sur la
  # série longue (mêmes pixels), sous R0 puis sous R2.
  cat("\n## Stabilité des dates de 2025-01 à 2025-09, série courte contre série longue\n")
  bas <- as.integer(format(as.Date("2025-01-01"), "%y%j"))
  haut <- as.integer(format(FIN_COURT, "%y%j"))
  stabilite <- function(court, long) {
    dc <- terra::values(lire_dates(court), mat = FALSE)
    dl <- terra::values(lire_dates(long), mat = FALSE)
    stopifnot(length(dc) == length(dl))
    dans <- !is.na(dc) & dc >= bas & dc <= haut
    mem <- dans & !is.na(dl) & dl == dc
    perdu <- dans & is.na(dl)
    autre <- dans & !is.na(dl) & dl != dc
    # pixels datés de la série longue dans la même fenêtre, absents de la courte
    nouveau <- !is.na(dl) & dl >= bas & dl <= haut & !dans
    data.frame(pixels_courte = sum(dans), identiques = sum(mem), redates = sum(autre),
               sans_date_dans_longue = sum(perdu), nouveaux_dans_longue = sum(nouveau))
  }
  st <- rbind(cbind(regle = "R0", stabilite(ref17, ref29)),
              cbind(regle = "R2", stabilite(sorties("court"), sorties("long"))))
  print(st, row.names = FALSE)
  # Objets : date médiane dans la fenêtre, série courte ; retrouvés en longue (identifiants non
  # comparables : par chevauchement de pixels datés)
  # Pixels datés de la série courte, toutes années : part qui change
  tout <- function(court, long) {
    dc <- terra::values(lire_dates(court), mat = FALSE)
    dl <- terra::values(lire_dates(long), mat = FALSE)
    dans <- !is.na(dc) & dc <= haut
    data.frame(pixels = sum(dans), identiques = sum(dans & !is.na(dl) & dl == dc),
               redates = sum(dans & !is.na(dl) & dl != dc), sans_date = sum(dans & is.na(dl)))
  }
  cat("\n## Toutes dates jusqu'au 2025-09-30, série courte contre série longue\n")
  print(rbind(cbind(regle = "R0", tout(ref17, ref29)),
              cbind(regle = "R2", tout(sorties("court"), sorties("long")))), row.names = FALSE)

  # R0 contre R2 sur la même série courte : pixels datés, dates changées
  cat("\n## Série courte : R0 contre R2, pixels datés\n")
  d0 <- terra::values(lire_dates(ref17), mat = FALSE)
  d2 <- terra::values(lire_dates(sorties("court")), mat = FALSE)
  cat("pixels datés R0 :", sum(!is.na(d0)), "; R2 :", sum(!is.na(d2)),
      "; communs :", sum(!is.na(d0) & !is.na(d2)),
      "; dates changées sur les communs :", sum(!is.na(d0) & !is.na(d2) & d0 != d2), "\n")
  r0 <- terra::values(terra::rast(file.path(ref17, "ratio.tif")), mat = FALSE)
  r2 <- terra::values(terra::rast(file.path(sorties("court"), "ratio.tif")), mat = FALSE)
  cat("pixels avec ratio R0 :", sum(!is.na(r0)), "; R2 :", sum(!is.na(r2)),
      "; ratio identique sur les communs :", sum(!is.na(r0) & !is.na(r2) & abs(r0 - r2) < 1e-9), "\n")

  # Comparaison à la v3.0.1, série courte
  cat("\n## Comparaison à la v3.0.1 (série courte, R2)\n")
  cmp <- compare_reference(sorties("court"), v301, periode = c(DEBUT, FIN_COURT),
                           aoi = aoi_pilote(), seuil_objet = 0.75)
  print(t(cmp$resume))
  print(cmp$par_annee, row.names = FALSE)
  cmp0 <- readRDS(file.path(dirname(ref17), "comparaison.rds"))
  cat("\nMême comparaison, règle d'avant (R0, mission 017)\n")
  print(t(cmp0$resume))
  saveRDS(list(resume = resume, tuiles = tuiles, stabilite = st, cmp = cmp),
          file.path(DOSSIER, "mesures_030.rds"))

  # Sept pixels tracés par la mission 027 (L93)
  cat("\n## Sept pixels tracés de 027 : date sous R2, séries courte et longue\n")
  pts <- data.frame(x = c(398525, 398595, 394175, 394465, 394475, 393725, 393975),
                    y = c(6351825, 6348385, 6352425, 6350145, 6350815, 6349945, 6349765))
  lecture <- function(d) {
    v <- terra::extract(lire_dates(d), as.matrix(pts))[[1]]
    ifelse(is.na(v), NA, format(yyddd_vers_date(v)))
  }
  print(cbind(pts, R0_court = lecture(ref17), R2_court = lecture(sorties("court")),
              R2_long = lecture(sorties("long"))), row.names = FALSE)
}
