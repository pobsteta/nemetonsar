skip_if_not_installed("terra")

# --- Identifiants MGRS ------------------------------------------------------

# Tuiles de référence : nom, coin haut-gauche en UTM (x, y), relevés dans la
# grille des tuiles Sentinel-2 de l'ESA,
# S2A_OPER_GPR_TILE_DF__20110101T000000_99991231T235959_0007.kml
# (sentinels.copernicus.eu, téléchargé le 2026-11-22, sha256 ffcd58f1...),
# champs TILE_ID et UTM_WKT : toutes les tuiles des zones 30 à 32, bandes T et
# U, dont le centre tombe dans l'emprise de la France métropolitaine (134),
# plus huit tuiles ailleurs (hémisphère sud, exceptions de Norvège et du
# Svalbard). Une tuile Sentinel-2 couvre son carré MGRS de 100 km et déborde
# de 9,8 km à l'est et au sud ; son coin haut-gauche est à moins de 40 m du
# coin nord-ouest du carré.
ref_s2 <- c(
  "18SUJ 300000 4400040", "20GMS 399960 5200000", "30TUM 300000 4700040", "30TUN 300000 4800000",
  "30TUP 300000 4900020", "30TUQ 300000 5000040", "30TUR 300000 5100000", "30TUS 300000 5200020",
  "30TUT 300000 5300040", "30TVM 399960 4700040", "30TVN 399960 4800000", "30TVP 399960 4900020",
  "30TVQ 399960 5000040", "30TVR 399960 5100000", "30TVS 399960 5200020", "30TVT 399960 5300040",
  "30TWM 499980 4700040", "30TWN 499980 4800000", "30TWP 499980 4900020", "30TWQ 499980 5000040",
  "30TWR 499980 5100000", "30TWS 499980 5200020", "30TWT 499980 5300040", "30TXM 600000 4700040",
  "30TXN 600000 4800000", "30TXP 600000 4900020", "30TXQ 600000 5000040", "30TXR 600000 5100000",
  "30TXS 600000 5200020", "30TXT 600000 5300040", "30TYM 699960 4700040", "30TYN 699960 4800000",
  "30TYP 699960 4900020", "30TYQ 699960 5000040", "30TYR 699960 5100000", "30TYS 699960 5200020",
  "30TYT 699960 5300040", "30UUA 300000 5600040", "30UUB 300000 5700000", "30UUU 300000 5400000",
  "30UUV 300000 5500020", "30UVA 399960 5600040", "30UVB 399960 5700000", "30UVU 399960 5400000",
  "30UVV 399960 5500020", "30UWA 499980 5600040", "30UWB 499980 5700000", "30UWU 499980 5400000",
  "30UWV 499980 5500020", "30UXA 600000 5600040", "30UXB 600000 5700000", "30UXU 600000 5400000",
  "30UXV 600000 5500020", "30UYA 699960 5600040", "30UYB 699960 5700000", "30UYU 699960 5400000",
  "30UYV 699960 5500020", "31TBG 199980 4700040", "31TCG 300000 4700040", "31TCH 300000 4800000",
  "31TCJ 300000 4900020", "31TCK 300000 5000040", "31TCL 300000 5100000", "31TCM 300000 5200020",
  "31TCN 300000 5300040", "31TDG 399960 4700040", "31TDH 399960 4800000", "31TDJ 399960 4900020",
  "31TDK 399960 5000040", "31TDL 399960 5100000", "31TDM 399960 5200020", "31TDN 399960 5300040",
  "31TEG 499980 4700040", "31TEH 499980 4800000", "31TEJ 499980 4900020", "31TEK 499980 5000040",
  "31TEL 499980 5100000", "31TEM 499980 5200020", "31TEN 499980 5300040", "31TFG 600000 4700040",
  "31TFH 600000 4800000", "31TFJ 600000 4900020", "31TFK 600000 5000040", "31TFL 600000 5100000",
  "31TFM 600000 5200020", "31TFN 600000 5300040", "31TGG 699960 4700040", "31TGH 699960 4800000",
  "31TGJ 699960 4900020", "31TGK 699960 5000040", "31TGL 699960 5100000", "31TGM 699960 5200020",
  "31TGN 699960 5300040", "31UCP 300000 5400000", "31UCQ 300000 5500020", "31UCR 300000 5600040",
  "31UCS 300000 5700000", "31UDP 399960 5400000", "31UDQ 399960 5500020", "31UDR 399960 5600040",
  "31UDS 399960 5700000", "31UEP 499980 5400000", "31UEQ 499980 5500020", "31UER 499980 5600040",
  "31UES 499980 5700000", "31UFP 600000 5400000", "31UFQ 600000 5500020", "31UFR 600000 5600040",
  "31UFS 600000 5700000", "31UGP 699960 5400000", "31UGQ 699960 5500020", "31UGR 699960 5600040",
  "31UGS 699960 5700000", "32TKM 199980 4700040", "32TLM 300000 4700040",
  "32TLN 300000 4800000", "32TLP 300000 4900020", "32TLQ 300000 5000040", "32TLR 300000 5100000",
  "32TLS 300000 5200020", "32TLT 300000 5300040", "32TMM 399960 4700040", "32TMN 399960 4800000",
  "32TMP 399960 4900020", "32TMQ 399960 5000040", "32TMR 399960 5100000", "32TMS 399960 5200020",
  "32TMT 399960 5300040", "32ULA 300000 5600040", "32ULB 300000 5700000", "32ULU 300000 5400000",
  "32ULV 300000 5500020", "32UMA 399960 5600040", "32UMB 399960 5700000", "32UMU 399960 5400000",
  "32UMV 399960 5500020", "32VKM 199980 6700020", "32VLM 300000 6700020", "33UVP 399960 5400000",
  "33XVG 399960 8700000", "33XWG 499980 8700000", "56HLH 300000 6300040"
)

