' Sports & PPV panel (mirrors the TunerBox web screen): tabs On Now / Coming Up / Sports Channels / Events & PPV.
' Data comes from TunerBox GET /api/sports; the scene does the networking and playback.

sub init()
    m.ROW_X = 44
    m.ROW_Y = 196
    m.ROW_H = 80
    m.NROWS = 10

    m.titleLbl = m.top.findNode("titleLbl")
    m.tabsGroup = m.top.findNode("tabsGroup")
    m.statusLbl = m.top.findNode("statusLbl")
    m.rowsGroup = m.top.findNode("rowsGroup")
    m.msgLbl = m.top.findNode("msgLbl")
    m.footLbl = m.top.findNode("footLbl")
    m.titleLbl.font.size = 52
    m.statusLbl.font.size = 27
    m.msgLbl.font.size = 36
    m.footLbl.font.size = 27

    m.tabs = ["On Now", "Coming Up", "Sports Channels", "Events & PPV"]
    m.tab = 0
    m.sel = 0
    m.top0 = 0
    m.data = invalid
    m.grp = invalid
    m.showSlots = false
    m.items = []
    m.games = invalid
    m.nowList = []
    m.upList = []
    m.drawnTop = -1
    m.drawnSel = -1
    buildNodes()
end sub

' The tab strip and the visible rows are created once and then only updated, never rebuilt.
sub buildNodes()
    m.tabSel = mkRect(60, 100, 10, 50, "0xFFC845FF")
    m.tabsGroup.appendChild(m.tabSel)
    m.tabLbls = []
    for i = 0 to 3
        l = centerLabel(60, 100, 10, 50, "", "0xCFE0FFFF")
        m.tabsGroup.appendChild(l)
        m.tabLbls.Push(l)
    end for

    ' unseen label used only to measure how wide a title is
    m.measLbl = mkLabel(0, 0, 0, m.ROW_H - 4, "", 33, true, "0xFFFFFFFF")
    m.measLbl.opacity = 0
    m.rowsGroup.appendChild(m.measLbl)

    m.rows = []
    h = m.ROW_H - 4
    tx = m.ROW_X + 16
    for r = 0 to m.NROWS - 1
        y = m.ROW_Y + r * m.ROW_H
        row = { y: y }
        row.bg = mkRect(m.ROW_X, y, 1800, h, "0x1C4FA855")
        row.badgeBg = mkRect(tx, y + 14, 104, h - 28, "0x3B5B96FF")
        row.badge = mkLabel(tx, y + 14, 104, h - 28, "", 24, true, "0xFFFFFFFF")
        row.badge.horizAlign = "center"
        row.title = mkLabel(tx, y, 0, h, "", 33, true, "0xFFFFFFFF")
        row.subt = mkLabel(tx, y, 100, h, "", 27, false, "0xA9BEE8FF")
        row.right = mkLabel(1160, y, 660, h, "", 27, false, "0xCFE0FFFF")
        row.right.horizAlign = "right"
        for each k in ["bg", "badgeBg", "badge", "title", "subt", "right"]
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
    m.tab = 0
    m.sel = 0
    m.top0 = 0
    m.top.message = "Loading Sports & PPV..."
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
    c = counts()
    if c[m.tab] = 0 then
        for i = 0 to 3
            if c[i] > 0 then
                m.tab = i
                exit for
            end if
        end for
    end if
    m.sel = 0
    m.top0 = 0
    render()
end sub

' live games arrive separately (usually after /api/sports): merge them in without moving the selection
sub onGames()
    m.games = cleanGames(m.top.games)
    mergeLists()
    if m.data = invalid then return
    ' still on an empty tab (e.g. nothing in the guide on now)? jump to the games
    c = counts()
    if m.tab <= 1 and c[m.tab] = 0 and m.sel = 0 then
        if c[0] > 0 then
            m.tab = 0
        else if c[1] > 0 then
            m.tab = 1
        end if
    end if
    if m.grp = invalid then render()
