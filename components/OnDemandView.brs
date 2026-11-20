' On Demand (movies and TV shows from the playlists), mirrors the TunerBox web screen:
' live TV keeps playing in the corner, the highlighted title's details beside it, then tabs
' (Movies / TV Shows / Continue Watching / My List / Search), a category column and a poster grid.
' A TV show opens in the same frame with its seasons on the left and episodes on the right.
' This view talks to TunerBox /api/vod/* itself; the scene shows its dialogs and plays the video.

sub init()
    themeInit()
    ' where the live-TV preview sits (not m.PV: names ignore case, so that's m.pv, Pick a version's state)
    m.PREVIEW_RECT = [40, 30, 560, 315]
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
    ' first page of a list: 3 screens of tiles (small = quick to parse and hand over); later pages are bigger
    m.PAGE = 42
    m.MORE = 84
    ' lists already seen (first page only), so switching back to a category shows at once
    m.CACHE_MAX = 12
    m.CACHE_FRESH = 120
    m.uptime = CreateObject("roTimespan")
    m.cacheGen = 0
    m.RESUME_MIN = 30

    m.top.previewRect = m.PREVIEW_RECT
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
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onHoldTimer")
    m.holdKey = ""
    m.holdZone = ""
    m.holdSteps = 0
    m.clockTimer.observeField("fire", "drawClock")
    m.pvTimer = m.top.findNode("pvTimer")
    m.pvTimer.observeField("fire", "onPvTimer")
    m.pvGroup = m.top.findNode("pvGroup")
    m.mdGroup = m.top.findNode("mdGroup")
    m.kbGroup = m.top.findNode("kbGroup")

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
    cacheClear()
    buildNodes()
end sub

' ============================================================ nodes (created once, then only updated)
sub buildNodes()
    m.tabNodes = []
    for i = 0 to m.TABS.Count() - 1
        n = {}
        n.bg = mkRect(0, 369, 10, 52, thm("0xFFC845FF"))
        n.lbl = mkLabel(0, 365, 0, 60, "", 28, true, thm("0xFFFFFFFF"))
        n.line = mkRect(0, 419, 10, 6, thm("0xFFC845FF"))
        m.tabsGroup.appendChild(n.bg)
        m.tabsGroup.appendChild(n.lbl)
        m.tabsGroup.appendChild(n.line)
        m.tabNodes.Push(n)
    end for

    m.catNodes = []
    for r = 0 to m.NCATS - 1
        y = m.CAT_Y + r * m.CAT_H
        n = {}
        n.bg = mkRect(m.CAT_X, y, m.CAT_W, m.CAT_H - 4, thm("0x153A80FF"))
        n.name = mkLabel(m.CAT_X + 16, y, m.CAT_W - 120, m.CAT_H - 4, "", 26, true, thm("0xFFFFFFFF"))
        n.cnt = mkLabel(m.CAT_X + m.CAT_W - 110, y, 96, m.CAT_H - 4, "", 23, false, thm("0xCFE0FFFF"))
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
            n.ring = mkRect(x - 6, y - 6, m.TW + 12, m.TH + 12, thm("0xFFC845FF"))
            n.bg = mkRect(x, y, m.TW, m.TH, thm("0x1C3F86FF"))
            ' the name sits under the poster: it shows when there is no artwork
            n.name = mkLabel(x + 10, y + 10, m.TW - 20, m.TH - 20, "", 25, true, thm("0xFFFFFFFF"))
            n.name.horizAlign = "center"
            n.name.wrap = true
            n.poster = CreateObject("roSGNode", "Poster")
            n.poster.translation = [x, y]
            n.poster.width = m.TW
            n.poster.height = m.TH
            n.poster.loadWidth = m.TW
            n.poster.loadHeight = m.TH
            n.poster.loadDisplayMode = "scaleToFill"
            ' the rows below start loading only once the ones on screen are in (see prefetchWhenReady)
            n.poster.observeField("loadStatus", "onTileLoad")
            n.tagBg = mkRect(x, y, 70, 30, thm("0xE0243CFF"))
            n.tag = mkLabel(x, y, 70, 30, "", 19, true, thm("0xFFFFFFFF"))
            n.tag.horizAlign = "center"
            n.progBg = mkRect(x, y + m.TH - 10, m.TW, 10, thm("0x00000099"))
            n.progFill = mkRect(x, y + m.TH - 10, 0, 10, thm("0xFFC845FF"))
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
        n.bg = mkRect(m.GX, y, 1410, m.EP_H - 4, thm("0x153A80FF"))
        n.num = mkLabel(m.GX + 16, y, 100, m.EP_H - 4, "", 26, true, thm("0xFFC845FF"))
        n.name = mkLabel(m.GX + 120, y, 960, m.EP_H - 4, "", 27, true, thm("0xFFFFFFFF"))
        n.right = mkLabel(m.GX + 1090, y, 300, m.EP_H - 4, "", 23, false, thm("0xCFE0FFFF"))
        n.right.horizAlign = "right"
        n.prog = mkRect(m.GX, y + m.EP_H - 10, 0, 6, thm("0xFFC845FF"))
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
    if tag = "pre" then
        gotPre(r, ctx)
        return
    end if
    if tag = "settings" then
        ' Setup > Settings: read each version's details for Pick a version (auto | ask | off)
        if r.ok and Type(r.data) = "roAssociativeArray" and anyStr(r.data.vod_details) <> "" then m.vodDetails = anyStr(r.data.vod_details)
        return
    end if
    ' Pick a version: also after On Demand closed (lets go of paused live TV)
    if tag = "pvlist" then
        gotPvList(r, ctx)
        return
    else if tag = "pvpeek" then
        gotPvPeek(r, ctx)
        return
    else if tag = "pvstop" then
        gotPvStop(ctx)
        return
    end if
    ' My List / watched: said even when the panel over Search has closed meanwhile
    if tag = "list" or tag = "watched" then
        if not r.ok then
            toast("Could not reach TunerBox")
            return
        end if
        toast(ctx.msg)
        if m.top.visible and not isTrue(m.overlay) then
            refresh()
        else
            ' the panel was over another screen (Home's Continue Watching): it shows the change itself
            m.top.request = { type: "changed" }
        end if
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
        m.overlayLoading = false
        if not r.ok then
            toast("That title is no longer in the playlist")
            overlayEnd()
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
    end if
end sub

sub toast(text as String)
    m.top.request = { type: "toast", text: text }
end sub

' ============================================================ open / close (called by the scene)
' args: {} = where you left it, { kind: "movie" | "series" }, { showId }, { movieId }, { episode: { id, name, sub, title_id } }
sub openOD(args as Object)
    if args = invalid then args = {}
    overlayRestore()
    m.top.visible = true
    m.top.setFocus(true)
    m.clockTimer.control = "start"
    drawClock()
    m.args = args
    m.message = "Loading On Demand..."
    m.seq = m.seq + 1
    cacheClear()
    api("counts", "/api/vod", invalid, {})
    api("settings", "/api/settings", invalid, {})
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
    pvClose()
    mdClose()
    kbClose()
    overlayRestore()
    m.infoTimer.control = "stop"
    m.tabTimer.control = "stop"
    m.catTimer.control = "stop"
    holdStop(false)
    m.clockTimer.control = "stop"
    m.top.visible = false
    m.top.setFocus(false)
end sub

' ============================================================ over another screen (Search)
' A movie found by Search: only its panel (and Pick a version) over the Search screen, the rest of On Demand
' hidden. Closing them hands back to the scene (request "overlayDone"); playing goes through it as usual.
sub openMovie(args as Object)
    overlayRestore()
    m.overlay = true
    m.overlayLoading = true
    m.overlayHidden = []
    for i = 0 to m.top.getChildCount() - 1
        ch = m.top.getChild(i)
        ' Timers have no "visible": skipped (it reads as invalid, which can't go in an "and")
        keep = (not ch.hasField("visible")) or ch.isSameNode(m.mdGroup) or ch.isSameNode(m.pvGroup)
        if not keep then
            if ch.visible = true then
                ch.visible = false
                m.overlayHidden.Push(ch)
            end if
        end if
    end for
    m.show = invalid
    mdClose()
    m.top.visible = true
    m.top.setFocus(true)
    api("settings", "/api/settings", invalid, {})
    api("pick", "/api/vod/title/" + urlEncode(anyStr(args.id)), invalid, {})
end sub

' the rest of On Demand shown again (it's opened for itself, or closed)
sub overlayRestore()
    if m.overlayHidden <> invalid then
        for each ch in m.overlayHidden
            ch.visible = true
        end for
    end if
    m.overlayHidden = invalid
    m.overlay = false
    m.overlayLoading = false
