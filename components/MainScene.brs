' TunerBox TV - scene controller
' modes: boot | needhost | error | live | guide | sports | search | ondemand | vod

sub init()
    m.video = m.top.findNode("video")
    m.guide = m.top.findNode("guide")
    m.hud = m.top.findNode("hud")
    m.statusGroup = m.top.findNode("statusGroup")
    m.statusLbl = m.top.findNode("statusLbl")
    m.statusTitle = m.top.findNode("statusTitle")
    m.toast = m.top.findNode("toast")
    m.toastBg = m.top.findNode("toastBg")
    m.toastLbl = m.top.findNode("toastLbl")
    m.toastTimer = m.top.findNode("toastTimer")
    m.retryTimer = m.top.findNode("retryTimer")
    m.entryTimer = m.top.findNode("entryTimer")
    m.guideDelay = m.top.findNode("guideDelay")
    m.sports = m.top.findNode("sports")
    m.search = m.top.findNode("search")
    m.od = m.top.findNode("od")
    m.vod = invalid
    m.vodSeq = 0
    m.vodTasks = []
    m.vodTimer = m.top.findNode("vodTimer")
    m.seekTimer = m.top.findNode("seekTimer")
    m.parkTimer = m.top.findNode("parkTimer")
    m.searchFrom = ""
    m.menu = m.top.findNode("menu")
    m.checkTimer = m.top.findNode("checkTimer")
    m.extern = invalid
    m.sportsTasks = []
    m.sportsGroupName = ""
    m.gameReq = invalid
    m.menuPage = "main"
    m.recReq = invalid
    m.srReq = invalid
    m.quick = false
    m.quickNum = ""
    m.hideUnmapped = (regRead("hideUnmapped", "1") = "1")

    m.statusTitle.font.size = 72
    m.statusLbl.font.size = 38
    m.toastLbl.font.size = 36

    m.channels = []
    m.curIdx = -1
    m.lastIdx = -1
    m.playIdx = -1
    m.mode = "boot"
    m.digits = ""
    m.retries = 0
    m.base = ""
    m.dlg = invalid
    m.dlgKind = ""
    m.dlgActions = []
    m.epgCount = 0
    m.guideLoading = false
    m.underruns = 0
    m.favs = {}
    m.favTasks = []
    m.guideTitle = ""
    m.useCache = true
    m.fromCache = false
    m.guideTask = invalid

    m.video.observeField("state", "onVideoState")
    m.video.observeField("streamInfo", "onStreamInfo")
    m.guide.observeField("tuneRequest", "onGuideTune")
    m.guide.observeField("previewRequest", "onGuidePreview")
    m.guide.observeField("optionsRequest", "onGuideOptions")
    m.guide.observeField("menuRequest", "onGuideMenu")
    m.guide.observeField("exitRequest", "onGuideExit")
    m.hud.observeField("buttonSelected", "onHudButton")
    m.sports.observeField("request", "onSportsRequest")
    m.search.observeField("query", "onSearchQuery")
    m.search.observeField("request", "onSearchRequest")
    m.od.observeField("request", "onOdRequest")
    m.vodTimer.observeField("fire", "onVodTick")
    m.seekTimer.observeField("fire", "onSeekTimer")
    m.parkTimer.observeField("fire", "onParkTimer")
    m.menu.observeField("selected", "onMenuSelected")
    m.menu.observeField("closeRequest", "onMenuClose")
    m.checkTimer.observeField("fire", "onCheckTimer")
    m.toastTimer.observeField("fire", "onToastTimer")
    m.retryTimer.observeField("fire", "onRetryTimer")
    m.entryTimer.observeField("fire", "onEntryTimer")
    m.guideDelay.observeField("fire", "onGuideDelay")

    m.launchDone = false
    m.pendingLink = ""
    m.fitCal = m.top.findNode("fitCal")
    m.calPrev = "live"
    applyScreenFit()
    m.video.disableScreenSaver = true
    loadFavsCache()
    m.top.setFocus(true)
    if regRead("host", "") <> "" then quickPlay()
    start()
end sub

' ============================================================ startup / loading
sub start()
    if regRead("host", "") = "" then
        m.mode = "needhost"
        launchComplete()
        setStatus("No TunerBox server set." + Chr(10) + Chr(10) + "Press OK to enter its IP address.")
        promptHost()
    else
        loadAll()
    end if
end sub

sub onLaunchHost()
    h = m.top.launchHost
    if h <> "" then
        regWrite("host", h)
        regWrite("lastUrl", "")
        m.quick = false
        loadAll()
    end if
end sub

sub setStatus(text as String)
    m.statusLbl.text = text
    m.statusGroup.visible = true
end sub

sub loadAll()
    m.base = normalizeBase(regRead("host", ""))
    m.mode = "boot"
    m.guideDelay.control = "stop"
    if not m.quick then
        m.video.control = "stop"
        setStatus("Connecting to " + m.base + " ...")
    end if
    m.hud.callFunc("hideAll")
    m.guide.callFunc("closeGuide")
    m.task = CreateObject("roSGNode", "LoadTask")
    m.task.mode = "boot"
    m.task.hideUnmapped = m.hideUnmapped
    m.task.useCache = m.useCache
    m.useCache = true
    m.task.baseUrl = m.base
    m.task.observeField("status", "onTaskStatus")
    m.task.observeField("result", "onTaskResult")
    m.task.control = "RUN"
end sub

sub onTaskStatus()
    if m.mode = "boot" and not m.quick then setStatus(m.task.status)
end sub

' Start the last-watched channel immediately, before the channel list is even loaded.
sub quickPlay()
    url = regRead("lastUrl", "")
    if url = "" then return
    num = regRead("last", "")
    c = CreateObject("roSGNode", "ContentNode")
    c.url = streamUrl({ url: url, numStr: num })
    c.title = regRead("lastName", "")
    c.live = true
    c.streamFormat = streamFmt(url)
    m.video.content = c
    m.video.control = "play"
    m.quick = true
    m.quickNum = num
    m.statusGroup.visible = false
end sub

sub rememberChannel(idx as Integer)
    ch = m.channels[idx]
    regWrite("last", ch.numStr)
    regWrite("lastUrl", ch.url)
    regWrite("lastName", ch.name)
end sub

sub onGuideDelay()
    startGuideTask()
end sub

sub onTaskResult()
    r = m.task.result
    if r = invalid then return
    if not r.ok then
        m.video.control = "stop"
        m.quick = false
        m.mode = "error"
        launchComplete()
        setStatus(r.error + Chr(10) + Chr(10) + "OK = change server address     * = retry")
        return
    end if

    m.channels = r.channels
    m.fromCache = r.fromCache
    m.epgCount = 0
    m.guide.channels = m.channels
    m.statusGroup.visible = false
    m.mode = "live"
    m.top.setFocus(true)

    start_idx = 0
    last = regRead("last", "")
    if last <> "" then
        for i = 0 to m.channels.Count() - 1
            if m.channels[i].numStr = last then
                start_idx = i
                exit for
            end if
        end for
    end if
    if m.pendingLink <> "" then
        li = linkIndex(m.pendingLink)
        m.pendingLink = ""
        if li >= 0 then start_idx = li
    end if
    m.curIdx = start_idx
    if m.quick and m.quickNum = m.channels[start_idx].numStr then
        m.playIdx = start_idx
        m.retries = 0
    else
        playChannel(start_idx)
    end if
    m.quick = false
    rememberChannel(start_idx)
    guideFresh = false
    if r.guide <> invalid then
        applyGuide(r.guide)
        age = nowEpoch() - Int(Val(regRead("gTs", "0")))
        guideFresh = (age >= 0 and age < 10800)
    end if
    m.guide.favs = m.favs
    startFavsTask()
    ' the guide refresh is heavy: give the video a head start, and skip it if the cache is fresh
    if not guideFresh then m.guideDelay.control = "start"
    showBanner()
    launchComplete()
end sub

' ------------------------------------------------------------ launch beacon / deep links
' Tell the OS the app is ready for interaction (certification 3.2). Sent once.
sub launchComplete()
    if m.launchDone then return
    m.launchDone = true
    m.top.signalBeacon("AppLaunchComplete")
end sub

' contentId is a channel number ("52", "5.1"); returns -1 when there is no such channel
function linkIndex(id as String) as Integer
    for i = 0 to m.channels.Count() - 1
        if m.channels[i].numStr = id then return i
    end for
    return -1
end function

