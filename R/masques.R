#' Masque forêt : Tree Cover Density 2018, corrigé par les détections 2019
#'
#' Prépare le masque forêt de l'étape 3 de la méthode SUFOSAT sur la grille
#' d'une tuile : M24 (Mermoz et al., 2024, § II-D.1, p. 13747-13748) retient
#' comme forêt les pixels de **couvert arborescent minimal de 10 %** (Tree
#' Cover Density 2018 de Copernicus CLMS, définition de la forêt de la FAO),
#' puis met ce masque à jour avec les détections de l'année **2019** pour
#' retirer les sols nus et les cultures à forte variabilité.
#'
#' 1. **Valeurs du TCD.** Les valeurs de 0 à 100 sont un pourcentage de
#'    couvert. Toute autre valeur (en particulier 254 et 255, codes
#'    « non classable » et « hors zone » du produit CLMS) est tenue pour
#'    **sans donnée** (`NA`) avant le rééchantillonnage, pour qu'un code ne
#'    se mélange pas à un pourcentage. **Provisoire : codes 254 et 255 de
#'    mémoire, spécification CLMS du produit non relue ; à confirmer par
#'    l'acquereur.**
#' 2. **Rééchantillonnage** sur `grille` (système de coordonnées compris :
#'    le TCD est distribué en EPSG:3035, la grille est en UTM) par
#'    [terra::project()], méthode `methode`. Défaut `"near"` (plus proche
#'    voisin, le TCD et la grille étant tous deux à 10 m). **Provisoire, non
#'    sourcé (M24 ne dit pas comment le TCD est mis sur la grille), gèle au
#'    jalon 2.** `"average"` donne la moyenne des pixels TCD couverts, plus
#'    juste si le TCD est plus fin que la grille.
#' 3. **Seuil.** Un pixel est forêt si son couvert est **supérieur ou égal**
#'    à `parametres$seuil_tcd` (10 %) : M24 écrit « minimum tree cover of
#'    10% » (table de la mission 001), donc un couvert de 10 % exactement est
#'    forêt et 9,9 % ne l'est pas. Tolérance absolue de `1e-9` pour
#'    l'arithmétique flottante (méthodes qui moyennent).
#' 4. **Correction 2019.** Si `detections_2019` est fourni, les pixels
#'    détectés en 2019, élargis de `marge_2019` pixels (carré de côté
#'    `2 * marge_2019 + 1`), sont **retirés** de la forêt. M24 ne précise pas
#'    la règle de mise à jour : **retrait pixel à pixel, sans marge,
#'    provisoire, non sourcé, gèle au jalon 2.**
#'
#' @section Sans donnée : Un pixel dont le TCD est sans donnée (code, `NA`,
#'   hors de l'emprise du TCD) vaut `NA` dans le masque : ni forêt ni
#'   non-forêt. [masquer_hors_foret()] l'exclut comme un pixel non forestier.
#'   **Provisoire, non sourcé.**
#'
#' @section Détections 2019 : Elles viennent d'une détection lancée sur
#'   2019 avec le seul masque TCD (M24 : la méthode est appliquée d'abord aux
#'   données de 2019, puis de janvier 2020 à juillet 2023). On peut passer :
#'   * un `SpatRaster` à une couche, par exemple `dates.tif` ou `objets.tif`
#'     de [nemetonsar_detecter()] : est détectée toute cellule ni `NA` ni
#'     nulle (ni `FALSE`) ; s'il n'est pas sur `grille`, il y est projeté au
#'     plus proche voisin ;
#'   * un `SpatVector` de polygones, par exemple `objets.gpkg` : sont
#'     détectées les cellules de `grille` dont le centre est dans un
#'     polygone ([terra::rasterize()]) ; il est reprojeté si besoin.
#'
#'   Seules les détections de 2019 doivent être passées : la fonction ne
#'   filtre pas les dates.
#'
#' @param tcd Le Tree Cover Density 2018 : un `SpatRaster` à une couche, ou
#'   le chemin d'un fichier lisible par [terra::rast()]. Valeurs en
#'   pourcentage (0 à 100).
#' @param grille Un `SpatRaster` qui donne la grille de sortie (étendue,
#'   résolution, système de coordonnées) ; ses valeurs ne sont pas lues.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seul
#'   `seuil_tcd` sert ici.
#' @param detections_2019 `NULL` (pas de correction), un `SpatRaster` ou un
#'   `SpatVector` des détections de 2019 (voir la section « Détections
#'   2019 »).
#' @param methode Méthode de rééchantillonnage du TCD passée à
#'   [terra::project()] : `"near"` (défaut, provisoire), `"average"` ou
#'   `"bilinear"`.
#' @param marge_2019 Nombre entier de pixels (au moins 0) dont on élargit
#'   les détections 2019 avant de les retirer. Défaut 0. **Provisoire.**
#' @param fichier Chemin où écrire le masque (GeoTIFF), ou `""` (défaut)
#'   pour le garder en mémoire ou en fichier temporaire de `terra`.
#'
#' @return Un `SpatRaster` logique à une couche nommée `foret`, sur
#'   `grille` : `TRUE` forêt, `FALSE` non-forêt (sous le seuil ou détecté en
#'   2019), `NA` sans donnée.
#'
#' @seealso [masquer_hors_foret()], [masque_feu()], [parametres_sufosat()].
#'
#' @examples
#' # TCD synthétique à 20 m en Lambert-93 étendu (EPSG:3035), grille UTM à 10 m
#' tcd <- terra::rast(nrows = 10, ncols = 10, xmin = 3700000, xmax = 3700200,
#'                    ymin = 2800000, ymax = 2800200, crs = "EPSG:3035")
#' terra::values(tcd) <- rep(c(0, 9, 10, 50, 255), each = 20)
#' grille <- terra::rast(terra::project(terra::ext(tcd), "EPSG:3035", "EPSG:32631"),
#'                       resolution = 10, crs = "EPSG:32631")
#' foret <- masque_foret(tcd, grille)
#' terra::freq(foret)
#'
#' @export
masque_foret <- function(tcd, grille, parametres = parametres_sufosat(),
                         detections_2019 = NULL, methode = "near",
                         marge_2019 = 0L, fichier = "") {
  p <- valide_parametres(parametres)
  if (is.character(tcd) && length(tcd) == 1L && !is.na(tcd)) {
    tcd <- terra::rast(tcd)
  }
  valide_raster_une_couche(tcd, "tcd")
  valide_grille(grille)
  if (!is.character(methode) || length(methode) != 1L ||
      !methode %in% c("near", "average", "bilinear")) {
    stop("`methode` doit valoir \"near\", \"average\" ou \"bilinear\".", call. = FALSE)
  }
  if (!est_scalaire_num(marge_2019) || !is.finite(marge_2019) || marge_2019 < 0 ||
      marge_2019 != floor(marge_2019)) {
    stop("`marge_2019` doit \u00eatre un nombre entier de pixels, au moins \u00e9gal \u00e0 0.",
         call. = FALSE)
  }
  valide_fichier(fichier)

  # 1. Codes hors 0-100 : sans donnée.
  tcd <- terra::ifel(tcd >= 0 & tcd <= 100, tcd, NA)
  # 2. Sur la grille (système de coordonnées compris).
  tcd <- terra::project(tcd, terra::rast(grille), method = methode)
  # 3. Seuil : couvert >= seuil_tcd (M24 : « minimum tree cover of 10% »).
  foret <- tcd >= p$seuil_tcd - 1e-9

  # 4. Correction par les détections 2019.
  if (!is.null(detections_2019)) {
    det <- detections_sur_grille(detections_2019, grille)
    if (marge_2019 > 0) {
      k <- 2L * as.integer(marge_2019) + 1L
      det <- terra::focal(det, w = matrix(1, k, k), fun = "max", na.rm = TRUE,
                          expand = FALSE, fillvalue = 0)
      det <- det > 0
    }
    foret <- foret & !det
  }
  names(foret) <- "foret"
  if (nzchar(fichier)) {
    foret <- terra::writeRaster(foret, fichier, overwrite = TRUE, datatype = "INT1U",
                                names = "foret")
    foret <- foret == 1
    names(foret) <- "foret"
  }
  foret
}