test_that("les identifiants MGRS sont ceux des tuiles Sentinel-2 de l'ESA", {
  champs <- do.call(rbind, strsplit(ref_s2, " "))
  nom <- champs[, 1]
  ulx <- as.numeric(champs[, 2])
  uly <- as.numeric(champs[, 3])
  zone <- as.integer(substr(nom, 1, 2))
  bande <- substr(nom, 3, 3)
  nord <- bande >= "N"
  epsg <- ifelse(nord, 32600L, 32700L) + zone
  # Carré de 100 km de la tuile.
  x0 <- floor((ulx + 100) / 1e5) * 1e5
  y0 <- floor((uly - 100) / 1e5) * 1e5
  # Domaine de la zone de grille (norme MGRS) : bande de 8 degrés (12 pour X),
  # zone de 6 degrés, sauf exceptions de Norvège et du Svalbard.
  bandes <- strsplit("CDEFGHJKLMNPQRSTUVWX", "")[[1]]
  lat_min <- -80 + 8 * (match(bande, bandes) - 1)
  lat_max <- ifelse(bande == "X", 84, lat_min + 8)
  lon_min <- -180 + 6 * (zone - 1)
  lon_max <- lon_min + 6
  exc <- list("31V" = c(0, 3), "32V" = c(3, 12), "33X" = c(9, 21))
  for (k in names(exc)) {
    i <- substr(nom, 1, 3) == k
    lon_min[i] <- exc[[k]][1]
    lon_max[i] <- exc[[k]][2]
  }
  f <- seq(0.05, 0.95, by = 0.1)
  n_testes <- 0L
  for (j in seq_along(nom)) {
    pts <- expand.grid(x = x0[j] + f * 1e5, y = y0[j] + f * 1e5)
    ll <- terra::crds(terra::project(
      terra::vect(as.matrix(pts), crs = paste0("EPSG:", epsg[j])), "EPSG:4326"))
    garde <- ll[, 2] >= lat_min[j] & ll[, 2] < lat_max[j] &
      ll[, 1] >= lon_min[j] & ll[, 1] < lon_max[j]
    expect_true(any(garde), info = nom[j])
    r <- mgrs_point(ll[garde, 1], ll[garde, 2])
    expect_true(all(r$mgrs == nom[j]), info = nom[j])
    expect_true(all(r$epsg == epsg[j]), info = nom[j])
    n_testes <- n_testes + 1L
  }
  expect_equal(n_testes, 142L)
})

test_that("31VEG : tuile Sentinel-2 dans la zone 32V de la norme", {
  # La grille Sentinel-2 de l'ESA a une tuile 31VEG (EPSG:32631, coin
  # haut-gauche 499980, 6700020), à l'est de 3 degrés E ; la norme MGRS
  # rattache cette surface à la zone 32V (exception de Norvège). On suit la
  # norme.
  ll <- terra::crds(terra::project(terra::vect(cbind(550000, 6650000), crs = "EPSG:32631"),
                                   "EPSG:4326"))
  expect_gt(ll[1, 1], 3)
  expect_equal(substr(mgrs_point(ll[1, 1], ll[1, 2])$mgrs, 1, 3), "32V")
})

