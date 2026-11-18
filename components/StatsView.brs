' Game stats: a see-through card in the top right corner of live TV for the game on this channel (mirrors
' the TunerBox web TV's X panel); on the Live scores tab it becomes a slim panel down the right with a tile
' per game, like Home's. The picture stays full size behind it. Tabs: one per team's players, Team stats,
' Plays, Live scores (every other game on now).
' Data comes from TunerBox GET /api/sports/stats; the scene does the networking, playback and the
' "which stream" dialog. Drawn in the 1920x1080 layout and scaled into the safe area like Sports.

sub init()
    themeInit()
    m.PX = 1320         ' the box: left edge, width, top, and its bottom on the Live scores tab
    m.PW = 560
    m.PTOP = 40         ' the box's top edge (not m.TOP: names ignore case, and that would replace m.top, this view)
    ' how big the box is drawn: the layout below is at full size, then shrunk from its top-right corner, so it
    ' covers less of the game (the same share of the screen on every TV: the app is laid out at 1920x1080)
    m.SIZE = 0.8
    ' the Live scores panel still reaches the bottom of the screen once shrunk
    m.BOTTOM = m.PTOP + Int((1040 - m.PTOP) / m.SIZE)
    m.X = 1342          ' content left edge and width
    m.W = 516
    m.CARD_BODY = 470   ' the most body the corner card shows before it scrolls
    m.TEAMS_Y = 102
    m.TAB_Y = 174
    m.BODY_Y = 236      ' the scrolling part (both move up when there's no game header)
    m.BODY_END = 706
    m.WIDE = { "FG": true, "3PT": true, "FT": true, "C/ATT": true, "H-AB": true }

    sizer = m.top.findNode("sizer")
    sizer.scaleRotateCenter = [m.PX + m.PW, m.PTOP]
    sizer.scale = [m.SIZE, m.SIZE]
    m.frameGroup = m.top.findNode("frameGroup")
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
    m.leagueLbl.font.size = 22
    m.clockLbl.font = "font:MediumBoldSystemFont"
    m.clockLbl.font.size = 24
    m.msgLbl.font = "font:MediumSystemFont"
    m.msgLbl.font.size = 26
    m.updLbl.font = "font:SmallSystemFont"
    m.updLbl.font.size = 20
    m.leagueLbl.translation = [m.X, m.PTOP + 18]
    m.clockLbl.translation = [m.X + m.W - 240, m.PTOP + 18]
    m.msgLbl.translation = [m.X, m.PTOP + 20]
    m.msgLbl.width = m.W
    m.onScores = false

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
function teamColor(c as Dynamic, dflt = "" as String) as String
    s = LCase(sv(c))
    r = CreateObject("roRegex", "^[0-9a-f]{6}$", "")
    if r.IsMatch(s) then return "0x" + UCase(s) + "FF"
    if dflt <> "" then return dflt
    return thm("0x8FA3C8FF")
end function

' a team logo, fitted into the box (nothing shows if it won't load)
function mkLogo(x, y, w, h, uri as String) as Object
    p = CreateObject("roSGNode", "Poster")
    p.translation = [x, y]
    p.width = w
    p.height = h
    p.loadWidth = w
    p.loadHeight = h
    p.loadDisplayMode = "scaleToFit"
    p.uri = uri
    return p
end function

' the box behind everything: rounded, see-through so the game shows (solid in High contrast)
sub layoutFrame(bottom as Integer)
    clearGroup(m.frameGroup)
    alpha = 0.82
    if m.onScores then alpha = 0.72
    if themeName() = "contrast" then alpha = 0.97
    bg = CreateObject("roSGNode", "Poster")
    bg.uri = "pkg:/images/round.9.png"
    bg.translation = [m.PX, m.PTOP]
    bg.width = m.PW
    bg.height = bottom - m.PTOP
    bg.blendColor = thm("0x0B2A6AFF")
    bg.opacity = alpha
    m.frameGroup.appendChild(bg)
end sub