#' Mettre à `NA` les pixels hors forêt
#'
#' Applique un masque forêt ([masque_foret()]) à un raster de la même
#' grille, couche par couche : toute cellule dont le masque n'est pas `TRUE`
#' (non-forêt ou sans donnée) devient `NA`. Sert à appliquer le masque avant
#' la segmentation : sur les piles Sentinel-1 (le pixel n'a alors aucune
#' image et n'est jamais détecté), ou sur le ratio et la date (le pixel est
#' alors « sans donnée » pour [rcr_segment()] et [postprocess()]).
#'
#' Masquer les **piles** change le filtre multitemporel des pixels de forêt
#' en lisière : la moyenne spatiale 3 x 3 de [s1_filter_multitemp()] ignore
#' les voisins `NA`. Masquer le **ratio** après le filtre ne change rien aux
#' pixels de forêt. M24 ne dit pas où le masque s'applique dans la chaîne.
#'
#' @param x Un `SpatRaster` (une ou plusieurs couches).
#' @param foret Le masque forêt, `SpatRaster` logique à une couche, sur la
#'   même grille que `x`.
#' @param fichier Chemin où écrire le résultat, ou `""` (défaut).
#'
#' @return `x`, avec `NA` hors forêt ; mêmes noms de couches.
#'
#' @seealso [masque_foret()].
#'
#' @examples
#' grille <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 40,
#'                       ymin = 0, ymax = 40, crs = "EPSG:32631")
#' pile <- terra::rast(grille, nlyrs = 2, vals = 0.05)
#' foret <- terra::rast(grille, vals = rep(c(TRUE, FALSE), 8)) == 1
#' terra::values(masquer_hors_foret(pile, foret))[1:4, ]
#'
#' @export
masquer_hors_foret <- function(x, foret, fichier = "") {
  if (!inherits(x, "SpatRaster")) {
    stop("`x` doit \u00eatre un SpatRaster.", call. = FALSE)
  }
  valide_raster_une_couche(foret, "foret")
  if (!isTRUE(terra::compareGeom(x, foret, stopOnError = FALSE))) {
    stop("`foret` doit \u00eatre sur la m\u00eame grille que `x` (voir masque_foret()).",
         call. = FALSE)
  }
  valide_fichier(fichier)
  garde <- terra::ifel(foret, 1, NA)
  if (nzchar(fichier)) {
    terra::mask(x, garde, filename = fichier, overwrite = TRUE)
  } else {
    terra::mask(x, garde)
  }
}

