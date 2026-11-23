# Lecture réelle et passe 1 en parallèle — mission 019

Analyste, 2026-11-22. Script : [`lecture-parallele.R`](lecture-parallele.R), à
lancer depuis la racine du dépôt
(`Rscript docs/analyses/lecture-parallele.R <dossier_donnees> [etapes] [repetitions]`,
étapes 1 à 5, 2 répétitions par défaut).

**Mission redite.** Mesurer, sur des images Sentinel-1 RTC réelles des Landes, où
part le temps d'une tuile : structure des COG, lecture distante ou locale par
bandes de 9 lignes ou de la hauteur des tuiles internes, passe 1 sur 1, 2 et 3
orbites en parallèle. Puis extrapoler à une tuile MGRS pour que Pascal tranche
l'ADR 0004 sur des chiffres et non sur une estimation.

**Nature des chiffres.** Les temps par image et par bloc sont **mesurés** (2
répétitions, machine virtuelle de la session : 4 cœurs, 16 Go, R 4.3.3,
terra 1.7.65, GDAL 3.8.4). Les durées « par tuile » sont des **extrapolations
linéaires**. Ce ne sont pas des mesures sur une tuile. Le débit réseau est celui de cette
machine, derrière le mandataire HTTPS local de la session : il ne vaut que pour
elle.

## Ce qui a été mesuré, sur quoi

- **Données.** Collection `sentinel-1-rtc` du Planetary Computer (jeton SAS sans
  compte), point pilote (−0,80 E ; 44,20 N), année 2025, VH. Lecture : orbite
  **D008**, ses **31 images** de 2025. **Fenêtre native de 2 048 colonnes × 1 024
  lignes** (20 × 10 km, 8,39 Mo utiles en float32 par image), alignée sur la
  grille des tuiles internes. Volume reçu au total ≈ 1,4 Go ; disque utilisé
  1,8 Go, dans le dossier de travail seulement.
- **Passe 1.** Piles locales de **36 lignes × 10 980 colonnes × 300 dates** par
  orbite, blocs de 9 lignes (le défaut à 300 dates). Elles sont faites des
  copies locales réelles. Chaque « orbite » prend des lignes différentes de D008.
  Les colonnes sont répétées jusqu'à 10 980. L'année 2025 est répétée sur
  2016-2025, décalée de 7 colonnes par an. Les valeurs sont réelles et la
  structure est répétée : le coût de calcul est représentatif, la détection ne
  l'est pas. La boucle reprend celle de `detecter_blocs()`, avec les mêmes
  fonctions (`s1_filter_multitemp`, `rcr_compute`, `rcr_combine_orbites`). Le
  parallélisme se fait par bloc : un `mclapply` (fork) sur les orbites. Chaque
  configuration tourne dans un processus neuf. Le pic mémoire vient de `VmHWM`
  par processus et de l'échantillonnage de `MemAvailable` toutes les 0,1 s pour
  le total. Le cache disque est vidé avant chaque lecture locale.

## 1. Structure des COG RTC (`terra::describe`)

| Orbite | Système | Taille (col × lig) | Tuiles internes | Type | Compression | Fichier |
|---|---|---|---|---|---|---:|
| D008 | UTM 31N (32631) | 29 473 × 22 091 | 512 × 512 | Float32 | DEFLATE, prédicteur 3 | 1 842 Mo |
| A030 | UTM 30N (32630) | 29 075 × 21 825 | 512 × 512 | Float32 | DEFLATE, prédicteur 3 | 1 843 Mo |
| D081 | UTM 30N (32630) | 28 927 × 20 960 | 512 × 512 | Float32 | DEFLATE, prédicteur 3 | 1 818 Mo |