' the key hints and "Updated" line along the bottom of the box, at y
sub placeFoot(y as Integer, hints as Object)
    m.hintsGroup.translation = [m.X, y]
    buildKeyHints(m.hintsGroup, hints, 36, m.W - 200)
    m.updLbl.translation = [m.X + m.W - 190, y]
end sub

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
        ' a message: a small card in the corner
        m.onScores = false
        m.leagueLbl.text = ""
        m.clockLbl.text = ""
        m.updLbl.text = ""
        msg = m.top.message
        if msg = "" and not m.enabled then msg = "Sports scores are off." + Chr(10) + "To turn them on, go to TunerBox's Setup > Settings > Sports and pick the leagues (or teams) you follow."
        if msg = "" then msg = "No games are live right now."
        m.msgLbl.text = plainText(msg)
        m.msgLbl.visible = true
        y = m.PTOP + 186
        placeFoot(y, [["BACK", "Close"]])
        layoutFrame(y + 56)
        return
    end if
    m.msgLbl.visible = false
    m.updLbl.text = m.updText
    t = curTab()
    m.onScores = (t <> invalid and t.kind = "scores")
    if scoresOnly then
        ' no game on this channel: no header, just the Live scores tab at the top
        m.leagueLbl.text = ""
        m.clockLbl.text = ""
        m.TAB_Y = m.PTOP + 20
    else
        m.TAB_Y = 174
        lg = sv(g.league)
        if sv(g.state) = "in" then lg = lg + dotSep() + "LIVE"
        m.leagueLbl.text = plainText(lg)
        m.clockLbl.text = plainText(sv(g.detail))
        drawTeams()
    end if
    m.BODY_Y = m.TAB_Y + 62
    drawTabs()
    m.lines = buildLines()
    ' Live scores fills the panel down the right; anything else is a card as tall as its body (up to CARD_BODY)
    if m.onScores then
        m.BODY_END = m.BOTTOM - 70
    else
        total = 0
        for each ln in m.lines
            total = total + ln.h
        end for
        if total > m.CARD_BODY then total = m.CARD_BODY
        m.BODY_END = m.BODY_Y + total
    end if
    drawBody()
    hints = [["< >", "Tabs"], ["UP/DOWN", "Scroll"], ["BACK", "Close"]]
    if m.onScores then hints = [["< >", "Tabs"], ["UP/DOWN", "Pick"], ["OK", "Watch"], ["BACK", "Close"]]
    if m.onScores then
        placeFoot(m.BOTTOM - 56, hints)
        layoutFrame(m.BOTTOM)
    else
        placeFoot(m.BODY_END + 10, hints)
        layoutFrame(m.BODY_END + 66)
    end if
end sub

' the score on one line: [bar logo name score] - [score name logo bar], the leader brighter
sub drawTeams()
    teams = aaList(m.game.teams)
    if teams.Count() < 2 then return
    hi = 0
    for each t in teams
        if num(t.score) > hi then hi = num(t.score)
    end for
    y = m.TEAMS_Y
    mid = m.X + Int(m.W / 2)
    half = Int(m.W / 2)
    for i = 0 to 1
        t = teams[i]
        sc = sv(t.score)
        col = thm("0xFFFFFFFF")
        if sc <> "" and num(sc) < hi then col = thm("0x8FA3C8FF")
        name = sv(t.short)
        if name = "" then name = sv(t.abbr)
        if name = "" then name = sv(t.name)
        if i = 0 then
            m.teamsGroup.appendChild(mkRect(m.X, y + 8, 6, 40, teamColor(t.color)))
            m.teamsGroup.appendChild(mkLogo(m.X + 14, y + 6, 44, 44, sv(t.logo)))
            m.teamsGroup.appendChild(mkLabel(m.X + 64, y, half - 64 - 90, 56, name, 22, true, thm("0xFFFFFFFF")))
            s = mkLabel(mid - 18 - 72, y, 72, 56, sc, 40, true, col)
            s.horizAlign = "right"
        else
            m.teamsGroup.appendChild(mkRect(m.X + m.W - 6, y + 8, 6, 40, teamColor(t.color)))
            m.teamsGroup.appendChild(mkLogo(m.X + m.W - 58, y + 6, 44, 44, sv(t.logo)))
            n = mkLabel(mid + 90, y, half - 64 - 90, 56, name, 22, true, thm("0xFFFFFFFF"))
            n.horizAlign = "right"
            m.teamsGroup.appendChild(n)
            s = mkLabel(mid + 18, y, 72, 56, sc, 40, true, col)
        end if
        m.teamsGroup.appendChild(s)
    end for
    d = mkLabel(mid - 18, y, 36, 56, "-", 30, true, thm("0x8FA3C8FF"))
    d.horizAlign = "center"
    m.teamsGroup.appendChild(d)
