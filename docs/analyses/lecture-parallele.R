# Mission 019 : lecture réelle des images Sentinel-1 RTC et passe 1 en parallèle
# ---------------------------------------------------------------------------
# Script de mesure (aucune modification du package). À lancer depuis la racine
# du dépôt :
#
#   Rscript docs/analyses/lecture-parallele.R <dossier_donnees> [etapes] [repetitions]
#
#   <dossier_donnees> : dossier de travail (images copiées, piles, résultats
#                       .rds) ; à surveiller : ≈ 2 Go au plus.
#   [etapes]          : parmi 1,2,3,4 (défaut "1,2,3,4") :
#                       1 structure des COG (terra::describe) ;
#                       2 lecture distante et locale d'une orbite ;
#                       3 passe 1 sur 1, 2 et 3 orbites, en série et en
#                         parallèle (parallel::mclapply, fork) ;
#                       4 synthèse et extrapolation à une tuile MGRS.
#   [repetitions]     : défaut 2.
#
# Données : collection sentinel-1-rtc du Microsoft Planetary Computer (jeton
# SAS sans compte, mission 013), point pilote des Landes (-0,80 E ; 44,20 N),
# année 2025, polarisation VH (défaut du package), orbite D008 (31 images en
# 2025) pour la lecture. Fenêtre native de 2048 colonnes x 1024 lignes
# (20 x 10 km), alignée sur la grille des tuiles internes (512 x 512) et
# contenant le point.
#
# Réseau : le trafic reçu est compté sur l'interface eth0 (/proc/net/dev) ;
# rien d'autre ne tourne pendant la mesure. Cache disque : vidé avant chaque
# lecture locale si /proc/sys/vm/drop_caches est accessible (sinon dit).
#
# Graine fixée ; chemins relatifs à la racine du dépôt ; aucune écriture hors
# de <dossier_donnees>.
# ---------------------------------------------------------------------------

if (!file.exists("DESCRIPTION") || !dir.exists("R")) {
  stop("Lancer depuis la racine du dépôt nemetonsar.", call. = FALSE)
}
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("Donner le dossier de données.", call. = FALSE)
DOSSIER <- normalizePath(args[1], mustWork = FALSE)
dir.create(DOSSIER, showWarnings = FALSE, recursive = TRUE)
ETAPES <- if (length(args) >= 2L) as.integer(strsplit(args[2], ",")[[1]]) else 1:4
REP <- if (length(args) >= 3L) as.integer(args[3]) else 2L
SOUS_COMMANDE <- if (length(args) >= 4L) args[4] else ""
SCRIPT <- "docs/analyses/lecture-parallele.R"
set.seed(20261122L)

suppressMessages(pkgload::load_all(".", quiet = TRUE))
library(terra, quietly = TRUE, warn.conflicts = FALSE)

POINT <- c(-0.80, 44.20)
ORBITE <- "D008"
LARGEUR <- 2048L   # colonnes de la fenêtre native (4 tuiles internes)
HAUTEUR <- 1024L   # lignes de la fenêtre native (2 tuiles internes)
LIGNES_BLOC <- 9L  # bloc par défaut de nemetonsar_detecter() à 300 dates
fichier <- function(...) file.path(DOSSIER, ...)

# Outils ----------------------------------------------------------------------

