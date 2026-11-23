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
  valide_marge_2019(marge_2019)
  valide_fichier(fichier)

  # 1. Codes hors 0-100 : sans donnée.
  tcd <- terra::ifel(tcd >= 0 & tcd <= 100, tcd, NA)
  # 2. Sur la grille (système de coordonnées compris).
  tcd <- terra::project(tcd, terra::rast(grille), method = methode)
  # 3. Seuil : couvert >= seuil_tcd (M24 : « minimum tree cover of 10% »).
  foret <- tcd >= p$seuil_tcd - 1e-9

  # 4. Correction par les détections 2019.
  foret <- corriger_2019(foret, detections_2019, grille, marge_2019)
  sortie_foret(foret, fichier)
}

#' Masque forêt : BD Forêt v2 de l'IGN, corrigé par les détections 2019
#'
#' Construit le masque forêt sur la grille d'une tuile à partir des
#' polygones de la **BD Forêt® version 2.0** de l'IGN, à la place du Tree
#' Cover Density 2018 de [masque_foret()] (décision de Pascal du
#' 2026-11-22, journal `cap`, mission 020). **Écart à la méthode de
#' l'article** (M24 utilise le TCD 2018) : à dire dans le rapport de
#' comparaison.
#'
#' 1. **Lecture.** `bdforet` est un fichier vecteur (Shapefile ou GeoPackage
#'    de l'IGN, lu sur l'emprise de `grille` seulement), un `SpatVector`, ou
#'    `NULL` (ou `"wfs"`) pour lire le service WFS de la Géoplateforme
#'    (couche `LANDCOVER.FORESTINVENTORY.V2:formation_vegetale`, GeoJSON en
#'    Lambert-93, pages de 5 000 objets) sur l'emprise de `grille` : on ne
#'    télécharge que les polygones qui la touchent.
#' 2. **Codes.** Le champ `CODE_TFV` (nom cherché sans tenir compte de la
#'    casse : `CODE_TFV` dans les fichiers livrés, `code_tfv` dans le WFS)
#'    donne le type de formation végétale. Est forêt un polygone dont le
#'    code est dans `codes_foret`. Défaut : les **30 postes rattachés au
#'    niveau I « Forêt »** de la nomenclature nationale (descriptif de
#'    contenu de la BD Forêt v2.0, IGN, novembre 2018, annexe A, rubrique
#'    « Rattachements » de chaque fiche ; annexe B : FF forêt fermée,
#'    couvert arboré de plus de 40 %, FO forêt ouverte, de 10 à 40 %, FP
#'    peupleraie, plus de 10 %) : tous les codes `FF...`, `FO...` et `FP`.
#'    Les deux postes rattachés au niveau I « Lande » (`LA4` lande, `LA6`
#'    formation herbacée, moins de 10 % de couvert arboré) sont non-forêt.
#'    Les postes `FF0` et `FO0` (« sans couvert arboré » : coupe rase,
#'    incident, jeune peuplement) sont forêt au sens de l'IGN et donc dans
#'    le défaut, alors que le TCD les verrait peu couverts : **à trancher
#'    par Pascal**. Un code hors des 32 postes de la nomenclature donne un
#'    avertissement (il est non-forêt s'il n'est pas dans `codes_foret`).
#' 3. **Rastérisation** sur `grille` : les polygones sont reprojetés dans le
#'    système de `grille` (Lambert-93 vers UTM), puis une cellule est forêt
#'    si son **centre** est dans un polygone forestier ([terra::rasterize()],
#'    `touches = FALSE`). **Provisoire, non sourcé, gèle au jalon 2.**
#' 4. **Correction 2019** : la même que [masque_foret()] (`detections_2019`,
#'    `marge_2019`).
#'
#' @section Les trois états : `TRUE` forêt ; `FALSE` non-forêt : cellule
#'   dont le centre est dans un polygone non forestier **ou hors de tout
#'   polygone** (la BD Forêt ne décrit que les espaces naturels et
#'   semi-naturels : les terres agricoles et bâties n'y sont pas) ; `NA`
#'   sans donnée : centre dans un polygone sans code (et dans aucun polygone
#'   forestier), ou hors de `couverture` si elle est donnée (zone où la BD
#'   Forêt est réputée complète, par exemple les départements livrés).
#'
#' @param bdforet La BD Forêt v2 : chemin d'un fichier vecteur lisible par
#'   [terra::vect()], `SpatVector` de polygones avec un système de
#'   coordonnées, ou `NULL` (ou `"wfs"`) pour lire le service WFS.
#' @param grille Un `SpatRaster` qui donne la grille de sortie ; ses valeurs
#'   ne sont pas lues.
#' @param codes_foret Vecteur de codes TFV comptés comme forêt. Défaut : les
#'   30 postes du niveau I « Forêt » (voir plus haut).
#' @param champ_code Nom du champ des codes TFV, sans tenir compte de la
#'   casse. Défaut `"code_tfv"`.
#' @param detections_2019,marge_2019 Correction 2019, comme dans
#'   [masque_foret()].
#' @param couverture `NULL` (défaut : toute la grille est couverte), ou un
#'   `SpatVector` de polygones : les cellules dont le centre en est dehors
#'   valent `NA`.
#' @param couche Nom de la couche à lire si `bdforet` est un fichier à
#'   plusieurs couches (GeoPackage) ; `NULL` : la première.
#' @param fichier Chemin où écrire le masque (GeoTIFF), ou `""` (défaut).
#'
#' @return Un `SpatRaster` logique à une couche nommée `foret`, sur
#'   `grille` (voir « Les trois états »), avec un attribut `bdforet` : liste
#'   `source` (texte), `nb_polygones` (lus sur l'emprise), `codes` (table
#'   des codes lus : `code`, `nb`, `foret`).
#'
#' @seealso [masque_foret()], [masquer_hors_foret()], [nemetonsar_run()].
#'
#' @examples
#' # Deux polygones en Lambert-93 : un pin maritime pur, une lande.
#' carre <- function(x0, y0, cote) {
#'   terra::vect(sprintf("POLYGON ((%f %f, %f %f, %f %f, %f %f, %f %f))",
#'                       x0, y0, x0 + cote, y0, x0 + cote, y0 + cote,
#'                       x0, y0 + cote, x0, y0), crs = "EPSG:2154")
#' }
#' bdf <- rbind(carre(400000, 6350000, 100), carre(400100, 6350000, 100))
#' bdf$CODE_TFV <- c("FF2-51-51", "LA4")
#' grille <- terra::rast(terra::project(terra::ext(400000, 400200, 6350000, 6350100),
#'                                      "EPSG:2154", "EPSG:32630"),
#'                       resolution = 10, crs = "EPSG:32630")
#' foret <- masque_foret_bdforet(bdf, grille)
#' terra::freq(foret)
#'
#' \dontrun{
#' # Lecture du service WFS de la Géoplateforme sur l'emprise de la grille
#' foret <- masque_foret_bdforet(NULL, grille)
#' }
#'
#' @export
masque_foret_bdforet <- function(bdforet, grille, codes_foret = .bdforet_codes_foret,
                                 champ_code = "code_tfv", detections_2019 = NULL,
                                 marge_2019 = 0L, couverture = NULL, couche = NULL,
                                 fichier = "") {
  valide_grille(grille)
  if (!is.character(codes_foret) || length(codes_foret) == 0L || anyNA(codes_foret)) {
    stop("`codes_foret` doit \u00eatre un vecteur de codes TFV (texte, sans NA).", call. = FALSE)
  }
  if (!is.character(champ_code) || length(champ_code) != 1L || is.na(champ_code)) {
    stop("`champ_code` doit \u00eatre un nom de champ.", call. = FALSE)
  }
  valide_marge_2019(marge_2019)
  valide_fichier(fichier)
  if (!is.null(couverture) &&
      (!inherits(couverture, "SpatVector") || nrow(couverture) == 0L ||
       terra::geomtype(couverture) != "polygons" || !nzchar(terra::crs(couverture)))) {
    stop("`couverture` doit \u00eatre NULL ou un SpatVector de polygones avec un syst\u00e8me de coordonn\u00e9es.",
         call. = FALSE)
  }
  modele <- terra::rast(grille)

  lu <- bdforet_lire(bdforet, modele, couche)
  v <- lu$v
  source <- lu$source
  codes <- character(0)
  if (nrow(v) > 0L) {
    champ <- names(v)[tolower(names(v)) == tolower(champ_code)]
    if (length(champ) != 1L) {
      stop("La BD For\u00eat n'a pas de champ `", champ_code, "` (codes TFV) ; champs : ",
           paste(names(v), collapse = ", "), ".", call. = FALSE)
    }
    codes <- trimws(as.character(v[[champ]][[1]]))
    codes[!is.na(codes) & !nzchar(codes)] <- NA_character_
    inconnus <- setdiff(unique(stats::na.omit(codes)), .bdforet_tfv$code)
    if (length(inconnus) > 0L) {
      warning("Code(s) TFV hors des 32 postes de la nomenclature BD For\u00eat v2 : ",
              paste(sort(inconnus), collapse = ", "),
              if (length(setdiff(inconnus, codes_foret)) > 0L) " (compt\u00e9s non-for\u00eat)." else ".",
              call. = FALSE)
    }
  }
  est_foret <- !is.na(codes) & codes %in% codes_foret
  sans_code <- is.na(codes)

  rasteriser <- function(w) {
    if (nrow(w) == 0L) return(terra::rast(modele, vals = FALSE))
    terra::rasterize(w, modele, field = 1, background = 0, touches = FALSE) == 1
  }
  foret <- rasteriser(v[est_foret])
  if (any(sans_code)) {
    inconnu <- rasteriser(v[sans_code])
    foret <- terra::ifel(inconnu & !foret, NA, foret)
  }
  if (!is.null(couverture)) {
    if (!terra::same.crs(couverture, modele)) {
      couverture <- terra::project(couverture, terra::crs(modele))
    }
    dedans <- rasteriser(couverture)
    foret <- terra::ifel(dedans, foret, NA)
  }
  foret <- foret == 1 # ifel() rend des 0/1 : retour au logique
  foret <- corriger_2019(foret, detections_2019, grille, marge_2019)
  foret <- sortie_foret(foret, fichier)

  tab <- if (length(codes) > 0L) as.data.frame(table(code = codes, useNA = "ifany"),
                                               stringsAsFactors = FALSE) else
    data.frame(code = character(0), Freq = integer(0))
  names(tab) <- c("code", "nb")
  tab$foret <- !is.na(tab$code) & tab$code %in% codes_foret
  attr(foret, "bdforet") <- list(source = source, nb_polygones = nrow(v), codes = tab)
  foret
}

