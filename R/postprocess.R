#' Post-traitement : surface minimale, fermeture et table des objets
#'
#' Nettoie la détection rendue par [rcr_segment()] selon M24, § II-D.1,
#' p. 13748 : les détections de **moins de** `surface_min_ha` (0,1 ha) sont
#' écartées, **puis** une fermeture morphologique « lisse légèrement » les
#' zones détectées. Les objets sont ensuite réétiquetés et, si `rcr` est
#' fourni, décrits dans une table.
#'
#' 1. **Surface minimale.** Les objets sont les composantes connexes des
#'    pixels détectés, avec le voisinage `parametres$connexite` (4 ou 8 ;
#'    **provisoire**, voir [parametres_sufosat()]). La surface d'un objet est
#'    son nombre de pixels fois `resolution_m^2` m². Un objet est retiré si
#'    sa surface est **strictement inférieure** à `surface_min_ha` : M24 écrit
#'    « lower than 0.1 ha » et parle de 0,1 ha comme unité minimale de
#'    cartographie (p. 13747), donc un objet de 0,1 ha exactement est gardé.
#'    À 10 m, un objet de 9 pixels (0,09 ha) est retiré, un objet de 10
#'    pixels (0,1 ha) est gardé. (B18, § 2.3.3, p. 12, garde les segments de
#'    « plus de 10 pixels » : il écarterait donc un objet de 10 pixels ; on
#'    suit M24.) La comparaison se fait en m², avec une
#'    tolérance relative de `1e-9` pour l'arithmétique flottante.
#' 2. **Fermeture** (si `parametres$fermeture`) : dilatation puis érosion par
#'    un **carré** de côté `taille_fermeture` pixels, centré. M24 ne précise
#'    ni la forme ni la taille de l'élément structurant : **carré de 3 pixels,
#'    provisoire, gèle au jalon 2.** La fermeture comble les trous et les
#'    échancrures plus étroits que le carré ; avec un carré de côté `k`, deux
#'    objets séparés par au moins `k` pixels vides ne sont pas reliés.
#' 3. **Réétiquetage** des objets de la détection finale (même voisinage),
#'    de 1 au nombre d'objets, dans l'ordre du premier pixel en parcourant la
#'    matrice colonne par colonne, comme [rcr_segment()].
#'
#' La fermeture n'agrandit et ne fusionne que des objets : elle ne crée pas
#' d'objet sous la surface minimale, d'où l'ordre « surface puis fermeture »
#' sans second tamisage.
#'
#' @section Bords et pixels sans donnée : **Convention provisoire, non
#'   sourcée (choix du package), gèle au jalon 2.** L'image est traitée comme
#'   une fenêtre sur un plan **vide** à l'infini : la fermeture est calculée
#'   sur l'image bordée de pixels non détectés, puis recadrée. Elle ne retire
#'   donc aucun pixel détecté, même au bord, et ne relie pas un objet au bord
#'   de l'image (contrairement à une érosion qui tiendrait l'extérieur pour
#'   détecté). Un pixel est **sans donnée** s'il vaut `NA` dans la matrice
#'   `segmentation`, ou, quand `rcr` est fourni, si son `ratio_min_db` est
#'   `NA` : il compte comme non détecté pour la surface et la fermeture, et
#'   n'est **jamais rendu détecté**, même dans un trou comblé. Le résultat de
#'   [rcr_segment()] ne contient pas de `NA` : fournir `rcr` pour protéger
#'   les pixels sans ratio.
#'
#' @section Table des objets : Une ligne par objet de la détection finale.
#'   `nb_pixels` et `surface_ha` comptent tous ses pixels, **pixels comblés
#'   par la fermeture compris**. `nb_pixels_dates`, `date_mediane` et
#'   `ratio_moyen_db` se calculent sur les **seuls pixels de l'objet qui
#'   étaient détectés avant la fermeture** (après le retrait des petits
#'   objets) : un pixel comblé n'a pas franchi les seuils, son ratio et sa
#'   date ne décrivent pas la coupe. **Provisoire, non sourcé (décision de
#'   l'orchestrateur du 2026-11-22), gèle au jalon 2.**
#'   * `identifiant` : numéro de l'objet dans `objet` ;
#'   * `nb_pixels`, `surface_ha` (`nb_pixels * resolution_m^2 / 10000`) ;
#'   * `nb_pixels_dates` : nombre de pixels de l'objet, détectés avant la
#'     fermeture, qui ont une date (`date_min` non `NA`) ;
#'   * `date_mediane` : médiane des dates `date_min` de ces pixels, en entier
#'     `YYDDD` (voir [date_vers_yyddd()]), et `date_mediane_date`, la même en
#'     `Date`. Pour un nombre pair de dates, c'est la **médiane basse** (la
#'     plus ancienne des deux dates du milieu), pour que la date rendue soit
#'     une date d'acquisition réelle et non un jour intermédiaire.
#'     **Provisoire, non sourcé (choix du package), gèle au jalon 2.**
#'   * `ratio_moyen_db` : ratio moyen de l'objet, en dB, calculé comme
#'     `10 * log10` de la moyenne des ratios **linéaires** de ses pixels,
#'     détectés avant la fermeture, qui ont un ratio, comme le ratio lui-même est un rapport de moyennes
#'     linéaires (voir [seuils_db()]). **Provisoire, non sourcé, gèle au
#'     jalon 2.**
#'
#'   Sans `rcr`, les colonnes `nb_pixels_dates`, `date_mediane`,
#'   `date_mediane_date` et `ratio_moyen_db` valent `NA`.
#'
#' @param segmentation Le résultat (une liste) de [rcr_segment()], dont
#'   l'élément `detection` est pris, ou directement une matrice logique
#'   (`TRUE` = détecté ; `NA` = sans donnée).
#' @param rcr `NULL`, ou le résultat de [rcr_compute()] ou de
#'   [rcr_combine_orbites()] sur la même grille (éléments `ratio_min_db` et
#'   `date_min`), pour remplir la table des objets.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seuls
#'   `connexite`, `surface_min_ha`, `fermeture` et `taille_fermeture` servent
#'   ici.
#' @param resolution_m Côté d'un pixel, en mètres (nombre strictement
#'   positif). Défaut 10 : M24, Table I, p. 13744.
#'
#' @return Une liste :
#'   * `detection` : matrice logique de la détection finale ;
#'   * `objet` : matrice d'entiers, identifiant de l'objet, `NA` hors
#'     détection ;
#'   * `table` : `data.frame` des objets (voir la section « Table des
#'     objets »), zéro ligne s'il n'y a aucun objet ;
#'   * `parametres` : l'objet `parametres` validé ;
#'   * `resolution_m` : la résolution utilisée.
#'
#'   Les matrices ont les dimensions et les noms de dimensions de la
#'   détection d'entrée.
#'
#' @seealso [rcr_segment()], [rcr_compute()], [parametres_sufosat()].
#'
#' @examples
#' # Détection synthétique (pixels de 10 m)
#' det <- matrix(FALSE, nrow = 14, ncol = 14)
#' det[2:6, 2:6] <- TRUE   # 25 pixels (0,25 ha) ...
#' det[4, 4] <- FALSE      # ... avec un trou d'un pixel
#' det[10:12, 2:4] <- TRUE # 9 pixels (0,09 ha) : retiré
#' det[9:10, 9:13] <- TRUE # 10 pixels (0,1 ha) : gardé
#' pp <- postprocess(det)
#' pp$table
#' pp$detection[4, 4] # trou comblé par la fermeture
#'
#' # Avec le ratio et les dates : chaîne complète sur un cas synthétique
#' dates <- seq(as.Date("2021-01-05"), by = 12, length.out = 10)
#' serie <- array(0.05, dim = c(14, 14, 10))
#' for (t in 6:10) serie[, , t][det] <- 0.05 * db_vers_lineaire(-7)
#' r <- rcr_compute(serie, dates)
#' s <- rcr_segment(r)
#' pp2 <- postprocess(s, rcr = r)
#' pp2$table
#'
#' \donttest{
#' # Avant / après le post-traitement
#' op <- par(mfrow = c(1, 2))
#' image(t(det[nrow(det):1, ]), main = "Avant", axes = FALSE)
#' image(t(pp$detection[nrow(det):1, ]), main = "Après", axes = FALSE)
#' par(op)
#' }
#'
#' @export
postprocess <- function(segmentation, rcr = NULL,
                        parametres = parametres_sufosat(),
                        resolution_m = 10) {
  p <- valide_parametres(parametres)
  if (!est_scalaire_num(resolution_m) || !is.finite(resolution_m) || resolution_m <= 0) {
    stop("`resolution_m` doit \u00eatre un nombre strictement positif (en m\u00e8tres).", call. = FALSE)
  }
  entree <- valide_segmentation(segmentation)
  sans_donnee <- is.na(entree)
  ratio <- NULL
  date_min <- NULL
  if (!is.null(rcr)) {
    v <- valide_rcr_post(rcr, dim(entree))
    ratio <- v$ratio_min_db
    date_min <- v$date_min
    sans_donnee <- sans_donnee | is.na(ratio)
  }
  detection <- !sans_donnee & !is.na(entree) & entree

  # 1. Retrait des objets sous la surface minimale (comparaison en m²).
  surface_pixel_m2 <- resolution_m^2
  seuil_m2 <- p$surface_min_ha * 1e4
  racine <- etiquette_composantes(detection, p$connexite)
  if (any(detection)) {
    taille <- tabulate(racine[detection], nbins = length(detection))
    petit <- taille * surface_pixel_m2 < seuil_m2 * (1 - 1e-9)
    detection <- detection & !petit[racine]
  }

  avant_fermeture <- detection

  # 2. Fermeture morphologique (carré de côté taille_fermeture).
  if (p$fermeture && p$taille_fermeture > 1L) {
    detection <- fermeture_carre(detection, sans_donnee, p$taille_fermeture)
  }

  # 3. Réétiquetage : identifiants 1..K dans l'ordre du premier pixel.
  racine <- etiquette_composantes(detection, p$connexite)
  n <- length(detection)
  objet <- rep(NA_integer_, n)
  racines <- sort(unique(racine[detection]))
  objet[detection] <- match(racine[detection], racines)

  forme <- function(x) {
    m <- matrix(x, nrow = nrow(entree), ncol = ncol(entree))
    dimnames(m) <- dimnames(entree)
    m
  }
  list(
    detection = forme(detection),
    objet = forme(objet),
    table = table_objets(objet, avant_fermeture, length(racines), surface_pixel_m2,
                         ratio, date_min),
    parametres = p,
    resolution_m = resolution_m
  )
}