test_that("les coins des tuiles Sentinel-2 sont sur la grille de 10 et 20 m", {
  champs <- do.call(rbind, strsplit(ref_s2, " "))
  expect_true(all(as.numeric(champs[, 2]) %% 20 == 0))
  expect_true(all(as.numeric(champs[, 3]) %% 20 == 0))
})

test_that("Paris est en 31UDQ", {
  # Parvis de Notre-Dame, coordonnées approchées (le carré fait 100 km).
  r <- mgrs_point(2.3488, 48.8534)
  expect_equal(r$mgrs, "31UDQ")
  expect_equal(r$epsg, 32631L)
})

test_that("bandes et zones aux limites", {
  expect_equal(mgrs_bande(c(-80, -72.0001, 0, 47.9999, 48, 72, 84)),
               c("C", "C", "N", "T", "U", "X", "X"))
  expect_true(is.na(mgrs_bande(84.5)))
  expect_true(is.na(mgrs_bande(-80.5)))
  expect_equal(mgrs_zone(c(-180, -0.0001, 0, 5.9999, 6, 179.9999, 180), 45),
               c(1L, 30L, 31L, 31L, 32L, 60L, 1L))
  # Exceptions : Norvège (32V entre 3 et 12 degrés E) et Svalbard.
  expect_equal(mgrs_zone(c(2.9, 3, 11.9), 60), c(31L, 32L, 32L))
  expect_equal(mgrs_zone(c(8.9, 9, 20.9, 21, 32.9, 33, 41.9), 78),
               c(31L, 33L, 33L, 35L, 35L, 37L, 37L))
})

# --- AOI synthétiques ---------------------------------------------------------

rect <- function(xmin, xmax, ymin, ymax, crs = "EPSG:4326") {
  terra::vect(sprintf("POLYGON ((%f %f, %f %f, %f %f, %f %f, %f %f))",
                      xmin, ymin, xmax, ymin, xmax, ymax, xmin, ymax, xmin, ymin),
              crs = crs)
}

test_that("une AOI dans un seul carr\u00e9 de la zone 31 donne une tuile", {
  aoi <- rect(2.30, 2.40, 48.80, 48.88)
  p <- aoi_preparer(aoi)
  expect_s3_class(p, "nemetonsar_aoi")
  t <- p$tuiles
  expect_equal(nrow(t), 1L)
  expect_equal(t$mgrs, "31UDQ")
  expect_equal(t$epsg, 32631L)
  expect_equal(t$zone, 31L)
  expect_equal(t$bande, "U")
  expect_equal(t$carre, "DQ")
  # emprise alignée sur 10 m, dans le carré 31UDQ (400-500 km, 5400-5500 km)
  for (k in c("xmin", "ymin", "xmax", "ymax")) expect_equal(t[[k]] %% 10, 0)
  expect_true(t$xmin >= 4e5 && t$xmax <= 5e5 && t$ymin >= 5.4e6 && t$ymax <= 5.5e6)
  # l'AOI reprojetée tient dans l'emprise, à moins d'un pixel des bords
  e <- as.vector(terra::ext(p$aoi[["31UDQ"]]))
  expect_true(e[["xmin"]] >= t$xmin && e[["xmin"]] - t$xmin < 10)
  expect_true(e[["xmax"]] <= t$xmax && t$xmax - e[["xmax"]] < 10)
  expect_true(e[["ymin"]] >= t$ymin && e[["ymin"]] - t$ymin < 10)
  expect_true(e[["ymax"]] <= t$ymax && t$ymax - e[["ymax"]] < 10)
  expect_true(terra::same.crs(p$aoi[["31UDQ"]], "EPSG:32631"))
  expect_equal(p$surface_km2, sum(terra::expanse(aoi, unit = "km")))
  expect_equal(t$surface_ha, p$surface_km2 * 100, tolerance = 1e-6)
})

test_that("une AOI \u00e0 cheval sur les zones 30 et 31 donne deux tuiles", {
  aoi <- rect(-0.1, 0.1, 47.0, 47.1)
  p <- aoi_preparer(aoi)
  t <- p$tuiles
  # 30TYT existe dans la grille Sentinel-2 ; 31TBN est un carré MGRS sans
  # tuile Sentinel-2 (couvert par le débord de 30TYT).
  expect_equal(t$mgrs, c("30TYT", "31TBN"))
  expect_equal(t$epsg, c(32630L, 32631L))
  expect_true(terra::same.crs(p$aoi[["30TYT"]], "EPSG:32630"))
  expect_true(terra::same.crs(p$aoi[["31TBN"]], "EPSG:32631"))
  # les deux parties ont la même surface (AOI symétrique autour de 0 degré)
  # et leur somme est la surface de l'AOI : la coupe suit le méridien.
  expect_equal(t$surface_ha[1], t$surface_ha[2], tolerance = 1e-4)
  expect_equal(sum(t$surface_ha) / 100, p$surface_km2, tolerance = 1e-6)
  # chaque partie reste de son côté du méridien 0
  for (m in t$mgrs) {
    e <- as.vector(terra::ext(terra::project(p$aoi[[m]], "EPSG:4326")))
    if (m == "30TYT") expect_true(e[["xmax"]] <= 1e-6) else expect_true(e[["xmin"]] >= -1e-6)
  }
})

