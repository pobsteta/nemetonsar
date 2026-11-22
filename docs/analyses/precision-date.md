# Précision de la date de coupe sur séries synthétiques (mission 008)

> Analyste, 2026-11-22. Script : [`precision-date.R`](precision-date.R) (graine 20261122,
> environ 45 s sous R 4.3.3 ; sortie identique d'une exécution à l'autre, vérifiée).
>
> **Tous les chiffres de ce rapport viennent d'une simulation** (forêt homogène, speckle
> gamma indépendant, sans saisonnalité). Ce ne sont **pas des mesures sur données réelles**
> et ils ne disent rien de la précision de la carte SUFOSAT v3.0.1.

## Mission redite

Mesurer, sur des séries synthétiques à speckle simulé (ENL 4,4), la part des coupes dont la
date est exacte, à ±1 et à ±2 acquisitions, selon `xb`, la fenêtre du filtre, la cadence et
l'amplitude de la chute, avec les fausses alertes en forêt intacte. Le but : que
l'orchestrateur puisse fixer, en citant un chiffre, les réglages provisoires de la date
(`xb`, règle de date) avant le jalon 2.

## Plan de simulation

| Élément | Valeur | Origine |
|---|---|---|
| Grille | 60 × 120 pixels : colonnes 1 à 60 coupées, 61 à 120 forêt intacte | choix de l'analyste |
| Pixels évalués | 3 420 coupés (colonnes 1 à 57) et 3 420 intacts (colonnes 64 à 120), à 3 pixels ou plus de la lisière | choix de l'analyste |
| Forêt | rétrodiffusion linéaire 0,05 (≈ −13 dB), constante | consigne |
| Speckle | gamma, forme = ENL = 4,4, moyenne 1, indépendant entre pixels et entre dates | B18, § 2.2.1, p. 4 (ENL avant filtre) ; **hypothèse de simulation** |
| Dates | 2018-01-03 au 2021-12-31, tous les 12 j (122 images) ou 6 j (244 images) | consigne |
| Coupe | marche permanente de −3, −4,5 ou −6 dB à partir de la première image après le 2020-06-15 | consigne |
| Vérité | date attendue = `d_(k+1)`, première image qui montre la chute | règle du package (décision 004) |
| Chaîne | `s1_filter_multitemp()` (fenêtre 1 = pas de filtre) → `rcr_compute()` → `rcr_segment()`, défauts du package sauf `xb` et `fenetre_filtre` | package chargé par `pkgload::load_all()` |
| Facteurs | `xb` ∈ {Inf, 5, 10, 20} × fenêtre ∈ {1, 3, 5} × cadence ∈ {12, 6} j × chute ∈ {−3, −4,5, −6} dB : 72 cas | consigne |
| Plan apparié | un même tirage de speckle par cadence, commun aux amplitudes, fenêtres et `xb` : les écarts entre réglages ne viennent pas du tirage | choix de l'analyste |

Contrôle interne : le script recalcule toute la série du RCR (pour les règles de date
alternatives et les profils) ; son minimum diffère de celui de `rcr_compute()` d'au plus
1e-12 dB sur les 72 cas.

**Incertitudes.** Les intervalles sont des intervalles de Wilson à 95 % sur n = 3 420
pixels. Avec filtre, des pixels voisins partagent leurs valeurs : l'intervalle sur n est
**trop étroit**. Le script donne aussi l'intervalle sur l'effectif efficace
n_eff = n / fenêtre² (380 pour la fenêtre 3, 136 pour la fenêtre 5), plus prudent. Le
contrôle de fin de série (plus bas) le confirme : même réglage (12 j, −6 dB, fenêtre 3,
`xb = Inf`), autre tirage, 18,3 % [17,0 ; 19,6] contre 15,6 % [14,4 ; 16,9] : les
intervalles sur n ne se recouvrent pas, ceux sur n_eff ([12,2 ; 19,5]) si. **Lire les
pourcentages des cas filtrés à ±4 points près environ.** Une fausse alerte nulle sur 3 420
pixels intacts a une borne haute de 0,1 % sur n, de 1 % sur n_eff = 380.

## Tableau de synthèse

Fenêtre 3 (défaut, M24 § II-B.1, p. 13746), chutes −4,5 et −6 dB. « Exacte » : `date_min`
= première image qui montre la chute ; « ±1 acq. » : au plus une acquisition d'écart
(12 ou 6 jours) ; biais médian en acquisitions (positif = date trop tardive) ;
erreur moyenne absolue en jours ; « détecté » : pixels coupés retenus par `rcr_segment()` ;
« FA détecté » : pixels de forêt intacte retenus ; dernier chiffre : 1er centile du ratio
minimal en forêt intacte (marge avant `ts` = −5,175 dB).

| cad. (j) | chute (dB) | xb | exacte % [IC n] | IC prudent (n_eff) | ±1 acq. % [IC n] | ±2 acq. % | biais méd. (acq.) | err. moy. abs. (j) | détecté (segm.) % | FA détecté % (intact) | q1 % RCR min intact (dB) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 | -4.5 | Inf | 13.6 [12.5 ; 14.8] | [10.6 ; 17.5] (n_eff 380) | 25.0 [23.6 ; 26.5] | 33.4 | 5 | 83.2 | 100.0 | 0.0 | -1.66 |
| 12 | -4.5 | 5 | 92.4 [91.4 ; 93.2] | [89.3 ; 94.6] (n_eff 380) | 98.8 [98.4 ; 99.1] | 99.9 | 0 | 1.1 | 97.7 | 0.0 | -2.00 |
| 12 | -4.5 | 10 | 70.9 [69.4 ; 72.4] | [66.3 ; 75.4] (n_eff 380) | 89.3 [88.2 ; 90.3] | 95.8 | 0 | 5.4 | 99.6 | 0.0 | -1.86 |
| 12 | -4.5 | 20 | 47.1 [45.5 ; 48.8] | [42.1 ; 52.1] (n_eff 380) | 67.8 [66.2 ; 69.3] | 78.9 | 1 | 15.5 | 100.0 | 0.0 | -1.74 |
| 12 | -6 | Inf | 15.6 [14.4 ; 16.9] | [12.2 ; 19.5] (n_eff 380) | 28.6 [27.1 ; 30.1] | 37.5 | 4 | 69.4 | 100.0 | 0.0 | -1.66 |
| 12 | -6 | 5 | 96.4 [95.7 ; 97.0] | [93.9 ; 97.8] (n_eff 380) | 99.5 [99.2 ; 99.7] | 100.0 | 0 | 0.5 | 100.0 | 0.0 | -2.00 |
| 12 | -6 | 10 | 77.9 [76.4 ; 79.2] | [73.5 ; 81.8] (n_eff 380) | 93.0 [92.1 ; 93.8] | 97.7 | 0 | 3.8 | 100.0 | 0.0 | -1.86 |
| 12 | -6 | 20 | 52.3 [50.6 ; 54.0] | [47.3 ; 57.3] (n_eff 380) | 73.0 [71.5 ; 74.5] | 84.0 | 0 | 12.4 | 100.0 | 0.0 | -1.74 |
| 6 | -4.5 | Inf | 9.3 [8.4 ; 10.3] | [6.7 ; 12.5] (n_eff 380) | 16.7 [15.5 ; 18.0] | 22.5 | 8 | 76.3 | 100.0 | 0.0 | -1.72 |
| 6 | -4.5 | 5 | 90.8 [89.8 ; 91.8] | [87.5 ; 93.3] (n_eff 380) | 99.3 [98.9 ; 99.5] | 100.0 | 0 | 0.6 | 98.9 | 0.0 | -2.09 |
| 6 | -4.5 | 10 | 70.8 [69.3 ; 72.3] | [66.0 ; 75.1] (n_eff 380) | 89.4 [88.3 ; 90.3] | 95.4 | 0 | 2.7 | 99.8 | 0.0 | -1.93 |
| 6 | -4.5 | 20 | 47.8 [46.2 ; 49.5] | [42.9 ; 52.9] (n_eff 380) | 69.4 [67.8 ; 70.9] | 80.1 | 1 | 7.3 | 100.0 | 0.0 | -1.83 |
| 6 | -6 | Inf | 11.2 [10.2 ; 12.3] | [8.5 ; 14.9] (n_eff 380) | 19.6 [18.3 ; 21.0] | 26.0 | 7 | 63.7 | 100.0 | 0.0 | -1.72 |
| 6 | -6 | 5 | 95.5 [94.7 ; 96.1] | [93.0 ; 97.2] (n_eff 380) | 99.9 [99.7 ; 100.0] | 100.0 | 0 | 0.3 | 100.0 | 0.0 | -2.09 |
| 6 | -6 | 10 | 77.2 [75.8 ; 78.6] | [72.6 ; 81.0] (n_eff 380) | 93.5 [92.7 ; 94.3] | 97.9 | 0 | 1.9 | 100.0 | 0.0 | -1.93 |
| 6 | -6 | 20 | 52.9 [51.2 ; 54.6] | [47.9 ; 57.9] (n_eff 380) | 74.6 [73.1 ; 76.1] | 85.0 | 0 | 5.9 | 100.0 | 0.0 | -1.83 |

