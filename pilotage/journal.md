# Journal de nemetonsar

> **Règle du sommier : on n'efface pas, on ajoute.**
> Chaque inscription est datée et signée (agent ou personne). Une correction est une
> nouvelle ligne qui renvoie à l'ancienne. Un hook refuse toute modification qui
> supprimerait ou réécrirait une inscription existante.
>
> Format : `AAAA-MM-JJ · auteur · mission · ce qui a été fait / décidé / bloqué`
>
> **Le carnet des écarts** (fiche n° 3), en une ligne marquée `écart` :
> `AAAA-MM-JJ · auteur · mission · écart · attendu : … · vu : … · vérifié : comment (ou « non ») · décision : …`
> La décision est l'une des trois : **garder** (vérifié : on adopte), **creuser** (prochain
> essai, daté), **abandonner** (vrai hasard : on le note).
> Règle : on ne sanctionne pas un écart signalé ; on regarde d'abord, on corrige ensuite,
> s'il le faut.
>
> **Les changements de cap** (fiche n° 13), en une ligne marquée `cap`, signée par qui l'a
> décidé : `AAAA-MM-JJ · auteur · mission · cap · ancien → nouveau · pourquoi : … · fait : …`
>
> **La délégation**, en une ligne marquée `délégation`, signée de Pascal :
> `AAAA-MM-JJ · Pascal · — · délégation · portée : … · jusqu'à : … · réservé : …`
> Chaque décision prise par délégation :
> `AAAA-MM-JJ · Claude (orchestrateur, par délégation) · mission · décidé : … · pourquoi : … · ce que Pascal peut défaire : …`

2026-11-22 · Claude (orchestrateur) · — · méthode installée (`/imperatrice:demarrer`) : `CLAUDE.md`, `.claude/settings.json` (plugin `imperatrice@pobsteta`), `pilotage/` (équipe, kanban, journal, missions), `docs/adr/` ; `pilotage` ajouté à `.Rbuildignore`. `docs/brief.md` existait (rédigé par Pascal le 2026-11-21) : laissé tel quel. Reste à remplir : rubrique « Ma réponse d'abord » du brief (absente), « pour qui » du projet (bénéficiaires non nommés au brief), `.claude/test-command` (après la stack tranchée).
2026-11-22 · Claude (orchestrateur) · — · `/imperatrice:brief` étape 2 : question « Qu'attends-tu de ce projet, et pourquoi ? » posée à Pascal. Aucun code, aucun agent lancé avant sa réponse.
2026-11-22 · Claude (orchestrateur) · — · `/imperatrice:brief` étape 2 : réponse d'abord de Pascal recopiée mot pour mot dans `docs/brief.md`. Brief déjà rédigé par Pascal (2026-11-21) : étape 5, `contradicteur` lancé sur le brief.
2026-11-22 · contradicteur · — · critique du brief : bénéficiaire non nommé ; « tout point, tout temps » contredit le périmètre v1 (France, 2018, noyau figé) ; S1A arrêté le 29/06/2026 (ESA), « S1A uniquement » caduc ; aucune référence de validation après 09/2025 ; licences à préciser (SUFOSAT CC BY-NC 4.0, RTC PC CC BY 4.0) ; option D CDSE/openEO à ajouter au crible ; propositions soumises à Pascal, rien tranché.
2026-11-22 · Pascal · — · délégation · « Je te laisse trancher » · portée : les quatre questions du brief posées après la critique du contradicteur (pour qui ; tout point, tout temps en v1 ; fidélité ou détections 2026 ; usage des résultats), portée la plus étroite faute de portée dite · jusqu'à : ces quatre décisions prises · réservé : rien de dit (restent à Pascal : validation du brief et de la spec, ADR, portes n° 2 et 3, rendre la main, ce qui touche l'extérieur)
2026-11-22 · Claude (orchestrateur, par délégation) · brief · décidé : bénéficiaire v1 = Pascal, qui calcule lui-même la donnée sur les AOI qu'il choisit ; les autres utilisateurs (gestionnaires, services) à trancher par Pascal plus tard · pourquoi : sa réponse d'abord parle de « pouvoir calculer » lui-même, et nommer d'autres bénéficiaires engagerait des personnes que le brief ne cite pas (je ne tranche pas ce qui ferait payer d'autres) · ce que Pascal peut défaire : rubrique « Pour qui » du brief
2026-11-22 · Claude (orchestrateur, par délégation) · brief · décidé : « tout point, tout temps » en v1 = toute AOI en France métropolitaine jusqu'à la taille d'un département, toute période depuis 2018 jusqu'au dernier mois disponible, Sentinel-1A puis 1C/1D ; France entière et hors Europe hors v1 ; délai de détection = valeur provisoire mesurée au prototype · pourquoi : c'est la plus grande part de sa réponse d'abord que les données (masque TCD européen) et un poste de travail tiennent · ce que Pascal peut défaire : rubriques « Arbitrages » et « Périmètre » du brief
2026-11-22 · Claude (orchestrateur, par délégation) · brief · décidé : priorité aux détections d'après septembre 2025 ; l'accord avec la v3.0.1 sur 2018-2025 reste un contrôle de la méthode, pas le but ; continuité S1A → S1C/1D vérifiée dès le jalon 1 ; référence locale de validation constituée dès le jalon 0 · pourquoi : « en tout temps » vise la série à prolonger, et la v3 ne couvre pas ce qui est nouveau · ce que Pascal peut défaire : critères de réussite et validation du brief
2026-11-22 · Claude (orchestrateur, par délégation) · brief · décidé : usage interne et non commercial en v1 ; une licence par entrée et par sortie ; sorties produites sans la v3.0.1 tenues hors de sa clause NC · pourquoi : choix le plus étroit, compatible avec CC BY-NC 4.0 des données SUFOSAT ; aucun usage commercial n'est dit par Pascal · ce que Pascal peut défaire : rubrique « Arbitrages » du brief
2026-11-22 · Claude (orchestrateur) · — · `/imperatrice:brief` étapes 6-8 : arbitrages reportés dans `docs/brief.md` (qui les a rendus : Claude par délégation) ; `docs/spec.md` rédigée (proposée) ; ADR 0001 (prétraitement, mesurer avant de choisir) et 0002 (licences) proposées ; contradicteur lancé sur la spec et les ADR. Validation du brief, de la spec et des ADR : à Pascal (hors délégation).