end sub

' the tab row is clipped to the panel's width; when it's wider, it slides left so the chosen tab shows
sub drawTabs()
    tabs = tabList()
    ws = []
    selEnd = 0
    total = 0
    for i = 0 to tabs.Count() - 1
        w = Len(tabs[i].label) * 13 + 34
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
            m.tabsGroup.appendChild(mkPill(x, m.TAB_Y, w, 44, thm("0xFFC845FF")))
            col = thm("0x111111FF")
        else
            m.tabsGroup.appendChild(mkPill(x, m.TAB_Y, w, 44, thm("0x16397AFF")))
            col = thm("0xAFC8F5FF")
        end if
        l = mkLabel(x, m.TAB_Y, w, 44, t.label, 21, true, col)
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
            out.Push({ k: "head", h: 34, title: UCase(title), cells: cols, cols: cols, team: false })
            for each r in aaList(tb.rows)
                out.Push({ k: "row", h: 40, num: sv(r.num), name: sv(r.name), cells: strList(r.stats), cols: cols, team: false })
            end for
            out.Push({ k: "gap", h: 14 })
        end for
    else if t.kind = "teamstats" then
        abbrs = []
        for each tm in aaList(g.teams)
            abbrs.Push(sv(tm.abbr))
        end for
        out.Push({ k: "head", h: 34, title: "", cells: abbrs, cols: abbrs, team: true })
        for each s in aaList(g.team_stats)
            out.Push({ k: "row", h: 40, num: "", name: sv(s.label), cells: strList(s.values), cols: abbrs, team: true })
        end for
    else if t.kind = "plays" then
        for each p in aaList(g.plays)
            out.Push({ k: "play", h: 88, when: sv(p.when), text: sv(p.text), score: isTrue(p.score) })
        end for
    else if t.kind = "scores" then
        i = 0
        for each o in m.others
            out.Push({ k: "game", h: 166, o: o, i: i })
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
            out.Push(130)
        else if m.WIDE.DoesExist(c) then
            out.Push(92)
        else
            out.Push(62)
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
                l = mkLabel(x, y, ws[c], ln.h, txt, 19, true, thm("0x8FA3C8FF"))
            else
                l = mkLabel(x, y, ws[c], ln.h, txt, 24, (c = 0 and not ln.team), thm("0xFFFFFFFF"))
            end if
            l.horizAlign = "right"
            g.appendChild(l)
        end for
        nameW = x - m.X - 12
        if ln.k = "head" then
            g.appendChild(mkLabel(m.X, y, nameW, ln.h, ln.title, 19, true, thm("0x8FA3C8FF")))
        else
            nx = m.X
            if ln.num <> "" then
                g.appendChild(mkLabel(nx, y, 50, ln.h, "#" + ln.num, 19, false, thm("0x8FA3C8FF")))
                nx = nx + 50
            end if
            col = thm("0xFFFFFFFF")
            if ln.team then col = thm("0xAFC8F5FF")
            g.appendChild(mkLabel(nx, y, nameW - (nx - m.X), ln.h, ln.name, 24, false, col))
        end if
    else if ln.k = "play" then
        col = thm("0xFFFFFFFF")
        if ln.score then col = thm("0xFFC845FF")
        g.appendChild(mkLabel(m.X, y + 4, m.W, 24, ln.when, 19, false, thm("0x8FA3C8FF")))
        t = mkLabel(m.X, y + 28, m.W, 54, ln.text, 22, false, col)
        t.wrap = true
        t.maxLines = 2
        t.vertAlign = "top"
        g.appendChild(t)
        g.appendChild(mkRect(m.X, y + ln.h - 2, m.W, 1, thm("0x34466BFF")))
    else if ln.k = "game" then
        drawGame(ln.o, ln.i = m.sel, y + 4, ln.h - 16)
    end if
