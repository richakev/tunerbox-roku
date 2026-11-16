' Home (mirrors the TunerBox web Home screen): live TV keeps playing in the corner with the highlighted
' tile's details beside it, then rows: shortcuts, favorites on now, Continue Watching (On Demand and
' recordings), sports on now, recent channels, new recordings and what's coming up. Everything comes from
' one request (GET /api/home). The scene only shows Home when TunerBox's "Home screen" setting is on, and
' does what a picked tile asks for (this view only draws and moves the selection).

sub init()
    themeInit()
    m.PV = [0, 0, 1920, 1080]     ' live TV fills the screen behind Home (the scene doesn't fit it to the safe area)
    m.X0 = 40
    m.W = 1840
    m.Y0 = 434
    m.YMAX = 1016
    m.NAV_Y = 22            ' the shortcuts sit in the top bar, not in the rows
    m.LABEL_H = 38
    m.ROW_H = 214
    m.TW = 288
    m.TH = 162
    m.PW = 108
    m.GAP = 18
    m.NSLOTS = 3
    m.NTILES = 14
    m.RESUME_MIN = 30
    homeColors()
    m.NAV = [
        { t: "nav", id: "tv", label: "Watch TV", info: "Back to full-screen TV" },
        { t: "nav", id: "guide", label: "Guide", info: "What's on, channel by channel" },
        { t: "nav", id: "ondemand", label: "On Demand", info: "Movies and TV shows from your playlists" },
        { t: "nav", id: "sports", label: "Sports & Events", info: "Games on now and coming up, scores and event feeds" },
        { t: "nav", id: "search", label: "Search", info: "Channels, shows, games, movies and TV shows" },
        { t: "nav", id: "menu", label: "Menu", info: "Favorites, settings and more" }
    ]

    m.top.previewRect = m.PV
    m.titleLbl = m.top.findNode("titleLbl")
    m.subLbl = m.top.findNode("subLbl")
    m.metaLbl = m.top.findNode("metaLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.brandLbl = m.top.findNode("brandLbl")
    m.brand2Lbl = m.top.findNode("brand2Lbl")
    m.clockLbl = m.top.findNode("clockLbl")
    m.dateLbl = m.top.findNode("dateLbl")
    m.rowsGroup = m.top.findNode("rowsGroup")
    ' the row below the last full one peeks out (cut off above the key hints), so it's clear there's more
    m.rowsGroup.clippingRect = [-200, -200, 2320, m.YMAX + 200 - 4]
    m.msgLbl = m.top.findNode("msgLbl")
    m.hintsGroup = m.top.findNode("hintsGroup")
    m.refreshTimer = m.top.findNode("refreshTimer")
    m.clockTimer = m.top.findNode("clockTimer")
    m.refreshTimer.observeField("fire", "onRefreshTimer")
    m.clockTimer.observeField("fire", "drawClock")

    m.titleLbl.font.size = 62
    m.subLbl.font.size = 30
    m.metaLbl.font.size = 27
    m.descLbl.font.size = 26
    m.brandLbl.font.size = 40
    m.brand2Lbl.font.size = 40
    m.clockLbl.font.size = 30
    m.dateLbl.font.size = 25
    ' "TunerBox", with "Box" in the accent colour
    m.brand2Lbl.translation = [m.X0 + m.brandLbl.boundingRect().width, 20]
    m.NAV_X = m.X0 + m.brandLbl.boundingRect().width + m.brand2Lbl.boundingRect().width + 40
    m.msgLbl.font.size = 32
    m.HINTS = [["OK", "Watch / Open"], ["ARROWS", "Move"], ["*", "Favorite"], ["REW/FF", "Start / end of row"], ["BACK", "Live TV"]]
    buildKeyHints(m.hintsGroup, m.HINTS, 36, m.W)

    m.rows = []
    m.r = 0
    m.cols = {}
    m.left = {}
    m.top0 = 0
    m.state = "loading"
    m.seq = 0
    m.tasks = []
    m.bad = {}
    buildNodes()
end sub

' fit inside the overscan insets: narrower rows, the bottom (key hints, last row) moved up
sub onSafe()
    sf = m.top.safe
    if sf = invalid or sf.Count() < 4 then return
    m.W = 1840 - sf[0] - sf[2]
    m.YMAX = 1016 - sf[1] - sf[3]
    m.rowsGroup.clippingRect = [-200, -200, 2320, m.YMAX + 200 - 4]
    m.hintsGroup.translation = [m.X0, m.YMAX + 12]
    buildKeyHints(m.hintsGroup, m.HINTS, 36, m.W)
    if m.top.visible then
        drawClock()
        render()
    end if
end sub

' colours kept for drawing; again on each open, in case the theme changed
sub homeColors()
    m.YELLOW = thm("0xFFC845FF")
    m.DIM = thm("0x9FB3DCFF")
    ' tile colours by name (as the web: a title keeps its colour)
    m.TONES = [thm("0x163A7DFF"), thm("0x3F2A7EFF"), thm("0x145A3AFF"), thm("0x6A3A12FF"), thm("0x0D6C74FF"), thm("0x5A1F4AFF"), thm("0x1F4FA3FF"), thm("0x4A3A10FF")]
end sub

' ============================================================ nodes (created once, then only updated)
sub buildNodes()
    m.chips = []
    for i = 0 to m.NAV.Count() - 1
        c = {}
        c.bg = mkPill(0, 0, 10, 52, thm("0xFFC845FF"))
        c.lbl = mkLabel(0, 0, 0, 52, "", 28, true, thm("0x9FB3DCFF"))
        for each k in ["bg", "lbl"]
            c[k].visible = false
            m.rowsGroup.appendChild(c[k])
        end for
        m.chips.Push(c)
    end for

    m.slots = []
    for s = 0 to m.NSLOTS - 1
        slot = {}
        slot.label = mkLabel(0, 0, 1800, m.LABEL_H, "", 28, true, m.DIM)
        slot.label.visible = false
        m.rowsGroup.appendChild(slot.label)
        slot.tiles = []
        for k = 0 to m.NTILES - 1
            n = {}
            n.ring = mkRect(0, 0, 10, 10, m.YELLOW)
            n.bg = mkRect(0, 0, 10, 10, m.TONES[0])
            n.logo = mkPoster("scaleToFit")
            n.big = mkLabel(0, 0, 10, 70, "", 54, true, thm("0xFFFFFFCC"))
            n.big.horizAlign = "center"
            n.pic = mkPoster("scaleToZoom")     ' fill the tile, keep the shape, trim the edges (as the web's object-fit: cover)
            n.grad = mkRect(0, 0, 10, 72, thm("0x000000B8"))
            n.title = mkLabel(0, 0, 10, 30, "", 24, true, thm("0xFFFFFFFF"))
            n.title.ellipsizeOnBoundary = true
            n.subt = mkLabel(0, 0, 10, 26, "", 19, false, thm("0xD7E3FFFF"))
            n.badgeBg = mkRect(0, 0, 10, 30, thm("0x000000B8"))
            n.badge = mkLabel(0, 0, 10, 30, "", 19, true, m.YELLOW)
            n.badge.horizAlign = "center"
            n.barBg = mkRect(0, 0, 10, 7, thm("0x000000AA"))
            n.bar = mkRect(0, 0, 0, 7, m.YELLOW)
            n.logo.observeField("loadStatus", "onImgStatus")
            n.pic.observeField("loadStatus", "onImgStatus")
            for each f in tileFields()
                n[f].visible = false
                m.rowsGroup.appendChild(n[f])
            end for
            slot.tiles.Push(n)
        end for
        m.slots.Push(slot)
    end for
