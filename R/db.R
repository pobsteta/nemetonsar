#' Passer de la rétrodiffusion linéaire aux décibels, et retour
#'
#' La rétrodiffusion Sentinel-1 est une intensité (puissance) : en décibels,
#' elle vaut `10 * log10(x)`. Le ratio de changement radar se calcule sur les
#' moyennes linéaires, puis s'exprime en dB pour être comparé aux seuils (voir
#' [seuils_db()]).
#'
#' Les valeurs manquantes sont conservées. Une valeur linéaire nulle ou
#' négative n'a pas de logarithme : elle devient `NA`, avec un seul
#' avertissement qui en donne le nombre. En sens inverse, `-Inf` dB donne 0.
#' Les attributs de l'entrée (dimensions d'une matrice, par exemple) sont
#' conservés.
#'
#' @param x Vecteur, matrice ou tableau numérique.
#'
#' @return Un objet numérique (double) de même forme que `x`.
#'
#' @examples
#' lineaire_vers_db(c(1, 10, 0.01))
#' db_vers_lineaire(c(0, 10, -20))
#' db_vers_lineaire(lineaire_vers_db(0.25))
#'
#' @name conversions_db
NULL

#' @rdname conversions_db
#' @export
lineaire_vers_db <- function(x) {
  x <- valide_numerique(x)
  negatif <- !is.na(x) & x <= 0
  if (any(negatif)) {
    warning(
      sum(negatif), " valeur(s) lin\u00e9aire(s) nulle(s) ou n\u00e9gative(s) ",
      "remplac\u00e9e(s) par NA.",
      call. = FALSE
    )
    x[negatif] <- NA_real_
  }
  10 * log10(x)
}

#' @rdname conversions_db
#' @export
db_vers_lineaire <- function(x) {
  x <- valide_numerique(x)
  10^(x / 10)
}

valide_numerique <- function(x) {
  if (!is.numeric(x) && !(is.logical(x) && all(is.na(x)))) {
    stop("`x` doit \u00eatre num\u00e9rique.", call. = FALSE)
  }
  storage.mode(x) <- "double"
  x
}
