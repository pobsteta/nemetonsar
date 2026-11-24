test_that("les défauts sont ceux de la spec et de la table de la mission 001", {
  p <- parametres_sufosat()
  expect_s3_class(p, "parametres_sufosat")
  expect_identical(p$polarisation, "VH")
  expect_identical(p$xa, 3L)
  expect_identical(p$xb, Inf)
  expect_identical(p$xb_date, 5)
  expect_identical(p$facteur_seuil, 1.15)
  expect_identical(p$ts_db, -4.5)
  expect_identical(p$tp_db, -3)
  expect_identical(p$combinaison_orbites, "minimum")
  expect_identical(p$connexite, 8L)
  expect_identical(p$surface_min_ha, 0.1)
  expect_identical(p$fermeture, TRUE)
  expect_identical(p$taille_fermeture, 3L)
  expect_identical(p$fenetre_filtre, 3L)
  expect_identical(p$annee_noyau, 2018L)
  expect_identical(p$seuil_tcd, 10)
  expect_identical(p$seuil_feu, 0.75)
  expect_identical(p$source_neige, "MOD10A1")
  expect_identical(
    p$capteurs,
    list("2014-04-03" = "S1A", "2026-06-30" = c("S1C", "S1D"))
  )
})

test_that("les entiers donnés en double sont rangés en entiers", {
  p <- parametres_sufosat(xa = 2, connexite = 4, fenetre_filtre = 5, annee_noyau = 2019)
  expect_identical(p$xa, 2L)
  expect_identical(p$connexite, 4L)
  expect_identical(p$fenetre_filtre, 5L)
  expect_identical(p$annee_noyau, 2019L)
  expect_identical(parametres_sufosat(xb = 5L)$xb, 5)
  expect_identical(parametres_sufosat(xb_date = 10L)$xb_date, 10)
  expect_identical(parametres_sufosat(xb_date = Inf)$xb_date, Inf)
  expect_identical(parametres_sufosat(xb_date = 1)$xb_date, 1)
})

test_that("ts = 1,15 x -4,5 dB et tp = 1,15 x -3 dB, sans arrondi", {
  s <- seuils_db(parametres_sufosat())
  expect_named(s, c("ts", "tp"))
  expect_equal(s[["ts"]], 1.15 * -4.5)
  expect_equal(s[["tp"]], 1.15 * -3)
  expect_equal(unname(s), c(-5.175, -3.45))
})

test_that("le facteur de seuil est modifiable", {
  expect_equal(seuils_db(parametres_sufosat(facteur_seuil = 1)), c(ts = -4.5, tp = -3))
  # exemple de Mermoz et al. (2024), p. 13748 : facteur 1,1
  expect_equal(seuils_db(parametres_sufosat(facteur_seuil = 1.1)), c(ts = -4.95, tp = -3.3))
  # plage de sensibilité du critère 6 : 0,8 à 1,2 par pas de 0,05
  for (f in seq(0.8, 1.2, by = 0.05)) {
    expect_equal(seuils_db(parametres_sufosat(facteur_seuil = f)), c(ts = f * -4.5, tp = f * -3))
  }
})