sub onDeepLink()
    dl = m.top.deepLink
    if dl = invalid or dl.contentId = invalid then return
    id = dl.contentId.ToStr().Trim()
    if id = "" then return
    if m.channels.Count() = 0 or m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then
        ' channels not loaded yet: tune once they are (and don't keep showing the last channel)
        m.pendingLink = id
        if m.quick then
            m.quick = false
            m.video.control = "stop"
            setStatus("Loading channel " + id + " ...")
        end if
        return
    end if
    idx = linkIndex(id)
    if idx < 0 then
        showToast("No channel " + id)
        return
    end if
    ' leave whatever screen is up and go straight to playback
    if m.dlg <> invalid then
        d = m.dlg
        m.dlg = invalid
        d.close = true
    end if
    if m.fitCal.visible then
        m.fitCal.visible = false
        m.mode = m.calPrev
    end if
    if m.menu.visible then m.menu.callFunc("closeMenu")
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if m.mode = "ondemand" then closeOnDemand()
    if m.mode = "vod" then vodLeave()
    m.mode = "live"
    m.top.setFocus(true)
    commitChannel(idx)
    playChannel(idx)
    showBanner()
end sub

' ------------------------------------------------------------ guide (background)
sub startGuideTask()
    keys = []
    for i = 0 to m.channels.Count() - 1
        ch = m.channels[i]
        keys.Push({ n: ch.numStr, id: LCase(ch.tvgId), name: LCase(ch.name), tvgName: LCase(ch.tvgName) })
    end for
    m.guideLoading = true
    m.guideTask = CreateObject("roSGNode", "LoadTask")
    m.guideTask.mode = "guide"
    m.guideTask.baseUrl = m.base
    m.guideTask.refreshCache = m.fromCache
    m.guideTask.chanKeys = keys
    m.guideTask.observeField("result", "onGuideResult")
    m.guideTask.control = "RUN"
end sub

' guideByNum = { "<channel number>": [programs] }  ->  channels + guide view
function applyGuide(guideByNum as Object) as Integer
    numToIdx = {}
    for i = 0 to m.channels.Count() - 1
        numToIdx[m.channels[i].numStr] = i
    end for
    idxGuide = {}
    n = 0
    for each num in guideByNum.Keys()
        idx = numToIdx[num]
        if idx <> invalid then
            m.channels[idx].programs = guideByNum[num]
            idxGuide[idx.ToStr()] = guideByNum[num]
            n = n + 1
        end if
    end for
    m.epgCount = n
    m.guide.guideData = idxGuide
    return n
end function

sub onGuideResult()
    r = m.guideTask.result
    m.guideLoading = false
    if r = invalid then return
    if not r.ok or r.count = 0 then
        if m.epgCount = 0 then showToast("No guide data available")
        return
    end if
    n = applyGuide(r.guide)
    regWrite("gTs", nowEpoch().ToStr())
    showToast("Guide loaded (" + n.ToStr() + " channels)")
end sub

' ============================================================ favorites
sub loadFavsCache()
    m.favs = {}
    for each n in regRead("favs", "").Split(",")
        if n <> "" then m.favs[n] = true
    end for
end sub

sub saveFavsCache()
    csv = ""
    for each k in m.favs.Keys()
        if csv <> "" then csv = csv + ","
        csv = csv + k
    end for
    regWrite("favs", csv)
end sub

sub applyFavArray(arr as Object)
    m.favs = {}
    for each n in arr
        m.favs[Str(n).Trim()] = true
    end for
    saveFavsCache()
    m.guide.favs = m.favs
    updateHudFav()
end sub

sub updateHudFav()
    if m.curIdx >= 0 and m.curIdx < m.channels.Count() then
        m.hud.isFav = (m.favs[m.channels[m.curIdx].numStr] <> invalid)
    end if
end sub

sub runFavTask(mode as String, num as String, on as Boolean)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = mode
    t.baseUrl = m.base
    t.favNumber = num
    t.favOn = on
    t.observeField("result", "onFavResult")
    m.favTasks.Push(t)
    if m.favTasks.Count() > 8 then m.favTasks.Shift()
    t.control = "RUN"
end sub

sub startFavsTask()
    runFavTask("favs", "", true)
end sub

sub onFavResult(event as Object)
    r = event.getData()
    if r = invalid then return
    if r.ok then
        applyFavArray(r.favs)
    else
        showToast("Couldn't reach TunerBox favorites")
        if m.mode <> "boot" then startFavsTask()
    end if
end sub

sub toggleFav(numStr as String)
    on = (m.favs[numStr] = invalid)
    if on then
        m.favs[numStr] = true
        showToast("Added " + numStr + " to favorites")
    else
        m.favs.Delete(numStr)
        showToast("Removed " + numStr + " from favorites")
    end if
    saveFavsCache()
    m.guide.favs = m.favs
    updateHudFav()
    runFavTask("setfav", numStr, on)
end sub

sub toggleFavCurrent()
    if m.curIdx < 0 then return
    if m.extern <> invalid then
        showToast("Favorites aren't available for this feed")
        return
    end if
    toggleFav(m.channels[m.curIdx].numStr)
    showBanner()
end sub

sub openFavorites()
    view = []
    for i = 0 to m.channels.Count() - 1
        if m.favs[m.channels[i].numStr] <> invalid then view.Push(i)
    end for
    if view.Count() = 0 then
        showToast("No favorites yet - use + FAV on a channel")
        return
    end if
    fromIdx = m.curIdx
    if m.mode = "guide" then
        fromIdx = m.guide.focusedChannel
        m.guide.callFunc("closeGuide")
    end if
    openGuide(fromIdx, view, "FAVORITES")
end sub

sub showAllChannels()
    fromIdx = m.curIdx
    if m.mode = "guide" then
        fromIdx = m.guide.focusedChannel
        m.guide.callFunc("closeGuide")
    end if
    openGuide(fromIdx, invalid, "")
end sub

sub toggleFavView()
    if m.guideTitle = "FAVORITES" then
        showAllChannels()
    else
        openFavorites()
    end if
end sub

sub showGuideMenu()
    idx = m.guide.focusedChannel
    if idx < 0 or idx >= m.channels.Count() then return
    ch = m.channels[idx]
    favText = "Add to favorites"
    if m.favs[ch.numStr] <> invalid then favText = "Remove from favorites"
    viewText = "Show favorites only"
    if m.guideTitle = "FAVORITES" then viewText = "Show all channels"
    showDialog("gmenu", ch.numStr + " " + ch.name, ["Guide options"], [favText, viewText, "Search", "Sports", "On Demand", "Main menu", "Close"], ["fav", "favview", "search", "sports", "ondemand", "mainmenu", "close"])
end sub

sub runGuideMenuAction(action as String)
    if action = "fav" then
        idx = m.guide.focusedChannel
        if idx >= 0 and idx < m.channels.Count() then toggleFav(m.channels[idx].numStr)
    else if action = "favview" then
        toggleFavView()
    else if action = "ondemand" then
        openOnDemand({})
    else if action = "search" then
        promptSearch()
    else if action = "sports" then
        openSports()
    else if action = "mainmenu" then
        showMenu()
    end if
end sub

' ============================================================ playback
sub playChannel(idx as Integer)
    if idx < 0 or idx >= m.channels.Count() then return
    ch = m.channels[idx]
    c = CreateObject("roSGNode", "ContentNode")
    c.url = streamUrl(ch)
    c.title = ch.name
    c.live = true
    c.streamFormat = streamFmt(ch.url)
    m.extern = invalid
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.playIdx = idx
    m.retries = 0
    m.underruns = 0
end sub

' 720p compatibility mode: applies to ALL channels (default ON, toggle in MENU)
function isCompat(numStr as String) as Boolean
    return regRead("compat720", "1") = "1"
end function

function streamUrl(ch as Object) as String
    u = ch.url
    if isCompat(ch.numStr) then
        sep = "?"
        if Instr(1, u, "?") > 0 then sep = "&"
        u = u + sep + "mode=roku720"
    end if
    return u
end function

sub toggleCompat()
    if isCompat("") then
        regWrite("compat720", "0")
        showToast("720p mode OFF (original quality)")
    else
        regWrite("compat720", "1")
        showToast("720p mode ON")
    end if
    if m.extern <> invalid then
        playExternal(m.extern)
    else if m.playIdx >= 0 then
        playChannel(m.playIdx)
    end if
end sub

function streamFmt(url as String) as String
    f = regRead("fmt", "auto")
    if f = "hls" or f = "ts" then return f
    if Instr(1, LCase(url), ".m3u8") > 0 then return "hls"
    return "ts"
end function

' make idx the "real" channel (as opposed to a guide preview)
sub commitChannel(idx as Integer)
    if idx <> m.curIdx then
        m.lastIdx = m.curIdx
        m.curIdx = idx
    end if
    rememberChannel(idx)
end sub

