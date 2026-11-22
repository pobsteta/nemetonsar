#' Ratio de changement radar (RCR) minimal et sa date, pour une orbite
#'
#' Calcule, pour chaque pixel d'une série Sentinel-1 d'**une seule orbite
#' relative**, le ratio de changement radar à chaque date, puis garde le ratio
#' le plus bas et sa date. Définition (M24, § II-D.1, p. 13747 ; B18, § 2.3.2,
#' p. 10, éq. 1) : à la date d'acquisition `d_i`,
#'
#' * `Mb` = moyenne de la rétrodiffusion sur les `xb` images **jusqu'à `d_i`
#'   incluse** (toutes les images depuis le début si `xb = Inf`) ;
#' * `Ma` = moyenne sur les `xa` images **à partir de `d_(i+1)` incluse** ;
#' * `RCR_i = 10 * log10(Ma / Mb)`, en dB.
#'
#' Les moyennes portent sur les valeurs **linéaires** et le rapport est
#' exprimé en dB (voir [seuils_db()] et [lineaire_vers_db()]) : ni M24 ni B18
#' ne l'écrivent explicitement. **Provisoire, gèle au jalon 2.**
#'
#' @section Images manquantes : Une valeur `NA` (ou `NaN`) est une image
#'   écartée pour ce pixel (neige, hors fauchée...). Les moyennes ne
#'   comptent que les images valides : `Ma` prend les `xa` premières images
#'   valides après `d_i`, `Mb` les `xb` dernières images valides jusqu'à
#'   `d_i`. Un ratio n'est calculé qu'aux dates où le pixel est valide et
#'   suivi d'au moins `xa` images valides ; sinon le pixel n'a pas de ratio à
#'   cette date. Une valeur nulle ou négative n'a pas de sens en intensité :
#'   elle est traitée comme une image écartée (`NA`), avec un seul
#'   avertissement qui en donne le nombre, comme [lineaire_vers_db()]. Une
#'   valeur infinie est refusée.
#'
#' @section Date retenue : La coupe a lieu entre `d_i` (dernière image avant
#'   la chute) et `d_(i+1)` (première image après) : B18, § 2.3.2, p. 11,
#'   intervalle `[d_k, d_(k+1)]`. M24 retient « la date correspondant au RCR
#'   le plus bas » sans dire laquelle des deux. `date_min` est la **première
#'   image valide après la chute**, `d_(i+1)` ; `date_avant` donne `d_i`.
#'   **Provisoire (non précisé dans M24), gèle au jalon 2** : à confronter aux
#'   dates de la carte SUFOSAT v3.0.1. En cas d'égalité de ratios, la date la
#'   plus ancienne l'emporte (choix du package, non sourcé).
#'
#' @section Xa en jours : `xa` compte des images. Sa durée réelle se lit sur
#'   les dates d'acquisition et non sur une cadence supposée :
#'   `duree_xa_jours` donne, pour le minimum retenu, le nombre de jours entre
#'   `d_i` et la dernière image de la fenêtre `Ma`. Sur une cadence régulière
#'   sans image manquante, il vaut [xa_en_jours()].
#'
#' @section Mémoire : Le calcul est vectorisé sur les pixels, avec une boucle
#'   sur les dates. Il garde en mémoire environ trois fois la taille de
#'   `serie` (sommes cumulées et positions des images valides).
#'
#' @param serie Tableau numérique à trois dimensions (lignes x colonnes x
#'   dates) de rétrodiffusion **linéaire** (intensité, pas des dB) d'une
#'   seule orbite relative.
#' @param dates Vecteur de classe `Date`, strictement croissant, sans `NA`, de
#'   longueur `dim(serie)[3]` : la date d'acquisition de chaque image.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seuls `xa` et
#'   `xb` servent ici.
#'
#' @return Une liste :
#'   * `ratio_min_db` : matrice (lignes x colonnes) du ratio minimal, en dB ;
#'     `NA` si le pixel n'a aucun ratio ;
#'   * `date_min` : matrice d'entiers `YYDDD` (voir [date_vers_yyddd()]) de
#'     la première image valide après la chute ;
#'   * `date_avant` : matrice d'entiers `YYDDD` de la dernière image valide
#'     avant la chute ;
#'   * `duree_xa_jours` : matrice d'entiers, durée en jours de `d_i` à la
#'     dernière image de la fenêtre `Ma` ;
#'   * `parametres` : l'objet `parametres` validé.
#'
#'   Les matrices gardent les noms des deux premières dimensions de `serie`.
#'
#' @seealso [rcr_combine_orbites()], [seuils_db()], [yyddd_vers_date()].
#'
#' @examples
#' dates <- seq(as.Date("2021-01-05"), by = 12, length.out = 10)
#' serie <- array(0.05, dim = c(2, 2, 10))
#' serie[1, 1, 6:10] <- 0.05 * db_vers_lineaire(-6) # chute de 6 dB
#' r <- rcr_compute(serie, dates)
#' r$ratio_min_db
#' yyddd_vers_date(r$date_min[1, 1]) # dates[6]
#'
#' @export
rcr_compute <- function(serie, dates, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  serie <- valide_serie(serie)
  d <- dim(serie)
  nt <- d[3]
  codes <- valide_dates_serie(dates, nt)
  npix <- d[1] * d[2]
  xa <- p$xa
  xb <- p$xb

  x <- matrix(serie, nrow = npix, ncol = nt)
  noms <- dimnames(serie)[1:2]
  rm(serie)
  negatif <- !is.na(x) & x <= 0
  if (any(negatif)) {
    warning(
      sum(negatif), " valeur(s) linéaire(s) nulle(s) ou négative(s) ",
      "traitée(s) comme images écartées (NA).",
      call. = FALSE
    )
    x[negatif] <- NA_real_
  }
  rm(negatif)

  # Passe 1 : pour chaque pixel, somme cumulée des k premières images valides
  # (colonne k + 1 de `cumul`) et position (index de date) de la k-ième.
  cumul <- matrix(0, nrow = npix, ncol = nt + 1L)
  position <- matrix(NA_integer_, nrow = npix, ncol = nt + 1L)
  somme <- numeric(npix)
  compte <- integer(npix)
  for (t in seq_len(nt)) {
    v <- which(!is.na(x[, t]))
    if (length(v) == 0L) next
    somme[v] <- somme[v] + x[v, t]
    compte[v] <- compte[v] + 1L
    cle <- cbind(v, compte[v] + 1L)
    cumul[cle] <- somme[v]
    position[cle] <- t
  }
  total <- compte
  rm(somme)

  lire <- function(m, pix, k) m[cbind(pix, k + 1L)]

  # Passe 2 : ratio à chaque date valide suivie d'au moins xa images valides.
  meilleur <- rep(Inf, npix)
  k_avant <- rep(NA_integer_, npix)
  compte <- integer(npix)
  for (i in seq_len(nt)) {
    v <- !is.na(x[, i])
    compte[v] <- compte[v] + 1L
    pix <- which(v & compte + xa <= total)
    if (length(pix) == 0L) next
    k <- compte[pix]
    nb <- if (is.infinite(xb)) k else pmin(k, as.integer(xb))
    mb <- (lire(cumul, pix, k) - lire(cumul, pix, k - nb)) / nb
    ma <- (lire(cumul, pix, k + xa) - lire(cumul, pix, k)) / xa
    r <- lineaire_vers_db(ma / mb)
    mieux <- r < meilleur[pix]
    meilleur[pix[mieux]] <- r[mieux]
    k_avant[pix[mieux]] <- k[mieux]
  }

  trouve <- which(!is.na(k_avant))
  ratio <- rep(NA_real_, npix)
  date_min <- rep(NA_integer_, npix)
  date_avant <- rep(NA_integer_, npix)
  duree <- rep(NA_integer_, npix)
  if (length(trouve) > 0L) {
    k <- k_avant[trouve]
    i_avant <- lire(position, trouve, k)
    i_apres <- lire(position, trouve, k + 1L)
    i_fin <- lire(position, trouve, k + xa)
    ratio[trouve] <- meilleur[trouve]
    date_avant[trouve] <- codes[i_avant]
    date_min[trouve] <- codes[i_apres]
    duree[trouve] <- as.integer(dates[i_fin] - dates[i_avant])
  }

  en_matrice <- function(v) {
    m <- matrix(v, nrow = d[1], ncol = d[2])
    if (!is.null(noms)) dimnames(m) <- noms
    m
  }
  list(
    ratio_min_db = en_matrice(ratio),
    date_min = en_matrice(date_min),
    date_avant = en_matrice(date_avant),
    duree_xa_jours = en_matrice(duree),
    parametres = p
  )
}

