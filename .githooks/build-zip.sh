#!/bin/sh
# Rebuilds tunerbox-tv.zip when the app's files (components, images, source, or the manifest apart from
# minor_version) changed since the last build. minor_version goes up once per commit: on the first build
# after a commit (while the manifest still has the committed number), not on every build. NO_BUMP=1
# rebuilds without bumping (the post-commit hook, so a commit doesn't leave the manifest changed).
# Run by the Claude Code Stop hook and by the post-commit hook; safe to run by hand.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
stamp="$root/.build-stamp"

fingerprint() {
    {
        grep -v '^minor_version=' manifest
        find components images source -type f ! -name '.DS_Store' | LC_ALL=C sort | while IFS= read -r f; do
            printf '%s ' "$f"
            shasum "$f" | cut -d' ' -f1
        done
    } | shasum | cut -d' ' -f1
}

# a BrightScript reserved word used as a name only fails on the Roku itself: stop here instead
python3 "$root/.githooks/check-reserved.py"

now=$(fingerprint)
if [ -f "$stamp" ] && [ -f tunerbox-tv.zip ] && [ "$(cat "$stamp")" = "$now" ]; then
    exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

current=$(grep '^minor_version=' manifest | cut -d= -f2)
committed=$(git show HEAD:manifest 2>/dev/null | grep '^minor_version=' | cut -d= -f2 || true)
bump=1
[ "${NO_BUMP:-}" = "1" ] && bump=0
# already bumped since the last commit: keep the number
[ -n "$committed" ] && [ "$current" != "$committed" ] && bump=0

[ "$bump" = "1" ] && awk -F= '
    BEGIN { OFS = "="; found = 0 }
    $1 == "minor_version" {
        if (found || $2 !~ /^[0-9]+$/) exit 1
        $2 = $2 + 1
        found = 1
    }
    { print }
    END { if (!found) exit 1 }
' manifest > "$tmp/manifest" && cp "$tmp/manifest" manifest

rm -f tunerbox-tv.zip
zip -qr tunerbox-tv.zip manifest components images source -x '*.DS_Store'
printf '%s\n' "$now" > "$stamp"
echo "Built tunerbox-tv.zip, version $(grep '^major_version=' manifest | cut -d= -f2).$(grep '^minor_version=' manifest | cut -d= -f2)"

# put the new build on the Roku, if one is set up (see install-roku.sh); never fails the build
"$root/.githooks/install-roku.sh" || true
