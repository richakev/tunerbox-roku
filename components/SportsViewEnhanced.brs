' Sports & Events panel, the Enhanced layout (TunerBox Setup › Settings › Sports › layout; Basic is SportsView): a list of sports down the left (Live now,
' Your teams, Coming up, each sport, Sports channels, Event feeds) and what's picked on the right: the
' biggest game or event in a box at the top, then a list (a sport's under a heading per day).
' Replays and shows about sport ("kind" from a newer TunerBox) stay folded away until asked for; an
' older TunerBox sends no "kind", and then nothing is folded away.
' Data comes from TunerBox GET /api/sports plus the Roku's own live game schedule (LoadTask "espn");
' the scene does the networking and playback.

sub init()
    themeInit()
    m.RAIL_X = 44
    m.RAIL_Y = 110
    m.RAIL_H = 56
    m.RAIL_N = 15
    m.ROW_X = 500
    m.ROW_W = 1360
    m.ROW_H = 72
    m.NROWS = 11
    m.HERO_Y = 110
    m.HERO_H = 200

    m.titleLbl = m.top.findNode("titleLbl")
    m.secLbl = m.top.findNode("secLbl")
    m.statusLbl = m.top.findNode("statusLbl")
    m.railGroup = m.top.findNode("railGroup")
    m.heroGroup = m.top.findNode("heroGroup")
    m.rowsGroup = m.top.findNode("rowsGroup")
    m.msgLbl = m.top.findNode("msgLbl")
    m.footLbl = m.top.findNode("footLbl")
    m.titleLbl.font.size = 40
    m.secLbl.font.size = 46
    m.statusLbl.font.size = 27
    m.msgLbl.font.size = 36
    m.footLbl.font.size = 27

    m.sec = "now"
    m.zone = "rail"
    m.ri = 0
    m.railTop = 0
    m.rail = []
    m.sel = 0
    m.top0 = 0
    m.heroSel = false
    m.hero = invalid
    m.data = invalid
    m.grp = invalid
    m.showSlots = false
    m.showRep = false
    m.items = []
    m.games = invalid
    m.nowList = []
    m.upList = []
    m.rowY0 = 0
    m.moreSports = []
    m.nVis = m.NROWS
    m.drawnTop = -1
    m.drawnSel = -1
    buildNodes()
end sub

' Everything is created once and then only updated, never rebuilt.
sub buildNodes()
    m.railRows = []
    for r = 0 to m.RAIL_N - 1
        y = m.RAIL_Y + r * m.RAIL_H
        rr = { y: y }
        rr.bg = mkRect(m.RAIL_X, y, 424, m.RAIL_H - 6, thm("0xFFC845FF"))
        rr.name = mkLabel(m.RAIL_X + 18, y, 290, m.RAIL_H - 6, "", 30, true, thm("0xCFE0FFFF"))
        rr.liveBg = mkRect(m.RAIL_X + 300, y + 12, 50, m.RAIL_H - 30, thm("0xE0243CFF"))
        rr.live = mkLabel(m.RAIL_X + 300, y + 12, 50, m.RAIL_H - 30, "", 22, true, thm("0xFFFFFFFF"))
        rr.live.horizAlign = "center"
        rr.count = mkLabel(m.RAIL_X + 352, y, 58, m.RAIL_H - 6, "", 26, false, thm("0xA9BEE8FF"))
        rr.count.horizAlign = "right"
        rr.line = mkRect(m.RAIL_X + 12, y + Int(m.RAIL_H / 2) - 3, 400, 2, thm("0x4F86E855"))
        for each k in ["bg", "line", "name", "liveBg", "live", "count"]
            rr[k].visible = false
            m.railGroup.appendChild(rr[k])
        end for
        m.railRows.Push(rr)
    end for

    ' the box at the top: a stripe in the first team's colour, tags, two lines, where, how far through
    x = m.ROW_X
    y = m.HERO_Y
    h = {}
    h.bg = mkRect(x, y, m.ROW_W, m.HERO_H, thm("0x1C4FA899"))
    h.ring = mkRect(x - 4, y - 4, m.ROW_W + 8, m.HERO_H + 8, thm("0xFFC845FF"))
    h.stripe = mkRect(x, y, 10, m.HERO_H, thm("0x3B5B96FF"))
    h.tagBg = mkRect(x + 34, y + 18, 110, 34, thm("0xE0243CFF"))
    h.tag = mkLabel(x + 34, y + 18, 110, 34, "", 22, true, thm("0xFFFFFFFF"))
    h.tag.horizAlign = "center"
    h.head = mkLabel(x + 160, y + 18, m.ROW_W - 200, 34, "", 26, false, thm("0xCFE0FFFF"))
    h.big = mkLabel(x + 34, y + 58, m.ROW_W - 70, 62, "", 48, true, thm("0xFFFFFFFF"))
    h.where = mkLabel(x + 34, y + 124, m.ROW_W - 330, 36, "", 27, false, thm("0xCFE0FFFF"))
    h.ok = mkLabel(x + m.ROW_W - 300, y + 124, 270, 36, "", 24, true, thm("0xA9BEE8FF"))
    h.ok.horizAlign = "right"
    h.progBg = mkRect(x + 34, y + m.HERO_H - 26, m.ROW_W - 70, 8, thm("0xFFFFFF22"))
    h.prog = mkRect(x + 34, y + m.HERO_H - 26, 10, 8, thm("0x2ED47AFF"))
    for each k in ["ring", "bg", "stripe", "tagBg", "tag", "head", "big", "where", "ok", "progBg", "prog"]
        h[k].visible = false
        m.heroGroup.appendChild(h[k])
    end for
    m.heroN = h

    ' unseen label used only to measure how wide a title is
    m.measLbl = mkLabel(0, 0, 0, m.ROW_H - 4, "", 31, true, thm("0xFFFFFFFF"))
    m.measLbl.opacity = 0
    m.rowsGroup.appendChild(m.measLbl)

    m.rows = []
    rh = m.ROW_H - 6
    for r = 0 to m.NROWS - 1
        row = { y: 0 }
        row.bg = mkRect(m.ROW_X, 0, m.ROW_W, rh, thm("0x1C4FA855"))
        row.badgeBg = mkRect(m.ROW_X + 14, 0, 104, rh - 28, thm("0x3B5B96FF"))
        row.badge = mkLabel(m.ROW_X + 14, 0, 104, rh - 28, "", 22, true, thm("0xFFFFFFFF"))
        row.badge.horizAlign = "center"
        row.title = mkLabel(m.ROW_X + 14, 0, 0, rh, "", 31, true, thm("0xFFFFFFFF"))
        row.subt = mkLabel(m.ROW_X + 14, 0, 100, rh, "", 25, false, thm("0xA9BEE8FF"))
        row.right = mkLabel(m.ROW_X + m.ROW_W - 560, 0, 544, rh, "", 25, false, thm("0xCFE0FFFF"))
        row.right.horizAlign = "right"
        row.prog = mkRect(m.ROW_X, 0, 10, 4, thm("0x2ED47A99"))
        for each k in ["bg", "badgeBg", "badge", "title", "subt", "right", "prog"]
            row[k].visible = false
            m.rowsGroup.appendChild(row[k])
        end for
        m.rows.Push(row)
    end for