# BD Forêt v2 : nomenclature et service WFS -------------------------------------
#
# Source : IGN, BD Forêt version 2.0, descriptif de contenu (février 2014,
# révisé novembre 2018), § 5.1.2 (32 valeurs de CODE_TFV), annexe A
# (« Rattachements », niveau I « Forêt » ou « Lande » de chaque poste) et
# annexe B (niveaux I et II du code). Document lu le 2026-11-22 :
# https://data.geopf.fr/annexes/ressources/documentation/DC_BDForet_2-0.pdf
# (lien de la fiche de métadonnées IGNF_BD-FORET de la Géoplateforme).
# Libellés, dans l'ordre : forêt fermée sans couvert arboré ; feuillus purs
# en îlots ; chênes décidus purs ; chênes sempervirents purs ; hêtre pur ;
# châtaignier pur ; robinier pur ; autre feuillu pur ; mélange de feuillus ;
# conifères purs en îlots ; pin maritime pur ; pin sylvestre pur ; pin
# laricio ou pin noir pur ; pin d'Alep pur ; pin à crochets ou pin cembro
# pur ; autre pin pur ; mélange de pins purs ; sapin ou épicéa ; mélèze
# pur ; douglas pur ; autre conifère pur autre que pin ; mélange d'autres
# conifères ; mélange de conifères ; mélange de feuillus prépondérants et
# conifères ; mélange de conifères prépondérants et feuillus ; forêt
# ouverte sans couvert arboré ; forêt ouverte de feuillus purs ; de
# conifères purs ; à mélange de feuillus et conifères ; peupleraie ; lande ;
# formation herbacée.
.bdforet_tfv <- data.frame(
  code = c("FF0", "FF1-00", "FF1G01-01", "FF1G06-06", "FF1-09-09", "FF1-10-10",
           "FF1-14-14", "FF1-49-49", "FF1-00-00", "FF2-00", "FF2-51-51", "FF2-52-52",
           "FF2G53-53", "FF2-57-57", "FF2G58-58", "FF2-81-81", "FF2-80-80", "FF2G61-61",
           "FF2-63-63", "FF2-64-64", "FF2-91-91", "FF2-90-90", "FF2-00-00", "FF31",
           "FF32", "FO0", "FO1", "FO2", "FO3", "FP", "LA4", "LA6"),
  niveau_1 = c(rep("foret", 30L), "lande", "lande"),
  stringsAsFactors = FALSE
)
.bdforet_codes_foret <- .bdforet_tfv$code[.bdforet_tfv$niveau_1 == "foret"]