octets_recus <- function() {
  l <- grep("^\\s*eth0:", readLines("/proc/net/dev"), value = TRUE)
  as.numeric(strsplit(trimws(sub(".*:", "", l)), " +")[[1]][1])
}
vider_cache_disque <- function() {
  ok <- tryCatch({
    system("sync")
    cat("3", file = "/proc/sys/vm/drop_caches")
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  ok
}
vm_hwm_mo <- function(pid = "self") {
  l <- grep("^VmHWM", readLines(sprintf("/proc/%s/status", pid)), value = TRUE)
  as.numeric(gsub("[^0-9]", "", l)) / 1024
}
# Échantillonneur de MemAvailable (toutes les 0,1 s) en arrière-plan.
memoire_debut <- function(f) {
  pid <- system(sprintf(
    "bash -c 'while true; do grep MemAvailable /proc/meminfo | tr -s \" \" | cut -d\" \" -f2; sleep 0.1; done > %s 2>/dev/null & echo $!'",
    f), intern = TRUE)
  Sys.sleep(0.3)
  as.integer(pid)
}
memoire_fin <- function(pid, f) {
  tools::pskill(pid)
  v <- suppressWarnings(as.numeric(readLines(f)))
  v <- v[!is.na(v)]
  # Mo utilisés au pic au-dessus du premier relevé.
  (v[1] - min(v)) / 1024
}
signer <- function(urls) {
  s <- rstac::sign_planetary_computer()
  vapply(urls, function(u) s(list(assets = list(a = list(href = u))))$assets$a$href,
         character(1), USE.NAMES = FALSE)
}
distant <- function(u) paste0("/vsicurl/", u)
terra::setGDALconfig("GDAL_DISABLE_READDIR_ON_OPEN", "EMPTY_DIR")

items_orbite <- function() {
  f <- fichier("items2025.rds")
  if (!file.exists(f)) {
    pt <- terra::vect(cbind(POINT[1], POINT[2]), crs = "EPSG:4326")
    saveRDS(s1_rechercher(pt, "2025-01-01", "2025-12-31"), f)
  }
  readRDS(f)
}

# Fenêtre native alignée sur les tuiles internes, contenant le point.
fenetre <- function(r, largeur = LARGEUR, hauteur = HAUTEUR, bloc = 512L) {
  pt <- terra::project(terra::vect(cbind(POINT[1], POINT[2]), crs = "EPSG:4326"), terra::crs(r))
  xy <- terra::geom(pt)[, c("x", "y"), drop = FALSE]
  rc <- terra::rowColFromCell(r, terra::cellFromXY(r, xy))
  l0 <- ((rc[1] - 1L) %/% bloc) * bloc + 1L - (hauteur %/% 2L %/% bloc) * bloc
  c0 <- ((rc[2] - 1L) %/% bloc) * bloc + 1L - (largeur %/% 2L %/% bloc) * bloc
  list(ligne = as.integer(max(1L, l0)), colonne = as.integer(max(1L, c0)),
       nl = as.integer(hauteur), nc = as.integer(largeur))
}

# Lit la fenêtre `w` de `source` par bandes de `pas` lignes, chacune lue avec
# une bordure de `bord` lignes de chaque côté (comme la passe 1 de
# nemetonsar_detecter() : bande de 9 lignes, bordure du filtre 3 x 3 = 1).
# Rend les temps (ouverture, lecture), les octets reçus et, sur demande,
# la fenêtre lue (sans bordure).
lire_fenetre <- function(source, w, pas, bord = 0L, garder = FALSE) {
  b0 <- octets_recus()
  t0 <- proc.time()[["elapsed"]]
  r <- terra::rast(source)
  t1 <- proc.time()[["elapsed"]]
  terra::readStart(r)
  garde <- if (garder) matrix(NA_real_, w$nc, w$nl) else NULL
  for (d in seq(1L, w$nl, by = pas)) {
    n <- min(pas, w$nl - d + 1L)
    lu <- bande_bordee(d, n, bord, w$nl)
    v <- terra::readValues(r, row = w$ligne + lu$debut - 1L, nrows = lu$n,
                           col = w$colonne, ncols = w$nc, mat = FALSE)
    if (garder) garde[, d + seq_len(n) - 1L] <- matrix(v, w$nc, lu$n)[, lu$centre]
  }
  terra::readStop(r)
  t2 <- proc.time()[["elapsed"]]
  list(ouverture = t1 - t0, lecture = t2 - t1, total = t2 - t0,
       recu_mo = (octets_recus() - b0) / 1e6, valeurs = garde)
}

# Étape 1 : structure des COG ------------------------------------------------

etape1 <- function() {
  items <- items_orbite()
  un <- items[!duplicated(items$serie), ]
  urls <- signer(un$url)
  lignes <- lapply(seq_len(nrow(un)), function(i) {
    d <- terra::describe(distant(urls[i]))
    v <- function(motif) {
      l <- grep(motif, d, value = TRUE)
      if (length(l) == 0L) NA_character_ else trimws(l[1])
    }
    taille <- grep("Content-Length", curlGetHeaders(urls[i]), value = TRUE, ignore.case = TRUE)
    data.frame(
      serie = un$serie[i], date = format(un$date[i]),
      crs = terra::crs(terra::rast(distant(urls[i])), describe = TRUE)$code,
      taille = sub("Size is ", "", v("^Size is")),
      bloc = sub(".*Block=([0-9x]+).*", "\\1", v("Block=")),
      type = sub(".*Type=([A-Za-z0-9]+).*", "\\1", v("Block=")),
      compression = sub(".*=", "", v("COMPRESSION=")),
      predicteur = sub(".*=", "", v("PREDICTOR=")),
      disposition = sub(".*=", "", v("LAYOUT=")),
      apercus = sub(".*Overviews: ", "", v("Overviews:")),
      fichier_mo = round(as.numeric(gsub("[^0-9]", "", taille[1])) / 1e6),
      stringsAsFactors = FALSE
    )
  })
  tab <- do.call(rbind, lignes)
  print(tab, row.names = FALSE)
  saveRDS(tab, fichier("etape1.rds"))
  invisible(tab)
}

# Étape 2 : lecture d'une orbite ---------------------------------------------

# 2c dans un processus neuf : caches GDAL et /vsicurl/ réduits, pour imiter
# une lecture de 300 images sur la largeur d'une tuile (voir le rapport).
lecture_sans_cache <- function() {
  terra::gdalCache(1)
  items <- items_orbite()
  items <- items[items$serie == ORBITE, ][1:3, ]
  w0 <- NULL
  res <- list()
  for (rep in seq_len(REP)) {
    urls <- signer(items$url)
    for (i in seq_along(urls)) {
      r <- terra::rast(distant(urls[i]))
      w <- fenetre(r, largeur = 1024L, hauteur = 512L)
      m <- lire_fenetre(distant(urls[i]), w, LIGNES_BLOC, bord = 1L)
      res[[length(res) + 1L]] <- data.frame(
        cas = "distant, 9 lignes, cache insuffisant", repetition = rep, image = i, n_images = 1,
        mo_utiles = w$nl * w$nc * 4 / 1e6, recu_mo = m$recu_mo,
        ouverture_s = m$ouverture, lecture_s = m$lecture, total_s = m$total)
    }
  }
  saveRDS(do.call(rbind, res), fichier("etape2c.rds"))
}

etape2 <- function() {
  items <- items_orbite()
  items <- items[items$serie == ORBITE, ]
  n_img <- nrow(items)
  cat(sprintf("Orbite %s : %d images en 2025\n", ORBITE, n_img))
  dir.create(fichier("copie"), showWarnings = FALSE)
  res <- list()
  ajoute <- function(cas, rep, i, w, m) {
    res[[length(res) + 1L]] <<- data.frame(
      cas = cas, repetition = rep, image = i, n_images = 1, mo_utiles = w$nl * w$nc * 4 / 1e6,
      recu_mo = m$recu_mo, ouverture_s = m$ouverture, lecture_s = m$lecture,
      total_s = m$total)
  }
  fenetres <- list()
  # 2a : distant, bandes de 512 lignes (hauteur des tuiles internes) ; la
  # première répétition garde les valeurs pour la copie locale.
  for (rep in seq_len(REP)) {
    urls <- signer(items$url)
    for (i in seq_len(n_img)) {
      r <- terra::rast(distant(urls[i]))
      w <- fenetre(r)
      fenetres[[i]] <- w
      m <- lire_fenetre(distant(urls[i]), w, 512L, garder = (rep == 1L))
      ajoute("distant, 512 lignes (aligné)", rep, i, w, m)
      if (rep == 1L) {
        # Copie locale de la fenêtre, GeoTIFF par défaut de terra (comme
        # s1_lire(dossier =) : LZW, FLT4S), avec sa géoréférence native.
        e <- terra::ext(r, cells = c(
          terra::cellFromRowCol(r, w$ligne, w$colonne),
          terra::cellFromRowCol(r, w$ligne + w$nl - 1L, w$colonne + w$nc - 1L)))
        g <- terra::rast(nrows = w$nl, ncols = w$nc, ext = e, crs = terra::crs(r))
        terra::values(g) <- as.vector(m$valeurs)
        terra::writeRaster(g, fichier("copie", sprintf("img%02d.tif", i)),
                           overwrite = TRUE, datatype = "FLT4S")
      }
    }
  }
  # 2b : distant, bandes de 9 lignes (+ bordure de 1), cache GDAL par
  # défaut (suffisant ici : une image à la fois) ; 10 images.
  for (rep in seq_len(REP)) {
    urls <- signer(items$url[1:10])
    for (i in 1:10) {
      m <- lire_fenetre(distant(urls[i]), fenetres[[i]], LIGNES_BLOC, bord = 1L)
      ajoute("distant, 9 lignes, cache suffisant", rep, i, fenetres[[i]], m)
    }
  }
  # 2d : distant, 512 lignes, 8 images lues par 4 processus à la fois.
  for (rep in seq_len(REP)) {
    urls <- signer(items$url[1:8])
    b0 <- octets_recus()
    t0 <- proc.time()[["elapsed"]]
    invisible(parallel::mclapply(1:8, function(i) {
      lire_fenetre(distant(urls[i]), fenetres[[i]], 512L)$total
    }, mc.cores = 4L, mc.preschedule = FALSE))
    dt <- proc.time()[["elapsed"]] - t0
    w <- fenetres[[1]]
    res[[length(res) + 1L]] <- data.frame(
      cas = "distant, 512 lignes, 4 processus (8 images)", repetition = rep, image = NA, n_images = 8,
      mo_utiles = 8 * w$nl * w$nc * 4 / 1e6, recu_mo = (octets_recus() - b0) / 1e6,
      ouverture_s = NA, lecture_s = NA, total_s = dt)
  }
  # 2c : cache insuffisant, dans un processus neuf.
  system2("Rscript", c(SCRIPT, shQuote(DOSSIER), "2", REP, "sans_cache"),
          env = "CPL_VSIL_CURL_CACHE_SIZE=65536")
  res[[length(res) + 1L]] <- readRDS(fichier("etape2c.rds"))
  # 2e : copie locale, mêmes lectures (cache disque vidé avant chaque image).
  copies <- fichier("copie", sprintf("img%02d.tif", seq_len(n_img)))
  froid <- NA
  for (rep in seq_len(REP)) {
    for (pas in c(LIGNES_BLOC, 512L)) {
      for (i in seq_len(n_img)) {
        froid <- vider_cache_disque()
        w <- fenetres[[i]]
        wl <- list(ligne = 1L, colonne = 1L, nl = w$nl, nc = w$nc)
        m <- lire_fenetre(copies[i], wl, pas, bord = if (pas == 512L) 0L else 1L)
        ajoute(sprintf("local, %d lignes", pas), rep, i, w, m)
      }
    }
  }
  # 2f : chaîne actuelle, s1_lire() (recadrage, reprojection bilinéaire sur
  # une grille UTM 30N de 10 m, écriture de la pile), 3 images : distant,
  # puis depuis les copies locales (sans réseau).
  r1 <- terra::rast(copies[1])
  centre <- terra::geom(terra::project(terra::vect(cbind(POINT[1], POINT[2]), crs = "EPSG:4326"),
                                       "EPSG:32630"))[1, c("x", "y")]
  cx <- round(centre[["x"]], -1)
  cy <- round(centre[["y"]], -1)
  grille <- terra::rast(xmin = cx - 7000, xmax = cx + 7000, ymin = cy - 3500, ymax = cy + 3500,
                        resolution = 10, crs = "EPSG:32630")
  for (rep in seq_len(REP)) {
    for (src in c("distant", "local")) {
      it <- items[1:3, ]
      if (src == "local") it$url <- copies[1:3]
      sortie <- fichier("s1_lire", src)
      unlink(sortie, recursive = TRUE)
      froid <- vider_cache_disque()
      b0 <- octets_recus()
      t0 <- proc.time()[["elapsed"]]
      s <- suppressWarnings(s1_lire(it, grille, signer = (src == "distant"), dossier = sortie))
      dt <- proc.time()[["elapsed"]] - t0
      res[[length(res) + 1L]] <- data.frame(
        cas = paste0("s1_lire(), ", src, ", grille 1400 x 700 (3 images)"), repetition = rep,
        image = NA, n_images = 3, mo_utiles = 3 * terra::ncell(grille) * 4 / 1e6,
        recu_mo = (octets_recus() - b0) / 1e6, ouverture_s = NA, lecture_s = NA, total_s = dt)
    }
  }
  tab <- do.call(rbind, res)
  attr(tab, "cache_disque_vide") <- froid
  attr(tab, "taille_copie_mo") <- sum(file.size(copies)) / 1e6
  attr(tab, "n_images") <- n_img
  attr(tab, "crs_orbite") <- terra::crs(r1, describe = TRUE)$code
  saveRDS(tab, fichier("etape2.rds"))
  invisible(tab)
}

# Étape 3 : passe 1 en série et en parallèle -----------------------------------

NL3 <- 36L      # lignes des piles de la passe 1 (4 blocs de 9 lignes)
NC3 <- 10980L   # largeur d'une tuile MGRS
NT3 <- 300L     # dates par orbite

# Piles de 36 x 10 980 x 300 par orbite, faites des copies locales réelles
# (D008, 2025) : lignes différentes pour chaque « orbite » (décalage de 300
# lignes), colonnes répétées jusqu'à 10 980, année 2025 répétée sur 2016-2025
# avec un décalage de 7 colonnes par année (pas deux fois la même série en un
# pixel). Valeurs réelles, structure répétée : le coût de calcul par pixel
# est celui de données réelles, pas la détection.
construire_piles <- function() {
  items <- items_orbite()
  items <- items[items$serie == ORBITE, ]
  copies <- fichier("copie", sprintf("img%02d.tif", seq_len(nrow(items))))
  fichiers <- fichier(sprintf("pile_o%d.tif", 1:3))
  dates_o <- list()
  for (k in 1:3) {
    l0 <- 1L + (k - 1L) * 300L
    v <- lapply(copies, function(f) {
      m <- terra::readValues(terra::rast(f), row = l0, nrows = NL3, mat = FALSE)
      matrix(m, nrow = LARGEUR)   # [colonne, ligne]
    })
    couches <- list()
    dts <- as.Date(character(0))
    for (y in 9:0) {
      for (j in seq_along(v)) {
        cols <- ((seq_len(NC3) - 1L + 7L * y) %% LARGEUR) + 1L
        couches[[length(couches) + 1L]] <- as.vector(v[[j]][cols, ])
        dts <- c(dts, as.Date(sprintf("%d-%s", 2025L - y, format(items$date[j], "%m-%d"))))
      }
    }
    o <- order(dts)
    garde <- utils::tail(o, NT3)
    garde <- garde[order(dts[garde])]
    r <- terra::rast(nrows = NL3, ncols = NC3, nlyrs = NT3, xmin = 600000,
                     xmax = 600000 + 10 * NC3, ymin = 5000000, ymax = 5000000 + 10 * NL3,
                     crs = "EPSG:32630")
    terra::values(r) <- do.call(cbind, couches[garde])
    terra::writeRaster(r, fichiers[k], overwrite = TRUE, datatype = "FLT4S")
    dates_o[[k]] <- dts[garde]
    rm(couches, r)
    invisible(gc())
  }
  saveRDS(list(fichiers = fichiers, dates = dates_o), fichier("piles.rds"))
}

# Passe 1 de nemetonsar_detecter() (même boucle, mêmes fonctions), sur K
# orbites, en série (lapply) ou en parallèle (mclapply, un processus par
# orbite et par bloc). Chaque orbite ouvre son fichier dans son processus.
passe1 <- function(K, parallele) {
  piles <- readRDS(fichier("piles.rds"))
  p <- valide_parametres(parametres_sufosat())
  rf <- (p$fenetre_filtre - 1L) %/% 2L
  debuts <- seq(1L, NL3, by = LIGNES_BLOC)
  ratio <- matrix(NA_real_, NC3, NL3)
  date <- matrix(NA_integer_, NC3, NL3)
  une_orbite <- function(k, lu) {
    t0 <- proc.time()[["elapsed"]]
    r <- terra::rast(piles$fichiers[k])
    terra::readStart(r)
    serie <- terra::readValues(r, row = lu$debut, nrows = lu$n, col = 1, ncols = NC3, mat = FALSE)
    terra::readStop(r)
    dim(serie) <- c(NC3, lu$n, terra::nlyr(r))
    t1 <- proc.time()[["elapsed"]]
    serie <- s1_filter_multitemp(serie, piles$dates[[k]], p)
    attr(serie, "nb_images_noyau") <- NULL
    t2 <- proc.time()[["elapsed"]]
    res <- rcr_compute(serie, piles$dates[[k]], p)
    t3 <- proc.time()[["elapsed"]]
    list(res = res, t = c(lecture = t1 - t0, filtre = t2 - t1, ratio = t3 - t2),
         hwm = if (parallele) vm_hwm_mo() else NA_real_)
  }
  temps <- c(lecture = 0, filtre = 0, ratio = 0)
  hwm_fils <- 0
  t0 <- proc.time()[["elapsed"]]
  for (d in debuts) {
    n <- min(LIGNES_BLOC, NL3 - d + 1L)
    lu <- bande_bordee(d, n, rf, NL3)
    sorties <- if (parallele) {
      parallel::mclapply(seq_len(K), une_orbite, lu = lu, mc.cores = K,
                         mc.preschedule = FALSE)
    } else {
      lapply(seq_len(K), une_orbite, lu = lu)
    }
    for (s in sorties) {
      temps <- temps + s$t
      hwm_fils <- max(hwm_fils, s$hwm, na.rm = TRUE)
    }
    comb <- rcr_combine_orbites(lapply(sorties, `[[`, "res"), p)
    rm(sorties)
    ratio[, d + seq_len(n) - 1L] <- comb$ratio_min_db[, lu$centre, drop = FALSE]
    date[, d + seq_len(n) - 1L] <- comb$date_min[, lu$centre, drop = FALSE]
    rm(comb)
  }
  total <- proc.time()[["elapsed"]] - t0
  list(total = total, temps = temps, hwm_pere = vm_hwm_mo(), hwm_fils = hwm_fils,
       empreinte = digest_simple(ratio, date))
}
digest_simple <- function(ratio, date) {
  f <- tempfile()
  saveRDS(list(ratio, date), f, compress = FALSE)
  e <- unname(tools::md5sum(f))
  unlink(f)
  e
}

# Une configuration, dans un processus neuf (pic mémoire propre).
passe1_processus <- function(K, parallele, rep) {
  sortie <- fichier(sprintf("p1_K%d_%s_r%d.rds", K, if (parallele) "par" else "ser", rep))
  journal_mem <- fichier("memoire.txt")
  froid <- vider_cache_disque()
  pid <- memoire_debut(journal_mem)
  r <- passe1(K, parallele)
  r$pic_total_mo <- memoire_fin(pid, journal_mem)
  r$cache_disque_vide <- froid
  r$K <- K
  r$parallele <- parallele
  r$repetition <- rep
  saveRDS(r, sortie)
}

etape3 <- function() {
  if (!file.exists(fichier("piles.rds"))) construire_piles()
  for (rep in seq_len(REP)) {
    for (K in 1:3) {
      for (par in c(FALSE, TRUE)) {
        if (K == 1L && par) next
        cat(sprintf("passe 1 : K = %d, %s, répétition %d\n", K, if (par) "parallèle" else "série", rep))
        system2("Rscript", c(SCRIPT, shQuote(DOSSIER), "3", REP,
                             sprintf("passe1:%d:%d:%d", K, as.integer(par), rep)))
      }
    }
  }
}

# Étape 4 : synthèse et extrapolation -------------------------------------------

etape4 <- function() {
  t2 <- readRDS(fichier("etape2.rds"))
  cat("\n== Lecture d'une orbite (par image : moyenne des images, puis des répétitions) ==\n")
  par_cas <- do.call(rbind, lapply(split(t2, t2$cas), function(x) {
    rep_moy <- aggregate(cbind(total_s, recu_mo, mo_utiles, n_images) ~ repetition, x, sum)
    n <- rep_moy$n_images[1]
    data.frame(cas = x$cas[1], images = n,
               s_par_image_r1 = rep_moy$total_s[1] / n,
               s_par_image_r2 = if (nrow(rep_moy) > 1) rep_moy$total_s[2] / rep_moy$n_images[2] else NA,
               mo_utiles_par_image = rep_moy$mo_utiles[1] / n,
               recu_mo_par_image = mean(rep_moy$recu_mo) / n,
               s_par_mo_utile = mean(rep_moy$total_s / rep_moy$mo_utiles))
  }))
  print(par_cas, row.names = FALSE, digits = 3)
  cat(sprintf("Copie locale : %.0f Mo pour %d images (%.2f octet par valeur) ; cache disque vidé : %s ; CRS de l'orbite : %s\n",
              attr(t2, "taille_copie_mo"), attr(t2, "n_images"),
              attr(t2, "taille_copie_mo") * 1e6 / (attr(t2, "n_images") * LARGEUR * HAUTEUR),
              attr(t2, "cache_disque_vide"), attr(t2, "crs_orbite")))

  f3 <- list.files(DOSSIER, "^p1_K", full.names = TRUE)
  p1 <- do.call(rbind, lapply(f3, function(f) {
    r <- readRDS(f)
    data.frame(K = r$K, mode = if (r$parallele) "parallele" else "serie", rep = r$repetition,
               total_s = r$total, lecture_s = r$temps[["lecture"]],
               filtre_s = r$temps[["filtre"]], ratio_s = r$temps[["ratio"]],
               hwm_pere_mo = r$hwm_pere, hwm_fils_mo = r$hwm_fils,
               pic_total_mo = r$pic_total_mo, empreinte = r$empreinte)
  }))
  p1 <- p1[order(p1$K, p1$mode, p1$rep), ]
  cat("\n== Passe 1 (36 x 10 980 x 300 dates par orbite, blocs de 9 lignes) ==\n")
  print(p1[, names(p1) != "empreinte"], row.names = FALSE, digits = 4)
  for (K in unique(p1$K)) {
    cat(sprintf("K = %d : empreintes identiques entre série, parallèle et répétitions : %s\n",
                K, length(unique(p1$empreinte[p1$K == K])) == 1L))
  }
  saveRDS(list(lecture = par_cas, passe1 = p1), fichier("synthese.rds"))

  # Extrapolation (linéaire) à une tuile MGRS : 10 980 x 10 980 pixels,
  # 300 dates x 3 orbites = 900 images.
  px_tuile <- 10980^2
  facteur <- px_tuile / (NL3 * NC3)
  moy <- function(K, mode, col) mean(p1[p1$K == K & p1$mode == mode, col])
  serie3 <- moy(3, "serie", "total_s") * facteur / 3600
  par3 <- moy(3, "parallele", "total_s") * facteur / 3600
  lect3 <- moy(3, "serie", "lecture_s") * facteur / 3600
  filt3 <- moy(3, "serie", "filtre_s") * facteur / 3600
  rat3 <- moy(3, "serie", "ratio_s") * facteur / 3600
  # Gains du prototype C de la mission 016 (par bloc et par orbite) :
  # filtre 3,3 à 4,0 s -> 0,5 s ; ratio 2,6 s -> 1,1 s.
  gf <- c(0.5 / 4.0, 0.5 / 3.3)
  gr <- 1.1 / 2.6
  c_serie <- lect3 + filt3 * gf + rat3 * gr + (serie3 - lect3 - filt3 - rat3)
  # Acquisition (s1_lire) : téléchargement + reprojection + écriture.
  sl <- function(src) par_cas$s_par_mo_utile[par_cas$cas == sprintf("s1_lire(), %s, grille 1400 x 700 (3 images)", src)]
  mo_tuile <- px_tuile * 4 / 1e6 * 900
  acq_dist <- sl("distant") * mo_tuile / 3600
  acq_loc <- sl("local") * mo_tuile / 3600
  recu <- par_cas$recu_mo_par_image[par_cas$cas == "distant, 512 lignes (aligné)"] /
    par_cas$mo_utiles_par_image[par_cas$cas == "distant, 512 lignes (aligné)"]
  debit1 <- with(par_cas[par_cas$cas == "distant, 512 lignes (aligné)", ],
                 recu_mo_par_image / mean(c(s_par_image_r1, s_par_image_r2)))
  debit4 <- with(par_cas[par_cas$cas == "distant, 512 lignes, 4 processus (8 images)", ],
                 recu_mo_par_image / mean(c(s_par_image_r1, s_par_image_r2)))
  ampli <- with(par_cas, recu_mo_par_image[cas == "distant, 9 lignes, cache insuffisant"] /
                  mo_utiles_par_image[cas == "distant, 9 lignes, cache insuffisant"]) / recu
  cat("\n== Extrapolation linéaire à une tuile MGRS (10 980 x 10 980, 300 dates x 3 orbites) ==\n")
  cat(sprintf("Facteur passe 1 : x %.0f (pixels)\n", facteur))
  cat(sprintf("Passe 1, base R en série : %.1f h (lecture locale %.1f h, filtre %.1f h, ratio %.1f h)\n",
              serie3, lect3, filt3, rat3))
  cat(sprintf("Passe 1, base R, 3 orbites en parallèle : %.1f h\n", par3))
  cat(sprintf("Passe 1, C (gains du prototype 016) en série : %.1f à %.1f h\n", min(c_serie), max(c_serie)))
  cat(sprintf("Volume utile d'une tuile : %.0f Go (float32) ; reçu par Mo utile : %.2f ; à télécharger : %.0f Go\n",
              mo_tuile / 1e3, recu, mo_tuile * recu / 1e3))
  cat(sprintf("Débit mesuré : %.1f Mo/s (1 flux), %.1f Mo/s (4 processus)\n", debit1, debit4))
  cat(sprintf("Téléchargement seul d'une tuile : %.1f h (1 flux), %.1f h (4 processus)\n",
              mo_tuile * recu / debit1 / 3600, mo_tuile * recu / debit4 / 3600))
  cat(sprintf("s1_lire() : distant %.1f h, depuis copie locale (reprojection + écriture) %.1f h\n",
              acq_dist, acq_loc))
  cat(sprintf("Lecture distante par 9 lignes sans cache : x %.0f d'octets reçus, soit %.0f h de téléchargement (1 flux)\n",
              ampli, mo_tuile * recu * ampli / debit1 / 3600))
  cat(sprintf("Disque d'une pile locale de tuile (3 orbites, %.2f octet par valeur) : %.0f Go\n",
              attr(t2, "taille_copie_mo") * 1e6 / (attr(t2, "n_images") * LARGEUR * HAUTEUR),
              attr(t2, "taille_copie_mo") * 1e6 / (attr(t2, "n_images") * LARGEUR * HAUTEUR) * px_tuile * 900 / 1e9))
}

# Lancement -------------------------------------------------------------------

if (SOUS_COMMANDE == "sans_cache") {
  lecture_sans_cache()
} else if (startsWith(SOUS_COMMANDE, "passe1:")) {
  a <- as.integer(strsplit(SOUS_COMMANDE, ":")[[1]][-1])
  passe1_processus(a[1], as.logical(a[2]), a[3])
} else {
  if (1L %in% ETAPES) etape1()
  if (2L %in% ETAPES) etape2()
  if (3L %in% ETAPES) etape3()
  if (4L %in% ETAPES) etape4()
}