Chute de −3 dB, fenêtre 3 : la date du minimum est aussi sensible à `xb`, mais **aucun pixel
n'est détecté** (ratio ≈ −3 dB, au-dessus de `tp` = −3,45 dB) : cette date n'est jamais
publiée.

| cad. (j) | xb | exacte % [IC n] | ±1 acq. % [IC n] | graine % | détecté (segm.) % |
|---|---|---|---|---|---|
| 12 | Inf | 10.6 [9.6 ; 11.7] | 20.0 [18.7 ; 21.4] | 0.0 | 0.0 |
| 12 | 5 | 82.1 [80.8 ; 83.3] | 95.4 [94.6 ; 96.0] | 0.0 | 0.0 |
| 12 | 10 | 59.5 [57.8 ; 61.1] | 80.5 [79.2 ; 81.8] | 0.0 | 0.0 |
| 12 | 20 | 38.0 [36.4 ; 39.7] | 58.2 [56.6 ; 59.9] | 0.0 | 0.0 |
| 6 | Inf | 7.0 [6.2 ; 7.9] | 13.1 [12.0 ; 14.3] | 0.0 | 0.0 |
| 6 | 5 | 81.0 [79.6 ; 82.2] | 95.8 [95.1 ; 96.4] | 0.0 | 0.0 |
| 6 | 10 | 59.7 [58.1 ; 61.4] | 80.7 [79.4 ; 82.0] | 0.0 | 0.0 |
| 6 | 20 | 39.6 [37.9 ; 41.2] | 60.4 [58.7 ; 62.0] | 0.0 | 0.0 |

**Lecture.** Avec `xb = Inf` (défaut provisoire), la date est exacte pour 9 à 16 % des
pixels coupés et à ±1 acquisition pour 17 à 29 % ; elle est en retard de 4 à 8 acquisitions
en médiane (48 à 96 jours à 12 j). Avec `xb = 5`, elle est exacte pour 91 à 96 % et à ±1
acquisition pour 99 % ou plus. `xb = 10` et `xb = 20` se rangent entre les deux. La
détection et les fausses alertes ne changent pas avec la fenêtre 3 : 98 à 100 % des pixels
coupés détectés, 0 fausse alerte sur 3 420 pixels intacts pour les quatre `xb`.

### Effet du filtre (chute −6 dB, cadence 12 j)

| fen. | xb | exacte % [IC n] | ±1 acq. % [IC n] | graine % | détecté % | FA graine % (n) | intact ≤ tp % | FA détecté % | q1 % RCR min intact (dB) |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Inf | 7.1 [6.3 ; 8.0] | 12.0 [10.9 ; 13.1] | 100.0 | 100.0 | 2.2 (3420) | 42.6 | 40.1 | -5.56 |
| 1 | 5 | 56.7 [55.1 ; 58.4] | 79.6 [78.2 ; 80.9] | 83.2 | 99.9 | 7.0 (3420) | 71.1 | 71.1 | -6.16 |
| 1 | 10 | 39.2 [37.6 ; 40.9] | 60.2 [58.6 ; 61.8] | 93.0 | 100.0 | 3.9 (3420) | 56.5 | 56.3 | -5.88 |
| 1 | 20 | 24.0 [22.6 ; 25.4] | 39.9 [38.3 ; 41.5] | 98.5 | 100.0 | 2.9 (3420) | 48.3 | 46.7 | -5.70 |
| 3 | Inf | 15.6 [14.4 ; 16.9] | 28.6 [27.1 ; 30.1] | 100.0 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.66 |
| 3 | 5 | 96.4 [95.7 ; 97.0] | 99.5 [99.2 ; 99.7] | 93.5 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -2.00 |
| 3 | 10 | 77.9 [76.4 ; 79.2] | 93.0 [92.1 ; 93.8] | 97.4 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.86 |
| 3 | 20 | 52.3 [50.6 ; 54.0] | 73.0 [71.5 ; 74.5] | 99.7 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.74 |
| 5 | Inf | 24.3 [22.9 ; 25.7] | 41.5 [39.9 ; 43.2] | 100.0 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.10 |
| 5 | 5 | 99.8 [99.5 ; 99.9] | 100.0 [99.9 ; 100.0] | 98.7 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.31 |
| 5 | 10 | 93.9 [93.1 ; 94.7] | 99.2 [98.9 ; 99.5] | 99.6 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.20 |
| 5 | 20 | 70.7 [69.2 ; 72.2] | 87.5 [86.4 ; 88.6] | 100.0 | 100.0 | 0.0 (3420) | 0.0 | 0.0 | -1.15 |

Sans filtre (fenêtre 1), 43 à 71 % des pixels intacts ont un ratio minimal sous `tp`. Ces
pixels se touchent et forment une zone unique qui contient des graines (2 à 7 % des pixels
intacts) : **40 à 71 % de la forêt intacte est « détectée »**. Sans filtre, la chaîne
n'est pas utilisable ; SUFOSAT filtre toujours (M24, § II-B.1, p. 13746).

### Distribution des erreurs (chute −6 dB, fenêtre 3)

| cadence | xb | −1 | 0 (exacte) | +1 | +2 | > +2 |
|---|---|---|---|---|---|---|
| 12 j | Inf | 0,0 | 15,6 | 13,0 | 8,9 | 62,5 |
| 12 j | 5 | 0,0 | 96,4 | 3,1 | 0,5 | 0,0 |
| 12 j | 10 | 0,0 | 77,9 | 15,1 | 4,7 | 2,3 |
| 12 j | 20 | 0,0 | 52,3 | 20,7 | 11,0 | 16,0 |
| 6 j | Inf | 0,0 | 11,2 | 8,4 | 6,3 | 74,0 |
| 6 j | 5 | 0,0 | 95,5 | 4,4 | 0,1 | 0,0 |

(en % des 3 420 pixels coupés ; aucune erreur négative avec filtre, dans aucun cas)

### Règles de date alternatives (hors package, calculées par le script)

Même minimum, même détection ; seule change la date rendue : premier `d_i` dont le ratio
passe sous `ts` (ou sous `tp`), date rendue `d_(i+1)`, à défaut la date du minimum.
Fenêtre 3.

