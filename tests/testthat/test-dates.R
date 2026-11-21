test_that("date_vers_yyddd code l'année sur deux chiffres et le jour de l'année", {
  expect_identical(date_vers_yyddd(as.Date("2024-03-15")), 24075L)
  expect_identical(date_vers_yyddd(as.Date("2018-01-01")), 18001L)
  expect_identical(date_vers_yyddd(as.Date("2025-09-30")), 25273L)
  expect_identical(date_vers_yyddd("2000-01-01"), 1L)
})

test_that("le 31 décembre vaut 365 ou 366 selon l'année", {
  expect_identical(date_vers_yyddd(as.Date("2023-12-31")), 23365L)
  expect_identical(date_vers_yyddd(as.Date("2024-12-31")), 24366L)
})

test_that("yyddd_vers_date décode les codes des cartes publiées", {
  expect_identical(yyddd_vers_date(24075L), as.Date("2024-03-15"))
  expect_identical(yyddd_vers_date(18001), as.Date("2018-01-01"))
  expect_identical(yyddd_vers_date(24366L), as.Date("2024-12-31"))
})

test_that("l'aller-retour redonne la date de départ", {
  dates <- seq(as.Date("2018-01-01"), as.Date("2026-12-31"), by = "day")
  # expect_equal : selon la version de R, seq() rend des dates stockées en entiers ou en doubles
  expect_equal(yyddd_vers_date(date_vers_yyddd(dates)), dates)
})

test_that("les valeurs manquantes sont conservées", {
  expect_identical(date_vers_yyddd(as.Date(c("2024-03-15", NA))), c(24075L, NA))
  expect_identical(yyddd_vers_date(c(NA, 24075L)), as.Date(c(NA, "2024-03-15")))
  expect_identical(yyddd_vers_date(NA), as.Date(NA))
  expect_identical(yyddd_vers_date(integer(0)), as.Date(character(0)))
})

test_that("le siècle est paramétrable", {
  expect_identical(date_vers_yyddd(as.Date("1999-12-31"), siecle = 1900), 99365L)
  expect_identical(yyddd_vers_date(99365L, siecle = 1900), as.Date("1999-12-31"))
  expect_error(date_vers_yyddd(as.Date("2024-01-01"), siecle = 2024), "multiple de 100")
  expect_error(yyddd_vers_date(24001L, siecle = NA), "multiple de 100")
})

test_that("les dates hors du siècle sont refusées", {
  expect_error(date_vers_yyddd(as.Date("1999-12-31")), "hors de la plage 2000-2099")
  expect_error(date_vers_yyddd(as.Date("2100-01-01")), "hors de la plage")
})

test_that("les codes impossibles sont refusés", {
  expect_error(yyddd_vers_date(24000L), "invalides")
  expect_error(yyddd_vers_date(23366L), "invalides")
  expect_error(yyddd_vers_date(24367L), "invalides")
  expect_error(yyddd_vers_date(-1L), "invalides")
  expect_error(yyddd_vers_date(100001L), "invalides")
  expect_error(yyddd_vers_date(24075.5), "entiers")
  expect_error(yyddd_vers_date("24075"), "`code` doit")
})
