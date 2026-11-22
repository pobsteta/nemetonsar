#' Chaîne de détection sur rasters, par blocs de lignes
#'
#' Applique la chaîne complète de la méthode SUFOSAT à des piles
#' [terra::rast()] (une par orbite) : filtre multitemporel
#' ([s1_filter_multitemp()]), ratio de changement ([rcr_compute()]),
#' combinaison des orbites ([rcr_combine_orbites()]), segmentation
#' ([rcr_segment()]) et post-traitement ([postprocess()]). Les piles sont lues
#' par blocs de lignes, pour que la mémoire ne dépende que de la largeur du
#' raster, du nombre de dates et de `lignes_par_bloc` ; le résultat est
#' **identique** à celui de la chaîne appliquée au tableau entier.
#'
#' @section Orientation : Les fonctions de la chaîne reçoivent des matrices
#'   `[colonne, ligne]` du raster (transposées) : l'ordre « colonne par
#'   colonne » de ces matrices est alors l'ordre des cellules de `terra`
#'   (ligne par ligne, de haut en bas). Les objets sont donc numérotés dans
#'   l'ordre de leur première cellule. Le filtre (fenêtre carrée), la
#'   connexité et la fermeture (carré) sont symétriques : la transposition ne
#'   change rien d'autre.
#'
#' @section Blocs et bordures : Le calcul se fait en trois passes sur des
#'   bandes de `lignes_par_bloc` lignes.
#'   1. **Filtre, ratio, combinaison.** Chaque bande est lue avec une bordure
#'      de `(fenetre_filtre - 1) / 2` lignes de chaque côté : c'est le rayon
#'      du filtre, seule opération spatiale de cette passe (le ratio et la
#'      combinaison sont calculés pixel par pixel). Seule la partie centrale
#'      est gardée ; au bord du raster, la bande s'arrête au bord, et le
#'      filtre y réplique le bord comme sur le tableau entier.
#'   2. **Segmentation et retrait des petits objets.** Les composantes
#'      connexes des zones `ratio <= tp` sont étiquetées bande par bande, sans
#'      bordure ; les étiquettes qui se touchent d'une bande à la suivante
#'      (voisins verticaux, et diagonaux en connexité 8) sont fusionnées
#'      ensuite. Une zone est gardée si elle contient une graine (`ratio < ts`)
#'      et si sa surface, sommée sur toutes ses bandes, atteint
#'      `surface_min_ha`.
#'   3. **Fermeture et réétiquetage.** La fermeture (dilatation puis érosion
#'      par un carré de côté `taille_fermeture`, de rayon
#'      `(taille_fermeture - 1) / 2`) d'un pixel dépend des pixels à moins de
#'      deux rayons : chaque bande est lue avec une bordure de
#'      `taille_fermeture - 1` lignes. Les objets fermés sont étiquetés puis fusionnés entre bandes
#'      comme en 2 ; un objet coupé par une limite de bloc n'est donc compté
#'      qu'une fois.
#'
#'   Les rasters intermédiaires (ratio et date de toutes les détections
#'   possibles, étiquettes) sont écrits dans `dossier`, sous des noms
#'   commençant par `.nemetonsar_tmp_`, et effacés à la fin.
#'
#' @section Mémoire : Le pic vient de la passe 1 : pour une orbite, la bande
#'   bordée est un tableau pixels x dates en double, que le filtre puis
#'   [rcr_compute()] recopient (pic du tas R de l'ordre de six fois la bande
#'   lue, mesuré ; voir `docs/analyses/performance.md`, mission 016). Les passes 2
#'   et 3 ne gardent qu'une bande de quelques matrices pixels, plus une
#'   entrée par composante connexe (étiquettes, tailles, première cellule) et
#'   par couple (objet, date) : ces tables grandissent avec le nombre de
#'   composantes de la tuile, pas avec sa surface.
#'
#' @section Masque forêt : Avec `foret`, le ratio et la date sont mis à `NA`
#'   hors forêt (cellules du masque qui ne valent pas `TRUE`) **après la
#'   passe 1** : le filtre multitemporel et le ratio des pixels de forêt sont
#'   calculés sur les piles entières, puis les pixels hors forêt deviennent
#'   « sans donnée » pour la segmentation et le post-traitement (option B,
#'   décision du 2026-11-22). Masquer le ratio plutôt que les piles ne change
#'   pas le filtre en lisière (voir [masquer_hors_foret()]). M24 ne dit pas où
#'   le masque s'applique dans la chaîne : **provisoire, gèle au jalon 2.**
#'
#' @section Sorties : Écrits dans `dossier` (créé s'il manque ; les fichiers
#'   existants du même nom sont écrasés), sur la grille et dans le système de
#'   coordonnées des piles d'entrée :
#'   - `dates.tif` : entier 32 bits (`INT4S`), date de la coupe en `YYDDD`
#'     (champ `date_min` de [rcr_compute()]) ; `NA` (valeur de non-donnée
#'     déclarée dans le fichier) hors détection ;
#'   - `ratio.tif` : réel 32 bits (`FLT4S`), ratio minimal en dB ; `NA` hors
#'     détection ;
#'   - `objets.tif` : entier 32 bits, identifiant de l'objet (`NA` ailleurs),
#'     le même que dans le GeoPackage ;
#'   - `objets.gpkg` (couche `objets`) : un polygone par objet
#'     ([terra::as.polygons()]), avec les colonnes de la table de
#'     [postprocess()] (`date_mediane` en `YYDDD`, `date_mediane_date` en
#'     texte `AAAA-MM-JJ`, `surface_ha`, `ratio_moyen_db`, ...). Sans aucun
#'     objet, le GeoPackage n'est pas écrit (`terra` n'écrit pas de couche
#'     vide).
#'
#'   Dans `dates.tif` et `ratio.tif`, seuls les pixels détectés **avant** la
#'   fermeture portent une valeur : les pixels comblés par la fermeture
#'   appartiennent à l'objet (`objets.tif`, surface) mais n'ont pas de chute
#'   mesurée, comme dans la table de [postprocess()]. **Provisoire, non
#'   sourcé.**
#'
#' @param orbites Liste (nommée de préférence : les noms désignent les
#'   orbites) de `SpatRaster`, une couche par date, valeurs **linéaires**,
#'   tous sur la même grille et dans le même système de coordonnées projeté
#'   (en mètres, par exemple UTM).
#' @param dates Liste parallèle à `orbites` de vecteurs de classe `Date`, un
#'   par orbite, d'autant d'éléments que la pile a de couches.
#' @param dossier Dossier où écrire les sorties.
#' @param parametres Un objet créé par [parametres_sufosat()].
#' @param lignes_par_bloc Nombre de lignes du raster lues à la fois (sans la
#'   bordure). `NULL` : environ 2,5e8 octets de valeurs lues par bloc
#'   (`floor(2.5e8 / (8 * colonnes * dates))` lignes, au moins 1), soit, par
#'   mesure, un pic de l'ordre de 1,5 Go pour la passe 1. **Provisoire**,
#'   à revoir sur une tuile pilote.
#' @param resolution_m Côté du pixel, en mètres, pour les surfaces. `NULL` :
#'   lu dans le raster (pixels carrés exigés).
#' @param foret `NULL` (pas de masque) ou masque forêt : `SpatRaster` à une
#'   couche sur la même grille que les piles (par exemple [masque_foret()]),
#'   à trois états : `TRUE` (ou 1) forêt, `FALSE` (ou 0) non-forêt, `NA`
#'   sans donnée, **traité comme non-forêt**. Voir la section « Masque
#'   forêt ».
#' @return Une liste : `fichiers`, vecteur nommé des chemins écrits
#'   (`dates`, `ratio`, `objets_raster`, `objets`) ; `objets`, la table des
#'   objets (mêmes colonnes que celle de [postprocess()]) ; `lignes_par_bloc`,
#'   la taille de bloc utilisée.
#' @seealso [s1_filter_multitemp()], [rcr_compute()], [rcr_combine_orbites()],
#'   [rcr_segment()], [postprocess()].
#' @examples
#' # Deux orbites synthétiques de 20 x 20 pixels (UTM 31N), une coupe de
#' # -6 dB au 1er juillet 2019 sur un carré de 6 x 6 pixels.
#' grille <- terra::rast(nrows = 20, ncols = 20, xmin = 600000, xmax = 600200,
#'                       ymin = 5000000, ymax = 5000200, crs = "EPSG:32631")
#' pile <- function(dates) {
#'   set.seed(1)
#'   v <- matrix(0.05 * stats::rgamma(400 * length(dates), 50, 50),
#'               nrow = 400)
#'   coupe <- (rep(1:20, each = 20) %in% 8:13) & (rep(1:20, 20) %in% 5:10)
#'   apres <- dates >= as.Date("2019-07-01")
#'   v[coupe, apres] <- v[coupe, apres] * 10^(-6 / 10)
#'   r <- terra::rast(grille, nlyrs = length(dates))
#'   terra::values(r) <- v
#'   r
#' }
#' dates_a <- seq(as.Date("2018-01-03"), as.Date("2019-12-31"), by = 12)
#' dates_d <- seq(as.Date("2018-01-09"), as.Date("2019-12-31"), by = 12)
#' res <- nemetonsar_detecter(
#'   orbites = list(asc = pile(dates_a), desc = pile(dates_d)),
#'   dates = list(dates_a, dates_d),
#'   dossier = file.path(tempdir(), "nemetonsar-exemple"),
#'   lignes_par_bloc = 5
#' )
#' res$objets
#' terra::plot(terra::rast(res$fichiers[["dates"]]))
#' @export
nemetonsar_detecter <- function(orbites, dates, dossier,
                                parametres = parametres_sufosat(),
                                lignes_par_bloc = NULL,
                                resolution_m = NULL,
                                foret = NULL) {
  p <- valide_parametres(parametres)
  valide_orbites(orbites, dates)
  modele <- orbites[[1]]
  if (!is.null(foret)) {
    if (!inherits(foret, "SpatRaster") || terra::nlyr(foret) != 1L) {
      stop("`foret` doit \u00eatre NULL ou un SpatRaster \u00e0 une couche (voir masque_foret()).",
           call. = FALSE)
    }
    if (!isTRUE(terra::compareGeom(modele, foret, stopOnError = FALSE))) {
      stop("`foret` doit \u00eatre sur la m\u00eame grille et dans le m\u00eame syst\u00e8me que les piles de `orbites`.",
           call. = FALSE)
    }
  }
  if (is.null(resolution_m)) {
    resolution_m <- resolution_carree(modele)
  } else if (!est_scalaire_num(resolution_m) || !is.finite(resolution_m) ||
             resolution_m <= 0) {
    stop("`resolution_m` doit \u00eatre NULL ou un nombre strictement positif (en m\u00e8tres).",
         call. = FALSE)
  }
  nl <- terra::nrow(modele)
  nc <- terra::ncol(modele)
  if (is.null(lignes_par_bloc)) {
    nt_max <- max(vapply(orbites, terra::nlyr, numeric(1)))
    lignes_par_bloc <- max(1L, as.integer(floor(2.5e8 / (8 * nc * nt_max))))
  } else if (!est_scalaire_num(lignes_par_bloc) || !is.finite(lignes_par_bloc) ||
             lignes_par_bloc < 1 || lignes_par_bloc != round(lignes_par_bloc)) {
    stop("`lignes_par_bloc` doit \u00eatre NULL ou un entier au moins \u00e9gal \u00e0 1.",
         call. = FALSE)
  }
  lignes_par_bloc <- as.integer(min(lignes_par_bloc, nl))
  if (!is.character(dossier) || length(dossier) != 1L || is.na(dossier) || !nzchar(dossier)) {
    stop("`dossier` doit \u00eatre un chemin (cha\u00eene de caract\u00e8res).", call. = FALSE)
  }
  if (!dir.exists(dossier)) {
    dir.create(dossier, recursive = TRUE)
  }
  chemin <- function(nom) file.path(dossier, nom)
  tmp <- chemin(paste0(".nemetonsar_tmp_", c("ratio", "date", "zone", "objet"), ".tif"))
  names(tmp) <- c("ratio", "date", "zone", "objet")
  on.exit(unlink(tmp[file.exists(tmp)]), add = TRUE)
  sorties <- c(
    dates = chemin("dates.tif"),
    ratio = chemin("ratio.tif"),
    objets_raster = chemin("objets.tif"),
    objets = chemin("objets.gpkg")
  )

  debuts <- seq(1L, nl, by = lignes_par_bloc)
  blocs <- data.frame(debut = debuts, n = pmin(lignes_par_bloc, nl - debuts + 1L))
  s <- seuils_db(p)

  # Passe 1 : filtre, ratio, combinaison, par bande bordée. --------------------
  rf <- (p$fenetre_filtre - 1L) %/% 2L
  ecr_ratio <- ecrivain(modele, tmp[["ratio"]], "FLT8S")
  ecr_date <- ecrivain(modele, tmp[["date"]], "INT4S")
  for (o in orbites) terra::readStart(o)
  if (!is.null(foret)) terra::readStart(foret)
  for (b in seq_len(nrow(blocs))) {
    lu <- bande_bordee(blocs$debut[b], blocs$n[b], rf, nl)
    resultats <- lapply(seq_along(orbites), function(k) {
      # Lu en vecteur puis mis en forme par dim<- : pas de copie.
      serie <- terra::readValues(orbites[[k]], row = lu$debut, nrows = lu$n,
                                 col = 1, ncols = nc, mat = FALSE)
      dim(serie) <- c(nc, lu$n, terra::nlyr(orbites[[k]]))
      serie <- s1_filter_multitemp(serie, dates[[k]], p)
      attr(serie, "nb_images_noyau") <- NULL
      rcr_compute(serie, dates[[k]], p)
    })
    names(resultats) <- names(orbites)
    comb <- rcr_combine_orbites(resultats, p)
    rm(resultats)
    garde <- lu$centre
    ratio_b <- comb$ratio_min_db[, garde, drop = FALSE]
    date_b <- comb$date_min[, garde, drop = FALSE]
    rm(comb)
    if (!is.null(foret)) {
      # Masque forêt (option B) : NA hors forêt ; NA du masque = non-forêt.
      f <- lire_bande(foret, blocs$debut[b], blocs$n[b], nc)
      hors <- is.na(f) | f == 0
      ratio_b[hors] <- NA_real_
      date_b[hors] <- NA_integer_
    }
    terra::writeValues(ecr_ratio, as.vector(ratio_b), blocs$debut[b], blocs$n[b])
    terra::writeValues(ecr_date, as.vector(date_b), blocs$debut[b], blocs$n[b])
    rm(ratio_b, date_b)
  }
  for (o in orbites) terra::readStop(o)
  if (!is.null(foret)) terra::readStop(foret)
  terra::writeStop(ecr_ratio)
  terra::writeStop(ecr_date)
  r_ratio <- terra::rast(tmp[["ratio"]])
  r_date <- terra::rast(tmp[["date"]])

  # Passe 2 : zones <= tp étiquetées par bande, fusionnées entre bandes. -------
  ecr_zone <- ecrivain(modele, tmp[["zone"]], "INT4S")
  terra::readStart(r_ratio)
  z <- nouvelles_etiquettes()
  graine_lab <- list()
  for (b in seq_len(nrow(blocs))) {
    ratio <- lire_bande(r_ratio, blocs$debut[b], blocs$n[b], nc)
    valide <- !is.na(ratio)
    zone <- valide & ratio <= s[["tp"]]
    graine <- valide & ratio < s[["ts"]]
    lab <- etiquette_bande(zone, p$connexite, z, blocs$debut[b], nc)
    z <- lab$etat
    graine_lab[[b]] <- unique(lab$matrice[graine])
    terra::writeValues(ecr_zone, as.vector(lab$matrice), blocs$debut[b], blocs$n[b])
  }
  terra::readStop(r_ratio)
  terra::writeStop(ecr_zone)
  r_zone <- terra::rast(tmp[["zone"]])
  racine_z <- racines_equivalences(z$n, z$a, z$b)
  taille_z <- somme_par(z$taille, racine_z, z$n)
  seme <- logical(z$n)
  seme[racine_z[unlist(graine_lab, use.names = FALSE)]] <- TRUE
  petit <- taille_z * resolution_m^2 < p$surface_min_ha * 1e4 * (1 - 1e-9)
  garde_z <- (seme & !petit)[racine_z]
  rm(graine_lab, seme, petit, taille_z)

  # Passe 3 : fermeture par bande bordée, objets étiquetés et fusionnés. -------
  rc <- if (p$fermeture && p$taille_fermeture > 1L) (p$taille_fermeture - 1L) %/% 2L else 0L
  ecr_objet <- ecrivain(modele, tmp[["objet"]], "INT4S")
  ecr_dates <- ecrivain(modele, sorties[["dates"]], "INT4S")
  ecr_rsort <- ecrivain(modele, sorties[["ratio"]], "FLT4S")
  for (r in list(r_ratio, r_date, r_zone)) terra::readStart(r)
  ob <- nouvelles_etiquettes()
  paires <- list()
  somme_lin <- list()
  for (b in seq_len(nrow(blocs))) {
    lu <- bande_bordee(blocs$debut[b], blocs$n[b], 2L * rc, nl)
    lab_z <- lire_bande(r_zone, lu$debut, lu$n, nc)
    sans_donnee <- is.na(lire_bande(r_ratio, lu$debut, lu$n, nc))
    avant <- !is.na(lab_z)
    avant[avant] <- garde_z[lab_z[avant]]
    ferme <- if (rc > 0L) fermeture_carre(avant, sans_donnee, p$taille_fermeture) else avant
    centre <- lu$centre
    ferme <- ferme[, centre, drop = FALSE]
    avant <- avant[, centre, drop = FALSE]
    ratio <- lire_bande(r_ratio, blocs$debut[b], blocs$n[b], nc)
    date <- lire_bande(r_date, blocs$debut[b], blocs$n[b], nc)
    lab <- etiquette_bande(ferme, p$connexite, ob, blocs$debut[b], nc)
    ob <- lab$etat
    # Date et ratio : pixels de l'objet détectés avant la fermeture.
    dans <- avant & ferme
    l <- lab$matrice[dans]
    d <- date[dans]
    a_d <- !is.na(d)
    cle <- sort(l[a_d] * 1e5 + d[a_d])
    rl <- rle(cle)
    paires[[b]] <- list(cle = rl$values, n = rl$lengths)
    rr <- ratio[dans]
    a_r <- !is.na(rr)
    somme_lin[[b]] <- list(lab = l[a_r], lin = db_vers_lineaire(rr[a_r]))
    date[!dans] <- NA_integer_
    ratio[!dans] <- NA_real_
    terra::writeValues(ecr_objet, as.vector(lab$matrice), blocs$debut[b], blocs$n[b])
    terra::writeValues(ecr_dates, as.vector(date), blocs$debut[b], blocs$n[b])
    terra::writeValues(ecr_rsort, as.vector(ratio), blocs$debut[b], blocs$n[b])
  }
  for (r in list(r_ratio, r_date, r_zone)) terra::readStop(r)
  terra::writeStop(ecr_objet)
  terra::writeStop(ecr_dates)
  terra::writeStop(ecr_rsort)

  # Objets : racines, numérotation par première cellule, table. ---------------
  racine_o <- racines_equivalences(ob$n, ob$a, ob$b)
  # Racines rangées par première cellule de leur objet.
  par_cellule <- order(ob$premiere)
  racines <- unique(racine_o[par_cellule])
  identifiant <- match(racine_o, racines)
  k <- length(racines)
  table <- table_objets_blocs(
    identifiant, k, ob$taille, resolution_m^2,
    paires, somme_lin
  )

  # Raster des objets : étiquettes de bande -> identifiants. -------------------
  r_objet <- terra::rast(tmp[["objet"]])
  ecr_obj <- ecrivain(modele, sorties[["objets_raster"]], "INT4S")
  terra::readStart(r_objet)
  for (b in seq_len(nrow(blocs))) {
    v <- terra::readValues(r_objet, row = blocs$debut[b], nrows = blocs$n[b],
                           col = 1, ncols = nc, mat = FALSE)
    a <- !is.na(v)
    v[a] <- identifiant[v[a]]
    terra::writeValues(ecr_obj, v, blocs$debut[b], blocs$n[b])
  }
  terra::readStop(r_objet)
  terra::writeStop(ecr_obj)

  # GeoPackage. ----------------------------------------------------------------
  if (k > 0L) {
    r_id <- terra::rast(sorties[["objets_raster"]])
    names(r_id) <- "identifiant"
    poly <- terra::as.polygons(r_id, dissolve = TRUE, values = TRUE, na.rm = TRUE)
    attributs <- table
    attributs$date_mediane_date <- format(attributs$date_mediane_date, "%Y-%m-%d")
    attributs <- attributs[match(poly$identifiant, attributs$identifiant), , drop = FALSE]
    terra::values(poly) <- attributs
    poly <- poly[order(poly$identifiant), ]
    terra::writeVector(poly, sorties[["objets"]], filetype = "GPKG",
                       layer = "objets", overwrite = TRUE)
  } else {
    if (file.exists(sorties[["objets"]])) unlink(sorties[["objets"]])
    sorties <- sorties[names(sorties) != "objets"]
  }

  list(fichiers = sorties, objets = table, lignes_par_bloc = lignes_par_bloc)
}

