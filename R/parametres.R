#' Réglages de la méthode SUFOSAT
#'
#' Rassemble, dans un seul objet validé, les réglages partagés par toutes les
#' étapes de la détection. Chaque défaut porte sa source, relevée dans
#' `docs/referentiels/parametres-sufosat.md` (mission 001) : M24 = Mermoz et al.
#' (2024), IEEE JSTARS 17, doi:10.1109/JSTARS.2024.3429012 (pages du manuscrit
#' HAL) ; B18 = Bouvet et al. (2018), Remote Sensing 10(8), 1250,
#' doi:10.3390/rs10081250.
#'
#' Les défauts dits **provisoires** répondent à un point que l'article ne
#' précise pas ; ils ont été fixés par décision du 2026-11-22 et **gèlent au
#' jalon 2** (comparaison à la carte SUFOSAT v3.0.1).
#'
#' @param polarisation Polarisation des images, `"VH"` ou `"VV"`. Défaut
#'   `"VH"` : M24, § II-B.1, p. 13746 (B18 utilise `"VV"`).
#' @param xa Nombre d'images après la date pour la moyenne Ma du ratio. Défaut
#'   3 : M24, § II-D.1, p. 13747 ; B18, § 2.3.2, p. 10. Pour l'exprimer en
#'   jours, voir [xa_en_jours()].
#' @param xb Nombre d'images avant la date pour la moyenne Mb ; `Inf` pour
#'   toutes les images antérieures. Défaut `Inf` : B18, § 2.3.2, p. 10 ; non
#'   précisé dans M24. **Provisoire, gèle au jalon 2.** Sert au ratio de
#'   **détection** (`ratio_min_db` de [rcr_compute()]).
#' @param xb_date Nombre d'images avant la date pour la moyenne Mb du ratio
#'   qui sert à **dater** la coupe ; `Inf` pour toutes les images
#'   antérieures. Entier au moins égal à 1, ou `Inf`. La détection reste
#'   calculée avec `xb` ; la date retenue est celle du minimum du ratio calculé
#'   avec `xb_date` (voir [rcr_compute()], section « Date retenue »). Défaut 5 :
#'   non précisé dans M24 ni B18. **Provisoire : simulation
#'   `docs/analyses/precision-date.md` (mission 008 ; fenêtre 3, chute de
#'   -6 dB, cadence 12 j), 96,4 % de dates exactes contre 15,6 % à
#'   `xb = Inf` ; repli 10 ; gèle au jalon 2** (mesure sur données réelles).
#'   Avec `xb_date = xb`, la date est celle du ratio de détection (comportement
#'   d'avant la mission 010 si `xb = xb_date = Inf`).
#' @param regle_date Règle qui donne la date de coupe d'un pixel détecté :
#'   `"premiere_sous_seuil"` (défaut) ou `"minimum"`. Avec
#'   `"premiere_sous_seuil"` (règle R2 de `docs/analyses/regles-de-date.md`,
#'   mission 027), la date est la **première date** où l'une quelconque des
#'   orbites a un ratio de datation (calculé avec `xb_date`) au plus égal à
#'   `seuil_datation_db` ; un pixel détecté sans aucun passage sous ce seuil
#'   garde la date de la règle `"minimum"` (repli). Avec `"minimum"` (règle
#'   d'avant la mission 030, R0), la date est celle du minimum du ratio de
#'   datation de la seule orbite retenue par la détection. La règle ne change
#'   ni le ratio de détection ni les pixels détectés. Défaut décidé par Pascal
#'   le 2026-11-24 ; **provisoire, gèle au jalon 2** (choix du package, non
#'   précisé dans M24 : « la date correspondant au RCR le plus bas »).
#' @param seuil_datation_db Seuil du ratio de datation, en dB (strictement
#'   négatif), pour la règle `"premiere_sous_seuil"`. `NULL` (défaut) : le seuil
#'   de détection effectif, `facteur_seuil * tp_db` (-3,45 dB), calculé à la
#'   construction ; la valeur est ensuite fixe. Réglage distinct du seuil de
#'   détection : le changer ne change pas la détection. **Provisoire, gèle au
#'   jalon 2.**
#' @param facteur_seuil Facteur multiplicatif appliqué à `ts_db` et `tp_db`.
#'   Défaut 1,15 : M24, § III-A, p. 13750 (plage étudiée 0,8 à 1,2).
#' @param ts_db Seuil des ombres radar, en dB, avant facteur. Défaut -4,5 :
#'   B18, § 2.3.2, p. 11, repris par M24, § II-D.1, p. 13748.
#' @param tp_db Seuil des zones modérément négatives, en dB, avant facteur.
#'   Défaut -3 : B18, § 2.3.3, p. 12, repris par M24, § II-D.1, p. 13748.
#'   La règle `ts_db < tp_db` (ombres plus sombres que les coupes) est une
#'   règle de cohérence du package, **non sourcée** : aucun des deux articles
#'   ne l'écrit comme contrainte.
#' @param combinaison_orbites Combinaison des ratios des orbites ascendante et
#'   descendante. Seule valeur permise : `"minimum"` (par pixel, l'orbite au
#'   ratio le plus bas donne la détection et sa date). Non précisé dans M24
#'   (p. 13748, « mosaicked ») ; B18, § 2.3.2, p. 11. **Provisoire, gèle au
#'   jalon 2.**
#' @param connexite Voisinage de la croissance de région, 4 ou 8. Défaut 8 :
#'   non précisé dans M24 ni B18, réglage de départ. **Provisoire, gèle au
#'   jalon 2.**
#' @param surface_min_ha Surface minimale d'un objet détecté, en hectares.
#'   Défaut 0,1 : M24, § II-D.1, p. 13748.
#' @param fermeture Appliquer une fermeture morphologique après le retrait des
#'   petits objets. Défaut `TRUE` : M24, § II-D.1, p. 13748.
#' @param taille_fermeture Côté de l'élément structurant carré de la
#'   fermeture, en pixels (impair, au moins 1). Défaut 3 : non précisé dans
#'   M24, réglage de départ. **Provisoire, gèle au jalon 2.**
#' @param fenetre_filtre Côté de la fenêtre du filtre multitemporel de Quegan
#'   et Yu, en pixels (impair, au moins 1). Défaut 3 : M24, § II-B.1,
#'   p. 13746 ; B18, § 2.2.1, p. 4.
#' @param annee_noyau Année des images servant à calculer le noyau du filtre.
#'   Défaut 2018 : M24, § II-B.1, p. 13746.
#' @param seuil_tcd Couvert arborescent minimal (Tree Cover Density 2018),
#'   **en pourcentage (de 0 à 100)**, comme les valeurs du produit TCD.
#'   Défaut 10 : M24, § II-D.1, p. 13747. Attention : `seuil_feu`, lui, est
#'   une fraction.
#' @param seuil_feu Part de la surface d'un objet brûlée (EFFIS) à partir de
#'   laquelle il est retiré, **en fraction (de 0 exclu à 1)**, et non en
#'   pourcentage. Défaut 0,75 (soit 75 %) : M24, § II-D.1, p. 13748.
#' @param capteurs Capteurs utilisés, sous forme de liste nommée par la date
#'   de début (`"AAAA-MM-JJ"`, dates croissantes) de chaque période ; une
#'   période court jusqu'à la veille de la suivante. Défaut :
#'   [capteurs_sufosat()], `"S1A"` depuis le 2014-04-03 puis
#'   `c("S1C", "S1D")` depuis le 2026-06-30. M24, § II-B.1, p. 13746 pour 1A
#'   seul ; fin de 1A le 29 juin 2026 : ESA (brief, arbitrage n° 2). La date
#'   du 2014-04-03 n'est pas dans la table de la mission 001 : **Provisoire :
#'   date de lancement de Sentinel-1A, à relever par l'acquereur ; gèle au
#'   jalon 2.**
#' @param source_neige Produit du masque neige. Défaut `"MOD10A1"` : M24,
#'   Table I, p. 13744 et § II-D.1, p. 13748 ; fin de Terra annoncée, autre
#'   source possible.
#'
#' @return Un objet de classe `parametres_sufosat` (une liste nommée).
#'
#' @seealso [seuils_db()], [capteurs_a_la_date()], [xa_en_jours()].
#'
#' @examples
#' p <- parametres_sufosat()
#' p
#' seuils_db(p)
#' seuils_db(parametres_sufosat(facteur_seuil = 1))
#'
#' @export
parametres_sufosat <- function(polarisation = "VH",
                               xa = 3L,
                               xb = Inf,
                               xb_date = 5L,
                               regle_date = "premiere_sous_seuil",
                               seuil_datation_db = NULL,
                               facteur_seuil = 1.15,
                               ts_db = -4.5,
                               tp_db = -3,
                               combinaison_orbites = "minimum",
                               connexite = 8L,
                               surface_min_ha = 0.1,
                               fermeture = TRUE,
                               taille_fermeture = 3L,
                               fenetre_filtre = 3L,
                               annee_noyau = 2018L,
                               seuil_tcd = 10,
                               seuil_feu = 0.75,
                               capteurs = capteurs_sufosat(),
                               source_neige = "MOD10A1") {
  # Seuil de datation par défaut : le seuil de détection effectif (tp), si les
  # deux réglages qui le donnent sont valides ; sinon la validation les refuse.
  if (is.null(seuil_datation_db) && est_scalaire_num(facteur_seuil) &&
      est_scalaire_num(tp_db)) {
    seuil_datation_db <- facteur_seuil * tp_db
  }
  p <- list(
    polarisation = polarisation,
    xa = xa,
    xb = xb,
    xb_date = xb_date,
    regle_date = regle_date,
    seuil_datation_db = seuil_datation_db,
    facteur_seuil = facteur_seuil,
    ts_db = ts_db,
    tp_db = tp_db,
    combinaison_orbites = combinaison_orbites,
    connexite = connexite,
    surface_min_ha = surface_min_ha,
    fermeture = fermeture,
    taille_fermeture = taille_fermeture,
    fenetre_filtre = fenetre_filtre,
    annee_noyau = annee_noyau,
    seuil_tcd = seuil_tcd,
    seuil_feu = seuil_feu,
    capteurs = capteurs,
    source_neige = source_neige
  )
  class(p) <- c("parametres_sufosat", "list")
  p <- valide_parametres(p)
  p
}