end sub

function tileFields() as Object
    return ["ring", "bg", "logo", "big", "pic", "grad", "title", "subt", "badgeBg", "badge", "barBg", "bar"]
end function

function mkPoster(mode as String) as Object
    p = CreateObject("roSGNode", "Poster")
    p.loadDisplayMode = mode
    return p
end function

' a picture or logo that won't load: show the tile without it from now on
sub onImgStatus(event as Object)
    p = event.getRoSGNode()
    if p.loadStatus <> "failed" or p.uri = "" then return
    print "[home] picture didn't load: "; p.uri
    m.bad[p.uri] = true
    if m.top.visible then drawRows()
end sub

' ============================================================ open / close / load (called by the scene)
sub openHome()
    homeColors()
    m.bad = {}
    m.top.visible = true
    m.top.setFocus(true)
    m.clockTimer.control = "start"
    m.refreshTimer.control = "start"
    drawClock()
    if m.rows.Count() = 0 then m.rows = buildRows(invalid)
    if m.state <> "ok" then m.state = "loading"
    m.cols = {}
    m.left = {}
    m.r = minI(1, m.rows.Count() - 1)
    m.top0 = 0
    render()
    load(true)
end sub

sub closeHome()
    m.seq = m.seq + 1
    m.refreshTimer.control = "stop"
    m.clockTimer.control = "stop"
    m.top.visible = false
    m.top.setFocus(false)
