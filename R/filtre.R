#' Filtre multitemporel de Quegan et Yu, à noyau calculé sur l'année de référence
#'
#' Réduit le speckle d'une série Sentinel-1 d'**une seule orbite relative**
#' par le filtre multitemporel de Quegan et Yu (2001), comme l'étape de
#' prétraitement de SUFOSAT : le noyau est calculé sur les images de l'année
#' `annee_noyau` (2018 par défaut), puis appliqué aux images (M24, § II-B.1,
#' p. 13746 ; fenêtre 3 x 3, aucun autre filtre de speckle).
#'
#' @section Formule : Pour chaque image `I_t` et chaque pixel, `E[I_t]` est la
#'   moyenne locale de `I_t` sur une fenêtre carrée de `fenetre_filtre` pixels
#'   de côté centrée sur le pixel. Avec `R` l'ensemble des `N` images de
#'   l'année `annee_noyau` valides au pixel :
#'
#'   * noyau : `K = (1 / N) * somme_{i dans R} I_i / E[I_i]` ;
#'   * image filtrée : `J_t = E[I_t] * K`.
#'
#'   C'est la forme simplifiée du filtre (corrélation entre images négligée) :
#'   Quegan et Yu (2001), IEEE TGRS 39(11), p. 2373-2379,
#'   doi:10.1109/36.964973 (article non lu ici, non accessible) ; formule
#'   relevée dans Meraoumia et al. (2022), arXiv:2207.11111v1, § 3.1, éq. (1) :
#'   `v_t = (v_t / T) * somme_k w_k / v_k`, `v_k` estimé par moyenne locale.
#'   Le calcul suit le code CNES des applications OTB
#'   `MultitempFilteringOutcore` (noyau, « outcore ») et
#'   `MultitempFilteringFilter` (dépôt `s1-tiling/s1tilingsupportapplications`,
#'   commit fa40f9b du 2020-09-23, fichiers `include/otbOutcoreFunctor.h`,
#'   `include/otbMeanFilterFunctor.h`,
#'   `include/otbMultiplyVectorImageFilterFunctor.h`) : l'outcore somme
#'   `I_i / E[I_i]` et compte les images valides, le filtre multiplie
#'   `E[I_t]` par cette somme divisée par ce compte.
#'
#' @section Images filtrées : M24 applique le noyau aux images acquises après
#'   le 1er janvier de `annee_noyau + 1`. Le sort des images de l'année de
#'   référence n'y est pas précisé ; l'ancienne chaîne S1Tiling
#'   (`deprecated/S1FilteringProcessor.py`, listes `year_outcore_list` et
#'   `year_filter_list` identiques) filtre aussi les images qui ont servi au
#'   noyau. Ici, **toutes les images de la série** reçoivent le même noyau,
#'   y compris celles de l'année de référence et des années antérieures.
#'   **Provisoire (non précisé dans M24 ; images antérieures : aucune
#'   source), gèle au jalon 2.** [rcr_compute()] ne calcule de toute façon
#'   aucun ratio avant le 1er janvier de `annee_noyau + 1`.
#'
#' @section Bords : Hors de l'image, la fenêtre reprend la valeur du pixel de
#'   bord le plus proche (bord répliqué), comme la condition
#'   `itk::ZeroFluxNeumannBoundaryCondition` des filtres de voisinage OTB
#'   utilisés par les deux applications. M24 ne dit pas quel logiciel est
#'   employé : **provisoire, gèle au jalon 2.**
#'
#' @section Images manquantes : Une valeur `NA` (ou `NaN`) est une image
#'   écartée pour ce pixel. Elle est ignorée dans les moyennes locales
#'   (OTB ignore de même les pixels nuls) ; un pixel `NA` reste `NA` après
#'   filtrage ; le noyau d'un pixel ne compte que les images de référence
#'   valides en ce pixel. Un pixel sans aucune image de référence valide n'a
#'   pas de noyau : il vaut `NA` à toutes les dates. Une valeur nulle ou
#'   négative est traitée comme `NA`, avec un seul avertissement qui en donne
#'   le nombre, comme dans [rcr_compute()]. Une valeur infinie est refusée.
#'
#' @section Calcul : Moyennes locales par sommes cumulées en deux dimensions,
#'   une image à la fois (pas de boucle sur les pixels) ; la moyenne locale
#'   d'une image de référence sert au noyau et à l'image filtrée (calculée
#'   une seule fois). Les sommes cumulées le long d'un axe court sont prises
#'   par sommes de lignes (`.rowSums()`), qui accumulent comme [cumsum()] :
#'   le résultat est identique au bit près (mission 016). La mémoire tient
#'   environ deux fois la taille de `serie`.
#'
#' @param serie Tableau numérique à trois dimensions (lignes x colonnes x
#'   dates) de rétrodiffusion **linéaire** (intensité, pas des dB) d'une
#'   seule orbite relative.
#' @param dates Vecteur de classe `Date`, strictement croissant, sans `NA`, de
#'   longueur `dim(serie)[3]`. Au moins une date doit tomber dans l'année
#'   `annee_noyau`.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seuls
#'   `fenetre_filtre` et `annee_noyau` servent ici.
#'
#' @return Un tableau de mêmes dimensions (et mêmes noms de dimensions) que
#'   `serie`, en valeurs linéaires filtrées. Il porte l'attribut
#'   `nb_images_noyau` : matrice d'entiers (lignes x colonnes) du nombre
#'   d'images de référence entrées dans le noyau de chaque pixel (le fichier
#'   « ENL » de l'application OTB).
#'
#' @seealso [rcr_compute()], [parametres_sufosat()].
#'
#' @examples
#' set.seed(1)
#' dates <- seq(as.Date("2018-01-04"), as.Date("2020-12-31"), by = 12)
#' nt <- length(dates)
#' # Champ homogène (0,05 en linéaire) avec un speckle gamma de 4 vues
#' serie <- array(0.05 * rgamma(20 * 20 * nt, shape = 4, rate = 4),
#'                dim = c(20, 20, nt))
#' filtree <- s1_filter_multitemp(serie, dates)
#' enl <- function(x) mean(x)^2 / stats::var(as.vector(x))
#' c(avant = enl(serie[, , nt]), apres = enl(filtree[, , nt]))
#'
#' \donttest{
#' # Tracé : un pixel avant et après filtre, en dB
#' plot(dates, lineaire_vers_db(serie[10, 10, ]), type = "l", col = "grey",
#'      xlab = "Date d'acquisition", ylab = "VH (dB)")
#' lines(dates, lineaire_vers_db(filtree[10, 10, ]), lwd = 2)
#' }
#'
#' @export
s1_filter_multitemp <- function(serie, dates, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  serie <- valide_serie(serie)
  d <- dim(serie)
  nt <- d[3]
  valide_dates_serie(dates, nt)
  cote <- p$fenetre_filtre

  negatif <- !is.na(serie) & serie <= 0
  if (any(negatif)) {
    warning(
      sum(negatif), " valeur(s) lin\u00e9aire(s) nulle(s) ou n\u00e9gative(s) ",
      "trait\u00e9e(s) comme images \u00e9cart\u00e9es (NA).",
      call. = FALSE
    )
    serie[negatif] <- NA_real_
  }
  rm(negatif)

  annees <- as.integer(format(dates, "%Y"))
  reference <- which(annees == p$annee_noyau)
  if (length(reference) == 0L) {
    stop(
      "Aucune image de `serie` n'est de l'ann\u00e9e `annee_noyau` (",
      p$annee_noyau, ") : le noyau du filtre ne peut pas \u00eatre calcul\u00e9.",
      call. = FALSE
    )
  }

  # Noyau (« outcore ») : moyenne des I_i / E[I_i] sur les images de référence,
  # sommés dans l'ordre des dates. E[I_i] est gardé dans `serie` pour l'image
  # filtrée (une seule moyenne locale par image).
  somme <- matrix(0, nrow = d[1], ncol = d[2])
  compte <- matrix(0L, nrow = d[1], ncol = d[2])
  for (t in reference) {
    image <- serie[, , t, drop = FALSE]
    dim(image) <- d[1:2]
    e <- moyenne_locale(image, cote)
    r <- image / e
    ok <- !is.na(r)
    somme[ok] <- somme[ok] + r[ok]
    compte[ok] <- compte[ok] + 1L
    serie[, , t] <- e
  }
  noyau <- somme / compte
  noyau[compte == 0L] <- NA_real_
  rm(somme, image, e, r, ok)

  # Images filtrées : J_t = E[I_t] * noyau.
  est_reference <- seq_len(nt) %in% reference
  for (t in seq_len(nt)) {
    if (est_reference[t]) {
      serie[, , t] <- serie[, , t] * noyau
    } else {
      image <- serie[, , t, drop = FALSE]
      dim(image) <- d[1:2]
      serie[, , t] <- moyenne_locale(image, cote) * noyau
    }
  }
  dimnames(compte) <- dimnames(serie)[1:2]
  attr(serie, "nb_images_noyau") <- compte
  serie
}

