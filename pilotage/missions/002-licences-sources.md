# Mission 002 — Licences et attributions de chaque source

> Gabarit `fiche-mission.md` du plugin. Écrite par l'orchestrateur le 2026-11-22.

## Mission

**En une phrase (quoi, et pourquoi) :** Établir la licence, le lien et l'attribution exigée de chaque donnée d'entrée et de sortie, pour appliquer l'ADR 0002.

**Redite par l'agent :** Établir, pour chaque source d'entrée et de sortie de l'ADR 0002, la licence, le lien du texte, l'attribution et les usages permis, sans conclure sans document ni donner d'avis juridique. *(Rendu de l'`acquereur`, reporté par l'orchestrateur.)*

## Les trois questions (règle de staffing)

| Question | Réponse | Conséquence |
|---|---|---|
| Peut-il redire la mission en une phrase, avec son but ? | oui | |
| Sait-il comment faire ? | oui : ADR 0002 en donne la liste | |
| A-t-il les moyens ? | oui : accès web | |

**Temps de la main :** donner.

**Degré de la main :** le chef tranche (touche l'usage des résultats).

## Ma réponse d'abord

_Rempli par Pascal seul, avant de lire le travail de l'agent._

## L'Homme

- **Agent :** `acquereur`
- **Modèle :** sonnet
- **Ce qui ne lui est pas demandé :** Pas de code.

## Harnais

- **Peut (périmètre) :** `docs/referentiels/licences.md`
- **Câblé (ne peut pas) :** pas de `main`, pas de « terminé » sans tests verts, journal en ajout seul (hooks du plugin).
- **Ne doit pas (écrit) :** sortir du périmètre ; conclure sur une licence sans le document qui la porte ; donner un avis juridique.
- **Sources autorisées :** `docs/adr/0002-licences-entrees-sorties.md`, pages des fournisseurs (Copernicus, CLMS, NASA Earthdata, EFFIS, THEIA, Planetary Computer, IEEE).

## Journal

- **Ce que l'agent inscrit :** une ligne par rendu et par aller-retour, proposée à l'orchestrateur.

## Valeur provisoire (chiffre, réglage)

aucune.

## Dépend de / rouge attendu jusqu'à

aucune.

## Tests

- **Comment saura-t-on que c'est juste :** Une ligne par source de l'ADR 0002 : licence, lien vers le texte, attribution à reproduire, usage non commercial permis ou non. « Non trouvé » quand c'est le cas. Liste de contrôle jointe.

## Terrain

- **Échantillon que Pascal vérifiera :** Pascal ouvre deux liens de licence et vérifie la ligne.

## Qui veille, qui tranche

- **Relecteur :** `relecteur`, puis Pascal.
- **Critère d'arrêt de la relecture :** 3 allers-retours.
- **Point de suivi :** à chaque `/imperatrice:boucle`.
- **Qui tranche :** Pascal.

## Comment saura-t-on que ça marche ?

Le journal d'exécution (mission ultérieure) peut citer chaque ligne telle quelle.