end sub

' one other game, drawn like Home's tiles: the two teams' colours side by side with their logos, the score
' and clock between them, and the matchup, league and where to watch along the bottom
sub drawGame(o as Object, selected as Boolean, y as Integer, h as Integer)
    g = m.bodyGroup
    teams = aaList(o.teams)
    if teams.Count() < 2 then return
    half = Int(m.W / 2)
    mid = m.X + half
    if selected then g.appendChild(mkRect(m.X - 4, y - 4, m.W + 8, h + 8, thm("0xFFC845FF")))
    g.appendChild(mkRect(m.X, y, half, h, teamColor(teams[0].color, "0x1D3A7AFF")))
    g.appendChild(mkRect(mid, y, m.W - half, h, teamColor(teams[1].color, "0x5A1F2AFF")))
    g.appendChild(mkRect(mid - 2, y, 4, h, "0xFFFFFF55"))
    ' the logos in the upper part, a team's abbreviation where there's none
    lh = h - 66
    for i = 0 to 1
        t = teams[i]
        cx = m.X + Int(m.W * 0.16)
        if i = 1 then cx = m.X + Int(m.W * 0.84)
        if sv(t.logo) <> "" then
            g.appendChild(mkLogo(cx - Int(lh / 2), y + 6, lh, lh, sv(t.logo)))
        else
            a = mkLabel(cx - 70, y + 6, 140, lh, sv(t.abbr), 30, true, "0xFFFFFFCC")
            a.horizAlign = "center"
            g.appendChild(a)
        end if
    end for
    ' the score on a dark pill, the leader brighter, the clock under it
    hi = 0
    for each t in teams
        if num(t.score) > hi then hi = num(t.score)
    end for
    pill = mkPill(mid - 74, y + 12, 148, 46, "0x000000FF")
    pill.opacity = 0.72
    g.appendChild(pill)
    for i = 0 to 1
        t = teams[i]
        col = "0xFFFFFFFF"
        if sv(t.score) <> "" and num(t.score) < hi then col = "0xFFFFFFA6"
        if i = 0 then
            s = mkLabel(mid - 70, y + 12, 58, 46, sv(t.score), 32, true, col)
            s.horizAlign = "right"
        else
            s = mkLabel(mid + 12, y + 12, 58, 46, sv(t.score), 32, true, col)
        end if
        g.appendChild(s)
    end for
    dash = mkLabel(mid - 12, y + 12, 24, 46, "-", 24, true, "0xFFFFFFCC")
    dash.horizAlign = "center"
    g.appendChild(dash)
    if sv(o.detail) <> "" then
        ck = mkLabel(mid - 110, y + 60, 220, 26, sv(o.detail), 19, true, thm("0xFFC845FF"))
        ck.horizAlign = "center"
        g.appendChild(ck)
    end if
    ' the matchup and where to watch on a dark band along the bottom
    band = mkRect(m.X, y + h - 58, m.W, 58, "0x000000B8")
    g.appendChild(band)
    name = sv(o.name)
    if name = "" then name = sv(teams[0].abbr) + " at " + sv(teams[1].abbr)
    g.appendChild(mkLabel(m.X + 14, y + h - 56, m.W - 28, 30, name, 21, true, "0xFFFFFFFF"))
    lg = mkLabel(m.X + 14, y + h - 28, 0, 24, sv(o.league), 18, true, "0x2ED47AFF")
    g.appendChild(lg)
    lw = Int(lg.boundingRect().width)
    g.appendChild(mkLabel(m.X + 14 + lw, y + h - 28, m.W - 28 - lw, 24, dotSep() + whereText(o), 18, false, "0xFFFFFFCC"))
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
