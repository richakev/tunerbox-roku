' On Demand (movies and TV shows from the playlists), mirrors the TunerBox web screen:
' live TV keeps playing in the corner, the highlighted title's details beside it, then tabs
' (Movies / TV Shows / Continue Watching / My List / Search), a category column and a poster grid.
' A TV show opens in the same frame with its seasons on the left and episodes on the right.
' This view talks to TunerBox /api/vod/* itself; the scene shows its dialogs and plays the video.

sub init()
    m.PV = [40, 30, 560, 315]
    m.CAT_X = 40
    m.CAT_Y = 440
    m.CAT_W = 400
    m.CAT_H = 58
    m.NCATS = 10
    m.GX = 470
    m.GY = 440
    m.COLS = 7
    m.ROWS = 2
    m.TW = 186
    m.TH = 279
    m.GAP = 16
    m.EP_H = 58
    m.NEPS = 10
    m.PAGE = 140
    m.RESUME_MIN = 30

    m.top.previewRect = m.PV
    m.titleLbl = m.top.findNode("titleLbl")
    m.metaLbl = m.top.findNode("metaLbl")
    m.srcLbl = m.top.findNode("srcLbl")
    m.plotLbl = m.top.findNode("plotLbl")
    m.castLbl = m.top.findNode("castLbl")
    m.clockLbl = m.top.findNode("clockLbl")
    m.dateLbl = m.top.findNode("dateLbl")
    m.sideHead = m.top.findNode("sideHead")
    m.tabsGroup = m.top.findNode("tabsGroup")
    m.sideGroup = m.top.findNode("sideGroup")
    m.mainGroup = m.top.findNode("mainGroup")
    m.msgLbl = m.top.findNode("msgLbl")
    m.footLbl = m.top.findNode("footLbl")
    m.infoTimer = m.top.findNode("infoTimer")
    m.tabTimer = m.top.findNode("tabTimer")
    m.catTimer = m.top.findNode("catTimer")
    m.clockTimer = m.top.findNode("clockTimer")
    m.infoTimer.observeField("fire", "onInfoTimer")
    m.tabTimer.observeField("fire", "onTabTimer")
    m.catTimer.observeField("fire", "onCatTimer")
    m.clockTimer.observeField("fire", "drawClock")

    m.titleLbl.font.size = 46
    m.metaLbl.font.size = 29
    m.srcLbl.font.size = 25
    m.plotLbl.font.size = 26
    m.castLbl.font.size = 23
    m.clockLbl.font.size = 30
    m.dateLbl.font.size = 25
    m.sideHead.font.size = 27
    m.msgLbl.font.size = 34
    m.footLbl.font.size = 25

    m.TABS = [
        { id: "movie", label: "Movies" },
        { id: "series", label: "TV Shows" },
        { id: "continue", label: "Continue Watching" },
        { id: "list", label: "My List" },
        { id: "search", label: "Search" }
    ]
    m.tab = 0
    m.focusTab = 0
    m.zone = "cats"
    m.counts = invalid
    m.cats = []
    m.cat = 0
    m.catTop = 0
    m.items = []
    m.total = 0
    m.sel = 0
    m.topRow = 0
    m.loading = false
    m.seq = 0
    m.loaded = false
    m.show = invalid
    m.season = 0
    m.ep = 0
    m.epTop = 0
    m.details = {}
    m.nDetails = 0
    m.searchQ = ""
    m.searchItems = []
    m.pending = invalid
    m.tasks = []
    m.message = ""
    buildNodes()
end sub

' ============================================================ nodes (created once, then only updated)
sub buildNodes()
    m.tabNodes = []
    for i = 0 to m.TABS.Count() - 1
        n = {}
        n.bg = mkRect(0, 369, 10, 52, "0xFFC845FF")
        n.lbl = mkLabel(0, 365, 0, 60, "", 28, true, "0xFFFFFFFF")
        n.line = mkRect(0, 419, 10, 6, "0xFFC845FF")
        m.tabsGroup.appendChild(n.bg)
        m.tabsGroup.appendChild(n.lbl)
        m.tabsGroup.appendChild(n.line)
        m.tabNodes.Push(n)
    end for

    m.catNodes = []
    for r = 0 to m.NCATS - 1
        y = m.CAT_Y + r * m.CAT_H
        n = {}
        n.bg = mkRect(m.CAT_X, y, m.CAT_W, m.CAT_H - 4, "0x153A80FF")
        n.name = mkLabel(m.CAT_X + 16, y, m.CAT_W - 120, m.CAT_H - 4, "", 26, true, "0xFFFFFFFF")
        n.cnt = mkLabel(m.CAT_X + m.CAT_W - 110, y, 96, m.CAT_H - 4, "", 23, false, "0xCFE0FFFF")
        n.cnt.horizAlign = "right"
        for each k in ["bg", "name", "cnt"]
            n[k].visible = false
            m.sideGroup.appendChild(n[k])
        end for
        m.catNodes.Push(n)
    end for

    m.tiles = []
    for r = 0 to m.ROWS - 1
        for c = 0 to m.COLS - 1
            x = m.GX + c * (m.TW + m.GAP)
            y = m.GY + r * (m.TH + m.GAP)
            n = {}
            n.ring = mkRect(x - 6, y - 6, m.TW + 12, m.TH + 12, "0xFFC845FF")
            n.bg = mkRect(x, y, m.TW, m.TH, "0x1C3F86FF")
            ' the name sits under the poster: it shows when there is no artwork
            n.name = mkLabel(x + 10, y + 10, m.TW - 20, m.TH - 20, "", 25, true, "0xFFFFFFFF")
            n.name.horizAlign = "center"
            n.name.wrap = true
            n.poster = CreateObject("roSGNode", "Poster")
            n.poster.translation = [x, y]
            n.poster.width = m.TW
            n.poster.height = m.TH
            n.poster.loadWidth = m.TW
            n.poster.loadHeight = m.TH
            n.poster.loadDisplayMode = "scaleToFill"
            n.tagBg = mkRect(x, y, 70, 30, "0xE0243CFF")
            n.tag = mkLabel(x, y, 70, 30, "", 19, true, "0xFFFFFFFF")
            n.tag.horizAlign = "center"
            n.progBg = mkRect(x, y + m.TH - 10, m.TW, 10, "0x00000099")
            n.progFill = mkRect(x, y + m.TH - 10, 0, 10, "0xFFC845FF")
            for each k in ["ring", "bg", "name", "poster", "tagBg", "tag", "progBg", "progFill"]
                n[k].visible = false
                m.mainGroup.appendChild(n[k])
            end for
            m.tiles.Push(n)
        end for
    end for

    ' hidden posters that warm the image cache for the rows below (same size as the tiles, so the copy is reused)
    m.preload = []
    for k = 0 to m.COLS * 2 - 1
        p = CreateObject("roSGNode", "Poster")
        p.translation = [-4000, 0]
        p.width = m.TW
        p.height = m.TH
        p.loadWidth = m.TW
        p.loadHeight = m.TH
        p.loadDisplayMode = "scaleToFill"
        m.mainGroup.appendChild(p)
        m.preload.Push(p)
    end for

    m.epNodes = []
    for r = 0 to m.NEPS - 1
        y = m.GY + r * m.EP_H
        n = {}
        n.bg = mkRect(m.GX, y, 1410, m.EP_H - 4, "0x153A80FF")
        n.num = mkLabel(m.GX + 16, y, 100, m.EP_H - 4, "", 26, true, "0xFFC845FF")
        n.name = mkLabel(m.GX + 120, y, 960, m.EP_H - 4, "", 27, true, "0xFFFFFFFF")
        n.right = mkLabel(m.GX + 1090, y, 300, m.EP_H - 4, "", 23, false, "0xCFE0FFFF")
        n.right.horizAlign = "right"
        n.prog = mkRect(m.GX, y + m.EP_H - 10, 0, 6, "0xFFC845FF")
        for each k in ["bg", "num", "name", "right", "prog"]
            n[k].visible = false
            m.mainGroup.appendChild(n[k])
        end for
        m.epNodes.Push(n)
    end for