# Outils des blocs ------------------------------------------------------------

# Lignes à lire pour une bande [debut, debut + n - 1] avec une bordure de
# `bord` lignes de chaque côté, rognée au raster ; `centre` : colonnes de la
# matrice [colonne, ligne] lue qui correspondent à la bande.
bande_bordee <- function(debut, n, bord, nl) {
  de <- max(1L, debut - bord)
  a <- min(nl, debut + n - 1L + bord)
  list(debut = de, n = a - de + 1L, centre = (debut - de) + seq_len(n))
}

# Lit `n` lignes d'une couche, en matrice [colonne, ligne].
lire_bande <- function(r, debut, n, nc) {
  v <- terra::readValues(r, row = debut, nrows = n, col = 1, ncols = nc, mat = FALSE)
  matrix(v, nrow = nc, ncol = n)
}

# Ouvre l'écriture d'une couche sur la grille de `modele`.
ecrivain <- function(modele, fichier, type) {
  sortie <- terra::rast(modele, nlyrs = 1)
  terra::writeStart(sortie, fichier, overwrite = TRUE, datatype = type,
                    names = sub("\\.tif$", "", basename(fichier)))
  sortie
}

# État de l'étiquetage par bandes : nombre d'étiquettes, arêtes à fusionner
# (a, b), taille et première cellule de chaque étiquette, étiquettes de la
# dernière ligne de la bande précédente.
nouvelles_etiquettes <- function() {
  list(n = 0L, a = integer(0), b = integer(0), taille = numeric(0),
       premiere = numeric(0), derniere_ligne = NULL)
}

