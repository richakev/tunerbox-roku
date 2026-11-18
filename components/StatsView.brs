' Game stats: a panel down the right of live TV for the game on this channel (mirrors the TunerBox web
' TV's X panel). Tabs: one per team's players, Team stats, Plays, Live scores (every other game on now).
' Data comes from TunerBox GET /api/sports/stats; the scene does the networking, playback and the
' "which stream" dialog. Drawn in the 1920x1080 layout and scaled into the safe area like Sports.

sub init()
    themeInit()
    m.X = 1312          ' content left edge and width (the panel starts at 1280)
    m.W = 578
    m.TAB_Y = 262
    m.BODY_Y = 330      ' the scrolling part (both move up when there's no game header)
    m.BODY_END = 930
    m.WIDE = { "FG": true, "3PT": true, "FT": true, "C/ATT": true, "H-AB": true }

    m.leagueLbl = m.top.findNode("leagueLbl")
    m.clockLbl = m.top.findNode("clockLbl")
    m.teamsGroup = m.top.findNode("teamsGroup")
    m.tabsGroup = m.top.findNode("tabsGroup")
    m.bodyGroup = m.top.findNode("bodyGroup")
    m.msgLbl = m.top.findNode("msgLbl")
    m.hintsGroup = m.top.findNode("hintsGroup")
    m.updLbl = m.top.findNode("updLbl")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.refreshTimer.observeField("fire", "onRefresh")
    m.leagueLbl.font = "font:MediumBoldSystemFont"
    m.leagueLbl.font.size = 26
    m.clockLbl.font = "font:MediumBoldSystemFont"
    m.clockLbl.font.size = 30
    m.msgLbl.font = "font:MediumSystemFont"
    m.msgLbl.font.size = 30
    m.updLbl.font = "font:SmallSystemFont"
    m.updLbl.font.size = 22

    m.game = invalid
    m.others = []
    m.tab = 0
    m.first = 0         ' first body line shown
    m.sel = 0           ' Live scores: the chosen game
    m.lines = []
    m.lastShown = -1
    m.enabled = true
    m.updAt = ""
    m.updText = ""
end sub

' ------------------------------------------------------------ open / close
sub openStats()
    m.game = invalid
    m.others = []
    m.tab = 0
    m.first = 0
    m.sel = 0
    m.updAt = ""
    m.updText = ""
    m.top.visible = true
    m.top.setFocus(true)
    m.refreshTimer.control = "start"
    render()
end sub

sub closeStats()
    m.refreshTimer.control = "stop"
    m.top.visible = false
end sub

sub onRefresh()
    if m.top.visible then m.top.request = { type: "refresh" }
end sub

sub onMessage()
    if m.top.message <> "" then
        m.game = invalid
        render()
    end if
end sub

' a new answer: a new game (another channel) starts on its first tab; the same game keeps the tab and place
sub onData()
    d = m.top.data
    if d = invalid then return
    g = d.game
    if Type(g) <> "roAssociativeArray" then g = invalid
    ' the same game, or still no game (Live scores only): keep the tab and the chosen game
    same = (g = invalid and m.game = invalid)
    if g <> invalid and m.game <> invalid then same = (sv(g.id) = sv(m.game.id))
    m.game = g
    m.others = aaList(d.others)
    m.enabled = true
    if GetInterface(d.enabled, "ifBoolean") <> invalid then m.enabled = d.enabled
    if not same then
        m.tab = 0
        m.first = 0
        m.sel = 0
    end if
    n = tabList().Count()
    if m.tab >= n then m.tab = n - 1
    if m.tab < 0 then m.tab = 0
    if m.sel >= m.others.Count() then m.sel = m.others.Count() - 1
    if m.sel < 0 then m.sel = 0
    m.updAt = fmtClock(nowEpoch())
    m.updText = "Updated " + m.updAt
    m.top.message = ""
    render()
end sub