end sub

sub reload()
    if m.top.visible then load(false)
end sub

sub onRefreshTimer()
    ' pictures that failed get another try (TunerBox makes each one the first time it's asked, which can be slow)
    m.bad = {}
    if m.top.visible then load(false)
end sub

sub load(first as Boolean)
    m.seq = m.seq + 1
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.top.baseUrl
    t.apiPath = "/api/home?recent=" + m.top.recent
    t.apiTag = "home"
    t.apiCtx = { seq: m.seq, first: first }
    t.observeField("result", "onLoaded")
    m.tasks.Push(t)
    if m.tasks.Count() > 4 then m.tasks.Shift()
    t.control = "RUN"
end sub

' redraw with the new lists, staying on the same tile (or, the first time, on the first row with something in it)
sub onLoaded(event as Object)
    r = event.getData()
    if r = invalid or r.ctx = invalid or r.ctx.seq <> m.seq or not m.top.visible then return
    if not r.ok or not isAA(r.data) then
        if m.state = "ok" then return      ' keep what's shown
        m.state = "error"
        render()
        return
    end if
    m.state = "ok"
    old = invalid
    key = ""
    if m.r < m.rows.Count() then
        old = m.rows[m.r]
        key = itemKey(curItem())
    end if
    m.rows = buildRows(r.data)
    if r.ctx.first = true or old = invalid then
        m.r = minI(1, m.rows.Count() - 1)
        m.top0 = 0
    else
        m.r = minI(m.r, m.rows.Count() - 1)
        for i = 0 to m.rows.Count() - 1
            if m.rows[i].id = old.id then m.r = i
        end for
        row = m.rows[m.r]
        for i = 0 to row.items.Count() - 1
            if itemKey(row.items[i]) = key then m.cols[row.id] = i
        end for
    end if
    render()
end sub

' ============================================================ rows
function buildRows(d as Dynamic) as Object
    rows = [{ id: "nav", label: "", poster: false, items: m.NAV }]
    if not isAA(d) then return rows
    addRow(rows, "fav", "Favorites on now", false, tagged(d.favorites, "chan", ""))
    teams = []
    for each p in listOf(d.teams)
        teams.Push({ t: "game", p: p })
    end for
    addRow(rows, "teams", "Your teams on now", false, teams)
    ' posters and wide recording tiles in separate rows, so each row has one shape
    addRow(rows, "cont", "Continue Watching: On Demand", true, tagged(d["continue"], "vod", "vod"))
    addRow(rows, "contrec", "Continue Watching: Recordings", false, tagged(d["continue"], "rec", "rec"))
    games = []
    for each p in listOf(d.sports)
        games.Push({ t: "game", p: p })
    end for
    addRow(rows, "sports", "Sports on now", false, games)
    addRow(rows, "recent", "Recent channels", false, tagged(d.recent, "chan", ""))
    addRow(rows, "recorded", "Recently recorded", false, tagged(d.recorded, "rec", ""))
    coming = []
    for each x in listOf(d.coming)
        it = {}
        it.Append(x)
        if anyStr(x.type) = "rec" then it.t = "sched" else it.t = "remind"
        coming.Push(it)
    end for
    addRow(rows, "coming", "Coming up", false, coming)
    return rows
end function

sub addRow(rows as Object, id as String, label as String, poster as Boolean, items as Object)
    if items.Count() > 0 then rows.Push({ id: id, label: label, poster: poster, items: items })
end sub

' copies of the list's objects marked with tile type t; onlyType keeps just those whose "type" matches
function tagged(list as Dynamic, t as String, onlyType as String) as Object
    out = []
    for each x in listOf(list)
        if onlyType = "" or anyStr(x.type) = onlyType then
            it = {}
            it.Append(x)
            it.t = t
            out.Push(it)
        end if
    end for
    return out
end function

function listOf(v as Dynamic) as Object
    out = []
    if Type(v) <> "roArray" then return out
    for each x in v
        if isAA(x) then out.Push(x)
    end for
    return out
end function

function isAA(v as Dynamic) as Boolean
    return Type(v) = "roAssociativeArray"
end function