end sub

sub overlayEnd()
    if not isTrue(m.overlay) then return
    m.top.request = { type: "overlayDone" }
end sub

sub refresh()
    m.details = {}
    m.nDetails = 0
    ' progress / watched / My List marks may have changed: cached lists are out of date
    cacheClear()
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
    if numv(d.lib_new) > 0 then cats.Push({ all: false, key: "*libnew", name: "New in My Library", count: numv(d.lib_new) })
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

' ============================================================ list cache (per tab / category)
' key of the list for category ci of this tab ("" when there is none)
function itemsKey(ci as Integer) as String
    if not hasCats() then return "tab|" + tabKind()
    if ci < 0 or ci >= m.cats.Count() or m.cats[ci].all then return tabKind() + "|*all"
    return tabKind() + "|=" + m.cats[ci].key
end function

function itemsPath(ci as Integer) as String
    if not hasCats() then return "/api/vod/titles?tab=" + tabKind()
    path = "/api/vod/titles?kind=" + tabKind()
    if ci >= 0 and ci < m.cats.Count() and not m.cats[ci].all then path = path + "&cat=" + urlEncode(m.cats[ci].key)
    return path
end function

sub cacheClear()
    m.cache = {}
    m.cache.SetModeCaseSensitive()
    m.cacheKeys = []
    m.preInFlight = {}
    m.preInFlight.SetModeCaseSensitive()
    m.waitPre = ""
    m.cacheGen = m.cacheGen + 1
end sub

' keeps (a copy of) the first page only: the shown list grows as you scroll and must not grow the cache
sub cacheSet(key as String, items as Object, total as Integer)
    if key = "" then return
    n = items.Count()
    if n > m.PAGE then n = m.PAGE
    copy = []
    for i = 0 to n - 1
        copy.Push(items[i])
    end for
    m.cache[key] = { items: copy, total: total, at: m.uptime.TotalSeconds() }
    for i = 0 to m.cacheKeys.Count() - 1
        if m.cacheKeys[i] = key then
            m.cacheKeys.Delete(i)
            exit for
        end if
    end for
    m.cacheKeys.Push(key)
    while m.cacheKeys.Count() > m.CACHE_MAX
        m.cache.Delete(m.cacheKeys.Shift())
    end while
end sub

function cacheFresh(c as Dynamic) as Boolean
    return c <> invalid and m.uptime.TotalSeconds() - c.at < m.CACHE_FRESH
end function

sub useCached(c as Object)
    items = []
    items.Append(c.items)
    m.items = items
    m.total = c.total
    m.message = ""
end sub

' first page of the categories above and below, so moving up / down the column usually finds it ready
sub prefetchCats()
    if not hasCats() or m.cats.Count() = 0 then return
    for each ci in [m.cat + 1, m.cat - 1]
        if ci >= 0 and ci < m.cats.Count() then
            key = itemsKey(ci)
            if not cacheFresh(m.cache[key]) and not m.preInFlight.DoesExist(key) then
                m.preInFlight[key] = true
                api("pre", itemsPath(ci) + "&offset=0&limit=" + m.PAGE.ToStr(), invalid, { key: key, gen: m.cacheGen })
            end if
        end if
    end for
end sub

sub gotPre(r as Object, ctx as Object)
    if numv(ctx.gen) <> m.cacheGen then return
    key = anyStr(ctx.key)
    m.preInFlight.Delete(key)
    if r.ok and Type(r.data) = "roAssociativeArray" then cacheSet(key, arr(r.data.items), Int(numv(r.data.total)))
    ' the category was picked while its prefetch was on the way: this is its list
    if m.top.visible and m.waitPre <> "" and m.waitPre = key and key = itemsKey(m.cat) and m.tab <> 4 then
        m.waitPre = ""
        gotItems(r, { key: key })
    end if
end sub

sub loadItems(keep as Boolean, append as Boolean)
    if m.tab = 4 then return
    if not append then m.seq = m.seq + 1
    m.waitPre = ""
    key = itemsKey(m.cat)
    if not keep and not append then
        c = m.cache[key]
        if c <> invalid then
            useCached(c)
            if cacheFresh(c) then
                m.loading = false
                render()
                prefetchCats()
                return
            end if
            ' seen a while ago: shown as it was, and read again in the background
            keep = true
        else if m.preInFlight.DoesExist(key) then
            m.items = []
            m.total = 0
            m.message = ""
            m.loading = true
            m.waitPre = key
            render()
            return
        end if
    end if
    path = itemsPath(m.cat)
    off = 0
    if append then off = m.items.Count()
    limit = m.PAGE
    if append then limit = m.MORE
    if keep and m.items.Count() > limit then limit = m.items.Count()
    if limit > 500 then limit = 500
    path = path + "&offset=" + off.ToStr() + "&limit=" + limit.ToStr()
    m.loading = true
    api("items", path, invalid, { seq: m.seq, append: append, keep: keep, key: key })
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
    if not isTrue(ctx.append) then
        cacheSet(anyStr(ctx.key), m.items, m.total)
        prefetchCats()
    end if
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
    if m.items.Count() < m.total and m.sel >= m.items.Count() - m.COLS * 4 then loadItems(false, true)
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
                n.lbl.color = thm("0xFFFFFFFF")
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
        n.lbl.text = plainText(label)
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
        if focused then n.lbl.color = thm("0x10244AFF") else n.lbl.color = thm("0xFFFFFFFF")
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
        n.cnt.text = plainText(row.cnt)
        if isCur and active then
            n.bg.color = thm("0xFFC845FF")
            n.name.color = thm("0x10244AFF")
            n.cnt.color = thm("0x10244AFF")
        else if isCur then
            n.bg.color = thm("0x2F66C8FF")
            n.name.color = thm("0xFFFFFFFF")
            n.cnt.color = thm("0xCFE0FFFF")
        else
            n.bg.color = thm("0x153A80FF")
            n.name.color = thm("0xFFFFFFFF")
            n.cnt.color = thm("0xCFE0FFFF")
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
        m.msgLbl.text = plainText(m.message)
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
    prefetchWhenReady()
end sub