' a refresh that didn't come back: keep what's shown, but say how old it is
sub onFailed()
    if not m.top.failed or m.updAt = "" then return
    m.updText = "Couldn't update" + dotSep() + "last " + m.updAt
    if m.updLbl.text <> "" then m.updLbl.text = m.updText
end sub

' ------------------------------------------------------------ helpers
function sv(v as Dynamic) as String
    return anyStr(v)
end function

function aaList(v as Dynamic) as Object
    out = []
    if Type(v) <> "roArray" then return out
    for each x in v
        if Type(x) = "roAssociativeArray" then out.Push(x)
    end for
    return out
end function

function strList(v as Dynamic) as Object
    out = []
    if Type(v) <> "roArray" then return out
    for each x in v
        out.Push(sv(x))
    end for
    return out
end function

' a team colour from TunerBox ("rrggbb") as a Roku colour, or the theme's dim grey
function teamColor(c as Dynamic) as String
    s = LCase(sv(c))
    r = CreateObject("roRegex", "^[0-9a-f]{6}$", "")
    if r.IsMatch(s) then return "0x" + UCase(s) + "FF"
    return thm("0x8FA3C8FF")
end function

function isTrue(v as Dynamic) as Boolean
    if GetInterface(v, "ifBoolean") = invalid then return false
    return v
end function

function num(v as Dynamic) as Float
    return Val(sv(v))
end function

' the tabs this game has: [{ label, kind, team }]
function tabList() as Object
    out = []
    ' no game the scoreboard knows on this channel: just the live games, if there are any
    if m.game = invalid then
        if m.others.Count() > 0 then out.Push({ label: "Live scores", kind: "scores" })
        return out
    end if
    for each p in aaList(m.game.players)
        out.Push({ label: sv(p.abbr), kind: "team", team: p })
    end for
    if aaList(m.game.team_stats).Count() > 0 then out.Push({ label: "Team stats", kind: "teamstats" })
    if aaList(m.game.plays).Count() > 0 then out.Push({ label: "Plays", kind: "plays" })
    if m.others.Count() > 0 then out.Push({ label: "Live scores", kind: "scores" })
    return out
end function

function curTab() as Dynamic
    t = tabList()
    if m.tab < t.Count() then return t[m.tab]
    return invalid
end function

sub clearGroup(g as Object)
    g.removeChildrenIndex(g.getChildCount(), 0)
end sub

' ------------------------------------------------------------ drawing
sub render()
    clearGroup(m.teamsGroup)
    clearGroup(m.tabsGroup)
    clearGroup(m.bodyGroup)
    g = m.game
    scoresOnly = (g = invalid and m.others.Count() > 0 and m.top.message = "")
    if g = invalid and not scoresOnly then
        m.leagueLbl.text = ""
        m.clockLbl.text = ""
        m.updLbl.text = ""
        msg = m.top.message
        if msg = "" and not m.enabled then msg = "Sports scores are off." + Chr(10) + "To turn them on, go to TunerBox's Setup > Settings > Sports and pick the leagues (or teams) you follow."
        if msg = "" then msg = "No games are live right now."
        m.msgLbl.text = plainText(msg)
        m.msgLbl.visible = true
        buildKeyHints(m.hintsGroup, [["BACK", "Close"]], 40, m.W)
        return
    end if
    m.msgLbl.visible = false
    m.updLbl.text = m.updText
    if scoresOnly then
        ' no game on this channel: no header, just the Live scores tab at the top
        m.leagueLbl.text = ""
        m.clockLbl.text = ""
        m.TAB_Y = 40
        m.BODY_Y = 108
    else
        m.TAB_Y = 262
        m.BODY_Y = 330
        lg = sv(g.league)
        if sv(g.state) = "in" then lg = lg + dotSep() + "LIVE"
        m.leagueLbl.text = plainText(lg)
        m.clockLbl.text = plainText(sv(g.detail))
        drawTeams()
    end if
    drawTabs()
    m.lines = buildLines()
    drawBody()
    hints = [["< >", "Tabs"], ["UP/DOWN", "Scroll"], ["BACK", "Close"]]
    t = curTab()
    if t <> invalid and t.kind = "scores" then hints = [["< >", "Tabs"], ["UP/DOWN", "Pick"], ["OK", "Watch"], ["BACK", "Close"]]
    buildKeyHints(m.hintsGroup, hints, 40, m.W)