#' @rdname parametres_sufosat
#' @export
capteurs_sufosat <- function() {
  list("2014-04-03" = "S1A", "2026-06-30" = c("S1C", "S1D"))
}

#' Seuils effectifs de la segmentation, en dB
#'
#' Multiplie les seuils `ts_db` et `tp_db` par `facteur_seuil` (M24, § II-D.1,
#' p. 13748 et § III-A, p. 13750). Le ratio de changement radar auquel ces
#' seuils s'appliquent est le rapport des moyennes **linéaires** de la
#' rétrodiffusion (après puis avant la date), exprimé en dB : `10 * log10(Ma /
#' Mb)`, voir [lineaire_vers_db()]. Ce choix suit B18 (éq. 1, moyenne de
#' gamma0) ; aucun des deux articles ne l'écrit explicitement. **Provisoire,
#' gèle au jalon 2.**
#'
#' @param parametres Un objet créé par [parametres_sufosat()].
#'
#' @return Un vecteur numérique nommé `c(ts = , tp = )`, en dB, non arrondi
#'   (par défaut -5,175 et -3,45).
#'
#' @examples
#' seuils_db(parametres_sufosat())
#'
#' @export
seuils_db <- function(parametres) {
  p <- valide_parametres(parametres)
  c(ts = p$facteur_seuil * p$ts_db, tp = p$facteur_seuil * p$tp_db)
}