'' small poster made by TunerBox (GET /api/vod/poster/<id>), not the provider's full-size image
' Search results don't carry a poster field: ask for the poster anyway (a title with no artwork 404s and
' the tile just shows its name), and an episode found by Search shows its show's poster.
function posterUri(t as Object) as String
    id = anyStr(t.id)
    if t.kind = "episode" then
        id = anyStr(t.title_id)
        if id = "" then return ""
    else if t.DoesExist("poster") and anyStr(t.poster) = "" then
        return ""
    end if
    if id = "" then return ""
    return m.top.baseUrl + "/api/vod/poster/" + urlEncode(id)
end function

' The posters on screen first: the hidden ones for the rows below would otherwise be asked for at the same
' moment and race them (the end of the list could fill in before its start). So they wait until every shown
' tile's poster has loaded (or failed); a tile with no poster, or one hidden, doesn't hold them up.
sub prefetchWhenReady()
    for each tile in m.tiles
        if tile.poster.visible and tile.poster.uri <> "" then
            st = tile.poster.loadStatus
            if st <> "ready" and st <> "failed" then return
        end if
    end for
    prefetch()
end sub

sub onTileLoad()
    if m.top.visible then prefetchWhenReady()
end sub

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
        tagC = thm("0xE0243CFF")
        if t.kind = "episode" then
            tag = "EPISODE"
            tagC = thm("0x3B5B96FF")
        else if isTrue(t.watched) then
            tag = "SEEN"
            tagC = thm("0x1B6B2FFF")
        else if isTrue(t["new"]) then
            tag = "NEW"
        else if m.tab >= 2 and t.kind = "series" then
            tag = "SHOW"
            tagC = thm("0x3B5B96FF")
        end if
        tag = plainText(tag)
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
        n.right.text = plainText(right)
        if not isTrue(e.watched) and playPos > m.RESUME_MIN and dur > 0 then
            n.prog.visible = true
            p = playPos / dur
            if p > 1 then p = 1
            n.prog.width = Int(1410 * p)
        end if
        if isCur and m.zone = "eps" then
            n.bg.color = thm("0xFFC845FF")
            n.name.color = thm("0x10244AFF")
            n.num.color = thm("0x10244AFF")
            n.right.color = thm("0x10244AFF")
        else
            n.bg.color = thm("0x153A80FF")
            n.name.color = thm("0xFFFFFFFF")
            n.num.color = thm("0xFFC845FF")
            n.right.color = thm("0xCFE0FFFF")
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
            ' its picture, sound, bitrate and file, as far as they're known
            extra.Push(fmtAv(e.av))
            if Type(e.av) = "roAssociativeArray" then extra.Push(fmtRate(numv(e.av.kbps)))
            extra.Push(fmtFile(e))
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
        setInfo("Search On Demand", "Press OK and type a title, a year or an actor", "Movies and TV shows", "Accents don't matter, the words can be in any order, and small typos still find it. Your last 5 searches are listed beside the keyboard.", "")
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

' a movie's picture, sound, bitrate and file, as far as they're known: "4K HEVC HDR10 · 5.1 DD+ · 16.4 Mbps · MKV 42.1 GB"
' (not read yet: what its file name or label says, e.g. "1080p H.264")
function odStats(d as Object) as String
    return joinParts([fmtAv(avOrHint(d)), fmtRate(numv(d.bitrate)), fmtFile(d)])
end function

function avOrHint(v as Object) as Dynamic
    if Type(v.av) = "roAssociativeArray" then return v.av
    return v.hint
end function

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
    if isTrue(t.upnext) and anyStr(t.ep) <> "" then
        seen = "Up next: " + anyStr(t.ep)
    else if anyStr(t["sub"]) <> "" then
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
    stats = ""
    if d <> invalid and movie then stats = odStats(d)
    setInfo(anyStr(x.name), joinParts([anyStr(x.year), lenTxt, ratingStr(x.rating), genre]), joinParts([kind, stats, src, listed, seen]), plot, cast)
end sub

sub drawFoot()
    ' a panel open over the grid: its own keys, not the grid's
    if kbIsOpen() then
        m.footLbl.text = "OK  Type      Left  Recent searches      Replay  Delete      Play  Search      Back  Cancel"
    else if pvIsOpen() then
        m.footLbl.text = "Up/Down  Versions      OK  Play this version      Back  Close"
    else if mdIsOpen() then
        m.footLbl.text = "Up/Down  Buttons      OK  Select      Play  Play / Resume      Back  Close"
    else if m.show <> invalid then
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
    if resume then
        buttons.Push("Remove from Continue Watching")
        actions.Push("forget")
    end if
    ' the same film under the playlist's other labels (languages, 4K...)
    others = []
    for each v in arr(d.versions)
        if not isTrue(v.current) then others.Push(pvName(v, "no label"))
    end for
    if others.Count() > 0 then
        buttons.Push("Other versions (" + others.Join(", ") + ")")
        actions.Push("versions")
    end if
    cat = anyStr(d.category)
    here = (m.show = invalid and m.tab = 0 and m.cats.Count() > m.cat and not m.cats[m.cat].all and m.cats[m.cat].key = cat)
    if cat <> "" and not here and not isTrue(m.overlay) then
        buttons.Push("More in " + cat)
        actions.Push("more")
    end if
    buttons.Push("Close")
    actions.Push("close")
    genre = anyStr(d.genre)
    if genre = "" then genre = cat
    ' what it is, then (yellow) this copy's picture, sound and where it's from
    meta = joinParts(["Movie", anyStr(d.year), fmtLen(numv(d.duration)), ratingStr(d.rating), genre])
    note = joinParts([fmtAv(avOrHint(d)), fmtRate(numv(d.bitrate)), "From " + anyStr(d.source_name)])
    if resume then
        note = note + " " + Chr(183) + " You stopped at " + fmtDur(playPos)
    else if isTrue(d.watched) then
        note = note + " " + Chr(183) + " Watched"
    else
        ' not started in this copy, but in another one: say which, most recent first
        best = invalid
        for each v in arr(d.versions)
            if not isTrue(v.current) and not isTrue(v.watched) and numv(v.position) > m.RESUME_MIN then
                if best = invalid or numv(v.stopped) > numv(best.stopped) then best = v
            end if
        end for
        if best <> invalid then note = note + " " + Chr(183) + " You stopped " + pvName(best, "another version") + " at " + fmtDur(numv(best.position))
    end if
    m.md = { d: d, title: anyStr(d.name), meta: meta, note: note, plot: anyStr(d.plot), cast: anyStr(d.actors),
             poster: posterUri(d), buttons: buttons, actions: actions, sel: 0, ctx: { kind: "movie", d: d } }
    mdDraw()
end sub

' ============================================================ movie panel
' A movie's details beside its buttons, so nothing has to scroll: poster on the left, the text in the middle
' (what it is, this copy's picture and sound, the plot, the cast), the buttons on the right. Picking a button
' does what the same button in a dialog does (dialogDo).
function mdIsOpen() as Boolean
    return Type(m.md) = "roAssociativeArray"
end function

sub mdClose()
    m.md = invalid
    if m.mdGroup <> invalid then
        m.mdGroup.removeChildrenIndex(m.mdGroup.getChildCount(), 0)
        m.mdGroup.visible = false
        drawFoot()
    end if
end sub

sub mdDraw()
    g = m.mdGroup
    g.removeChildrenIndex(g.getChildCount(), 0)
    drawFoot()
    if not mdIsOpen() then
        g.visible = false
        return
    end if
    md = m.md
    g.visible = true
    hl = thm("0xFFC845FF")
    hlText = thm("0x111111FF")
    white = thm("0xFFFFFFFF")
    dimC = thm("0xA9BEE8FF")
    bg = thm("0x0B1D46FF")
    btnBg = thm("0x16306AFF")
    edge = thm("0x4F86E8FF")

    PW = 1680
    PH = 700
    PX = (1920 - PW) \ 2
    PY = 190
    PAD = 44
    POW = 320           ' poster 2:3
    POH = 480
    BW = 440            ' buttons
    BH = 66
    BGAP = 10
    TX = PX + PAD + POW + 44
    BX = PX + PW - PAD - BW
    TW = BX - 44 - TX

    shade = CreateObject("roSGNode", "Rectangle")
    shade.translation = [-200, -200]
    shade.width = 2320
    shade.height = 1480
    shade.color = "0x000000A0"
    g.appendChild(shade)
    pvBox(g, PX, PY, PW, PH, bg, edge)

    ' poster, over a plain box (shown when there's no artwork or it hasn't loaded)
    pvBox(g, PX + PAD, PY + PAD, POW, POH, btnBg, "")
    if md.poster <> "" then
        p = CreateObject("roSGNode", "Poster")
        p.translation = [PX + PAD, PY + PAD]
        p.width = POW
        p.height = POH
        p.loadDisplayMode = "scaleToFit"
        p.uri = md.poster
        g.appendChild(p)
    else
        nm = mkLabel(PX + PAD + 16, PY + PAD, POW - 32, POH, md.title, 30, true, dimC)
        nm.wrap = true
        nm.horizAlign = "center"
        g.appendChild(nm)
    end if

    ' the text
    y = PY + PAD - 6
    t = mkLabel(TX, y, TW, 0, md.title, 46, true, white)
    t.wrap = true
    t.maxLines = 2
    t.vertAlign = "top"
    g.appendChild(t)
    y = y + Int(t.boundingRect().height) + 14
    for each part in [{ s: md.meta, c: thm("0xDCE8FFFF"), z: 27, n: 2 }, { s: md.note, c: hl, z: 25, n: 2 }]
        if part.s <> "" then
            l = mkLabel(TX, y, TW, 0, part.s, part.z, false, part.c)
            l.wrap = true
            l.maxLines = part.n
            l.vertAlign = "top"
            g.appendChild(l)
            y = y + Int(l.boundingRect().height) + 10
        end if
    end for
    y = y + 12
    castH = 0
    if md.cast <> "" then castH = 76
    bottom = PY + PH - PAD
    if md.plot <> "" then
        pl = mkLabel(TX, y, TW, bottom - castH - y, md.plot, 26, false, white)
        pl.wrap = true
        pl.vertAlign = "top"
        pl.lineSpacing = 4
        g.appendChild(pl)
    end if
    if md.cast <> "" then
        c = mkLabel(TX, bottom - 66, TW, 66, md.cast, 22, false, dimC)
        c.wrap = true
        c.maxLines = 2
        c.vertAlign = "bottom"
        g.appendChild(c)
    end if

    ' the buttons
    by = PY + PAD
    for i = 0 to md.buttons.Count() - 1
        sel = (i = md.sel)
        fill = btnBg
        fg = white
        if sel then
            fill = hl
            fg = hlText
        end if
        pvBox(g, BX, by, BW, BH, fill, "")
        g.appendChild(mkLabel(BX + 24, by, BW - 48, BH, md.buttons[i], 28, sel, fg))
        by = by + BH + BGAP
    end for
end sub