end sub

sub drawTeams()
    teams = aaList(m.game.teams)
    hi = 0
    for each t in teams
        if num(t.score) > hi then hi = num(t.score)
    end for
    y = 92
    for each t in teams
        m.teamsGroup.appendChild(mkRect(m.X, y + 6, 8, 54, teamColor(t.color)))
        m.teamsGroup.appendChild(mkLabel(m.X + 24, y, 420, 40, sv(t.name), 34, true, thm("0xFFFFFFFF")))
        m.teamsGroup.appendChild(mkLabel(m.X + 24, y + 38, 420, 28, sv(t.record), 22, false, thm("0x8FA3C8FF")))
        sc = sv(t.score)
        col = thm("0xFFFFFFFF")
        if sc <> "" and num(sc) < hi then col = thm("0x8FA3C8FF")
        s = mkLabel(m.X + 420, y, 158, 66, sc, 52, true, col)
        s.horizAlign = "right"
        m.teamsGroup.appendChild(s)
        y = y + 80
    end for
end sub

' the tab row is clipped to the panel's width; when it's wider, it slides left so the chosen tab shows
sub drawTabs()
    tabs = tabList()
    ws = []
    selEnd = 0
    total = 0
    for i = 0 to tabs.Count() - 1
        w = Len(tabs[i].label) * 15 + 40
        ws.Push(w)
        if i > 0 then total = total + 10
        total = total + w
        if i = m.tab then selEnd = total
    end for
    off = 0
    if selEnd > m.W then off = selEnd - m.W
    m.tabsGroup.clippingRect = [m.X, m.TAB_Y - 4, m.W, 54]
    x = m.X - off
    i = 0
    for each t in tabs
        w = ws[i]
        if i = m.tab then
            m.tabsGroup.appendChild(mkPill(x, m.TAB_Y, w, 46, thm("0xFFC845FF")))
            col = thm("0x111111FF")
        else
            m.tabsGroup.appendChild(mkPill(x, m.TAB_Y, w, 46, thm("0x16397AFF")))
            col = thm("0xAFC8F5FF")
        end if
        l = mkLabel(x, m.TAB_Y, w, 46, t.label, 24, true, col)
        l.horizAlign = "center"
        m.tabsGroup.appendChild(l)
        x = x + w + 10
        i = i + 1
    end for
end sub

' the body as lines of known height, so it scrolls a line at a time:
' { k: "head"|"row"|"gap"|"play"|"game", h, ... }
function buildLines() as Object
    out = []
    t = curTab()
    g = m.game
    if t = invalid then
        msg = "No stats for this game yet."
        if g <> invalid and sv(g.state) = "pre" then msg = "Stats start when the game does."
        out.Push({ k: "msg", h: 80, text: msg })
    else if t.kind = "team" then
        for each tb in aaList(t.team.tables)
            cols = strList(tb.cols)
            title = sv(tb.title)
            if title = "" then title = "PLAYER"
            out.Push({ k: "head", h: 40, title: UCase(title), cells: cols, cols: cols, team: false })
            for each r in aaList(tb.rows)
                out.Push({ k: "row", h: 46, num: sv(r.num), name: sv(r.name), cells: strList(r.stats), cols: cols, team: false })
            end for
            out.Push({ k: "gap", h: 18 })
        end for
    else if t.kind = "teamstats" then
        abbrs = []
        for each tm in aaList(g.teams)
            abbrs.Push(sv(tm.abbr))
        end for
        out.Push({ k: "head", h: 40, title: "", cells: abbrs, cols: abbrs, team: true })
        for each s in aaList(g.team_stats)
            out.Push({ k: "row", h: 46, num: "", name: sv(s.label), cells: strList(s.values), cols: abbrs, team: true })
        end for
    else if t.kind = "plays" then
        for each p in aaList(g.plays)
            out.Push({ k: "play", h: 96, when: sv(p.when), text: sv(p.text), score: isTrue(p.score) })
        end for
    else if t.kind = "scores" then
        i = 0
        for each o in m.others
            out.Push({ k: "game", h: 104, o: o, i: i })
            i = i + 1
        end for
    end if
    return out