end sub

' ------------------------------------------------------------ open / close
sub openSports()
    m.data = invalid
    m.games = invalid
    m.nowList = []
    m.upList = []
    m.grp = invalid
    m.top.groupName = ""
    m.showSlots = false
    m.showRep = false
    m.sec = "now"
    m.zone = "rail"
    m.ri = 0
    m.railTop = 0
    m.sel = 0
    m.top0 = 0
    m.heroSel = false
    m.top.message = "Loading Sports & Events..."
    m.top.visible = true
    m.top.setFocus(true)
    render()
end sub

sub closeSports()
    m.top.visible = false
    m.top.setFocus(false)
end sub

' ------------------------------------------------------------ inputs
sub onData()
    m.data = cleanData(m.top.data)
    m.grp = invalid
    m.top.groupName = ""
    m.top.message = ""
    mergeLists()
    m.sel = 0
    m.top0 = 0
    m.heroSel = false
    render()
end sub

' live games arrive separately (usually after /api/sports): merge them in without moving the selection
sub onGames()
    m.games = cleanGames(m.top.games)
    mergeLists()
    if m.data = invalid then return
    if m.grp = invalid then render()
end sub

' Live now  = live games found in the guide, then the guide's other sports, then live games not in the guide
' Coming up = upcoming games + the guide's upcoming sports, by start time
' A guide program that is also a matched game (same channel + start) only shows once, as the game.
sub mergeLists()
    m.nowList = []
    m.upList = []
    if m.data = invalid then return
    now = nowEpoch()
    seen = {}
    gNow = []
    gNowMissing = []
    up = []
    ' games no channel carries: off when either TunerBox's "List games you have no channel for"
    ' or the Roku's MENU > "Show games not in guide" is off
    showMissing = not isFalse(m.data.show_unmatched)
    if m.games <> invalid then
        if isFalse(m.games.showUnmatched) then showMissing = false
        if m.games.games <> invalid then
            for each g in m.games.games
                for each c in g.chans
                    seen[strv(c.number) + "|" + intv(c.start).ToStr()] = true
                end for
                started = (g.state = "in" or intv(g.start) <= now)
                if g.chans.Count() > 0 then
                    if started then gNow.Push(g) else up.Push(g)
                else if showMissing then
                    if started then gNowMissing.Push(g) else up.Push(g)
                end if
            end for
        end if
    end if
    m.nowList.Append(gNow)
    for each p in m.data.on_now
        if p.ch = invalid or seen[strv(p.ch.number) + "|" + intv(p.start).ToStr()] = invalid then m.nowList.Push(p)
    end for
    m.nowList.Append(gNowMissing)
    for each p in m.data.upcoming
        if p.ch = invalid or seen[strv(p.ch.number) + "|" + intv(p.start).ToStr()] = invalid then up.Push(p)
    end for
    up.SortBy("start")
    m.upList = up
end sub

sub onGroup()
    g = m.top.group
    if not isAA(g) or g.feeds = invalid then return
    g.feeds = aaList(g.feeds)
    m.grp = g
    m.top.groupName = strv(g.name)
    m.showSlots = false
    m.sel = 0
    if g.feeds.Count() > 0 then m.sel = 2
    m.top0 = 0
    m.zone = "main"
    render()
end sub

sub onCheck()
    if m.grp <> invalid then render()
end sub

sub onMessage()
    m.msgLbl.text = plainText(m.top.message)
end sub

' ------------------------------------------------------------ helpers
function isBool(v as Dynamic) as Boolean
    t = Type(v)
    return t = "Boolean" or t = "roBoolean"
end function

function isTrue(v as Dynamic) as Boolean
    if not isBool(v) then return false
    return v = true
end function

function isFalse(v as Dynamic) as Boolean
    if not isBool(v) then return false
    return v = false
end function

function isAA(v as Dynamic) as Boolean
    return Type(v) = "roAssociativeArray"
end function

' always an array, holding only the entries that are objects
function aaList(v as Dynamic) as Object
    out = []
    if Type(v) <> "roArray" then return out
    for each e in v
        if isAA(e) then out.Push(e)
    end for
    return out
end function

' /api/sports reply with every list present, so the rest of the view never touches a missing one
function cleanData(d as Dynamic) as Dynamic
    if not isAA(d) then return invalid
    d.on_now = aaList(d.on_now)
    d.upcoming = aaList(d.upcoming)
    d.channels = aaList(d.channels)
    d.groups = aaList(d.groups)
    for each lst in [d.on_now, d.upcoming]
        for each p in lst
            if not isAA(p.ch) then p.ch = invalid
            if not isAA(p.event) then p.event = invalid
            p.start = intv(p.start)
            p.stop = intv(p.stop)
        end for
    end for
    for each c in d.channels
        if not isAA(c.now) then c.now = invalid
    end for
    return d
end function

function cleanGames(gs as Dynamic) as Dynamic
    if not isAA(gs) then return invalid
    gs.games = aaList(gs.games)
    for each g in gs.games
        g.chans = aaList(g.chans)
        g.start = intv(g.start)
        g.state = strv(g.state)
    end for
    return gs
end function

function strv(v as Dynamic) as String
    if v = invalid then return ""
    t = Type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v.ToStr()
    return anyStr(v)     ' keeps every digit of a whole Float / Double