end sub

function isTrue(v as Dynamic) as Boolean
    t = Type(v)
    if t = "Boolean" or t = "roBoolean" then return v
    return false
end function

function arr(v as Dynamic) as Object
    if Type(v) = "roArray" then return v
    return []
end function

function joinParts(parts as Object) as String
    out = []
    for each p in parts
        if p <> "" then out.Push(p)
    end for
    return out.Join(" " + Chr(183) + " ")
end function

function plural(n as Integer, word as String) as String
    if n = 1 then return "1 " + word
    return n.ToStr() + " " + word + "s"
end function

function ratingStr(r as Dynamic) as String
    s = anyStr(r)
    if s = "" then return ""
    v = Val(s)
    if v > 0 then
        txt = Str(Int(v * 10 + 0.5) / 10.0).Trim()
        if Instr(1, txt, ".") = 0 then txt = txt + ".0"
        return txt + "/10"
    end if
    if s = "0" then return ""
    return s
end function

function kindName(k as String) as String
    if k = "series" then return "TV Shows"
    return "Movies"
end function

' ============================================================ networking (LoadTask mode "api")
sub api(tag as String, path as String, body as Dynamic, ctx as Object)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.top.baseUrl
    t.apiPath = path
    if body <> invalid then t.apiBody = FormatJson(body)
    t.apiTag = tag
    t.apiCtx = ctx
    t.observeField("result", "onApi")
    m.tasks.Push(t)
    if m.tasks.Count() > 16 then m.tasks.Shift()
    t.control = "RUN"
end sub

sub onApi(event as Object)
    r = event.getData()
    if r = invalid then return
    tag = r.tag
    ctx = r.ctx
    if ctx = invalid then ctx = {}
    if tag = "detail" then
        if r.ok then gotDetail(r.data)
        return
    end if
    if not m.top.visible then return
    if tag = "counts" then
        gotCounts(r)
    else if tag = "cats" then
        if ctx.seq <> m.seq then return
        gotCats(r)
    else if tag = "items" then
        if ctx.seq <> m.seq then return
        gotItems(r, ctx)
    else if tag = "search" then
        if anyStr(ctx.q) <> m.searchQ then return
        m.loading = false
        if r.ok then m.searchItems = arr(r.data) else m.searchItems = []
        if m.tab = 4 then
            m.items = m.searchItems
            m.total = m.items.Count()
            m.sel = 0
            m.topRow = 0
            if m.items.Count() > 0 then m.zone = "grid"
            render()
        end if
    else if tag = "pick" then
        if not r.ok then
            toast("That title is no longer in the playlist")
            return
        end if
        gotDetail(r.data)
        if anyStr(r.data.kind) = "series" then
            openShow(r.data, false)
        else
            movieDialog(r.data)
        end if
    else if tag = "show" then
        if not r.ok then
            toast("That title is no longer in the playlist")
            if isTrue(ctx.keep) then closeShow()
            return
        end if
        gotDetail(r.data)
        openShow(r.data, isTrue(ctx.keep))
    else if tag = "list" or tag = "watched" then
        if not r.ok then
            toast("Could not reach TunerBox")
            return
        end if
        toast(ctx.msg)
        refresh()
    end if
end sub

sub toast(text as String)
    m.top.request = { type: "toast", text: text }
end sub

' ============================================================ open / close (called by the scene)
' args: {} = where you left it, { kind: "movie" | "series" }, { showId }, { movieId }, { episode: { id, name, sub, title_id } }
sub openOD(args as Object)
    if args = invalid then args = {}
    m.top.visible = true
    m.top.setFocus(true)
    m.clockTimer.control = "start"
    drawClock()
    m.args = args
    m.message = "Loading On Demand..."
    m.seq = m.seq + 1
    api("counts", "/api/vod", invalid, {})
    render()
end sub

' back from watching something: fresh progress / watched marks, same place
sub reopenOD()
    m.top.visible = true
    m.top.setFocus(true)
    m.clockTimer.control = "start"
    drawClock()
    refresh()
end sub

sub closeOD()
    m.seq = m.seq + 1
    m.infoTimer.control = "stop"
    m.tabTimer.control = "stop"
    m.catTimer.control = "stop"
    m.clockTimer.control = "stop"
    m.top.visible = false
    m.top.setFocus(false)
end sub

sub refresh()
    m.details = {}
    m.nDetails = 0
    if m.show <> invalid then
        api("show", "/api/vod/title/" + urlEncode(m.show.id), invalid, { keep: true })
    else if m.tab = 4 then
        render()
    else if hasCats() and m.cats.Count() = 0 then
        loadTab(false)
    else
        loadItems(true, false)
    end if
end sub

