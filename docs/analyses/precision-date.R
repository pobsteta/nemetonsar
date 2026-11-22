# Mission 008 : précision de la date de coupe sur séries synthétiques
# ---------------------------------------------------------------------------
# Analyste, 2026-11-22. Script reproductible (graine fixée), à lancer depuis
# n'importe quel dossier :
#
#   Rscript docs/analyses/precision-date.R [dossier_des_figures]
#
# Tous les chiffres produits ici sont des chiffres de SIMULATION (forêt
# homogène, speckle gamma indépendant d'un pixel à l'autre et d'une date à
# l'autre, pas de saisonnalité). Ce ne sont pas des mesures sur données
# réelles.
#
# Chaîne testée : s1_filter_multitemp() (fenêtre 1 = pas de filtre)
#   -> rcr_compute() -> rcr_segment(), avec les défauts du package sauf `xb`
#   et `fenetre_filtre`.
# Le script ne modifie pas le package : il le charge par pkgload::load_all().
# ---------------------------------------------------------------------------

racine <- "/home/user/nemetonsar"
args <- commandArgs(trailingOnly = TRUE)
dossier_fig <- if (length(args) >= 1) args[1] else tempdir()
dir.create(dossier_fig, showWarnings = FALSE, recursive = TRUE)

suppressMessages(pkgload::load_all(racine, quiet = TRUE))
debut_chrono <- Sys.time()

# --- Plan de simulation -----------------------------------------------------
GRAINE     <- 20261122L
NR         <- 60L          # lignes de la grille
NC         <- 120L         # colonnes : 1..60 coupées, 61..120 forêt intacte
COL_COUPE  <- 1:60
MARGE      <- 3L           # colonnes écartées de part et d'autre de la lisière
SIGMA0     <- 0.05         # rétrodiffusion linéaire de la forêt (≈ -13 dB)
ENL        <- 4.4          # B18, § 2.2.1, p. 4 (avant filtre) : hypothèse
DATE_COUPE <- as.Date("2020-06-15")  # coupe entre deux acquisitions
DEBUT      <- as.Date("2018-01-03")
FIN        <- as.Date("2021-12-31")

facteurs <- list(
  cadence   = c(12L, 6L),
  amplitude = c(-3, -4.5, -6),           # dB
  fenetre   = c(1L, 3L, 5L),
  xb        = c(Inf, 5, 10, 20)
)

# Pixels évalués : bloc coupé loin de la lisière, forêt intacte loin de la
# lisière (le filtre et la segmentation agissent sur quelques pixels autour).
cols_eval_coupe  <- seq(1L, max(COL_COUPE) - MARGE)
cols_eval_intact <- seq(max(COL_COUPE) + 1L + MARGE, NC)
masque_coupe  <- matrix(FALSE, NR, NC); masque_coupe[, cols_eval_coupe] <- TRUE
masque_intact <- matrix(FALSE, NR, NC); masque_intact[, cols_eval_intact] <- TRUE

# --- Outils -----------------------------------------------------------------
# Intervalle de Wilson à 95 % pour une proportion x / n.
wilson <- function(x, n, z = 1.96) {
  if (n == 0) return(c(NA_real_, NA_real_))
  p <- x / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  demi <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(max(0, centre - demi), min(1, centre + demi))
}

# Série complète du RCR (dB) de chaque pixel, même définition que
# rcr_compute() (pas de NA ici) : sert à la règle de date alternative et au
# profil moyen. Contrôlée plus bas contre rcr_compute().
rcr_serie <- function(serie, dates, xa = 3L, xb = Inf, annee_noyau = 2018L) {
  d <- dim(serie); nt <- d[3]; npix <- d[1] * d[2]
  x <- matrix(serie, npix, nt)
  cs <- cbind(0, t(apply(x, 1, cumsum)))        # cs[, k + 1] = somme des k premières
  admise <- dates >= as.Date(sprintf("%d-01-01", annee_noyau + 1L))
  r <- matrix(NA_real_, npix, nt)
  for (i in which(admise)) {
    if (i + xa > nt) next
    nb <- if (is.infinite(xb)) i else min(i, xb)
    mb <- (cs[, i + 1] - cs[, i + 1 - nb]) / nb
    ma <- (cs[, i + 1 + xa] - cs[, i + 1]) / xa
    r[, i] <- 10 * log10(ma / mb)
  }
  r
}

# Règle de date alternative (hors package) : première date d_i dont le ratio
# passe sous un seuil ; date rendue d_(i+1) comme le package ; à défaut de
# franchissement, la date du minimum.
indice_premier_franchissement <- function(r, seuil) {
  sous <- !is.na(r) & r < seuil
  premier <- max.col(sous, ties.method = "first")
  aucun <- rowSums(sous) == 0
  premier[aucun] <- NA_integer_
  premier
}