test_that("une AOI \u00e0 cheval sur deux carr\u00e9s de 100 km et deux bandes", {
  # x = 500 km dans la zone 31 est le méridien 3 degrés E ; 48 degrés N
  # sépare les bandes T et U.
  p <- aoi_preparer(rect(2.95, 3.05, 47.95, 48.05))
  t <- p$tuiles
  expect_equal(nrow(t), 4L)
  expect_equal(t$mgrs, c("31TDP", "31TEP", "31UDP", "31UEP"))
  expect_true(all(t$epsg == 32631L))
  expect_equal(sum(t$surface_ha) / 100, p$surface_km2, tolerance = 1e-6)
  expect_true(all(t$xmax[t$carre == "DN"] <= 5e5))
  expect_true(all(t$xmin[t$carre == "EN"] >= 5e5))
})

test_that("les surfaces des tuiles somment \u00e0 celle de l'AOI, sans avertissement", {
  # polygone en Lambert-93 aux longs c\u00f4t\u00e9s, sur deux zones et trois carr\u00e9s
  aoi <- terra::vect("POLYGON ((-0.35 46.05, 0.25 46.02, 0.42 46.20, 0.10 46.33, -0.30 46.28, -0.35 46.05))",
                     crs = "EPSG:4326")
  aoi <- terra::project(aoi, "EPSG:2154")
  expect_silent(p <- aoi_preparer(aoi))
  expect_equal(p$tuiles$mgrs, c("30TYS", "31TBL", "31TBM", "31TCM"))
  expect_equal(sum(p$tuiles$surface_ha) / 100, p$surface_km2, tolerance = 1e-5)
})

test_that("une AOI en Lambert-93 est reprojet\u00e9e", {
  l93 <- terra::project(rect(2.30, 2.40, 48.80, 48.88), "EPSG:2154")
  p <- aoi_preparer(l93)
  expect_equal(p$tuiles$mgrs, "31UDQ")
  expect_true(terra::same.crs(p$aoi_origine, "EPSG:2154"))
})

test_that("une AOI hors de France m\u00e9tropolitaine est refus\u00e9e", {
  expect_error(aoi_preparer(rect(-3.8, -3.6, 40.3, 40.5)), "France")   # Madrid
  expect_error(aoi_preparer(rect(2.0, 2.2, 41.2, 41.4)), "France")     # déborde au sud
  expect_error(aoi_preparer(rect(9.5, 9.7, 42.0, 42.1)), "France")     # déborde à l'est
})

test_that("une AOI plus grande que le plus grand d\u00e9partement est refus\u00e9e", {
  # 1,5 x 1 degré vers 47 degrés N : de l'ordre de 12 600 km2
  expect_error(aoi_preparer(rect(1.0, 2.5, 46.5, 47.5)), "trop grande")
  # 1,2 x 1 degré : de l'ordre de 10 100 km2, accepté
  p <- aoi_preparer(rect(1.0, 2.2, 46.5, 47.5), resolution_m = 100)
  expect_lt(p$surface_km2, 10380.876)
  expect_gt(p$surface_km2, 9000)
})

test_that("une g\u00e9om\u00e9trie invalide est r\u00e9par\u00e9e, avec un avertissement", {
  # « nœud papillon » : contour qui se croise
  noeud <- terra::vect("POLYGON ((2.30 48.80, 2.40 48.88, 2.40 48.80, 2.30 48.88, 2.30 48.80))",
                       crs = "EPSG:4326")
  expect_false(terra::is.valid(noeud))
  expect_warning(p <- aoi_preparer(noeud), "makeValid")
  expect_equal(p$tuiles$mgrs, "31UDQ")
  expect_gt(p$surface_km2, 0)
})

test_that("plusieurs polygones sont r\u00e9unis", {
  a <- rbind(rect(2.30, 2.35, 48.80, 48.85), rect(2.34, 2.40, 48.82, 48.88))
  p <- aoi_preparer(a)
  expect_equal(nrow(p$aoi_origine), 1L)
  expect_equal(p$surface_km2, sum(terra::expanse(terra::aggregate(a), unit = "km")))
})

