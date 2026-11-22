# Mission 016 : temps et mémoire de nemetonsar_detecter()
# ---------------------------------------------------------------------------
# Script reproductible (graine fixée), à lancer depuis la racine du dépôt :
#
#   Rscript docs/analyses/performance.R [lignes] [colonnes] [dates] [orbites] [empreinte.rds] [lignes_par_bloc]
#
# (empreinte : "-" pour ne pas l'écrire ; lignes_par_bloc : défaut du package si absent)
#
# Défauts : 200 lignes x 500 colonnes x 300 dates x 3 orbites (1e5 pixels,
# 9e7 valeurs). Les piles synthétiques sont écrites en GeoTIFF FLT4S dans
# tempdir() : forêt à 0,05 (linéaire) avec un speckle gamma de 4,4 vues
# (hypothèse, B18 § 2.2.1), et 80 coupes rectangulaires de -6 dB à des dates
# tirées au hasard. Ce sont des données de SIMULATION : la répartition du
# temps entre les étapes dépend du nombre de composantes connexes, donc du
# speckle et des coupes simulés.
#
# Le script charge le package par pkgload::load_all() (sans l'installer),
# mesure le temps total (system.time), le temps par fonction (Rprof, temps
# « total » : la fonction et ce qu'elle appelle) et le pic de mémoire du tas
# R (gc(), colonne « max used »), puis écrit, si un 5e argument est donné,
# une empreinte des sorties (valeurs des trois rasters et table) : deux
# empreintes identiques au bit près prouvent que les sorties n'ont pas changé.
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
arg_entier <- function(i, defaut) if (length(args) >= i) as.integer(args[i]) else defaut
NL <- arg_entier(1, 200L)
NC <- arg_entier(2, 500L)
NT <- arg_entier(3, 300L)
NORB <- arg_entier(4, 3L)
EMPREINTE <- if (length(args) >= 5 && args[5] != "-") args[5] else NA_character_
LPB <- if (length(args) >= 6) as.integer(args[6]) else NULL
GRAINE <- 20261122L
ENL <- 4.4
NB_COUPES <- 80L

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# --- Piles synthétiques -----------------------------------------------------
set.seed(GRAINE)
grille <- terra::rast(nrows = NL, ncols = NC, xmin = 600000, xmax = 600000 + 10 * NC,
                      ymin = 5000000, ymax = 5000000 + 10 * NL, crs = "EPSG:32631")
# Orbites décalées de 2 jours, cadence 6 jours, à partir du 2018-01-01.
dates <- lapply(seq_len(NORB), function(k) {
  seq(as.Date("2018-01-01") + 2L * (k - 1L), by = 6, length.out = NT)
})
fin <- min(vapply(dates, function(d) as.numeric(max(d)), numeric(1)))
coupes <- lapply(seq_len(NB_COUPES), function(i) {
  h <- sample(3:25, 1)
  w <- sample(3:25, 1)
  l0 <- sample(seq_len(max(1L, NL - h)), 1)
  c0 <- sample(seq_len(max(1L, NC - w)), 1)
  list(lignes = l0 + seq_len(h) - 1L, colonnes = c0 + seq_len(w) - 1L,
       date = as.Date("2019-03-01") +
         sample(0:max(0, fin - as.numeric(as.Date("2019-03-01")) - 120), 1))
})
ligne <- rep(seq_len(NL), each = NC)
colonne <- rep(seq_len(NC), NL)
fichiers_piles <- character(NORB)
for (k in seq_len(NORB)) {
  r <- terra::rast(grille, nlyrs = NT)
  v <- matrix(0.05 * stats::rgamma(NL * NC * NT, ENL, ENL), nrow = NL * NC)
  for (cp in coupes) {
    dedans <- which(ligne %in% cp$lignes & colonne %in% cp$colonnes)
    apres <- which(dates[[k]] >= cp$date)
    v[dedans, apres] <- v[dedans, apres] * 10^(-6 / 10)
  }
  terra::values(r) <- v
  rm(v)
  fichiers_piles[k] <- tempfile(sprintf("orbite%d-", k), fileext = ".tif")
  terra::writeRaster(r, fichiers_piles[k], datatype = "FLT4S")
}
orbites <- lapply(fichiers_piles, terra::rast)
names(orbites) <- paste0("o", seq_len(NORB))
invisible(gc())

# --- Mesure -------------------------------------------------------------------
dossier <- tempfile("perf-")
profil <- tempfile(fileext = ".out")
invisible(gc(reset = TRUE))
Rprof(profil, interval = 0.01)
chrono <- system.time(
  res <- nemetonsar_detecter(orbites, dates, dossier, lignes_par_bloc = LPB)
)
Rprof(NULL)
memoire <- gc()
pic_mo <- sum(memoire[, ncol(memoire)])  # « max used » en Mo (Ncells + Vcells)

etapes <- c(
  "passe 1 : lecture des piles" = "terra::readValues",
  "passe 1 : filtre" = "s1_filter_multitemp",
  "passe 1 : ratio" = "rcr_compute",
  "passe 1 : combinaison" = "rcr_combine_orbites",
  "passes 2-3 : étiquetage" = "etiquette_bande",
  "passe 3 : fermeture" = "fermeture_carre",
  "union-find des bandes" = "racines_equivalences",
  "table des objets" = "table_objets_blocs",
  "polygones (as.polygons)" = "terra::as.polygons",
  "GeoPackage (writeVector)" = "terra::writeVector"
)
total <- summaryRprof(profil)$by.total
noms <- sub('^"(.*)"$', "\\1", rownames(total))
secondes <- vapply(etapes, function(f) {
  i <- match(f, noms)
  if (is.na(i)) i <- match(sub("^terra::", "", f), noms)
  if (is.na(i)) 0 else total$total.time[i]
}, numeric(1))

cat(sprintf("Grille : %d lignes x %d colonnes x %d dates x %d orbites (%.2g valeurs)\n",
            NL, NC, NT, NORB, as.numeric(NL) * NC * NT * NORB))
cat(sprintf("Blocs : %d lignes ; objets : %d\n", res$lignes_par_bloc, nrow(res$objets)))
cat(sprintf("Temps total (elapsed) : %.1f s ; pic mémoire du tas R : %.0f Mo\n",
            chrono[["elapsed"]], pic_mo))
cat("Temps par étape (Rprof, total.time, s) :\n")
for (e in names(secondes)) cat(sprintf("  %-28s %8.2f\n", e, secondes[[e]]))
pixels_tuile <- 10980^2
facteur <- pixels_tuile / (NL * NC) * (300 / NT) * (3 / NORB)
cat(sprintf("Extrapolation linéaire à une tuile MGRS 10 980 x 10 980 x 300 dates x 3 orbites (x %.0f) : %.1f h\n",
            facteur, chrono[["elapsed"]] * facteur / 3600))

if (!is.na(EMPREINTE)) {
  lire <- function(f) terra::values(terra::rast(f), mat = FALSE)
  sorties <- list(
    dates = lire(res$fichiers[["dates"]]),
    ratio = lire(res$fichiers[["ratio"]]),
    objets = lire(res$fichiers[["objets_raster"]]),
    table = res$objets
  )
  saveRDS(sorties, EMPREINTE)
  cat("Empreinte écrite :", EMPREINTE, "\n")
}
unlink(c(dossier, fichiers_piles, profil), recursive = TRUE)