| cad. (j) | chute (dB) | xb | argmin (package) exacte % | 1er passage sous ts : exacte % | … précoce % | 1er passage sous tp : exacte % | … précoce % |
|---|---|---|---|---|---|---|---|
| 12 | -3 | Inf | 10.6 [9.6 ; 11.7] | 10.6 | 0.0 | 17.4 | 0.0 |
| 12 | -3 | 5 | 82.1 [80.8 ; 83.3] | 82.1 | 1.4 | 83.1 | 1.5 |
| 12 | -4.5 | Inf | 13.6 [12.5 ; 14.8] | 14.8 | 0.0 | 96.8 | 2.5 |
| 12 | -4.5 | 5 | 92.4 [91.4 ; 93.2] | 92.5 | 0.0 | 94.8 | 4.3 |
| 12 | -6 | Inf | 15.6 [14.4 ; 16.9] | 97.5 | 0.0 | 78.2 | 21.8 |
| 12 | -6 | 5 | 96.4 [95.7 ; 97.0] | 98.9 | 0.0 | 75.9 | 24.1 |
| 6 | -3 | Inf | 7.0 [6.2 ; 7.9] | 7.0 | 0.0 | 15.9 | 0.0 |
| 6 | -3 | 5 | 81.0 [79.6 ; 82.2] | 81.0 | 1.3 | 81.7 | 1.3 |
| 6 | -4.5 | Inf | 9.3 [8.4 ; 10.3] | 11.3 | 0.0 | 97.6 | 2.0 |
| 6 | -4.5 | 5 | 90.8 [89.8 ; 91.8] | 91.0 | 0.1 | 95.2 | 4.4 |
| 6 | -6 | Inf | 11.2 [10.2 ; 12.3] | 98.7 | 0.0 | 79.6 | 20.4 |
| 6 | -6 | 5 | 95.5 [94.7 ; 96.1] | 99.4 | 0.0 | 75.3 | 24.7 |

Aucune règle de « premier passage » n'est bonne partout : sous `ts`, elle date bien les
chutes de −6 dB même avec `xb = Inf` (97,5 %) mais pas celles de −4,5 dB (14,8 %), dont le
ratio passe rarement sous `ts` ; sous `tp`, elle date bien −4,5 dB (96,8 %) mais avance
d'une acquisition un pixel sur cinq à −6 dB (21,8 % précoces). Un `xb` fini, lui, améliore
les trois amplitudes.

### Contrôle : effet de la fin de série (12 j, −6 dB, fenêtre 3, autre tirage)

| fin de série | xb | n | exacte % [IC] | ±1 % [IC] |
| --- | --- | --- | --- | --- |
| 2020-12-31 | Inf | 3420 | 20.3 [18.9 ; 21.6] | 31.7 [30.2 ; 33.3] |
| 2020-12-31 | 5 | 3420 | 97.0 [96.4 ; 97.5] | 99.8 [99.6 ; 99.9] |
| 2021-06-30 | Inf | 3420 | 18.6 [17.3 ; 19.9] | 29.0 [27.5 ; 30.5] |
| 2021-06-30 | 5 | 3420 | 97.0 [96.4 ; 97.5] | 99.8 [99.6 ; 99.9] |
| 2021-12-31 | Inf | 3420 | 18.3 [17.0 ; 19.6] | 28.7 [27.2 ; 30.2] |

Avec `xb = Inf`, la date exacte baisse un peu quand la série s'allonge (20,3 % → 18,3 %,
effet faible, du sens attendu par la cause n° 1) ; avec `xb = 5`, elle ne bouge pas (97,0 %
pour les trois fins). C'est aussi une piste pour l'écart avec le chiffre du dev en 007
(24 % filtré, 9 % brut, 40 × 40 pixels, réglage non rejoué) : ce rapport trouve 15,6 % et
7,1 % sur une série 2018-2021, 20,3 % sur une série qui s'arrête fin 2020. Même ordre de
grandeur ; l'écart restant n'est pas expliqué ici.

### Graphiques (non versionnés)

Écrits par le script dans le dossier passé en argument (ici
`/tmp/claude-0/-home-user/b63c98e0-2e08-5ea7-ab25-6043906217f2/scratchpad/`) :

- `precision-date-erreurs.png` : histogrammes de l'erreur de date (en acquisitions, de ≤ −3
  à ≥ 8), chute −6 dB, fenêtre 3, une case par cadence (lignes) et par `xb` (colonnes).
  Avec `xb = Inf`, la masse est étalée de 0 à « ≥ 8 », avec une barre ≥ 8 de 28 % (12 j) et
  46 % (6 j) ; avec `xb = 5`, une seule barre à 0 (≈ 96 %) ; `xb = 10` et `20` : pic à 0
  et queue à droite seulement.
- `precision-date-profils.png` : RCR moyen des pixels coupés autour de la coupe (j = 0 :
  `d_k`, dernière image avant la chute), un trait par `xb`, seuils `ts` et `tp` en
  pointillés. Les quatre courbes se confondent jusqu'à j = 0 (0, −1,3, −3,1, −6,0 dB) ;
  après, `xb = Inf` reste à plat vers −5,9 dB, `xb = 5` remonte de 0,7 dB par image et
  revient à 0 à j = 5, `xb = 10` remonte de 0,3 dB par image, `xb = 20` de 0,15 dB.

## Les causes de l'imprécision

Effet étudié : « la date du minimum n'est pas la première image qui montre la chute ».
Classement par causes (Ishikawa réduit aux branches que la simulation peut toucher :
méthode, mesure, matière).

### Cause n° 1 (méthode) — `xb = Inf` laisse le ratio à plat après la coupe

*Pourquoi la date est-elle tardive ?* Parce que le minimum tombe sur une date après `d_k`.
*Pourquoi ?* Parce que les ratios des dates suivantes valent presque autant que celui de
`d_k`. *Pourquoi ?* Parce que `Ma` reste dans la partie coupée et que `Mb`, moyenne de
**toutes** les images antérieures, ne bouge presque pas quand on lui ajoute une image
coupée. Le speckle choisit alors le minimum parmi des dizaines de dates presque égales.

Raisonnement vérifiable. Avec une chute d'un facteur `a` (−6 dB : a = 0,251) et `Mb` sur
`n` images, le ratio remonte, de `d_k` à `d_(k+1)`, de
`Δ = −10·log10(1 − (1 − a)/n)` dB :

| xb | Δ calculé (−6 dB) | Δ lu sur le profil moyen (12 j) | date exacte (12 j, fenêtre 3) |
|---|---|---|---|
| 5 | 0,71 dB | 0,68 dB | 96,4 % |
| 10 | 0,34 dB | 0,31 dB | 77,9 % |
| 20 | 0,17 dB | 0,14 dB | 52,3 % |
| Inf (≈ 75 images avant la coupe à 12 j) | 0,04 dB | 0,01 dB | 15,6 % |

Faits qui la confirment : la date exacte décroît avec `xb` dans les 18 cas filtrés ; les
erreurs sont toutes tardives (aucune erreur négative avec filtre) ; avec `xb = Inf`, la
précision dépend un peu de la longueur de série après la coupe, pas avec `xb = 5`. À 6 j,
`Mb` compte deux fois plus d'images avant la coupe : le plateau est encore plus plat et la
date encore moins exacte (11,2 % contre 15,6 %), ce qui va dans le même sens.

### Cause n° 2 (matière, mesure) — le bruit résiduel du ratio d'une date à l'autre