# Moyenne locale d'une image sur une fenêtre carrée de `cote` pixels (impair),
# NA ignorés, bord répliqué (comme itk::ZeroFluxNeumannBoundaryCondition).
# `image` est une matrice. Rend NA là où le pixel central est NA, comme le
# MeanFilterFunctor d'OTB.
moyenne_locale <- function(image, cote) {
  nr <- nrow(image)
  nc <- ncol(image)
  r <- (cote - 1L) %/% 2L
  lignes <- c(rep(1L, r), seq_len(nr), rep(nr, r))
  colonnes <- c(rep(1L, r), seq_len(nc), rep(nc, r))
  etendue <- image[lignes, colonnes, drop = FALSE]
  if (!anyNA(etendue)) {
    # Fenêtre pleine partout : le compte vaut cote * cote (entier exact).
    return(somme_fenetre(etendue, cote, nr, nc) / (cote * cote))
  }
  valide <- !is.na(etendue)
  etendue[!valide] <- 0
  somme <- somme_fenetre(etendue, cote, nr, nc)
  nombre <- compte_fenetre(valide, cote, nr, nc)
  moyenne <- somme / nombre
  moyenne[nombre == 0L | is.na(image)] <- NA_real_
  moyenne
}

# Somme sur chaque fenêtre cote x cote d'une matrice étendue, par sommes
# cumulées en deux dimensions (table de sommes de zone) : cumul le long des
# colonnes, puis le long des lignes, chaque cumul accumulé comme cumsum().
somme_fenetre <- function(m, cote, nr, nc) {
  cumul <- matrix(0, nrow = nrow(m) + 1L, ncol = ncol(m) + 1L)
  cumul[-1L, -1L] <- cumul_lignes(cumul_colonnes(m))
  i <- seq_len(nr)
  j <- seq_len(nc)
  cumul[i + cote, j + cote, drop = FALSE] - cumul[i, j + cote, drop = FALSE] -
    cumul[i + cote, j, drop = FALSE] + cumul[i, j, drop = FALSE]
}