' keys while the movie panel is open
function mdKey(key as String) as Boolean
    md = m.md
    n = md.buttons.Count()
    if key = "back" then
        mdClose()
    else if key = "up" then
        if md.sel > 0 then
            md.sel = md.sel - 1
            mdDraw()
        end if
    else if key = "down" then
        if md.sel < n - 1 then
            md.sel = md.sel + 1
            mdDraw()
        end if
    else if key = "OK" or key = "play" then
        ' Play on the remote: the first button (Resume / Play), wherever the highlight is
        i = md.sel
        if key = "play" then i = 0
        a = md.actions[i]
        if a = "versions" then
            ' Pick a version over the panel: Back / Close comes back to it
            openVersions(md.d)
            return true
        end if
        ctx = md.ctx
        mdClose()
        m.pending = ctx
        dialogDo(a)
    end if
    return true
end function

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
        ' Continue Watching: straight back into the episode (an Up next tile: the next one, from the start)
        sb = anyStr(t["sub"])
        ep = anyStr(t.ep)
        if ep = "" then ep = sb
        if ep = "" then ep = "episode"
        verb = "Resume "
        if isTrue(t.upnext) then verb = "Play "
        dialog(anyStr(t.name), [sb], [verb + ep, "All episodes", "Mark " + ep + " as watched", "Remove from Continue Watching", "Close"], ["resumeep", "allep", "cwwatched", "cwforget", "close"], { kind: "cw", t: t })
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
    dialogDo(m.top.dialogAction)
end sub

' a button picked: in a dialog the scene showed, or in the movie panel
sub dialogDo(a as String)
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
        else if a = "versions" then
            openVersions(d)
        else if a = "forget" then
            api("watched", "/api/vod/forget", { id: anyStr(d.id) }, { msg: "Removed from Continue Watching" })
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
        else if a = "cwwatched" then
            mark(anyStr(p.t.resume), true)
        else if a = "cwforget" then
            api("watched", "/api/vod/forget", { id: anyStr(p.t.id) }, { msg: "Removed from Continue Watching" })
        end if
    end if
end sub