end sub

' On Now   = live games found in the guide, then the guide's other sports, then live games not in the guide
' Coming Up = upcoming games + the guide's upcoming sports, by start time
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
    showMissing = true
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
    render()
end sub

sub onCheck()
    if m.grp <> invalid then render()
end sub

sub onMessage()
    m.msgLbl.text = m.top.message
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
    for each p in d.on_now
        if not isAA(p.ch) then p.ch = invalid
    end for
    for each p in d.upcoming
        if not isAA(p.ch) then p.ch = invalid
        p.start = intv(p.start)
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
    if t = "Integer" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "LongInteger" then return Str(v).Trim()
    return ""
end function

function intv(v as Dynamic) as Integer
    if v = invalid then return 0
    t = Type(v)
    if t = "Integer" or t = "roInt" then return v
    if t = "Float" or t = "roFloat" or t = "Double" or t = "LongInteger" then return Int(v)
    return 0
end function

function counts() as Object
    if m.data = invalid then return [0, 0, 0, 0]
    return [m.nowList.Count(), m.upList.Count(), m.data.channels.Count(), m.data.groups.Count()]
end function

function whenText(t as Integer) as String
    if fmtDay(t) = fmtDay(nowEpoch()) then return fmtClock(t)
    return Left(localDT(t).GetWeekday(), 3) + " " + fmtClock(t)
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
    return { kind: kind, badge: badge, title: title, subt: subt, right: right, act: act }
end function

' row for a game from the live sports schedule
function gameItem(g as Object, nowTab as Boolean) as Object
    sb = strv(g.league)
    if strv(g.score) <> "" then sb = sb + "  " + strv(g.score)
    if strv(g.detail) <> "" and (nowTab or g.state = "in") then sb = sb + "  " + Chr(183) + " " + strv(g.detail)
    n = g.chans.Count()
    if n > 0 then
        rt = chLabel(g.chans[0])
        if n > 1 then rt = rt + "  +" + (n - 1).ToStr()
        if nowTab then rt = rt + " " + Chr(183) + " until " + fmtClock(intv(g.chans[0].stop))
    else
        rt = "Not in guide"
        if strv(g.nets) <> "" then rt = rt + " " + Chr(183) + " " + strv(g.nets)
    end if
    if nowTab then
        bk = "norm"
        bt = "ON"
        if g.state = "in" then
            bk = "live"
            bt = "LIVE"
        end if
    else
        bk = "norm"
        bt = whenText(intv(g.start))
    end if
    if n = 0 then bk = "off"
    return mkItem(bk, bt, strv(g.title), sb, rt, { t: "game", g: g })
end function

function gamesStatus() as String
    gs = m.games
    if gs = invalid then return "Checking live game schedules..."
    if strv(gs.leagues) = "" then return "Live game matching is off. Pick leagues in Menu > Live sports leagues."
    if not isTrue(gs.ok) then return ""
    if isFalse(gs.hasGuide) then return strv(gs.leagueNames) + "  " + Chr(183) + "  guide not loaded yet, can't match channels"
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