sub changeChannel(delta as Integer)
    n = m.channels.Count()
    if n = 0 then return
    idx = (m.curIdx + delta + n) mod n
    commitChannel(idx)
    playChannel(idx)
    showBanner()
end sub

sub goLast()
    if m.lastIdx < 0 then return
    idx = m.lastIdx
    commitChannel(idx)
    playChannel(idx)
    showBanner()
end sub

sub tuneNumber(numStr as String)
    target = Val(numStr)
    for i = 0 to m.channels.Count() - 1
        if m.channels[i].numVal >= target then
            commitChannel(i)
            playChannel(i)
            showBanner()
            return
        end if
    end for
    showToast("No channel " + numStr)
end sub

sub onVideoState()
    st = m.video.state
    if m.vod <> invalid then
        vodState(st)
        return
    end if
    if st = "playing" then
        m.retries = 0
    else if st = "error" or st = "finished" then
        if m.retries < 3 then
            m.retries = m.retries + 1
            m.retryTimer.control = "stop"
            m.retryTimer.control = "start"
        else
            showToast("Channel unavailable")
        end if
    end if
end sub

sub onStreamInfo()
    si = m.video.streamInfo
    if si <> invalid and si.isUnderrun = true then
        m.underruns = m.underruns + 1
        cn = "?"
        if m.extern <> invalid then
            cn = m.extern.num
        else if m.playIdx >= 0 and m.playIdx < m.channels.Count() then
            cn = m.channels[m.playIdx].numStr
        end if
        print "[TunerBox] underrun #" + m.underruns.ToStr() + " ch=" + cn + " measured=" + Str(si.measuredBitrate) + " stream=" + Str(si.streamBitrate)
    end if
end sub

sub showStreamStats()
    v = m.video
    if m.extern <> invalid then
        showDialog("info", "Stream stats", [m.extern.num + " " + m.extern.name, "State: " + v.state, "Video: " + v.videoFormat + "    Audio: " + v.audioFormat, m.extern.url], ["OK"], ["close"])
        return
    end if
    if m.playIdx < 0 then return
    ch = m.channels[m.playIdx]
    si = v.streamInfo
    lines = [ch.numStr + " " + ch.name]
    lines.Push("State: " + v.state + "    format: " + streamFmt(ch.url))
    lines.Push("Video: " + v.videoFormat + "    Audio: " + v.audioFormat)
    if si <> invalid then
        lines.Push("Stream bitrate: " + Str(si.streamBitrate \ 1000) + " kbps    measured: " + Str(si.measuredBitrate \ 1000) + " kbps")
    end if
    lines.Push("Buffer underruns this channel: " + m.underruns.ToStr())
    lines.Push("Time to start: " + Str(v.timeToStartStreaming) + " s")
    lines.Push(streamUrl(ch))
    showDialog("info", "Stream stats", lines, ["OK"], ["close"])
end sub

sub onRetryTimer()
    if m.vod <> invalid then
        if m.mode = "vod" then vodStart(vodPos())
        return
    end if
    if m.extern <> invalid then
        r = m.retries
        playExternal(m.extern)
        m.retries = r
    else if m.playIdx >= 0 then
        r = m.retries
        playChannel(m.playIdx)
        m.retries = r
    end if
end sub

sub setPreviewSize(preview as Boolean)
    pr = m.guide.previewRect
    if preview and pr <> invalid and pr.Count() = 4 then
        ' the guide is laid out in screen pixels (not scaled) and reports its preview hole
        m.video.translation = [pr[0], pr[1]]
        m.video.width = pr[2]
        m.video.height = pr[3]
    else
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
    end if
end sub

sub toggleMute()
    m.hud.muted = not m.hud.muted
    m.video.mute = m.hud.muted
    if m.hud.muted then
        showToast("Muted")
    else
        showToast("Sound on")
    end if
end sub

' ============================================================ banner / toast
function bannerInfo(ch as Object) as Object
    t = nowEpoch()
    info = { num: ch.numStr, name: ch.name, logo: ch.logo, title: ch.name, subtitle: "", times: "", pct: 0.0, nextText: "", rating: "" }
    p = progAt(ch, t)
    if p <> invalid then
        info.title = p.title
        info.subtitle = subLine(p)
        info.times = fmtClock(p.start) + dashSep() + fmtClock(p.stop)
        info.pct = (t - p.start) / (p.stop - p.start)
        info.rating = p.rating
        nx = progAfter(ch, p.stop)
        if nx <> invalid then info.nextText = "Next: " + fmtClock(nx.start) + "  " + nx.title
    else
        if m.guideLoading then
            info.subtitle = "Guide loading..."
        else
            info.subtitle = "No guide data"
        end if
    end if
    return info
end function

sub showBanner()
    if m.extern <> invalid then
        m.hud.callFunc("showBanner", externInfo())
        return
    end if
    if m.curIdx < 0 then return
    updateHudFav()
    m.hud.callFunc("showBanner", bannerInfo(m.channels[m.curIdx]))
end sub

sub showToast(text as String)
    m.toastLbl.text = text
    bb = m.toastLbl.boundingRect()
    x = Int((1920 - bb.width) / 2)
    m.toastLbl.translation = [x, 740]
    m.toastBg.translation = [x - 32, 726]
    m.toastBg.width = bb.width + 64
    m.toastBg.height = bb.height + 28
    m.toast.visible = true
    m.toastTimer.control = "stop"
    m.toastTimer.control = "start"
end sub

sub onToastTimer()
    m.toast.visible = false
end sub

' ============================================================ keys
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.mode = "fitcal" then return fitCalKey(key)

    if m.mode = "needhost" or m.mode = "error" then
        if key = "OK" then
            promptHost()
            return true
        else if key = "options" and m.mode = "error" then
            loadAll()
            return true
        end if
        return false
    end if

    if m.mode = "vod" then return vodKey(key)

    if m.mode <> "live" then return false

    if key = "up" then
        changeChannel(1)
    else if key = "down" then
        changeChannel(-1)
    else if key = "OK" then
        m.hud.callFunc("showBar", bannerInfo(m.channels[m.curIdx]))
    else if key = "left" then
        showBanner()
    else if key = "right" or key = "fastforward" then
        openGuide(m.curIdx, invalid, "")
    else if key = "replay" then
        goLast()
    else if key = "options" then
        showMenu()
    else if key = "play" then
        toggleMute()
    else if key = "back" then
        confirmExit()
    else if Left(key, 4) = "Lit_" then
        return liveLit(Mid(key, 5))
    else
        return false
    end if
    return true
end function

function liveLit(ch as String) as Boolean
    lc = LCase(ch)
    if Len(lc) = 1 and lc >= "0" and lc <= "9" then
        if Len(m.digits) >= 5 then m.digits = ""
        m.digits = m.digits + lc
        showToast("Channel " + m.digits)
        m.entryTimer.control = "stop"
        m.entryTimer.control = "start"
    else if lc = "g" then
        openGuide(m.curIdx, invalid, "")
    else if lc = "i" then
        showBanner()
    else if lc = "l" then
        goLast()
    else if lc = "m" then
        toggleMute()
    else if lc = "/" then
        promptSearch()
    else if lc = "t" then
        openSports()
    else if lc = "o" then
        openOnDemand({})
    else if lc = "f" or lc = "*" then
        toggleFavCurrent()
    else if lc = "v" then
        openFavorites()
    else
        return false
    end if
    return true
end function

sub onEntryTimer()
    d = m.digits
    m.digits = ""
    if d <> "" then tuneNumber(d)
end sub

' ============================================================ HUD buttons
sub onHudButton()
    id = m.hud.buttonSelected
    if id = "chup" then
        changeChannel(1)
    else if id = "chdn" then
        changeChannel(-1)
    else if id = "info" then
        showBanner()
    else if id = "last" then
        goLast()
    else if id = "mute" then
        toggleMute()
    else if id = "guide" then
        openGuide(m.curIdx, invalid, "")
    else if id = "search" then
        m.hud.callFunc("hideAll")
        promptSearch()
    else if id = "sports" then
        openSports()
    else if id = "ondemand" then
        openOnDemand({})
    else if id = "favs" then
        openFavorites()
    else if id = "fav" then
        toggleFavCurrent()
    else if id = "dvr" then
        m.hud.callFunc("hideAll")
        showDvr()
    else if id = "menu" then
        m.hud.callFunc("hideAll")
        showMenu()
    end if
end sub

' ============================================================ guide
sub openGuide(startIdx as Integer, view as Object, title as String)
    m.hud.callFunc("hideAll")
    m.mode = "guide"
    m.guideTitle = title
    setPreviewSize(true)
    info = { chIdx: startIdx, title: title }
    if view <> invalid then info.view = view
    m.guide.callFunc("openGuide", info)