pct <- function(x) sprintf("%.1f", 100 * x)
ic_txt <- function(x, n) {
  w <- wilson(x, n)
  sprintf("[%s ; %s]", pct(w[1]), pct(w[2]))
}

# --- Boucle de simulation ---------------------------------------------------
set.seed(GRAINE)
p_def <- parametres_sufosat()
seuils <- seuils_db(p_def)               # ts = -5,175 ; tp = -3,45 dB
resultats <- list()
profils <- list()
erreurs_signees <- list()
controle_max_ecart <- 0

for (cad in facteurs$cadence) {
  dates <- seq(DEBUT, FIN, by = cad)
  nt <- length(dates)
  codes <- date_vers_yyddd(dates)
  k1 <- which(dates > DATE_COUPE)[1]     # première image qui montre la chute
  # Speckle commun à toutes les amplitudes, fenêtres et xb d'une cadence
  # (plan apparié : les écarts entre réglages ne viennent pas du tirage).
  speckle <- array(rgamma(NR * NC * nt, shape = ENL, rate = ENL), c(NR, NC, nt))

  for (amp in facteurs$amplitude) {
    serie <- array(SIGMA0, c(NR, NC, nt))
    serie[, COL_COUPE, k1:nt] <- SIGMA0 * db_vers_lineaire(amp)
    serie <- serie * speckle

    for (w in facteurs$fenetre) {
      p_f <- parametres_sufosat(fenetre_filtre = w)
      filtree <- if (w == 1L) serie else s1_filter_multitemp(serie, dates, p_f)

      for (xb in facteurs$xb) {
        p <- parametres_sufosat(fenetre_filtre = w, xb = xb)
        r <- rcr_compute(filtree, dates, p)
        s <- rcr_segment(r, p)

        idx <- matrix(match(r$date_min, codes), NR, NC)   # indice de d_(i+1)
        err <- idx - k1                                    # en acquisitions
        e_c <- err[masque_coupe]
        n_c <- length(e_c); n_i <- sum(masque_intact)
        graine_c <- (r$ratio_min_db < seuils[["ts"]])[masque_coupe]
        det_c <- s$detection[masque_coupe]
        graine_i <- (r$ratio_min_db < seuils[["ts"]])[masque_intact]
        det_i <- s$detection[masque_intact]

        # Règle alternative : premier franchissement de ts (série du RCR).
        rs <- rcr_serie(filtree, dates, xb = xb)
        # Contrôle : le minimum de la série recalculée = celui du package.
        mins <- apply(rs, 1, min, na.rm = TRUE)
        controle_max_ecart <- max(controle_max_ecart,
                                  max(abs(mins - as.vector(r$ratio_min_db))))
        i_ts <- indice_premier_franchissement(rs, seuils[["ts"]])
        i_alt <- ifelse(is.na(i_ts), idx - 1L, i_ts) + 1L
        e_alt <- (i_alt - k1)[as.vector(masque_coupe)]
        # Variante : premier franchissement de tp.
        i_tp <- indice_premier_franchissement(rs, seuils[["tp"]])
        i_alt2 <- ifelse(is.na(i_tp), idx - 1L, i_tp) + 1L
        e_alt2 <- (i_alt2 - k1)[as.vector(masque_coupe)]

        n_det <- sum(det_c)
        resultats[[length(resultats) + 1]] <- data.frame(
          cadence = cad, amplitude = amp, fenetre = w, xb = xb,
          n_coupe = n_c, n_intact = n_i,
          n_eff_coupe = floor(n_c / w^2),
          exacte = sum(e_c == 0), a1 = sum(abs(e_c) <= 1), a2 = sum(abs(e_c) <= 2),
          biais_median = median(e_c), erreur_moy_abs_j = mean(abs(e_c)) * cad,
          tardive = sum(e_c > 0), precoce = sum(e_c < 0),
          n_det = n_det,
          exacte_det = sum(e_c[det_c] == 0), a1_det = sum(abs(e_c[det_c]) <= 1),
          graine = sum(graine_c), detecte = n_det,
          fa_graine = sum(graine_i), fa_detecte = sum(det_i),
          intact_sous_tp = sum((r$ratio_min_db <= seuils[["tp"]])[masque_intact]),
          q01_intact = unname(quantile(r$ratio_min_db[masque_intact], 0.01)),
          alt_exacte = sum(e_alt == 0), alt_a1 = sum(abs(e_alt) <= 1),
          alt_precoce = sum(e_alt < 0),
          alt2_exacte = sum(e_alt2 == 0), alt2_a1 = sum(abs(e_alt2) <= 1),
          alt2_precoce = sum(e_alt2 < 0)
        )
        if (amp == -6) {
          erreurs_signees[[sprintf("c%d_w%d_xb%s", cad, w, xb)]] <- e_c
        }
        if (amp == -6 && w == 3L) {
          # Profil moyen du RCR des pixels coupés autour de la coupe.
          fen <- (k1 - 6):(k1 + 12)
          profils[[sprintf("c%d_xb%s", cad, xb)]] <- data.frame(
            j = fen - (k1 - 1L),           # 0 = d_k (dernière avant la chute)
            moyenne = colMeans(rs[as.vector(masque_coupe), fen]),
            q10 = apply(rs[as.vector(masque_coupe), fen], 2, quantile, 0.1),
            q90 = apply(rs[as.vector(masque_coupe), fen], 2, quantile, 0.9)
          )
        }
      }
    }
  }
}
tab <- do.call(rbind, resultats)