#' Capteurs actifs à une date
#'
#' @param parametres Un objet créé par [parametres_sufosat()].
#' @param date Vecteur de dates (`Date`, ou tout objet accepté par
#'   [as.Date()]).
#'
#' @return Une liste de même longueur que `date` ; chaque élément est le
#'   vecteur des capteurs actifs à cette date, ou `NA_character_` si la date
#'   est manquante ou antérieure à la première période.
#'
#' @examples
#' p <- parametres_sufosat()
#' capteurs_a_la_date(p, as.Date(c("2026-06-29", "2026-06-30")))
#'
#' @export
capteurs_a_la_date <- function(parametres, date) {
  p <- valide_parametres(parametres)
  date <- as.Date(date)
  debuts <- as.Date(names(p$capteurs))
  lapply(seq_along(date), function(i) {
    if (is.na(date[i])) {
      return(NA_character_)
    }
    k <- findInterval(as.numeric(date[i]), as.numeric(debuts))
    if (k == 0L) NA_character_ else p$capteurs[[k]]
  })
}

#' Exprimer Xa en jours
#'
#' `xa` est un nombre d'images. Sa durée dépend de l'intervalle entre deux
#' images d'une même orbite relative, qui change avec les capteurs : il n'y a
#' donc pas d'intervalle par défaut.
#'
#' @param parametres Un objet créé par [parametres_sufosat()].
#' @param intervalle_jours Intervalle entre deux images successives, en
#'   jours (nombre strictement positif).
#'
#' @return La durée couverte par `xa` images, en jours.
#'
#' @examples
#' xa_en_jours(parametres_sufosat(), intervalle_jours = 12)
#'
#' @export
xa_en_jours <- function(parametres, intervalle_jours) {
  p <- valide_parametres(parametres)
  if (!est_scalaire_num(intervalle_jours) || !is.finite(intervalle_jours) ||
      intervalle_jours <= 0) {
    stop("`intervalle_jours` doit \u00eatre un nombre strictement positif.", call. = FALSE)
  }
  p$xa * intervalle_jours
}

