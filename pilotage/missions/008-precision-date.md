# Mission 008 — Précision de la date sur séries synthétiques

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22 (cycle 3), par délégation.

## Mission

**En une phrase (quoi, et pourquoi) :** Mesurer, sur séries synthétiques à speckle simulé, la part des coupes datées exactement et à une acquisition près selon `xb`, la fenêtre du filtre et l'ENL, pour décider des réglages provisoires de date avant le jalon 2.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : fonctions du package (003 à 007), écart du journal (007), M24 p. 13747 (délai 12 à 24 jours) | |
| A-t-il les moyens ? | oui : R, simulation | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (par délégation : l'orchestrateur).

## Ma réponse d'abord

_Rempli par Pascal seul._

## L'Homme

- **Agent :** `analyste` (simulation et lecture des causes ; n'écrit pas le package)
- **Modèle :** opus
- **Ce qui ne lui est pas demandé :** changer un défaut du package : il propose, l'orchestrateur tranche.

## Harnais

- **Peut (périmètre) :** `docs/analyses/precision-date.md`, `docs/analyses/precision-date.R`.
- **Câblé (ne peut pas) :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier `R/`, `tests/`, `NAMESPACE`, `man/`, `DESCRIPTION` ; présenter un chiffre de simulation comme une mesure sur données réelles.
- **Sources autorisées :** le package (chargé par `pkgload::load_all()`), `docs/`, journal.

## Journal

- Une ligne par rendu, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

Mesure de `xb` (Inf provisoire), de la règle de date (d_(i+1)) et du délai de détection ; l'ENL simulé (4,4 avant filtre, B18 p. 4) est une hypothèse de simulation.

## Dépend de / rouge attendu jusqu'à

Dépend de : 003 à 007 (terminées). CI rouge attendue : aucune (aucun fichier du package).

## Tests

- **Comment saura-t-on que c'est juste :** script reproductible (graine fixée), tableau des taux (exacte, ±1 acquisition, ±2) et des fausses alertes en forêt intacte, par `xb` (Inf, 5, 10, 20), fenêtre (1, 3, 5), ENL (4,4 et filtré), cadence (6 et 12 jours), amplitude de chute (−3, −4,5, −6 dB) ; incertitudes données (taille d'échantillon) ; conclusion : deux ou trois causes et une proposition de réglage.

## Terrain

- **Échantillon que Pascal vérifiera :** le tableau de synthèse et un graphique.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Critère d'arrêt :** 3 allers-retours. **Qui tranche :** Pascal, ou l'orchestrateur par délégation.

## Comment saura-t-on que ça marche ?

L'orchestrateur peut décider `xb` et la règle de date en citant un chiffre de ce rapport.
