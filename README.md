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
Bar (top, as the web TV's): Left/Right + OK on Home, Guide, On Demand, Sports & Events, Search and More (Home only
when Home is on). More has favorite on/off, Favorites, Last channel, Record this show, Mute, Show info and Menu.
Guide: arrows move through programs/channels, REW/FF page, OK watch (now) or options (future),
* menu, Back return to previous channel.
Guide filters (pills above the grid, as the web guide): Up on the first channel moves onto them. Left/Right
goes along Favorites / All / Movies / Sports / News / Kids; a category filters as soon as it's highlighted,
and OK on Favorites switches between favorites only and every channel. OK or Down goes back to the channels.
Only channels with a show of that category on in the hours shown are listed, and other shows are dimmed. Also
in the guide's * menu (Category), or C on a keyboard.
Keyboard: 0-9 jump, G guide, H Home, I info, L last, M mute, R record, / search, T sports, O On Demand.

## Home
The same Home screen as the TunerBox web UI, fed by `/api/home`: a top bar with TunerBox, the shortcuts
(Watch TV, Guide, On Demand, Sports & Events, Search, Menu) and the time; live TV keeps playing full screen behind it,
darkened on the left and bottom, with the highlighted tile's details on the left, then rows for favorites on now, your teams on now, Continue Watching
(On Demand and recordings), sports on now, recent channels, new recordings and what's coming up. Up from the
first row goes to the shortcuts. It refreshes every minute.
- Only there when TunerBox's Setup > Settings **Home screen** is on (read from `/api/settings` at each
  launch). Off: no HOME button, no Home in the menus, and the app starts on live TV.
- Opens at launch; MENU > **Start on Home (this Roku)** turns that off for this Roku only.
- Open it with HOME on the button bar, MENU > Home, the guide's `*` menu, or `H` on a keyboard.
- Arrows move, OK watches / opens, `*` adds or removes a favorite, Rew/FF jump to the start / end of a row,
  Back goes to live TV. Screens opened from Home (guide, Sports, On Demand, Search) come back to it on Back.
- Recordings play straight from TunerBox and resume where you stopped on any screen
  (Left -10s, Right +30s, Rew/FF 5 min, OK pause, Back stop).

## Themes
The same colour themes as the web TV screens: Midnight (the default), Classic Blue, Retro 90s and High Contrast.
TunerBox's Setup > Settings > Screens > Theme sets the default (read from `/api/settings`; Light is for Setup and
phones, so TV screens use Midnight with it). MENU > **Theme** picks one for this Roku only.
The app's colours are written in the Classic Blue palette and `thm()` in `source/utils.brs` swaps each for the
theme's; the maps there were made from the palettes at the end of TunerBox's `web/tv.css`, matched by role.
If you add a colour, use one already in the app (or add it to the maps).

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

## Stream cache
MENU > **Stream cache** (Off, 5, 10, 20, 30 or 60 seconds) holds back that much video on the server before
playing, so a stream that stutters plays from the cache instead of freezing. Each channel change takes that
long to start. "Use the default" follows TunerBox's Setup > Settings > Stream cache; any other choice is
for this Roku only and is sent as `buf=` on live channel and event streams.

## Known gaps
- Not tested on hardware; the code passes the brighterscript linter only.
- Streams use format `ts` unless the URL ends in .m3u8; MENU > Stream format overrides.

## Sports & Events
SPORTS (top bar, `T` on a keyboard, or the guide menu) opens the same panel as the TunerBox web UI, fed by `/api/sports`:
- **On Now / Coming Up / Sports Channels / Events** tabs (Left/Right switches, Up/Down scrolls, Rew/FF page).
- OK on something airing watches it (works even for channels hidden by "Hide unmapped"). OK on a future program offers **Record**, which now posts to `/api/recordings` (the guide's Record uses the same call).
- Events: pick a group, optionally "Check which feeds are live now", then OK to watch a feed. Back returns to the group list, then closes.

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