#' @export
print.parametres_sufosat <- function(x, ...) {
  s <- seuils_db(x)
  periodes <- vapply(
    seq_along(x$capteurs),
    function(i) paste0(paste(x$capteurs[[i]], collapse = "+"), " depuis le ", names(x$capteurs)[i]),
    character(1)
  )
  lignes <- c(
    "Param\u00e8tres SUFOSAT",
    paste0("  polarisation        : ", x$polarisation),
    paste0("  xa                  : ", x$xa, " images"),
    paste0("  xb                  : ", texte_xb(x$xb), " (d\u00e9tection)"),
    paste0("  xb_date             : ", texte_xb(x$xb_date), " (date de coupe)"),
    paste0("  regle_date          : ", x$regle_date),
    paste0("  seuil_datation_db   : ", format(x$seuil_datation_db), " dB"),
    paste0("  facteur_seuil       : ", format(x$facteur_seuil)),
    paste0("  ts_db, tp_db        : ", format(x$ts_db), " dB, ", format(x$tp_db), " dB (avant facteur)"),
    paste0("  ts, tp effectifs    : ", format(s[["ts"]]), " dB, ", format(s[["tp"]]), " dB"),
    paste0("  combinaison_orbites : ", x$combinaison_orbites),
    paste0("  connexite           : ", x$connexite),
    paste0("  surface_min_ha      : ", format(x$surface_min_ha), " ha"),
    paste0("  fermeture           : ", x$fermeture, " (", x$taille_fermeture, " x ", x$taille_fermeture, " pixels)"),
    paste0("  fenetre_filtre      : ", x$fenetre_filtre, " x ", x$fenetre_filtre, " pixels"),
    paste0("  annee_noyau         : ", x$annee_noyau),
    paste0("  seuil_tcd           : ", format(x$seuil_tcd), " %"),
    paste0("  seuil_feu           : ", format(x$seuil_feu)),
    paste0("  capteurs            : ", paste(periodes, collapse = " ; ")),
    paste0("  source_neige        : ", x$source_neige)
  )
  cat(lignes, sep = "\n")
  invisible(x)
}