' ------------------------------------------------------------ list content
function buildItems() as Object
    items = []
    d = m.data
    if d = invalid then return items
    if m.tab = 0 then
        for each p in m.nowList
            if p.chans <> invalid then
                items.Push(gameItem(p, true))
            else
                bk = "norm"
                bt = "ON"
                if intv(p.is_live) <> 0 then
                    bk = "live"
                    bt = "LIVE"
                end if
                items.Push(mkItem(bk, bt, strv(p.title), strv(p.subtitle), chLabel(p.ch) + " " + Chr(183) + " until " + fmtClock(intv(p.stop)), { t: "program", p: p }))
            end if
        end for
        if items.Count() = 0 then items.Push(mkItem("none", "", "No sports on right now, according to the TV guide.", "", "", { t: "none" }))
    else if m.tab = 1 then
        for each p in m.upList
            if p.chans <> invalid then
                items.Push(gameItem(p, false))
            else
                sb = strv(p.subtitle)
                if intv(p.is_live) <> 0 then
                    if sb <> "" then sb = sb + "  "
                    sb = sb + Chr(183) + " LIVE"
                end if
                items.Push(mkItem("norm", whenText(intv(p.start)), strv(p.title), sb, chLabel(p.ch), { t: "program", p: p }))
            end if
        end for
        if items.Count() = 0 then items.Push(mkItem("none", "", "No upcoming sports in the TV guide.", "", "", { t: "none" }))
    else if m.tab = 2 then
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
' Full refresh: rebuilds the list for the current tab. Call when the data, tab or group changes.
' Moving the selection only needs drawRows().
sub render()
    m.items = []
    if m.data <> invalid then m.items = buildItems()
    drawTabs()

    if m.data = invalid then
        m.statusLbl.text = ""
        m.footLbl.text = "Back  Close"
        drawRows(true)
        return
    end if

    if m.tab = 3 and m.grp <> invalid then
        g = m.grp
        s = strv(g.name) + "  " + Chr(183) + "  "
        if intv(g.named) > 0 then s = s + intv(g.named).ToStr() + " events  " + Chr(183) + "  "
        s = s + intv(g.count).ToStr() + " feeds"
        if intv(g.live) > 0 then s = s + "  " + Chr(183) + "  " + intv(g.live).ToStr() + " live"
        m.statusLbl.text = s
        m.footLbl.text = "OK  Watch      Back  Groups      Event feeds only have video while the event is on."
    else
        m.statusLbl.text = ""
        if m.tab <= 1 then m.statusLbl.text = gamesStatus()
        m.footLbl.text = "Left / Right  Tabs      OK  Watch / Record      Back  Close"
    end if

    drawRows(true)
end sub

sub drawTabs()
    c = counts()
    x = 60
    for i = 0 to 3
        txt = m.tabs[i]
        if m.data <> invalid then txt = txt + "  " + c[i].ToStr()
        w = Len(txt) * 16 + 52
        l = m.tabLbls[i]
        l.translation = [x, 100]
        l.width = w
        l.text = txt
        if i = m.tab then
            m.tabSel.translation = [x, 100]
            m.tabSel.width = w
            l.color = "0x10244AFF"
        else
            l.color = "0xCFE0FFFF"
        end if
        x = x + w + 12
    end for
end sub

function centerLabel(x, y, w, h, text as String, color as String) as Object
    l = mkLabel(x, y, w, h, text, 28, true, color)
    l.horizAlign = "center"
    return l
end function

' Paints the visible window of m.items. With full = false and no scrolling, only the row that lost
' the selection and the row that gained it are repainted.
sub drawRows(full as Boolean)
    n = m.items.Count()
    if m.sel > n - 1 then m.sel = n - 1
    if m.sel < 0 then m.sel = 0
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.NROWS then m.top0 = m.sel - m.NROWS + 1

    if not full and m.top0 = m.drawnTop then
        for each i in [m.drawnSel, m.sel]
            r = i - m.top0
            if r >= 0 and r < m.NROWS and i < n then paintRow(r, m.items[i], (i = m.sel))
        end for
    else
        for r = 0 to m.NROWS - 1
            i = m.top0 + r
            if i < n then
                paintRow(r, m.items[i], (i = m.sel))
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
    row.bg.visible = false
    row.badgeBg.visible = false
    row.badge.visible = false
    row.title.visible = false
    row.subt.visible = false
    row.right.visible = false
end sub

