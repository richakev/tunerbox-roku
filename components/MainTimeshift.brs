' ============================================================ pause / rewind live TV (timeshift)
' TunerBox (richakev's fork) can keep the last few minutes of a live channel in its HLS playlist: GET
' /api/timeshift says how many ({ minutes }; 0 = off in Setup), and /api/hls/{n}?timeshift=<minutes> (or
' /api/feed/hls?key=..&timeshift=) asks for that long a playlist, which the Video node pauses and seeks in.
' pasiegel's TunerBox (v1.10.0 and older, and main) has no /api/timeshift: the reply is a 404 ({"detail"}),
' m.tsMin stays 0, and live TV plays as before (TS, Play mutes, FF opens the guide).
' While paused nothing is fetched, so tsTick tells the server this Roku is still there (/api/timeshift?client=).
'
' m.ts (invalid when what's on can't be paused): { up, since, lag, paused, pausedAt, win, pend, seekFrom, ticks }
'   lag: seconds behind live (counted here: pauses and skips), win: seconds the server keeps

sub tsInit()
    m.tsMin = 0
    m.ts = invalid
    m.tsPauseWhenUp = false
    m.tsTimer = CreateObject("roSGNode", "Timer")
    m.tsTimer.repeat = true
    m.tsTimer.duration = 1
    m.tsTimer.observeField("fire", "tsTick")
    ' several presses of Rewind / FF = one seek
    m.tsSeekTimer = CreateObject("roSGNode", "Timer")
    m.tsSeekTimer.repeat = false
    m.tsSeekTimer.duration = 0.6
    m.tsSeekTimer.observeField("fire", "tsSeekNow")
end sub

sub tsProbe()
    homeApi("timeshift", "/api/timeshift", "", invalid, {})
end sub

sub tsGot(r as Object)
    m.tsMin = 0
    if r.ok and Type(r.data) = "roAssociativeArray" and r.data.minutes <> invalid then m.tsMin = Int(numv(r.data.minutes))
    if m.tsMin < 0 then m.tsMin = 0
    print "[TunerBox] timeshift: " + m.tsMin.ToStr() + " min"
end sub

' the server can and this Roku hasn't turned it off (Menu > Settings > Pause live TV)
function tsWanted() as Boolean
    return m.tsMin > 0 and regRead("timeshift", "1") = "1"
end function

' TunerBox's own live stream over HLS, kept long enough to pause and rewind in. Other URLs are left as they are.
function tsUrl(u as String) as String
    if not tsWanted() or m.base = "" or Left(u, Len(m.base)) <> m.base then return u
    h = u
    if Instr(1, u, "/api/stream/") > 0 then
        h = u.Replace("/api/stream/", "/api/hls/")
    else if Instr(1, u, "/api/feed/stream?") > 0 then
        h = u.Replace("/api/feed/stream?", "/api/feed/hls?")
    else if Instr(1, u, "/api/hls/") = 0 and Instr(1, u, "/api/feed/hls?") = 0 then
        return u
    end if
    sep = "?"
    if Instr(1, h, "?") > 0 then sep = "&"
    return h + sep + "timeshift=" + m.tsMin.ToStr()
end function

' a live stream just started: pausable if it was asked for with timeshift=
sub tsStart(u as String)
    tsDrop()
    if Instr(1, u, "timeshift=") = 0 then
        m.tsPauseWhenUp = false
        return
    end if
    m.ts = { up: false, since: nowEpoch(), lag: 0, paused: false, pausedAt: 0, win: m.tsMin * 60, pend: 0, seekFrom: 0.0, ticks: 0 }
end sub

' On Demand, a recording, multiview or standby took the player over
sub tsDrop()
    m.tsTimer.control = "stop"
    m.tsSeekTimer.control = "stop"
    m.ts = invalid
end sub

' onVideoState, live TV playing
sub tsPlaying()
    t = m.ts
    if t = invalid then return
    if not t.up then
        t.up = true
        t.since = nowEpoch()
    end if
    if m.tsPauseWhenUp then
        m.tsPauseWhenUp = false
        if not t.paused then tsPause()
    end if
end sub

function tsLag() as Integer
    t = m.ts
    if t = invalid then return 0
    if t.paused then return t.lag + nowEpoch() - t.pausedAt
    return t.lag
end function

' furthest back the playlist reaches now (a little short of it, so a skip back doesn't land on a removed segment)
function tsMost() as Integer
    t = m.ts
    if t = invalid then return 0
    most = nowEpoch() - t.since
    if most > t.win then most = t.win
    most = most - 8
    if most < 0 then most = 0
    return most
end function

' live TV's Play key. Older servers (or Pause live TV off): mute, as before
sub tsPlayKey()
    if m.ts = invalid then
        if tsWanted() and m.mv = invalid and (m.extern <> invalid or m.playIdx >= 0) then
            ' this channel started before the server said it can: restart it pausable, then pause
            m.tsPauseWhenUp = true
            showToast("Getting live TV ready to pause...")
            retuneLive()
            if m.ts = invalid then              ' not TunerBox's own stream: it can't pause
                m.tsPauseWhenUp = false
                toggleMute()
            end if
        else
            toggleMute()
        end if
        return
    end if
    if not m.ts.up then return
    tsPause()