test_that("un paramètre invalide est refusé avec un message clair", {
  expect_error(parametres_sufosat(facteur_seuil = 0), "`facteur_seuil`")
  expect_error(parametres_sufosat(facteur_seuil = -1), "`facteur_seuil`")
  expect_error(parametres_sufosat(facteur_seuil = NA_real_), "`facteur_seuil`")
  expect_error(parametres_sufosat(facteur_seuil = c(1, 1.15)), "`facteur_seuil`")
  expect_error(parametres_sufosat(facteur_seuil = "1.15"), "`facteur_seuil`")
  expect_error(parametres_sufosat(polarisation = "HH"), "`polarisation`")
  expect_error(parametres_sufosat(xa = 0), "`xa`")
  expect_error(parametres_sufosat(xa = 2.5), "`xa`")
  expect_error(parametres_sufosat(xb = 0), "`xb`")
  expect_error(parametres_sufosat(xb = 2.5), "`xb`")
  expect_error(parametres_sufosat(xb = -Inf), "`xb`")
  expect_error(parametres_sufosat(xb_date = 0), "`xb_date`")
  expect_error(parametres_sufosat(xb_date = 2.5), "`xb_date`")
  expect_error(parametres_sufosat(xb_date = -Inf), "`xb_date`")
  expect_error(parametres_sufosat(xb_date = NA_real_), "`xb_date`")
  expect_error(parametres_sufosat(xb_date = c(5, 10)), "`xb_date`")
  expect_error(parametres_sufosat(xb_date = "5"), "`xb_date`")
  expect_error(parametres_sufosat(ts_db = 1), "`ts_db`")
  expect_error(parametres_sufosat(tp_db = 0), "`tp_db`")
  expect_error(parametres_sufosat(ts_db = -3, tp_db = -4.5), "plus sombres")
  expect_error(parametres_sufosat(ts_db = -3, tp_db = -3), "plus sombres")
  expect_error(parametres_sufosat(combinaison_orbites = "moyenne"), "`combinaison_orbites`")
  expect_error(parametres_sufosat(connexite = 6), "`connexite`")
  expect_error(parametres_sufosat(surface_min_ha = -0.1), "`surface_min_ha`")
  expect_error(parametres_sufosat(fermeture = NA), "`fermeture`")
  expect_error(parametres_sufosat(fermeture = "oui"), "`fermeture`")
  expect_error(parametres_sufosat(taille_fermeture = 4), "`taille_fermeture`")
  expect_error(parametres_sufosat(taille_fermeture = 0), "`taille_fermeture`")
  expect_error(parametres_sufosat(fenetre_filtre = 2), "`fenetre_filtre`")
  expect_error(parametres_sufosat(annee_noyau = 2018.5), "`annee_noyau`")
  expect_error(parametres_sufosat(seuil_tcd = 150), "`seuil_tcd`")
  expect_error(parametres_sufosat(seuil_tcd = -1), "`seuil_tcd`")
  expect_error(parametres_sufosat(seuil_feu = 0), "`seuil_feu`")
  expect_error(parametres_sufosat(seuil_feu = 75), "`seuil_feu`")
  expect_error(parametres_sufosat(source_neige = ""), "`source_neige`")
  expect_error(parametres_sufosat(source_neige = NA_character_), "`source_neige`")
  # message de R lui-même (« unused argument » ou sa traduction) : il nomme l'argument
  expect_error(parametres_sufosat(inconnu = 1), "inconnu", class = "error")
})

test_that("les capteurs mal formés sont refusés", {
  expect_error(parametres_sufosat(capteurs = "S1A"), "`capteurs`")
  expect_error(parametres_sufosat(capteurs = list("S1A")), "`capteurs`")
  expect_error(parametres_sufosat(capteurs = list("2014/04/03" = "S1A")), "`capteurs`")
  expect_error(parametres_sufosat(capteurs = list("2014-02-30" = "S1A")), "`capteurs`")
  expect_error(
    parametres_sufosat(capteurs = list("2026-06-30" = "S1C", "2014-04-03" = "S1A")),
    "croissantes"
  )
  expect_error(parametres_sufosat(capteurs = list("2014-04-03" = "S2A")), "Capteurs invalides")
  expect_error(parametres_sufosat(capteurs = list("2014-04-03" = character(0))), "Capteurs invalides")
  expect_error(parametres_sufosat(capteurs = list("2014-04-03" = c("S1A", "S1A"))), "Capteurs invalides")
})

test_that("une liste modifiée à la main est refusée", {
  p <- parametres_sufosat()
  expect_error(seuils_db(unclass(p)), "parametres_sufosat\\(\\)")
  q <- p
  q$facteur_seuil <- -2
  expect_error(seuils_db(q), "`facteur_seuil`")
  q <- p
  q$facteur_seuil <- NULL
  expect_error(seuils_db(q), "exactement")
  q <- p
  q$en_trop <- 1
  expect_error(seuils_db(q), "exactement")
  q <- p
  q$xb_date <- NULL
  expect_error(seuils_db(q), "exactement")
  q <- p
  q$xb_date <- 0.5
  expect_error(seuils_db(q), "`xb_date`")
})

test_that("capteurs_a_la_date bascule de S1A à S1C + S1D le 30 juin 2026", {
  p <- parametres_sufosat()
  r <- capteurs_a_la_date(p, as.Date(c("2018-01-01", "2026-06-29", "2026-06-30", NA, "2010-01-01")))
  expect_identical(r, list("S1A", "S1A", c("S1C", "S1D"), NA_character_, NA_character_))
  expect_identical(capteurs_a_la_date(p, "2014-04-03"), list("S1A"))
  expect_identical(capteurs_a_la_date(p, as.Date(character(0))), list())
  # essai du critère 9 : 1A et 1C ensemble pendant le recouvrement
  essai <- parametres_sufosat(capteurs = list(
    "2014-04-03" = "S1A", "2025-04-01" = c("S1A", "S1C"), "2026-06-30" = c("S1C", "S1D")
  ))
  expect_identical(capteurs_a_la_date(essai, "2025-06-01"), list(c("S1A", "S1C")))
})