sub paintRow(r as Integer, it as Object, selected as Boolean)
    row = m.rows[r]
    y = row.y
    x0 = m.ROW_X
    if selected then
        row.bg.color = "0xFFC845FF"
        tc = "0x111111FF"
        sc = "0x34415FFF"
        rc = "0x222222FF"
    else
        row.bg.color = "0x1C4FA855"
        tc = "0xFFFFFFFF"
        sc = "0xA9BEE8FF"
        rc = "0xCFE0FFFF"
    end if
    row.bg.visible = true

    tx = x0 + 16
    if it.badge <> "" then
        bw = Len(it.badge) * 15 + 32
        if bw < 104 then bw = 104
        bg = "0x3B5B96FF"
        if it.kind = "live" then bg = "0xE0243CFF"
        if it.kind = "ppv" then bg = "0x7A3FB5FF"
        if it.kind = "off" then bg = "0x4A5568FF"
        if it.kind = "num" then
            bg = "0x16397AFF"
            if selected then bg = "0x7A5A10FF"
        end if
        row.badgeBg.width = bw
        row.badgeBg.color = bg
        row.badgeBg.visible = true
        row.badge.width = bw
        row.badge.text = it.badge
        row.badge.visible = true
        tx = tx + bw + 18
    else
        row.badgeBg.visible = false
        row.badge.visible = false
    end if

    rightX = 1160
    ' title (natural width, capped), then the subtitle right after it; the width is measured once per item
    if it.tw = invalid then
        m.measLbl.text = it.title
        tw = m.measLbl.boundingRect().width
        if tw <= 0 then tw = Len(it.title) * 17
        it.tw = tw
    end if
    tw = it.tw
    maxT = rightX - 20 - tx
    if it.subt <> "" then maxT = 680
    if it.kind = "none" or it.kind = "head" then maxT = 1760 - (tx - x0)
    tl = row.title
    tl.translation = [tx, y]
    tl.color = tc
    if tw > maxT then
        tl.width = maxT
        tw = maxT
    else
        tl.width = 0
    end if
    tl.text = it.title
    tl.visible = true

    showSub = false
    if it.subt <> "" then
        sx = tx + tw + 14
        sw = rightX - 20 - sx
        if sw > 60 then
            row.subt.translation = [sx, y]
            row.subt.width = sw
            row.subt.color = sc
            row.subt.text = Chr(183) + " " + it.subt
            showSub = true
        end if
    end if
    row.subt.visible = showSub

    if it.right <> "" then
        row.right.color = rc
        row.right.text = it.right
        row.right.visible = true
    else
        row.right.visible = false
    end if
end sub

' ------------------------------------------------------------ keys
sub setTab(n as Integer)
    if n < 0 then n = 3
    if n > 3 then n = 0
    m.tab = n
    m.grp = invalid
    m.top.groupName = ""
    m.sel = 0
    m.top0 = 0
    render()
end sub

sub move(delta as Integer)
    if m.items.Count() = 0 then return
    n = m.sel + delta
    if n < 0 then n = 0
    if n > m.items.Count() - 1 then n = m.items.Count() - 1
    if n = m.sel then return
    m.sel = n
    drawRows(false)
end sub

sub activate()
    if m.sel < 0 or m.sel >= m.items.Count() then return
    a = m.items[m.sel].act
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
    end if
end sub

sub goBack()
    if m.tab = 3 and m.grp <> invalid then
        m.grp = invalid
        m.top.groupName = ""
        m.sel = 0
        m.top0 = 0
        render()
    else
        m.top.request = { type: "close" }
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false
    if key = "left" then
        setTab(m.tab - 1)
    else if key = "right" then
        setTab(m.tab + 1)
    else if key = "up" then
        move(-1)
    else if key = "down" then
        move(1)
    else if key = "rewind" or key = "pageup" then
        move(0 - m.NROWS)
    else if key = "fastforward" or key = "pagedown" then
        move(m.NROWS)
    else if key = "OK" then
        activate()
    else if key = "back" then
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
    else
        return false
    end if
    return true
end function
