#!/bin/sh
# Tests de release-necessaire.sh : cas synthétiques dans un dépôt temporaire.
S="$(cd "$(dirname "$0")" && pwd)/release-necessaire.sh"
ECHECS=0
verifie() { # nom attendu obtenu
  case "$3" in "$2"*) echo "ok   $1";; *) echo "ECHEC $1 : attendu '$2', obtenu '$3'"; ECHECS=$((ECHECS+1));; esac
}
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q . && git config user.email t@t && git config user.name t
commit() { git add -A && git commit -q -m "$1"; }
ecrit() { mkdir -p "$(dirname "$1")"; echo "$2" >> "$1"; }

ecrit R/a.R 1; commit init
verifie "aucun tag" "release:" "$("$S")"
git tag v0.1.0
verifie "rien changé" "pas de release:" "$("$S")"
ecrit docs/brief.md x; ecrit docs/a.pdf x; ecrit README.md x; commit docs
verifie "seulement docs/md" "pas de release:" "$("$S")"
ecrit pilotage/kanban.md x; ecrit pilotage/missions/suivi.csv x; commit pilotage
verifie "seulement pilotage" "pas de release:" "$("$S")"
ecrit R/a.R 2; commit code
verifie "docs + code" "release:" "$("$S")"
git tag -f v0.1.0 HEAD >/dev/null
ecrit .github/badges/couverture.svg x; commit badge
verifie "badge seul" "pas de release:" "$("$S")"
ecrit .github/workflows/release.yml x; commit workflow
verifie "workflow modifié" "release:" "$("$S")"
git tag -f v0.1.0 HEAD >/dev/null
ecrit DESCRIPTION x; commit description
verifie "DESCRIPTION modifié" "release:" "$("$S")"
git tag -f v0.1.0 HEAD >/dev/null
ecrit man/a.Rd x; commit doc
verifie "page d'aide modifiée" "release:" "$("$S")"
# code non publié, puis fusion de docs : on compare au tag, pas au commit précédent
git tag v0.2.0; ecrit R/b.R 1; commit code2; ecrit docs/j.md x; commit docs2
verifie "code puis docs (CI annulée)" "release:" "$("$S")"
git tag v0.2.1; ecrit R/b.R 1b; commit code2b; ecrit pilotage/suivi.csv x; commit pilotage2
verifie "code puis pilotage (CI annulée)" "release:" "$("$S")"
verifie "commit inconnu" "release:" "$("$S" deadbeef)"

# tête de main et fichiers de test
CODE2=$(git rev-parse HEAD)
verifie "commit = tête de main" "release:" "$("$S" HEAD "" "$CODE2")"
ecrit R/b.R 2; commit code3
verifie "commit dépassé par la tête" "pas de release: commit dépassé par $(printf '%s' "$(git rev-parse HEAD)" | cut -c1-7)" "$("$S" "$CODE2" "" "$(git rev-parse HEAD)")"
verifie "tête inconnue localement (SHA brut)" "pas de release: commit dépassé par 1234567" "$("$S" HEAD "" 1234567890abcdef1234567890abcdef12345678)"
verifie "tête illisible : on publie" "release:" "$("$S" HEAD)"
git tag v0.3.0
ecrit tests/testthat/test-x.R x; ecrit tests/testthat.R x; ecrit tests/testthat/fixtures/z.json x
ecrit .github/scripts/test-release-necessaire.sh x; commit tests
verifie "tests seuls" "pas de release:" "$("$S" HEAD "" "$(git rev-parse HEAD)")"
ecrit R/c.R 1; commit "test + code"
verifie "tests + code" "release:" "$("$S" HEAD "" "$(git rev-parse HEAD)")"
git tag v0.4.0
ecrit tests/testthat/test-q.R x; ecrit .github/scripts/release-necessaire.sh x; commit "test + script de release"
verifie "le script de release lui-même compte" "release:" "$("$S" HEAD "" "$(git rev-parse HEAD)")"

# la CI pousse un commit de badge [skip ci] sur main après le commit de code
git tag v0.5.0; ecrit R/d.R 1; commit "code D"; CODED=$(git rev-parse HEAD)
ecrit .github/badges/couverture.svg y; commit "docs: mise à jour du badge de couverture [skip ci]"; BADGE=$(git rev-parse HEAD)
verifie "code puis badge [skip ci] : release" "release:" "$("$S" "$CODED" "" "$BADGE")"
ecrit docs/m.md x; ecrit NEWS.md x; commit "docs"; DOCS=$(git rev-parse HEAD)
verifie "code puis badge puis docs : release" "release:" "$("$S" "$CODED" "" "$DOCS")"
ecrit tests/testthat/test-r.R x; commit "tests"; TESTS=$(git rev-parse HEAD)
verifie "code puis tests : release" "release:" "$("$S" "$CODED" "" "$TESTS")"
ecrit R/e.R 1; commit "code E"; CODEE=$(git rev-parse HEAD)
verifie "code puis badge puis code : dépassé" "pas de release: commit dépassé par $(printf '%s' "$CODEE" | cut -c1-7)" "$("$S" "$CODED" "" "$CODEE")"

# la release écrit la version publiée dans DESCRIPTION par un commit [skip ci] : seule la ligne Version: change
git tag v0.6.0; printf 'Package: p\nVersion: 0.0.1\nTitle: t\n' > DESCRIPTION; commit "description"
verifie "DESCRIPTION, autre ligne que Version : release" "release:" "$("$S")"
git tag v0.7.0; sed -i 's/^Version:.*/Version: 0.7.0/' DESCRIPTION; commit "version [skip ci]"; VERS=$(git rev-parse HEAD)
verifie "DESCRIPTION, seule la Version : pas de release" "pas de release:" "$("$S" HEAD "" "$VERS")"
git tag v0.8.0; ecrit R/f.R 1; commit "code F"; CODEF=$(git rev-parse HEAD)
sed -i 's/^Version:.*/Version: 0.8.0/' DESCRIPTION; commit "version [skip ci]"; VERS2=$(git rev-parse HEAD)
verifie "code puis commit de version : release" "release:" "$("$S" "$CODEF" "" "$VERS2")"
git tag v0.9.0; sed -i 's/^Version:.*/Version: 0.9.0/' DESCRIPTION; ecrit R/g.R 1; commit "version + code"
verifie "Version et code ensemble : release" "release:" "$("$S" HEAD "" "$(git rev-parse HEAD)")"
git tag v0.10.0; sed -i 's/^Version:.*/Version: 0.10.0/; s/^Title:.*/Title: u/' DESCRIPTION; commit "version + titre"
verifie "Version et autre ligne de DESCRIPTION : release" "release:" "$("$S" HEAD "" "$(git rev-parse HEAD)")"

if [ "$ECHECS" -eq 0 ]; then echo "Tous les tests passent."; else echo "$ECHECS échec(s)."; exit 1; fi