# Nombre de valeurs `TRUE` de chaque fenêtre cote x cote d'une matrice logique
# étendue, en entiers (exact : l'ordre des additions est indifférent).
compte_fenetre <- function(valide, cote, nr, nc) {
  v <- valide
  storage.mode(v) <- "integer"
  vertical <- v[seq_len(nr), , drop = FALSE]
  for (a in seq_len(cote - 1L)) vertical <- vertical + v[a + seq_len(nr), , drop = FALSE]
  n <- vertical[, seq_len(nc), drop = FALSE]
  for (b in seq_len(cote - 1L)) n <- n + vertical[, b + seq_len(nc), drop = FALSE]
  n
}

# Somme cumulée le long de chaque colonne (premier axe), par cumsum().
cumul_colonnes <- function(m) {
  for (j in seq_len(ncol(m))) m[, j] <- cumsum(m[, j])
  m
}

# Somme cumulée le long de chaque ligne (second axe). cumsum() et .rowSums()
# accumulent tous deux en partant de 0, valeur après valeur, dans un
# accumulateur long double (code C de R) : la colonne j de la somme cumulée
# est exactement .rowSums() des j premières colonnes, lues sans copie. Cette
# forme triangulaire (j colonnes relues pour la colonne j) est plus rapide que
# n cumsum() courts tant que les lignes sont courtes (bandes de quelques
# lignes du raster) ; au-delà de `cumul_lignes_max` colonnes, on transpose.
cumul_lignes <- function(m) {
  n1 <- nrow(m)
  n2 <- ncol(m)
  if (n2 > cumul_lignes_max) return(t(cumul_colonnes(t(m))))
  sortie <- m
  for (j in seq_len(n2)) sortie[, j] <- .rowSums(m, n1, j)
  sortie
}
cumul_lignes_max <- 48L
