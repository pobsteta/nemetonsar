# Mission 025 — Un jeton du Planetary Computer qui n'expire pas pendant la lecture

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-23 (fin du cycle 10), sur décision de Pascal.

## Mission

**En une phrase (quoi, et pourquoi) :** Faire que `s1_lire()` (et `lecteur_s1()` dans `nemetonsar_run()`) ne tombe plus en 403 quand le jeton SAS du Planetary Computer expire au milieu d'une lecture longue, sans changer un résultat, pour qu'une tuile MGRS entière puisse aller au bout.

**Redite par l'agent :** _à compléter par l'agent avant d'agir._

## Constat (2026-11-23, mission 024, poste de Pascal)

- Deux exécutions sur quatre du pilote Landes, en série, sont tombées en 403 au milieu d'une bande (journaux `/home/pascal/dev/nemetonsar-donnees/m024/echec_*_403.log`, après ≈ 46 et ≈ 88 min).
- Cause trouvée par l'analyste : `rstac::sign_planetary_computer()` (appelé une fois dans `s1_lire()`, `R/s1.R:256`) garde le jeton en cache et ne le renouvelle qu'à moins de 5 min de son expiration ; une URL signée garde le jeton du moment de la signature, et la lecture d'une bande dure plus longtemps que la vie restante du jeton.
- Contournement hors package, dans `docs/analyses/ecarts-date-v301.R` (l. 66-72) : vider le cache interne `ms_token` de rstac avant chaque bande. Fragile (interne de rstac) : à ne pas reprendre tel quel.
- La documentation de `s1_lire()` (`R/s1.R:106-110`) dit « renouvelé à l'expiration » : elle est fausse pour une lecture longue.

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | en partie : pistes à comparer, (a) signer chaque adresse juste avant de l'ouvrir (date par date), (b) relire une date en 403 après un jeton neuf, une fois, (c) demander un jeton neuf par bande par l'API publique des jetons (`api/sas/v1/token/sentinel-1-rtc`, sans interne de rstac) | l'agent mesure et propose ; l'orchestrateur tranche |
| A-t-il les moyens ? | oui : R, rstac, terra, réseau vers le Planetary Computer ; test hors réseau avec un lecteur simulé qui renvoie 403 après N lectures | |

**Temps de la main :** donner. **Degré de la main :** le chef tranche.

## L'Homme

- **Agent :** `dev` · **Modèle :** opus

## Harnais

- **Peut (périmètre) :** `R/s1.R`, `R/run.R` (seulement `lecteur_s1()` et son appel), `tests/testthat/test-s1.R`, `tests/testthat/test-run.R`. `NAMESPACE` et `man/` par l'orchestrateur.
- **Câblé :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul.
- **Ne doit pas (écrit) :** changer un résultat ; dépendre d'un objet interne de rstac ; affaiblir un test ; chaînes R non ASCII ; dépendance nouvelle ; toucher le parallélisme de la mission 023 (`enfant_sans_fils_terra()`).

## Valeur provisoire (chiffre, réglage)

Nombre de relectures après un 403, s'il y en a : 1 ; provisoire.

## Dépend de / rouge attendu jusqu'à

Dépend de : 023 (terminée). CI rouge attendue : aucune.

## Tests

- Un test hors réseau qui échouait avant : lecteur simulé dont le jeton « expire » après N lectures (403), lecture qui va au bout avec le correctif.
- Identité au bit près avec la lecture sans expiration.
- Une vraie erreur 403 (jeton refusé de façon durable) reste une erreur claire, pas une boucle.
- Nit versé de la mission 023 : ranger le test de `run_rasteriser_qui()` hors de l'en-tête « Essai réel (réseau) » de `test-run.R`.

## Terrain

Le pilote Landes en série (`flux = 1`), qui dure plus que la vie d'un jeton, va au bout sur le poste de Pascal sans 403.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal. **Arrêt :** 3 allers-retours. **Qui tranche :** l'orchestrateur par délégation.