# Étiquette les composantes de `masque` (matrice [colonne, ligne] d'une
# bande commençant à la ligne `debut`), avec des étiquettes globales qui
# suivent celles des bandes précédentes, et note les arêtes avec la dernière
# ligne de la bande précédente. Rend la matrice des étiquettes (NA hors
# masque) et l'état mis à jour.
etiquette_bande <- function(masque, connexite, etat, debut, nc) {
  racine <- etiquette_composantes(masque, connexite)
  dedans <- which(masque)
  u <- unique(racine[dedans])
  local <- match(racine[dedans], u)
  m <- matrix(NA_integer_, nrow(masque), ncol(masque))
  m[dedans] <- etat$n + local
  cellule <- (debut - 1) * nc + dedans
  taille <- tabulate(local, nbins = length(u))
  # `dedans` est croissant : la première occurrence d'une étiquette est sa
  # plus petite cellule.
  premiere <- cellule[match(seq_along(u), local)]
  # Arêtes avec la bande précédente.
  haut <- etat$derniere_ligne
  bas <- m[, 1L]
  a <- integer(0)
  b <- integer(0)
  if (!is.null(haut)) {
    decalages <- if (connexite == 8L) c(-1L, 0L, 1L) else 0L
    for (dj in decalages) {
      j <- seq_len(nc)
      jj <- j + dj
      ok <- jj >= 1L & jj <= nc
      x <- haut[j[ok]]
      y <- bas[jj[ok]]
      lien <- !is.na(x) & !is.na(y)
      a <- c(a, x[lien])
      b <- c(b, y[lien])
    }
  }
  etat$a <- c(etat$a, a)
  etat$b <- c(etat$b, b)
  etat$taille <- c(etat$taille, taille)
  etat$premiere <- c(etat$premiere, premiere)
  etat$n <- etat$n + length(u)
  etat$derniere_ligne <- m[, ncol(m)]
  list(matrice = m, etat = etat)
}