# --- Sorties -----------------------------------------------------------------
cat("Graine :", GRAINE, " | grille", NR, "x", NC,
    " | ENL", ENL, " | sigma0", SIGMA0, " | coupe après le", format(DATE_COUPE), "\n")
cat("Seuils effectifs (dB) : ts =", seuils[["ts"]], " tp =", seuils[["tp"]], "\n")
cat("Contrôle série recalculée vs rcr_compute() : écart max du minimum =",
    signif(controle_max_ecart, 3), "dB\n\n")

ligne_md <- function(v) cat("| ", paste(v, collapse = " | "), " |\n", sep = "")
xb_txt <- function(x) ifelse(is.infinite(x), "Inf", as.character(x))

cat("## Table complète (pourcentages ; IC de Wilson 95 % sur n pixels)\n")
cat("Avec filtre, les pixels voisins partagent leurs valeurs : l'IC sur n est\n",
    "trop étroit ; l'IC sur n_eff = n / fenetre^2 est l'ordre de grandeur prudent.\n\n")
ligne_md(c("cad. (j)", "chute (dB)", "fen.", "xb", "n coupe", "exacte % [IC]", "IC sur n_eff = n / fen.^2",
           "±1 % [IC]", "±2 %", "biais méd. (acq.)", "err. moy. (j)",
           "graine %", "détecté %", "exacte parmi détectés %",
           "FA graine % (n intact)", "intact <= tp %", "FA détecté %", "q1 % RCR min intact (dB)",
           "ts-1er exacte %", "ts-1er ±1 %", "ts-1er précoce %",
           "tp-1er exacte %", "tp-1er précoce %"))
ligne_md(rep("---", 23))
for (k in seq_len(nrow(tab))) {
  t <- tab[k, ]
  ligne_md(c(t$cadence, t$amplitude, t$fenetre, xb_txt(t$xb), t$n_coupe,
             paste(pct(t$exacte / t$n_coupe), ic_txt(t$exacte, t$n_coupe)),
             paste(ic_txt(round(t$exacte / t$n_coupe * t$n_eff_coupe), t$n_eff_coupe),
                   sprintf("(n_eff %d)", t$n_eff_coupe)),
             paste(pct(t$a1 / t$n_coupe), ic_txt(t$a1, t$n_coupe)),
             pct(t$a2 / t$n_coupe), t$biais_median, sprintf("%.1f", t$erreur_moy_abs_j),
             pct(t$graine / t$n_coupe), pct(t$detecte / t$n_coupe),
             if (t$n_det > 0) pct(t$exacte_det / t$n_det) else "-",
             sprintf("%s (%d)", pct(t$fa_graine / t$n_intact), t$n_intact),
             pct(t$intact_sous_tp / t$n_intact),
             pct(t$fa_detecte / t$n_intact), sprintf("%.2f", t$q01_intact),
             pct(t$alt_exacte / t$n_coupe), pct(t$alt_a1 / t$n_coupe),
             pct(t$alt_precoce / t$n_coupe),
             pct(t$alt2_exacte / t$n_coupe), pct(t$alt2_precoce / t$n_coupe)))
}

cat("\n## Distribution des erreurs signées (acquisitions), chute -6 dB\n\n")
for (nm in names(erreurs_signees)) {
  e <- erreurs_signees[[nm]]
  cat(sprintf("%-16s P(-1)=%5s P(0)=%5s P(+1)=%5s P(+2)=%5s P(>+2)=%5s P(<-1)=%5s\n", nm,
              pct(mean(e == -1)), pct(mean(e == 0)), pct(mean(e == 1)),
              pct(mean(e == 2)), pct(mean(e > 2)), pct(mean(e < -1))))
}