end function

' widths of a table's value columns, right to left from the content's right edge
function colWidths(cols as Object, team as Boolean) as Object
    out = []
    for each c in cols
        if team then
            out.Push(150)
        else if m.WIDE.DoesExist(c) then
            out.Push(104)
        else
            out.Push(72)
        end if
    end for
    return out
end function

sub drawBody()
    clearGroup(m.bodyGroup)
    y = m.BODY_Y
    i = m.first
    while i < m.lines.Count()
        ln = m.lines[i]
        if y + ln.h > m.BODY_END then exit while
        drawLine(ln, y)
        y = y + ln.h
        i = i + 1
    end while
    m.lastShown = i - 1
end sub

sub drawLine(ln as Object, y as Integer)
    g = m.bodyGroup
    if ln.k = "msg" then
        l = mkLabel(m.X, y, m.W, ln.h, ln.text, 28, false, thm("0xC5D3EFFF"))
        l.horizAlign = "center"
        g.appendChild(l)
    else if ln.k = "head" or ln.k = "row" then
        ws = colWidths(ln.cols, ln.team)
        right = m.X + m.W
        x = right
        ' value columns from the right
        vals = ln.cells
        for c = ws.Count() - 1 to 0 step -1
            x = x - ws[c]
            txt = ""
            if c < vals.Count() then txt = vals[c]
            if ln.k = "head" then
                l = mkLabel(x, y, ws[c], ln.h, txt, 22, true, thm("0x8FA3C8FF"))
            else
                l = mkLabel(x, y, ws[c], ln.h, txt, 28, (c = 0 and not ln.team), thm("0xFFFFFFFF"))
            end if
            l.horizAlign = "right"
            g.appendChild(l)
        end for
        nameW = x - m.X - 12
        if ln.k = "head" then
            g.appendChild(mkLabel(m.X, y, nameW, ln.h, ln.title, 22, true, thm("0x8FA3C8FF")))
        else
            nx = m.X
            if ln.num <> "" then
                g.appendChild(mkLabel(nx, y, 58, ln.h, "#" + ln.num, 22, false, thm("0x8FA3C8FF")))
                nx = nx + 58
            end if
            col = thm("0xFFFFFFFF")
            if ln.team then col = thm("0xAFC8F5FF")
            g.appendChild(mkLabel(nx, y, nameW - (nx - m.X), ln.h, ln.name, 28, false, col))
        end if
    else if ln.k = "play" then
        col = thm("0xFFFFFFFF")
        if ln.score then col = thm("0xFFC845FF")
        g.appendChild(mkLabel(m.X, y + 4, m.W, 26, ln.when, 21, false, thm("0x8FA3C8FF")))
        t = mkLabel(m.X, y + 30, m.W, 60, ln.text, 25, false, col)
        t.wrap = true
        t.maxLines = 2
        t.vertAlign = "top"
        g.appendChild(t)
        g.appendChild(mkRect(m.X, y + ln.h - 2, m.W, 1, thm("0x34466BFF")))
    else if ln.k = "game" then
        drawGame(ln.o, ln.i = m.sel, y, ln.h - 10)
    end if
end sub