function itemKey(it as Dynamic) as String
    if not isAA(it) then return ""
    t = it.t
    if t = "nav" then return "n" + it.id
    if t = "chan" then return "c" + anyStr(it.number)
    if t = "vod" then return "v" + anyStr(it.id)
    if t = "rec" or t = "sched" then return "r" + anyStr(it.id)
    if t = "remind" then return "m" + anyStr(it.id)
    if t = "game" and isAA(it.p) then return "g" + anyStr(it.p.title) + anyStr(it.p.start)
    return ""
end function

function curItem() as Dynamic
    if m.r < 0 or m.r >= m.rows.Count() then return invalid
    row = m.rows[m.r]
    i = colOf(row)
    if i < 0 or i >= row.items.Count() then return invalid
    return row.items[i]
end function

function colOf(row as Object) as Integer
    i = m.cols[row.id]
    if i = invalid then i = 0
    if i > row.items.Count() - 1 then i = row.items.Count() - 1
    if i < 0 then i = 0
    return i
end function

function minI(a as Integer, b as Integer) as Integer
    if a < b then return a
    return b
end function

function rowHeight(i as Integer) as Integer
    if m.rows[i].id = "nav" then return 0
    return m.ROW_H
end function

' the rows that fit on screen starting at top0: [{ i, y }]
function placeRows(top0 as Integer) as Object
    out = []
    y = m.Y0
    for i = top0 to m.rows.Count() - 1
        if m.rows[i].id = "nav" then continue for     ' in the top bar
        h = rowHeight(i)
        if y + h > m.YMAX + 2 then
            ' not enough room: show its label and the top of its tiles if that much fits
            if y + m.LABEL_H + 60 <= m.YMAX then out.Push({ i: i, y: y, part: true })
            exit for
        end if
        out.Push({ i: i, y: y, part: false })
        y = y + h
    end for
    return out
end function

' ============================================================ drawing
sub render()
    drawRows()
    drawInfo()
    if m.rows.Count() >= 3 then
        m.msgLbl.text = ""
    else if m.state = "loading" then
        m.msgLbl.text = "Loading..."
    else if m.state = "error" then
        m.msgLbl.text = "Couldn't load Home. Check that TunerBox is running."
    else
        m.msgLbl.text = "Nothing here yet. Press * on a channel to add it to Favorites. What you watch, record and set reminders for shows up here too."
    end if
end sub

' the time (bold) and the date, right-aligned in the top bar
sub drawClock()
    t = nowEpoch()
    m.clockLbl.text = fmtClock(t)
    m.dateLbl.text = fmtDay(t)
    dw = m.dateLbl.boundingRect().width
    cw = m.clockLbl.boundingRect().width
    r = m.X0 + m.W
    m.dateLbl.translation = [r - dw, 22]
    m.clockLbl.translation = [r - dw - 14 - cw, 22]
end sub

sub drawRows()
    n = m.rows.Count()
    if n = 0 then return
    if m.r > n - 1 then m.r = n - 1
    if m.r < 0 then m.r = 0
    ' keep the shortcuts in view near the top
    if m.r <= 1 then m.top0 = 0
    if m.r < m.top0 then m.top0 = m.r
    placed = placeRows(m.top0)
    while not hasRow(placed, m.r) and m.top0 < m.r
        m.top0 = m.top0 + 1
        placed = placeRows(m.top0)
    end while

    ' the shortcuts are always in the top bar
    if m.rows[0].id = "nav" then drawNav(m.rows[0], m.NAV_Y, m.r = 0)
    slot = 0
    for each pr in placed
        row = m.rows[pr.i]
        if slot < m.NSLOTS then
            drawSlot(m.slots[slot], row, pr.y, pr.i = m.r)
            slot = slot + 1
        end if
    end for
    for s = slot to m.NSLOTS - 1
        m.slots[s].label.visible = false
        for each tile in m.slots[s].tiles
            hideTile(tile)
        end for
    end for
end sub

' is row i fully on screen? (a row that only peeks out doesn't count: moving onto it scrolls)
function hasRow(placed as Object, i as Integer) as Boolean
    for each pr in placed
        if pr.i = i and not pr.part then return true
    end for
    return false
end function