#' Masque feu : retrait des objets brûlés (EFFIS)
#'
#' Applique l'étape 8 de la méthode SUFOSAT : M24 (§ II-D.1, p. 13748)
#' écarte les objets détectés touchés par le feu sur **75 % ou plus** de leur
#' surface, d'après les surfaces brûlées annuelles d'EFFIS. Un objet est donc
#' retiré si sa part brûlée est **supérieure ou égale** à
#' `parametres$seuil_feu` (0,75, une fraction) : à 75 % exactement il est
#' retiré, à 74 % il est gardé. Tolérance relative de `1e-9` pour
#' l'arithmétique flottante.
#'
#' La **part brûlée** d'un objet est la surface de son intersection avec la
#' réunion des polygones de `brules` (les recouvrements entre polygones ne
#' comptent qu'une fois), divisée par sa surface. Les surfaces sont
#' calculées dans le système de coordonnées des objets (planes s'il est
#' projeté) ; `brules` y est reprojeté si besoin.
#'
#' @section Période : M24 parle d'un masquage **temporaire** (une forêt
#'   brûlée, morte ou coupée ensuite, est détectée plus tard). La fonction ne
#'   choisit pas les années : on passe dans `brules` les surfaces brûlées à
#'   rapprocher des objets (par exemple l'année de la détection). **La règle
#'   d'appariement des années n'est pas précisée par M24 : à trancher.**
#'
#' @param objets Les objets détectés : un `SpatVector` de polygones avec une
#'   colonne `identifiant` (comme la couche `objets` de `objets.gpkg` écrite
#'   par [nemetonsar_detecter()]), ou un `SpatRaster` à une couche des
#'   identifiants (comme `objets.tif`, `NA` hors objet), vectorisé par
#'   [terra::as.polygons()].
#' @param brules Un `SpatVector` de polygones des surfaces brûlées (EFFIS),
#'   avec un système de coordonnées. Peut être vide (aucun objet retiré).
#' @param parametres Un objet créé par [parametres_sufosat()] ; seul
#'   `seuil_feu` sert ici.
#'
#' @return Une liste :
#'   * `objets` : `SpatVector` des objets gardés, avec leurs colonnes et une
#'     colonne `part_brulee` (fraction de 0 à 1) ;
#'   * `retires` : `SpatVector` des objets retirés, mêmes colonnes ;
#'   * `table` : `data.frame` d'une ligne par objet d'entrée, `identifiant`,
#'     `surface_brulee_ha`, `part_brulee`, `retire` (logique) ;
#'   * `raster` : si `objets` est un `SpatRaster`, le même raster où les
#'     identifiants des objets retirés valent `NA` ; sinon `NULL`.
#'
#' @seealso [masque_foret()], [nemetonsar_detecter()], [parametres_sufosat()].
#'
#' @examples
#' carre <- function(x0, y0, cote, crs = "EPSG:32631") {
#'   terra::vect(sprintf("POLYGON ((%f %f, %f %f, %f %f, %f %f, %f %f))",
#'                       x0, y0, x0 + cote, y0, x0 + cote, y0 + cote,
#'                       x0, y0 + cote, x0, y0), crs = crs)
#' }
#' objets <- rbind(carre(0, 0, 100), carre(200, 0, 100))
#' objets$identifiant <- 1:2
#' brules <- carre(0, 0, 100)       # objet 1 brûlé en entier
#' res <- masque_feu(objets, brules)
#' res$table
#'
#' @export
masque_feu <- function(objets, brules, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  raster_entree <- NULL
  if (inherits(objets, "SpatRaster")) {
    valide_raster_une_couche(objets, "objets")
    raster_entree <- objets
    objets <- terra::as.polygons(objets, dissolve = TRUE, na.rm = TRUE)
    names(objets) <- "identifiant"
  }
  if (!inherits(objets, "SpatVector") || terra::geomtype(objets) != "polygons") {
    stop("`objets` doit \u00eatre un SpatVector de polygones ou un SpatRaster des identifiants.",
         call. = FALSE)
  }
  if (!"identifiant" %in% names(objets)) {
    stop("`objets` doit avoir une colonne `identifiant`.", call. = FALSE)
  }
  if (anyNA(objets$identifiant) || anyDuplicated(objets$identifiant)) {
    stop("La colonne `identifiant` de `objets` doit \u00eatre sans NA ni doublon.", call. = FALSE)
  }
  if (!nzchar(terra::crs(objets))) {
    stop("`objets` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  if (!inherits(brules, "SpatVector") ||
      (nrow(brules) > 0L && terra::geomtype(brules) != "polygons")) {
    stop("`brules` doit \u00eatre un SpatVector de polygones (surfaces br\u00fbl\u00e9es EFFIS).",
         call. = FALSE)
  }
  if (!nzchar(terra::crs(brules))) {
    stop("`brules` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }

  plan <- !isTRUE(terra::is.lonlat(objets))
  surface <- function(v) terra::expanse(v, unit = "m", transform = !plan)
  id <- objets$identifiant
  surf <- surface(objets)
  brule_m2 <- numeric(length(id))
  if (nrow(objets) > 0L && nrow(brules) > 0L) {
    if (!terra::same.crs(brules, objets)) {
      brules <- terra::project(brules, objets)
    }
    zone <- terra::aggregate(brules)
    touche <- as.vector(terra::is.related(objets, zone, "intersects"))
    if (any(touche)) {
      morceaux <- terra::intersect(objets[touche, "identifiant"], zone)
      s <- tapply(surface(morceaux), factor(morceaux$identifiant, levels = id), sum)
      s[is.na(s)] <- 0
      brule_m2 <- as.numeric(s)
    }
  }
  part <- ifelse(surf > 0, pmin(brule_m2 / surf, 1), 0)
  retire <- part >= p$seuil_feu * (1 - 1e-9)

  objets$part_brulee <- part
  table <- data.frame(
    identifiant = id,
    surface_brulee_ha = brule_m2 / 1e4,
    part_brulee = part,
    retire = retire
  )
  raster <- NULL
  if (!is.null(raster_entree)) {
    raster <- raster_entree
    if (any(retire)) {
      raster <- terra::classify(raster_entree, cbind(id[retire], NA))
    }
  }
  list(
    objets = objets[!retire],
    retires = objets[retire],
    table = table,
    raster = raster
  )
}

# Validation et utilitaires ----------------------------------------------------

valide_raster_une_couche <- function(x, nom) {
  if (!inherits(x, "SpatRaster") || terra::nlyr(x) != 1L) {
    stop("`", nom, "` doit \u00eatre un SpatRaster \u00e0 une couche.", call. = FALSE)
  }
  invisible(x)
}

valide_grille <- function(grille) {
  if (!inherits(grille, "SpatRaster")) {
    stop("`grille` doit \u00eatre un SpatRaster (la grille de sortie).", call. = FALSE)
  }
  if (!nzchar(terra::crs(grille))) {
    stop("`grille` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
  }
  invisible(grille)
}

valide_fichier <- function(fichier) {
  if (!is.character(fichier) || length(fichier) != 1L || is.na(fichier)) {
    stop("`fichier` doit \u00eatre un chemin, ou \"\".", call. = FALSE)
  }
  invisible(fichier)
}

# Détections 2019 rendues en raster logique sur `grille` (TRUE détecté,
# FALSE ailleurs, jamais NA).
detections_sur_grille <- function(det, grille) {
  modele <- terra::rast(grille)
  if (inherits(det, "SpatVector")) {
    if (nrow(det) == 0L) {
      return(terra::rast(modele, vals = FALSE))
    }
    if (terra::geomtype(det) != "polygons") {
      stop("`detections_2019` doit contenir des polygones.", call. = FALSE)
    }
    if (!nzchar(terra::crs(det))) {
      stop("`detections_2019` doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
    }
    if (!terra::same.crs(det, modele)) {
      det <- terra::project(det, modele)
    }
    r <- terra::rasterize(det, modele, field = 1, background = 0, touches = FALSE)
    return(r == 1)
  }
  if (inherits(det, "SpatRaster")) {
    valide_raster_une_couche(det, "detections_2019")
    if (!isTRUE(terra::compareGeom(det, modele, stopOnError = FALSE))) {
      det <- terra::project(det, modele, method = "near")
    }
    d <- terra::ifel(is.na(det), 0, det)
    return(d != 0)
  }
  stop("`detections_2019` doit \u00eatre NULL, un SpatRaster ou un SpatVector.", call. = FALSE)
}