end sub

sub closeGuide()
    m.guide.callFunc("closeGuide")
    setPreviewSize(false)
    m.mode = "live"
    m.guideTitle = ""
    m.top.setFocus(true)
end sub

' Back from the guide: return to the channel that was already playing, nothing else
sub onGuideExit()
    closeGuide()
    if m.extern = invalid and m.playIdx <> m.curIdx then playChannel(m.curIdx)
end sub

sub onGuideTune()
    idx = m.guide.tuneRequest
    closeGuide()
    commitChannel(idx)
    if m.playIdx <> idx then playChannel(idx)
    showBanner()
end sub

sub onGuidePreview()
    idx = m.guide.previewRequest
    ' preview stays on the current channel while browsing the guide (no retune)
end sub

sub onGuideMenu()
    kind = m.guide.menuRequest
    if kind = "search" then
        promptSearch()
    else if kind = "sports" then
        openSports()
    else if kind = "fav" then
        idx = m.guide.focusedChannel
        if idx >= 0 and idx < m.channels.Count() then toggleFav(m.channels[idx].numStr)
    else if kind = "favview" then
        toggleFavView()
    else
        showGuideMenu()
    end if
end sub

sub onGuideOptions()
    req = m.guide.optionsRequest
    if req.record = true then
        dvrRecord(req.chIdx, req.prog)
        return
    end if
    ch = m.channels[req.chIdx]
    title = ch.name
    msg = [ch.numStr + " " + ch.name]
    buttons = ["Watch channel"]
    actions = ["watch"]
    if req.prog <> invalid then
        title = req.prog.title
        msg = [fmtDay(req.prog.start) + "  " + fmtClock(req.prog.start) + dashSep() + fmtClock(req.prog.stop), ch.numStr + " " + ch.name]
        buttons.Push("Record")
        actions.Push("record")
    end if
    buttons.Push("Jump to channel #")
    actions.Push("jump")
    buttons.Push("Cancel")
    actions.Push("cancel")
    m.optReq = req
    showDialog("opts", title, msg, buttons, actions)
end sub

' ------------------------------------------------------------ filtered guides
' ============================================================ Sports & PPV
sub runSportsTask(mode as String, group as String)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = mode
    t.baseUrl = m.base
    t.sportsGroup = group
    t.observeField("result", "onSportsTaskResult")
    m.sportsTasks.Push(t)
    if m.sportsTasks.Count() > 12 then m.sportsTasks.Shift()
    t.control = "RUN"
end sub

sub openSports()
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if m.mode = "guide" then closeGuide()
    if m.mode = "search" then closeSearch()
    m.hud.callFunc("hideAll")
    m.mode = "sports"
    m.sportsGroupName = ""
    m.sports.callFunc("openSports")
    runSportsTask("sports", "")
    runGamesTask()
end sub

' live game schedule for the leagues picked in MENU > Live sports leagues, matched to the guide
sub runGamesTask()
    sel = sportsLeagueSel()
    if sel = "" then
        m.sports.games = { ok: true, leagues: "", games: [] }
        return
    end if
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "espn"
    t.baseUrl = m.base
    t.hideUnmapped = m.hideUnmapped
    t.leagues = sel
    t.observeField("result", "onSportsTaskResult")
    m.sportsTasks.Push(t)
    if m.sportsTasks.Count() > 12 then m.sportsTasks.Shift()
    t.control = "RUN"
end sub

function leagueNames(sel as String) as String
    out = []
    for each lg in sportsLeagues()
        if leagueOn(sel, lg.id) then out.Push(lg.abbr)
    end for
    return out.Join(" " + Chr(183) + " ")
end function

sub closeSports()
    m.checkTimer.control = "stop"
    m.sports.callFunc("closeSports")
    m.mode = "live"
    m.top.setFocus(true)
end sub

sub onSportsTaskResult(event as Object)
    t = event.getRoSGNode()
    r = event.getData()
    if m.mode <> "sports" then return
    md = t.mode
    if md = "sports" then
        if r.ok = true then
            m.sports.data = r.data
        else if sportsLeagueSel() <> "" then
            ' live games can still be listed without the TunerBox sports feed
            m.sports.data = { on_now: [], upcoming: [], channels: [], groups: [] }
            showToast("Could not load Sports & PPV from TunerBox")
        else
            m.sports.message = "Could not load Sports & PPV from TunerBox. Press Back."
        end if
    else if md = "espn" then
        sel = t.leagues
        m.sports.games = { ok: (r.ok = true), leagues: sel, leagueNames: leagueNames(sel), hasGuide: (r.hasGuide = true), showUnmatched: (regRead("sportsUnmatched", "1") = "1"), games: r.games }
    else if md = "sgroup" then
        if r.ok = true then
            m.sports.message = ""
            m.sports.group = r.data
        else
            showToast("Could not load that group")
        end if
    else if md = "scheck" then
        if r.ok = true then
            m.checkTimer.control = "stop"
            m.checkTimer.control = "start"
            runSportsTask("scheckstate", "")
        else
            showToast("Could not start the live check")
        end if
    else if md = "scheckstate" then
        st = r.data
        if r.ok = true and st <> invalid then
            m.sports.checkState = st
            if st.running <> true then
                m.checkTimer.control = "stop"
                if m.sportsGroupName <> "" then runSportsTask("sgroup", m.sportsGroupName)
            end if
        end if
    end if
end sub

sub onCheckTimer()
    if m.mode <> "sports" then
        m.checkTimer.control = "stop"
        return
    end if
    runSportsTask("scheckstate", "")
end sub

function chIndexByNum(num as String) as Integer
    for i = 0 to m.channels.Count() - 1
        if m.channels[i].numStr = num then return i
    end for
    return -1
end function

sub onSportsRequest()
    req = m.sports.request
    if req = invalid then return
    ty = req.type
    if ty = "close" then
        closeSports()
    else if ty = "program" then
        p = req.p
        if p = invalid or p.ch = invalid then return
        num = numToStr(p.ch.number)
        if p.start > nowEpoch() + 60 then
            m.recReq = { num: num, start: p.start, title: p.title }
            showDialog("sprec", p.title, [fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop), num + " " + p.ch.name, "Hasn't started yet."], ["Record", "Cancel"], ["record", "cancel"])
        else
            watchChannelNum(num, p.ch.name)
        end if
    else if ty = "game" then
        openGame(req.g)
    else if ty = "channel" then
        watchChannelNum(numToStr(req.ch.number), req.ch.name)
    else if ty = "openGroup" then
        m.sportsGroupName = req.name
        m.sports.message = "Loading " + req.name + "..."
        runSportsTask("sgroup", req.name)
    else if ty = "feed" then
        watchFeed(req.f)
    else if ty = "check" then
        m.sportsGroupName = req.name
        runSportsTask("scheck", req.name)
    end if
end sub

 ' a game from the live schedule: watch / record on a channel the guide matched, or explain it isn't in the guide
sub openGame(g as Object)
    chans = g.chans
    started = (g.state = "in" or g.start <= nowEpoch() + 60)
    msg = [g.league + dotSep() + fmtDay(g.start) + "  " + fmtClock(g.start)]
    st = g.score
    if g.state = "in" and g.detail <> "" then
        if st <> "" then st = st + dotSep()
        st = st + g.detail
    end if
    if st <> "" then msg.Push(st)
    if g.nets <> "" then msg.Push("TV: " + g.nets)
    if chans.Count() = 0 then
        msg.Push("This game wasn't found in your channel guide.")
        showDialog("info", g.title, msg, ["OK"], ["close"])
        return
    end if
    if started and chans.Count() = 1 then
        watchChannelNum(chans[0].number, chans[0].name)
        return
    end if
    if not started then msg.Push("Hasn't started yet.")
    buttons = []
    actions = []
    n = chans.Count()
    if n > 6 then n = 6
    for i = 0 to n - 1
        c = chans[i]
        lbl = c.number + " " + c.name
        if started then
            buttons.Push("Watch " + lbl)
            actions.Push("w" + i.ToStr())
        else
            buttons.Push("Record " + lbl + "  (" + fmtClock(c.start) + ")")
            actions.Push("r" + i.ToStr())
        end if
    end for
    buttons.Push("Cancel")
    actions.Push("cancel")
    m.gameReq = g
    showDialog("game", g.title, msg, buttons, actions)
end sub

function numToStr(v as Dynamic) as String
    t = Type(v)
    if t = "String" or t = "roString" then return v
    if t = "Float" or t = "roFloat" or t = "Double" then return Str(Int(v)).Trim()
    return Str(v).Trim()
end function

