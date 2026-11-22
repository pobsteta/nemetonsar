#' Segmentation en deux seuils : graines d'ombre et croissance de région
#'
#' Applique l'étape de segmentation de la méthode à la carte du ratio de
#' changement radar (RCR) minimal : les **deux seuils s'appliquent à la même
#' image du ratio minimal** (B18, § 2.3.3, p. 12 ; M24, § II-D.1,
#' p. 13747-13748, « seeds and extends »).
#'
#' 1. **Graines** (ombres radar) : pixels dont le ratio est **strictement
#'    inférieur** au seuil `ts` effectif. Inégalité stricte : B18, § 2.3.2,
#'    p. 11 (« min(RCR_i) < Y dB »), relevé dans la table de la mission 001.
#' 2. **Zones** : composantes connexes des pixels dont le ratio est
#'    **inférieur ou égal** au seuil `tp` effectif. Le sens de l'égalité
#'    n'est écrit ni dans M24 ni dans B18 pour `tp` : **provisoire, non
#'    sourcé (choix du package), gèle au jalon 2.**
#' 3. On ne garde que les zones qui **contiennent au moins une graine** (B18,
#'    § 2.3.3, p. 12 : « only those that intersect with a detected shadow are
#'    kept »). Comme `ts < tp`, une graine est toujours dans une zone ; une
#'    graine isolée forme donc une zone d'un pixel, gardée.
#'
#' Les seuils effectifs sont ceux de [seuils_db()] (`facteur_seuil` x `ts_db`
#' et `tp_db`). Le voisinage est `parametres$connexite` (4 ou 8 voisins) :
#' **non précisé dans M24 ni B18, provisoire, gèle au jalon 2**, voir
#' [parametres_sufosat()].
#'
#' Ni le retrait des petits objets (`surface_min_ha`) ni la fermeture
#' morphologique ne sont faits ici : ils relèvent du post-traitement.
#'
#' @section Pixels sans ratio : Un ratio `NA` (ou `NaN`) n'est ni graine ni
#'   zone : le pixel n'est pas détecté et ne relie pas deux zones voisines.
#'   Une valeur infinie est refusée.
#'
#' @section Calcul : L'étiquetage des composantes connexes est écrit en R de
#'   base, sans récursion : union-find vectorisé (chaque racine est accrochée
#'   à la plus petite racine voisine, puis les chemins sont compressés par
#'   sauts de pointeurs, jusqu'à stabilité). Mémoire : quelques vecteurs de la
#'   taille de la matrice.
#'
#' @param ratio_min_db Matrice numérique (lignes x colonnes) du ratio minimal,
#'   en dB, ou directement le résultat (une liste) de [rcr_compute()] ou de
#'   [rcr_combine_orbites()], dont l'élément `ratio_min_db` est alors pris.
#' @param parametres Un objet créé par [parametres_sufosat()] ; seuls
#'   `facteur_seuil`, `ts_db`, `tp_db` et `connexite` servent ici.
#'
#' @return Une liste :
#'   * `detection` : matrice logique, `TRUE` pour un pixel détecté (dans une
#'     zone gardée), `FALSE` sinon, y compris pour un ratio `NA` ;
#'   * `zone` : matrice d'entiers, identifiant de la zone gardée (de 1 au
#'     nombre de zones, dans l'ordre du premier pixel de chaque zone en
#'     parcourant la matrice colonne par colonne), `NA` hors détection ;
#'   * `graine` : matrice logique des graines (ratio < `ts` effectif) ;
#'   * `seuils_db` : les seuils effectifs utilisés, `c(ts = , tp = )` ;
#'   * `parametres` : l'objet `parametres` validé.
#'
#'   Les matrices ont les dimensions et les noms de dimensions de
#'   `ratio_min_db`.
#'
#' @seealso [seuils_db()], [rcr_compute()], [rcr_combine_orbites()].
#'
#' @examples
#' # Ratio minimal synthétique (dB) : forêt stable autour de 0 dB, trois taches
#' ratio <- matrix(0, nrow = 12, ncol = 12)
#' ratio[2:5, 2:5] <- -4     # tache sous tp ...
#' ratio[3, 3] <- -7         # ... avec une ombre (graine) : gardée
#' ratio[8:10, 2:4] <- -4    # tache sous tp sans ombre : rejetée
#' ratio[10, 10] <- -6       # ombre isolée : gardée
#' ratio[7, 7] <- NA         # pixel sans ratio
#' s <- rcr_segment(ratio)
#' s$seuils_db
#' s$zone
#'
#' \donttest{
#' # Avant / après la segmentation
#' op <- par(mfrow = c(1, 2))
#' image(t(ratio[nrow(ratio):1, ]), main = "Ratio minimal (dB)", axes = FALSE)
#' image(t(s$detection[nrow(ratio):1, ]), main = "Détection", axes = FALSE)
#' par(op)
#' }
#'
#' @export
rcr_segment <- function(ratio_min_db, parametres = parametres_sufosat()) {
  p <- valide_parametres(parametres)
  ratio <- valide_ratio(ratio_min_db)
  s <- seuils_db(p)

  valide <- !is.na(ratio)
  graine <- valide & ratio < s[["ts"]]
  zone_tp <- valide & ratio <= s[["tp"]]

  racine <- etiquette_composantes(zone_tp, p$connexite)

  n <- length(ratio)
  garde <- logical(n)
  garde[racine[graine]] <- TRUE
  detection <- zone_tp & garde[racine]

  # Identifiants 1..K dans l'ordre du premier pixel (colonne par colonne) :
  # la racine d'une composante est son plus petit indice.
  zone <- rep(NA_integer_, n)
  racines_gardees <- which(garde)
  zone[detection] <- match(racine[detection], racines_gardees)

  forme <- function(v) {
    m <- matrix(v, nrow = nrow(ratio), ncol = ncol(ratio))
    dimnames(m) <- dimnames(ratio)
    m
  }
  list(
    detection = forme(detection),
    zone = forme(zone),
    graine = forme(graine),
    seuils_db = s,
    parametres = p
  )
}