test_that("les trois formats se lisent", {
  aoi <- rect(2.30, 2.40, 48.80, 48.88)
  aoi$nom <- "essai"
  d <- tempfile("aoi")
  dir.create(d)
  fichiers <- file.path(d, c("aoi.gpkg", "aoi.geojson", "aoi.shp"))
  formats <- c("GPKG", "GeoJSON", "ESRI Shapefile")
  for (k in seq_along(fichiers)) terra::writeVector(aoi, fichiers[k], filetype = formats[k])
  ref <- aoi_preparer(aoi)$tuiles
  for (f in fichiers) {
    t <- aoi_preparer(f)$tuiles
    expect_equal(t$mgrs, ref$mgrs, info = f)
    expect_equal(t[, c("xmin", "ymin", "xmax", "ymax")], ref[, c("xmin", "ymin", "xmax", "ymax")],
                 info = f)
    expect_equal(t$surface_ha, ref$surface_ha, tolerance = 1e-6, info = f)
  }
  expect_equal(aoi_preparer(fichiers[1], couche = "aoi")$tuiles$mgrs, "31UDQ")
  unlink(d, recursive = TRUE)
})

test_that("les entr\u00e9es incorrectes sont refus\u00e9es", {
  expect_error(aoi_preparer(file.path(tempdir(), "absent.gpkg")), "introuvable")
  expect_error(aoi_preparer(42), "SpatVector")
  pts <- terra::vect(cbind(2.3, 48.8), crs = "EPSG:4326")
  expect_error(aoi_preparer(pts), "polygones")
  sans_crs <- terra::vect("POLYGON ((2.3 48.8, 2.4 48.8, 2.4 48.9, 2.3 48.8))")
  expect_error(aoi_preparer(sans_crs), "coordonn")
  texte <- tempfile(fileext = ".txt")
  writeLines("rien", texte)
  expect_error(aoi_preparer(texte), "illisible")
  aoi <- rect(2.30, 2.40, 48.80, 48.88)
  expect_error(aoi_preparer(aoi, resolution_m = 7), "resolution_m")
  expect_error(aoi_preparer(aoi, resolution_m = -10), "resolution_m")
  expect_error(aoi_preparer(aoi, resolution_m = c(10, 20)), "resolution_m")
})

test_that("la r\u00e9solution r\u00e8gle l'alignement", {
  p <- aoi_preparer(rect(2.30, 2.40, 48.80, 48.88), resolution_m = 20)
  t <- p$tuiles
  for (k in c("xmin", "ymin", "xmax", "ymax")) expect_equal(t[[k]] %% 20, 0)
  expect_equal(t$ncol, (t$xmax - t$xmin) / 20)
  expect_equal(t$nrow, (t$ymax - t$ymin) / 20)
})

# --- Grille de calcul ---------------------------------------------------------

test_that("aoi_grille rend la grille de la tuile", {
  p <- aoi_preparer(rect(-0.1, 0.1, 47.0, 47.1))
  t <- p$tuiles
  for (i in seq_len(nrow(t))) {
    g <- aoi_grille(t[i, ])
    expect_s4_class(g, "SpatRaster")
    expect_false(terra::hasValues(g))
    expect_equal(terra::res(g), c(10, 10))
    expect_equal(as.vector(terra::ext(g)),
                 c(xmin = t$xmin[i], xmax = t$xmax[i], ymin = t$ymin[i], ymax = t$ymax[i]))
    expect_equal(c(terra::nrow(g), terra::ncol(g)), c(t$nrow[i], t$ncol[i]))
    expect_true(terra::same.crs(g, paste0("EPSG:", t$epsg[i])))
    # la partie de l'AOI couvre la grille sans la dépasser
    expect_true(terra::relate(p$aoi[[t$mgrs[i]]], terra::as.polygons(terra::ext(g),
                                                                     crs = terra::crs(g)),
                              "within")[1, 1])
  }
  expect_equal(as.vector(terra::ext(aoi_grille(p, "31TBN"))),
               as.vector(terra::ext(aoi_grille(t[2, ]))))
  expect_error(aoi_grille(p), "mgrs")
  expect_error(aoi_grille(p, "31UDQ"), "mgrs")
  expect_error(aoi_grille(t), "tuile")
  expect_error(aoi_grille("31UDQ"), "tuile")
  p1 <- aoi_preparer(rect(2.30, 2.40, 48.80, 48.88))
  expect_equal(terra::ncol(aoi_grille(p1)), p1$tuiles$ncol)
})
