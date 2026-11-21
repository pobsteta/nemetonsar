#' Coder et décoder les dates de coupe au format YYDDD
#'
#' Les cartes SUFOSAT stockent la date estimée d'une coupe sous la forme d'un
#' entier `YYDDD` : l'année sur deux chiffres, puis le jour de l'année sur
#' trois chiffres (de 1 à 366). Le 15 mars 2024 s'écrit ainsi `24075`.
#'
#' Les valeurs manquantes sont conservées : un `NA` en entrée donne un `NA` en
#' sortie, ce qui permet de traiter directement les pixels sans détection.
#'
#' @param date Vecteur de dates (`Date`, ou tout objet accepté par
#'   [as.Date()]), entre `siecle` et `siecle + 99`.
#' @param code Vecteur d'entiers au format `YYDDD`.
#' @param siecle Première année du siècle des dates. Par défaut 2000.
#'
#' @return `date_vers_yyddd()` renvoie un vecteur d'entiers ;
#'   `yyddd_vers_date()` renvoie un vecteur de classe `Date`.
#'
#' @examples
#' date_vers_yyddd(as.Date("2024-03-15"))
#' yyddd_vers_date(24075L)
#' yyddd_vers_date(date_vers_yyddd(as.Date(c("2018-01-01", NA, "2025-09-30"))))
#'
#' @name dates_yyddd
NULL

#' @rdname dates_yyddd
#' @export
date_vers_yyddd <- function(date, siecle = 2000L) {
  siecle <- valide_siecle(siecle)
  date <- as.Date(date)
  lt <- as.POSIXlt(date)
  annee <- lt$year + 1900L
  hors <- !is.na(annee) & (annee < siecle | annee > siecle + 99L)
  if (any(hors)) {
    stop(
      "Dates hors de la plage ", siecle, "-", siecle + 99L, " : ",
      paste(format(date[hors][seq_len(min(3L, sum(hors)))]), collapse = ", "),
      call. = FALSE
    )
  }
  as.integer((annee - siecle) * 1000L + lt$yday + 1L)
}

#' @rdname dates_yyddd
#' @export
yyddd_vers_date <- function(code, siecle = 2000L) {
  siecle <- valide_siecle(siecle)
  if (!is.numeric(code) && !all(is.na(code))) {
    stop("`code` doit \u00eatre num\u00e9rique.", call. = FALSE)
  }
  code <- as.numeric(code)
  connu <- !is.na(code)
  if (any(code[connu] != floor(code[connu]))) {
    stop("`code` doit contenir des entiers au format YYDDD.", call. = FALSE)
  }
  annee <- siecle + code %/% 1000
  jour <- code %% 1000
  nb_jours <- ifelse(est_bissextile(annee), 366, 365)
  invalide <- connu & (code < 0 | code > 99366 | jour < 1 | jour > nb_jours)
  if (any(invalide)) {
    stop(
      "Codes YYDDD invalides : ",
      paste(code[invalide][seq_len(min(3L, sum(invalide)))], collapse = ", "),
      call. = FALSE
    )
  }
  resultat <- rep(as.Date(NA), length(code))
  # sprintf() rend un vecteur vide pour une entrée vide, contrairement à paste0()
  premier_janvier <- as.Date(sprintf("%d-01-01", as.integer(annee[connu])))
  resultat[connu] <- premier_janvier + (jour[connu] - 1)
  resultat
}

est_bissextile <- function(annee) {
  (annee %% 4 == 0 & annee %% 100 != 0) | annee %% 400 == 0
}

valide_siecle <- function(siecle) {
  if (!is.numeric(siecle) || length(siecle) != 1L || is.na(siecle) || siecle %% 100 != 0) {
    stop("`siecle` doit \u00eatre une ann\u00e9e multiple de 100, par exemple 2000.", call. = FALSE)
  }
  as.integer(siecle)
}