' ============================================================ Pick a version
' A movie's other versions (languages, 4K...), drawn by this view as the web's Pick a version: one row per
' version with its label and small tags (Your copy, Current), what's known of it underneath ("HEVC 10-bit ·
' 5.1 AAC · 3.4 Mbps · MKV 2.4 GB") and the resolution / HDR as badges on the right (dim: only what the label
' or file name says). It opens at once and fills in as TunerBox fetches each version's bitrate
' (GET /api/vod/title/{id}/versions) and reads the picture and sound of the ones nobody has read yet, one at a
' time (GET /api/vod/peek/{id}; Setup > Settings "vod_details": auto | ask | off). What TunerBox already knows
' (played before, read by the library scan or another screen) comes with the list and isn't read again, and
' what this Roku read is kept while the app runs.
' When the playlist's only connection is this Roku's own live TV (the preview), that's paused for the reads
' and comes back on by itself.
' a version's name: its label ("EN", "4K-AMZ"), else "Your copy" for one of your own files, else where it is
function pvName(v as Object, none as String) as String
    n = anyStr(v.tag)
    if n = "" and isTrue(v.mine) then n = "Your copy"
    if n = "" then n = anyStr(v.where)
    if n = "" then n = none
    return n
end function

' a version's own progress (TunerBox sends it per version): { text, pct, watched }, or invalid when it has none
function pvProgress(v as Object) as Dynamic
    if isTrue(v.watched) then return { text: "WATCHED", pct: 0, watched: true }
    secs = numv(v.position)
    if secs <= m.RESUME_MIN then return invalid
    dur = numv(v.duration)
    if dur <= 0 then dur = numv(v.pdur)
    pct = 0
    if dur > 0 then pct = secs / dur
    if pct > 1 then pct = 1
    return { text: "STOPPED AT " + fmtDur(secs), pct: pct, watched: false }
end function

function pvClient() as String
    if m.pvClient = invalid then m.pvClient = "roku-" + CreateObject("roDeviceInfo").GetChannelClientId()
    return m.pvClient
end function

function pvMode() as String
    md = anyStr(m.vodDetails)
    if md = "" then md = "auto"
    return md
end function

function pvIsOpen() as Boolean
    ' m.pv doesn't exist until Pick a version first opens: checked on its own line, never in one "and"
    if Type(m.pv) <> "roAssociativeArray" then return false
    return isTrue(m.pv.open)
end function

' what's already known of a version (read here earlier) goes into ones TunerBox sent without it
sub pvKnown(vs as Object)
    if m.pvSeen = invalid then m.pvSeen = {}
    for each v in vs
        k = m.pvSeen[anyStr(v.id)]
        if k <> invalid and Type(v.av) <> "roAssociativeArray" then
            v.av = k.av
            if numv(v.bitrate) <= 0 then v.bitrate = k.bitrate
            if numv(v.duration) <= 0 then v.duration = k.duration
        end if
    end for
end sub

function pvUnread(vs as Object) as Boolean
    for each v in vs
        if Type(v.av) <> "roAssociativeArray" then return true
    end for
    return false
end function

sub openVersions(d as Object)
    m.pvSeq = numv(m.pvSeq) + 1
    ' a movie: into the other version from where this one was stopped (else wherever that one was left)
    at = -1
    if not isTrue(d.watched) and numv(d.position) > m.RESUME_MIN then at = numv(d.position)
    vs = arr(d.versions)
    pvKnown(vs)
    note = "Pick a version"
    if anyStr(d.kind) <> "series" and pvMode() = "auto" and pvUnread(vs) then note = note + " " + Chr(183) + " checking each one..."
    m.pv = { d: d, vs: vs, tag: "pv" + Int(m.pvSeq).ToStr(), open: true, reading: true, held: false,
             at: at, queue: [], force: false, note: note, sel: 0, waitId: "", ask: invalid }
    ' start on the version playing / picked last
    for i = 0 to vs.Count() - 1
        if isTrue(vs[i].current) then m.pv.sel = i
    end for
    pvDraw()
    api("pvlist", "/api/vod/title/" + urlEncode(anyStr(d.id)) + "/versions", invalid, { tag: m.pv.tag })
end sub

' the rows: { kind: "v", v, label } per version, then Read details (again) and Close
function pvRows() as Object
    pv = m.pv
    if pv.ask <> invalid then return pvAskRows()
    vs = pv.vs
    rows = []
    ' index loops, not "for each": a "for each" over vs inside another over vs shares the array's one
    ' iterator, so the outer loop ended after the first version (Pick a version listed only one)
    for vi = 0 to vs.Count() - 1
        v = vs[vi]
        name = pvName(v, "No label")
        ' a provider can list the same label twice: number them, and say which is newer
        same = []
        for xi = 0 to vs.Count() - 1
            if pvName(vs[xi], "No label") = name then same.Push(vs[xi])
        end for
        label = name
        if same.Count() > 1 then
            for i = 0 to same.Count() - 1
                if anyStr(same[i].id) = anyStr(v.id) then label = name + " (" + (i + 1).ToStr() + ")"
            end for
            if numv(v.added) > 0 then
                dt = CreateObject("roDateTime")
                dt.FromSeconds(Int(numv(v.added)))
                ds = dt.AsDateString("short-month-no-weekday")      ' "Nov 20, 2026"
                label = label + " " + Chr(183) + " added " + Left(ds, 3) + " " + Right(ds, 4)
            end if
        end if
        rows.Push({ kind: "v", v: v, label: label })
    end for
    ' Reading each version's picture and sound. "Only when I ask": always offered (read the ones not read yet,
    ' else read them all again). Automatically: only when some couldn't be read (no connection free, slow provider)
    md = pvMode()
    if not pv.reading and anyStr(pv.d.kind) <> "series" and md <> "off" then
        unread = false
        failed = false
        for each v in vs
            if Type(v.av) <> "roAssociativeArray" then
                if anyStr(v.why) <> "" then failed = true
                if anyStr(v.why) <> "" or md = "ask" then unread = true
            end if
        end for
        if unread then
            t = "Read video quality"
            if failed then t = "Read video quality again"
            rows.Push({ kind: "again", label: t, again: false })
        else if md = "ask" then
            rows.Push({ kind: "again", label: "Read video quality again", again: true })
        end if
    end if
    rows.Push({ kind: "close", label: "Close" })
    return rows
end function

' A version picked that was started (here, or in the one you were watching) or watched: where it starts.
' Its row stays on top (not selectable), the choices under it as buttons.
function pvAskRows() as Object
    pv = m.pv
    v = pv.ask.v
    rows = [{ kind: "v", v: v, label: pv.ask.label, fixed: true }]
    own = pvProgress(v)
    ownAt = -1
    if own <> invalid and not own.watched then
        ownAt = numv(v.position)
        rows.Push({ kind: "act", act: "play", at: ownAt, label: "Resume from " + fmtDur(ownAt) })
    end if
    carry = pvCarry(v)
    if carry >= 0 and (ownAt < 0 or Abs(carry - ownAt) > 60) then
        rows.Push({ kind: "act", act: "play", at: carry, label: "Continue from " + fmtDur(carry) + " (where " + pvName(pvHere(), "this version") + " stopped)" })
    end if
    rows.Push({ kind: "act", act: "play", at: 0, label: "Play from the beginning" })
    if own <> invalid then rows.Push({ kind: "act", act: "unwatch", label: "Mark this copy as not watched" })
    rows.Push({ kind: "act", act: "back", label: "Back" })
    return rows
end function

' the version you were watching (CURRENT), or invalid
function pvHere() as Dynamic
    for each x in m.pv.vs
        if isTrue(x.current) then return x
    end for
    return invalid
end function

' where the version you were watching stopped, as the same point in v (-1: none, or v is that version)
function pvCarry(v as Object) as Float
    pv = m.pv
    if isTrue(v.current) or pv.at < 0 then return -1
    here = pvHere()
    lenHere = numv(pv.d.duration)
    if here <> invalid and numv(here.duration) > 0 then lenHere = numv(here.duration)
    return pvSamePoint(pv.at, lenHere, numv(v.duration))
end function

' play v from `at` seconds (0: the beginning)
sub pvPlay(v as Object, at as Float)
    mdClose()               ' the movie panel under it: done
    m.pv.open = false
    m.pv.ask = invalid
    m.pv.held = false       ' what plays next is this version: live TV doesn't come back first (playVod forgets it)
    pvDraw()
    play(anyStr(v.id), at)
end sub

' "Mark this copy as not watched": its progress gone (TunerBox: only this version's), back to the list
sub pvUnwatch(v as Object)
    pv = m.pv
    api("watched", "/api/vod/watched", { id: anyStr(v.id), watched: false }, { msg: pvName(v, "This copy") + " marked as not watched" })
    v.position = 0
    v.watched = false
    v.stopped = 0
    if isTrue(v.current) then
        pv.at = -1
        pv.d.position = 0
        pv.d.watched = false
        if mdIsOpen() then movieDialog(pv.d)
    end if
    pvAskEnd()
end sub

' back from "where to start" to the versions, on the one that was picked
sub pvAskEnd()
    pv = m.pv
    v = pv.ask.v
    pv.ask = invalid
    pv.sel = 0
    for i = 0 to pv.vs.Count() - 1
        if anyStr(pv.vs[i].id) = anyStr(v.id) then pv.sel = i
    end for
    pvDraw()
end sub

' a version's details line: codec, sound, bitrate, length (only when the versions' lengths differ), file
function pvMeta(v as Object, lenDiffers as Boolean) as String
    av = avOrHint(v)
    meta = []
    if Type(av) = "roAssociativeArray" then
        pic = [avVcodec(anyStr(av.vcodec))]
        if numv(av.bits) >= 10 and anyStr(av.hdr) = "" then pic.Push(Int(numv(av.bits)).ToStr() + "-bit")
        meta.Push(spaceJoin(pic))
        lay = anyStr(av.layout)
        if lay = "stereo" then lay = "Stereo"
        if lay = "mono" then lay = "Mono"
        meta.Push(spaceJoin([lay, avAcodec(anyStr(av.acodec))]))
    end if
    meta.Push(fmtRate(numv(v.bitrate)))
    if isTrue(v.len_unknown) then
        meta.Push("length unknown")
    else if lenDiffers then
        meta.Push(fmtLen(numv(v.duration)))
    end if
    meta.Push(fmtFile(v))
    if anyStr(v.where) <> "" then meta.Push("from " + anyStr(v.where))
    info = joinParts(meta)
    if isTrue(v.checking) then
        info = joinParts([info, "Reading..."])
    else if anyStr(v.why) <> "" then
        info = joinParts([info, anyStr(v.why)])
    else if info = "" then
        info = "No details yet"
    end if
    if Type(v.av) <> "roAssociativeArray" and Type(v.hint) = "roAssociativeArray" then
        if isTrue(v.mine) then info = joinParts([info, "from the file name"]) else info = joinParts([info, "from its label"])
    end if
    return info
end function

' a small rounded label (a tag after the name, or a badge on the right) -> its width
function pvChip(g as Object, x as Integer, y as Integer, h as Integer, text as String, size as Integer, fill as String, edge as String, color as String) as Integer
    lbl = mkLabel(0, y, 0, h, text, size, true, color)
    w = Int(lbl.boundingRect().width) + 28
    pvBox(g, x, y, w, h, fill, edge)
    lbl.translation = [x, y]
    lbl.width = w
    lbl.horizAlign = "center"
    g.appendChild(lbl)
    return w
end function

sub pvDraw()
    g = m.pvGroup
    g.removeChildrenIndex(g.getChildCount(), 0)
    drawFoot()
    if not pvIsOpen() then
        g.visible = false
        return
    end if
    pv = m.pv
    g.visible = true
    rows = pvRows()
    if pv.sel > rows.Count() - 1 then pv.sel = rows.Count() - 1
    if pv.sel < 0 then pv.sel = 0
    ' lengths only when they differ (another cut, a PAL copy): otherwise they'd just repeat
    lo = 0
    hi = 0
    n = 0
    for each v in pv.vs
        l = numv(v.duration)
        if l > 0 then
            if n = 0 or l < lo then lo = l
            if l > hi then hi = l
            n = n + 1
        end if
    end for
    lenDiffers = (n > 1 and hi - lo > 120)

    hl = thm("0xFFC845FF")
    hlText = thm("0x111111FF")
    white = thm("0xFFFFFFFF")
    dimC = thm("0x9FB3DCFF")
    bg = thm("0x0B1D46FF")
    edge = thm("0x4F86E8FF")
    VH = 116            ' a version's row
    XH = 74             ' Read details / Close
    GAP = 6
    MAXV = 6            ' versions shown at once (the rest scroll)

    ' which rows show: all of them, or a window of the versions around the highlight (extras always shown)
    nv = 0
    for each r in rows
        if r.kind = "v" then nv = nv + 1
    end for
    first = 0
    if nv > MAXV then
        first = pv.sel - MAXV + 1
        if pv.sel >= nv then first = nv - MAXV
        if first < 0 then first = 0
        if first > nv - MAXV then first = nv - MAXV
    end if
    shown = []
    for i = 0 to rows.Count() - 1
        if rows[i].kind <> "v" or (i >= first and i < first + MAXV) then shown.Push(i)
    end for
    listH = 0
    for each i in shown
        if rows[i].kind = "v" then listH = listH + VH + GAP else listH = listH + XH + GAP + 8
    end for

    PW = 1200
    PH = 150 + listH + 24
    PX = (1920 - PW) \ 2
    PY = (1080 - PH) \ 2
    if PY < 40 then PY = 40

    shade = CreateObject("roSGNode", "Rectangle")
    shade.translation = [-200, -200]
    shade.width = 2320
    shade.height = 1480
    shade.color = "0x000000A0"
    g.appendChild(shade)
    pvBox(g, PX, PY, PW, PH, bg, edge)

    d = pv.d
    title = anyStr(d.name)
    if anyStr(d.year) <> "" then title = title + " (" + anyStr(d.year) + ")"
    g.appendChild(mkLabel(PX + 40, PY + 26, PW - 80, 60, title, 44, true, white))
    noteText = pv.note
    if pv.ask <> invalid then noteText = "Where do you want to start?"
    g.appendChild(mkLabel(PX + 40, PY + 90, PW - 80, 36, noteText, 26, false, dimC))
    if first > 0 then g.appendChild(mkLabel(PX + PW - 140, PY + 90, 100, 36, "more up", 22, false, dimC))

    y = PY + 140
    RX = PX + 24
    RW = PW - 48
    for each i in shown
        r = rows[i]
        sel = (i = pv.sel)
        fg = white
        sub2 = dimC
        if sel then
            fg = hlText
            sub2 = hlText
        end if
        if r.kind = "v" then
            if sel then pvBox(g, RX, y, RW, VH, hl, "")
            v = r.v
            ' badges on the right: resolution and HDR (dim outline: only what the label / file name says)
            av = avOrHint(v)
            guess = (Type(v.av) <> "roAssociativeArray" and Type(v.hint) = "roAssociativeArray")
            badges = []
            res = avRes(av)
            if res <> "" then badges.Push({ t: res, k: res })
            if Type(av) = "roAssociativeArray" and anyStr(av.hdr) <> "" then badges.Push({ t: anyStr(av.hdr), k: "hdr" })
            bx = RX + RW - 24
            for j = badges.Count() - 1 to 0 step -1
                b = badges[j]
                fill = bg
                ln = edge
                col = white
                if sel then
                    fill = hl
                    ln = hlText
                    col = hlText
                end if
                if guess then
                    ln = dimC
                    col = dimC
                    if sel then
                        ln = hlText
                        col = hlText
                    end if
                else if b.k = "4K" then
                    fill = white
                    ln = ""
                    col = bg
                    if sel then
                        fill = hlText
                        col = hl
                    end if
                else if b.k = "hdr" then
                    fill = "0x9B6BFFFF"
                    ln = ""
                    col = "0xFFFFFFFF"
                    if sel then
                        fill = hlText
                        col = hl
                    end if
                end if
                tmp = mkLabel(0, 0, 0, 40, b.t, 22, true, col)
                bw = Int(tmp.boundingRect().width) + 28
                bx = bx - bw
                pvChip(g, bx, y + (VH - 40) \ 2, 40, b.t, 22, fill, ln, col)
                bx = bx - 10
            end for
            ' the name, then its tags (room kept for them: the name is cut short first)
            prog = pvProgress(v)
            nameLbl = mkLabel(RX + 24, y + 14, 0, 50, r.label, 34, true, fg)
            nw = Int(nameLbl.boundingRect().width)
            maxName = bx - (RX + 24) - 330
            if prog <> invalid then maxName = maxName - 250
            if nw > maxName then
                nameLbl.width = maxName
                nw = maxName
            end if
            g.appendChild(nameLbl)
            tx = RX + 24 + nw + 18
            ' "Your copy" as a tag only when the name is a label (otherwise the name already says it)
            if isTrue(v.mine) and anyStr(v.tag) <> "" then
                tf = "0xFFFFFF26"
                if sel then tf = "0x00000026"
                tx = tx + pvChip(g, tx, y + 23, 32, "YOUR COPY", 18, tf, "", fg) + 10
            end if
            if isTrue(v.current) then
                tf = bg
                tl = edge
                tc = dimC
                if sel then
                    tf = hl
                    tl = hlText
                    tc = hlText
                end if
                tx = tx + pvChip(g, tx, y + 23, 32, "CURRENT", 18, tf, tl, tc) + 10
            end if
            ' where this version was stopped (or that it was watched), and a bar along the row's foot
            if prog <> invalid then
                pf = thm("0xE0243CFF")
                if prog.watched then pf = thm("0x1B6B2FFF")
                pvChip(g, tx, y + 23, 32, prog.text, 18, pf, "", "0xFFFFFFFF")
                if prog.pct > 0 then
                    BW = RW - 48
                    track = CreateObject("roSGNode", "Rectangle")
                    track.translation = [RX + 24, y + VH - 10]
                    track.width = BW
                    track.height = 5
                    track.color = "0xFFFFFF33"
                    if sel then track.color = "0x00000033"
                    g.appendChild(track)
                    fillBar = CreateObject("roSGNode", "Rectangle")
                    fillBar.translation = [RX + 24, y + VH - 10]
                    fillBar.width = Int(BW * prog.pct)
                    fillBar.height = 5
                    fillBar.color = pf
                    g.appendChild(fillBar)
                end if
            end if
            ' what's known of it underneath
            meta = mkLabel(RX + 24, y + 66, bx - (RX + 24) - 10, 36, pvMeta(v, lenDiffers), 24, false, sub2)
            if isTrue(v.checking) and not sel then meta.color = white
            g.appendChild(meta)
            y = y + VH + GAP
        else
            ' Close and Read details: buttons under the versions (outlined; filled when highlighted)
            y = y + 8
            if sel then
                pvBox(g, RX, y, RW, XH, hl, "")
            else
                pvBox(g, RX, y, RW, XH, bg, edge)
            end if
            c = fg
            bl = mkLabel(RX + 24, y, RW - 48, XH, r.label, 30, sel, c)
            bl.horizAlign = "center"
            g.appendChild(bl)
            y = y + XH + GAP
        end if
    end for
end sub

' keys while Pick a version is open
function pvKey(key as String) as Boolean
    pv = m.pv
    rows = pvRows()
    top = 0
    if pv.ask <> invalid then top = 1
    if key = "back" then
        if pv.ask <> invalid then pvAskEnd() else pvClose()
    else if key = "up" then
        if pv.sel > top then
            pv.sel = pv.sel - 1
            pvDraw()
        end if
    else if key = "down" then
        if pv.sel < rows.Count() - 1 then
            pv.sel = pv.sel + 1
            pvDraw()
        end if
    else if key = "OK" or key = "play" then
        if pv.sel < rows.Count() then pvPick(rows[pv.sel])
    end if
    return true
end function

sub pvPick(r as Object)
    pv = m.pv
    if r.kind = "close" then
        pvClose()
        return
    end if
    if r.kind = "again" then
        pvRead(true, isTrue(r.again))
        return
    end if
    if r.kind = "act" then
        if r.act = "play" then
            pvPlay(pv.ask.v, r.at)
        else if r.act = "unwatch" then
            pvUnwatch(pv.ask.v)
        else
            pvAskEnd()
        end if
        return
    end if
    if isTrue(r.fixed) then return
    v = r.v
    ' started or watched (this copy, or the one you were watching): ask where to start; else just play
    if pvProgress(v) <> invalid or pvCarry(v) >= 0 then
        pv.ask = { v: v, label: r.label }
        pv.sel = 1
        pvDraw()
        return
    end if
    pvPlay(v, 0)
end sub

' where `at` seconds into a copy `lenFrom` long falls in a copy `lenTo` long. Only a 24 fps film against a 25 fps
' (PAL) copy of it is scaled: the same frames run 4% faster, so lengths differ by 24/25. Any other difference
' (another cut, credits left off) keeps the seconds as they are.
function pvSamePoint(at as Float, lenFrom as Float, lenTo as Float) as Float
    r = 1.0
    if lenFrom > 0 and lenTo > 0 then r = lenTo / lenFrom
    if (r >= 0.95 and r <= 0.97) or (r >= 1 / 0.97 and r <= 1 / 0.95) then return Int(at * r + 0.5)
    return at
end function

sub pvClose()
    if Type(m.pv) <> "roAssociativeArray" then return
    pv = m.pv
    pv.open = false
    pvDraw()
    pvRelease()
end sub

' live TV paused for the reads: back on
sub pvRelease()
    if Type(m.pv) <> "roAssociativeArray" then return
    if isTrue(m.pv.held) then
        m.pv.held = false
        m.top.request = { type: "pvresume" }
    end if
end sub

sub gotPvList(r as Object, ctx as Object)
    if not pvIsOpen() then return
    pv = m.pv
    if anyStr(ctx.tag) <> anyStr(pv.tag) then return
    if r.ok and Type(r.data) = "roArray" and r.data.Count() > 0 then
        ' the highlight stays on the same version when the list comes back in another order
        selId = ""
        if pv.ask <> invalid then
            selId = anyStr(pv.ask.v.id)
        else if pv.sel < pv.vs.Count() then
            selId = anyStr(pv.vs[pv.sel].id)
        end if
        pv.vs = r.data
        pvKnown(pv.vs)
        for i = 0 to pv.vs.Count() - 1
            if anyStr(pv.vs[i].id) = selId then
                ' asking where to start: the highlight stays on its choice, the version gets the new details
                if pv.ask <> invalid then pv.ask.v = pv.vs[i] else pv.sel = i
            end if
        end for
    end if
    if anyStr(pv.d.kind) <> "series" and pvMode() = "auto" then
        pvRead(false, false)
    else
        pv.reading = false
        pv.note = "Pick a version"
        pvDraw()
    end if
end sub

' read each version not read yet, one at a time
' again: every version, the ones read already too (what each file says now); else the ones not read yet
sub pvRead(force as Boolean, again as Boolean)
    pv = m.pv
    pv.reading = true
    pv.force = force
    pv.again = again
    pv.queue = []
    for each v in pv.vs
        if again or Type(v.av) <> "roAssociativeArray" then pv.queue.Push(anyStr(v.id))
    end for
    if pv.queue.Count() > 0 then pv.note = "Pick a version " + Chr(183) + " reading each one..."
    pvNext()
end sub

sub pvNext()
    pv = m.pv
    if not pv.open then
        pvRelease()
        return
    end if
    if pv.queue.Count() = 0 then
        pv.reading = false
        pv.note = "Pick a version"
        pvDraw()
        pvRelease()
        return
    end if
    id = pv.queue.Shift()
    pvMark(id, { checking: true, why: "" })
    pvDraw()
    pvPeek(id, false)
end sub

sub pvPeek(id as String, retry as Boolean)
    f = ""
    if m.pv.force then f = "&force=1"
    if isTrue(m.pv.again) then f = f + "&again=1"
    api("pvpeek", "/api/vod/peek/" + urlEncode(id) + "?client=" + urlEncode(pvClient()) + f, invalid, { tag: m.pv.tag, id: id, retry: retry })
end sub

sub pvMark(id as String, more as Object)
    for each v in m.pv.vs
        if anyStr(v.id) = id then v.Append(more)
    end for
end sub

sub gotPvPeek(r as Object, ctx as Object)
    pv = m.pv
    if pv = invalid or anyStr(ctx.tag) <> pv.tag then return
    id = anyStr(ctx.id)
    got = invalid
    if r.ok and Type(r.data) = "roAssociativeArray" then got = r.data
    ' kept for this app run: the next Pick a version doesn't ask again
    if got <> invalid and Type(got.av) = "roAssociativeArray" then
        if m.pvSeen = invalid then m.pvSeen = {}
        m.pvSeen[id] = { av: got.av, bitrate: got.bitrate, duration: got.duration }
    end if
    if not pv.open then
        pvRelease()
        return
    end if
    if got = invalid then got = { why: "Could not reach TunerBox" }
    ' the playlist's connection is this Roku's own live TV: pause it, tell TunerBox it's let go, then read
    if isTrue(got.mine) and not isTrue(ctx.retry) and not pv.held then
        pv.waitId = id
        m.top.request = { type: "pvhold" }
        return
    end if
    got.Delete("mine")
    got.Delete("id")
    got.checking = false
    pvMark(id, got)
    pvNext()
end sub

' the scene's answer to pvhold: true when live TV was paused
sub onPvHeld()
    pv = m.pv
    if pv = invalid or anyStr(pv.waitId) = "" then return
    id = pv.waitId
    if m.top.pvHeld then pv.held = true
    if not pv.open then
        pv.waitId = ""
        pvRelease()
        return
    end if
    if not m.top.pvHeld then
        ' nothing here to let go of (an event feed): say why
        pv.waitId = ""
        pvMark(id, { checking: false, why: "This screen is using the playlist's connection" })
        pvNext()
        return
    end if
    pv.note = "Pick a version " + Chr(183) + " paused live TV to read each one..."
    pvDraw()
    api("pvstop", "/api/stop", { client: pvClient() }, { tag: pv.tag })
end sub

' TunerBox let go of the live stream: some providers take a moment to see it closed
sub gotPvStop(ctx as Object)
    if Type(m.pv) <> "roAssociativeArray" then return
    if anyStr(ctx.tag) <> anyStr(m.pv.tag) then return
    m.pvTimer.control = "stop"
    m.pvTimer.control = "start"
end sub

sub onPvTimer()
    pv = m.pv
    if pv = invalid or anyStr(pv.waitId) = "" then return
    id = pv.waitId
    pv.waitId = ""
    if not pv.open then
        pvRelease()
        return
    end if
    pvPeek(id, true)
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
    runSearch(m.top.searchText)
end sub

sub runSearch(q as String)
    q = q.Trim()
    if q = "" then return
    addRecentSearch(q)
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

' ============================================================ search keyboard
' The last 5 searches down the left, a keyboard drawn here on the right, Search and Cancel under it.
' Drawn rather than the Roku's own keyboard so every key comes here: Left from the first column goes to the
' recent searches (the Roku keyboard kept Left for itself). Typing on the Roku phone app works too (Lit_ keys),
' Instant Replay deletes a letter, Play searches from anywhere.
function kbIsOpen() as Boolean
    return Type(m.kb) = "roAssociativeArray"
end function


' the bottom row's wide keys: Space (columns 0-2), Delete (3-4), Clear (5-6) -> { id, first column, width }
function kbWide(c as Integer) as Object
    if c <= 2 then return { id: "space", label: "Space", c0: 0, n: 3 }
    if c <= 4 then return { id: "del", label: "Delete", c0: 3, n: 2 }
    return { id: "clear", label: "Clear", c0: 5, n: 2 }
end function

sub kbOpen()
    g = m.kbGroup
    g.removeChildrenIndex(g.getChildCount(), 0)
    back = CreateObject("roSGNode", "Group")
    front = CreateObject("roSGNode", "Group")
    g.appendChild(back)
    g.appendChild(front)
    m.kb = { text: m.searchQ, back: back, front: front, recent: recentSearches(), zone: "keys", r: 0, c: 0, sel: 0 }
    g.visible = true

    keyW = 84               ' a key
    keyH = 70
    keyGap = 8
    gridW = 7 * keyW + 6 * keyGap
    TH = 76                 ' the text typed
    gridH = TH + 24 + 7 * keyH + 6 * keyGap
    PAD = 48
    LW = 480                ' the recent searches
    GAPC = 56
    BH = 66                 ' Search / Cancel
    PW = PAD + LW + GAPC + gridW + PAD
    PH = PAD + 70 + gridH + 28 + BH + PAD
    PX = (1920 - PW) \ 2
    PY = (1080 - PH) \ 2
    if PY < 20 then PY = 20
    CY = PY + PAD + 70
    KX = PX + PAD + LW + GAPC
    m.kb.lay = { PX: PX, PY: PY, CY: CY, KX: KX, gridW: gridW, TH: TH, keyW: keyW, keyH: keyH, keyGap: keyGap, GY: CY + TH + 24,
                 LX: PX + PAD, LW: LW, BH: BH, BY: CY + gridH + 28 }

    shade = CreateObject("roSGNode", "Rectangle")
    shade.translation = [-200, -200]
    shade.width = 2320
    shade.height = 1480
    shade.color = "0x000000A0"
    back.appendChild(shade)
    pvBox(back, PX, PY, PW, PH, thm("0x0B1D46FF"), thm("0x4F86E8FF"))
    back.appendChild(mkLabel(PX + PAD, PY + PAD - 8, PW - 2 * PAD, 60, "Search On Demand", 44, true, thm("0xFFFFFFFF")))
    kbDraw()
    m.top.setFocus(true)
end sub

sub kbClose()
    m.kb = invalid
    if m.kbGroup <> invalid then
        m.kbGroup.removeChildrenIndex(m.kbGroup.getChildCount(), 0)
        m.kbGroup.visible = false
    end if
    drawFoot()
end sub

' a key: a rounded box, highlighted or not, with its label in the middle
sub kbKeyBox(f as Object, x as Integer, y as Integer, w as Integer, h as Integer, text as String, sel as Boolean, size as Integer)
    if sel then
        pvBox(f, x, y, w, h, thm("0xFFC845FF"), "")
    else
        pvBox(f, x, y, w, h, thm("0x16306AFF"), "")
    end if
    c = thm("0xFFFFFFFF")
    if sel then c = thm("0x111111FF")
    lb = mkLabel(x, y, w, h, text, size, sel, c)
    lb.horizAlign = "center"
    f.appendChild(lb)
end sub

sub kbDraw()
    kb = m.kb
    L = kb.lay
    f = kb.front
    f.removeChildrenIndex(f.getChildCount(), 0)
    drawFoot()
    white = thm("0xFFFFFFFF")
    dimC = thm("0xA9BEE8FF")

    ' recent searches
    f.appendChild(mkLabel(L.LX, L.CY, L.LW, 36, "RECENT SEARCHES", 22, true, dimC))
    y = L.CY + 50
    if kb.recent.Count() = 0 then
        nl = mkLabel(L.LX, y, L.LW, 0, "Searches you make show up here.", 26, false, dimC)
        nl.wrap = true
        nl.vertAlign = "top"
        f.appendChild(nl)
    end if
    for i = 0 to kb.recent.Count() - 1
        sel = (kb.zone = "recent" and kb.sel = i)
        if sel then
            pvBox(f, L.LX, y, L.LW, 66, thm("0xFFC845FF"), "")
        else
            pvBox(f, L.LX, y, L.LW, 66, thm("0x16306AFF"), "")
        end if
        c = white
        if sel then c = thm("0x111111FF")
        f.appendChild(mkLabel(L.LX + 22, y, L.LW - 44, 66, anyStr(kb.recent[i]), 28, sel, c))
        y = y + 66 + 10
    end for

    ' what's typed, with a cursor
    pvBox(f, L.KX, L.CY, L.gridW, L.TH, thm("0x06132FFF"), thm("0x4F86E8FF"))
    if kb.text = "" then
        f.appendChild(mkLabel(L.KX + 22, L.CY, L.gridW - 44, L.TH, "A title, a year or an actor", 28, false, dimC))
    else
        f.appendChild(mkLabel(L.KX + 22, L.CY, L.gridW - 44, L.TH, kb.text + "_", 32, false, white))
    end if

    ' the keys
    rows = kbRows()
    onKeys = (kb.zone = "keys")
    for r = 0 to rows.Count() - 1
        ky = L.GY + r * (L.keyH + L.keyGap)
        for c = 0 to 6
            kx = L.KX + c * (L.keyW + L.keyGap)
            kbKeyBox(f, kx, ky, L.keyW, L.keyH, Mid(rows[r], c + 1, 1), onKeys and kb.r = r and kb.c = c, 32)
        end for
    end for
    ky = L.GY + rows.Count() * (L.keyH + L.keyGap)
    for each c0 in [0, 3, 5]
        w = kbWide(c0)
        kx = L.KX + w.c0 * (L.keyW + L.keyGap)
        ww = w.n * L.keyW + (w.n - 1) * L.keyGap
        kbKeyBox(f, kx, ky, ww, L.keyH, w.label, onKeys and kb.r = rows.Count() and kbWide(kb.c).id = w.id, 28)
    end for

    ' Search and Cancel under the keyboard
    x = L.KX
    names = ["Search", "Cancel"]
    widths = [300, 220]
    for i = 0 to 1
        kbKeyBox(f, x, L.BY, widths[i], L.BH, names[i], kb.zone = "go" and kb.sel = i, 28)
        x = x + widths[i] + 16
    end for
end sub

sub kbGo(q as String)
    kbClose()
    runSearch(q)
end sub

sub kbType(ch as String)
    if Len(m.kb.text) < 80 then m.kb.text = m.kb.text + ch
end sub

sub kbDelete()
    t = m.kb.text
    if Len(t) > 0 then m.kb.text = Left(t, Len(t) - 1)
end sub

' every key while Search On Demand is open
function kbKey(key as String) as Boolean
    kb = m.kb
    n = kb.recent.Count()
    last = kbRows().Count()        ' the Space / Delete / Clear row
    if key = "back" then
        kbClose()
        return true
    end if
    if key = "play" or key = "enter" then
        kbGo(kb.text)
        return true
    end if
    ' a keyboard on the Roku phone app: its letters come as "Lit_a"
    if Left(key, 4) = "Lit_" then
        kbType(LCase(Mid(key, 5)))
        kbDraw()
        return true
    end if
    if key = "backspace" or key = "replay" then
        kbDelete()
        kbDraw()
        return true
    end if
    if kb.zone = "keys" then
        if key = "left" then
            if kb.r = last then
                if kbWide(kb.c).c0 > 0 then
                    kb.c = kbWide(kbWide(kb.c).c0 - 1).c0
                else if n > 0 then
                    kb.zone = "recent"
                    kb.sel = 0
                end if
            else if kb.c > 0 then
                kb.c = kb.c - 1
            else if n > 0 then
                kb.zone = "recent"
                kb.sel = 0
            end if
        else if key = "right" then
            if kb.r = last then
                w = kbWide(kb.c)
                if w.c0 + w.n <= 6 then kb.c = w.c0 + w.n
            else if kb.c < 6 then
                kb.c = kb.c + 1
            end if
        else if key = "up" then
            if kb.r > 0 then kb.r = kb.r - 1
        else if key = "down" then
            if kb.r < last then
                kb.r = kb.r + 1
            else
                kb.zone = "go"
                kb.sel = 0
            end if
        else if key = "OK" then
            if kb.r = last then
                id = kbWide(kb.c).id
                if id = "space" then
                    if kb.text <> "" and Right(kb.text, 1) <> " " then kbType(" ")
                else if id = "del" then
                    kbDelete()
                else
                    kb.text = ""
                end if
            else
                kbType(Mid(kbRows()[kb.r], kb.c + 1, 1))
            end if
        end if
    else if kb.zone = "recent" then
        if key = "up" and kb.sel > 0 then
            kb.sel = kb.sel - 1
        else if key = "down" and kb.sel < n - 1 then
            kb.sel = kb.sel + 1
        else if key = "right" then
            kb.zone = "keys"
            kb.c = 0
            if kb.r = last then kb.c = 0
        else if key = "OK" then
            kbGo(anyStr(kb.recent[kb.sel]))
            return true
        end if
    else if kb.zone = "go" then
        if key = "left" then
            if kb.sel > 0 then
                kb.sel = 0
            else if n > 0 then
                kb.zone = "recent"
                kb.sel = 0
            end if
        else if key = "right" and kb.sel < 1 then
            kb.sel = 1
        else if key = "up" then
            kb.zone = "keys"
            kb.r = last
            kb.c = 0
        else if key = "OK" then
            if kb.sel = 0 then kbGo(kb.text) else kbClose()
            return true
        end if
    end if
    kbDraw()
    return true
end function

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
    c = invalid
    if m.holdSteps = 0 then c = m.cache[itemsKey(i)]
    if c <> invalid then
        ' seen before: shown at once (the timer still reads it again if it's old, and fetches the neighbours)
        m.seq = m.seq + 1
        m.waitPre = ""
        useCached(c)
        m.loading = false
        render()
    else
        drawSide()
    end if
    m.catTimer.control = "stop"
    m.catTimer.control = "start"
end sub

sub onCatTimer()
    loadItems(false, false)
end sub

'' ============================================================ Up/Down held (category column, titles grid)
sub holdStart(key as String)
    m.holdKey = key
    m.holdZone = m.zone
    m.holdSteps = 0
    m.holdTimer.control = "stop"
    m.holdTimer.duration = 0.4
    m.holdTimer.control = "start"
end sub

' let go (or something else happened): when it scrolled, the list it stopped on loads now, not after the pause
sub holdStop(load as Boolean)
    if m.holdKey = "" then return
    m.holdTimer.control = "stop"
    stepped = m.holdSteps > 0
    m.holdKey = ""
    m.holdSteps = 0
    if load and stepped and m.zone = "cats" and m.show = invalid then
        m.catTimer.control = "stop"
        loadItems(false, false)
    end if
end sub

sub onHoldTimer()
    if m.holdKey = "" or m.zone <> m.holdZone or m.show <> invalid or not m.top.visible then
        holdStop(false)
        return
    end if
    if m.holdSteps = 0 then
        m.holdTimer.control = "stop"
        ' a row of posters a step: a little slower than the category names
        if m.zone = "grid" then m.holdTimer.duration = 0.15 else m.holdTimer.duration = 0.09
        m.holdTimer.control = "start"
    end if
    m.holdSteps = m.holdSteps + 1
    if m.zone = "grid" then
        holdGridStep()
        return
    end if
    before = m.cat
    if m.holdKey = "up" then setCat(m.cat - 1) else setCat(m.cat + 1)
    ' at either end of the column: stop there (held Up doesn't carry on into the tabs)
    if m.cat = before then m.holdTimer.control = "stop"