end function

' Numbers from ParseJson can arrive boxed (roInteger, roLongInteger...) after crossing a node field,
' so every numeric type name is accepted; an unknown type used to come back as 0 (= Wed 7:00 PM).
function intv(v as Dynamic) as Integer
    if v = invalid then return 0
    t = Type(v)
    if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return v
    if t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" then return Int(v)
    if t = "String" or t = "roString" then return v.Trim().ToInt()
    return 0
end function

function whenText(t as Integer) as String
    if fmtDay(t) = fmtDay(nowEpoch()) then return fmtClock(t)
    return Left(localDT(t).GetWeekday(), 3) + " " + fmtClock(t)
end function

function inText(t as Integer) as String
    mins = Int((t - nowEpoch()) / 60)
    if mins < 1 then mins = 1
    if mins < 60 then return "in " + mins.ToStr() + " min"
    mm = mins mod 60
    mmStr = mm.ToStr()
    if mm < 10 then mmStr = "0" + mmStr
    return "in " + Int(mins / 60).ToStr() + " h " + mmStr
end function

function agoText(t as Integer) as String
    mins = Int((nowEpoch() - t) / 60)
    if mins < 1 then return "just now"
    if mins < 60 then return mins.ToStr() + " min ago"
    if mins < 1440 then return Int(mins / 60).ToStr() + " h ago"
    return Int(mins / 1440).ToStr() + " days ago"
end function

function chLabel(ch as Dynamic) as String
    if Type(ch) <> "roAssociativeArray" then return "Channel unknown"
    lbl = strv(ch.label)
    if lbl = "" then lbl = strv(ch.name)
    return strv(ch.number) + " " + lbl
end function

function mkItem(kind as String, badge as String, title as String, subt as String, right as String, act as Object) as Object
    return { kind: kind, badge: badge, title: title, subt: subt, right: right, act: act, pct: -1 }
end function

' a game from the Roku's own schedule (it has "chans"), or a row from TunerBox
function isGame(x as Object) as Boolean
    return x.chans <> invalid
end function

function leagueSport(id as String) as String
    if id = "nfl" or id = "ncaaf" then return "Football"
    if id = "nba" or id = "wnba" or id = "ncaab" or id = "ncaaw" then return "Basketball"
    if id = "mlb" then return "Baseball"
    if id = "nhl" then return "Hockey"
    if id = "mls" or id = "epl" then return "Soccer"
    if id = "ufc" or id = "pfl" then return "MMA"
    return ""
end function

' the rail's name for a row's sport: MMA and Boxing go together as Fights
function groupOf(x as Object) as String
    s = ""
    if isGame(x) then
        s = leagueSport(strv(x.lg))
    else
        s = strv(x.sport)
        if s = "" and x.event <> invalid then s = strv(x.event.sport)
    end if
    if s = "MMA" or s = "Boxing" then return "Fights"
    if s = "" then return "Other"
    return s
end function

function kindOf(x as Object) as String
    if isGame(x) then return "game"
    if x.event <> invalid then return "game"
    return strv(x.kind)
end function

function hiddenRow(x as Object) as Boolean
    if m.showRep then return false
    k = kindOf(x)
    return k = "replay" or k = "show"
end function

function liveRow(x as Object) as Boolean
    if isGame(x) then return x.state = "in"
    if x.event <> invalid then return strv(x.event.state) = "in"
    k = strv(x.kind)
    return intv(x.is_live) <> 0 or k = "live"
end function

function favRow(x as Object) as Boolean
    if isGame(x) or x.event = invalid then return false
    return Type(x.event.fav) = "roArray" and x.event.fav.Count() > 0
end function

function pctOf(x as Object) as Integer
    if isGame(x) then
        if x.chans.Count() = 0 then return -1
        st = intv(x.chans[0].start)
        sp = intv(x.chans[0].stop)
    else
        st = intv(x.start)
        sp = intv(x.stop)
    end if
    now = nowEpoch()
    if sp <= st or now < st or now >= sp then return -1
    return Int((now - st) * 100 / (sp - st))
end function

' title / subtitle / score of a row: a game is headed by its league and teams
function rowText(x as Object) as Object
    if isGame(x) then
        sb = strv(x.league)
        if strv(x.score) <> "" then sb = sb + "  " + strv(x.score)
        if strv(x.detail) <> "" and x.state = "in" then sb = sb + "  " + Chr(183) + " " + strv(x.detail)
        return { title: strv(x.title), subt: sb }
    end if
    if x.event <> invalid then
        hd = strv(x.heading)
        if hd = "" then hd = strv(x.event.league)
        sb = strv(x.matchup)
        if sb = "" then sb = strv(x.event.name)
        sc = strv(x.event.score)
        if strv(x.event.detail) <> "" then
            if sc <> "" then sc = sc + " " + Chr(183) + " "
            sc = sc + strv(x.event.detail)
        end if
        if sc <> "" then sb = sb + "  " + sc
        return { title: hd, subt: sb }
    end if
    return { title: strv(x.title), subt: strv(x.subtitle) }
end function

function whereText(x as Object, until as Boolean) as String
    if isGame(x) then
        n = x.chans.Count()
        if n = 0 then
            rt = "Not in guide"
            if strv(x.nets) <> "" then rt = rt + " " + Chr(183) + " " + strv(x.nets)
            return rt
        end if
        rt = chLabel(x.chans[0])
        if n > 1 then rt = rt + "  +" + (n - 1).ToStr()
        if until and x.state = "in" then rt = rt + " " + Chr(183) + " until " + fmtClock(intv(x.chans[0].stop))
        return rt
    end if
    if x.ch = invalid then
        if isAA(x.feed) then return strv(x.feed.group)
        return "no channel"
    end if
    rt = chLabel(x.ch)
    if Type(x.also) = "roArray" and x.also.Count() > 0 then rt = rt + "  +" + x.also.Count().ToStr()
    if until and intv(x.start) <= nowEpoch() then rt = rt + " " + Chr(183) + " until " + fmtClock(intv(x.stop))
    return rt
end function

