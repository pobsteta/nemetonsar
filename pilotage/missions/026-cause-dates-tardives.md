# Mission 026 — Observer la cause non établie des dates tardives

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (fin du cycle 10), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Sur la tuile pilote des Landes, relever pour chaque pixel resté tardif après la mission 024 et pour chaque orbite le ratio de détection à la date publiée par la v3.0.1 et la date de premier passage sous le seuil, pour dire si la cause en tête (52 % des pixels tardifs) est un signal trop faible, une autre orbite à l'heure, un événement réel postérieur, ou autre chose, avant que Pascal tranche la règle de date.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Point de départ

- Rapport de la mission 024 : `docs/analyses/ecarts-date-v301.md` (CC BY-NC 4.0) et son script `docs/analyses/ecarts-date-v301.R`.
- Faits déjà établis : 67 % des dates tardives en février-mars ; 8 acquisitions portent 53 % des tardifs ; sur orthophoto, plusieurs événements sur un même pixel (déjà clair en 2018, sol travaillé en 2021, plantation) ; la coupe « recalcul seul » de 100,7 ha était déjà coupée en 2018 (piste : masque BD Forêt).
- Données, **sur le poste de Pascal seulement**, hors dépôt : `/home/pascal/dev/nemetonsar-donnees/` (extrait v3.0.1, sorties `pilote/` et `pilote-parallele/`, travail `m024/`). La mission tourne en session locale.

## Questions à trancher par les chiffres

1. Pour les pixels tardifs de cause non établie : le ratio de détection à la date publiée est-il proche du seuil (signal trop faible), loin (rien à cette date), ou sous le seuil sur une autre orbite que celle retenue ?
2. Les 8 acquisitions de fin d'hiver : chute du ratio sur de larges zones (sol gelé ou très humide, que le masque neige non appliqué ne retire pas) ou vrais événements ?
3. Part des pixels tardifs sur des postes BD Forêt « coupe rase / jeune peuplement » (FF0, FO0), comptés forêt par décision de Pascal du 2026-11-22.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : script de 024, `compare_reference()`, sorties de `nemetonsar_run()` | |
| A-t-il les moyens ? | oui en session locale : données ci-dessus, R, terra, réseau vers le Planetary Computer ; lecture en parallèle possible (023 terminée) ; jeton : contournement du script de 024 tant que 025 n'est pas faite | hors du poste de Pascal : s'arrêter |

**Temps de la main :** donner. **Degré de la main :** le chef tranche (touche la justesse des dates).

## L'Homme

- **Agent :** `analyste` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `docs/analyses/cause-dates-tardives.R` (script), `docs/analyses/cause-dates-tardives.md` (rapport, **CC BY-NC 4.0**, mention « usage non commercial » en tête, attributions [S1] [FOR] [MET] [SUF], et [ORT] si orthophotos). Fichiers de travail hors dépôt (`/home/pascal/dev/nemetonsar-donnees/m026/`).
- **Câblé :** pas de `main`, journal en ajout seul.
- **Ne doit pas (écrit) :** modifier le package (`R/`, `tests/`) ; mettre une donnée ou un extrait de la v3.0.1 au dépôt ; recopier des valeurs de la v3.0.1 au journal ; changer un réglage par défaut (il propose, Pascal tranche). Le rapport dit exactement ce qu'il contient (leçon de 024).

## Valeur provisoire (chiffre, réglage)

Seuils de 15 j (« date retrouvée ») et 180 j (« tardive ») repris de 024, provisoires.

## Dépend de / rouge attendu jusqu'à

Dépend de : 024 (terminée). Indépendante de 025 (périmètres disjoints). CI rouge attendue : aucune.

## Tests

Script reproductible (chemins en argument, graine) ; chiffres recalculés par le relecteur ; quelques pixels tracés à l'appui de chaque conclusion.

## Terrain

Les pixels tracés et les dates de fin d'hiver, sur orthophoto IGN et, si possible, Sentinel-2.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** Pascal (règle de date, masques).