' one other game: two team lines (scores in one column), then league, clock and where to watch on the right
sub drawGame(o as Object, selected as Boolean, y as Integer, h as Integer)
    g = m.bodyGroup
    if selected then g.appendChild(mkRect(m.X - 4, y - 4, m.W + 8, h + 8, thm("0xFFC845FF")))
    g.appendChild(mkRect(m.X, y, m.W, h, thm("0x16397AFF")))
    teams = aaList(o.teams)
    hi = 0
    for each t in teams
        if num(t.score) > hi then hi = num(t.score)
    end for
    ty = y + 6
    for each t in teams
        g.appendChild(mkRect(m.X + 14, ty + 8, 6, 26, teamColor(t.color)))
        g.appendChild(mkLabel(m.X + 32, ty, 200, 42, sv(t.abbr), 28, true, thm("0xFFFFFFFF")))
        col = thm("0xFFFFFFFF")
        if sv(t.score) <> "" and num(t.score) < hi then col = thm("0x8FA3C8FF")
        s = mkLabel(m.X + 230, ty, 120, 42, sv(t.score), 30, true, col)
        s.horizAlign = "right"
        g.appendChild(s)
        ty = ty + 42
    end for
    rx = m.X + 372
    rw = m.W - 372 - 14
    lg = mkLabel(rx, y + 4, rw, 26, sv(o.league), 20, true, thm("0xFFC845FF"))
    lg.horizAlign = "right"
    g.appendChild(lg)
    dt = mkLabel(rx, y + 30, rw, 30, sv(o.detail), 24, true, thm("0xFFFFFFFF"))
    dt.horizAlign = "right"
    g.appendChild(dt)
    wh = mkLabel(rx, y + 60, rw, 28, whereText(o), 20, false, thm("0x8FA3C8FF"))
    wh.horizAlign = "right"
    g.appendChild(wh)
end sub

' (the scene has already dropped channels that aren't in this Roku's lineup from ch / also)
function whereText(o as Object) as String
    feeds = aaList(o.feeds)
    also = aaList(o.also)
    hasCh = (Type(o.ch) = "roAssociativeArray")
    n = feeds.Count() + also.Count()
    if hasCh then n = n + 1
    if n = 0 then return "Not on your channels"
    if n > 1 then return n.ToStr() + " places to watch"
    if hasCh then return "Ch " + sv(o.ch.number)
    if also.Count() > 0 then return "Ch " + sv(also[0].number)
    if sv(feeds[0].group) <> "" then return sv(feeds[0].group)
    return "Event feed"
end function

' ------------------------------------------------------------ keys
sub setTab(n as Integer)
    c = tabList().Count()
    if c < 2 then return
    m.tab = (n + c) mod c
    m.first = 0
    render()
end sub

sub scrollBy(d as Integer)
    n = m.lines.Count()
    f = m.first + d
    ' stop once the last line is on screen
    if d > 0 and m.lastShown >= n - 1 then return
    if f < 0 then f = 0
    if f > n - 1 then f = n - 1
    if f = m.first then return
    m.first = f
    drawBody()
end sub

sub pick(d as Integer)
    n = m.others.Count()
    if n = 0 then return
    s = m.sel + d
    if s < 0 then s = 0
    if s > n - 1 then s = n - 1
    m.sel = s
    if m.sel < m.first then m.first = m.sel
    drawBody()
    while m.sel > m.lastShown and m.first < n - 1
        m.first = m.first + 1
        drawBody()
    end while
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false
    t = curTab()
    onScores = (t <> invalid and t.kind = "scores")
    if key = "left" then
        setTab(m.tab - 1)
    else if key = "right" then
        setTab(m.tab + 1)
    else if key = "up" then
        if onScores then pick(-1) else scrollBy(-1)
    else if key = "down" then
        if onScores then pick(1) else scrollBy(1)
    else if key = "rewind" then
        if onScores then pick(-5) else scrollBy(-8)
    else if key = "fastforward" then
        if onScores then pick(5) else scrollBy(8)
    else if key = "OK" then
        if onScores and m.sel < m.others.Count() then m.top.request = { type: "watch", o: m.others[m.sel] }
    else if key = "back" or key = "options" then
        m.top.request = { type: "close" }
    else
        return false
    end if
    return true
end function