sub drawNav(row as Object, y as Integer, cur as Boolean)
    ' as the web top bar: plain dimmed words; the highlighted one in an accent pill
    sel = colOf(row)
    x = m.NAV_X
    for i = 0 to m.chips.Count() - 1
        c = m.chips[i]
        vis = (i < row.items.Count())
        c.lbl.visible = vis
        c.bg.visible = false
        if vis then
            c.lbl.width = 0
            c.lbl.text = row.items[i].label
            w = c.lbl.boundingRect().width
            if w <= 0 then w = Len(row.items[i].label) * 16
            w = w + 40
            c.lbl.translation = [x, y]
            c.lbl.width = w
            c.lbl.horizAlign = "center"
            if cur and i = sel then
                c.bg.translation = [x, y]
                c.bg.width = w
                c.bg.blendColor = m.YELLOW
                c.bg.visible = true
                c.lbl.color = thm("0x10244AFF")
            else
                c.lbl.color = thm("0x9FB3DCFF")
            end if
            x = x + w + 6
        end if
    end for
end sub

sub drawSlot(slot as Object, row as Object, y as Integer, cur as Boolean)
    slot.label.translation = [m.X0 + 6, y]
    slot.label.text = row.label
    if cur then slot.label.color = thm("0xFFFFFFFF") else slot.label.color = m.DIM
    slot.label.visible = true
    w = m.TW
    if row.poster then w = m.PW
    fit = Int((m.W + m.GAP) / (w + m.GAP))
    if fit > m.NTILES then fit = m.NTILES
    sel = colOf(row)
    lf = m.left[row.id]
    if lf = invalid then lf = 0
    if sel < lf then lf = sel
    if sel > lf + fit - 1 then lf = sel - fit + 1
    if lf < 0 then lf = 0
    m.left[row.id] = lf
    ty = y + m.LABEL_H + 4
    for k = 0 to m.NTILES - 1
        tile = slot.tiles[k]
        i = lf + k
        if k < fit and i < row.items.Count() then
            drawTile(tile, row.items[i], m.X0 + k * (w + m.GAP), ty, w, row.poster, cur and i = sel)
        else
            hideTile(tile)
        end if
    end for
end sub

sub hideTile(tile as Object)
    for each f in tileFields()
        tile[f].visible = false
    end for
end sub

sub drawTile(n as Object, it as Object, x as Integer, y as Integer, w as Integer, poster as Boolean, sel as Boolean)
    h = m.TH
    v = tileView(it)
    pic = v.pic
    if m.bad[pic] <> invalid then pic = ""
    logo = v.logo
    if m.bad[logo] <> invalid then logo = ""

    n.ring.visible = sel
    if sel then
        n.ring.translation = [x - 6, y - 6]
        n.ring.width = w + 12
        n.ring.height = h + 12
    end if
    n.bg.translation = [x, y]
    n.bg.width = w
    n.bg.height = h
    n.bg.color = m.TONES[tone(v.tone)]
    n.bg.visible = true

    ' channel logo (or its number) in the upper part of a tile without a picture
    showLogo = (pic = "" and logo <> "" and not poster)
    n.logo.visible = showLogo
    if showLogo then
        lw = Int(w * 0.62)
        lh = Int(h * 0.46)
        n.logo.translation = [x + Int((w - lw) / 2), y + Int(h * 0.36) - Int(lh / 2)]
        n.logo.width = lw
        n.logo.height = lh
        if n.logo.uri <> logo then n.logo.uri = logo
    end if
    showBig = (pic = "" and logo = "" and v.num <> "" and not poster)
    n.big.visible = showBig
    if showBig then
        n.big.translation = [x, y + Int(h * 0.36) - 35]
        n.big.width = w
        n.big.text = v.num
    end if

    n.pic.visible = (pic <> "")
    if pic <> "" then
        ' inset, so the tile's colour shows round it as a thin edge (as the web tiles)
        n.pic.translation = [x + 3, y + 3]
        n.pic.width = w - 6
        n.pic.height = h - 6
        n.pic.loadWidth = w - 6
        n.pic.loadHeight = h - 6
        if n.pic.uri <> pic then n.pic.uri = pic
    end if

    ' name and line under it, over a dark fade when there's a picture; a poster has the name on it
    if poster then
        n.grad.visible = false
        n.subt.visible = false
        n.title.visible = (pic = "")
        if pic = "" then
            n.title.translation = [x + 8, y + 8]
            n.title.width = w - 16
            n.title.height = h - 16
            n.title.wrap = true
            n.title.maxLines = 5
            n.title.vertAlign = "top"
            n.title.font.size = 19
            n.title.text = v.title
        end if
    else
        n.grad.visible = (pic <> "")
        if pic <> "" then
            n.grad.translation = [x, y + h - 72]
            n.grad.width = w
        end if
        n.title.translation = [x + 12, y + h - 62]
        n.title.width = w - 24
        n.title.height = 30
        n.title.wrap = false
        n.title.maxLines = 1
        n.title.vertAlign = "center"
        n.title.font.size = 24
        n.title.text = v.title
        n.title.visible = true
        n.subt.translation = [x + 12, y + h - 33]
        n.subt.width = w - 24
        n.subt.text = v.subt
        n.subt.visible = (v.subt <> "")
    end if

    n.badge.visible = (v.badge <> "")
    n.badgeBg.visible = (v.badge <> "")
    if v.badge <> "" then
        bw = Len(v.badge) * 13 + 20
        n.badgeBg.translation = [x + 8, y + 8]
        n.badgeBg.width = bw
        n.badge.translation = [x + 8, y + 8]
        n.badge.width = bw
        n.badge.text = v.badge
        if v.live then
            n.badgeBg.color = thm("0xE0263AFF")
            n.badge.color = thm("0xFFFFFFFF")
        else if v.dim then
            n.badgeBg.color = thm("0x000000B8")
            n.badge.color = m.DIM
        else
            n.badgeBg.color = thm("0x000000B8")
            n.badge.color = m.YELLOW
        end if
    end if

    showBar = (v.pct > 0)
    n.barBg.visible = showBar
    n.bar.visible = showBar
    if showBar then
        p = v.pct
        if p > 100 then p = 100
        n.barBg.translation = [x, y + h - 7]
        n.barBg.width = w
        n.bar.translation = [x, y + h - 7]
        n.bar.width = Int(w * p / 100)
    end if