' tune a TunerBox channel number: use the loaded list when it's there, otherwise stream it directly
sub watchChannelNum(num as String, name as String)
    idx = chIndexByNum(num)
    closeSports()
    if idx >= 0 then
        commitChannel(idx)
        playChannel(idx)
        showBanner()
    else
        u = m.base + "/api/stream/" + num
        playExternal({ num: num, name: name, title: name, url: u })
        showBanner()
    end if
end sub

sub watchFeed(f as Object)
    if f.slot = true and f.status <> "ok" then
        showToast("That slot is empty or the event has ended")
        return
    end if
    esc = urlEncode(f.key)
    u = m.base + "/api/feed/stream?key=" + esc
    closeSports()
    playExternal({ num: "EVENT", name: f.group, title: f.name, url: u })
    showBanner()
end sub

sub playExternal(ex as Object)
    m.extern = ex
    u = ex.url
    if isCompat("") then
        sep = "?"
        if Instr(1, u, "?") > 0 then sep = "&"
        u = u + sep + "mode=roku720"
    end if
    c = CreateObject("roSGNode", "ContentNode")
    c.url = u
    c.title = ex.title
    c.live = true
    c.streamFormat = "ts"
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.playIdx = -1
    m.retries = 0
    m.underruns = 0
end sub

function externInfo() as Object
    return { num: m.extern.num, name: m.extern.name, logo: "", title: m.extern.title, subtitle: "", times: "", pct: 0.0, nextText: "", rating: "" }
end function


' ============================================================ search
sub openSearch()
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if m.mode = "search" then return
    m.searchFrom = ""
    if m.mode = "guide" then
        m.searchFrom = "guide"
        closeGuide()
    else if m.mode = "sports" then
        closeSports()
    end if
    m.hud.callFunc("hideAll")
    m.mode = "search"
    m.search.callFunc("openSearch")
end sub

sub closeSearch()
    m.search.callFunc("closeSearch")
    m.mode = "live"
    m.top.setFocus(true)
end sub

' ask TunerBox (GET /api/search: every channel, 7 days of guide, event feeds);
' fall back to the locally loaded channel list if the server doesn't answer
sub onSearchQuery()
    q = m.search.query
    if q.Trim() = "" then
        m.search.results = { query: q, items: [] }
        return
    end if
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "search"
    t.baseUrl = m.base
    t.searchQuery = q
    t.observeField("result", "onSearchResult")
    m.sportsTasks.Push(t)
    if m.sportsTasks.Count() > 12 then m.sportsTasks.Shift()
    t.control = "RUN"
end sub

sub onSearchResult(event as Object)
    r = event.getData()
    if m.mode <> "search" or r = invalid then return
    if r.query <> m.search.query then return
    if r.ok <> true then
        m.search.results = { query: r.query, items: localSearch(r.query) }
        return
    end if
    d = r.data
    items = []
    for each c in d.channels
        nm = c.name
        if nm = invalid or nm = "" then nm = c.label
        rt = ""
        if c.now <> invalid then rt = c.now
        items.Push({ k: "ch", num: numToStr(c.number), name: nm, title: "", sub: "", right: rt, start: 0, stop: 0 })
    end for
    for each p in d.programs
        if p = invalid or p.ch = invalid then continue for
        nm = p.ch.name
        if nm = invalid or nm = "" then nm = p.ch.label
        sb = ""
        if p.subtitle <> invalid then sb = p.subtitle
        items.Push({ k: "pg", num: numToStr(p.ch.number), name: nm, title: p.title, sub: sb, right: "", start: p.start, stop: p.stop })
    end for
    if d.feeds <> invalid then
        for each f in d.feeds
            items.Push({ k: "feed", num: "", name: "", title: f.name, sub: "", right: f.group, start: 0, stop: 0, f: f })
        end for
    end if
    if Type(d.vod) = "roArray" then
        for each v in d.vod
            items.Push(vodSearchRow(v))
        end for
    end if
    m.search.results = { query: r.query, items: items }
end sub

function localSearch(q as String) as Object
    ql = LCase(q.Trim())
    items = []
    t = nowEpoch()
    progs = []
    for i = 0 to m.channels.Count() - 1
        ch = m.channels[i]
        if Instr(1, LCase(ch.name), ql) > 0 then
            items.Push({ k: "ch", num: ch.numStr, name: ch.name, title: "", sub: "", right: "", start: 0, stop: 0 })
        end if
        if ch.programs <> invalid and Len(ql) >= 2 and progs.Count() < 300 then
            for each p in ch.programs
                if p.stop > t and Instr(1, LCase(p.title), ql) > 0 then
                    progs.Push({ k: "pg", num: ch.numStr, name: ch.name, title: p.title, sub: "", right: "", start: p.start, stop: p.stop })
                end if
            end for
        end if
        if items.Count() >= 150 then exit for
    end for
    progs.SortBy("start")
    for each p in progs
        if items.Count() >= 200 then exit for
        items.Push(p)
    end for
    return items
end function

sub onSearchRequest()
    req = m.search.request
    if req = invalid then return
    ty = req.type
    if ty = "close" then
        closeSearch()
        if m.searchFrom = "guide" then openGuide(m.curIdx, invalid, "")
    else if ty = "channel" then
        searchWatch(req.num, req.name)
    else if ty = "vod" then
        v = req.v
        closeSearch()
        if anyStr(v.kind) = "series" then
            openOnDemand({ showId: v.id })
        else if anyStr(v.kind) = "episode" then
            openOnDemand({ episode: v })
        else
            openOnDemand({ movieId: v.id })
        end if
    else if ty = "feed" then
        f = req.f
        if f.slot = true and f.status <> "ok" then
            showToast("That slot is empty or the event has ended")
            return
        end if
        closeSearch()
        playExternal({ num: "EVENT", name: f.group, title: f.name, url: m.base + "/api/feed/stream?key=" + urlEncode(f.key) })
        showBanner()
    else if ty = "program" then
        p = req.prog
        if p.start > nowEpoch() + 60 then
            m.srReq = { num: req.num, name: req.name, start: p.start, title: p.title }
            showDialog("srec", p.title, [fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop), req.num + " " + req.name, "Hasn't started yet."], ["Record", "Watch channel now", "Cancel"], ["record", "watch", "cancel"])
        else
            searchWatch(req.num, req.name)
        end if
    end if
end sub

' tune a channel number: from the loaded list if it's there, otherwise stream it straight from TunerBox
sub searchWatch(num as String, name as String)
    closeSearch()
    idx = chIndexByNum(num)
    if idx >= 0 then
        commitChannel(idx)
        if m.playIdx <> idx or m.extern <> invalid then playChannel(idx)
    else
        playExternal({ num: num, name: name, title: name, url: m.base + "/api/stream/" + num })
    end if
    showBanner()
end sub

' ============================================================ DVR (hook point)
' TODO: wire these to your DVR / recording API.
sub dvrRecord(chIdx as Integer, prog as Object)
    if prog = invalid then
        showToast("Nothing to record in this slot")
        return
    end if
    if chIdx < 0 or chIdx >= m.channels.Count() then return
    dvrRecordRaw(m.channels[chIdx].numStr, prog.start, prog.title)
end sub

' schedule a recording on TunerBox (POST /api/recordings {number, start})
sub dvrRecordRaw(num as String, startAt as Integer, title as String)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "record"
    t.baseUrl = m.base
    t.recNumber = num
    t.recStart = Str(startAt).Trim()
    t.observeField("result", "onRecordResult")
    m.sportsTasks.Push(t)
    if m.sportsTasks.Count() > 12 then m.sportsTasks.Shift()
    m.recTitle = title
    t.control = "RUN"
end sub

sub onRecordResult(event as Object)
    r = event.getData()
    if r <> invalid and r.ok = true then
        showToast("Recording scheduled: " + m.recTitle)
    else
        showToast("Could not schedule recording")
    end if
end sub

sub showDvr()
    showDialog("info", "DVR", ["DVR isn't connected to a backend yet.", "Implement dvrRecord() in MainScene.brs to schedule recordings."], ["OK"], ["close"])
end sub

' ============================================================ dialogs
sub showDialog(kind as String, title as String, message as Object, buttons as Object, actions as Object)
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = title
    dlg.message = message
    dlg.buttons = buttons
    m.dlgKind = kind
    m.dlgActions = actions
    m.dlg = dlg
    dlg.observeFieldScoped("buttonSelected", "onDlgButton")
    dlg.observeFieldScoped("wasClosed", "onDlgClosed")
    m.top.dialog = dlg
end sub