end sub

' one row up or down the titles grid while Up/Down is held
sub holdGridStep()
    before = m.sel
    if m.holdKey = "up" then
        ' stops on the first row (held Up doesn't carry on into the tabs)
        if m.sel >= m.COLS then moveSel(0 - m.COLS)
    else
        gridKey("down")
    end if
    if m.sel = before then
        ' at the end of what's loaded while the next page is on its way: keep going once it's in
        if m.holdKey = "down" and m.loading and m.items.Count() < m.total then return
        m.holdTimer.control = "stop"
    end if
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
    if not press then
        if m.holdKey <> "" and key = m.holdKey then
            holdStop(true)
            return true
        end if
        return false
    end if
    holdStop(false)
    if not m.top.visible then return false
    if isTrue(m.overlay) then
        if pvIsOpen() then
            pvKey(key)
        else if mdIsOpen() then
            mdKey(key)
        else if key = "back" then
            overlayEnd()
            return true
        end if
        ' both panels closed (Close, Back, a button done): back to Search
        if not pvIsOpen() and not mdIsOpen() and not m.overlayLoading then overlayEnd()
        return true
    end if
    if pvIsOpen() then return pvKey(key)
    if mdIsOpen() then return mdKey(key)
    if kbIsOpen() then return kbKey(key)

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
                kbOpen()
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
                holdStart("up")
            end if
        else if key = "down" then
            setCat(m.cat + 1)
            holdStart("down")
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

    if gridKey(key) then
        if (key = "up" or key = "down") and m.zone = "grid" then holdStart(key)
        return true
    end if
    return true
end function