texte_xb <- function(xb) {
  if (is.infinite(xb)) "Inf (toutes les images ant\u00e9rieures)" else paste(xb, "images")
}

# Validation ----------------------------------------------------------------

noms_parametres <- c(
  "polarisation", "xa", "xb", "xb_date", "regle_date", "seuil_datation_db", "facteur_seuil", "ts_db", "tp_db",
  "combinaison_orbites", "connexite", "surface_min_ha", "fermeture",
  "taille_fermeture", "fenetre_filtre", "annee_noyau", "seuil_tcd",
  "seuil_feu", "capteurs", "source_neige"
)

capteurs_connus <- c("S1A", "S1B", "S1C", "S1D")

# Vérifie un objet parametres_sufosat et le rend normalisé (entiers en
# integer). Appelée par le constructeur et par chaque fonction qui lit les
# réglages, pour refuser une liste modifiée à la main.
valide_parametres <- function(p) {
  if (!inherits(p, "parametres_sufosat") || !is.list(p)) {
    stop("`parametres` doit \u00eatre cr\u00e9\u00e9 par parametres_sufosat().", call. = FALSE)
  }
  if (!setequal(names(p), noms_parametres) || length(p) != length(noms_parametres)) {
    stop(
      "`parametres` doit contenir exactement les r\u00e9glages : ",
      paste(noms_parametres, collapse = ", "), ".",
      call. = FALSE
    )
  }

  choix(p$polarisation, "polarisation", c("VH", "VV"))
  p$xa <- entier(p$xa, "xa", min = 1L)
  p$xb <- entier_ou_inf(p$xb, "xb")
  p$xb_date <- entier_ou_inf(p$xb_date, "xb_date")
  if (!est_scalaire_num(p$facteur_seuil) || !is.finite(p$facteur_seuil) || p$facteur_seuil <= 0) {
    stop("`facteur_seuil` doit \u00eatre un nombre strictement positif.", call. = FALSE)
  }
  for (nom in c("ts_db", "tp_db")) {
    v <- p[[nom]]
    if (!est_scalaire_num(v) || !is.finite(v) || v >= 0) {
      stop("`", nom, "` doit \u00eatre un nombre strictement n\u00e9gatif (en dB).", call. = FALSE)
    }
  }
  if (p$ts_db >= p$tp_db) {
    stop(
      "`ts_db` doit \u00eatre inf\u00e9rieur \u00e0 `tp_db` ",
      "(les ombres radar sont plus sombres que les coupes).",
      call. = FALSE
    )
  }
  choix(p$regle_date, "regle_date", c("premiere_sous_seuil", "minimum"))
  v <- p$seuil_datation_db
  if (!est_scalaire_num(v) || !is.finite(v) || v >= 0) {
    stop("`seuil_datation_db` doit \u00eatre un nombre strictement n\u00e9gatif (en dB).", call. = FALSE)
  }
  choix(p$combinaison_orbites, "combinaison_orbites", "minimum")
  p$connexite <- entier(p$connexite, "connexite", min = 4L)
  if (!p$connexite %in% c(4L, 8L)) {
    stop("`connexite` doit valoir 4 ou 8.", call. = FALSE)
  }
  if (!est_scalaire_num(p$surface_min_ha) || !is.finite(p$surface_min_ha) || p$surface_min_ha < 0) {
    stop("`surface_min_ha` doit \u00eatre un nombre positif ou nul (en hectares).", call. = FALSE)
  }
  if (!is.logical(p$fermeture) || length(p$fermeture) != 1L || is.na(p$fermeture)) {
    stop("`fermeture` doit valoir TRUE ou FALSE.", call. = FALSE)
  }
  p$taille_fermeture <- entier_impair(p$taille_fermeture, "taille_fermeture")
  p$fenetre_filtre <- entier_impair(p$fenetre_filtre, "fenetre_filtre")
  p$annee_noyau <- entier(p$annee_noyau, "annee_noyau")
  if (!est_scalaire_num(p$seuil_tcd) || !is.finite(p$seuil_tcd) ||
      p$seuil_tcd < 0 || p$seuil_tcd > 100) {
    stop("`seuil_tcd` doit \u00eatre un pourcentage entre 0 et 100.", call. = FALSE)
  }
  if (!est_scalaire_num(p$seuil_feu) || !is.finite(p$seuil_feu) ||
      p$seuil_feu <= 0 || p$seuil_feu > 1) {
    stop("`seuil_feu` doit \u00eatre une part entre 0 (exclu) et 1.", call. = FALSE)
  }
  valide_capteurs(p$capteurs)
  if (!is.character(p$source_neige) || length(p$source_neige) != 1L ||
      is.na(p$source_neige) || !nzchar(p$source_neige)) {
    stop("`source_neige` doit \u00eatre une cha\u00eene de caract\u00e8res non vide.", call. = FALSE)
  }
  p
}