sub gotCounts(r as Object)
    args = m.args
    m.args = {}
    if args = invalid then args = {}
    if not r.ok then
        m.message = "Could not reach TunerBox. Press Back."
        render()
        return
    end if
    c = r.data
    m.counts = invalid
    mv = c.movie
    se = c.series
    if mv = invalid or se = invalid then
        m.message = "This TunerBox version has no On Demand. Press Back."
        render()
        return
    end if
    if numv(mv.total) = 0 and numv(se.total) = 0 and numv(mv.list) = 0 and numv(se.list) = 0 then
        if isTrue(c.enabled) then
            m.message = "On Demand is still being read from your playlist." + Chr(10) + "Try again when the scan is done."
        else
            m.message = "On Demand is off." + Chr(10) + "Turn it on in TunerBox Setup > Playlists."
        end if
        render()
        return
    end if
    m.message = ""
    m.counts = c
    want = -1
    if anyStr(args.kind) = "movie" then want = 0
    if anyStr(args.kind) = "series" then want = 1
    if args.showId <> invalid then
        m.loaded = true
        m.tab = 1
        m.focusTab = 1
        m.cats = []
        m.items = []
        api("show", "/api/vod/title/" + urlEncode(args.showId), invalid, {})
        render()
        return
    end if
    if args.movieId <> invalid then
        api("pick", "/api/vod/title/" + urlEncode(args.movieId), invalid, {})
    end if
    if args.episode <> invalid then episodeQuick(args.episode)
    if not m.loaded or (want >= 0 and want <> m.tab) then
        m.loaded = true
        m.show = invalid
        m.zone = "cats"
        if want >= 0 then
            m.tab = want
        else if numv(mv.total) = 0 and numv(se.total) > 0 then
            m.tab = 1
        else
            m.tab = 0
        end if
        m.focusTab = m.tab
        loadTab(false)
    else if m.show <> invalid then
        api("show", "/api/vod/title/" + urlEncode(m.show.id), invalid, { keep: true })
    else if m.tab = 4 then
        render()
    else
        render()
        loadItems(true, false)
    end if
end sub

' ============================================================ loading lists
function hasCats() as Boolean
    return m.tab < 2
end function

function tabKind() as String
    return m.TABS[m.tab].id
end function

sub loadTab(keep as Boolean)
    m.seq = m.seq + 1
    if not keep then
        m.cat = 0
        m.catTop = 0
        m.sel = 0
        m.topRow = 0
        m.cats = []
        m.items = []
        m.total = 0
    end if
    if m.tab = 4 then
        m.items = m.searchItems
        m.total = m.items.Count()
        m.loading = false
        if m.zone = "cats" then m.zone = "tabs"
        render()
        return
    end if
    m.loading = true
    if hasCats() then
        api("cats", "/api/vod/categories?kind=" + tabKind(), invalid, { seq: m.seq })
        render()
    else
        if m.zone = "cats" then m.zone = "grid"
        render()
        loadItems(keep, false)
    end if
end sub

sub gotCats(r as Object)
    if not r.ok then
        m.loading = false
        m.message = "Could not load the categories"
        render()
        return
    end if
    d = r.data
    cats = [{ all: true, key: "", name: "All " + kindName(tabKind()), count: numv(d.total) }]
    if numv(d.recent) > 0 then cats.Push({ all: false, key: "*recent", name: "Recently Added", count: numv(d.recent) })
    for each c in arr(d.cats)
        nm = anyStr(c.name)
        label = nm
        if label = "" then label = "Other"
        cats.Push({ all: false, key: nm, name: label, count: numv(c["count"]) })
    end for
    m.cats = cats
    if m.cat > cats.Count() - 1 then m.cat = cats.Count() - 1
    if m.pendingCat <> invalid then
        for i = 0 to cats.Count() - 1
            if not cats[i].all and cats[i].key = m.pendingCat then
                m.cat = i
                m.zone = "grid"
                exit for
            end if
        end for
        m.pendingCat = invalid
    end if
    loadItems(false, false)
end sub

sub loadItems(keep as Boolean, append as Boolean)
    if m.tab = 4 then return
    if not append then m.seq = m.seq + 1
    if hasCats() then
        path = "/api/vod/titles?kind=" + tabKind()
        if m.cats.Count() > 0 and m.cat < m.cats.Count() and not m.cats[m.cat].all then path = path + "&cat=" + urlEncode(m.cats[m.cat].key)
    else
        path = "/api/vod/titles?tab=" + tabKind()
    end if
    off = 0
    if append then off = m.items.Count()
    limit = m.PAGE
    if keep and m.items.Count() > limit then limit = m.items.Count()
    if limit > 500 then limit = 500
    path = path + "&offset=" + off.ToStr() + "&limit=" + limit.ToStr()
    m.loading = true
    api("items", path, invalid, { seq: m.seq, append: append, keep: keep })
    if not append then render()
end sub

sub gotItems(r as Object, ctx as Object)
    m.loading = false
    if not r.ok then
        if not isTrue(ctx.append) then
            m.items = []
            m.total = 0
            m.message = "Could not load this list"
        end if
        render()
        return
    end if
    m.message = ""
    d = r.data
    if isTrue(ctx.append) then
        m.items.Append(arr(d.items))
    else
        m.items = arr(d.items)
    end if
    m.total = Int(numv(d.total))
    if isTrue(ctx.keep) or isTrue(ctx.append) then
        if m.sel > m.items.Count() - 1 then m.sel = m.items.Count() - 1
        if m.sel < 0 then m.sel = 0
    else
        m.sel = 0
        m.topRow = 0
    end if
    if m.items.Count() = 0 and m.zone = "grid" then
        if hasCats() then m.zone = "cats" else m.zone = "tabs"
    end if
    if m.show = invalid then render()
end sub

sub maybeMore()
    if m.tab = 4 or m.loading then return
    if m.items.Count() < m.total and m.sel >= m.items.Count() - m.COLS * 2 then loadItems(false, true)
end sub

' ============================================================ details (plot, cast, length)
sub gotDetail(d as Object)
    if d = invalid or d.id = invalid then return
    if m.nDetails > 300 then
        m.details = {}
        m.nDetails = 0
    end if
    m.details[d.id] = d
    m.nDetails = m.nDetails + 1
    if m.top.visible and m.show = invalid then
        t = curItem()
        if t <> invalid and t.id = d.id then drawInfo()
    end if
end sub