function actOf(x as Object) as Object
    if isGame(x) then return { t: "game", g: x }
    if x.ch = invalid and isAA(x.feed) then return { t: "feed", f: x.feed, kind: strv(x.feed.kind) }
    return { t: "program", p: x }
end function

' a list row for a game or listing
function rowItem(x as Object) as Object
    now = nowEpoch()
    tx = rowText(x)
    k = kindOf(x)
    st = intv(x.start)
    if st > now then
        bk = "norm"
        bt = whenText(st)
    else if liveRow(x) then
        bk = "live"
        bt = "LIVE"
    else if k = "replay" then
        bk = "off"
        bt = "REPLAY"
    else if k = "show" then
        bk = "norm"
        bt = "SHOW"
    else
        bk = "norm"
        bt = "ON"
    end if
    if isGame(x) and x.chans.Count() = 0 then bk = "off"
    it = mkItem(bk, bt, tx.title, tx.subt, whereText(x, true), actOf(x))
    it.pct = pctOf(x)
    return it
end function

' the heading a row goes under: ON NOW, LATER TODAY, TOMORROW, then the day
function dayHead(x as Object) as String
    now = nowEpoch()
    st = intv(x.start)
    if st <= now then return "ON NOW"
    if fmtDay(st) = fmtDay(now) then return "LATER TODAY"
    if fmtDay(st) = fmtDay(now + 86400) then return "TOMORROW"
    return UCase(fmtDay(st))
end function

sub pushByDay(items as Object, rows as Object, skip as Dynamic)
    head = ""
    for each x in rows
        if not sameRow(x, skip) then
            h = dayHead(x)
            if h <> head then
                head = h
                items.Push(secItem(h))
            end if
            it = rowItem(x)
            if intv(x.start) > nowEpoch() then it.badge = fmtClock(intv(x.start))   ' the day is in the heading
            items.Push(it)
        end if
    end for
end sub

function secItem(label as String) as Object
    return mkItem("sec", "", label, "", "", { t: "none" })
end function

function gamesStatus() as String
    gs = m.games
    if gs = invalid then return "Checking live game schedules..."
    if strv(gs.leagues) = "" then return ""
    if not isTrue(gs.ok) then return ""
    if isFalse(gs.hasGuide) then return "guide not loaded yet"
    return ""
end function

function feedBadge(f as Object, kind as String) as Object
    st = strv(f.status)
    if st = "ok" then return { kind: "live", badge: "LIVE" }
    if isTrue(f.ended) then return { kind: "off", badge: "ENDED" }
    if isTrue(f.slot) then return { kind: "off", badge: "EMPTY" }
    if st = "dead" then return { kind: "off", badge: "OFF AIR" }
    if kind = "ppv" then return { kind: "ppv", badge: "PPV" }
    return { kind: "norm", badge: "EVENT" }
end function

' ------------------------------------------------------------ the left list
function buildRail() as Object
    rail = []
    now = nowEpoch()
    nNow = 0
    nLive = 0
    for each x in m.nowList
        if not hiddenRow(x) then nNow = nNow + 1
        if liveRow(x) then nLive = nLive + 1
    end for
    rail.Push({ key: "now", name: "Live now", n: nNow, live: nLive })
    nFav = 0
    nFavLive = 0
    for each lst in [m.nowList, m.upList]
        for each x in lst
            if favRow(x) then
                nFav = nFav + 1
                if intv(x.start) <= now then nFavLive = nFavLive + 1
            end if
        end for
    end for
    if nFav > 0 then rail.Push({ key: "fav", name: "Your teams", n: nFav, live: nFavLive })
    nUp = 0
    for each x in m.upList
        if not hiddenRow(x) then nUp = nUp + 1
    end for
    rail.Push({ key: "up", name: "Coming up", n: nUp, live: 0 })
    rail.Push({ line: true })

    ' each sport: live ones first, then the busiest; Other last
    lt = localDT(now)
    eod = now - (lt.GetHours() * 3600 + lt.GetMinutes() * 60 + lt.GetSeconds()) + 86400    ' midnight tonight
    by = {}
    order = []
    for each lst in [m.nowList, m.upList]
        for each x in lst
            if not hiddenRow(x) then
                g = groupOf(x)
                if by[g] = invalid then
                    by[g] = { key: "s:" + g, name: g, n: 0, live: 0, later: 0, nextAt: 0 }
                    order.Push(g)
                end if
                e = by[g]
                if intv(x.start) < eod then
                    e.n = e.n + 1
                else
                    e.later = e.later + 1
                    if e.nextAt = 0 or intv(x.start) < e.nextAt then e.nextAt = intv(x.start)
                end if
                if intv(x.start) <= now and liveRow(x) then e.live = e.live + 1
            end if
        end for
    end for
    sports = []
    for each g in order
        e = by[g]
        e.sk = 0 - e.live * 100000 - e.n
        if g = "Other" then e.sk = e.sk + 100000000
        sports.Push(e)
    end for
    sports.SortBy("sk")
    ' a sport with nothing on today folds under "More sports" (unless it's the one picked)
    m.moreSports = []
    for each e in sports
        if e.n = 0 and e.key <> m.sec then m.moreSports.Push(e) else rail.Push(e)
    end for
    if m.moreSports.Count() > 0 then rail.Push({ key: "more", name: "More sports", n: m.moreSports.Count(), live: 0 })
    rail.Push({ line: true })
    if m.data <> invalid then
        rail.Push({ key: "ch", name: "Sports channels", n: m.data.channels.Count(), live: 0 })
        rail.Push({ key: "ev", name: "Event feeds", n: m.data.groups.Count(), live: 0 })
    end if
    return rail
end function

' ------------------------------------------------------------ the right side
' the biggest thing: the first live game, else (pickNext) the next live broadcast or game, else what's next
function closeRow(x as Object) as Boolean
    if isGame(x) or x.event = invalid then return false
    return isTrue(x.event.close) or isTrue(x.event.ot)
end function