valide_capteurs <- function(capteurs) {
  message_forme <- paste0(
    "`capteurs` doit \u00eatre une liste nomm\u00e9e par la date de d\u00e9but ",
    "(\"AAAA-MM-JJ\") de chaque p\u00e9riode, par exemple ",
    "list(\"2014-04-03\" = \"S1A\", \"2026-06-30\" = c(\"S1C\", \"S1D\"))."
  )
  if (!is.list(capteurs) || length(capteurs) < 1L || is.null(names(capteurs))) {
    stop(message_forme, call. = FALSE)
  }
  debuts <- as.Date(names(capteurs), format = "%Y-%m-%d")
  if (anyNA(debuts) || any(format(debuts) != names(capteurs))) {
    stop(message_forme, call. = FALSE)
  }
  if (is.unsorted(debuts, strictly = TRUE)) {
    stop("Les dates de d\u00e9but de `capteurs` doivent \u00eatre strictement croissantes.", call. = FALSE)
  }
  for (k in seq_along(capteurs)) {
    v <- capteurs[[k]]
    if (!is.character(v) || length(v) < 1L || anyNA(v) || anyDuplicated(v) ||
        !all(v %in% capteurs_connus)) {
      stop(
        "Capteurs invalides pour la p\u00e9riode du ", names(capteurs)[k],
        " : valeurs permises ", paste(capteurs_connus, collapse = ", "), ".",
        call. = FALSE
      )
    }
  }
  invisible(capteurs)
}

est_scalaire_num <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

choix <- function(x, nom, permis) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !x %in% permis) {
    stop(
      "`", nom, "` doit valoir ",
      paste0("\"", permis, "\"", collapse = " ou "), ".",
      call. = FALSE
    )
  }
  x
}

entier <- function(x, nom, min = NULL) {
  ok <- est_scalaire_num(x) && is.finite(x) && x == floor(x) &&
    (is.null(min) || x >= min)
  if (!ok) {
    stop(
      "`", nom, "` doit \u00eatre un nombre entier",
      if (!is.null(min)) paste0(" au moins \u00e9gal \u00e0 ", min),
      ".",
      call. = FALSE
    )
  }
  as.integer(x)
}

# Entier au moins égal à 1, ou Inf ; rendu en double (pour garder Inf).
entier_ou_inf <- function(x, nom) {
  if (!est_scalaire_num(x) || (!identical(as.numeric(x), Inf) &&
      (!is.finite(x) || x < 1 || x != floor(x)))) {
    stop("`", nom, "` doit \u00eatre un entier au moins \u00e9gal \u00e0 1, ou Inf.", call. = FALSE)
  }
  as.numeric(x)
}

entier_impair <- function(x, nom) {
  ok <- est_scalaire_num(x) && is.finite(x) && x == floor(x) && x >= 1 && x %% 2 == 1
  if (!ok) {
    stop("`", nom, "` doit \u00eatre un entier impair au moins \u00e9gal \u00e0 1 (en pixels).", call. = FALSE)
  }
  as.integer(x)
}
