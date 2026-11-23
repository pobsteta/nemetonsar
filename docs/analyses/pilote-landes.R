# Mission 017 : tuile pilote des Landes et comparaison à la carte SUFOSAT v3.0.1
# ---------------------------------------------------------------------------
# Script reproductible (aucune modification du package). À lancer depuis la
# racine du dépôt :
#
#   Rscript docs/analyses/pilote-landes.R <dossier> executer
#   Rscript docs/analyses/pilote-landes.R <dossier> resumer
#   Rscript docs/analyses/pilote-landes.R <dossier> comparer <dates_v301.tif>
#
#   <dossier>  : dossier de travail, HORS du dépôt (sorties de
#                nemetonsar_run() dans <dossier>/sorties, mesures en .rds).
#   executer   : lance nemetonsar_run() sur l'AOI pilote et mesure le temps,
#                le disque (pic du dossier, échantillonné toutes les 20 s),
#                le trafic reçu (eth0) et le nombre d'images ;
#   resumer    : objets par année, trois coupes détectées à contrôler sur
#                orthophoto (coordonnées) ;
#   comparer   : compare_reference() avec un extrait de la carte des dates
#                SUFOSAT v3.0.1 (GeoTIFF, Lambert-93, YYDDD, nodata 0), donné
#                en argument. L'extrait est sous licence CC BY-NC 4.0 : il
#                reste hors du dépôt (ADR 0002) ; seuls les chiffres de la
#                comparaison vont au rapport.
#
# Extrait de la v3.0.1 (à faire là où le S3 de THEIA répond ; 403 depuis la
# session du 2026-11-22) :
#
#   gdal_translate -projwin 391403 6354861 401403 6344861 \
#     /vsicurl/https://s3-data.meso.umontpellier.fr/sm1-gdc-ext/sufosat/forest-clearcuts_mainland-france_sufosat_dates_v3_set25.tif \
#     sufosat_v301_dates_aoi.tif
#
# AOI : carré de 10 km x 10 km en Lambert-93, centré 2 km au sud du point
# pilote (-0,80 E ; 44,20 N) pour tenir dans la seule tuile MGRS 30TXP (le
# carré centré sur le point coupe 30TXP et 30TXQ) ; le point est dans l'AOI.
# Période 2018-01-01 au 2025-09-30, masque BD Forêt v2 par le WFS de la
# Géoplateforme, parametres_sufosat() par défaut, bandes et flux par défaut.
#
# Graine fixée ; chemins relatifs à la racine du dépôt ; aucune écriture hors
# de <dossier> (sauf fichiers temporaires de terra).
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) {
  stop("Usage : Rscript docs/analyses/pilote-landes.R <dossier> executer|resumer|comparer [dates_v301.tif]",
       call. = FALSE)
}
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
ETAPE <- args[2]
if (startsWith(DOSSIER, normalizePath(".", mustWork = TRUE))) {
  stop("Le dossier de travail doit être hors du dépôt.", call. = FALSE)
}
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
SORTIES <- file.path(DOSSIER, "sorties")
set.seed(20261122L)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

POINT <- c(-0.80, 44.20)
DECALAGE_SUD_M <- 2000
COTE_M <- 10000
DEBUT <- as.Date("2018-01-01")
FIN <- as.Date("2025-09-30")

aoi_pilote <- function() {
  p <- terra::project(terra::vect(rbind(POINT), crs = "EPSG:4326"), "EPSG:2154")
  xy <- terra::crds(p)
  terra::buffer(terra::vect(cbind(xy[1], xy[2] - DECALAGE_SUD_M), crs = "EPSG:2154"),
                COTE_M / 2, capstyle = "square")
}

octets_recus <- function() {
  l <- readLines("/proc/net/dev")
  l <- l[grepl("^\\s*eth0:", l)]
  if (length(l) == 0L) return(NA_real_)
  as.numeric(strsplit(trimws(sub("^\\s*eth0:", "", l)), "\\s+")[[1]][1])
}

taille_dossier_mo <- function(d) {
  f <- list.files(d, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  sum(file.size(f), na.rm = TRUE) / 2^20
}

# Étape 1 : exécution ----------------------------------------------------------

if (ETAPE == "executer") {
  aoi <- aoi_pilote()
  terra::writeVector(aoi, file.path(DOSSIER, "aoi.gpkg"), overwrite = TRUE)
  # Échantillonneur du disque (processus fils) : pic de <dossier> et du
  # dossier temporaire de terra, toutes les 20 s.
  fichier_disque <- file.path(DOSSIER, "disque.txt")
  temp_terra <- terra::terraOptions(print = FALSE)$tempdir
  pid_parent <- Sys.getpid()
  echant <- parallel::mcparallel({
    repeat {
      cat(format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), taille_dossier_mo(DOSSIER),
          taille_dossier_mo(temp_terra), "\n", file = fichier_disque, append = TRUE)
      Sys.sleep(20)
      if (!file.exists(file.path("/proc", pid_parent))) break
    }
  }, detached = TRUE)
  t0 <- Sys.time()
  o0 <- octets_recus()
  res <- tryCatch(
    nemetonsar_run(aoi, DEBUT, FIN, dossier = SORTIES, bdforet = "wfs",
                   parametres = parametres_sufosat()),
    error = function(e) e
  )
  t1 <- Sys.time()
  o1 <- octets_recus()
  tools::pskill(echant$pid)
  d <- utils::read.table(fichier_disque, col.names = c("heure", "dossier_mo", "temp_terra_mo"))
  mesures <- list(
    debut = t0, fin = t1,
    duree_h = as.numeric(difftime(t1, t0, units = "hours")),
    recu_go = (o1 - o0) / 1e9,
    disque_pic_dossier_mo = max(d$dossier_mo),
    disque_pic_temp_terra_mo = max(d$temp_terra_mo),
    disque_final_dossier_mo = taille_dossier_mo(DOSSIER),
    erreur = if (inherits(res, "error")) conditionMessage(res) else NA_character_
  )
  saveRDS(list(res = if (inherits(res, "error")) NULL else res, mesures = mesures),
          file.path(DOSSIER, "execution.rds"))
  str(mesures)
  if (!inherits(res, "error")) print(res$tuiles)
  if (inherits(res, "error")) stop(conditionMessage(res), call. = FALSE)
}