# Racine (plus petite étiquette) de chaque étiquette 1..n, les arêtes (a, b)
# reliant deux étiquettes de la même composante. Même union-find vectorisé
# que etiquette_composantes().
racines_equivalences <- function(n, a, b) {
  parent <- seq_len(n)
  compresse <- function(parent) {
    repeat {
      suivant <- parent[parent]
      if (identical(suivant, parent)) return(parent)
      parent <- suivant
    }
  }
  while (length(a) > 0L) {
    ra <- parent[a]
    rb <- parent[b]
    differe <- ra != rb
    if (!any(differe)) break
    ra <- ra[differe]
    rb <- rb[differe]
    a <- a[differe]
    b <- b[differe]
    haute <- pmax(ra, rb)
    basse <- pmin(ra, rb)
    o <- order(basse, decreasing = TRUE)
    parent[haute[o]] <- basse[o]
    parent <- compresse(parent)
  }
  parent
}

# Somme de `x` par groupe (entiers 1..n), rendue pour chaque groupe.
somme_par <- function(x, groupe, n) {
  s <- numeric(n)
  if (length(x) == 0L) return(s)
  r <- rowsum(as.numeric(x), groupe, reorder = TRUE)
  s[as.integer(rownames(r))] <- r[, 1L]
  s
}