function pickHero(rows as Object, pickNext as Boolean) as Dynamic
    now = nowEpoch()
    ' a favorite team's game, then a close one late on (a newer TunerBox marks it), then the first live game
    for each x in rows
        if intv(x.start) <= now and liveRow(x) and favRow(x) then return x
    end for
    for each x in rows
        if intv(x.start) <= now and liveRow(x) and closeRow(x) then return x
    end for
    for each x in rows
        if intv(x.start) <= now and liveRow(x) and kindOf(x) = "game" then return x
    end for
    for each x in rows
        if intv(x.start) <= now and liveRow(x) then return x
    end for
    if not pickNext then return invalid
    for each x in rows
        st = intv(x.start)
        k = kindOf(x)
        if st > now and st < now + 86400 and (k = "game" or k = "live") then return x
    end for
    for each x in rows
        if intv(x.start) > now then return x
    end for
    return invalid
end function

' live rows first, then the rest, each in the order they came ("Live:" in a title counts, not just the guide's flag)
function liveFirst(rows as Object) as Object
    out = []
    rest = []
    for each x in rows
        if liveRow(x) then out.Push(x) else rest.Push(x)
    end for
    out.Append(rest)
    return out
end function

function visibleRows(lst as Object, g as String) as Object
    out = []
    for each x in lst
        if not hiddenRow(x) and (g = "" or groupOf(x) = g) then out.Push(x)
    end for
    return out
end function

function hiddenCount(lists as Object, g as String) as Integer
    n = 0
    for each lst in lists
        for each x in lst
            k = kindOf(x)
            if (k = "replay" or k = "show") and (g = "" or groupOf(x) = g) then n = n + 1
        end for
    end for
    return n
end function

function repItem(n as Integer) as Object
    lbl = "Show " + n.ToStr() + " replays and shows"
    if m.showRep then lbl = "Hide replays and shows"
    return mkItem("head", "", lbl, "", "", { t: "reps" })
end function

' fills m.hero and returns the list rows for the picked section
function buildItems() as Object
    items = []
    m.hero = invalid
    d = m.data
    if d = invalid then return items
    now = nowEpoch()
    sec = m.sec
    if sec = "now" or sec = "fav" then
        if sec = "fav" then
            rows = []
            for each lst in [m.nowList, m.upList]
                for each x in lst
                    if favRow(x) and not hiddenRow(x) then rows.Push(x)
                end for
            end for
        else
            rows = liveFirst(visibleRows(m.nowList, ""))
        end if
        m.hero = pickHero(rows, sec = "fav")
        for each x in rows
            if not sameRow(x, m.hero) then items.Push(rowItem(x))
        end for
        if sec = "now" then
            n = hiddenCount([m.nowList], "")
            if n > 0 then items.Push(repItem(n))
            ' your teams' games first, then by start
            soon = []
            for each pass in [true, false]
                for each x in m.upList
                    if favRow(x) = pass and not hiddenRow(x) and intv(x.start) < now + 12 * 3600 and soon.Count() < 4 then soon.Push(x)
                end for
            end for
            if soon.Count() > 0 then
                items.Push(secItem("STARTING SOON"))
                for each x in soon
                    it = rowItem(x)
                    it.badge = inText(intv(x.start))
                    items.Push(it)
                end for
            end if
        end if
        if items.Count() = 0 and m.hero = invalid then items.Push(mkItem("none", "", "No sports on right now, according to the TV guide.", "", "", { t: "none" }))
    else if sec = "up" then
        rows = visibleRows(m.upList, "")
        pushByDay(items, rows, invalid)
        n = hiddenCount([m.upList], "")
        if n > 0 then items.Push(repItem(n))
        if rows.Count() = 0 then items.Push(mkItem("none", "", "No upcoming sports in the TV guide.", "", "", { t: "none" }))
    else if Left(sec, 2) = "s:" then
        g = Mid(sec, 3)
        rows = visibleRows(m.nowList, g)
        rows.Append(visibleRows(m.upList, g))
        m.hero = pickHero(rows, true)
        pushByDay(items, rows, m.hero)
        n = hiddenCount([m.nowList, m.upList], g)
        if n > 0 then items.Push(repItem(n))
    else if sec = "more" then
        for each e in m.moreSports
            rt = e.later.ToStr() + " coming up"
            if e.nextAt > 0 then rt = rt + " " + Chr(183) + " next " + whenText(e.nextAt)
            items.Push(mkItem("head", "", e.name, "", rt, { t: "sport", key: e.key }))
        end for
    else if sec = "ch" then
        for each c in d.channels
            rt = ""
            if c.now <> invalid then
                rt = strv(c.now.title)
                if intv(c.now.is_live) <> 0 then rt = "LIVE " + Chr(183) + " " + rt
            end if
            items.Push(mkItem("num", strv(c.number), strv(c.name), "", rt, { t: "channel", ch: c }))
        end for
        if items.Count() = 0 then items.Push(mkItem("none", "", "No sports channels found.", "", "", { t: "none" }))
    else
        if m.grp = invalid then
            for each g in d.groups
                bt = "EVENTS"
                bk = "norm"
                if strv(g.kind) = "ppv" then
                    bt = "PPV"
                    bk = "ppv"
                end if
                rt = ""
                if intv(g.live) > 0 then rt = intv(g.live).ToStr() + " live " + Chr(183) + " "
                if intv(g.named) > 0 then
                    rt = rt + intv(g.named).ToStr() + " event"
                    if intv(g.named) <> 1 then rt = rt + "s"
                else
                    rt = rt + intv(g.count).ToStr() + " feeds"
                end if
                items.Push(mkItem(bk, bt, strv(g.name), "", rt, { t: "group", name: strv(g.name) }))
            end for
            if items.Count() = 0 then items.Push(mkItem("none", "", "None of your playlists have event or PPV groups (like ESPN+, PPV or NFL Game Pass).", "", "", { t: "none" }))
        else
            items = groupItems()
        end if
    end if
    return items
end function

function sameRow(a as Dynamic, b as Dynamic) as Boolean
    if a = invalid or b = invalid then return false
    if isGame(a) <> isGame(b) then return false
    if isGame(a) then return strv(a.lg) = strv(b.lg) and strv(a.id) = strv(b.id)
    return intv(a.start) = intv(b.start) and strv(a.title) = strv(b.title) and chLabel(a.ch) = chLabel(b.ch)
end function