Les fenêtres `Ma` de deux dates voisines ne diffèrent que d'une image entrée et d'une image
sortie : l'écart-type du saut de ratio dû au speckle vaut `4,343·√(2 / (9·ENL_eff))` dB,
soit 0,98 dB sans filtre (ENL 4,4), 0,33 dB en fenêtre 3, 0,19 dB en fenêtre 5 (ENL × 9 et
× 25 si le speckle est indépendant). Mesuré par le contrôle de l'analyste : 0,97, 0,34 et
0,20 dB. La date est juste quand `Δ` (cause n° 1) dépasse nettement ce bruit : `xb = 5`
donne 56,7 % sans filtre, 96,4 % en fenêtre 3, 99,8 % en fenêtre 5 (12 j, −6 dB). Le noyau
K du filtre n'aide pas : il s'annule dans le ratio (constat de 007, confirmé ici : l'ENL
d'une image filtrée en fenêtre 3 n'est que de 30, mais le bruit du ratio suit 9 × 4,4).

### Cause n° 3 (matière) — le contraste de la chute

`Δ` est proportionnel à `1 − a` : à `xb = 5`, 0,71 dB pour −6 dB, 0,58 dB pour −4,5 dB,
0,46 dB pour −3 dB ; la date exacte passe de 96 à 92 puis 82 % (fenêtre 3, 12 j). C'est
une propriété de la coupe, pas un réglage : on ne peut pas agir dessus.

### Hypothèse écartée — la règle `d_(i+1)`

Elle n'est **pas** une cause d'imprécision dans cette simulation : avec filtre, aucune date
n'est trop précoce, et prendre `d_i` décalerait toutes les dates d'une acquisition (date
exacte proche de 0 %). Limite : la simulation pose la vérité sur `d_(k+1)` ; sur le
terrain, la coupe a lieu entre `d_k` et `d_(k+1)` (B18, § 2.3.2, p. 11) et le choix de la
borne ne se tranchera qu'à la comparaison avec la v3.0.1 (jalon 2), comme décidé en 004.

### Le délai de détection de M24 (12 à 24 jours)

C'est une autre grandeur que la précision : le ratio de `d_k` demande `xa = 3` images après
`d_k`, donc deux images après la première qui montre la chute, soit 24 jours à 12 j et 12
jours à 6 j : c'est la fourchette de M24 (p. 13747). Avec `xb` fini, la date ne bouge plus
une fois ces images arrivées (le ratio remonte ensuite) ; avec `xb = Inf`, le minimum peut
encore glisser vers des dates plus tardives à chaque nouvelle image. Ce point est lu sur le
raisonnement et le profil, pas mesuré en temps quasi réel.

## Proposition de réglage

1. **Rendre `xb` fini.** Dans la simulation, `xb = 5` est le meilleur des quatre réglages
   dans les 12 cas filtrés : à fenêtre 3, date exacte 91 à 96 % (contre 9 à 16 % pour
   `Inf`) et ±1 acquisition 99 % ou plus (contre 17 à 29 %), sans perte de détection ni
   fausse alerte (0/3 420). Le coût d'un `xb` court n'apparaît pas ici, car la simulation
   n'a ni saisonnalité ni événement passager (pluie, gel, neige) : le 1er centile du ratio
   minimal en forêt intacte baisse seulement de −1,66 dB (`Inf`) à −2,00 dB (`xb = 5`),
   encore à 3,2 dB de `ts`. Sur données réelles, cette marge peut fondre.
   - **Valeur provisoire proposée : `xb = 5`**, avec `xb = 10` en repli (exacte 77 à 78 %,
     ±1 acquisition 93 %, à −6 dB) si le jalon 2 montre des fausses alertes dues à un `Mb`
     trop court. M24 ne donne pas `xb` (table 001 : ND) : le réglage reste un paramètre
     exposé, comme le veut la règle du projet.
   - Variante, si Pascal tient à `xb = Inf` pour la détection (fidélité à B18) : détecter
     avec `xb = Inf`, puis **dater** avec un second calcul à `xb = 5`. Dans la simulation,
     la détection est la même (98 à 100 % des pixels coupés pour les deux) : la date
     obtenue serait celle de `xb = 5`. Cela coûte un second passage de `rcr_compute()` et
     un choix de code que je ne fais pas.
2. **Garder la règle `d_(i+1)`** et la règle « date du minimum » : la simulation ne les met
   pas en cause. Les règles de « premier passage » sous `ts` ou `tp` ne sont pas meilleures
   partout (tableau plus haut).
3. **Ne jamais lancer la détection sans filtre** (fenêtre ≥ 3) : sans filtre, 40 à 71 % de
   la forêt intacte est détectée.
4. **À mesurer au jalon 2** sur la v3.0.1 : date exacte et ±1 acquisition pour `xb` ∈
   {5, 10, Inf}, avec les fausses alertes, en été comme en hiver.

## Limites

- **Speckle indépendant** entre pixels voisins : sur une image Sentinel-1 réelle, le
  speckle est corrélé dans l'espace et le gain du filtre est inférieur à × 9 ; le bruit du
  ratio sera plus fort que 0,33 dB et les taux de date exacte plus bas.
- **Pas de saisonnalité ni d'événement passager** (humidité, gel, neige, vent) : c'est ce
  qui peut pénaliser un `xb` court. La simulation ne peut pas mesurer ce coût.
- **Forêt homogène**, une seule orbite, aucune image manquante, ENL 4,4 supposé (valeur B18
  avant filtre, en VV ; SUFOSAT utilise VH).
- **Coupe en une seule fois, en bloc de 34 ha, sans repousse** : une coupe étalée sur
  plusieurs acquisitions n'a pas de « date exacte » ; un grand bloc rend la détection par
  segmentation triviale (100 %) ; une petite coupe dépendrait plus des graines (à −4,5 dB,
  fenêtre 3, seuls 9 à 24 % des pixels coupés sont des graines).
- **Un seul tirage par cas** ; l'intervalle de Wilson sur n surestime la précision des
  cas filtrés (voir « Incertitudes ») : les écarts entre `xb` (plan apparié, 15 à 80
  points) sont sûrs, les niveaux absolus le sont à quelques points près.
- La vérité de la simulation est `d_(k+1)` : elle ne peut pas trancher entre `d_i` et
  `d_(i+1)`.

## Question de contrôle : quelles sont les deux ou trois causes sur lesquelles agir ?

1. **`xb = Inf`** : le ratio reste à plat après la coupe et le speckle choisit la date
   (Δ de 0,04 dB contre 0,71 dB à `xb = 5`). Levier : `xb` fini (5 proposé, 10 en repli),
   ou une date calculée à part avec `xb` fini.
2. **Le bruit résiduel du ratio** (0,98 dB sans filtre, 0,33 dB en fenêtre 3). Levier :
   garder le filtre ; la fenêtre 5 n'est pas sourcée (M24 : 3 × 3), elle n'est donc pas
   proposée, seulement mesurée.
3. Le contraste de la chute pèse aussi, mais **on ne peut pas agir dessus** ; la règle
   `d_(i+1)` n'est pas une cause.

## Ligne de journal proposée

