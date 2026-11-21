#!/bin/sh
# Écrit sur la sortie standard un badge SVG « couverture: NN.N% ».
# Usage : badge-couverture.sh POURCENTAGE   (ex. 94.3 ; nombre entre 0 et 100)
# Couleur : vert >= 90, vert clair >= 80, jaune >= 70, orange >= 60, rouge en dessous.
P="${1:-}"
case "$P" in
  ''|*[!0-9.]*|*.*.*|.) echo "pourcentage invalide : '$P' (attendu un nombre, ex. 94.3)" >&2; exit 2 ;;
esac
ENTIER=${P%%.*}; ENTIER=${ENTIER:-0}
if [ "$ENTIER" -gt 100 ]; then echo "pourcentage invalide : '$P' (maximum 100)" >&2; exit 2; fi
if   [ "$ENTIER" -ge 90 ]; then C="#4c1"
elif [ "$ENTIER" -ge 80 ]; then C="#97ca00"
elif [ "$ENTIER" -ge 70 ]; then C="#dfb317"
elif [ "$ENTIER" -ge 60 ]; then C="#fe7d37"
else C="#e05d44"; fi
V="$P%"
cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="124" height="20" role="img" aria-label="couverture: $V"><linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient><clipPath id="r"><rect width="124" height="20" rx="3" fill="#fff"/></clipPath><g clip-path="url(#r)"><rect width="73" height="20" fill="#555"/><rect x="73" width="51" height="20" fill="$C"/><rect width="124" height="20" fill="url(#s)"/></g><g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" text-rendering="geometricPrecision" font-size="110"><text aria-hidden="true" x="375" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="630">couverture</text><text x="375" y="140" transform="scale(.1)" fill="#fff" textLength="630">couverture</text><text aria-hidden="true" x="975" y="150" fill="#010101" fill-opacity=".3" transform="scale(.1)" textLength="410">$V</text><text x="975" y="140" transform="scale(.1)" fill="#fff" textLength="410">$V</text></g></svg>
EOF