# Table des objets, mêmes colonnes et mêmes règles que table_objets() de
# postprocess() (médiane basse des dates, moyenne linéaire des ratios rendue
# en dB, sur les pixels détectés avant la fermeture), à partir des comptes
# agrégés par bande.
table_objets_blocs <- function(identifiant, k, taille, surface_pixel_m2,
                               paires, somme_lin) {
  id <- seq_len(k)
  nb <- as.integer(round(somme_par(taille, identifiant, k)))
  nb_dates <- rep(NA_integer_, k)
  mediane <- rep(NA_integer_, k)
  ratio_moyen <- rep(NA_real_, k)
  if (k > 0L) {
    cle <- unlist(lapply(paires, `[[`, "cle"), use.names = FALSE)
    n <- unlist(lapply(paires, `[[`, "n"), use.names = FALSE)
    lab <- floor(cle / 1e5)
    d <- as.integer(round(cle - lab * 1e5))
    obj <- identifiant[lab]
    nb_dates <- as.integer(round(somme_par(n, obj, k)))
    # Médiane basse par objet : dates YYDDD triées (ordre chronologique dans
    # un même siècle), comptes cumulés.
    # Un seul tri, puis comptes cumulés dans chaque objet : la médiane est la
    # première date dont le compte cumulé atteint le rang (nb + 1) %/% 2.
    # Linéaire en nombre de couples (objet, date) après le tri.
    o <- order(obj, d)
    obj <- obj[o]
    d <- d[o]
    cum <- cumsum(as.numeric(n[o]))
    debut <- !duplicated(obj)
    avant <- c(0, cum)[which(debut)][cumsum(debut)]
    rang <- (nb_dates[obj] + 1L) %/% 2L
    atteint <- which(cum - avant >= rang)
    premiere <- atteint[!duplicated(obj[atteint])]
    mediane[obj[premiere]] <- d[premiere]
    lab_r <- unlist(lapply(somme_lin, `[[`, "lab"), use.names = FALSE)
    lin <- unlist(lapply(somme_lin, `[[`, "lin"), use.names = FALSE)
    obj_r <- identifiant[lab_r]
    compte <- tabulate(obj_r, nbins = k)
    somme <- somme_par(lin, obj_r, k)
    ratio_moyen <- ifelse(compte > 0L, 10 * log10(somme / compte), NA_real_)
  }
  data.frame(
    identifiant = id,
    nb_pixels = nb,
    surface_ha = nb * surface_pixel_m2 / 1e4,
    nb_pixels_dates = nb_dates,
    date_mediane = mediane,
    date_mediane_date = yyddd_vers_date(mediane),
    ratio_moyen_db = ratio_moyen
  )
}

