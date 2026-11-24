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
#' @section Première date sous le seuil de datation : En plus du minimum,
#'   chaque orbite donne, par pixel, la **première** date `d_(i+1)` où le ratio
#'   de datation est au plus égal à `seuil_datation_db` (`date_seuil`,
#'   `date_avant_seuil`, `duree_seuil_jours`), `NA` s'il n'y passe jamais.
#'   La comparaison se fait sur le rapport linéaire `Ma / Mb`, contre
#'   `db_vers_lineaire(seuil_datation_db)`. C'est l'entrée de la règle de date
#'   `"premiere_sous_seuil"` de [rcr_combine_orbites()]. Elle ne dépend que des
#'   images jusqu'à `d_(i+1)` + `xa` : prolonger la série ne change pas une
#'   date déjà trouvée (voir `docs/analyses/regle-r2-pilote.md`).
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
#'   `xb`, `xb_date`, `seuil_datation_db` et `annee_noyau` servent ici.
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
#'   * `date_seuil`, `date_avant_seuil`, `duree_seuil_jours` : comme `date_min`,
#'     `date_avant` et `duree_xa_jours`, mais à la première date où le ratio de
#'     datation est au plus égal à `seuil_datation_db` (`NA` si aucune) ;
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
  # min() sans copie ; le masque n'est construit que s'il sert.
  if (isTRUE(suppressWarnings(min(x, na.rm = TRUE)) <= 0)) {
    negatif <- !is.na(x) & x <= 0
    warning(
      sum(negatif), " valeur(s) lin\u00e9aire(s) nulle(s) ou n\u00e9gative(s) ",
      "trait\u00e9e(s) comme images \u00e9cart\u00e9es (NA).",
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
    somme <- x[, 1L]
    for (t in seq_len(nt)[-1L]) {
      somme <- somme + x[, t]
      x[, t] <- somme
    }
    rm(somme)
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
  # xa images valides et admise ; parmi `restreint` si non NULL. NULL : tous ;
  # integer(0) : aucun.
  pixels_k <- function(k, restreint) {
    if (is.null(restreint)) {
      if (pleine) return(if (admise[k]) NULL else integer(0))
      return(which(total >= k + xa & admise[position[, k]]))
    }
    if (pleine) return(if (admise[k]) restreint else integer(0))
    restreint[total[restreint] >= k + xa & admise[position[restreint, k]]]
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
  # Le ratio en dB est lineaire_vers_db() du rapport Ma / Mb, et seul le
  # logarithme coûte. (2a) On suit en linéaire, pour chaque pixel, le plus
  # petit rapport `m1`, sa première position `k1` et le plus petit des autres
  # rapports `m2`. Si `m2` dépasse `m1` d'un facteur 1 + 1e-6, aucun autre
  # ratio ne peut égaler ni passer sous celui de `k1` (l'écart, environ
  # 4e-6 dB, dépasse de loin l'erreur d'arrondi du logarithme) : le minimum
  # est lineaire_vers_db(m1), atteint pour la première fois en `k1`. (2b)
  # Pour les autres pixels (rapports presque égaux, plateaux), on passe en dB
  # les rapports à moins de 1e-6 du minimum et on leur applique la règle de
  # mise à jour, date par date. Les résultats sont ceux du calcul de tous
  # les ratios. Si un rapport n'est pas strictement positif (cas
  # dégénérés), on calcule tous les ratios de tous les pixels, comme la
  # définition.
  balayer <- function(traiter, restreint = NULL) {
    for (k in seq_len(max(lim, 0L))) {
      pix <- pixels_k(k, restreint)
      if (!is.null(pix) && length(pix) == 0L) next
      c_k <- cumul_j(k, pix)
      s_apres <- cumul_j(k + xa, pix) - c_k
      traiter(k, pix, s_apres, c_k)
    }
  }
  suivi <- function() list(m1 = rep(Inf, npix), m2 = rep(Inf, npix))
  # Met à jour m1, m2 (et k1 si `position` est vrai) avec les rapports q.
  suivre <- function(etat, q, pix, k, position) {
    if (is.null(pix)) {
      if (position) k1[q < etat$m1] <<- k
      etat$m2 <- pmin(etat$m2, pmax(q, etat$m1))
      etat$m1 <- pmin(etat$m1, q)
    } else {
      m1 <- etat$m1[pix]
      if (position) k1[pix[q < m1]] <<- k
      etat$m2[pix] <- pmin(etat$m2[pix], pmax(q, m1))
      etat$m1[pix] <- pmin(m1, q)
    }
    etat
  }
  k1 <- rep(NA_integer_, npix)
  # Première image valide (rang k) dont le ratio de datation passe au plus à
  # `seuil_datation_db` : comparaison en linéaire, sans logarithme.
  seuil_lin <- db_vers_lineaire(p$seuil_datation_db)
  k_seuil <- rep(NA_integer_, npix)
  marquer_seuil <- function(q, pix, k) {
    sous <- which(!is.na(q) & q <= seuil_lin)
    if (length(sous) == 0L) return(invisible())
    cible <- if (is.null(pix)) sous else pix[sous]
    nouveau <- is.na(k_seuil[cible])
    k_seuil[cible[nouveau]] <<- k
    invisible()
  }
  detection <- suivi()
  datation <- if (dater_a_part) suivi() else NULL
  regulier <- TRUE
  balayer(function(k, pix, s_apres, c_k) {
    q <- rapport_k(k, pix, s_apres, c_k, xb)
    if (is.na(m <- min(q)) || m <= 0) regulier <<- FALSE
    detection <<- suivre(detection, q, pix, k, !dater_a_part)
    if (dater_a_part) {
      q <- rapport_k(k, pix, s_apres, c_k, xb_date)
      if (is.na(m <- min(q)) || m <= 0) regulier <<- FALSE
      datation <<- suivre(datation, q, pix, k, TRUE)
    }
    # `q` est ici le rapport de datation (xb_date, ou xb s'ils sont égaux).
    marquer_seuil(q, pix, k)
  })
  marge <- 1 + 1e-6

  # `meilleur` : minimum du ratio de détection (xb) ; `meilleur_date` et
  # `k_avant` : minimum du ratio de datation (xb_date) et sa position.
  meilleur <- rep(Inf, npix)
  meilleur_date <- if (dater_a_part) rep(Inf, npix) else NULL
  k_avant <- rep(NA_integer_, npix)
  if (regulier) {
    proche <- detection$m2 <= detection$m1 * marge
    if (dater_a_part) proche <- proche | datation$m2 <= datation$m1 * marge
    proche <- proche & !is.na(k1)
    net <- which(!is.na(k1) & !proche)
    meilleur[net] <- lineaire_vers_db(detection$m1[net])
    k_avant[net] <- k1[net]
    restreint <- which(proche)
    q_lim <- detection$m1 * marge
    q_lim_date <- if (dater_a_part) datation$m1 * marge else NULL
  } else {
    restreint <- NULL
  }
  rm(detection, datation, k1)

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
  if (is.null(restreint) || length(restreint) > 0L) {
    balayer(function(k, pix, s_apres, c_k) {
      q <- rapport_k(k, pix, s_apres, c_k, xb)
      garde <- if (regulier) q <= q_lim[pix] else TRUE
      maj <- mettre_a_jour(q, pix, garde, meilleur)
      meilleur <<- maj$courant
      if (dater_a_part) {
        q <- rapport_k(k, pix, s_apres, c_k, xb_date)
        garde <- if (regulier) q <= q_lim_date[pix] else TRUE
        maj <- mettre_a_jour(q, pix, garde, meilleur_date)
        meilleur_date <<- maj$courant
      }
      marquer(k, maj)
    }, restreint)
  }
  rm(meilleur_date)

  # Dates (d_(i+1), d_i) et durée de Xa pour les pixels `pix` dont le rang de
  # la dernière image avant la chute est `k`.
  dates_de <- function(pix, k) {
    if (pleine) {
      i_avant <- k
      i_apres <- k + 1L
      i_fin <- k + xa
    } else {
      lire <- function(j) position[(j - 1) * npix + pix]
      i_avant <- lire(k)
      i_apres <- lire(k + 1L)
      i_fin <- lire(k + xa)
    }
    list(apres = codes[i_apres], avant = codes[i_avant],
         duree = as.integer(dates[i_fin] - dates[i_avant]))
  }
  trouve <- which(!is.na(k_avant))
  ratio <- rep(NA_real_, npix)
  date_min <- rep(NA_integer_, npix)
  date_avant <- rep(NA_integer_, npix)
  duree <- rep(NA_integer_, npix)
  if (length(trouve) > 0L) {
    dd <- dates_de(trouve, k_avant[trouve])
    ratio[trouve] <- meilleur[trouve]
    date_avant[trouve] <- dd$avant
    date_min[trouve] <- dd$apres
    duree[trouve] <- dd$duree
  }
  # Première date sous le seuil de datation (règle « premiere_sous_seuil »).
  date_seuil <- rep(NA_integer_, npix)
  date_avant_seuil <- rep(NA_integer_, npix)
  duree_seuil <- rep(NA_integer_, npix)
  sous_seuil <- which(!is.na(k_seuil))
  if (length(sous_seuil) > 0L) {
    dd <- dates_de(sous_seuil, k_seuil[sous_seuil])
    date_seuil[sous_seuil] <- dd$apres
    date_avant_seuil[sous_seuil] <- dd$avant
    duree_seuil[sous_seuil] <- dd$duree
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
    date_seuil = en_matrice(date_seuil),
    date_avant_seuil = en_matrice(date_avant_seuil),
    duree_seuil_jours = en_matrice(duree_seuil),
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
#' @section Règle de date : Le ratio (`ratio_min_db`) est toujours celui de
#'   l'orbite au ratio de détection le plus bas : la règle de date ne change ni
#'   la détection ni la segmentation. Les dates dépendent de
#'   `parametres$regle_date` :
#'
#'   * `"minimum"` : dates du minimum du ratio de datation de l'orbite retenue
#'     (règle d'avant la mission 030) ;
#'   * `"premiere_sous_seuil"` (défaut, règle R2 de la mission 027) : par
#'     pixel, parmi **toutes** les orbites, la première date `d_(i+1)` (la plus
#'     ancienne) où le ratio de datation est au plus égal à
#'     `seuil_datation_db`. Une date commune à deux orbites : la première de la
#'     liste. Un pixel qui a un ratio mais aucun passage sous le seuil garde les
#'     dates de la règle `"minimum"` (repli) ; `date_repli` le marque.
#'
#'   Les dates sont comparées en `YYDDD` : valable pour des dates d'un même
#'   siècle (Sentinel-1 date de 2014). Pour `"premiere_sous_seuil"`, `date_avant`
#'   et `duree_xa_jours` sont celles de l'orbite qui donne la date.
#'   **Provisoire, décision de Pascal du 2026-11-24, gèle au jalon 2.**
#'
#' @param resultats Liste (nommée ou non) d'au moins un résultat de
#'   [rcr_compute()], tous de mêmes dimensions et calculés avec `parametres`.
#' @param parametres Un objet créé par [parametres_sufosat()].
#'
#' @return Une liste de même forme que celle de [rcr_compute()], sans les champs
#'   `date_seuil`, `date_avant_seuil` et `duree_seuil_jours` (déjà utilisés), plus :
#'   * `orbite` : matrice donnant, par pixel, le nom de l'orbite retenue par la
#'     détection (ou son rang dans `resultats` si la liste n'est pas nommée),
#'     `NA` sans ratio ;
#'   * `orbite_date` : l'orbite qui donne la date (celle de `orbite` pour la
#'     règle `"minimum"` et pour un pixel en repli) ;
#'   * `date_repli` : matrice logique, `TRUE` pour un pixel en repli sur la règle
#'     `"minimum"` (règle `"premiere_sous_seuil"` sans passage sous le seuil) ;
#'     toujours `FALSE` avec la règle `"minimum"`.
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
  champs_seuil <- c("date_seuil", "date_avant_seuil", "duree_seuil_jours")
  champs_requis <- c(champs, if (p$regle_date == "premiere_sous_seuil") champs_seuil)
  if (!is.list(resultats) || inherits(resultats, "parametres_sufosat") ||
      length(resultats) < 1L) {
    stop("`resultats` doit \u00eatre une liste d'au moins un r\u00e9sultat de rcr_compute().", call. = FALSE)
  }
  for (j in seq_along(resultats)) {
    r <- resultats[[j]]
    if (!is.list(r) || !all(champs_requis %in% names(r))) {
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
      sortie$orbite_date <- orbite
      sortie$date_repli <- array(FALSE, dim = dim(orbite), dimnames = dimnames(orbite))
      if (p$regle_date == "premiere_sous_seuil") sortie <- dater_premiere(sortie, orbite)
      sortie
    }
  )
  # Règle R2 : première date sous le seuil, toutes orbites, repli sur le minimum.
  dater_premiere <- function(sortie, orbite) {
    t_date <- array(NA_integer_, dim = dim(orbite), dimnames = dimnames(orbite))
    t_avant <- t_date
    t_duree <- t_date
    t_orbite <- orbite
    t_orbite[] <- NA
    for (j in seq_along(resultats)) {
      r <- resultats[[j]]
      mieux <- !is.na(r$date_seuil) & (is.na(t_date) | r$date_seuil < t_date)
      t_date[mieux] <- r$date_seuil[mieux]
      t_avant[mieux] <- r$date_avant_seuil[mieux]
      t_duree[mieux] <- r$duree_seuil_jours[mieux]
      t_orbite[mieux] <- etiquettes[j]
    }
    # Seuls les pixels détectables (avec un ratio) sont datés.
    pris <- !is.na(t_date) & !is.na(sortie$ratio_min_db)
    sortie$date_min[pris] <- t_date[pris]
    sortie$date_avant[pris] <- t_avant[pris]
    sortie$duree_xa_jours[pris] <- t_duree[pris]
    sortie$orbite_date[pris] <- t_orbite[pris]
    sortie$date_repli[] <- !pris & !is.na(sortie$ratio_min_db)
    sortie
  }
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
  # min() et max() lisent le tableau sans le recopier ; any(is.infinite())
  # ne sert que si une borne est infinie (ou si tout est NA).
  bornes <- suppressWarnings(c(min(serie, na.rm = TRUE), max(serie, na.rm = TRUE)))
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