sub onInfoTimer()
    t = curItem()
    if t = invalid or m.show <> invalid then return
    if t.kind = "episode" then return
    if m.details[t.id] <> invalid then return
    api("detail", "/api/vod/title/" + urlEncode(t.id), invalid, {})
end sub

function curItem() as Dynamic
    if m.zone <> "grid" and m.zone <> "cats" then
        if m.zone = "tabs" and m.focusTab <> m.tab then return invalid
    end if
    if m.sel < 0 or m.sel >= m.items.Count() then return invalid
    return m.items[m.sel]
end function

' ============================================================ shows (seasons and episodes)
function curEps() as Object
    out = []
    if m.show = invalid then return out
    seasons = arr(m.show.seasons)
    if m.season >= seasons.Count() then return out
    sn = numv(seasons[m.season].season)
    for each e in arr(m.show.episodes)
        if numv(e.season) = sn then out.Push(e)
    end for
    return out
end function

sub openShow(d as Object, keep as Boolean)
    eps = arr(d.episodes)
    if eps.Count() = 0 then
        toast("No episodes are listed for this show")
        if keep then closeShow()
        return
    end if
    m.show = d
    seasons = arr(d.seasons)
    if keep then
        if m.season > seasons.Count() - 1 then m.season = seasons.Count() - 1
        n = curEps().Count()
        if m.ep > n - 1 then m.ep = n - 1
        if m.ep < 0 then m.ep = 0
    else
        ' start on the episode that's next for you
        e = eps[0]
        nx = anyStr(d["next"])
        for each x in eps
            if x.id = nx then
                e = x
                exit for
            end if
        end for
        m.season = 0
        for i = 0 to seasons.Count() - 1
            if numv(seasons[i].season) = numv(e.season) then m.season = i
        end for
        m.ep = 0
        list = curEps()
        for i = 0 to list.Count() - 1
            if list[i].id = e.id then m.ep = i
        end for
        m.epTop = 0
        m.zone = "eps"
    end if
    render()
end sub

sub closeShow()
    m.show = invalid
    if m.items.Count() > 0 then
        m.zone = "grid"
    else if hasCats() then
        m.zone = "cats"
    else
        m.zone = "tabs"
    end if
    if m.tab = 4 then
        render()
    else if m.cats.Count() > 0 or not hasCats() then
        loadItems(true, false)
    else
        loadTab(false)
    end if
end sub

' ============================================================ drawing
sub render()
    drawTabs()
    drawSide()
    drawMain()
    drawInfo()
    drawFoot()
end sub

sub drawClock()
    t = nowEpoch()
    m.clockLbl.text = fmtClock(t)
    m.dateLbl.text = fmtDay(t)
end sub

sub drawTabs()
    if m.show <> invalid then
        m.sideHead.text = "Seasons"
    else if hasCats() then
        m.sideHead.text = "Categories"
    else
        m.sideHead.text = "On Demand"
    end if
    x = 470
    for i = 0 to m.TABS.Count() - 1
        n = m.tabNodes[i]
        if m.show <> invalid then
            ' inside a show the strip is a breadcrumb
            n.bg.visible = false
            n.line.visible = false
            n.lbl.visible = (i = 0)
            if i = 0 then
                n.lbl.translation = [x, 365]
                n.lbl.width = 1400
                n.lbl.text = plainText(anyStr(m.show.name)) + "    " + Chr(183) + "    Back: all " + LCase(kindName(anyStr(m.show.kind)))
                n.lbl.color = "0xFFFFFFFF"
            end if
        else
            x = drawTab(n, i, x)
        end if
    end for
end sub

' one tab in the strip at x; returns where the next one starts
function drawTab(n as Object, i as Integer, x as Integer) as Integer
        label = m.TABS[i].label
        cnt = tabCount(i)
        if cnt <> "" then label = label + "  " + cnt
        n.lbl.visible = true
        n.lbl.width = 0
        n.lbl.text = label
        w = n.lbl.boundingRect().width
        if w <= 0 then w = Len(label) * 15
        n.lbl.translation = [x + 18, 365]
        focused = (m.zone = "tabs" and i = m.focusTab)
        n.bg.visible = focused
        n.bg.translation = [x, 369]
        n.bg.width = w + 36
        n.line.visible = (i = m.tab and not focused)
        n.line.translation = [x, 419]
        n.line.width = w + 36
        if focused then n.lbl.color = "0x10244AFF" else n.lbl.color = "0xFFFFFFFF"
        return x + w + 44
end function

function tabCount(i as Integer) as String
    c = m.counts
    if c = invalid or c.movie = invalid or c.series = invalid then return ""
    id = m.TABS[i].id
    if id = "movie" then return fmtCount(numv(c.movie.total))
    if id = "series" then return fmtCount(numv(c.series.total))
    if id = "continue" then return fmtCount(numv(c.movie["continue"]) + numv(c.series["continue"]))
    if id = "list" then return fmtCount(numv(c.movie.list) + numv(c.series.list))
    return ""
end function

' 28245 -> "28,245"
function fmtCount(n as Float) as String
    s = Int(n).ToStr()
    out = ""
    while Len(s) > 3
        out = "," + Right(s, 3) + out
        s = Left(s, Len(s) - 3)
    end while
    return s + out
end function

sub drawSide()
    rows = []
    cur = -1
    active = false
    if m.show <> invalid then
        for each s in arr(m.show.seasons)
            w = numv(s.watched)
            cnt = Int(numv(s["count"])).ToStr()
            if w > 0 then cnt = Int(w).ToStr() + "/" + cnt
            rows.Push({ name: "Season " + anyStr(s.season), cnt: cnt })
        end for
        cur = m.season
        active = (m.zone = "seasons")
    else if hasCats() then
        for each c in m.cats
            rows.Push({ name: c.name, cnt: fmtCount(c["count"]) })
        end for
        cur = m.cat
        active = (m.zone = "cats")
    end if
    if cur < m.catTop then m.catTop = cur
    if cur >= m.catTop + m.NCATS then m.catTop = cur - m.NCATS + 1
    if m.catTop < 0 then m.catTop = 0
    for r = 0 to m.NCATS - 1
        n = m.catNodes[r]
        i = m.catTop + r
        vis = (i < rows.Count())
        n.bg.visible = vis
        n.name.visible = vis
        n.cnt.visible = vis
        if vis then drawSideRow(n, rows[i], (i = cur), active)
    end for
end sub