# Service WFS de la Géoplateforme (GetCapabilities lu le 2026-11-22 :
# couche « BD Forêt v2 (2006-2019) », CRS par défaut EPSG:2154, sortie
# application/json, CountDefault 5000).
.bdforet_wfs_url <- "https://data.geopf.fr/wfs/ows"
.bdforet_wfs_couche <- "LANDCOVER.FORESTINVENTORY.V2:formation_vegetale"
.bdforet_wfs_page <- 5000L

# Emprise de `modele` dans le système `crs` (rectangle densifié, reprojeté).
emprise_dans <- function(modele, crs) {
  r <- terra::as.polygons(terra::ext(modele), crs = terra::crs(modele))
  if (terra::same.crs(r, crs)) return(terra::ext(r))
  pas <- max(terra::res(modele)) * 10
  terra::ext(terra::project(terra::densify(r, pas), crs))
}

# Lit la BD Forêt sur l'emprise de `modele` ; rend list(v, source) avec `v`
# dans le système de `modele` (polygones seulement).
bdforet_lire <- function(bdforet, modele, couche = NULL) {
  wfs <- is.null(bdforet) ||
    (is.character(bdforet) && length(bdforet) == 1L && identical(tolower(bdforet), "wfs") &&
       !file.exists(bdforet))
  if (wfs) {
    e <- emprise_dans(modele, "EPSG:2154")
    v <- lire_bdforet_wfs(e)
    source <- paste0("service WFS de la G\u00e9oplateforme (", .bdforet_wfs_url, ", couche ",
                     .bdforet_wfs_couche, "), lu le ", format(Sys.Date()))
  } else if (is.character(bdforet) && length(bdforet) == 1L && !is.na(bdforet)) {
    if (!file.exists(bdforet)) {
      stop("Fichier BD For\u00eat introuvable : ", bdforet, call. = FALSE)
    }
    args <- list(bdforet)
    if (!is.null(couche)) args$layer <- couche
    proxy <- do.call(terra::vect, c(args, proxy = TRUE))
    if (!nzchar(terra::crs(proxy))) {
      stop("La BD For\u00eat (`bdforet`) doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
    }
    e <- emprise_dans(modele, terra::crs(proxy))
    v <- do.call(terra::vect, c(args, extent = e))
    source <- bdforet
  } else if (inherits(bdforet, "SpatVector")) {
    v <- bdforet
    source <- "SpatVector fourni"
  } else {
    stop("`bdforet` doit \u00eatre un chemin, un SpatVector, ou NULL (service WFS).", call. = FALSE)
  }
  if (nrow(v) > 0L) {
    if (terra::geomtype(v) != "polygons") {
      stop("La BD For\u00eat (`bdforet`) doit contenir des polygones.", call. = FALSE)
    }
    if (!nzchar(terra::crs(v))) {
      stop("La BD For\u00eat (`bdforet`) doit avoir un syst\u00e8me de coordonn\u00e9es.", call. = FALSE)
    }
    if (!terra::same.crs(v, modele)) {
      v <- terra::project(v, terra::crs(modele))
    }
  }
  list(v = v, source = source)
}

# URL GetFeature (GeoJSON, Lambert-93) d'une page du WFS sur l'emprise `e`
# (SpatExtent en EPSG:2154), triée par identifiant pour une pagination
# stable.
bdforet_wfs_url <- function(e, debut = 0L, nb = .bdforet_wfs_page,
                            url = .bdforet_wfs_url, couche = .bdforet_wfs_couche) {
  paste0(url, "?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature",
         "&TYPENAMES=", couche,
         "&OUTPUTFORMAT=application/json&SRSNAME=EPSG:2154",
         sprintf("&BBOX=%.2f,%.2f,%.2f,%.2f,urn:ogc:def:crs:EPSG::2154",
                 terra::xmin(e), terra::ymin(e), terra::xmax(e), terra::ymax(e)),
         "&COUNT=", as.integer(nb), "&STARTINDEX=", as.integer(debut), "&SORTBY=id")
}

# Lit toutes les pages du WFS sur l'emprise `e` (EPSG:2154). `lecteur`
# (défaut terra::vect) sert aux tests. Rend un SpatVector en EPSG:2154,
# éventuellement vide ; les doublons d'identifiant entre pages sont retirés.
lire_bdforet_wfs <- function(e, nb = .bdforet_wfs_page, lecteur = terra::vect,
                             max_pages = 1000L) {
  morceaux <- list()
  debut <- 0L
  for (k in seq_len(max_pages)) {
    u <- bdforet_wfs_url(e, debut, nb)
    page <- tryCatch(lecteur(u), error = function(err) {
      stop("Lecture du WFS BD For\u00eat impossible (", conditionMessage(err), ") : ", u,
           call. = FALSE)
    })
    n <- nrow(page)
    if (n > 0L) morceaux[[length(morceaux) + 1L]] <- page
    if (n < nb) break
    if (k == max_pages) {
      stop("WFS BD For\u00eat : plus de ", max_pages, " pages, emprise trop grande.", call. = FALSE)
    }
    debut <- debut + n
  }
  if (length(morceaux) == 0L) {
    return(terra::vect("POLYGON ((0 0, 1 0, 1 1, 0 0))", crs = "EPSG:2154")[0])
  }
  v <- do.call(rbind, morceaux)
  if ("id" %in% names(v)) v <- v[!duplicated(v$id)]
  v
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

valide_marge_2019 <- function(marge_2019) {
  if (!est_scalaire_num(marge_2019) || !is.finite(marge_2019) || marge_2019 < 0 ||
      marge_2019 != floor(marge_2019)) {
    stop("`marge_2019` doit \u00eatre un nombre entier de pixels, au moins \u00e9gal \u00e0 0.",
         call. = FALSE)
  }
  invisible(marge_2019)
}

# Correction 2019 (étape 4 de masque_foret()) : pixels détectés en 2019,
# élargis de `marge_2019` pixels, retirés de la forêt. Sans détections,
# `foret` est rendu tel quel.
corriger_2019 <- function(foret, detections_2019, grille, marge_2019 = 0L) {
  if (is.null(detections_2019)) return(foret)
  det <- detections_sur_grille(detections_2019, grille)
  if (marge_2019 > 0) {
    k <- 2L * as.integer(marge_2019) + 1L
    det <- terra::focal(det, w = matrix(1, k, k), fun = "max", na.rm = TRUE,
                        expand = FALSE, fillvalue = 0)
    det <- det > 0
  }
  foret & !det
}

# Nomme la couche `foret` et l'écrit si `fichier` n'est pas "".
sortie_foret <- function(foret, fichier) {
  names(foret) <- "foret"
  if (nzchar(fichier)) {
    foret <- terra::writeRaster(foret, fichier, overwrite = TRUE, datatype = "INT1U",
                                names = "foret")
    foret <- foret == 1
    names(foret) <- "foret"
  }
  foret
}

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