# Validation ------------------------------------------------------------------

valide_orbites <- function(orbites, dates) {
  if (!is.list(orbites) || length(orbites) < 1L ||
      !all(vapply(orbites, inherits, logical(1), what = "SpatRaster"))) {
    stop("`orbites` doit \u00eatre une liste d'au moins un SpatRaster (une couche par date).",
         call. = FALSE)
  }
  if (!is.list(dates) || length(dates) != length(orbites)) {
    stop("`dates` doit \u00eatre une liste de m\u00eame longueur que `orbites` (un vecteur de dates par orbite).",
         call. = FALSE)
  }
  modele <- orbites[[1]]
  if (!nzchar(terra::crs(modele))) {
    stop("Les rasters de `orbites` doivent avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  if (isTRUE(terra::is.lonlat(modele))) {
    stop("Les rasters de `orbites` doivent \u00eatre dans un syst\u00e8me projet\u00e9 en m\u00e8tres (par exemple UTM), pas en degr\u00e9s.",
         call. = FALSE)
  }
  for (k in seq_along(orbites)) {
    if (k > 1L && !isTRUE(terra::compareGeom(modele, orbites[[k]], stopOnError = FALSE))) {
      stop("L'orbite ", k, " n'a pas la m\u00eame grille ou le m\u00eame syst\u00e8me de coordonn\u00e9es que la premi\u00e8re.",
           call. = FALSE)
    }
    valide_dates_serie(dates[[k]], terra::nlyr(orbites[[k]]))
  }
  invisible(TRUE)
}

resolution_carree <- function(r) {
  re <- terra::res(r)
  if (!isTRUE(all.equal(re[1], re[2]))) {
    stop("Pixels non carr\u00e9s (", re[1], " x ", re[2], ") : donner `resolution_m`.",
         call. = FALSE)
  }
  re[1]
}