cat("\n## Profil moyen du RCR des pixels coupés (chute -6 dB, fenêtre 3)\n")
cat("j = 0 : d_k, dernière image avant la chute (minimum attendu ici)\n\n")
for (nm in names(profils)) {
  pr <- profils[[nm]]
  cat(nm, ":", paste(sprintf("j%+d=%.2f", pr$j, pr$moyenne)[pr$j >= -2 & pr$j <= 6],
                     collapse = " "), "\n")
}

# --- Contrôle : effet de la fin de série (cause n° 1) -------------------------
# Avec xb = Inf, le RCR reste au niveau de la chute jusqu'à la fin de la série :
# la date du minimum devrait dépendre du nombre d'images après la coupe.
cat("\n## Effet de la fin de série (cadence 12 j, chute -6 dB, fenêtre 3)\n\n")
ligne_md(c("fin de série", "xb", "n", "exacte % [IC]", "±1 % [IC]"))
ligne_md(rep("---", 5))
set.seed(GRAINE + 1L)
dates_c <- seq(DEBUT, FIN, by = 12L)
k1_c <- which(dates_c > DATE_COUPE)[1]
sp_c <- array(rgamma(NR * NC * length(dates_c), shape = ENL, rate = ENL),
              c(NR, NC, length(dates_c)))
for (fin in c("2020-12-31", "2021-06-30", "2021-12-31")) {
  garde <- dates_c <= as.Date(fin)
  dd <- dates_c[garde]
  se <- array(SIGMA0, c(NR, NC, length(dd)))
  se[, COL_COUPE, k1_c:length(dd)] <- SIGMA0 * db_vers_lineaire(-6)
  se <- se * sp_c[, , garde]
  fi <- s1_filter_multitemp(se, dd, parametres_sufosat(fenetre_filtre = 3L))
  for (xb in c(Inf, 5)) {
    r <- rcr_compute(fi, dd, parametres_sufosat(fenetre_filtre = 3L, xb = xb))
    e <- (match(r$date_min, date_vers_yyddd(dd)) - k1_c)[as.vector(masque_coupe)]
    ligne_md(c(fin, xb_txt(xb), length(e),
               paste(pct(mean(e == 0)), ic_txt(sum(e == 0), length(e))),
               paste(pct(mean(abs(e) <= 1)), ic_txt(sum(abs(e) <= 1), length(e)))))
  }
}

# --- Figures (PNG, hors dépôt) ----------------------------------------------
png(file.path(dossier_fig, "precision-date-erreurs.png"), width = 1400, height = 900, res = 130)
op <- par(mfrow = c(2, 4), mar = c(4, 4, 3, 1))
for (cad in facteurs$cadence) for (xb in facteurs$xb) {
  e <- erreurs_signees[[sprintf("c%d_w3_xb%s", cad, xb)]]
  e <- pmax(pmin(e, 8), -3)
  barplot(100 * table(factor(e, levels = -3:8)) / length(e), ylim = c(0, 100),
          names.arg = c("<=-3", -2:7, ">=8"), las = 2, col = "grey60",
          main = sprintf("cadence %d j, xb = %s", cad, xb_txt(xb)),
          xlab = "erreur (acquisitions)", ylab = "% des pixels coupes")
}
par(op); dev.off()

png(file.path(dossier_fig, "precision-date-profils.png"), width = 1400, height = 650, res = 130)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 3, 1))
couleurs <- c("black", "firebrick", "darkorange", "steelblue")
for (cad in facteurs$cadence) {
  plot(NA, xlim = c(-6, 12), ylim = c(-8, 1), xlab = "j (0 = d_k, derniere image avant la chute)",
       ylab = "RCR moyen (dB)", main = sprintf("Chute -6 dB, fenetre 3, cadence %d j", cad))
  abline(h = seuils, lty = 3); abline(v = 0, lty = 2)
  for (k in seq_along(facteurs$xb)) {
    pr <- profils[[sprintf("c%d_xb%s", cad, facteurs$xb[k])]]
    lines(pr$j, pr$moyenne, type = "b", pch = 19, col = couleurs[k])
  }
  legend("bottomright", legend = paste("xb =", xb_txt(facteurs$xb)), col = couleurs,
         lwd = 1, pch = 19, bty = "n")
}
par(op); dev.off()

cat("\nFigures écrites dans", dossier_fig, "\n")
cat("Durée :", format(round(difftime(Sys.time(), debut_chrono, units = "secs"), 1)), "\n")