#' Combiner les ratios minimaux de plusieurs orbites
#'
#' Applique la règle `combinaison_orbites` de [parametres_sufosat()] aux
#' résultats de [rcr_compute()] obtenus sur plusieurs orbites relatives (par
#' exemple une ascendante et une descendante) d'une même grille. Avec
#' `"minimum"`, seule règle permise : par pixel, l'orbite au ratio le plus bas
#' donne le ratio et ses dates ; une orbite sans ratio pour ce pixel (`NA`)
#' est ignorée. Règle **provisoire, gèle au jalon 2** : non précisée dans M24
#' (p. 13748, « mosaicked »), formule ambiguë dans B18 (§ 2.3.2, p. 11). En
#' cas d'égalité, la première orbite de la liste l'emporte (choix du
#' package, non sourcé).
#'
#' @param resultats Liste (nommée ou non) d'au moins un résultat de
#'   [rcr_compute()], tous de mêmes dimensions et calculés avec `parametres`.
#' @param parametres Un objet créé par [parametres_sufosat()].
#'
#' @return Une liste de même forme que celle de [rcr_compute()], plus
#'   `orbite` : matrice donnant, par pixel, le nom de l'orbite retenue (ou son
#'   rang dans `resultats` si la liste n'est pas nommée), `NA` sans ratio.
#'
#' @examples
#' dates <- seq(as.Date("2021-01-05"), by = 12, length.out = 10)
#' asc <- array(0.05, dim = c(1, 2, 10))
#' desc <- asc
#' asc[1, 1, 6:10] <- 0.05 * db_vers_lineaire(-4)
#' desc[1, 1, 7:10] <- 0.05 * db_vers_lineaire(-6)
#' p <- parametres_sufosat()
#' comb <- rcr_combine_orbites(
#'   list(asc = rcr_compute(asc, dates, p), desc = rcr_compute(desc, dates + 3, p)),
#'   p
#' )
#' comb$orbite
#'
#' @export
rcr_combine_orbites <- function(resultats, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  champs <- c("ratio_min_db", "date_min", "date_avant", "duree_xa_jours", "parametres")
  if (!is.list(resultats) || inherits(resultats, "parametres_sufosat") ||
      length(resultats) < 1L) {
    stop("`resultats` doit être une liste d'au moins un résultat de rcr_compute().", call. = FALSE)
  }
  for (j in seq_along(resultats)) {
    r <- resultats[[j]]
    if (!is.list(r) || !all(champs %in% names(r))) {
      stop("L'élément ", j, " de `resultats` n'est pas un résultat de rcr_compute().", call. = FALSE)
    }
    if (!isTRUE(all.equal(valide_parametres(r$parametres), p))) {
      stop(
        "L'élément ", j, " de `resultats` a été calculé avec d'autres ",
        "réglages que `parametres`.",
        call. = FALSE
      )
    }
    if (!identical(dim(r$ratio_min_db), dim(resultats[[1]]$ratio_min_db))) {
      stop("Tous les résultats doivent avoir les mêmes dimensions.", call. = FALSE)
    }
  }

  etiquettes <- names(resultats)
  if (is.null(etiquettes) || any(is.na(etiquettes) | !nzchar(etiquettes))) {
    etiquettes <- seq_along(resultats)
  }

  combine <- switch(p$combinaison_orbites,
    minimum = function() {
      sortie <- resultats[[1]][champs]
      orbite <- ifelse(is.na(sortie$ratio_min_db), NA, etiquettes[1])
      orbite <- array(orbite, dim = dim(sortie$ratio_min_db),
                      dimnames = dimnames(sortie$ratio_min_db))
      for (j in seq_along(resultats)[-1L]) {
        r <- resultats[[j]]
        mieux <- !is.na(r$ratio_min_db) &
          (is.na(sortie$ratio_min_db) | r$ratio_min_db < sortie$ratio_min_db)
        for (champ in champs[1:4]) {
          sortie[[champ]][mieux] <- r[[champ]][mieux]
        }
        orbite[mieux] <- etiquettes[j]
      }
      sortie$parametres <- p
      sortie$orbite <- orbite
      sortie
    }
  )
  combine()
}