# Étape 2 : résumé de la carte recalculée ----------------------------------------

if (ETAPE == "resumer") {
  ex <- readRDS(file.path(DOSSIER, "execution.rds"))
  res <- ex$res
  tab <- res$objets
  tab$annee <- as.integer(format(tab$date_mediane_date, "%Y"))
  par_annee <- do.call(rbind, lapply(split(tab, tab$annee), function(x) {
    data.frame(annee = x$annee[1], objets = nrow(x), surface_ha = round(sum(x$surface_ha), 2),
               surface_mediane_ha = round(stats::median(x$surface_ha), 2))
  }))
  rownames(par_annee) <- NULL
  cat("\n## Mesures\n"); str(ex$mesures)
  cat("\n## Tuiles\n"); print(res$tuiles)
  cat("\n## Objets par année (date médiane)\n"); print(par_annee)
  cat("\nTotal :", nrow(tab), "objets,", round(sum(tab$surface_ha), 2), "ha\n")

  # Dates médianes partagées par plusieurs objets (une même acquisition qui
  # fait chuter le ratio sur de grandes surfaces est suspecte).
  partage <- aggregate(cbind(objets = 1, surface_ha = tab$surface_ha) ~ date_mediane_date,
                       data = tab, FUN = sum)
  partage <- utils::head(partage[order(-partage$surface_ha), ], 5L)
  cat("\n## Dates médianes qui portent le plus de surface\n"); print(partage, row.names = FALSE)
  # Trois coupes à contrôler : la plus grande, la plus grande de 2019 (première
  # année de ratio : effet de début de série possible) et la plus récente ;
  # centroïde dans l'objet (terra::centroids(inside = TRUE)).
  poly <- terra::vect(file.path(SORTIES, "objets.gpkg"), layer = "objets")
  t19 <- tab[tab$annee == 2019L, ]
  choix <- unique(c(tab$identifiant[which.max(tab$surface_ha)],
                    t19$identifiant[which.max(t19$surface_ha)],
                    tab$identifiant[which.max(tab$date_mediane_date)]))
  sel <- poly[poly$identifiant %in% choix, ]
  ctr <- terra::centroids(sel, inside = TRUE)
  ll <- terra::crds(terra::project(ctr, "EPSG:4326"))
  l93 <- terra::crds(ctr)
  controle <- data.frame(identifiant = sel$identifiant,
                         surface_ha = round(sel$surface_ha, 2),
                         date_mediane = format(as.Date(sel$date_mediane_date)),
                         lon = round(ll[, 1], 5), lat = round(ll[, 2], 5),
                         x_l93 = round(l93[, 1]), y_l93 = round(l93[, 2]))
  cat("\n## Trois coupes détectées à contrôler sur orthophoto\n"); print(controle)
  saveRDS(list(par_annee = par_annee, partage = partage, controle = controle), file.path(DOSSIER, "resume.rds"))
}

# Étape 3 : comparaison à la v3.0.1 -----------------------------------------------

if (ETAPE == "comparer") {
  if (length(args) < 3L || !file.exists(args[3])) {
    stop("Donner le chemin de l'extrait des dates de la v3.0.1 (hors dépôt).", call. = FALSE)
  }
  reference <- normalizePath(args[3])
  if (startsWith(reference, normalizePath(".", mustWork = TRUE))) {
    stop("L'extrait de la v3.0.1 (CC BY-NC 4.0) ne doit pas être dans le dépôt.", call. = FALSE)
  }
  cmp <- compare_reference(SORTIES, reference, periode = c(DEBUT, FIN),
                           aoi = aoi_pilote(), seuil_objet = 0.75)
  cat("\n## Grille\n", cmp$reprojection, "\n")
  cat("\n## Résumé\n"); print(t(cmp$resume))
  cat("\n## Par année\n"); print(cmp$par_annee, row.names = FALSE)
  saveRDS(cmp, file.path(DOSSIER, "comparaison.rds"))
  # Trois désaccords à contrôler : les deux plus grands objets de référence
  # non retrouvés et le plus grand objet recalculé absent de la référence.
  ref <- cmp$objets_reference[!cmp$objets_reference$retrouve, ]
  rec <- cmp$objets_recalcules[!cmp$objets_recalcules$retrouve, ]
  ref <- utils::head(ref[order(-ref$surface_ha), ], 2L)
  rec <- utils::head(rec[order(-rec$surface_ha), ], 1L)
  des <- rbind(data.frame(carte = rep("publiee", nrow(ref)), ref[, c("surface_ha", "x", "y")]),
               data.frame(carte = rep("recalculee", nrow(rec)), rec[, c("surface_ha", "x", "y")]))
  if (nrow(des) > 0L) {
    ll <- terra::crds(terra::project(terra::vect(as.matrix(des[, c("x", "y")]), crs = "EPSG:2154"),
                                     "EPSG:4326"))
    des$lon <- round(ll[, 1], 5)
    des$lat <- round(ll[, 2], 5)
  }
  cat("\n## Trois coupes en désaccord à contrôler\n"); print(des)
}