end sub

' colour index for a name (same formula as the web, so a title keeps its colour)
function tone(name as String) as Integer
    h = 0
    for i = 1 to Len(name)
        h = (h * 31 + Asc(Mid(name, i, 1))) mod 8
    end for
    return h
end function

function pctOf(startAt as Float, stopAt as Float) as Float
    span = stopAt - startAt
    if span <= 0 then span = 1
    p = (nowEpoch() - startAt) / span * 100
    if p < 0 then p = 0
    if p > 100 then p = 100
    return p
end function

function joinDot(parts as Object, sep as String) as String
    out = []
    for each p in parts
        if p <> "" then out.Push(p)
    end for
    return out.Join(sep)
end function

function artUri(num as String, startAt as String) as String
    return m.top.baseUrl + "/api/art/" + num + "/" + startAt
end function

function recArt(it as Object) as String
    if truthy(it.art) then return m.top.baseUrl + "/api/recordings/" + anyStr(it.id) + "/art"
    return ""
end function

' "7:30 PM" today, "Sat 7:30 PM" another day
function whenText(t as Float) as String
    ti = Int(t)
    if fmtDay(ti) = fmtDay(nowEpoch()) then return fmtClock(ti)
    return Left(localDT(ti).GetWeekday(), 3) + " " + fmtClock(ti)
end function