end sub

sub tsPause()
    t = m.ts
    if t = invalid then return
    if t.paused then
        t.lag = tsLag()
        if t.lag > tsMost() then t.lag = tsMost()
        t.paused = false
        m.video.control = "resume"
    else
        t.paused = true
        t.pausedAt = nowEpoch()
        t.ticks = 0
        m.video.control = "pause"
    end if
    m.tsTimer.control = "stop"
    if t.paused then m.tsTimer.control = "start"
    tsHud()
end sub

' delta: seconds forward (+) or back (-). Returns false at live with nothing to skip forward to.
function tsSeek(delta as Integer) as Boolean
    t = m.ts
    if t = invalid or not t.up then return false
    lag = tsLag()
    want = lag - delta
    most = tsMost()
    if want > most then want = most
    if want < 0 then want = 0
    d = lag - want                      ' seconds the picture moves forward
    if d = 0 and delta > 0 then return false        ' at live already: nothing to skip to
    if t.paused then
        ' a skip plays from the new spot
        t.paused = false
        m.tsTimer.control = "stop"
        m.video.control = "resume"
    end if
    t.lag = want
    if d = 0 then
        showToast("That's as far back as this channel goes")
        tsHud()
        return true
    end if
    if t.pend = 0 then t.seekFrom = m.video.position
    t.pend = t.pend + d
    m.tsSeekTimer.control = "stop"
    m.tsSeekTimer.control = "start"
    tsHud()
    return true
end function

sub tsSeekNow()
    t = m.ts
    if t = invalid or t.pend = 0 then return
    at = t.seekFrom + t.pend
    if at < 0 then at = 0
    t.pend = 0
    print "[TunerBox] timeshift: seek to " + Str(at) + ", " + t.lag.ToStr() + "s behind live"
    m.video.seek = at
end sub

sub tsGoLive()
    if m.ts = invalid then return
    tsSeek(tsLag() + 60)
end sub

sub tsTick()
    t = m.ts
    if t = invalid or m.mv <> invalid or m.vod <> invalid or m.rec <> invalid then
        tsDrop()
        return
    end if
    if not t.paused then
        m.tsTimer.control = "stop"
        return
    end if
    t.ticks = t.ticks + 1
    if t.ticks mod 10 = 0 then homeApi("tsalive", "/api/timeshift?client=" + urlEncode(vodClientId()), "", invalid, {})
    ' paused as long as the server keeps: play on before the paused spot is gone
    if tsLag() >= t.win - 15 then
        showToast("Paused as long as TunerBox keeps live TV: playing on")
        tsPause()
        return
    end if
    if m.mode = "live" then m.hud.callFunc("updateVod", tsInfo())
end sub

function tsInfo() as Object
    if m.extern <> invalid then
        info = externInfo()
    else if m.curIdx >= 0 and m.curIdx < m.channels.Count() then
        info = bannerInfo(m.channels[m.curIdx])
    else
        info = { num: "", name: "", logo: "", title: "", subtitle: "", times: "", pct: 0.0, nextText: "", rating: "" }
    end if
    lag = tsLag()
    most = tsMost()
    if m.ts <> invalid and m.ts.paused and most < lag then most = lag
    if lag > 0 then
        info.times = fmtDur(lag) + " behind live"
    else
        info.times = "Live"
    end if
    info.pct = 1.0
    if most > 0 then info.pct = (most - lag) / most
    if m.ts <> invalid and m.ts.paused then
        info.rating = "PAUSED"
    else if lag > 0 then
        info.rating = "BEHIND LIVE"
    else
        info.rating = "LIVE"
    end if
    info.nextText = "Play Pause   Rew -15s   FF +30s   (up to " + fmtDur(m.tsMin * 60) + " back)"
    info.flag = invalid
    return info
end function

sub tsHud()
    if m.mode <> "live" or m.ts = invalid then return
    secs = 4
    if m.ts.paused then secs = 0
    m.hud.callFunc("showVod", tsInfo(), secs)
end sub

' live TV keys for timeshift; false: not one of them (the usual live key does its thing)
function tsKey(key as String) as Boolean
    if key = "play" then
        tsPlayKey()
        return true
    end if
    if m.ts = invalid then return false
    if key = "rewind" then
        tsSeek(-15)
        return true
    else if key = "fastforward" then
        return tsSeek(30)               ' at live: FF opens the guide, as before
    end if
    return false
end function

sub tsToggleSetting()
    if regRead("timeshift", "1") = "1" then
        regWrite("timeshift", "0")
        showToast("Pause live TV: Off")
    else
        regWrite("timeshift", "1")
        showToast("Pause live TV: On")
    end if
    retuneLive()
end sub