sub drawSideRow(n as Object, row as Object, isCur as Boolean, active as Boolean)
        n.name.text = plainText(row.name)
        n.cnt.text = row.cnt
        if isCur and active then
            n.bg.color = "0xFFC845FF"
            n.name.color = "0x10244AFF"
            n.cnt.color = "0x10244AFF"
        else if isCur then
            n.bg.color = "0x2F66C8FF"
            n.name.color = "0xFFFFFFFF"
            n.cnt.color = "0xCFE0FFFF"
        else
            n.bg.color = "0x153A80FF"
            n.name.color = "0xFFFFFFFF"
            n.cnt.color = "0xCFE0FFFF"
        end if
end sub

sub drawMain()
    if m.show <> invalid then
        hideTiles()
        drawEps()
        m.msgLbl.text = ""
        return
    end if
    hideEps()
    n = m.items.Count()
    if m.message <> "" then
        m.msgLbl.text = m.message
    else if n = 0 then
        if m.loading then
            m.msgLbl.text = "Loading..."
        else if m.tab = 4 then
            if m.searchQ = "" then
                m.msgLbl.text = "Press OK on Search and type a title, a year or an actor"
            else
                m.msgLbl.text = "Nothing found for " + Chr(34) + m.searchQ + Chr(34)
            end if
        else if tabKind() = "continue" then
            m.msgLbl.text = "Nothing in progress. Movies and episodes you start show up here."
        else if tabKind() = "list" then
            m.msgLbl.text = "My List is empty. Press * on a title to add it."
        else
            m.msgLbl.text = "Nothing here"
        end if
    else
        m.msgLbl.text = ""
    end if

    if m.sel > n - 1 then m.sel = n - 1
    if m.sel < 0 then m.sel = 0
    selRow = m.sel \ m.COLS
    if selRow < m.topRow then m.topRow = selRow
    if selRow > m.topRow + m.ROWS - 1 then m.topRow = selRow - m.ROWS + 1
    for k = 0 to m.tiles.Count() - 1
        i = m.topRow * m.COLS + k
        tile = m.tiles[k]
        if i >= n or m.message <> "" then
            hideTile(tile)
        else
            drawTile(tile, m.items[i], i)
        end if
    end for
    prefetch()
end sub

'' small poster made by TunerBox (GET /api/vod/poster/<id>), not the provider's full-size image
function posterUri(t as Object) as String
    if anyStr(t.poster) = "" or t.kind = "episode" then return ""
    return m.top.baseUrl + "/api/vod/poster/" + urlEncode(anyStr(t.id))
end function

' start loading the next rows' posters (off screen) so they're ready when you scroll down
sub prefetch()
    n = m.items.Count()
    first = (m.topRow + m.ROWS) * m.COLS
    for k = 0 to m.preload.Count() - 1
        i = first + k
        u = ""
        if i < n and m.message = "" and m.show = invalid then u = posterUri(m.items[i])
        if u <> "" and m.preload[k].uri <> u then m.preload[k].uri = u
    end for
end sub

sub hideTile(tile as Object)
    for each f in ["ring", "bg", "name", "poster", "tagBg", "tag", "progBg", "progFill"]
        tile[f].visible = false
    end for
end sub

sub drawTile(tile as Object, t as Object, i as Integer)
        tile.ring.visible = (i = m.sel and m.zone = "grid")
        tile.bg.visible = true
        nm = anyStr(t.name)
        if t.kind = "episode" then nm = nm + Chr(10) + anyStr(t["sub"])
        tile.name.text = plainText(nm)
        tile.name.visible = true
        pu = posterUri(t)
        tile.poster.visible = (pu <> "")
        if tile.poster.uri <> pu then tile.poster.uri = pu
        tag = ""
        tagC = "0xE0243CFF"
        if t.kind = "episode" then
            tag = "EPISODE"
            tagC = "0x3B5B96FF"
        else if isTrue(t.watched) then
            tag = "SEEN"
            tagC = "0x1B6B2FFF"
        else if isTrue(t["new"]) then
            tag = "NEW"
        else if m.tab >= 2 and t.kind = "series" then
            tag = "SHOW"
            tagC = "0x3B5B96FF"
        end if
        tile.tag.visible = (tag <> "")
        tile.tagBg.visible = (tag <> "")
        if tag <> "" then
            tw = Len(tag) * 13 + 20
            tile.tag.text = tag
            tile.tag.width = tw
            tile.tagBg.width = tw
            tile.tagBg.color = tagC
        end if
        pct = numv(t.pct)
        tile.progBg.visible = (pct > 0)
        tile.progFill.visible = (pct > 0)
        if pct > 0 then tile.progFill.width = Int(m.TW * pct / 100)
end sub

sub hideTiles()
    for each tile in m.tiles
        for each f in ["ring", "bg", "name", "poster", "tagBg", "tag", "progBg", "progFill"]
            tile[f].visible = false
        end for
    end for
end sub

sub hideEps()
    for each n in m.epNodes
        for each f in ["bg", "num", "name", "right", "prog"]
            n[f].visible = false
        end for
    end for
end sub

sub drawEps()
    eps = curEps()
    if m.ep < m.epTop then m.epTop = m.ep
    if m.ep >= m.epTop + m.NEPS then m.epTop = m.ep - m.NEPS + 1
    if m.epTop < 0 then m.epTop = 0
    nx = anyStr(m.show["next"])
    for r = 0 to m.NEPS - 1
        n = m.epNodes[r]
        i = m.epTop + r
        vis = (i < eps.Count())
        for each f in ["bg", "num", "name", "right"]
            n[f].visible = vis
        end for
        n.prog.visible = false
        if vis then drawEpRow(n, eps[i], (i = m.ep), nx)
    end for
end sub

sub drawEpRow(n as Object, e as Object, isCur as Boolean, nx as String)
        n.num.text = "E" + anyStr(e.episode)
        nm = anyStr(e.name)
        if nm = "" then nm = "Episode " + anyStr(e.episode)
        n.name.text = plainText(nm)
        dur = numv(e.duration)
        playPos = numv(e.position)
        right = fmtLen(dur)
        if isTrue(e.watched) then
            right = joinParts(["Watched", right])
        else if e.id = nx then
            right = joinParts(["Next up", right])
        end if
        n.right.text = right
        if not isTrue(e.watched) and playPos > m.RESUME_MIN and dur > 0 then
            n.prog.visible = true
            p = playPos / dur
            if p > 1 then p = 1
            n.prog.width = Int(1410 * p)
        end if
        if isCur and m.zone = "eps" then
            n.bg.color = "0xFFC845FF"
            n.name.color = "0x10244AFF"
            n.num.color = "0x10244AFF"
            n.right.color = "0x10244AFF"
        else
            n.bg.color = "0x153A80FF"
            n.name.color = "0xFFFFFFFF"
            n.num.color = "0xFFC845FF"
            n.right.color = "0xCFE0FFFF"
        end if