# Vérifie l'entrée de rcr_segment() et rend la matrice du ratio.
valide_ratio <- function(x) {
  if (is.list(x) && !is.data.frame(x)) {
    if (!"ratio_min_db" %in% names(x)) {
      stop(
        "`ratio_min_db` doit être une matrice numérique ou un résultat de ",
        "rcr_compute() ou rcr_combine_orbites().",
        call. = FALSE
      )
    }
    x <- x$ratio_min_db
  }
  if (is.matrix(x) && is.logical(x) && all(is.na(x))) {
    storage.mode(x) <- "double"
  }
  if (!is.matrix(x) || !is.numeric(x)) {
    stop("`ratio_min_db` doit être une matrice numérique (en dB).", call. = FALSE)
  }
  if (any(is.infinite(x))) {
    stop("`ratio_min_db` ne doit pas contenir de valeur infinie.", call. = FALSE)
  }
  x
}

# Étiquette les composantes connexes des pixels TRUE de la matrice logique
# `masque` (sans NA), avec 4 ou 8 voisins. Rend un vecteur d'entiers de
# longueur length(masque) : pour un pixel du masque, l'indice (colonne par
# colonne) du plus petit pixel de sa composante ; pour les autres, leur propre
# indice (sans signification).
#
# Union-find vectorisé : parent[i] <= i à tout moment (pas de cycle) ; à
# chaque tour, la racine la plus grande de chaque arête est accrochée à la
# plus petite (la plus petite proposition l'emporte), puis les chemins sont
# compressés par sauts de pointeurs. On s'arrête quand toutes les arêtes
# relient deux pixels de même racine.
etiquette_composantes <- function(masque, connexite) {
  nr <- nrow(masque)
  nc <- ncol(masque)
  n <- nr * nc
  parent <- seq_len(n)
  if (n == 0L || !any(masque)) {
    return(parent)
  }
  idx <- matrix(seq_len(n), nr, nc)

  # Arêtes entre deux pixels du masque, chacune une seule fois.
  arete <- function(lignes_a, colonnes_a, lignes_b, colonnes_b) {
    m <- masque[lignes_a, colonnes_a, drop = FALSE] &
      masque[lignes_b, colonnes_b, drop = FALSE]
    list(
      a = idx[lignes_a, colonnes_a, drop = FALSE][m],
      b = idx[lignes_b, colonnes_b, drop = FALSE][m]
    )
  }
  tout_l <- seq_len(nr)
  tout_c <- seq_len(nc)
  haut <- seq_len(nr - 1L)          # lignes 1..nr-1
  bas <- haut + 1L                  # lignes 2..nr
  gauche <- seq_len(nc - 1L)
  droite <- gauche + 1L
  aretes <- list(
    arete(haut, tout_c, bas, tout_c),     # voisin du dessous
    arete(tout_l, gauche, tout_l, droite) # voisin de droite
  )
  if (connexite == 8L) {
    aretes <- c(aretes, list(
      arete(haut, gauche, bas, droite),   # diagonale bas-droite
      arete(bas, gauche, haut, droite)    # diagonale haut-droite
    ))
  }
  a <- unlist(lapply(aretes, `[[`, "a"), use.names = FALSE)
  b <- unlist(lapply(aretes, `[[`, "b"), use.names = FALSE)

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
    # Affectation par ordre décroissant : la dernière, donc la plus petite
    # racine proposée, l'emporte.
    o <- order(basse, decreasing = TRUE)
    parent[haute[o]] <- basse[o]
    parent <- compresse(parent)
  }
  parent
}