# Validation ----------------------------------------------------------------

valide_serie <- function(serie) {
  if (!is.numeric(serie) && !(is.logical(serie) && all(is.na(serie)))) {
    stop("`serie` doit être un tableau numérique.", call. = FALSE)
  }
  d <- dim(serie)
  if (length(d) != 3L) {
    stop("`serie` doit être un tableau à trois dimensions (lignes x colonnes x dates).", call. = FALSE)
  }
  if (any(d == 0L)) {
    stop("`serie` ne doit avoir aucune dimension vide.", call. = FALSE)
  }
  if (any(is.infinite(serie))) {
    stop("`serie` ne doit pas contenir de valeur infinie.", call. = FALSE)
  }
  storage.mode(serie) <- "double"
  serie
}

valide_dates_serie <- function(dates, nt) {
  if (!inherits(dates, "Date")) {
    stop("`dates` doit être de classe Date.", call. = FALSE)
  }
  if (length(dates) != nt) {
    stop(
      "`dates` doit avoir autant d'éléments que la troisième dimension de `serie` (",
      nt, "), et non ", length(dates), ".",
      call. = FALSE
    )
  }
  if (anyNA(dates)) {
    stop("`dates` ne doit pas contenir de NA.", call. = FALSE)
  }
  if (is.unsorted(dates, strictly = TRUE)) {
    stop("`dates` doit être strictement croissant (une image par date).", call. = FALSE)
  }
  date_vers_yyddd(dates)
}