end sub

sub setInfo(title as String, meta as String, src as String, plot as String, cast as String)
    m.titleLbl.text = plainText(title)
    m.metaLbl.text = plainText(meta)
    m.srcLbl.text = plainText(src)
    m.plotLbl.text = plainText(plot)
    m.castLbl.text = plainText(cast)
end sub

sub drawInfo()
    m.infoTimer.control = "stop"
    s = m.show
    if s <> invalid then
        eps = curEps()
        e = invalid
        if m.ep < eps.Count() then e = eps[m.ep]
        nSeasons = arr(s.seasons).Count()
        line2 = ""
        plot = anyStr(s.plot)
        extra = []
        if e <> invalid then
            line2 = "Season " + anyStr(e.season) + " " + Chr(183) + " Episode " + anyStr(e.episode)
            if anyStr(e.name) <> "" then line2 = line2 + " " + Chr(183) + " " + anyStr(e.name)
            if anyStr(e.plot) <> "" then plot = anyStr(e.plot)
            extra.Push(fmtLen(numv(e.duration)))
            if anyStr(e.aired) <> "" then extra.Push("First aired " + anyStr(e.aired))
            if e.id = anyStr(s["next"]) and not isTrue(e.watched) then extra.Push("Next up for you")
            if isTrue(e.watched) then extra.Push("Watched")
            if not isTrue(e.watched) and numv(e.position) > m.RESUME_MIN then extra.Push("Stopped at " + fmtDur(numv(e.position)))
        end if
        genre = anyStr(s.genre)
        if genre = "" then genre = anyStr(s.category)
        src = joinParts(["TV Show", anyStr(s.year), plural(nSeasons, "season"), genre, srcName(s)])
        setInfo(anyStr(s.name), line2, src, plot, joinParts(extra))
        return
    end if
    if m.zone = "tabs" and m.focusTab = 4 then
        setInfo("Search On Demand", "Press OK and type a title, a year or an actor", "Movies and TV shows", "Accents don't matter, the words can be in any order, and small typos still find it.", "")
        return
    end if
    t = curItem()
    if t = invalid then
        if m.message <> "" then
            setInfo("On Demand", "", "", "", "")
        else
            setInfo(m.TABS[m.tab].label, "", "On Demand", "", "")
        end if
        return
    end if
    if t.kind = "episode" then
        setInfo(anyStr(t.name), anyStr(t["sub"]), "Episode", "", fmtLen(numv(t.duration)))
        return
    end if
    d = m.details[t.id]
    fill(t, d)
    if d = invalid then
        m.infoTimer.control = "start"
    end if
end sub

function srcName(d as Object) as String
    s = anyStr(d.source_name)
    if s = "" then return ""
    return "from " + s
end function

sub fill(t as Object, d as Dynamic)
    x = t
    if d <> invalid then x = d
    movie = (t.kind = "movie")
    seen = ""
    if anyStr(t["sub"]) <> "" then
        seen = "Stopped in " + anyStr(t["sub"])
    else if d <> invalid and movie and isTrue(d.watched) then
        seen = "Watched"
    else if d <> invalid and movie and numv(d.position) > m.RESUME_MIN then
        seen = "Watched " + Int(numv(d.position) / 60 + 0.5).ToStr() + " min"
        if numv(d.duration) > 0 then seen = seen + " of " + Int(numv(d.duration) / 60 + 0.5).ToStr()
    end if
    lenTxt = ""
    if movie then
        lenTxt = fmtLen(numv(x.duration))
    else if d <> invalid and arr(d.seasons).Count() > 0 then
        lenTxt = plural(arr(d.seasons).Count(), "season")
    end if
    genre = ""
    if d <> invalid then genre = anyStr(d.genre)
    if genre = "" then genre = anyStr(x.category)
    kind = "TV Show"
    if movie then kind = "Movie"
    listed = ""
    plot = ""
    cast = ""
    src = ""
    if d <> invalid then
        if isTrue(d.in_list) then listed = "In My List"
        plot = anyStr(d.plot)
        dir = anyStr(d.director)
        if dir <> "" then dir = "Directed by " + dir
        cast = joinParts([anyStr(d.actors), dir])
        src = srcName(d)
    end if
    setInfo(anyStr(x.name), joinParts([anyStr(x.year), lenTxt, ratingStr(x.rating), genre]), joinParts([kind, src, listed, seen]), plot, cast)
end sub

sub drawFoot()
    if m.show <> invalid then
        m.footLbl.text = "OK  Episode options      Play  Play      *  My List      Left  Seasons      Back  All shows"
    else if m.zone = "tabs" then
        if m.focusTab = 4 then
            m.footLbl.text = "OK  Type a search      Left/Right  Tabs      Down  Results      Back  Close"
        else
            m.footLbl.text = "Left/Right  Tabs      Down  Titles      Back  Close"
        end if
    else if m.zone = "cats" then
        m.footLbl.text = "Up/Down  Categories      Right  Titles      Rew/FF  Page      Back  Close"
    else
        m.footLbl.text = "OK  Details      Play  Play / Resume      *  My List      Rew/FF  Page      Back  Close"
    end if
end sub

' ============================================================ picking
sub dialog(title as String, message as Object, buttons as Object, actions as Object, ctx as Object)
    m.pending = ctx
    msg = []
    for each line in message
        msg.Push(plainText(line))
    end for
    btns = []
    for each b in buttons
        btns.Push(plainText(b))
    end for
    m.top.request = { type: "dialog", title: plainText(title), message: msg, buttons: btns, actions: actions }
end sub

sub play(id as String, start as Float)
    m.top.request = { type: "play", id: id, start: start }
end sub