Ce sont des COG (`LAYOUT=COG`), avec 6 aperçus. Une image couvre ≈ 295 × 220 km.
**D008 est en UTM 31N** : pour une tuile MGRS en 30N, il faut une vraie
reprojection (rotation de l'emprise : × 1,147 en surface lue). Une bande de 9
lignes d'une tuile MGRS touche **22 tuiles internes** par image : 22 × 512 × 512
× 4 o ≈ 23 Mo décompressés, pour 0,4 Mo utiles.

## 2. Lecture d'une orbite (par image : fenêtre 2 048 × 1 024, 8,39 Mo utiles)

| Cas | Images | s / image (rép. 1 ; 2) | Mo reçus / image | s / Mo utile |
|---|---:|---|---:|---:|
| Distant, bandes de 512 lignes (alignées) | 31 | 1,58 ; 1,74 | 6,91 | 0,198 |
| Distant, bandes de 9 lignes (+1 de bord), cache suffisant | 10 | 2,04 ; 2,02 | 6,92 | 0,242 |
| Distant, bandes de 9 lignes, **cache insuffisant** (fenêtre 1 024 × 512) | 3 | 175 ; 173 | 104 (2,10 utiles) | **83** |
| Distant, 512 lignes, **4 processus** (8 images) | 8 | 1,15 ; 0,82 | 6,93 | 0,118 |
| Local (copie GeoTIFF terra, cache disque vidé), 512 lignes | 31 | 0,049 ; 0,050 | 0 | 0,0059 |
| Local, 9 lignes (+1 de bord) | 31 | 0,072 ; 0,057 | 0 | 0,0077 |
| `s1_lire()` distant, grille UTM 30N 1 400 × 700 | 3 | 1,91 ; 1,14 | 5,16 (3,92 utiles) | 0,389 |
| `s1_lire()` depuis les copies locales (sans réseau) | 3 | 0,60 ; 0,53 | 0 | 0,145 |

Ce qu'on lit dans ce tableau :

- **Distant, aligné contre 9 lignes.** Tant que les tuiles internes d'une image
  restent en cache, lire par 9 lignes ne coûte que 22 % de plus et le volume
  reçu est le même. Mais à l'échelle d'une tuile, le cache ne tient pas. La
  passe 1 lit une bande de 9 lignes dans les 300 images d'une orbite avant de
  passer à la suivante. Il faudrait donc garder 300 × 22 tuiles × 1 Mo ≈ 6,6 Go
  par orbite (≈ 20 Go pour trois), contre 683 Mo de cache GDAL ici. Le régime
  « cache insuffisant » imite ce cas (`gdalCache(1)`,
  `CPL_VSIL_CURL_CACHE_SIZE=65536`). Chaque bande retélécharge alors ses
  tuiles : **× 60 en octets, × 420 en temps**. Lire les COG à distance par
  bandes de 9 lignes est donc **exclu**.
- **Les bandes alignées sur 512 lignes** lisent chaque tuile interne une fois,
  sans cache. Mais 512 lignes × 10 980 × 300 dates × 8 o font 13,5 Go par
  orbite dans R : elles ne peuvent pas nourrir la passe 1 directement. Elles
  servent à **rapatrier** les images.
- **Local contre distant** (aligné) : **× 34** plus rapide par Mo (0,0059 contre
  0,198 s/Mo), cache disque vidé.
- **Débit réseau** : 4,2 Mo/s sur un flux, 7,0 Mo/s avec 4 processus (× 1,7).
  Le reçu vaut 0,82 o par octet utile (DEFLATE + prédicteur 3).
- **Copie locale** (GeoTIFF par défaut de terra, LZW, comme
  `s1_lire(dossier =)`) : **4,50 o par valeur**, soit 12 % de plus que le float32
  brut. Le LZW sans prédicteur gonfle ces données. La source en DEFLATE +
  prédicteur 3 tient en ≈ 3,3 o par valeur (déduit des octets reçus, non mesuré
  sur disque).
- **`s1_lire()` sans réseau** (étape 5, grilles de 350 × 350 à 1 400 × 700, une
  image) coûte ≈ 0,1 s fixe par image, plus **0,46 à 0,56 s par million de
  pixels** (deux passages). La reprojection seule (`terra::project`, bilinéaire)
  prend 0,48 s/Mpx sur un fil et **0,155 s/Mpx** avec `threads = TRUE` (× 3).

## 3. Passe 1 sur 1, 2 et 3 orbites (36 × 10 980 × 300 par orbite, blocs de 9 lignes)

| Orbites | Mode | Temps (rép. 1 ; 2) | Lecture / filtre / ratio (somme des orbites, rép. 1) | Pic par processus | Pic total |
|---:|---|---|---|---:|---:|
| 1 | série | 28,7 ; 28,9 s | 5,7 / 14,8 / 8,2 s | 2,10 Go | 2,04 ; 1,55 Go |
| 2 | série | 55,7 ; 59,1 s | 11,4 / 28,6 / 15,7 s | 2,36 Go | 2,10 ; 2,18 Go |
| 2 | parallèle | 32,8 ; 35,4 s (**× 1,68**) | 15,1 / 31,3 / 18,2 s | 1,60 Go (fils), 0,25 Go (père) | 3,20 ; 3,16 Go |
| 3 | série | 80,6 ; 89,3 s | 15,2 / 40,9 / 24,4 s | 2,78 Go | 2,33 ; 2,41 Go |
| 3 | parallèle | 34,9 ; 41,8 s (**× 2,21**) | 23,1 / 49,8 / 29,6 s | 1,60 Go (fils), 0,25 Go (père) | 4,24 ; 4,58 Go |

- **Les résultats sont identiques** au bit près (MD5 du ratio et de la date)
  entre série, parallèle et répétitions, pour 1, 2 et 3 orbites.
- **Trois orbites en parallèle : × 2,2, pas × 3.** Sur 4 cœurs, chaque orbite
  lit et calcule plus lentement en parallèle : lecture × 1,5 (décompression LZW
  et disque partagés), filtre et ratio × 1,2 (bande passante mémoire).
- **Mémoire** : 1,6 Go par fils (dont ≈ 0,25 Go partagés avec le père). Pic
  total ≈ 4,2 à 4,6 Go pour trois orbites, contre ≈ 2,4 Go en série. Le pic du
  processus série monte avec le nombre d'orbites (2,1 → 2,8 Go) : il garde les
  résultats des orbites déjà calculées.
- **Lecture locale** : ≈ 20 % de la passe 1 en série (5,5 s par orbite pour 36
  lignes).

## 4. Extrapolation à une tuile MGRS (10 980 × 10 980, 300 dates × 3 orbites = 900 images)

Tous les chiffres de cette section sont **extrapolés** linéairement : passe 1 ×
305 (pixels), acquisition au volume. Moyenne des deux répétitions.

**Acquisition** (`s1_rechercher()` + `s1_lire()`, commune à toutes les options) :

| Poste | Valeur extrapolée |
|---|---|
| Volume utile | 434 Go (float32) |
| Volume à télécharger | **375 Go** (0,82 × 434 × 1,049 d'emprise moyenne ; une image par date et par orbite, tuile entièrement couverte) |
| Téléchargement | **25,0 h** sur un flux (4,2 Mo/s) ; 14,8 h avec 4 processus (7,0 Mo/s) |
| Reprojection + écriture (`s1_lire()`, sans réseau) | **14 à 17 h** (0,46 à 0,56 s/Mpx) ; `project()` seul : 14,5 h sur un fil, **4,7 h** en multi-fil |
| Disque des piles locales (`s1_lire(dossier =)`, LZW) | **488 Go** par tuile |
| Lecture distante directe par 9 lignes (pour mémoire) | × 60 en octets, ≈ 1 500 h : exclue |

**Passe 1** (lecture des piles locales, filtre, ratio) : options de l'ADR 0004.
« Option C » est lue comme l'option 1 (C par `.Call`), avec les gains du
prototype de 016 : filtre 3,3-4,0 s → 0,5 s, ratio 2,6 s → 1,1 s par bloc et
par orbite.

| Option ADR 0004 | Lecture locale | Calcul (filtre + ratio) | Passe 1 | Tuile entière, acquisition actuelle (25 h + 17 h) | Nature |
|---|---:|---:|---:|---:|---|
| 0 — base R, série | 1,4 h | 3,6 + 2,2 h | **7,2 h** | ≈ 49 h | mesuré-extrapolé |
| 3 — base R, 3 orbites en parallèle (fork) | (dans les fils) | (dans les fils) | **3,2 h** | ≈ 45 h | mesuré-extrapolé |
| 1 — C (option C), série | 1,4 h | ≈ 0,5 + 0,9 h | **2,8 à 2,9 h** | ≈ 45 h | extrapolé avec les gains du prototype (non mesuré dans le package) |
| 2 — Rcpp | comme 1 | comme 1 | ≈ 2,8 à 2,9 h | ≈ 45 h | même calcul que 1, dépendance en plus |
| 4 — C + parallèle | (dans les fils) | (dans les fils) | **≈ 1,3 h** | ≈ 43 h | **estimé** : lecture parallèle mesurée (8,4 s par orbite et par 36 lignes) + calcul C du prototype |

Passes 2 et 3, table et polygones : non mesurés ici (négligeables sur les
simulations de 016, pas encore mesurés sur une tuile réelle).

**Où va le temps d'une tuile aujourd'hui** (chaîne actuelle, tout en série,
extrapolé) : ≈ 49 h, dont **téléchargement 51 %**, **reprojection 35 %**,
passe 1 15 %. Même avec une passe 1 instantanée, il resterait ≈ 42 h.

## Conclusion

**Le goulot est l'acquisition des images, pas le calcul de la passe 1.** Sur
cette machine, télécharger et reprojeter 900 images prend ≈ 39 à 42 h par
tuile, contre 7,2 h pour la passe 1. L'estimation de l'ADR (« ≈ 2 à 2,5 h par
tuile » avec le C) ne comptait que la lecture de piles déjà locales (1,4 h,
confirmée ici). Elle oubliait le téléchargement, la reprojection et
**488 Go de disque** par tuile.

**Ce que chaque option de l'ADR 0004 apporterait** (passe 1 seule) :

- **0** (base R) : 7,2 h.
- **3** (orbites en parallèle, base R) : **3,2 h**. Gain × 2,2 mesuré, sans
  compilateur, résultats identiques, pic ≈ 4,6 Go. Non mesuré sous Windows : il
  n'y a pas de fork, il faudrait PSOCK, ce qui veut dire copier les blocs vers
  les processus.
- **1 / 2** (C ou Rcpp) : ≈ 2,8 h. Gain voisin de l'option 3, au prix d'un
  compilateur, de deux implémentations et des points 2 à 4 de la critique.
- **4** (C + parallèle) : ≈ 1,3 h, estimé.

Aucune ne change l'ordre de grandeur d'une tuile tant que l'acquisition prend
≈ 40 h.

**Réponse à la question de contrôle : les trois causes sur lesquelles agir.**

1. **Le volume et le débit du téléchargement.** 375 Go par tuile, 25 h à
   4,2 Mo/s. Leviers : plusieurs flux (× 1,7 mesuré à 4 processus) ;
   télécharger chaque image **une seule fois** et la garder, car une mise à jour
   n'ajoute que les nouvelles dates (≈ 30 par an et par orbite, contre 300) ;
   jamais de lecture distante par 9 lignes (× 60).
2. **La reprojection sur un seul fil dans `s1_lire()`.** 0,5 s par million de
   pixels, 14 à 17 h par tuile. Levier : `terra::project(threads = TRUE)`
   (× 3 mesuré sur la reprojection seule), en même temps que le téléchargement.
3. **Le calcul de la passe 1** (filtre et ratio, 5,8 h en série). Levier : les
   orbites en parallèle (× 2,2 mesuré), puis le C seulement s'il reste dominant.

À côté de ces causes de durée, une condition de faisabilité : **488 Go de
piles locales par tuile**. Une acquisition par bandes de la tuile alignées sur
512 lignes (512 + 2 lignes × 10 980 × 900 images × 4,5 o) ramènerait le disque à
**≈ 23 Go** (calcul, non mesuré). Écrire en DEFLATE + prédicteur 3 plutôt qu'en
LZW gagnerait ≈ 25 % (déduit, non mesuré).

## Recommandation (Pascal tranche)

1. **ADR 0004 : ne pas retenir le C maintenant.** Retenir l'**option 3**
   (orbites en parallèle par fork, en base R, repli en série là où le fork
   manque). Elle donne le même ordre de gain que le C (3,2 h contre ≈ 2,8 h),
   sans compilateur et sans dépendance, à résultats identiques. Le C (options
   1, 2, 4) se rejuge plus tard, sur une tuile réelle, une fois l'acquisition
   corrigée, si la passe 1 domine encore.
2. **Mission suivante proposée : l'acquisition** (`s1_lire()`, `R/s1.R`). Elle
   couvre :
   - des téléchargements en parallèle ;
   - la reprojection multi-fil ;
   - une acquisition par bandes de 512 lignes de la tuile (disque borné) ;
   - des images gardées d'une exécution à l'autre ;
   - un format local compressé avec prédicteur.

   À mesurer ensuite sur une vraie tuile, idéalement sur une machine proche des
   données (Azure Europe de l'Ouest), où le débit n'est pas celui d'ici.
   Avec ces leviers, l'ordre de grandeur passerait de ≈ 49 h à ≈ 23 h par tuile
   sur cette machine (14,8 + 4,7 + 3,2 h, **extrapolé**, écriture des piles non
   comptée).

## Limites

- **Le débit réseau est propre à cette session** (mandataire HTTPS local, lieu
  inconnu). Le téléchargement extrapolé (25 h) peut être bien moindre ailleurs.
  La reprojection et la passe 1 ne dépendent que de la machine.
- Lecture mesurée sur **une orbite (D008), 2025, 31 images**, une fenêtre de
  20 × 10 km. Le régime « cache insuffisant » porte sur 3 images et une fenêtre
  de 1 024 × 512. Il est **imité** par des caches réduits, sur l'argument
  chiffré du § 2, et non mesuré sur 300 images.
- Piles de la passe 1 : **valeurs réelles, structure répétée** (colonnes et
  années). Les trois « orbites » sont des lignes différentes de la même orbite.
- Extrapolations linéaires. Hypothèses : une image par date et par orbite,
  sans tranches doubles ; tuile entièrement couverte par chaque orbite. Passes
  2 et 3, assemblage et masques non mesurés. Les parts fixes de `s1_lire()` par
  image, mesurées sur de petites grilles, sont ignorées à l'échelle d'une tuile.
- Machine virtuelle partagée, 4 cœurs. Écart de 4 à 20 % entre répétitions
  (3 orbites en parallèle : 34,9 et 41,8 s). Pendant la 2e répétition de « 3
  orbites en série », une synthèse de quelques secondes a tourné sur un autre
  cœur. Le processus principal de l'étape 3 s'est terminé en erreur après la
  dernière mesure, parce que le script a été modifié pendant son exécution. Les
  dix résultats étaient déjà écrits.
- Option 4 : estimée, pas mesurée. Options 1 et 2 : gains du prototype de 016
  (hors package, sans `NA`), appliqués aux temps mesurés ici.