sub showKeyboard(kind as String, title as String, message as Object, initial as String)
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = title
    dlg.message = message
    dlg.text = initial
    dlg.buttons = ["OK", "Cancel"]
    m.dlgKind = kind
    m.dlgActions = ["ok", "cancel"]
    m.dlg = dlg
    dlg.observeFieldScoped("buttonSelected", "onDlgButton")
    dlg.observeFieldScoped("wasClosed", "onDlgClosed")
    m.top.dialog = dlg
end sub

sub onDlgClosed(event as Object)
    d = event.getRoSGNode()
    if m.dlg <> invalid and m.dlg.isSameNode(d) then
        m.dlg = invalid
        restoreFocus()
        if m.mode = "needhost" or m.mode = "error" then m.top.setFocus(true)
    end if
end sub

sub restoreFocus()
    if m.menu.visible then
        m.menu.setFocus(true)
    else if m.mode = "guide" then
        m.guide.setFocus(true)
    else if m.mode = "sports" then
        m.sports.setFocus(true)
    else if m.mode = "search" then
        m.search.setFocus(true)
    else if m.mode = "ondemand" then
        m.od.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub onDlgButton()
    dlg = m.dlg
    idx = dlg.buttonSelected
    action = ""
    if idx >= 0 and idx < m.dlgActions.Count() then action = m.dlgActions[idx]
    kind = m.dlgKind
    txt = ""
    if kind = "host" or kind = "jump" or kind = "vodsearch" then txt = dlg.text
    dlg.close = true

    if kind = "host" then
        if action = "ok" and txt.Trim() <> "" then
            regWrite("host", txt.Trim())
            regWrite("lastUrl", "")
            m.quick = false
            loadAll()
        end if
    else if kind = "jump" then
        if action = "ok" and txt.Trim() <> "" then
            if m.mode = "guide" then
                m.guide.callFunc("jumpToNumber", txt.Trim())
            else
                tuneNumber(txt.Trim())
            end if
        end if
    else if kind = "exit" then
        if action = "exit" then m.top.exitApp = true
    else if kind = "opts" then
        if action = "watch" then
            onGuideTuneIdx(m.optReq.chIdx)
        else if action = "record" then
            dvrRecord(m.optReq.chIdx, m.optReq.prog)
        else if action = "jump" then
            promptJump()
        end if
    else if kind = "srec" then
        if m.srReq <> invalid then
            if action = "record" then
                dvrRecordRaw(m.srReq.num, m.srReq.start, m.srReq.title)
            else if action = "watch" then
                searchWatch(m.srReq.num, m.srReq.name)
            end if
        end if
        m.srReq = invalid
    else if kind = "game" then
        g = m.gameReq
        m.gameReq = invalid
        if g <> invalid and action <> "cancel" and action <> "" then
            i = Int(Val(Mid(action, 2)))
            if i >= 0 and i < g.chans.Count() then
                c = g.chans[i]
                if Left(action, 1) = "w" then
                    watchChannelNum(c.number, c.name)
                else
                    dvrRecordRaw(c.number, c.start, g.title)
                end if
            end if
        end if
    else if kind = "sprec" then
        if action = "record" and m.recReq <> invalid then dvrRecordRaw(m.recReq.num, m.recReq.start, m.recReq.title)
        m.recReq = invalid
    else if kind = "vod" then
        if m.mode = "ondemand" then m.od.dialogAction = action
    else if kind = "vodsearch" then
        if action = "ok" and txt.Trim() <> "" and m.mode = "ondemand" then m.od.searchText = txt.Trim()
    else if kind = "vodnext" then
        vodNextAction(action)
    else if kind = "menu" then
        runMenuAction(action)
    else if kind = "gmenu" then
        runGuideMenuAction(action)
    end if
end sub

sub onGuideTuneIdx(idx as Integer)
    closeGuide()
    commitChannel(idx)
    if m.playIdx <> idx then playChannel(idx)
    showBanner()
end sub

sub promptHost()
    showKeyboard("host", "TunerBox server", ["Enter the IP address of the machine running TunerBox.", "Example: 192.168.1.50  (port 8642 is assumed)"], regRead("host", ""))
end sub

sub promptSearch()
    openSearch()
end sub

sub promptJump()
    showKeyboard("jump", "Jump to channel", ["Channel number"], "")
end sub

sub confirmExit()
    showDialog("exit", "Exit TunerBox TV?", ["Stop watching and close the app?"], ["Exit", "Keep watching"], ["exit", "cancel"])
end sub

' ============================================================ menu
function hideLabel() as String
    if m.hideUnmapped then return "ON"
    return "OFF"
end function

function compatLabel() as String
    if isCompat("") then return "ON"
    return "OFF"
end function

' ============================================================ screen fit (overscan)
' Percent of the screen trimmed from EACH edge; UI is scaled (the guide re-flows) into the remaining safe area.
' Full-screen video is never scaled (overscan on video is normal: broadcast content is framed
' so the cropped edges don't matter, but the guide is drawn edge to edge, so it does).
function fitOptions() as Object
    opts = []
    for t = 0 to 80 step 5   ' 0.0% .. 8.0% in 0.5% steps
        opts.Push(fitStr(t / 10.0))
    end for
    return opts
end function

function fitStr(v as Float) as String
    tenths = Int(v * 10 + 0.5)
    s = Int(tenths / 10).ToStr()
    if tenths mod 10 <> 0 then s = s + "." + (tenths mod 10).ToStr()
    return s
end function

function fitLabel() as String
    return regRead("fit", "2.5") + "%"
end function

sub applyScreenFit()
    pct = Val(regRead("fit", "2.5")) / 100.0
    m.fitScale = 1.0 - 2.0 * pct
    m.fitOff = [Int(1920 * pct + 0.5), Int(1080 * pct + 0.5)]
    for each n in [m.hud, m.sports, m.search, m.od, m.menu, m.statusGroup, m.toast]
        n.scale = [m.fitScale, m.fitScale]
        n.translation = m.fitOff
    end for
    ' the guide re-flows into the safe area at full size instead of being shrunk
    m.guide.safe = [m.fitOff[0], m.fitOff[1], m.fitOff[0], m.fitOff[1]]
    if m.mode = "guide" or (m.mode = "fitcal" and m.calPrev = "guide") then setPreviewSize(true)
    if m.mode = "ondemand" then setOdPreview()
    if m.fitCal.visible then drawFitFrame()
end sub

sub stepScreenFit(dir as Integer)
    opts = fitOptions()
    cur = Val(regRead("fit", "2.5"))
    idx = 0
    for i = 0 to opts.Count() - 1
        if Abs(Val(opts[i]) - cur) < 0.01 then idx = i
    end for
    idx = idx + dir
    if idx < 0 then idx = 0
    if idx > opts.Count() - 1 then idx = opts.Count() - 1
    regWrite("fit", opts[idx])
    applyScreenFit()
end sub

sub drawFitFrame()
    t = 6   ' frame thickness
    x = m.fitOff[0]
    y = m.fitOff[1]
    w = 1920 - 2 * x
    h = 1080 - 2 * y
    setRect(m.fitCal.findNode("calTop"), x, y, w, t)
    setRect(m.fitCal.findNode("calBottom"), x, y + h - t, w, t)
    setRect(m.fitCal.findNode("calLeft"), x, y, t, h)
    setRect(m.fitCal.findNode("calRight"), x + w - t, y, t, h)
    m.fitCal.findNode("calValue").text = fitLabel() + " per edge"
end sub

sub setRect(r as Object, x, y, w, h)
    r.translation = [x, y]
    r.width = w
    r.height = h
end sub

sub openFitCal()
    m.calPrev = m.mode
    m.mode = "fitcal"
    m.toast.visible = false
    m.fitCal.visible = true
    drawFitFrame()
    m.top.setFocus(true)
end sub

sub closeFitCal()
    m.fitCal.visible = false
    m.mode = m.calPrev
    showToast("Screen fit: " + fitLabel() + " per edge")
    restoreFocus()
end sub

function fitCalKey(key as String) as Boolean
    if key = "right" or key = "up" then
        stepScreenFit(1)
    else if key = "left" or key = "down" then
        stepScreenFit(-1)
    else if key = "OK" or key = "back" or key = "options" then
        closeFitCal()
    end if
    return true
end function

function menuItems() as Object
    return [
        { id: "server", label: "Change server address" },
        { id: "reload", label: "Reload channels and guide" },
        { id: "favorites", label: "Favorites" },
        { id: "jump", label: "Jump to channel #" },
        { id: "fmt", label: "Stream format", value: UCase(regRead("fmt", "auto")) },
        { id: "compat", label: "720p mode (all channels)", value: compatLabel() },
        { id: "hideun", label: "Hide unmapped (20000+)", value: hideLabel() },
        { id: "fit", label: "Screen fit (overscan)", value: fitLabel() },
        { id: "leagues", label: "Live sports leagues", value: leaguesLabel() },
        { id: "stats", label: "Stream stats" },
        { id: "about", label: "About" },
        { id: "close", label: "Close" }
    ]