' what a tile shows: { pic, logo, num, badge, live, dim, title, subt, pct, tone }
function tileView(it as Object) as Object
    v = { pic: "", logo: "", num: "", badge: "", live: false, dim: false, title: "", subt: "", pct: 0.0, tone: "" }
    t = it.t
    dot = " " + Chr(183) + " "
    if t = "chan" then
        p = it.now
        num = anyStr(it.number)
        if isAA(p) and anyStr(p.image) <> "" then v.pic = artUri(num, anyStr(p.start))
        v.logo = anyStr(it.logo)
        v.badge = num
        v.num = num
        if isAA(p) then
            v.title = plainText(anyStr(p.title))
            v.subt = joinDot([anyStr(p.episode), anyStr(p.subtitle)], dot)
            if v.subt = "" then v.subt = anyStr(it.label)
            v.pct = pctOf(numv(p.start), numv(p.stop))
        else
            v.title = anyStr(it.name)
            v.subt = "No information"
        end if
        v.tone = anyStr(it.name)
    else if t = "vod" then
        if anyStr(it.poster) <> "" then v.pic = m.top.baseUrl + "/api/vod/poster/" + urlEncode(anyStr(it.id))
        v.title = plainText(anyStr(it.name))
        v.subt = anyStr(it["sub"])
        if v.subt = "" then v.subt = anyStr(it.year)
        v.pct = numv(it.pct)
        v.tone = anyStr(it.name)
    else if t = "rec" then
        v.pic = recArt(it)
        v.title = plainText(anyStr(it.title))
        v.subt = joinDot([anyStr(it.episode), anyStr(it.subtitle)], dot)
        if v.subt = "" then v.subt = fmtDay(Int(numv(it.start)))
        dur = numv(it.duration)
        at = numv(it.position)
        if not truthy(it.watched) and dur > 0 and at > m.RESUME_MIN then v.pct = at / dur * 100
        if truthy(it.watched) then
            v.badge = "WATCHED"
            v.dim = true
        else if at <= m.RESUME_MIN then
            v.badge = "NEW"
        end if
        v.tone = anyStr(it.title)
    else if t = "game" then
        p = it.p
        e = p.event
        score = ""
        if isAA(e) then score = joinDot([anyStr(e.score), anyStr(e.detail)], dot)
        hasCh = isAA(p.ch)
        if hasCh and anyStr(p.image) <> "" then v.pic = artUri(anyStr(p.ch.number), anyStr(p.start))
        v.live = (numv(p.is_live) <> 0)
        if v.live then
            v.badge = "LIVE"
        else if hasCh then
            v.badge = anyStr(p.ch.number)
        else
            v.badge = "FEED"
        end if
        hd = gameHeading(p)
        v.title = plainText(hd[0])
        v.subt = joinDot([plainText(hd[1]), score], dot)
        if v.subt = "" then
            if hasCh then v.subt = chName(p.ch) else v.subt = "Event feed"
        end if
        v.pct = pctOf(numv(p.start), numv(p.stop))
        v.tone = anyStr(p.title)
    else
        ' sched (a recording to come) / remind
        num = anyStr(it.number)
        if t <> "remind" and truthy(it.art) then
            v.pic = recArt(it)
        else
            v.pic = artUri(num, anyStr(it.start))
        end if
        v.live = (anyStr(it.status) = "recording")
        if v.live then
            v.badge = "RECORDING"
        else if t = "sched" then
            v.badge = "REC"
        else
            v.badge = "REMIND"
        end if
        v.title = plainText(anyStr(it.title))
        v.subt = whenText(numv(it.start)) + dot + num + " " + anyStr(it.channel_name)
        v.tone = anyStr(it.title)
    end if
    return v
end function

' [title, line under it] for a game, as the web's Sports list
function gameHeading(p as Object) as Object
    t = anyStr(p.heading)
    if t = "" then t = anyStr(p.title)
    s = anyStr(p.matchup)
    if s = "" then s = anyStr(p.subtitle)
    return [t, s]
end function

function chName(ch as Object) as String
    s = anyStr(ch.label)
    if s = "" then s = anyStr(ch.name)
    return s
end function

' the details above the rows for the highlighted tile
sub drawInfo()
    it = curItem()
    title = ""
    sb = ""
    meta = ""
    desc = ""
    sep = "  " + Chr(183) + "  "
    if it = invalid then
        title = "Home"
    else if it.t = "nav" then
        title = it.label
        sb = it.info
    else if it.t = "chan" then
        p = it.now
        if isAA(p) then
            title = anyStr(p.title)
            sb = joinDot([anyStr(p.episode), anyStr(p.subtitle)], sep)
            meta = joinDot([anyStr(it.number) + " " + chName(it), fmtClock(Int(numv(p.start))) + dashSep() + fmtClock(Int(numv(p.stop))), anyStr(p.category)], sep)
            desc = anyStr(p.descr)
        else
            title = anyStr(it.name)
            sb = "No information available"
            meta = anyStr(it.number) + " " + chName(it)
        end if
    else if it.t = "vod" then
        title = anyStr(it.name)
        sb = anyStr(it["sub"])
        kind = "Movie"
        if anyStr(it.kind) = "series" then kind = "TV Show"
        watched = ""
        if numv(it.pct) > 0 then watched = Int(numv(it.pct)).ToStr() + "% watched"
        meta = joinDot([kind, anyStr(it.year), watched], sep)
    else if it.t = "rec" then
        title = anyStr(it.title)
        sb = joinDot([anyStr(it.episode), anyStr(it.subtitle)], sep)
        st = ""
        if truthy(it.watched) then
            st = "Watched"
        else if numv(it.position) > m.RESUME_MIN then
            st = "Stopped at " + fmtDur(numv(it.position))
        end if
        startAt = Int(numv(it.start))
        meta = joinDot(["Recorded " + fmtDay(startAt) + " " + fmtClock(startAt), anyStr(it.number) + " " + anyStr(it.channel_name), st], sep)
        desc = anyStr(it.descr)
    else if it.t = "game" then
        p = it.p
        e = p.event
        hd = gameHeading(p)
        title = hd[0]
        sc = ""
        dt = ""
        if isAA(e) then
            sc = anyStr(e.score)
            dt = anyStr(e.detail)
        end if
        sb = joinDot([hd[1], sc, dt], sep)
        where = "Event feed"
        if isAA(p.ch) then where = anyStr(p.ch.number) + " " + chName(p.ch)
        meta = where + sep + "until " + fmtClock(Int(numv(p.stop)))
        desc = anyStr(p.descr)
    else
        title = anyStr(it.title)
        sb = anyStr(it.subtitle)
        startAt = Int(numv(it.start))
        st = "Will be recorded"
        if it.t = "remind" then
            st = "Reminder set"
        else if anyStr(it.status) = "recording" then
            st = "Recording now"
        end if
        meta = joinDot([fmtDay(startAt) + " " + fmtClock(startAt), anyStr(it.number) + " " + anyStr(it.channel_name), st], sep)
        desc = anyStr(it.descr)
    end if
    m.titleLbl.text = plainText(title)
    m.subLbl.text = plainText(sb)
    m.metaLbl.text = plainText(meta)
    m.descLbl.text = plainText(desc)
    placeInfo()
