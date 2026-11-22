# Équipe de nemetonsar

> Produit par l'orchestrateur avec `/imperatrice:mission`, **validé par Pascal** avant
> tout démarrage. Règle de staffing : un agent par mission qui passe les trois
> questions, jamais un agent « par principe ».

- **Statut :** validée par délégation le 2026-11-22
- **Validée par :** Claude (orchestrateur, par délégation de Pascal)

## Plafond humain

- **PR ouvertes en même temps, au plus :** 3
- **Rythme de relecture de Pascal :** à dire par Pascal ; en attendant, toutes les missions passent dans la PR #2, qui reste en brouillon

## Délégation

> Ce que Pascal demande à l'orchestrateur de trancher à sa place (skill `methode`,
> « La délégation »). Vide : aucune délégation, Pascal tranche tout.

- **Portée :** « tout » (Pascal, 2026-11-22 : « Peux-tu coder jusqu'à la fin sans que
  j'aie à intervenir ? ») : portes n° 1 à 3 au sens de la méthode, temps de la main
  (prendre ou donner), arbitrages du `contradicteur`, AOI pilote et lieu de calcul.
  Remplace la délégation précédente (quatre questions du brief), close.
- **Jusqu'à :** fin de la v1 (jalon 4), ou révocation.
- **Inscrite au journal le :** 2026-11-22 (« Je te laisse trancher », puis « Peux-tu coder jusqu'à la fin sans que j'aie à intervenir ? »)

## Le vivier (catalogue, pas une équipe)

| Agent | A / plan | Modèle | Écrit du code ? |
|---|---|---|---|
| `contradicteur` | Abstraction · Polos | opus | non |
| `acquereur` | Acquisition · Ponos | sonnet | non (référentiels et données) |
| `archiviste` | Archivage · Pontos | sonnet | non (docs) |
| `analyste` | Analyse · Ponos | sonnet | non |
| `afficheur` | Affichage · Ponos | sonnet | oui (interface) |
| `dev` | réalisation · Ponos | sonnet | oui |
| `testeur` | réalisation · Ponos | sonnet | oui (tests) |
| `relecteur` | contrôle · C3 | opus | non (lecture seule) |

## Missions

| Mission | Agent | Modèle | Temps de la main | Les 3 questions | Cycle |
|---|---|---|---|---|---|
| [001](missions/001-parametres-methode.md) paramètres de la méthode, à la source | `acquereur` | sonnet | donner | 3 oui | 1 |
| [002](missions/002-licences-sources.md) licences et attributions | `acquereur` | sonnet | donner | 3 oui | 1 |
| [003](missions/003-parametres-et-db.md) paramètres exposés et dB | `dev` | opus | prendre (plan d'abord) | 3 oui | 1 (plan), après 001 |
| [004](missions/004-rcr-compute.md) ratio et date du minimum | `dev` | opus | donner | 3 oui | après 003 |
| [005](missions/005-rcr-segment.md) segmentation en deux seuils | `dev` | opus | donner | 3 oui | après 004 |
| [006](missions/006-postprocess.md) post-traitement : surface minimale et fermeture | `dev` | opus | donner | 3 oui | 2 |
| [007](missions/007-filtre-quegan.md) filtre multitemporel de Quegan et Yu | `dev` | opus | donner (formule sourcée d'abord) | 3 oui, la 2e sous condition | 2 |
| [008](missions/008-precision-date.md) précision de la date sur séries synthétiques | `analyste` | opus | donner | 3 oui | 3 |
| [009](missions/009-chaine-raster-blocs.md) chaîne de détection sur rasters, par blocs | `dev` | opus | donner | 3 oui | 3 |
| [010](missions/010-datation-xb.md) dater la coupe avec un Xb fini | `dev` | opus | donner | 3 oui | 3 |
| [011](missions/011-aoi.md) préparer l'AOI et la grille de calcul | `dev` | opus | donner | 3 oui | 4 |
| [012](missions/012-masques.md) masques forêt et feu | `dev` | opus | donner | 3 oui | 4 |
| [013](missions/013-recherche-s1.md) rechercher et lire les images Sentinel-1 | `dev` | opus | donner | 3 oui, la 3e sous condition (réseau) | 4 |
| [014](missions/014-nemetonsar-run.md) une commande unique, `nemetonsar_run()` | `dev` | opus | donner | 3 oui | 5 |
| [015](missions/015-limite-tuiles.md) coupes à la limite de deux tuiles | `dev` | opus | donner | 3 oui | 6 |
| [016](missions/016-performance.md) performance de la passe 1 | `dev` | opus | donner | 3 oui | 6 |
| [018](missions/018-suites-015.md) suites de 015 (FLT8S, une copie des passes 2-3, sans GeoPackage brut) | `dev` | opus | donner | 3 oui | 7 |
| [019](missions/019-mesure-lecture-parallele.md) mesurer la lecture réelle et le parallélisme | `analyste` | opus | donner | 3 oui | 8 |
| [020](missions/020-masque-bdforet.md) masque forêt BD Forêt v2 | `dev` | opus | donner | 3 oui | 8 |
| [021](missions/021-orbites-parallele.md) orbites en parallèle (option 3) | `dev` | opus | donner | 3 oui | 9 |
| [022](missions/022-acquisition-bandes.md) acquisition par bandes à disque borné | `dev` | opus | donner | 3 oui | 9 |
| [017](missions/017-tuile-pilote-landes.md) tuile pilote des Landes et comparaison à la v3.0.1 | `dev` | opus | donner | 3 oui, la 3e sous condition (accès v3.0.1) | 10 |

### Missions qui ne passent pas les trois questions (pas de fiche, pas d'agent)

| Mission pressentie | Question qui bloque | Ce qu'il faut |
|---|---|---|
| Mesure A contre B en γ0 sur forêt stable (ADR 0001, jalon 0) | 3e : pas d'AOI pilote, pas de Docker ni de compte Planetary Computer, lieu de calcul non dit | Pascal choisit l'AOI pilote (une tuile) et le poste ou serveur de calcul |
| Référence locale de validation (protocole, premiers polygones) | 3e : orthophotos ou données terrain sur l'AOI inconnues | Pascal dit ce dont il dispose |
| Masques, `nemetonsar_run()` sur images réelles | 3e : dépendent des missions ci-dessus | Cycles suivants |