sub movieDialog(d as Object)
    playPos = numv(d.position)
    resume = (not isTrue(d.watched) and playPos > m.RESUME_MIN)
    buttons = []
    actions = []
    if resume then
        buttons.Push("Resume from " + fmtDur(playPos))
        actions.Push("resume")
        buttons.Push("Play from the beginning")
    else
        buttons.Push("Play")
    end if
    actions.Push("play")
    if isTrue(d.in_list) then buttons.Push("Remove from My List") else buttons.Push("Add to My List")
    actions.Push("list")
    if isTrue(d.watched) then buttons.Push("Mark as not watched") else buttons.Push("Mark as watched")
    actions.Push("watched")
    cat = anyStr(d.category)
    here = (m.show = invalid and m.tab = 0 and m.cats.Count() > m.cat and not m.cats[m.cat].all and m.cats[m.cat].key = cat)
    if cat <> "" and not here then
        buttons.Push("More in " + cat)
        actions.Push("more")
    end if
    buttons.Push("Close")
    actions.Push("close")
    genre = anyStr(d.genre)
    if genre = "" then genre = cat
    msg = [joinParts(["Movie", anyStr(d.year), fmtLen(numv(d.duration)), genre])]
    note = "From " + anyStr(d.source_name)
    if resume then
        note = note + " " + Chr(183) + " You stopped at " + fmtDur(playPos)
    else if isTrue(d.watched) then
        note = note + " " + Chr(183) + " Watched"
    end if
    msg.Push(note)
    if anyStr(d.plot) <> "" then msg.Push(anyStr(d.plot))
    dialog(anyStr(d.name), msg, buttons, actions, { kind: "movie", d: d })
end sub

sub episodeDialog(show as Object, e as Object)
    playPos = numv(e.position)
    resume = (not isTrue(e.watched) and playPos > m.RESUME_MIN)
    buttons = []
    actions = []
    if resume then
        buttons.Push("Resume from " + fmtDur(playPos))
        actions.Push("resume")
        buttons.Push("Play from the beginning")
    else
        buttons.Push("Play")
    end if
    actions.Push("play")
    if isTrue(e.watched) then buttons.Push("Mark as not watched") else buttons.Push("Mark as watched")
    actions.Push("watched")
    if isTrue(show.in_list) then buttons.Push("Remove show from My List") else buttons.Push("Add show to My List")
    actions.Push("list")
    buttons.Push("Close")
    actions.Push("close")
    st = ""
    if resume then
        st = "You stopped at " + fmtDur(playPos)
    else if isTrue(e.watched) then
        st = "Watched"
    end if
    msg = [joinParts([anyStr(e.name), fmtLen(numv(e.duration)), st])]
    if anyStr(e.plot) <> "" then msg.Push(anyStr(e.plot))
    dialog(anyStr(show.name) + "  S" + anyStr(e.season) + " E" + anyStr(e.episode), msg, buttons, actions, { kind: "episode", show: show, e: e })
end sub

' an episode found by Search: play it, or open the show
sub episodeQuick(e as Object)
    dialog(anyStr(e.name), [anyStr(e["sub"])], ["Play", "All episodes", "Close"], ["playep", "allep", "close"], { kind: "epquick", e: e })
end sub

sub pick(t as Object)
    if t = invalid then return
    if t.kind = "episode" then
        episodeQuick(t)
        return
    end if
    if t.kind = "series" and anyStr(t.resume) <> "" then
        ' Continue Watching: straight back into the episode
        sb = anyStr(t["sub"])
        lbl = "Resume episode"
        if sb <> "" then lbl = "Resume " + sb
        dialog(anyStr(t.name), [sb], [lbl, "All episodes", "Close"], ["resumeep", "allep", "close"], { kind: "cw", t: t })
        return
    end if
    if t.kind = "series" then
        api("show", "/api/vod/title/" + urlEncode(t.id), invalid, {})
    else
        api("pick", "/api/vod/title/" + urlEncode(t.id), invalid, {})
    end if
end sub

' Play button: no dialog, resume where you stopped
sub quickPlay()
    if m.show <> invalid then
        eps = curEps()
        if m.ep < eps.Count() then play(eps[m.ep].id, -1)
        return
    end if
    t = curItem()
    if t = invalid then return
    if t.kind = "movie" or t.kind = "episode" then
        play(t.id, -1)
    else if anyStr(t.resume) <> "" then
        play(anyStr(t.resume), -1)
    else
        pick(t)
    end if
end sub

sub setList(d as Object, on as Boolean)
    msg = anyStr(d.name) + " removed from My List"
    if on then msg = anyStr(d.name) + " added to My List"
    api("list", "/api/vod/list", { id: d.id, on: on }, { msg: msg })
end sub

sub mark(id as String, watched as Boolean)
    msg = "Marked as not watched"
    if watched then msg = "Marked as watched"
    api("watched", "/api/vod/watched", { id: id, watched: watched }, { msg: msg })
end sub

sub starCurrent()
    if m.show <> invalid then
        setList(m.show, not isTrue(m.show.in_list))
        return
    end if
    t = curItem()
    if t = invalid then return
    if t.kind = "episode" then
        toast("Open the show to add it to My List")
        return
    end if
    d = m.details[t.id]
    if d <> invalid then
        setList(d, not isTrue(d.in_list))
    else
        ' My List tab: everything there is listed; elsewhere assume not
        setList({ id: t.id, name: t.name }, (tabKind() <> "list"))
    end if
end sub

sub onDialogAction()
    a = m.top.dialogAction
    p = m.pending
    m.pending = invalid
    if p = invalid or a = "close" or a = "" then return
    if p.kind = "movie" then
        d = p.d
        if a = "resume" then
            play(d.id, numv(d.position))
        else if a = "play" then
            play(d.id, 0)
        else if a = "list" then
            setList(d, not isTrue(d.in_list))
        else if a = "watched" then
            mark(d.id, not isTrue(d.watched))
        else if a = "more" then
            goCategory(anyStr(d.category))
        end if
    else if p.kind = "episode" then
        e = p.e
        if a = "resume" then
            play(e.id, numv(e.position))
        else if a = "play" then
            play(e.id, 0)
        else if a = "watched" then
            mark(e.id, not isTrue(e.watched))
        else if a = "list" then
            setList(p.show, not isTrue(p.show.in_list))
        end if
    else if p.kind = "epquick" then
        if a = "playep" then
            play(p.e.id, -1)
        else if a = "allep" then
            api("show", "/api/vod/title/" + urlEncode(anyStr(p.e.title_id)), invalid, {})
        end if
    else if p.kind = "cw" then
        if a = "resumeep" then
            play(anyStr(p.t.resume), -1)
        else if a = "allep" then
            api("show", "/api/vod/title/" + urlEncode(p.t.id), invalid, {})
        end if
    end if
end sub