end sub

' stack the details (title up to two lines, then the lines that have text), centred between the top bar and
' the rows, as the web Home
sub placeInfo()
    parts = [m.titleLbl, m.subLbl, m.metaLbl, m.descLbl]
    gaps = [0, 6, 4, 10]
    hs = []
    total = 0
    for i = 0 to parts.Count() - 1
        h = 0
        if parts[i].text <> "" then
            if i = 0 or i = 3 then
                h = Int(parts[i].boundingRect().height)
            else
                h = Int(parts[i].height)
            end if
            if total > 0 then h = h + gaps[i]
        end if
        hs.Push(h)
        total = total + h
    end for
    y = 88 + Int((m.Y0 - 100 - total) / 2)
    if y < 84 then y = 84
    started = false
    for i = 0 to parts.Count() - 1
        if hs[i] > 0 then
            g = 0
            if started then g = gaps[i]
            parts[i].translation = [m.X0, y + g]
            y = y + hs[i]
            started = true
        end if
    end for
end sub

' ============================================================ keys
sub moveTo(r as Integer, c as Integer)
    m.r = r
    row = m.rows[r]
    if c >= 0 then m.cols[row.id] = c
    drawRows()
    drawInfo()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.top.visible then return false
    n = m.rows.Count()
    if n = 0 then
        if key = "back" then m.top.request = { type: "close" }
        return true
    end if
    row = m.rows[m.r]
    i = colOf(row)
    if key = "up" then
        if m.r > 0 then moveTo(m.r - 1, -1)
    else if key = "down" then
        if m.r < n - 1 then moveTo(m.r + 1, -1)
    else if key = "left" then
        if i > 0 then moveTo(m.r, i - 1)
    else if key = "right" then
        if i < row.items.Count() - 1 then moveTo(m.r, i + 1)
    else if key = "rewind" then
        moveTo(m.r, 0)
    else if key = "fastforward" then
        moveTo(m.r, row.items.Count() - 1)
    else if key = "OK" then
        it = curItem()
        if it <> invalid then m.top.request = { type: "pick", item: it }
    else if key = "options" then
        it = curItem()
        if it <> invalid and it.t = "chan" then m.top.request = { type: "fav", num: anyStr(it.number) }
    else if key = "back" then
        m.top.request = { type: "close" }
    else if Left(key, 4) = "Lit_" then
        lc = LCase(Mid(key, 5))
        shortcuts = { g: "guide", o: "ondemand", t: "sports", m: "menu", "/": "search" }
        if shortcuts[lc] <> invalid then
            m.top.request = { type: "nav", id: shortcuts[lc] }
        else if lc = "*" or lc = "f" then
            it = curItem()
            if it <> invalid and it.t = "chan" then m.top.request = { type: "fav", num: anyStr(it.number) }
        else
            return false
        end if
    else
        return false
    end if
    return true
end function
