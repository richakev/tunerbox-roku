# TunerBox TV (Roku)

Live-TV front end for a running TunerBox backend. Loads `/playlist.m3u` + `/epg.xml`
from `http://<host>:8642`, shows a cable-box style guide and live viewer.

## Versioning
`.githooks/build-zip.sh` bumps `minor_version` in `manifest` and rebuilds `tunerbox-tv.zip` in the
project root, but only when `components/`, `images/`, `source/` or the rest of the manifest changed since
the last build (tracked in `.build-stamp`). It runs automatically when Claude Code finishes a turn
(Stop hook in `.claude/settings.json`) and after each commit (post-commit hook); you can also run it by hand.
Enable the repository hook once:
`git config core.hooksPath .githooks`

## Auto-install on your Roku
After each new build, `.githooks/install-roku.sh` sideloads the zip onto your Roku, so the TV always has
the latest version. Set it up once (the Roku must be in developer mode, see Install below):

    echo 'ROKU_IP=192.168.1.60' > .roku.env                                         # gitignored
    security add-generic-password -s tunerbox-roku -a rokudev -w 'DEV-PASSWORD'     # macOS Keychain

`ROKU_IP` and `ROKU_DEV_PASSWORD` environment variables work too. Without them nothing is installed.
If the Roku is off or unreachable it prints a warning and the build or commit still succeeds.
Run `.githooks/install-roku.sh` by hand to reinstall the current zip.

## Keeping up with TunerBox
TunerBox's `tests/test_roku_contract.py` lists every endpoint this app calls and the fields it reads,
so a backend change that would break the Roku fails TunerBox's tests. If you start calling a new
endpoint here, add it to that list. Features the web TV UI has and this app doesn't yet are tracked in
TunerBox's `ideas/IMPROVEMENT-IDEAS.md` under "Roku app".

## Install (sideload)
1. Roku: Settings > System > Advanced > Developer mode (enable, set a password).
2. Zip the contents of this folder (manifest at zip root) or use `tunerbox-tv.zip`.
3. Browse to `http://<roku-ip>` , log in as `rokudev`, upload the zip, Install.
   CLI: `curl --digest -u rokudev:PASSWORD -F mysubmit=Install -F archive=@tunerbox-tv.zip http://<roku-ip>/plugin_install`
4. First launch asks for the TunerBox IP (port 8642 assumed; `ip:port` or full URL also fine).
   Set it remotely: `curl -d '' "http://<roku-ip>:8060/launch/dev?host=192.168.1.50"`

## Remote controls
Live: Up/Down channel; the button bar appears on every channel change (Left/Right move, OK selects);
OK also opens it, FF opens the guide, Replay last channel,
Play mute, * menu, Back exit prompt.
Bar: Left/Right + OK (GUIDE FAVS DVR SEARCH SPORTS ON DEMAND MENU LAST MUTE +FAV).
Guide: arrows move through programs/channels, REW/FF page, OK watch (now) or options (future),
* menu, Back return to previous channel.
Keyboard: 0-9 jump, G guide, I info, L last, M mute, R record, / search, T sports, O On Demand.

## Fast loading
After the first successful load the channel list and guide are cached on the Roku. Next launch starts
playing almost immediately, then refreshes the guide in the background
(MENU > Reload channels and guide forces a full fresh load). Timings are printed to the console
(`telnet <roku-ip> 8085`), lines start with `[TunerBox]`.

## Favorites (synced with TunerBox /api/favorites)
- Guide shows a star next to each channel number (filled = favorite).
- Button bar: **FAVS** opens the guide with only your favorites, **+ FAV / - FAV** toggles the channel you are watching.
- In the guide press `*` (Options) for: add/remove favorite, favorites-only / all channels, search, sports.
- Keyboard: `F` or `*` toggle favorite, `V` favorites view (in the guide `V` switches favorites/all).
- Changes are sent to TunerBox immediately, so the web UI and the Roku always match.

## Startup speed
- The last channel you watched starts playing immediately at launch, before the channel list loads.
- Channel list and guide come from a local cache; the heavy guide refresh waits ~8 seconds (so the video
  starts first) and is skipped entirely if the cached guide is under 3 hours old.
- MENU > "Hide unmapped 20000+ channels" (default ON) removes the thousands of channels without a real
  number, which makes the cache tiny and loading much faster. Turn it off to see everything.

## Screen fit (overscan)
MENU > **Screen fit (overscan)** cycles 0% / 2.5% / 5% / 7.5% trimmed from each edge (default 2.5%).
All on-screen UI (guide, banner, button bar, menu, Sports) is scaled into that safe area; full-screen
video is not affected. Raise it if the edges of the guide are cut off on your TV, lower it if there is a border.

## Known gaps
- Not tested on hardware; the code passes the brighterscript linter only.
- Streams use format `ts` unless the URL ends in .m3u8; MENU > Stream format overrides.

## Sports & PPV
SPORTS (top bar, `T` on a keyboard, or the guide menu) opens the same panel as the TunerBox web UI, fed by `/api/sports`:
- **On Now / Coming Up / Sports Channels / Events & PPV** tabs (Left/Right switches, Up/Down scrolls, Rew/FF page).
- OK on something airing watches it (works even for channels hidden by "Hide unmapped"). OK on a future program offers **Record**, which now posts to `/api/recordings` (the guide's Record uses the same call).
- Events & PPV: pick a group, optionally "Check which feeds are live now", then OK to watch a feed. Back returns to the group list, then closes.

## On Demand (movies & TV shows)
ON DEMAND (top bar, `O` on a keyboard, or the guide's `*` menu) opens the same screen as the TunerBox web UI, fed by `/api/vod/*`:
- Live TV keeps playing in the corner; the highlighted title's details (plot, cast, length) show beside it.
- Tabs: **Movies / TV Shows** (with a category column, incl. Recently Added), **Continue Watching**, **My List**, **Search** (OK opens a keyboard).
- Grid: OK = details (Resume / Play from the beginning / My List / Mark watched / More in category), Play = play or resume straight away,
  `*` = add/remove My List, Rew/FF = page. A TV show opens its seasons (left) and episodes (right), starting on the episode that's next for you.
- Playback streams `/api/vod/stream/<id>?ss=<seconds>` (720p mode adds `mode=roku720`): OK/Play pause, Left -10s, Right +30s,
  Rew/FF -/+5 min, Up/Down show the progress bar, Back stops and returns to On Demand. Progress is saved to TunerBox every 15 s
  (so Continue Watching matches the web UI); at the end of an episode you're offered the next one.
- The main Search panel also lists On Demand matches (MOVIE / SHOW / EPISODE); OK opens them in On Demand.