function groupItems() as Object
    g = m.grp
    items = []
    items.Push(mkItem("head", "", "<  All event groups", "", "", { t: "back" }))
    st = m.top.checkState
    running = (isAA(st) and isTrue(st.running))
    if running then
        items.Push(mkItem("head", "", "Checking which feeds are live... " + intv(st.done).ToStr() + "/" + intv(st.total).ToStr(), "", "", { t: "none" }))
    else if intv(g.checkable) > 0 then
        lbl = "Check which feeds are live now"
        if intv(g.checked) > 0 then lbl = lbl + "  (last checked " + agoText(intv(g.checked)) + ")"
        items.Push(mkItem("head", "", lbl, "", "", { t: "check", name: strv(g.name) }))
    else
        items.Push(mkItem("head", "", "These feeds are from Xtream, which isn't checked automatically. Just pick one to try it.", "", "", { t: "none" }))
    end if
    real = []
    slots = []
    for each f in g.feeds
        if not isTrue(f.slot) or strv(f.status) = "ok" then
            real.Push(f)
        else
            slots.Push(f)
        end if
    end for
    shown = g.feeds
    if real.Count() > 0 and not m.showSlots then shown = real
    for each f in shown
        b = feedBadge(f, strv(g.kind))
        items.Push(mkItem(b.kind, b.badge, strv(f.name), "", strv(f.group), { t: "feed", f: f, kind: strv(g.kind) }))
    end for
    if real.Count() > 0 and slots.Count() > 0 then
        lbl = "Show " + slots.Count().ToStr() + " empty and ended slots"
        if m.showSlots then lbl = "Hide empty and ended slots"
        items.Push(mkItem("head", "", lbl, "", "", { t: "slots" }))
    end if
    return items
end function

' ------------------------------------------------------------ drawing
' Full refresh: rebuilds the rail, the box and the list. Moving the selection only needs drawRows().
sub render()
    m.rail = buildRail()
    m.ri = -1
    for i = 0 to m.rail.Count() - 1
        if not m.rail[i].DoesExist("line") and m.rail[i].key = m.sec then m.ri = i
    end for
    if m.ri < 0 then
        m.ri = 0
        m.sec = m.rail[0].key
    end if
    m.items = []
    if m.data <> invalid then m.items = buildItems()
    if m.hero = invalid then m.heroSel = false
    drawRail()

    if m.data = invalid then
        m.secLbl.text = ""
        m.statusLbl.text = ""
        m.footLbl.text = "Back  Close"
        drawHero()
        layoutRows()
        drawRows(true)
        return
    end if

    e = m.rail[m.ri]
    m.secLbl.text = plainText(e.name)
    st = ""
    if m.sec = "now" then
        st = e.live.ToStr() + " live"
        gs = gamesStatus()
        if gs <> "" then st = st + "  " + Chr(183) + "  " + gs
    else if Left(m.sec, 2) = "s:" then
        st = e.live.ToStr() + " on now  " + Chr(183) + "  " + (e.n - e.live).ToStr() + " later"
    else if m.sec = "ev" and m.grp <> invalid then
        g = m.grp
        m.secLbl.text = plainText(strv(g.name))
        st = intv(g.count).ToStr() + " feeds"
        if intv(g.live) > 0 then st = st + "  " + Chr(183) + "  " + intv(g.live).ToStr() + " live"
    end if
    m.statusLbl.text = plainText(st)
    if m.zone = "rail" then
        m.footLbl.text = "Up / Down  Pick      Right  Go in      Back  Close"
    else if m.sec = "ev" and m.grp <> invalid then
        m.footLbl.text = "OK  Watch      Back  Groups      Event feeds only have video while the event is on."
    else
        m.footLbl.text = "Up / Down  Move      Left  Back to the list      OK  Watch / Record      Back  Close"
    end if
    drawHero()
    layoutRows()
    drawRows(true)
end sub

sub drawRail()
    n = m.rail.Count()
    if m.ri < m.railTop then m.railTop = m.ri
    if m.ri >= m.railTop + m.RAIL_N then m.railTop = m.ri - m.RAIL_N + 1
    for r = 0 to m.RAIL_N - 1
        rr = m.railRows[r]
        i = m.railTop + r
        if i >= n then
            for each k in ["bg", "line", "name", "liveBg", "live", "count"]
                rr[k].visible = false
            end for
        else
            e = m.rail[i]
            if e.DoesExist("line") then
                for each k in ["bg", "name", "liveBg", "live", "count"]
                    rr[k].visible = false
                end for
                rr.line.visible = true
            else
                rr.line.visible = false
                sel = (i = m.ri)
                focus = sel and m.zone = "rail"
                rr.bg.visible = sel
                if focus then
                    rr.bg.color = thm("0xFFC845FF")
                    rr.name.color = thm("0x111111FF")
                    rr.count.color = thm("0x34415FFF")
                else if sel then
                    rr.bg.color = thm("0xFFFFFF22")
                    rr.name.color = thm("0xFFFFFFFF")
                    rr.count.color = thm("0xA9BEE8FF")
                else
                    rr.name.color = thm("0xCFE0FFFF")
                    rr.count.color = thm("0xA9BEE8FF")
                end if
                rr.name.text = plainText(e.name)
                rr.name.visible = true
                if e.n > 0 then rr.count.text = e.n.ToStr() else rr.count.text = ""
                rr.count.visible = true
                lv = (e.live > 0)
                rr.liveBg.visible = lv
                rr.live.visible = lv
                if lv then rr.live.text = e.live.ToStr()
            end if
        end if
    end for
end sub