sub goCategory(name as String)
    m.show = invalid
    m.tab = 0
    m.focusTab = 0
    m.zone = "cats"
    m.pendingCat = name
    loadTab(false)
end sub

' ============================================================ search
sub onSearchText()
    q = m.top.searchText.Trim()
    if q = "" then return
    m.searchQ = q
    m.searchItems = []
    m.show = invalid
    m.tab = 4
    m.focusTab = 4
    m.zone = "tabs"
    m.items = []
    m.total = 0
    m.loading = true
    m.message = ""
    api("search", "/api/vod/search?q=" + urlEncode(q) + "&limit=100", invalid, { q: q })
    render()
end sub

' ============================================================ keys
sub useTab(i as Integer)
    m.tabTimer.control = "stop"
    if i = m.tab and (m.items.Count() > 0 or m.loading) then return
    m.tab = i
    m.focusTab = i
    m.show = invalid
    loadTab(false)
end sub

sub focusTabTo(i as Integer)
    n = m.TABS.Count()
    m.focusTab = (i + n) mod n
    render()
    m.tabTimer.control = "stop"
    ' lists switch when the highlight rests on them; Search acts on OK
    if m.focusTab < 4 and m.focusTab <> m.tab then m.tabTimer.control = "start"
end sub

sub onTabTimer()
    if m.zone = "tabs" and m.focusTab < 4 and m.focusTab <> m.tab then useTab(m.focusTab)
end sub

sub setCat(i as Integer)
    if i < 0 then i = 0
    if i > m.cats.Count() - 1 then i = m.cats.Count() - 1
    if i = m.cat then return
    m.cat = i
    m.sel = 0
    m.topRow = 0
    drawSide()
    m.catTimer.control = "stop"
    m.catTimer.control = "start"
end sub

sub onCatTimer()
    loadItems(false, false)
end sub

sub moveSel(delta as Integer)
    n = m.items.Count()
    if n = 0 then return
    s = m.sel + delta
    if s < 0 then s = 0
    if s > n - 1 then s = n - 1
    if s = m.sel then return
    m.sel = s
    drawMain()
    drawInfo()
    maybeMore()
end sub

function gridKey(key as String) as Boolean
    n = m.items.Count()
    col = m.sel mod m.COLS
    if key = "left" then
        if col = 0 then
            if hasCats() then m.zone = "cats" else return true
            render()
        else
            moveSel(-1)
        end if
    else if key = "right" then
        if col < m.COLS - 1 and m.sel + 1 < n then moveSel(1)
    else if key = "up" then
        if m.sel < m.COLS then
            m.zone = "tabs"
            m.focusTab = m.tab
            render()
        else
            moveSel(0 - m.COLS)
        end if
    else if key = "down" then
        if m.sel + m.COLS < n then
            moveSel(m.COLS)
        else if (n - 1) \ m.COLS > m.sel \ m.COLS then
            moveSel(n - 1 - m.sel)
        else
            maybeMore()
        end if
    else if key = "rewind" then
        moveSel(0 - m.COLS * m.ROWS)
    else if key = "fastforward" then
        moveSel(m.COLS * m.ROWS)
    else if key = "OK" then
        pick(curItem())
    else if key = "play" then
        quickPlay()
    else if key = "options" then
        starCurrent()
    else
        return false
    end if
    return true
end function

function showKey(key as String) as Boolean
    eps = curEps()
    nSeasons = arr(m.show.seasons).Count()
    if m.zone = "seasons" then
        if key = "up" and m.season > 0 then
            m.season = m.season - 1
            m.ep = 0
            m.epTop = 0
            render()
        else if key = "down" and m.season < nSeasons - 1 then
            m.season = m.season + 1
            m.ep = 0
            m.epTop = 0
            render()
        else if key = "right" or key = "OK" then
            m.zone = "eps"
            render()
        else if key = "options" then
            starCurrent()
        end if
        return true
    end if
    if key = "up" then
        if m.ep > 0 then
            m.ep = m.ep - 1
            render()
        end if
    else if key = "down" then
        if m.ep < eps.Count() - 1 then
            m.ep = m.ep + 1
            render()
        end if
    else if key = "rewind" then
        m.ep = m.ep - m.NEPS
        if m.ep < 0 then m.ep = 0
        render()
    else if key = "fastforward" then
        m.ep = m.ep + m.NEPS
        if m.ep > eps.Count() - 1 then m.ep = eps.Count() - 1
        render()
    else if key = "left" then
        m.zone = "seasons"
        render()
    else if key = "OK" then
        if m.ep < eps.Count() then episodeDialog(m.show, eps[m.ep])
    else if key = "play" then
        quickPlay()
    else if key = "options" then
        starCurrent()
    end if
    return true
end function

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false

    if key = "back" then
        if m.show <> invalid then
            closeShow()
        else if m.zone = "tabs" and m.focusTab <> m.tab then
            m.focusTab = m.tab
            m.tabTimer.control = "stop"
            render()
        else
            m.top.request = { type: "close" }
        end if
        return true
    end if
    if m.message <> "" and m.counts = invalid then return true

    if m.show <> invalid then return showKey(key)

    if m.zone = "tabs" then
        if key = "left" then
            focusTabTo(m.focusTab - 1)
        else if key = "right" then
            focusTabTo(m.focusTab + 1)
        else if key = "OK" then
            if m.focusTab = 4 then
                m.top.request = { type: "keyboard", text: m.searchQ }
            else
                useTab(m.focusTab)
                if m.items.Count() > 0 then
                    m.zone = "grid"
                    render()
                end if
            end if
        else if key = "down" then
            if m.focusTab <> m.tab then useTab(m.focusTab)
            if hasCats() and m.cats.Count() > 0 then
                m.zone = "cats"
            else if m.items.Count() > 0 then
                m.zone = "grid"
            end if
            render()
        end if
        return true
    end if

    if m.zone = "cats" then
        if key = "up" then
            if m.cat = 0 then
                m.zone = "tabs"
                m.focusTab = m.tab
                render()
            else
                setCat(m.cat - 1)
            end if
        else if key = "down" then
            setCat(m.cat + 1)
        else if key = "rewind" then
            setCat(m.cat - m.NCATS)
        else if key = "fastforward" then
            setCat(m.cat + m.NCATS)
        else if key = "right" or key = "OK" then
            if m.items.Count() > 0 then
                m.zone = "grid"
                render()
            end if
        end if
        return true
    end if

    if gridKey(key) then return true
    return true
end function