2026-11-22 · analyste · 008 · Rendu (donner) : docs/analyses/precision-date.R (72 cas
simulés, graine fixée, ≈ 45 s) et precision-date.md ; **simulation, pas une mesure** ;
fenêtre 3, chute −6 dB, 12 j : date exacte 15,6 % avec xb = Inf contre 96,4 % avec
xb = 5 (±1 acquisition 28,6 % contre 99,5 %), sans fausse alerte (0/3 420) ni perte de
détection ; causes : (1) xb = Inf laisse le ratio à plat après la coupe (Δ 0,04 dB contre
0,71 dB), (2) bruit résiduel du ratio (0,98 dB sans filtre, 0,33 dB filtré), (3) contraste
de la chute (non réglable) ; règle d_(i+1) non en cause ; proposition : xb = 5 provisoire
(10 en repli), ou date calculée à part avec xb fini ; limites : speckle indépendant, ni
saisonnalité ni événement passager (coût d'un xb court non mesuré) ; à trancher par
l'orchestrateur, à vérifier au jalon 2.

## Annexe : table complète des 72 cas (sortie du script)

« ts-1er » et « tp-1er » : règles de date alternatives (premier passage sous `ts` ou
`tp`). « intact <= tp » : part des pixels intacts dont le ratio minimal est sous `tp`.

| cad. (j) | chute (dB) | fen. | xb | n coupe | exacte % [IC] | IC sur n_eff = n / fen.^2 | ±1 % [IC] | ±2 % | biais méd. (acq.) | err. moy. (j) | graine % | détecté % | exacte parmi détectés % | FA graine % (n intact) | intact <= tp % | FA détecté % | q1 % RCR min intact (dB) | ts-1er exacte % | ts-1er ±1 % | ts-1er précoce % | tp-1er exacte % | tp-1er précoce % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 12 | -3 | 1 | Inf | 3420 | 5.2 [4.5 ; 6.0] | [4.5 ; 6.0] (n_eff 3420) | 9.6 [8.7 ; 10.7] | 13.1 | 14 | 205.5 | 63.3 | 99.9 | 5.2 | 2.2 (3420) | 42.6 | 40.1 | -5.56 | 7.0 | 13.3 | 3.4 | 22.6 | 34.6 |
| 12 | -3 | 1 | 5 | 3420 | 20.1 [18.8 ; 21.5] | [18.8 ; 21.5] (n_eff 3420) | 35.9 [34.3 ; 37.6] | 43.9 | 0 | 148.3 | 19.5 | 88.6 | 21.6 | 7.0 (3420) | 71.1 | 71.1 | -6.16 | 20.7 | 36.3 | 34.5 | 17.0 | 59.2 |
| 12 | -3 | 1 | 10 | 3420 | 18.0 [16.7 ; 19.3] | [16.7 ; 19.3] (n_eff 3420) | 33.2 [31.6 ; 34.8] | 43.1 | 1 | 112.9 | 20.4 | 89.3 | 19.2 | 3.9 (3420) | 56.5 | 56.3 | -5.88 | 18.7 | 34.0 | 24.5 | 20.3 | 48.2 |
| 12 | -3 | 1 | 20 | 3420 | 13.8 [12.7 ; 15.0] | [12.7 ; 15.0] (n_eff 3420) | 26.4 [25.0 ; 27.9] | 35.1 | 3 | 97.1 | 26.6 | 94.2 | 14.2 | 2.9 (3420) | 48.3 | 46.7 | -5.70 | 14.7 | 27.6 | 13.9 | 21.5 | 40.4 |
| 12 | -3 | 3 | Inf | 3420 | 10.6 [9.6 ; 11.7] | [7.8 ; 14.0] (n_eff 380) | 20.0 [18.7 ; 21.4] | 27.3 | 6 | 107.3 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.66 | 10.6 | 20.0 | 0.0 | 17.4 | 0.0 |
| 12 | -3 | 3 | 5 | 3420 | 82.1 [80.8 ; 83.3] | [77.9 ; 85.6] (n_eff 380) | 95.4 [94.6 ; 96.0] | 98.5 | 0 | 3.0 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -2.00 | 82.1 | 95.4 | 1.4 | 83.1 | 1.5 |
| 12 | -3 | 3 | 10 | 3420 | 59.5 [57.8 ; 61.1] | [54.5 ; 64.3] (n_eff 380) | 80.5 [79.2 ; 81.8] | 89.9 | 0 | 9.1 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.86 | 59.5 | 80.5 | 0.4 | 61.5 | 0.4 |
| 12 | -3 | 3 | 20 | 3420 | 38.0 [36.4 ; 39.7] | [33.4 ; 43.1] (n_eff 380) | 58.2 [56.6 ; 59.9] | 69.7 | 1 | 21.7 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.74 | 38.0 | 58.2 | 0.1 | 41.5 | 0.2 |
| 12 | -3 | 5 | Inf | 3420 | 16.6 [15.4 ; 17.9] | [11.5 ; 24.1] (n_eff 136) | 30.3 [28.7 ; 31.8] | 38.7 | 4 | 65.0 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.10 | 16.6 | 30.3 | 0.0 | 17.4 | 0.0 |
| 12 | -3 | 5 | 5 | 3420 | 95.7 [95.0 ; 96.3] | [90.7 ; 98.0] (n_eff 136) | 99.2 [98.8 ; 99.4] | 100.0 | 0 | 0.6 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.31 | 95.7 | 99.2 | 0.1 | 95.8 | 0.1 |
| 12 | -3 | 5 | 10 | 3420 | 79.1 [77.7 ; 80.4] | [71.9 ; 85.4] (n_eff 136) | 92.9 [92.0 ; 93.7] | 97.5 | 0 | 3.7 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.20 | 79.1 | 92.9 | 0.1 | 79.4 | 0.1 |
| 12 | -3 | 5 | 20 | 3420 | 52.7 [51.0 ; 54.3] | [44.6 ; 61.1] (n_eff 136) | 73.0 [71.4 ; 74.4] | 82.3 | 0 | 13.3 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.15 | 52.7 | 73.0 | 0.0 | 52.9 | 0.0 |
| 12 | -4.5 | 1 | Inf | 3420 | 6.3 [5.5 ; 7.2] | [5.5 ; 7.2] (n_eff 3420) | 10.9 [9.9 ; 12.0] | 14.7 | 13 | 190.5 | 99.5 | 100.0 | 6.3 | 2.2 (3420) | 42.6 | 40.1 | -5.56 | 29.6 | 44.9 | 4.7 | 42.8 | 45.8 |
| 12 | -4.5 | 1 | 5 | 3420 | 41.1 [39.5 ; 42.8] | [39.5 ; 42.8] (n_eff 3420) | 62.3 [60.7 ; 63.9] | 72.5 | 0 | 66.4 | 49.5 | 97.2 | 41.8 | 7.0 (3420) | 71.1 | 71.1 | -6.16 | 44.7 | 64.2 | 22.3 | 27.5 | 63.4 |
| 12 | -4.5 | 1 | 10 | 3420 | 31.3 [29.8 ; 32.9] | [29.8 ; 32.9] (n_eff 3420) | 51.5 [49.8 ; 53.2] | 64.2 | 1 | 45.3 | 59.9 | 98.6 | 31.6 | 3.9 (3420) | 56.5 | 56.3 | -5.88 | 39.6 | 59.1 | 13.0 | 35.6 | 53.5 |
| 12 | -4.5 | 1 | 20 | 3420 | 20.0 [18.7 ; 21.4] | [18.7 ; 21.4] (n_eff 3420) | 35.4 [33.8 ; 37.0] | 46.2 | 3 | 52.1 | 75.4 | 99.8 | 20.0 | 2.9 (3420) | 48.3 | 46.7 | -5.70 | 33.6 | 50.4 | 7.2 | 38.9 | 49.6 |
| 12 | -4.5 | 3 | Inf | 3420 | 13.6 [12.5 ; 14.8] | [10.6 ; 17.5] (n_eff 380) | 25.0 [23.6 ; 26.5] | 33.4 | 5 | 83.2 | 23.5 | 100.0 | 13.6 | 0.0 (3420) | 0.0 | 0.0 | -1.66 | 14.8 | 26.3 | 0.0 | 96.8 | 2.5 |
| 12 | -4.5 | 3 | 5 | 3420 | 92.4 [91.4 ; 93.2] | [89.3 ; 94.6] (n_eff 380) | 98.8 [98.4 ; 99.1] | 99.9 | 0 | 1.1 | 9.5 | 97.7 | 92.5 | 0.0 (3420) | 0.0 | 0.0 | -2.00 | 92.5 | 98.8 | 0.0 | 94.8 | 4.3 |
| 12 | -4.5 | 3 | 10 | 3420 | 70.9 [69.4 ; 72.4] | [66.3 ; 75.4] (n_eff 380) | 89.3 [88.2 ; 90.3] | 95.8 | 0 | 5.4 | 9.0 | 99.6 | 70.9 | 0.0 (3420) | 0.0 | 0.0 | -1.86 | 71.5 | 89.4 | 0.0 | 96.0 | 3.0 |
| 12 | -4.5 | 3 | 20 | 3420 | 47.1 [45.5 ; 48.8] | [42.1 ; 52.1] (n_eff 380) | 67.8 [66.2 ; 69.3] | 78.9 | 1 | 15.5 | 9.6 | 100.0 | 47.1 | 0.0 (3420) | 0.0 | 0.0 | -1.74 | 47.8 | 68.1 | 0.0 | 96.6 | 2.6 |
| 12 | -4.5 | 5 | Inf | 3420 | 21.2 [19.9 ; 22.6] | [15.3 ; 28.9] (n_eff 136) | 37.5 [35.8 ; 39.1] | 46.5 | 3 | 48.0 | 1.1 | 100.0 | 21.2 | 0.0 (3420) | 0.0 | 0.0 | -1.10 | 21.2 | 37.5 | 0.0 | 99.9 | 0.1 |
| 12 | -4.5 | 5 | 5 | 3420 | 99.4 [99.1 ; 99.6] | [96.0 ; 99.9] (n_eff 136) | 99.9 [99.8 ; 100.0] | 100.0 | 0 | 0.1 | 1.8 | 99.7 | 99.4 | 0.0 (3420) | 0.0 | 0.0 | -1.31 | 99.4 | 99.9 | 0.0 | 99.5 | 0.4 |
| 12 | -4.5 | 5 | 10 | 3420 | 89.1 [88.0 ; 90.1] | [82.6 ; 93.2] (n_eff 136) | 97.7 [97.1 ; 98.1] | 99.4 | 0 | 1.7 | 0.6 | 99.9 | 89.1 | 0.0 (3420) | 0.0 | 0.0 | -1.20 | 89.1 | 97.7 | 0.0 | 99.8 | 0.2 |
| 12 | -4.5 | 5 | 20 | 3420 | 64.4 [62.8 ; 66.0] | [56.4 ; 72.2] (n_eff 136) | 83.1 [81.8 ; 84.3] | 91.0 | 0 | 7.9 | 0.6 | 100.0 | 64.4 | 0.0 (3420) | 0.0 | 0.0 | -1.15 | 64.4 | 83.1 | 0.0 | 100.0 | 0.0 |
| 12 | -6 | 1 | Inf | 3420 | 7.1 [6.3 ; 8.0] | [6.3 ; 8.0] (n_eff 3420) | 12.0 [10.9 ; 13.1] | 16.4 | 12 | 176.5 | 100.0 | 100.0 | 7.1 | 2.2 (3420) | 42.6 | 40.1 | -5.56 | 68.0 | 85.8 | 11.0 | 40.6 | 58.7 |
| 12 | -6 | 1 | 5 | 3420 | 56.7 [55.1 ; 58.4] | [55.1 ; 58.4] (n_eff 3420) | 79.6 [78.2 ; 80.9] | 89.4 | 0 | 21.3 | 83.2 | 99.9 | 56.8 | 7.0 (3420) | 71.1 | 71.1 | -6.16 | 65.8 | 84.6 | 18.7 | 28.5 | 70.0 |
| 12 | -6 | 1 | 10 | 3420 | 39.2 [37.6 ; 40.9] | [37.6 ; 40.9] (n_eff 3420) | 60.2 [58.6 ; 61.8] | 73.3 | 1 | 22.1 | 93.0 | 100.0 | 39.2 | 3.9 (3420) | 56.5 | 56.3 | -5.88 | 65.9 | 84.1 | 13.0 | 35.1 | 63.7 |
| 12 | -6 | 1 | 20 | 3420 | 24.0 [22.6 ; 25.4] | [22.6 ; 25.4] (n_eff 3420) | 39.9 [38.3 ; 41.5] | 51.7 | 2 | 39.1 | 98.5 | 100.0 | 24.0 | 2.9 (3420) | 48.3 | 46.7 | -5.70 | 65.8 | 83.6 | 11.7 | 38.8 | 60.4 |
| 12 | -6 | 3 | Inf | 3420 | 15.6 [14.4 ; 16.9] | [12.2 ; 19.5] (n_eff 380) | 28.6 [27.1 ; 30.1] | 37.5 | 4 | 69.4 | 100.0 | 100.0 | 15.6 | 0.0 (3420) | 0.0 | 0.0 | -1.66 | 97.5 | 99.1 | 0.0 | 78.2 | 21.8 |
| 12 | -6 | 3 | 5 | 3420 | 96.4 [95.7 ; 97.0] | [93.9 ; 97.8] (n_eff 380) | 99.5 [99.2 ; 99.7] | 100.0 | 0 | 0.5 | 93.5 | 100.0 | 96.4 | 0.0 (3420) | 0.0 | 0.0 | -2.00 | 98.9 | 99.8 | 0.0 | 75.9 | 24.1 |
| 12 | -6 | 3 | 10 | 3420 | 77.9 [76.4 ; 79.2] | [73.5 ; 81.8] (n_eff 380) | 93.0 [92.1 ; 93.8] | 97.7 | 0 | 3.8 | 97.4 | 100.0 | 77.9 | 0.0 (3420) | 0.0 | 0.0 | -1.86 | 97.3 | 98.6 | 0.0 | 77.8 | 22.2 |
| 12 | -6 | 3 | 20 | 3420 | 52.3 [50.6 ; 54.0] | [47.3 ; 57.3] (n_eff 380) | 73.0 [71.5 ; 74.5] | 84.0 | 0 | 12.4 | 99.7 | 100.0 | 52.3 | 0.0 (3420) | 0.0 | 0.0 | -1.74 | 96.8 | 98.2 | 0.0 | 77.8 | 22.2 |
| 12 | -6 | 5 | Inf | 3420 | 24.3 [22.9 ; 25.7] | [17.8 ; 32.1] (n_eff 136) | 41.5 [39.9 ; 43.2] | 51.1 | 2 | 40.8 | 100.0 | 100.0 | 24.3 | 0.0 (3420) | 0.0 | 0.0 | -1.10 | 99.9 | 100.0 | 0.0 | 90.2 | 9.8 |
| 12 | -6 | 5 | 5 | 3420 | 99.8 [99.5 ; 99.9] | [97.3 ; 100.0] (n_eff 136) | 100.0 [99.9 ; 100.0] | 100.0 | 0 | 0.0 | 98.7 | 100.0 | 99.8 | 0.0 (3420) | 0.0 | 0.0 | -1.31 | 99.9 | 100.0 | 0.0 | 86.8 | 13.2 |
| 12 | -6 | 5 | 10 | 3420 | 93.9 [93.1 ; 94.7] | [88.8 ; 97.0] (n_eff 136) | 99.2 [98.9 ; 99.5] | 99.9 | 0 | 0.8 | 99.6 | 100.0 | 93.9 | 0.0 (3420) | 0.0 | 0.0 | -1.20 | 99.9 | 100.0 | 0.0 | 88.9 | 11.1 |
| 12 | -6 | 5 | 20 | 3420 | 70.7 [69.2 ; 72.2] | [62.4 ; 77.6] (n_eff 136) | 87.5 [86.4 ; 88.6] | 94.3 | 0 | 5.9 | 100.0 | 100.0 | 70.7 | 0.0 (3420) | 0.0 | 0.0 | -1.15 | 99.8 | 99.9 | 0.0 | 89.5 | 10.5 |
| 6 | -3 | 1 | Inf | 3420 | 2.4 [1.9 ; 2.9] | [1.9 ; 2.9] (n_eff 3420) | 4.9 [4.2 ; 5.7] | 6.9 | 31 | 214.6 | 85.9 | 100.0 | 2.4 | 3.9 (3420) | 67.0 | 67.0 | -5.77 | 5.4 | 10.6 | 3.5 | 18.0 | 47.6 |
| 6 | -3 | 1 | 5 | 3420 | 16.5 [15.3 ; 17.8] | [15.3 ; 17.8] (n_eff 3420) | 28.3 [26.8 ; 29.8] | 33.9 | 0 | 175.9 | 26.6 | 97.1 | 16.8 | 13.7 (3420) | 92.1 | 92.1 | -6.47 | 17.1 | 28.7 | 38.4 | 9.4 | 77.0 |
| 6 | -3 | 1 | 10 | 3420 | 15.3 [14.1 ; 16.5] | [14.1 ; 16.5] (n_eff 3420) | 28.2 [26.7 ; 29.7] | 36.1 | 1 | 134.1 | 24.8 | 95.1 | 15.8 | 7.9 (3420) | 82.6 | 82.6 | -6.12 | 16.2 | 29.3 | 29.3 | 13.3 | 64.8 |
| 6 | -3 | 1 | 20 | 3420 | 11.3 [10.3 ; 12.5] | [10.3 ; 12.5] (n_eff 3420) | 22.8 [21.4 ; 24.2] | 31.3 | 3 | 96.7 | 29.7 | 97.2 | 11.4 | 5.7 (3420) | 74.9 | 74.9 | -5.87 | 12.7 | 24.7 | 19.1 | 15.8 | 56.4 |
| 6 | -3 | 3 | Inf | 3420 | 7.0 [6.2 ; 7.9] | [4.9 ; 10.1] (n_eff 380) | 13.1 [12.0 ; 14.3] | 17.6 | 11 | 102.3 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.72 | 7.0 | 13.1 | 0.0 | 15.9 | 0.0 |
| 6 | -3 | 3 | 5 | 3420 | 81.0 [79.6 ; 82.2] | [76.8 ; 84.7] (n_eff 380) | 95.8 [95.1 ; 96.4] | 98.9 | 0 | 1.9 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -2.09 | 81.0 | 95.8 | 1.3 | 81.7 | 1.3 |
| 6 | -3 | 3 | 10 | 3420 | 59.7 [58.1 ; 61.4] | [54.7 ; 64.5] (n_eff 380) | 80.7 [79.4 ; 82.0] | 89.7 | 0 | 4.5 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.93 | 59.7 | 80.7 | 0.2 | 61.4 | 0.3 |
| 6 | -3 | 3 | 20 | 3420 | 39.6 [37.9 ; 41.2] | [34.7 ; 44.5] (n_eff 380) | 60.4 [58.7 ; 62.0] | 71.5 | 1 | 10.1 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.83 | 39.6 | 60.4 | 0.1 | 42.9 | 0.2 |
| 6 | -3 | 5 | Inf | 3420 | 11.4 [10.4 ; 12.5] | [7.4 ; 18.3] (n_eff 136) | 20.8 [19.5 ; 22.2] | 26.9 | 6 | 58.2 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.14 | 11.4 | 20.8 | 0.0 | 12.4 | 0.0 |
| 6 | -3 | 5 | 5 | 3420 | 94.0 [93.1 ; 94.7] | [88.8 ; 97.0] (n_eff 136) | 99.8 [99.5 ; 99.9] | 99.9 | 0 | 0.4 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.41 | 94.0 | 99.8 | 0.1 | 94.0 | 0.1 |
| 6 | -3 | 5 | 10 | 3420 | 79.8 [78.4 ; 81.1] | [71.9 ; 85.4] (n_eff 136) | 95.0 [94.2 ; 95.7] | 98.2 | 0 | 1.7 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.30 | 79.8 | 95.0 | 0.0 | 80.1 | 0.0 |
| 6 | -3 | 5 | 20 | 3420 | 55.6 [53.9 ; 57.3] | [47.5 ; 64.0] (n_eff 136) | 78.5 [77.1 ; 79.9] | 87.8 | 0 | 5.3 | 0.0 | 0.0 | - | 0.0 (3420) | 0.0 | 0.0 | -1.25 | 55.6 | 78.5 | 0.0 | 56.1 | 0.0 |
| 6 | -4.5 | 1 | Inf | 3420 | 3.2 [2.6 ; 3.8] | [2.6 ; 3.8] (n_eff 3420) | 5.9 [5.2 ; 6.8] | 8.2 | 27 | 193.3 | 100.0 | 100.0 | 3.2 | 3.9 (3420) | 67.0 | 67.0 | -5.77 | 29.0 | 45.1 | 6.1 | 34.7 | 55.6 |
| 6 | -4.5 | 1 | 5 | 3420 | 36.7 [35.1 ; 38.3] | [35.1 ; 38.3] (n_eff 3420) | 55.4 [53.7 ; 57.1] | 63.7 | 0 | 89.2 | 54.1 | 99.4 | 36.9 | 13.7 (3420) | 92.1 | 92.1 | -6.47 | 39.4 | 56.7 | 27.3 | 14.9 | 80.0 |
| 6 | -4.5 | 1 | 10 | 3420 | 30.2 [28.7 ; 31.8] | [28.7 ; 31.8] (n_eff 3420) | 49.1 [47.4 ; 50.8] | 60.6 | 1 | 49.2 | 60.3 | 99.5 | 30.4 | 7.9 (3420) | 82.6 | 82.6 | -6.12 | 37.3 | 56.0 | 16.8 | 23.0 | 69.3 |
| 6 | -4.5 | 1 | 20 | 3420 | 19.9 [18.6 ; 21.3] | [18.6 ; 21.3] (n_eff 3420) | 34.8 [33.2 ; 36.4] | 45.9 | 3 | 34.9 | 75.7 | 99.9 | 19.9 | 5.7 (3420) | 74.9 | 74.9 | -5.87 | 32.8 | 49.6 | 9.7 | 28.0 | 63.2 |
| 6 | -4.5 | 3 | Inf | 3420 | 9.3 [8.4 ; 10.3] | [6.7 ; 12.5] (n_eff 380) | 16.7 [15.5 ; 18.0] | 22.5 | 8 | 76.3 | 35.5 | 100.0 | 9.3 | 0.0 (3420) | 0.0 | 0.0 | -1.72 | 11.3 | 18.5 | 0.0 | 97.6 | 2.0 |
| 6 | -4.5 | 3 | 5 | 3420 | 90.8 [89.8 ; 91.8] | [87.5 ; 93.3] (n_eff 380) | 99.3 [98.9 ; 99.5] | 100.0 | 0 | 0.6 | 10.1 | 98.9 | 90.9 | 0.0 (3420) | 0.0 | 0.0 | -2.09 | 91.0 | 99.3 | 0.1 | 95.2 | 4.4 |
| 6 | -4.5 | 3 | 10 | 3420 | 70.8 [69.3 ; 72.3] | [66.0 ; 75.1] (n_eff 380) | 89.4 [88.3 ; 90.3] | 95.4 | 0 | 2.7 | 8.4 | 99.8 | 71.0 | 0.0 (3420) | 0.0 | 0.0 | -1.93 | 71.2 | 89.5 | 0.0 | 96.6 | 2.7 |
| 6 | -4.5 | 3 | 20 | 3420 | 47.8 [46.2 ; 49.5] | [42.9 ; 52.9] (n_eff 380) | 69.4 [67.8 ; 70.9] | 80.1 | 1 | 7.3 | 9.4 | 100.0 | 47.8 | 0.0 (3420) | 0.0 | 0.0 | -1.83 | 48.7 | 69.7 | 0.0 | 97.1 | 2.5 |
| 6 | -4.5 | 5 | Inf | 3420 | 14.2 [13.1 ; 15.4] | [9.1 ; 20.8] (n_eff 136) | 25.7 [24.3 ; 27.2] | 33.1 | 5 | 43.2 | 1.8 | 100.0 | 14.2 | 0.0 (3420) | 0.0 | 0.0 | -1.14 | 14.3 | 25.8 | 0.0 | 99.9 | 0.1 |
| 6 | -4.5 | 5 | 5 | 3420 | 97.9 [97.4 ; 98.4] | [93.7 ; 99.2] (n_eff 136) | 100.0 [99.9 ; 100.0] | 100.0 | 0 | 0.1 | 1.7 | 99.9 | 97.9 | 0.0 (3420) | 0.0 | 0.0 | -1.41 | 97.9 | 100.0 | 0.0 | 99.8 | 0.2 |
| 6 | -4.5 | 5 | 10 | 3420 | 87.6 [86.5 ; 88.7] | [80.9 ; 92.0] (n_eff 136) | 98.5 [98.0 ; 98.8] | 99.5 | 0 | 0.9 | 0.5 | 100.0 | 87.7 | 0.0 (3420) | 0.0 | 0.0 | -1.30 | 87.6 | 98.5 | 0.0 | 99.9 | 0.1 |
| 6 | -4.5 | 5 | 20 | 3420 | 65.8 [64.2 ; 67.4] | [57.1 ; 72.9] (n_eff 136) | 86.8 [85.7 ; 87.9] | 93.8 | 0 | 3.4 | 0.6 | 100.0 | 65.8 | 0.0 (3420) | 0.0 | 0.0 | -1.25 | 65.8 | 86.8 | 0.0 | 99.9 | 0.1 |
| 6 | -6 | 1 | Inf | 3420 | 3.5 [3.0 ; 4.2] | [3.0 ; 4.2] (n_eff 3420) | 6.5 [5.7 ; 7.3] | 9.0 | 23 | 179.3 | 100.0 | 100.0 | 3.5 | 3.9 (3420) | 67.0 | 67.0 | -5.77 | 67.2 | 85.0 | 11.3 | 33.9 | 65.8 |
| 6 | -6 | 1 | 5 | 3420 | 55.6 [53.9 ; 57.2] | [53.9 ; 57.2] (n_eff 3420) | 76.2 [74.8 ; 77.6] | 85.1 | 0 | 27.9 | 83.8 | 99.9 | 55.6 | 13.7 (3420) | 92.1 | 92.1 | -6.47 | 62.8 | 80.0 | 21.9 | 15.2 | 84.0 |
| 6 | -6 | 1 | 10 | 3420 | 39.7 [38.1 ; 41.4] | [38.1 ; 41.4] (n_eff 3420) | 60.2 [58.6 ; 61.8] | 72.7 | 1 | 15.2 | 92.5 | 99.9 | 39.7 | 7.9 (3420) | 82.6 | 82.6 | -6.12 | 63.7 | 81.2 | 14.9 | 23.3 | 75.8 |
| 6 | -6 | 1 | 20 | 3420 | 24.2 [22.8 ; 25.7] | [22.8 ; 25.7] (n_eff 3420) | 39.9 [38.3 ; 41.6] | 52.0 | 2 | 20.2 | 98.6 | 100.0 | 24.2 | 5.7 (3420) | 74.9 | 74.9 | -5.87 | 64.7 | 82.2 | 13.0 | 28.0 | 71.4 |
| 6 | -6 | 3 | Inf | 3420 | 11.2 [10.2 ; 12.3] | [8.5 ; 14.9] (n_eff 380) | 19.6 [18.3 ; 21.0] | 26.0 | 7 | 63.7 | 100.0 | 100.0 | 11.2 | 0.0 (3420) | 0.0 | 0.0 | -1.72 | 98.7 | 99.6 | 0.0 | 79.6 | 20.4 |
| 6 | -6 | 3 | 5 | 3420 | 95.5 [94.7 ; 96.1] | [93.0 ; 97.2] (n_eff 380) | 99.9 [99.7 ; 100.0] | 100.0 | 0 | 0.3 | 96.1 | 100.0 | 95.5 | 0.0 (3420) | 0.0 | 0.0 | -2.09 | 99.4 | 99.9 | 0.0 | 75.3 | 24.7 |
| 6 | -6 | 3 | 10 | 3420 | 77.2 [75.8 ; 78.6] | [72.6 ; 81.0] (n_eff 380) | 93.5 [92.7 ; 94.3] | 97.9 | 0 | 1.9 | 98.3 | 100.0 | 77.2 | 0.0 (3420) | 0.0 | 0.0 | -1.93 | 98.2 | 99.2 | 0.0 | 77.6 | 22.4 |
| 6 | -6 | 3 | 20 | 3420 | 52.9 [51.2 ; 54.6] | [47.9 ; 57.9] (n_eff 380) | 74.6 [73.1 ; 76.1] | 85.0 | 0 | 5.9 | 99.8 | 100.0 | 52.9 | 0.0 (3420) | 0.0 | 0.0 | -1.83 | 98.2 | 99.0 | 0.0 | 79.2 | 20.8 |
| 6 | -6 | 5 | Inf | 3420 | 15.7 [14.5 ; 17.0] | [10.3 ; 22.5] (n_eff 136) | 28.3 [26.8 ; 29.8] | 36.0 | 4 | 36.8 | 100.0 | 100.0 | 15.7 | 0.0 (3420) | 0.0 | 0.0 | -1.14 | 99.9 | 100.0 | 0.0 | 91.5 | 8.5 |
| 6 | -6 | 5 | 5 | 3420 | 99.2 [98.9 ; 99.5] | [96.0 ; 99.9] (n_eff 136) | 100.0 [99.9 ; 100.0] | 100.0 | 0 | 0.0 | 99.7 | 100.0 | 99.2 | 0.0 (3420) | 0.0 | 0.0 | -1.41 | 100.0 | 100.0 | 0.0 | 87.7 | 12.3 |
| 6 | -6 | 5 | 10 | 3420 | 91.8 [90.8 ; 92.6] | [86.1 ; 95.4] (n_eff 136) | 99.5 [99.2 ; 99.7] | 99.8 | 0 | 0.5 | 99.9 | 100.0 | 91.8 | 0.0 (3420) | 0.0 | 0.0 | -1.30 | 99.9 | 100.0 | 0.0 | 90.2 | 9.8 |
| 6 | -6 | 5 | 20 | 3420 | 71.8 [70.3 ; 73.3] | [64.0 ; 78.9] (n_eff 136) | 90.7 [89.7 ; 91.6] | 96.2 | 0 | 2.5 | 100.0 | 100.0 | 71.8 | 0.0 (3420) | 0.0 | 0.0 | -1.25 | 99.9 | 99.9 | 0.0 | 90.9 | 9.1 |