test_that("xa_en_jours multiplie xa par l'intervalle donné", {
  p <- parametres_sufosat()
  expect_identical(xa_en_jours(p, 12), 36)
  expect_identical(xa_en_jours(p, 6), 18)
  expect_identical(xa_en_jours(parametres_sufosat(xa = 1), 12), 12)
  expect_error(xa_en_jours(p), "intervalle_jours")
  expect_error(xa_en_jours(p, 0), "`intervalle_jours`")
  expect_error(xa_en_jours(p, NA_real_), "`intervalle_jours`")
})

test_that("l'affichage montre les valeurs du brief et les seuils effectifs", {
  sortie <- capture.output(print(parametres_sufosat()))
  expect_true(any(grepl("-5.175 dB, -3.45 dB", sortie, fixed = TRUE)))
  expect_true(any(grepl("S1A depuis le 2014-04-03 ; S1C+S1D depuis le 2026-06-30", sortie, fixed = TRUE)))
  expect_true(any(grepl("VH", sortie, fixed = TRUE)))
  expect_true(any(grepl("xb                  : Inf", sortie, fixed = TRUE)))
  expect_true(any(grepl("xb_date             : 5 images", sortie, fixed = TRUE)))
  sortie_inf <- capture.output(print(parametres_sufosat(xb_date = Inf)))
  expect_true(any(grepl("xb_date             : Inf", sortie_inf, fixed = TRUE)))
  capture.output(v <- withVisible(print(parametres_sufosat())))
  expect_false(v$visible)
})

test_that("mission 030 : règle de date et seuil de datation", {
  p <- parametres_sufosat()
  expect_identical(p$regle_date, "premiere_sous_seuil")
  # défaut : le seuil de détection effectif (tp x facteur), -3,45 dB
  expect_identical(p$seuil_datation_db, seuils_db(p)[["tp"]])
  expect_equal(p$seuil_datation_db, -3.45)
  # il suit tp_db et facteur_seuil quand on ne le donne pas
  expect_equal(parametres_sufosat(facteur_seuil = 1)$seuil_datation_db, -3)
  expect_equal(parametres_sufosat(tp_db = -2)$seuil_datation_db, -2.3)
  # réglage distinct : le donner ne change pas les seuils de détection
  q <- parametres_sufosat(seuil_datation_db = -3)
  expect_identical(q$seuil_datation_db, -3)
  expect_identical(seuils_db(q), seuils_db(p))
  expect_identical(parametres_sufosat(regle_date = "minimum")$regle_date, "minimum")
  # le passage dB <-> linéaire du seuil
  expect_equal(lineaire_vers_db(db_vers_lineaire(p$seuil_datation_db)), p$seuil_datation_db)
  # impression
  sortie <- capture.output(print(p))
  expect_true(any(grepl("regle_date          : premiere_sous_seuil", sortie, fixed = TRUE)))
  expect_true(any(grepl("seuil_datation_db   : -3.45 dB", sortie, fixed = TRUE)))
})

test_that("mission 030 : un seuil de datation absurde ou une règle inconnue est refusé", {
  expect_error(parametres_sufosat(seuil_datation_db = 0), "`seuil_datation_db`")
  expect_error(parametres_sufosat(seuil_datation_db = 3), "`seuil_datation_db`")
  expect_error(parametres_sufosat(seuil_datation_db = -Inf), "`seuil_datation_db`")
  expect_error(parametres_sufosat(seuil_datation_db = NA_real_), "`seuil_datation_db`")
  expect_error(parametres_sufosat(seuil_datation_db = c(-3, -4)), "`seuil_datation_db`")
  expect_error(parametres_sufosat(seuil_datation_db = "-3"), "`seuil_datation_db`")
  expect_error(parametres_sufosat(regle_date = "maximum"), "`regle_date`")
  expect_error(parametres_sufosat(regle_date = NA_character_), "`regle_date`")
  expect_error(parametres_sufosat(regle_date = c("minimum", "minimum")), "`regle_date`")
  p <- parametres_sufosat()
  q <- p
  q$seuil_datation_db <- NULL
  expect_error(seuils_db(q), "exactement")
  q <- p
  q$seuil_datation_db <- 1
  expect_error(seuils_db(q), "`seuil_datation_db`")
})