# Table des objets (voir la section « Table des objets » de postprocess()).
table_objets <- function(objet, avant, k, surface_pixel_m2, ratio, date_min) {
  id <- seq_len(k)
  nb <- tabulate(objet[!is.na(objet)], nbins = k)
  nb_dates <- rep(NA_integer_, k)
  mediane <- rep(NA_integer_, k)
  ratio_moyen <- rep(NA_real_, k)
  if (!is.null(ratio) && k > 0L) {
    # Date et ratio : seuls les pixels détectés avant la fermeture.
    dans <- !is.na(objet) & avant
    o <- objet[dans]
    d <- as.integer(date_min[dans])
    a_date <- !is.na(d)
    nb_dates <- tabulate(o[a_date], nbins = k)
    # Médiane basse des dates, par objet : jours depuis l'origine, triés.
    jours <- as.numeric(yyddd_vers_date(d[a_date]))
    par_objet <- split(jours, factor(o[a_date], levels = id))
    med <- vapply(par_objet, function(j) {
      if (length(j) == 0L) return(NA_real_)
      sort(j)[(length(j) + 1L) %/% 2L]
    }, numeric(1))
    a_med <- !is.na(med)
    mediane[a_med] <- date_vers_yyddd(as.Date(med[a_med], origin = "1970-01-01"))
    # Moyenne des ratios linéaires, rendue en dB.
    r <- ratio[dans]
    a_ratio <- !is.na(r)
    somme <- vapply(split(db_vers_lineaire(r[a_ratio]), factor(o[a_ratio], levels = id)),
                    function(x) if (length(x)) mean(x) else NA_real_, numeric(1))
    ratio_moyen <- unname(10 * log10(somme))
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

# Fermeture d'une matrice logique par un carré de côté k (impair) :
# dilatation puis érosion, chacune séparable (lignes puis colonnes), sur
# l'image bordée de r = (k - 1) / 2 pixels FALSE (plan vide à l'infini :
# l'érosion d'un pixel de l'image ne lit que la dilatation à distance <= r),
# puis recadrée. Les pixels `neutre` (sans donnée) comptent comme FALSE et
# sont rendus FALSE.
fermeture_carre <- function(x, neutre, k) {
  r <- (k - 1L) %/% 2L
  nr <- nrow(x)
  nc <- ncol(x)
  pad <- matrix(FALSE, nr + 2L * r, nc + 2L * r)
  dedans_l <- r + seq_len(nr)
  dedans_c <- r + seq_len(nc)
  pad[dedans_l, dedans_c] <- x & !neutre
  ferme <- filtre_carre(filtre_carre(pad, r, any_ = TRUE), r, any_ = FALSE)
  ferme[dedans_l, dedans_c, drop = FALSE] & !neutre
}

# Maximum (any_ = TRUE) ou minimum (any_ = FALSE) d'une matrice logique sur
# un carré de demi-côté r ; hors de l'image, la valeur de bord est l'élément
# neutre (FALSE pour le maximum, TRUE pour le minimum).
filtre_carre <- function(x, r, any_) {
  nr <- nrow(x)
  nc <- ncol(x)
  bord <- !any_
  op <- if (any_) `|` else `&`
  # Le long des lignes (décalage vertical)
  pad <- rbind(matrix(bord, r, nc), x, matrix(bord, r, nc))
  y <- x
  for (s in seq_len(2L * r + 1L)) {
    y <- op(y, pad[s:(s + nr - 1L), , drop = FALSE])
  }
  # Le long des colonnes (décalage horizontal)
  pad <- cbind(matrix(bord, nr, r), y, matrix(bord, nr, r))
  z <- y
  for (s in seq_len(2L * r + 1L)) {
    z <- op(z, pad[, s:(s + nc - 1L), drop = FALSE])
  }
  dimnames(z) <- NULL
  z
}

# Vérifie l'entrée `segmentation` de postprocess() et rend la matrice
# logique (avec ses NA éventuels).
valide_segmentation <- function(x) {
  if (is.list(x) && !is.data.frame(x)) {
    if (!"detection" %in% names(x)) {
      stop(
        "`segmentation` doit \u00eatre une matrice logique ou un r\u00e9sultat de rcr_segment().",
        call. = FALSE
      )
    }
    x <- x$detection
  }
  if (!is.matrix(x) || !is.logical(x)) {
    stop("`segmentation` doit \u00eatre une matrice logique (TRUE = d\u00e9tect\u00e9).", call. = FALSE)
  }
  x
}

# Vérifie l'entrée `rcr` de postprocess() : liste avec `ratio_min_db` et
# `date_min`, de mêmes dimensions que la détection.
valide_rcr_post <- function(rcr, d) {
  if (!is.list(rcr) || !all(c("ratio_min_db", "date_min") %in% names(rcr))) {
    stop(
      "`rcr` doit \u00eatre NULL ou un r\u00e9sultat de rcr_compute() ou rcr_combine_orbites().",
      call. = FALSE
    )
  }
  ratio <- rcr$ratio_min_db
  date_min <- rcr$date_min
  if (is.logical(ratio) && all(is.na(ratio))) storage.mode(ratio) <- "double"
  if (is.logical(date_min) && all(is.na(date_min))) storage.mode(date_min) <- "integer"
  if (!is.matrix(ratio) || !is.numeric(ratio) || !is.matrix(date_min) || !is.numeric(date_min)) {
    stop("`rcr$ratio_min_db` et `rcr$date_min` doivent \u00eatre des matrices num\u00e9riques.", call. = FALSE)
  }
  if (!identical(dim(ratio), d) || !identical(dim(date_min), d)) {
    stop("`rcr` doit avoir les m\u00eames dimensions que `segmentation`.", call. = FALSE)
  }
  if (any(is.infinite(ratio))) {
    stop("`rcr$ratio_min_db` ne doit pas contenir de valeur infinie.", call. = FALSE)
  }
  list(ratio_min_db = ratio, date_min = date_min)
}