sub drawHero()
    h = m.heroN
    x = m.hero
    if x = invalid then
        for each k in ["ring", "bg", "stripe", "tagBg", "tag", "head", "big", "where", "ok", "progBg", "prog"]
            h[k].visible = false
        end for
        return
    end if
    now = nowEpoch()
    live = intv(x.start) <= now
    tagTxt = "NEXT UP"
    tagCol = thm("0x2ED47AFF")
    tagTc = thm("0x062013FF")
    if favRow(x) then
        tagTxt = "YOUR TEAM"
        tagCol = thm("0xFFC845FF")
        tagTc = thm("0x111111FF")
    else if live and liveRow(x) and closeRow(x) then
        tagTxt = "CLOSE GAME"
        if isTrue(x.event.ot) then tagTxt = "OVERTIME"
        tagCol = thm("0xFF9F1CFF")
        tagTc = thm("0x1A0F00FF")
    else if live and liveRow(x) then
        tagTxt = "LIVE"
        tagCol = thm("0xE0243CFF")
        tagTc = thm("0xFFFFFFFF")
    else if live then
        tagTxt = "ON NOW"
        tagCol = thm("0x3B5B96FF")
        tagTc = thm("0xFFFFFFFF")
    end if
    h.tagBg.color = tagCol
    h.tag.color = tagTc
    h.tag.text = tagTxt
    ' the big line: the matchup and score for a game, else the show; the small line over it says what it is
    stripe = thm("0x3B5B96FF")
    if isGame(x) then
        big = strv(x.title)
        if strv(x.score) <> "" then big = big + "    " + strv(x.score)
        head = strv(x.league)
        if strv(x.detail) <> "" and x.state = "in" then head = head + "  " + Chr(183) + "  " + strv(x.detail)
    else if x.event <> invalid then
        big = strv(x.event.name)
        tms = x.event.teams
        if Type(tms) = "roArray" and tms.Count() = 2 and isAA(tms[0]) and isAA(tms[1]) then
            if strv(tms[0].score) <> "" and strv(tms[1].score) <> "" and strv(x.event.state) <> "pre" then
                big = strv(tms[0].name) + "  " + strv(tms[0].score) + " - " + strv(tms[1].score) + "  " + strv(tms[1].name)
            end if
            if Len(strv(tms[0].color)) = 6 then stripe = "0x" + UCase(strv(tms[0].color)) + "FF"
        end if
        head = strv(x.heading)
        if head = "" then head = strv(x.event.league)
        if strv(x.event.detail) <> "" then head = head + "  " + Chr(183) + "  " + strv(x.event.detail)
    else
        big = strv(x.title)
        head = strv(x.sport)
        if strv(x.subtitle) <> "" then head = head + "  " + Chr(183) + "  " + strv(x.subtitle)
    end if
    if not live then head = whenText(intv(x.start)) + "  " + Chr(183) + "  " + inText(intv(x.start)) + "   " + head
    h.stripe.color = stripe
    h.head.text = plainText(head)
    h.big.text = plainText(big)
    h.where.text = plainText(whereText(x, true))
    if live then h.ok.text = "OK  Watch" else h.ok.text = "OK  Record"
    p = pctOf(x)
    h.progBg.visible = (p >= 0)
    h.prog.visible = (p >= 0)
    if p >= 0 then h.prog.width = Int((m.ROW_W - 70) * p / 100) + 1
    h.ring.visible = m.heroSel and m.zone = "main"
    for each k in ["bg", "stripe", "tagBg", "tag", "head", "big", "where", "ok"]
        h[k].visible = true
    end for
end sub

' the list starts under the box
sub layoutRows()
    y = m.HERO_Y
    if m.hero <> invalid then y = y + m.HERO_H + 22
    m.rowY0 = y
    n = Int((990 - y) / m.ROW_H)
    if n > m.NROWS then n = m.NROWS
    if n < 2 then n = 2
    m.nVis = n
    for r = 0 to m.NROWS - 1
        row = m.rows[r]
        row.y = y + r * m.ROW_H
    end for
    m.drawnTop = -1
end sub

' Paints the visible window of m.items. With full = false and no scrolling, only the row that lost
' the selection and the row that gained it are repainted.
sub drawRows(full as Boolean)
    n = m.items.Count()
    if m.sel > n - 1 then m.sel = n - 1
    if m.sel < 0 then m.sel = 0
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.nVis then m.top0 = m.sel - m.nVis + 1
    rowSel = m.zone = "main" and not m.heroSel

    if not full and m.top0 = m.drawnTop then
        for each i in [m.drawnSel, m.sel]
            r = i - m.top0
            if r >= 0 and r < m.nVis and i < n then paintRow(r, m.items[i], (i = m.sel and rowSel))
        end for
    else
        for r = 0 to m.NROWS - 1
            i = m.top0 + r
            if r < m.nVis and i < n then
                paintRow(r, m.items[i], (i = m.sel and rowSel))
            else
                hideRow(r)
            end if
        end for
    end if
    m.drawnTop = m.top0
    m.drawnSel = m.sel
end sub

sub hideRow(r as Integer)
    row = m.rows[r]
    for each k in ["bg", "badgeBg", "badge", "title", "subt", "right", "prog"]
        row[k].visible = false
    end for
end sub

sub paintRow(r as Integer, it as Object, selected as Boolean)
    row = m.rows[r]
    y = row.y
    x0 = m.ROW_X
    rh = m.ROW_H - 6
    if it.kind = "sec" then
        ' a heading in the list ("STARTING SOON", a day)
        hideRow(r)
        row.title.translation = [x0 + 4, y]
        row.title.width = 0
        row.title.color = thm("0xA9BEE8FF")
        row.title.text = plainText(it.title)
        row.title.visible = true
        return
    end if
    if selected then
        row.bg.color = thm("0xFFC845FF")
        tc = thm("0x111111FF")
        sc = thm("0x34415FFF")
        rc = thm("0x222222FF")
    else
        row.bg.color = thm("0x1C4FA855")
        tc = thm("0xFFFFFFFF")
        sc = thm("0xA9BEE8FF")
        rc = thm("0xCFE0FFFF")
    end if
    row.bg.translation = [x0, y]
    row.bg.visible = true

    tx = x0 + 14
    badge = plainText(it.badge)
    if badge <> "" then
        bw = Len(badge) * 14 + 30
        if bw < 104 then bw = 104
        bg = thm("0x3B5B96FF")
        if it.kind = "live" then bg = thm("0xE0243CFF")
        if it.kind = "ppv" then bg = thm("0x7A3FB5FF")
        if it.kind = "off" then bg = thm("0x4A5568FF")
        if it.kind = "num" then
            bg = thm("0x16397AFF")
            if selected then bg = thm("0x7A5A10FF")
        end if
        row.badgeBg.translation = [tx, y + 14]
        row.badgeBg.width = bw
        row.badgeBg.color = bg
        row.badgeBg.visible = true
        row.badge.translation = [tx, y + 14]
        row.badge.width = bw
        row.badge.text = badge
        row.badge.visible = true
        tx = tx + bw + 16
    else
        row.badgeBg.visible = false
        row.badge.visible = false
    end if

    rightX = x0 + m.ROW_W - 560
    ' title (natural width, capped), then the subtitle right after it; the width is measured once per item
    if it.tw = invalid then
        m.measLbl.text = plainText(it.title)
        tw = m.measLbl.boundingRect().width
        if tw <= 0 then tw = Len(m.measLbl.text) * 16
        it.tw = tw
    end if
    tw = it.tw
    maxT = rightX - 20 - tx
    if it.subt <> "" then maxT = 460
    if it.kind = "none" or it.kind = "head" then maxT = m.ROW_W - 40 - (tx - x0)
    tl = row.title
    tl.translation = [tx, y]
    tl.color = tc
    if tw > maxT then
        tl.width = maxT
        tw = maxT
    else
        tl.width = 0
    end if
    tl.text = plainText(it.title)
    tl.visible = true

    showSub = false
    if it.subt <> "" then
        sx = tx + tw + 12
        sw = rightX - 20 - sx
        if sw > 60 then
            row.subt.translation = [sx, y]
            row.subt.width = sw
            row.subt.color = sc
            row.subt.text = plainText(Chr(183) + " " + it.subt)
            showSub = true
        end if
    end if
    row.subt.visible = showSub

    if it.right <> "" then
        row.right.translation = [rightX, y]
        row.right.color = rc
        row.right.text = plainText(it.right)
        row.right.visible = true
    else
        row.right.visible = false
    end if

    if it.pct >= 0 then
        row.prog.translation = [x0, y + rh - 4]
        row.prog.width = Int(m.ROW_W * it.pct / 100) + 1
        row.prog.visible = true
    else
        row.prog.visible = false
    end if
