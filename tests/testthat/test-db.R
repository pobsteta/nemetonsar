test_that("lineaire_vers_db donne 10 * log10 sur des valeurs connues", {
  expect_equal(lineaire_vers_db(c(1, 10, 100, 0.01)), c(0, 10, 20, -20))
  expect_equal(lineaire_vers_db(0.5), -3.0103, tolerance = 1e-5)
  expect_identical(lineaire_vers_db(1L), 0)
})

test_that("db_vers_lineaire donne 10^(x / 10) sur des valeurs connues", {
  expect_equal(db_vers_lineaire(c(0, 10, 20, -20)), c(1, 10, 100, 0.01))
  expect_equal(db_vers_lineaire(-3), 0.5011872, tolerance = 1e-6)
})

test_that("l'aller-retour linéaire <-> dB redonne la valeur de départ", {
  lin <- 10^seq(-4, 4, by = 0.1)
  expect_equal(db_vers_lineaire(lineaire_vers_db(lin)), lin)
  db <- seq(-30, 10, by = 0.5)
  expect_equal(lineaire_vers_db(db_vers_lineaire(db)), db)
})

test_that("les seuils effectifs passent en linéaire et reviennent", {
  s <- seuils_db(parametres_sufosat())
  expect_equal(lineaire_vers_db(db_vers_lineaire(s)), s)
  expect_true(all(db_vers_lineaire(s) < 1))
})

test_that("les valeurs manquantes sont conservées", {
  expect_identical(lineaire_vers_db(c(NA, 10)), c(NA, 10))
  expect_identical(db_vers_lineaire(c(10, NA)), c(10, NA))
  expect_identical(lineaire_vers_db(NA), NA_real_)
  expect_identical(db_vers_lineaire(NA), NA_real_)
  expect_identical(lineaire_vers_db(numeric(0)), numeric(0))
  expect_identical(db_vers_lineaire(numeric(0)), numeric(0))
})

test_that("une valeur nulle ou négative devient NA avec un avertissement", {
  expect_warning(r <- lineaire_vers_db(c(0, -1, 10)), "2 valeur")
  expect_identical(r, c(NA, NA, 10))
  expect_no_warning(lineaire_vers_db(c(NA, 1)))
})

test_that("les infinis sont traités", {
  expect_identical(db_vers_lineaire(-Inf), 0)
  expect_identical(db_vers_lineaire(Inf), Inf)
  expect_identical(lineaire_vers_db(Inf), Inf)
})

test_that("la forme d'une matrice est conservée", {
  m <- matrix(c(1, 10, 100, 1000), nrow = 2)
  r <- lineaire_vers_db(m)
  expect_identical(dim(r), c(2L, 2L))
  expect_equal(db_vers_lineaire(r), m)
})

test_that("une entrée non numérique est refusée", {
  expect_error(lineaire_vers_db("10"), "`x`")
  expect_error(db_vers_lineaire(TRUE), "`x`")
})