end function

sub showMenu()
    m.hud.callFunc("hideAll")
    m.menuPage = "main"
    m.menu.heading = "Menu"
    m.menu.items = menuItems()
    m.menu.subtitle = "Server: " + m.base
    m.menu.callFunc("openMenu")
end sub

' ------------------------------------------------------------ live sports leagues (settings page inside the menu)
function leaguesLabel() as String
    sel = sportsLeagueSel()
    n = 0
    for each lg in sportsLeagues()
        if leagueOn(sel, lg.id) then n = n + 1
    end for
    if n = 0 then return "OFF"
    return n.ToStr() + " ON"
end function

function onOff(b as Boolean) as String
    if b then return "ON"
    return "OFF"
end function

function leagueItems() as Object
    sel = sportsLeagueSel()
    items = []
    for each lg in sportsLeagues()
        items.Push({ id: "lg_" + lg.id, label: lg.label, value: onOff(leagueOn(sel, lg.id)) })
    end for
    items.Push({ id: "lgmissing", label: "Show games not in guide", value: onOff(regRead("sportsUnmatched", "1") = "1") })
    items.Push({ id: "lgback", label: "Back to menu" })
    return items
end function

sub showLeagues()
    m.menuPage = "leagues"
    m.menu.heading = "Live sports leagues"
    m.menu.items = leagueItems()
    m.menu.subtitle = "Games from these leagues are matched to your guide in Sports > On Now / Coming Up"
    m.menu.callFunc("openMenu")
end sub

sub toggleLeague(id as String)
    out = []
    sel = sportsLeagueSel()
    for each lg in sportsLeagues()
        isOn = leagueOn(sel, lg.id)
        if lg.id = id then isOn = not isOn
        if isOn then out.Push(lg.id)
    end for
    regWrite("sportsLeagues", out.Join(","))
end sub

sub closeMenuView()
    m.menu.callFunc("closeMenu")
    restoreFocus()
end sub

sub onMenuClose()
    if m.menuPage = "leagues" then
        showMenu()
        return
    end if
    closeMenuView()
end sub

sub onMenuSelected()
    id = m.menu.selected
    if m.menuPage = "leagues" then
        if Left(id, 3) = "lg_" then
            toggleLeague(Mid(id, 4))
            m.menu.items = leagueItems()
        else if id = "lgmissing" then
            if regRead("sportsUnmatched", "1") = "1" then regWrite("sportsUnmatched", "0") else regWrite("sportsUnmatched", "1")
            m.menu.items = leagueItems()
        else if id = "lgback" then
            showMenu()
        end if
        return
    end if
    if id = "leagues" then
        showLeagues()
    else if id = "fmt" or id = "compat" then
        ' toggles keep the menu open and refresh the value in place
        runMenuAction(id)
        m.menu.items = menuItems()
    else if id = "close" then
        closeMenuView()
    else
        closeMenuView()
        runMenuAction(id)
    end if
end sub

sub runMenuAction(action as String)
    if action = "server" then
        promptHost()
    else if action = "reload" then
        m.useCache = false
        loadAll()
    else if action = "favorites" then
        openFavorites()
    else if action = "jump" then
        promptJump()
    else if action = "fmt" then
        f = regRead("fmt", "auto")
        if f = "auto" then
            f = "hls"
        else if f = "hls" then
            f = "ts"
        else
            f = "auto"
        end if
        regWrite("fmt", f)
        showToast("Stream format: " + UCase(f))
        if m.playIdx >= 0 then playChannel(m.playIdx)
    else if action = "compat" then
        toggleCompat()
    else if action = "fit" then
        openFitCal()
    else if action = "hideun" then
        m.hideUnmapped = not m.hideUnmapped
        if m.hideUnmapped then
            regWrite("hideUnmapped", "1")
        else
            regWrite("hideUnmapped", "0")
        end if
        loadAll()
    else if action = "stats" then
        if m.playIdx >= 0 then showStreamStats()
    else if action = "about" then
        showDialog("info", "About", ["TunerBox TV 1.0", "Server: " + m.base, "Channels: " + m.channels.Count().ToStr() + "   With guide data: " + m.epgCount.ToStr()], ["OK"], ["close"])
    end if
end sub

' ============================================================ On Demand (browse screen)
' args: {} | { kind } | { showId } | { movieId } | { episode } (see OnDemandView.openOD)
sub openOnDemand(args as Object)
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if m.mode = "vod" then vodStop(false)
    m.hud.callFunc("hideAll")
    m.mode = "ondemand"
    m.od.baseUrl = m.base
    m.od.callFunc("openOD", args)
    setOdPreview()
end sub

' live TV keeps playing in the panel's corner
sub setOdPreview()
    pr = m.od.previewRect
    if pr = invalid or pr.Count() <> 4 then return
    s = m.fitScale
    m.video.translation = [m.fitOff[0] + Int(pr[0] * s), m.fitOff[1] + Int(pr[1] * s)]
    m.video.width = Int(pr[2] * s)
    m.video.height = Int(pr[3] * s)
end sub

sub closeOnDemand()
    m.od.callFunc("closeOD")
    setPreviewSize(false)
    m.mode = "live"
    m.top.setFocus(true)
end sub

sub onOdRequest()
    req = m.od.request
    if req = invalid or m.mode <> "ondemand" then return
    ty = req.type
    if ty = "close" then
        closeOnDemand()
        showBanner()
    else if ty = "toast" then
        showToast(req.text)
    else if ty = "dialog" then
        showDialog("vod", req.title, req.message, req.buttons, req.actions)
    else if ty = "keyboard" then
        showKeyboard("vodsearch", "Search On Demand", ["A title, a year or an actor"], req.text)
    else if ty = "play" then
        playVod(req.id, req.start, true)
    end if
end sub

' small GET / POST to TunerBox for playback (results come back in onVodApi)
sub vodApi(tag as String, path as String, body as Dynamic, ctx as Object)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = path
    if body <> invalid then t.apiBody = FormatJson(body)
    t.apiTag = tag
    t.apiCtx = ctx
    t.observeField("result", "onVodApi")
    m.vodTasks.Push(t)
    if m.vodTasks.Count() > 8 then m.vodTasks.Shift()
    t.control = "RUN"
end sub

sub onVodApi(event as Object)
    r = event.getData()
    if r = invalid or r.tag <> "vodplay" then return
    ctx = r.ctx
    if ctx.seq <> m.vodSeq then return
    if not r.ok or r.data = invalid then
        showToast("Can't play this title")
        return
    end if
    startVod(r.data, ctx.start, ctx.back)
end sub

' search results from GET /api/search ("vod" list) as rows for the Search panel
function vodSearchRow(v as Object) as Object
    kind = anyStr(v.kind)
    badge = "MOVIE"
    sb = ""
    if kind = "series" then badge = "SHOW"
    if kind = "episode" then
        badge = "EPISODE"
        sb = anyStr(v["sub"])
    else
        parts = []
        if anyStr(v.year) <> "" then parts.Push(anyStr(v.year))
        if anyStr(v.category) <> "" then parts.Push(anyStr(v.category))
        sb = parts.Join(dotSep())
    end if
    right = "On Demand"
    ln = fmtLen(numv(v.duration))
    if kind <> "series" and ln <> "" then right = right + dotSep() + ln
    return { k: "vod", badge: badge, num: "", name: "", title: plainText(anyStr(v.name)), sub: plainText(sb), right: right, start: 0, stop: 0, v: v }
end function

' ============================================================ On Demand playback
' TunerBox streams a title from a start time (ss) like a live channel, so the position is
' base + how long it has been playing, and skipping asks for a new stream from the new time.
function vodClientId() as String
    if m.vodClient = invalid then m.vodClient = "roku-" + CreateObject("roDeviceInfo").GetChannelClientId()
    return m.vodClient
end function

' start < 0 = resume where you stopped
sub playVod(id as String, start as Float, back as Boolean)
    m.vodSeq = m.vodSeq + 1
    showToast("Loading...")
    vodApi("vodplay", "/api/vod/play/" + urlEncode(id), invalid, { seq: m.vodSeq, start: start, back: back })
end sub