end sub

' ------------------------------------------------------------ keys
sub pickRail(i as Integer)
    e = m.rail[i]
    if e.DoesExist("line") then return
    m.sec = e.key
    m.grp = invalid
    m.top.groupName = ""
    m.sel = 0
    m.top0 = 0
    m.heroSel = false
    render()
end sub

sub railMove(delta as Integer)
    n = m.rail.Count()
    if n = 0 then return
    i = m.ri
    for k = 1 to n
        i = (i + delta + n) mod n
        if not m.rail[i].DoesExist("line") then exit for
    end for
    pickRail(i)
end sub

sub enterMain()
    if m.hero = invalid and m.items.Count() = 0 then return
    m.zone = "main"
    m.heroSel = (m.hero <> invalid)
    m.sel = firstFocusable(0, 1)
    m.top0 = 0
    render()
end sub

sub backToRail()
    m.zone = "rail"
    m.heroSel = false
    render()
end sub

' the next row that can be highlighted (not a heading), from i going dir; -1 if none
function firstFocusable(i as Integer, dir as Integer) as Integer
    n = m.items.Count()
    while i >= 0 and i < n
        if m.items[i].kind <> "sec" then return i
        i = i + dir
    end while
    return -1
end function

sub move(delta as Integer)
    if m.heroSel then
        if delta > 0 then
            j = firstFocusable(0, 1)
            if j < 0 then return
            m.heroSel = false
            m.sel = j
            m.top0 = 0
            drawHero()
            drawRows(true)
        end if
        return
    end if
    if m.items.Count() = 0 then return
    dir = 1
    if delta < 0 then dir = -1
    target = m.sel + delta
    if target < 0 then target = 0
    if target > m.items.Count() - 1 then target = m.items.Count() - 1
    j = firstFocusable(target, dir)
    if j < 0 then j = firstFocusable(target, 0 - dir)
    if delta < 0 and (j < 0 or j >= m.sel) then
        ' up from the first row: to the box at the top, if there is one
        if m.hero <> invalid then
            m.heroSel = true
            drawHero()
            drawRows(true)
        end if
        return
    end if
    if j < 0 or j = m.sel then return
    m.sel = j
    drawRows(false)
end sub

sub activate()
    if m.heroSel and m.hero <> invalid then
        a = actOf(m.hero)
    else
        if m.sel < 0 or m.sel >= m.items.Count() then return
        a = m.items[m.sel].act
    end if
    if not isAA(a) then return
    t = a.t
    if t = "program" then
        m.top.request = { type: "program", p: a.p }
    else if t = "game" then
        m.top.request = { type: "game", g: a.g }
    else if t = "channel" then
        m.top.request = { type: "channel", ch: a.ch }
    else if t = "group" then
        m.top.request = { type: "openGroup", name: a.name }
    else if t = "feed" then
        m.top.request = { type: "feed", f: a.f, kind: a.kind }
    else if t = "check" then
        m.top.request = { type: "check", name: a.name }
    else if t = "back" then
        m.grp = invalid
        m.top.groupName = ""
        m.sel = 0
        m.top0 = 0
        render()
    else if t = "slots" then
        m.showSlots = not m.showSlots
        render()
    else if t = "sport" then
        m.sec = a.key
        m.sel = 0
        m.top0 = 0
        m.heroSel = false
        m.zone = "rail"
        render()
    else if t = "reps" then
        m.showRep = not m.showRep
        render()
    end if
end sub

sub goBack()
    if m.sec = "ev" and m.grp <> invalid then
        m.grp = invalid
        m.top.groupName = ""
        m.sel = 0
        m.top0 = 0
        render()
    else if m.zone = "main" then
        backToRail()
    else
        m.top.request = { type: "close" }
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false
    if key = "back" then
        goBack()
    else if key = "options" then
        m.top.request = { type: "close" }
    else if Left(key, 4) = "Lit_" then
        lc = LCase(Mid(key, 5))
        if lc = "t" then
            m.top.request = { type: "close" }
        else
            return false
        end if
    else if m.zone = "rail" then
        if key = "up" then
            railMove(-1)
        else if key = "down" then
            railMove(1)
        else if key = "right" or key = "OK" then
            enterMain()
        else
            return false
        end if
    else
        if key = "left" then
            backToRail()
        else if key = "up" then
            move(-1)
        else if key = "down" then
            move(1)
        else if key = "rewind" or key = "pageup" then
            move(0 - m.nVis)
        else if key = "fastforward" or key = "pagedown" then
            move(m.nVis)
        else if key = "OK" then
            activate()
        else
            return false
        end if
    end if
    return true
end function
