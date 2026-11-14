#!/bin/sh
# Sideloads tunerbox-tv.zip onto the Roku (developer mode). build-zip.sh runs it after each new build;
# safe to run by hand. Does nothing unless a Roku is set up, and never fails the build or commit:
# a Roku that's off or unreachable only prints a warning.
#
# Setup (once):
#   echo 'ROKU_IP=192.168.1.60' > .roku.env          # this file is gitignored
#   security add-generic-password -s tunerbox-roku -a rokudev -w 'DEV-PASSWORD'   # macOS Keychain
# or set ROKU_IP / ROKU_DEV_PASSWORD in the environment instead.
set -u

root=$(cd "$(dirname "$0")/.." && pwd)
zip="$root/tunerbox-tv.zip"

[ -f "$root/.roku.env" ] && . "$root/.roku.env"
ip=${ROKU_IP:-}
[ -n "$ip" ] || exit 0                                   # no Roku set up: nothing to do

pw=${ROKU_DEV_PASSWORD:-}
if [ -z "$pw" ] && command -v security >/dev/null 2>&1; then
    pw=$(security find-generic-password -s tunerbox-roku -a rokudev -w 2>/dev/null || true)
fi
if [ -z "$pw" ]; then
    echo "Roku install skipped: no developer password (ROKU_DEV_PASSWORD or Keychain item tunerbox-roku)" >&2
    exit 0
fi
[ -f "$zip" ] || { echo "Roku install skipped: $zip not built yet" >&2; exit 0; }

# password goes to curl on stdin, not the command line, so it doesn't show in the process list
out=$(printf 'user = "rokudev:%s"\n' "$pw" | curl -sS -K - --digest --connect-timeout 5 --max-time 120 \
    -F mysubmit=Install -F "archive=@$zip" "http://$ip/plugin_install" 2>&1) || {
    echo "Roku install skipped: couldn't reach $ip (is it on, and in developer mode?)" >&2
    exit 0
}

ver="$(grep '^major_version=' "$root/manifest" | cut -d= -f2).$(grep '^minor_version=' "$root/manifest" | cut -d= -f2)"
case "$out" in
    *"Install Success"*)               echo "Installed TunerBox TV $ver on Roku $ip" ;;
    *"Identical to previous version"*) echo "Roku $ip already has this build ($ver)" ;;
    *"401"*|*"Unauthorized"*)          echo "Roku install failed: wrong developer password for $ip" >&2 ;;
    *)                                 echo "Roku install may have failed on $ip; check http://$ip" >&2 ;;
esac
exit 0