sub startVod(it as Object, start as Float, back as Boolean)
    if start < 0 then
        start = 0
        if numv(it.position) > 30 then start = numv(it.position)
    end if
    if m.dlg <> invalid then
        d = m.dlg
        m.dlg = invalid
        d.close = true
    end if
    if m.menu.visible then m.menu.callFunc("closeMenu")
    if m.mode = "ondemand" then m.od.callFunc("closeOD")
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if m.vod <> invalid then vodLeave()
    setPreviewSize(false)
    m.mode = "vod"
    m.top.setFocus(true)
    m.vod = { it: it, id: anyStr(it.id), dur: numv(it.duration), base: start, back: back, retries: 0, target: -1.0, paused: false, parked: false, done: false, acc: 0.0, running: false, clock: CreateObject("roTimespan"), ticks: 0 }
    if start > 0 then showToast("Resuming from " + fmtDur(start)) else showToast(anyStr(it.title))
    vodStart(start)
    m.vodTimer.control = "start"
end sub

sub vodStart(at as Float)
    v = m.vod
    if v = invalid then return
    m.seekTimer.control = "stop"
    m.parkTimer.control = "stop"
    m.retryTimer.control = "stop"
    if v.dur > 0 and at > v.dur - 5 then at = v.dur - 5
    if at < 0 then at = 0
    v.base = at
    v.target = -1.0
    v.parked = false
    v.paused = false
    v.acc = 0.0
    v.running = false
    u = m.base + "/api/vod/stream/" + urlEncode(v.id) + "?ss=" + Int(at).ToStr() + "&client=" + urlEncode(vodClientId())
    if isCompat("") then u = u + "&mode=roku720"
    c = CreateObject("roSGNode", "ContentNode")
    c.url = u
    c.title = anyStr(v.it.title)
    c.live = true
    c.streamFormat = "ts"
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.underruns = 0
    showVodHud()
end sub

function vodPos() as Float
    v = m.vod
    if v = invalid then return 0
    if v.target >= 0 then return v.target
    if v.parked then return v.base
    p = v.base + v.acc
    if v.running then p = p + v.clock.TotalMilliseconds() / 1000.0
    return p
end function

sub vodState(st as String)
    v = m.vod
    if st = "playing" then
        if not v.running then
            v.clock.Mark()
            v.running = true
        end if
        return
    end if
    if v.running then
        v.acc = v.acc + v.clock.TotalMilliseconds() / 1000.0
        v.running = false
    end if
    if v.done or v.parked or m.mode <> "vod" then return
    if st = "error" then
        vodDropped()
    else if st = "finished" then
        vodEnded()
    end if
end sub

' the stream stopped early (provider hiccup): pick up from the same spot, a few times
sub vodDropped()
    v = m.vod
    playPos = vodPos()
    v.base = playPos
    v.parked = true
    m.video.control = "stop"
    if v.retries < 3 then
        v.retries = v.retries + 1
        showToast("Reconnecting...")
        m.retryTimer.control = "stop"
        m.retryTimer.control = "start"
    else
        vodSave()
        showDialog("vodnext", "Can't play this title", [anyStr(v.it.title) + ": no video from the provider."], ["OK"], ["stop"])
    end if
end sub

sub vodEnded()
    v = m.vod
    if v.dur > 0 and vodPos() < v.dur - 120 then
        vodDropped()
    else
        vodFinish()
    end if
end sub

sub vodFinish()
    v = m.vod
    if v = invalid or v.done then return
    v.done = true
    v.base = v.dur
    v.parked = true
    m.vodTimer.control = "stop"
    vodApi("watched", "/api/vod/watched", { id: v.id, watched: true }, {})
    m.video.control = "stop"
    m.hud.callFunc("hideAll")
    nx = v.it["next"]
    if nx = invalid then
        vodStop(v.back)
        return
    end if
    backLbl = "Back to TV"
    if v.back then backLbl = "Back to the episodes"
    showDialog("vodnext", "Finished: " + anyStr(v.it.title), [anyStr(v.it["sub"])], ["Play next: " + anyStr(nx.label), backLbl], ["next", "stop"])
end sub

sub vodNextAction(action as String)
    v = m.vod
    if v = invalid then return
    if action = "next" and v.it["next"] <> invalid then
        playVod(anyStr(v.it["next"].id), 0, v.back)
    else
        vodStop(v.back)
    end if
end sub

sub vodSave()
    v = m.vod
    if v = invalid or v.done then return
    playPos = vodPos()
    if playPos < 5 then return
    vodApi("progress", "/api/vod/progress", { id: v.id, position: playPos, duration: v.dur }, {})
end sub

' something else is about to play: remember the spot and let go
sub vodLeave()
    vodSave()
    m.vodTimer.control = "stop"
    m.seekTimer.control = "stop"
    m.parkTimer.control = "stop"
    m.retryTimer.control = "stop"
    m.vod = invalid
    m.hud.callFunc("hideAll")
end sub

' Back / Stop: return to the channel you were on, and to On Demand if you came from there
sub vodStop(backToOD as Boolean)
    if m.vod = invalid then return
    vodLeave()
    m.video.control = "stop"
    m.mode = "live"
    m.top.setFocus(true)
    if m.extern <> invalid then
        playExternal(m.extern)
    else if m.curIdx >= 0 then
        playChannel(m.curIdx)
    end if
    if backToOD then
        m.mode = "ondemand"
        m.od.callFunc("reopenOD")
        setOdPreview()
    else
        showBanner()
    end if
end sub

sub vodPause()
    v = m.vod
    if v.done then return
    if v.paused then
        v.paused = false
        m.parkTimer.control = "stop"
        if v.parked then
            vodStart(v.base)
            return
        end if
        m.video.control = "resume"
    else
        v.paused = true
        m.video.control = "pause"
        vodSave()
        ' a long pause lets go of the provider's connection; Play picks up from the same spot
        m.parkTimer.control = "start"
    end if
    showVodHud()
end sub

sub onParkTimer()
    v = m.vod
    if v = invalid or not v.paused or v.parked then return
    v.base = vodPos()
    v.parked = true
    m.video.control = "stop"
    showVodHud()
end sub

sub vodSeek(delta as Float)
    v = m.vod
    if v.done then return
    t = vodPos() + delta
    if v.dur > 0 and t > v.dur - 10 then t = v.dur - 10
    if t < 0 then t = 0
    v.target = t
    showVodHud()
    ' several presses = one jump
    m.seekTimer.control = "stop"
    m.seekTimer.control = "start"
end sub

sub onSeekTimer()
    v = m.vod
    if v = invalid or v.target < 0 then return
    vodStart(v.target)
end sub

sub onVodTick()
    v = m.vod
    if v = invalid or m.mode <> "vod" or v.done then return
    m.hud.callFunc("updateVod", vodInfo())
    if v.parked or v.paused or v.target >= 0 or not v.running then return
    v.ticks = v.ticks + 1
    if v.ticks mod 15 = 0 then
        vodSave()
        v.retries = 0
    end if
    if v.dur > 0 and vodPos() >= v.dur - 1 then vodFinish()
end sub

function vodInfo() as Object
    v = m.vod
    playPos = vodPos()
    times = fmtDur(playPos)
    pct = 0.0
    if v.dur > 0 then
        times = times + " / " + fmtDur(v.dur)
        pct = playPos / v.dur
    end if
    badge = ""
    if v.target >= 0 then
        badge = "SKIPPING"
    else if v.paused then
        badge = "PAUSED"
    else if v.parked or not v.running then
        badge = "LOADING"
    end if
    hint = "Left -10s   Right +30s   Rew/FF 5 min   OK Pause   Back Stop"
    return { num: "VOD", name: "On Demand", logo: "", title: plainText(anyStr(v.it.title)), subtitle: plainText(anyStr(v.it["sub"])), times: times, pct: pct, nextText: hint, rating: badge }
end function

sub showVodHud()
    v = m.vod
    if v = invalid then return
    secs = 5
    if v.paused then secs = 0
    m.hud.callFunc("showVod", vodInfo(), secs)
end sub

function vodKey(key as String) as Boolean
    v = m.vod
    if v = invalid then
        m.mode = "live"
        return false
    end if
    if v.done then
        if key = "back" or key = "OK" then vodStop(v.back)
        return true
    end if
    if key = "OK" or key = "play" then
        vodPause()
    else if key = "left" or key = "replay" then
        vodSeek(-10)
    else if key = "right" then
        vodSeek(30)
    else if key = "rewind" then
        vodSeek(-300)
    else if key = "fastforward" then
        vodSeek(300)
    else if key = "up" or key = "down" or key = "options" then
        showVodHud()
    else if key = "back" then
        vodStop(v.back)
    else if Left(key, 4) = "Lit_" then
        lc = LCase(Mid(key, 5))
        if lc = "m" then
            toggleMute()
        else if lc = "i" then
            showVodHud()
        else if lc = "s" then
            vodStop(v.back)
        end if
    else
        return false
    end if
    return true
end function
