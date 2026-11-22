#' Ratio de changement radar (RCR) minimal et sa date, pour une orbite
#'
#' Calcule, pour chaque pixel d'une série Sentinel-1 d'**une seule orbite
#' relative**, le ratio de changement radar à chaque date, puis garde le ratio
#' le plus bas et une date de coupe. Définition (M24, § II-D.1, p. 13747 ; B18,
#' § 2.3.2, p. 10, éq. 1) : à la date d'acquisition `d_i`,
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
#' @section Deux ratios, détection et date : Le ratio est calculé deux fois,
#'   avec la même `Ma` et deux longueurs de `Mb` :
#'
#'   * avec `xb` : c'est le ratio de **détection**, `ratio_min_db` (son
#'     minimum), seul lu par la segmentation ([rcr_segment()]) ;
#'   * avec `xb_date` : c'est le ratio de **datation** ; la date de coupe
#'     (`date_min`, `date_avant`, `duree_xa_jours`) est celle de **son**
#'     minimum, qui peut différer de la date du minimum du ratio de détection.
#'
#'   Avec `xb = Inf`, `Mb` garde après la coupe les images d'avant : le ratio
#'   reste presque à plat sur plusieurs dates et son minimum tombe souvent
#'   trop tard. En simulation (`docs/analyses/precision-date.md`, mission 008 ;
#'   fenêtre 3, chute de -6 dB, cadence 12 j), la date est exacte pour 15,6 %
#'   des pixels coupés à `xb = Inf` contre 96,4 % à `xb = 5`, sans changer ce
#'   qui est détecté. **Provisoire (`xb_date = 5`, repli 10), gèle au jalon 2.**
#'   Si `xb_date == xb`, un seul ratio est calculé et la date est celle du
#'   ratio de détection (comportement d'avant la mission 010 avec
#'   `xb = xb_date = Inf`).
#'
#'   Un pixel a une date si et seulement s'il a un ratio de détection : les
#'   deux ratios sont calculés aux mêmes dates (celles qui ont `xa` images
#'   valides après elles).
#'
#' @section Date retenue : La coupe a lieu entre `d_i` (dernière image avant
#'   la chute) et `d_(i+1)` (première image après) : B18, § 2.3.2, p. 11,
#'   intervalle `[d_k, d_(k+1)]`. M24 retient « la date correspondant au RCR
#'   le plus bas » sans dire laquelle des deux. `date_min` est la **première
#'   image valide après la chute**, `d_(i+1)` ; `date_avant` donne `d_i`, où
#'   `d_i` est la date du minimum du ratio de **datation** (voir plus haut).
#'   **Provisoire (non précisé dans M24), gèle au jalon 2** : à confronter aux
#'   dates de la carte SUFOSAT v3.0.1.
#'
#'   En cas d'égalité de ratios, la date la plus ancienne l'emporte.
#'   **Provisoire, non sourcé (choix du package), gèle au jalon 2.**
#'
#' @section Début des ratios : Aucun ratio n'est calculé pour une date `d_i`
#'   antérieure au 1er janvier de l'année `annee_noyau + 1` (2019 par défaut).
#'   Les images plus anciennes servent encore à la moyenne `Mb` d'une date
#'   ultérieure. Cela écarte les faux minima de début de série, où `Mb`
#'   repose sur trop peu d'images. **Provisoire, déduit de M24, § II-B.1,
#'   p. 13746 (noyau du filtre calculé sur 2018, images filtrées à partir du
#'   1er janvier 2019), gèle au jalon 2.**
#'
#' @section Xa en jours : `xa` compte des images. Sa durée réelle se lit sur
#'   les dates d'acquisition et non sur une cadence supposée :
#'   `duree_xa_jours` donne, pour le minimum retenu, le nombre de jours entre
#'   `d_i` et la dernière image de la fenêtre `Ma`. Sur une cadence régulière
#'   sans image manquante, il vaut [xa_en_jours()].
#'
#' @section Mémoire : Le calcul est vectorisé sur les pixels, avec une boucle
#'   sur les dates. Il garde en mémoire environ trois fois la taille de
#'   `serie` (sommes cumulées et positions des images valides). Le ratio de
#'   datation réutilise les mêmes sommes cumulées : il n'ajoute que quelques
#'   vecteurs de la taille d'une image.
#'
#' @param serie Tableau numérique à trois dimensions (lignes x colonnes x
#'   dates) de rétrodiffusion **linéaire** (intensité, pas des dB) d'une
#'   seule orbite relative.
#' @param dates Vecteur de classe `Date`, strictement croissant, sans `NA`, de
#'   longueur `dim(serie)[3]` : la date d'acquisition de chaque image.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seuls `xa`,
#'   `xb`, `xb_date` et `annee_noyau` servent ici.
#'
#' @return Une liste :
#'   * `ratio_min_db` : matrice (lignes x colonnes) du minimum du ratio de
#'     détection (calculé avec `xb`), en dB ; `NA` si le pixel n'a aucun
#'     ratio ;
#'   * `date_min` : matrice d'entiers `YYDDD` (voir [date_vers_yyddd()]) de
#'     la première image valide après la chute, au minimum du ratio de
#'     datation (calculé avec `xb_date`) ;
#'   * `date_avant` : matrice d'entiers `YYDDD` de la dernière image valide
#'     avant la chute, au même minimum ;
#'   * `duree_xa_jours` : matrice d'entiers, durée en jours de `d_i` à la
#'     dernière image de la fenêtre `Ma`, au même minimum ;
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
#' \donttest{
#' # Tracé : la série du pixel [1, 1] et les deux dates qui encadrent la chute
#' plot(dates, lineaire_vers_db(serie[1, 1, ]), type = "b",
#'      xlab = "Date d'acquisition", ylab = "VH (dB)")
#' abline(v = yyddd_vers_date(r$date_avant[1, 1]), lty = 2) # d_i
#' abline(v = yyddd_vers_date(r$date_min[1, 1]), lty = 1)   # d_(i+1), date retenue
#' }
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
  xb_date <- p$xb_date
  # Un seul calcul si la date se lit sur le ratio de détection.
  dater_a_part <- !identical(xb_date, xb)
  # Dates d_i admises pour un ratio (voir la section « Début des ratios »).
  debut <- as.Date(sprintf("%d-01-01", p$annee_noyau + 1L))
  admise <- dates >= debut

  noms <- dimnames(serie)[1:2]
  x <- serie
  rm(serie)
  dim(x) <- c(npix, nt)
  if (isTRUE(min(x, na.rm = TRUE) <= 0)) {
    negatif <- !is.na(x) & x <= 0
    warning(
      sum(negatif), " valeur(s) linéaire(s) nulle(s) ou négative(s) ",
      "traitée(s) comme images écartées (NA).",
      call. = FALSE
    )
    x[negatif] <- NA_real_
    rm(negatif)
  }

  # Passe 1 : pour chaque pixel, somme cumulée des k premières images valides,
  # écrite sur place dans la colonne k de `x` (la somme de 0 image vaut 0), et
  # position (index de date) de la k-ième image valide. Les sommes sont
  # accumulées en double, dans l'ordre des dates. Sans aucune image manquante,
  # la k-ième image valide est la date k : `position` n'est pas construite.
  pleine <- !anyNA(x)
  if (pleine) {
    total <- rep(nt, npix)
    position <- NULL
    for (t in seq_len(nt)[-1L]) x[, t] <- x[, t - 1L] + x[, t]
  } else {
    total <- integer(npix)
    somme <- numeric(npix)
    position <- matrix(NA_integer_, nrow = npix, ncol = nt)
    for (t in seq_len(nt)) {
      v <- which(!is.na(x[, t]))
      if (length(v) == 0L) next
      somme[v] <- somme[v] + x[v, t]
      total[v] <- total[v] + 1L
      # Colonne total <= t : déjà lue, on peut l'écraser.
      cle <- (total[v] - 1) * npix + v
      x[cle] <- somme[v]
      position[cle] <- t
    }
    rm(somme)
  }
  lim <- max(total) - xa

  # Somme cumulée de rang j (0 : aucune image) des pixels `pix` (NULL : tous).
  cumul_j <- function(j, pix) {
    if (j == 0L) return(0)
    if (is.null(pix)) x[, j] else x[pix, j]
  }
  # Pixels dont la k-ième image valide reçoit un ratio : suivie d'au moins
  # xa images valides et admise. NULL : tous ; integer(0) : aucun.
  pixels_k <- function(k) {
    if (pleine) return(if (admise[k]) NULL else integer(0))
    which(total >= k + xa & admise[position[, k]])
  }
  # Rapport linéaire Ma / Mb à la k-ième image valide, Mb sur `nb_avant`
  # images (Inf : toutes), à partir des sommes cumulées : mêmes opérations,
  # dans le même ordre, que la définition (le ratio en dB est
  # lineaire_vers_db() de ce rapport).
  rapport_k <- function(k, pix, s_apres, c_k, nb_avant) {
    nb <- if (is.infinite(nb_avant)) k else min(k, as.integer(nb_avant))
    mb <- (c_k - cumul_j(k - nb, pix)) / nb
    (s_apres / xa) / mb
  }
  # Mise à jour d'un minimum courant : strictement plus bas seulement (en cas
  # d'égalité, la date la plus ancienne l'emporte).
  plus_bas <- function(r, courant, pix) {
    if (is.null(pix)) r < courant else r < courant[pix]
  }
  ecrit <- function(cible, pix, mieux, valeur) {
    if (is.null(pix)) cible[mieux] <- valeur[mieux] else cible[pix[mieux]] <- valeur[mieux]
    cible
  }

  # Passe 2 : ratio à chaque image valide suivie d'au moins xa images valides.
  # Le ratio en dB est croissant avec le rapport Ma / Mb : seul le logarithme
  # coûte. On cherche d'abord, en linéaire, le rapport minimal de chaque pixel
  # (2a) ; puis (2b) on ne passe en dB que les rapports à moins de 1e-6 (en
  # relatif) de ce minimum, et on applique à eux seuls la règle de mise à
  # jour : un rapport plus grand d'un facteur 1 + 1e-6 donne un ratio plus
  # grand d'environ 4e-6 dB, bien au-delà de l'erreur d'arrondi du
  # logarithme ; il ne peut ni être le minimum ni l'égaler. Le minimum et sa
  # date sont donc ceux du calcul de tous les ratios. Si un rapport n'est pas
  # strictement positif et fini ou infini (cas dégénérés), on calcule tous
  # les ratios (2c), comme la définition.
  `%||%` <- function(a, b) if (is.null(a)) b else a
  balayer <- function(traiter) {
    for (k in seq_len(max(lim, 0L))) {
      pix <- pixels_k(k)
      if (!is.null(pix) && length(pix) == 0L) next
      c_k <- cumul_j(k, pix)
      s_apres <- cumul_j(k + xa, pix) - c_k
      traiter(k, pix, s_apres, c_k)
    }
  }
  q_min <- rep(Inf, npix)
  q_min_date <- if (dater_a_part) rep(Inf, npix) else NULL
  regulier <- TRUE
  balayer(function(k, pix, s_apres, c_k) {
    q <- rapport_k(k, pix, s_apres, c_k, xb)
    if (is.na(m <- min(q)) || m <= 0) regulier <<- FALSE
    if (is.null(pix)) q_min <<- pmin(q_min, q) else q_min[pix] <<- pmin(q_min[pix], q)
    if (dater_a_part) {
      q <- rapport_k(k, pix, s_apres, c_k, xb_date)
      if (is.na(m <- min(q)) || m <= 0) regulier <<- FALSE
      if (is.null(pix)) {
        q_min_date <<- pmin(q_min_date, q)
      } else {
        q_min_date[pix] <<- pmin(q_min_date[pix], q)
      }
    }
  })
  marge <- 1 + 1e-6
  q_lim <- q_min * marge
  q_lim_date <- if (dater_a_part) q_min_date * marge else NULL
  rm(q_min, q_min_date)

  # `meilleur` : minimum du ratio de détection (xb) ; `meilleur_date` et
  # `k_avant` : minimum du ratio de datation (xb_date) et sa position.
  meilleur <- rep(Inf, npix)
  meilleur_date <- if (dater_a_part) rep(Inf, npix) else NULL
  k_avant <- rep(NA_integer_, npix)
  # Applique la règle de mise à jour aux rapports `q` des pixels `pix`
  # retenus par `garde` (TRUE : tous) ; rend les positions mises à jour.
  mettre_a_jour <- function(q, pix, garde, courant) {
    if (!isTRUE(garde)) {
      idx <- which(garde)
      if (length(idx) == 0L) return(list(courant = courant, pix = integer(0), mieux = logical(0)))
      q <- q[idx]
      pix <- if (is.null(pix)) idx else pix[idx]
    }
    r <- lineaire_vers_db(q)
    mieux <- plus_bas(r, courant, pix)
    list(courant = ecrit(courant, pix, mieux, r), pix = pix, mieux = mieux)
  }
  marquer <- function(k, maj) {
    if (length(maj$mieux) == 0L) return(invisible())
    if (is.null(maj$pix)) {
      k_avant[maj$mieux] <<- k
    } else {
      k_avant[maj$pix[maj$mieux]] <<- k
    }
  }
  balayer(function(k, pix, s_apres, c_k) {
    q <- rapport_k(k, pix, s_apres, c_k, xb)
    garde <- if (regulier) q <= (q_lim[pix %||% TRUE]) else TRUE
    maj <- mettre_a_jour(q, pix, garde, meilleur)
    meilleur <<- maj$courant
    if (dater_a_part) {
      q <- rapport_k(k, pix, s_apres, c_k, xb_date)
      garde <- if (regulier) q <= (q_lim_date[pix %||% TRUE]) else TRUE
      maj <- mettre_a_jour(q, pix, garde, meilleur_date)
      meilleur_date <<- maj$courant
    }
    marquer(k, maj)
  })
  rm(meilleur_date)

  trouve <- which(!is.na(k_avant))
  ratio <- rep(NA_real_, npix)
  date_min <- rep(NA_integer_, npix)
  date_avant <- rep(NA_integer_, npix)
  duree <- rep(NA_integer_, npix)
  if (length(trouve) > 0L) {
    k <- k_avant[trouve]
    if (pleine) {
      i_avant <- k
      i_apres <- k + 1L
      i_fin <- k + xa
    } else {
      lire <- function(j) position[(j - 1) * npix + trouve]
      i_avant <- lire(k)
      i_apres <- lire(k + 1L)
      i_fin <- lire(k + xa)
    }
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
#' `"minimum"`, seule règle permise : par pixel, l'orbite au ratio de
#' **détection** (`ratio_min_db`) le plus bas donne le ratio et ses dates
#' (celles que [rcr_compute()] a tirées, pour cette orbite, du ratio de
#' datation calculé avec `xb_date`) ; une orbite sans ratio pour ce pixel
#' (`NA`) est ignorée. Règle **provisoire, gèle au jalon 2** : non précisée dans M24
#' (p. 13748, « mosaicked »), formule ambiguë dans B18 (§ 2.3.2, p. 11). En
#' cas d'égalité, la première orbite de la liste l'emporte : **provisoire,
#' non sourcé (choix du package), gèle au jalon 2.**
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
    stop("`resultats` doit \u00eatre une liste d'au moins un r\u00e9sultat de rcr_compute().", call. = FALSE)
  }
  for (j in seq_along(resultats)) {
    r <- resultats[[j]]
    if (!is.list(r) || !all(champs %in% names(r))) {
      stop("L'\u00e9l\u00e9ment ", j, " de `resultats` n'est pas un r\u00e9sultat de rcr_compute().", call. = FALSE)
    }
    if (!isTRUE(all.equal(valide_parametres(r$parametres), p))) {
      stop(
        "L'\u00e9l\u00e9ment ", j, " de `resultats` a \u00e9t\u00e9 calcul\u00e9 avec d'autres ",
        "r\u00e9glages que `parametres`.",
        call. = FALSE
      )
    }
    if (!identical(dim(r$ratio_min_db), dim(resultats[[1]]$ratio_min_db))) {
      stop("Tous les r\u00e9sultats doivent avoir les m\u00eames dimensions.", call. = FALSE)
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
    stop("`serie` doit \u00eatre un tableau num\u00e9rique.", call. = FALSE)
  }
  d <- dim(serie)
  if (length(d) != 3L) {
    stop("`serie` doit \u00eatre un tableau \u00e0 trois dimensions (lignes x colonnes x dates).", call. = FALSE)
  }
  if (any(d == 0L)) {
    stop("`serie` ne doit avoir aucune dimension vide.", call. = FALSE)
  }
  # range() lit le tableau sans le recopier ; any(is.infinite()) ne sert
  # que si une borne est infinie (ou si tout est NA).
  bornes <- suppressWarnings(range(serie, na.rm = TRUE))
  if (any(is.infinite(bornes)) && any(is.infinite(serie))) {
    stop("`serie` ne doit pas contenir de valeur infinie.", call. = FALSE)
  }
  storage.mode(serie) <- "double"
  serie
}

valide_dates_serie <- function(dates, nt) {
  if (!inherits(dates, "Date")) {
    stop("`dates` doit \u00eatre de classe Date.", call. = FALSE)
  }
  if (length(dates) != nt) {
    stop(
      "`dates` doit avoir autant d'\u00e9l\u00e9ments que la troisi\u00e8me dimension de `serie` (",
      nt, "), et non ", length(dates), ".",
      call. = FALSE
    )
  }
  if (anyNA(dates)) {
    stop("`dates` ne doit pas contenir de NA.", call. = FALSE)
  }
  if (is.unsorted(dates, strictly = TRUE)) {
    stop("`dates` doit \u00eatre strictement croissant (une image par date).", call. = FALSE)
  }
  date_vers_yyddd(dates)
}
