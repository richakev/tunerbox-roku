' TunerBox TV - scene controller
' modes: boot | needhost | error | live | home | guide | sports | stats | search | ondemand | vod | rec

sub init()
    themeInit()
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
    m.guideRefresh = m.top.findNode("guideRefresh")
    m.guideRefresh.observeField("fire", "onGuideRefresh")
    m.savedGuideTimer = m.top.findNode("savedGuideTimer")
    m.savedGuideTimer.observeField("fire", "startSavedGuide")
    m.savedGuideWait = false
    ' Sports & Events comes in two layouts (TunerBox Setup › Settings › Sports): Basic (SportsView, the
    ' default) and Enhanced (SportsViewEnhanced). m.sports is the one in use: the last one TunerBox asked for.
    m.sportsBasic = m.top.findNode("sports")
    m.sportsEnh = m.top.findNode("sportsx")
    m.sports = m.sportsBasic
    if regRead("sportsLayout", "basic") = "enhanced" then m.sports = m.sportsEnh
    ' TunerBox matches live games to the guide itself (its scoreboard): the Enhanced layout shows its
    ' games and this Roku doesn't fetch and match them again (as last heard, until /api/sports says)
    m.serverGames = (regRead("sportsServerGames", "0") = "1")
    m.gamesAsked = false    ' this Roku's own live-games matching was started for the Sports screen open now
    m.stats = m.top.findNode("stats")
    m.statsTasks = []
    m.statsSeq = 0
    m.gswOpts = invalid
    m.search = m.top.findNode("search")
    m.od = m.top.findNode("od")
    m.home = m.top.findNode("home")
    ' Home screen: only when TunerBox's Setup > Settings "Home screen" is on (last answer cached for the next launch)
    m.homeOn = (regRead("homeOn", "0") = "1")
    ' TunerBox's optional features, as last heard (Setup > Settings): On Demand only when a playlist or library
    ' has it, Record only while Setup > Settings > DVR > Recordings is on
    m.vodOn = (regRead("vodOn", "1") = "1")
    m.dvrOn = (regRead("dvrOn", "1") = "1")
    m.homeAuto = true       ' still launching: open on Home once we know it's on (until a key is pressed)
    m.returnHome = false    ' the screen on top was opened from Home: Back goes back there
    m.homeReq = invalid
    m.rec = invalid
    m.inStandby = false
    m.homeTasks = []
    m.vod = invalid
    m.vodSeq = 0
    m.vodTasks = []
    m.cuDays = {}           ' catch-up: { "<channel number>": days of archive } (TunerBox /api/catchup)
    m.cuFrom = 0            ' the guide's listings go back to here (0: as loaded, an hour ago)
    m.vodTimer = m.top.findNode("vodTimer")
    m.seekTimer = m.top.findNode("seekTimer")
    m.parkTimer = m.top.findNode("parkTimer")
    m.subsTimer = m.top.findNode("subsTimer")
    m.subsTimer.observeField("fire", "subsTick")
    m.subs = m.top.findNode("subs")
    m.subsBg = m.top.findNode("subsBg")
    m.subsLbl = m.top.findNode("subsLbl")
    m.subsLbl.font.size = 44
    m.searchFrom = ""
    m.svod = invalid        ' the On Demand title whose play menu is open over Search or Home
    m.menu = m.top.findNode("menu")
    m.jump = m.top.findNode("jump")
    m.jump.observeField("result", "onJumpResult")
    m.jump.observeField("closeRequest", "onJumpClose")
    m.checkTimer = m.top.findNode("checkTimer")
    m.extern = invalid
    m.sportsTasks = []
    m.sportsGroupName = ""
    m.gameReq = invalid
    m.menuPage = "main"
    m.feedsFrom = "main"     ' which page opened Switch feed (its Back goes there)
    m.settingsFrom = "main"  ' and Settings
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
    m.pvHeldIdx = -1        ' live channel paused for On Demand's Pick a version reads
    m.alt = 0           ' which of the playing channel's feeds: 0 the main one, 1.. its backups (Setup's order)
    m.altNum = ""       ' the channel number m.alt is for (a reload can put another channel at the same index)
    m.feedTask = invalid
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
    ' a favorites load that failed is tried again a few times, spaced out (not straight away, in a loop)
    m.favRetries = 0
    m.favRetryTimer = CreateObject("roSGNode", "Timer")
    m.favRetryTimer.repeat = false
    m.favRetryTimer.observeField("fire", "onFavRetry")
    ' the show in On Demand (odProgAsk): answers by "<channel>-<start>", the bar's button, and the guide's
    ' OK dialog waiting a moment for its answer
    m.odProg = {}
    m.odProgOff = 0
    m.odHud = invalid
    m.odHudAsking = ""
    m.odPick = invalid
    m.optWait = invalid
    m.optOd = invalid
    m.optWaitTimer = CreateObject("roSGNode", "Timer")
    m.optWaitTimer.repeat = false
    m.optWaitTimer.duration = 1.2
    m.optWaitTimer.observeField("fire", "onOptWait")
    ' the bar's button asks a moment after tuning (as places), so channel surfing doesn't ask for every channel
    m.odHudTimer = CreateObject("roSGNode", "Timer")
    m.odHudTimer.repeat = false
    m.odHudTimer.duration = 2.5
    m.odHudTimer.observeField("fire", "onOdHudTimer")
    ' the other channels and event feeds showing the game that's on (TunerBox /api/sports/places), asked a
    ' moment after tuning so channel surfing doesn't ask; m.places = { key: placesKey(), game } (game may be invalid)
    m.places = invalid
    m.placesTask = invalid
    m.placesMenuTask = invalid
    m.placeOpts = []        ' what the Switch feed list's pl_<i> rows play: { ch } or { f }
    m.swf = invalid         ' Switch feed waiting on its answers: { key, idx, wait, feeds, seq }
    m.swfSeq = 0            ' which Switch feed opening an answer is for (an older one is ignored)
    m.placesTimer = CreateObject("roSGNode", "Timer")
    m.placesTimer.repeat = false
    m.placesTimer.duration = 2.5
    m.placesTimer.observeField("fire", "onPlacesTimer")
    mvInit()                ' multiview (MainMultiview.brs)
    m.guideTitle = ""
    m.useCache = true
    m.fromCache = false
    m.guideTask = invalid

    m.video.observeField("state", "onVideoState")
    m.video.observeField("streamInfo", "onStreamInfo")
    m.video.observeField("availableSubtitleTracks", "onCcTracks")
    m.guide.observeField("tuneRequest", "onGuideTune")
    m.guide.observeField("previewRequest", "onGuidePreview")
    m.guide.observeField("optionsRequest", "onGuideOptions")
    m.guide.observeField("pastRequest", "onGuidePast")
    m.guide.observeField("descRequest", "onGuideDesc")
    m.guide.observeField("menuRequest", "onGuideMenu")
    m.guide.observeField("exitRequest", "onGuideExit")
    m.guide.observeField("notice", "onGuideNotice")
    m.hud.observeField("buttonSelected", "onHudButton")
    m.sportsBasic.observeField("request", "onSportsRequest")
    m.sportsEnh.observeField("request", "onSportsRequest")
    m.stats.observeField("request", "onStatsRequest")
    m.search.observeField("query", "onSearchQuery")
    m.search.observeField("request", "onSearchRequest")
    m.od.observeField("request", "onOdRequest")
    m.home.observeField("request", "onHomeRequest")
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
    m.hud.showHome = m.homeOn
    m.hud.showOnDemand = m.vodOn
    m.home.vodOn = m.vodOn
    m.top.setFocus(true)
    if regRead("host", "") <> "" then quickPlay()
    start()
end sub

' ============================================================ startup / loading
sub start()
    if regRead("host", "") = "" then
        m.mode = "needhost"
        setStatus("No TunerBox server set." + Chr(10) + Chr(10) + "Press OK to enter its IP address.")
        ' a dialog before the app's first screen: tell the OS (certification 3.2), so the time spent typing
        ' doesn't count as launch time; AppLaunchComplete follows when it closes (launchDialogDone)
        if not m.launchDone then
            m.launchDlg = true
            m.top.signalBeacon("AppDialogInitiate")
        end if
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
    m.statusLbl.text = plainText(text)
    m.statusGroup.visible = true
end sub

sub loadAll()
    m.base = normalizeBase(regRead("host", ""))
    m.odProg = {}           ' another (or a newer) TunerBox: the show-in-On-Demand answers again
    m.odProgOff = 0
    m.mode = "boot"
    m.guideDelay.control = "stop"
    if not m.quick then
        m.video.control = "stop"
        setStatus("Connecting to " + m.base + " ...")
    end if
    m.hud.callFunc("hideAll")
    m.guide.callFunc("closeGuide")
    if m.home.visible then hideHome()
    m.returnHome = false
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
    noteRecent(ch.numStr)
    regWrite("last", ch.numStr)
    regWrite("lastUrl", ch.url)
    regWrite("lastName", ch.name)
end sub

sub onGuideDelay()
    startGuideTask()
end sub

' every 30 min while the app is open: the guide again once the last full fetch is 3 hours old, so an app left
' on for a day doesn't run out of listings.
sub onGuideRefresh()
    if m.channels.Count() = 0 or m.base = "" then return
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if m.guideTask <> invalid and m.guideTask.state = "run" then return
    age = nowEpoch() - Int(Val(regRead("gFullTs", "0")))
    if age >= 0 and age < 10800 then return
    print "[TunerBox] guide is " + Int(age / 60).ToStr() + " min old: refreshing in the background"
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
        m.homeAuto = false
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
    m.guide.favs = m.favs
    startFavsTask()
    fetchSettings()
    ' the saved guide is read once the video is playing (startSavedGuide), so it doesn't slow the stream down
    m.savedGuideWait = true
    m.savedGuideTimer.control = "start"
    if m.video.state = "playing" then startSavedGuide()
    if m.homeAuto and m.homeOn and homeAtStart() then
        m.homeAuto = false
        openHome()
    else
        showBanner()
    end if
    launchComplete()
end sub

' at launch, once the video is playing (or the timer gives up waiting): read the guide saved on this Roku
sub startSavedGuide()
    if not m.savedGuideWait then return
    m.savedGuideWait = false
    m.savedGuideTimer.control = "stop"
    m.sgTask = CreateObject("roSGNode", "LoadTask")
    m.sgTask.mode = "savedguide"
    ' the saved files are named after the server
    m.sgTask.baseUrl = m.base
    m.sgTask.observeField("result", "onSavedGuide")
    m.sgTask.control = "RUN"
end sub

sub onSavedGuide()
    r = m.sgTask.result
    if r = invalid then return
    ' memory: the finished task would keep its copy of the guide in its result; let the task go
    m.sgTask = invalid
    bootGuide(r.guide)
end sub

' the saved guide, read after the channels and the video's start; then the guide refresh, unless it's fresh
sub bootGuide(g as Dynamic)
    guideFresh = false
    if g <> invalid then
        applyGuide(g)
        ' fresh: the whole guide (both passes) fetched in the last 3 hours. "gFullTs" is only written once the
        ' second pass is in, so a guide saved with just the first hours (or by an older version, which wrote
        ' "gTs") is fetched again
        age = nowEpoch() - Int(Val(regRead("gFullTs", "0")))
        guideFresh = (age >= 0 and age < 10800)
        ' the live banner showed "Guide loading..." until now
        if m.mode = "live" then showBanner()
    end if
    ' the guide refresh is heavy: give the video a head start (8 s) when a saved guide is already showing, and
    ' skip it if that one is fresh. With no saved guide there's nothing to show meanwhile: start almost at once
    ' (the first pass is only a few hours, so it doesn't hold the stream up for long)
    if g = invalid then
        m.guideDelay.duration = 2
    else
        m.guideDelay.duration = 8
    end if
    if not guideFresh then m.guideDelay.control = "start"
    ' and from now on, a check every 30 min (onGuideRefresh)
    m.guideRefresh.control = "start"
end sub

' ------------------------------------------------------------ launch beacon / deep links
' Tell the OS the app is ready for interaction (certification 3.2). Sent once.
' the first-launch server prompt closed (entered or dismissed)
sub launchDialogDone()
    if m.launchDlg = invalid or not m.launchDlg then return
    m.launchDlg = false
    m.top.signalBeacon("AppDialogComplete")
    ' nothing entered: the "No TunerBox server set" screen is the first screen
    if m.mode = "needhost" then launchComplete()
end sub

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
    if m.mode = "stats" then closeStats()
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
    m.guidePass = 0
    m.guideTask = CreateObject("roSGNode", "LoadTask")
    m.guideTask.mode = "guide"
    m.guideTask.baseUrl = m.base
    m.guideTask.refreshCache = m.fromCache
    m.guideTask.chanKeys = keys
    ' a guide is already showing (the saved one, or the last fetch): no quick first pass, it'd only replace
    ' that with fewer hours; just the whole guide, in one go
    if m.epgCount > 0 then m.guideTask.guideHours = m.guideTask.guideMore
    m.guideTask.observeField("result", "onGuideResult")
    m.guideTask.control = "RUN"
end sub


' how far ahead a guide goes: the latest end time of any show in it
function guideReach(guideByNum as Object) as Integer
    reach = 0
    for each num in guideByNum
        progs = guideByNum[num]
        if progs <> invalid and progs.Count() > 0 then
            lastP = progs[progs.Count() - 1]
            if lastP.stop > reach then reach = lastP.stop
        end if
    end for
    return reach
end function

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
    m.cuFrom = 0
    m.guide.guideData = idxGuide
    return n
end function

sub onGuideResult(event as Object)
    ' this answer's own copy (the task's field may already hold the next one)
    r = event.getData()
    if r = invalid or r.ok = invalid then return      ' (the {} that clears it, below)
    m.guideLoading = false
    if not r.ok or r.count = 0 then
        if m.epgCount = 0 then showToast("No guide data available")
        return
    end if
    ' this comes twice: the first hours (shown at once), then the rest of the guide (replaces it quietly)
    m.guidePass = m.guidePass + 1
    n = applyGuide(r.guide)
    ' the cache only counts as fresh once it has the whole guide; until then the next launch fetches again
    if r.full = true then
        regWrite("gFullTs", nowEpoch().ToStr())
        ' memory: the task's result would keep a copy of the whole guide for as long as the task is around
        m.guideTask.result = {}
    end if
    if m.guidePass = 1 then print "[TunerBox] guide applied: " + n.ToStr() + " channels, through " + fmtClock(guideReach(r.guide))
    if r.full = true then print "[TunerBox] guide complete: " + n.ToStr() + " channels, through " + fmtDay(guideReach(r.guide)) + " " + fmtClock(guideReach(r.guide))
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

sub onFavRetry()
    if m.mode <> "boot" then startFavsTask()
end sub

sub startFavsTask()
    runFavTask("favs", "", true)
end sub

sub onFavResult(event as Object)
    r = event.getData()
    if r = invalid then return
    if r.ok then
        m.favRetries = 0
        applyFavArray(r.favs)
        if m.mode = "home" then m.home.callFunc("reload")
    else
        if m.favRetries = 0 then showToast("Couldn't reach TunerBox favorites")
        if m.mode <> "boot" and m.favRetries < 5 then
            m.favRetries = m.favRetries + 1
            m.favRetryTimer.duration = 10 * m.favRetries     ' 10, 20, 30, 40, 50 s
            m.favRetryTimer.control = "start"
        end if
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
    buttons = [favText, viewText, "Category (All, Movies, Sports, News, Kids)", "Search", "Sports & Events"]
    actions = ["fav", "favview", "category", "search", "sports"]
    if m.vodOn then
        buttons.Push("On Demand")
        actions.Push("ondemand")
    end if
    if m.homeOn then
        buttons.Push("Home")
        actions.Push("home")
    end if
    buttons.Append(["Main menu", "Close"])
    actions.Append(["mainmenu", "close"])
    showDialog("gmenu", ch.numStr + " " + ch.name, ["Guide options"], buttons, actions)
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
    else if action = "category" then
        showDialog("gcat", "Category", ["Show only the channels with a show of this category on in the hours shown"], ["All channels", "Movies", "Sports", "News", "Kids", "Close"], ["g:", "g:movies", "g:sports", "g:news", "g:kids", "close"])
    else if action = "home" then
        openHome()
    end if
end sub

' ============================================================ playback
sub playChannel(idx as Integer)
    ' another channel starts on its main feed (whatever Setup has made main now); restarting the one
    ' that's on (retry, stream cache, 720p, format) stays on the feed it was playing
    alt = 0
    if idx >= 0 and idx < m.channels.Count() and m.extern = invalid and m.channels[idx].numStr = m.altNum then alt = m.alt
    playChannelFeed(idx, alt)
end sub

' a channel on one of its feeds: alt 0 = main, 1.. = backups, as /api/stream/{n}?alt= numbers them
sub playChannelFeed(idx as Integer, alt as Integer)
    if idx < 0 or idx >= m.channels.Count() then return
    mvForget()
    ch = m.channels[idx]
    m.alt = alt
    m.altNum = ch.numStr
    c = CreateObject("roSGNode", "ContentNode")
    c.url = streamUrl({ url: withAlt(ch.url, alt), numStr: ch.numStr })
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
    placesSoon()
end sub

' 720p compatibility mode: applies to ALL channels (default ON, toggle in MENU)
function isCompat() as Boolean
    return regRead("compat720", "1") = "1"
end function

function withAlt(u as String, alt as Integer) as String
    if alt <= 0 then return u
    sep = "?"
    if Instr(1, u, "?") > 0 then sep = "&"
    return u + sep + "alt=" + alt.ToStr()
end function

' backup feeds of a channel (from /channels.json; 0 when the server doesn't say)
function chAlts(idx as Integer) as Integer
    if idx < 0 or idx >= m.channels.Count() then return 0
    return Int(numv(m.channels[idx].alts))
end function

function streamUrl(ch as Object) as String
    u = withDevice(withBuffer(ccUrl(ch.url)))
    if isCompat() then
        sep = "?"
        if Instr(1, u, "?") > 0 then sep = "&"
        u = u + sep + "mode=roku720"
    end if
    return u
end function

sub toggleCompat()
    if isCompat() then
        regWrite("compat720", "0")
        showToast("720p mode OFF (original quality)")
    else
        regWrite("compat720", "1")
        showToast("720p mode ON")
    end if
    if m.mv <> invalid then
        mvStartStream()
    else if m.extern <> invalid then
        playExternal(m.extern)
    else if m.playIdx >= 0 then
        playChannel(m.playIdx)
    end if
end sub

function streamFmt(url as String) as String
    if ccUrl(url) <> url then return "hls"     ' captions on: TunerBox's own stream comes over HLS
    f = regRead("fmt", "auto")
    if f = "hls" or f = "ts" then return f
    if Instr(1, LCase(url), ".m3u8") > 0 then return "hls"
    return "ts"
end function

' make idx the "real" channel (as opposed to a guide preview)
sub commitChannel(idx as Integer)
    m.returnHome = false
    if m.mode = "home" then leaveHome()
    if idx <> m.curIdx then
        m.lastIdx = m.curIdx
        m.curIdx = idx
    end if
    rememberChannel(idx)
end sub

' tune a channel picked on purpose (guide, search, Home, Sports, a typed number): it plays on its main
' feed, as channel up/down and Last do. Menu > Switch feed offers its backup feeds (and other places
' showing the game that's on).
sub tuneTo(idx as Integer)
    if idx < 0 or idx >= m.channels.Count() then return
    if mvRoute({ idx: idx }) then return        ' multiview: into the highlighted (or a new) picture
    if m.extern = invalid and m.playIdx = idx then
        ' already on: keep whichever feed it's playing
        commitChannel(idx)
        showBanner()
        return
    end if
    commitChannel(idx)
    playChannelFeed(idx, 0)
    showBanner()
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
            tuneTo(i)
            return
        end if
    end for
    showToast("No channel " + numStr)
end sub

' ------------------------------------------------------------ TV off / input switched (HDMI-CEC)
' TV off: stop streaming so the server tuner is let go; On Demand and recordings save their spot
' (resume them from On Demand / Recordings). TV back on: retune the live channel.
sub onStandby()
    if m.top.standby then
        if m.inStandby then return
        m.inStandby = true
        print "[TunerBox] standby: stopping playback"
        m.retryTimer.control = "stop"
        if m.rec <> invalid then
            recSave(false)
            m.rec = invalid
        end if
        if m.vod <> invalid then vodLeave()
        m.vodTimer.control = "stop"
        if m.mode = "vod" or m.mode = "rec" then
            m.mode = "live"
            m.top.setFocus(true)
        end if
        m.hud.callFunc("hideAll")
        m.video.control = "stop"
    else
        if not m.inStandby then return
        m.inStandby = false
        print "[TunerBox] standby over: resuming live"
        if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
        if m.extern <> invalid then
            playExternal(m.extern)
        else if m.curIdx >= 0 then
            playChannel(m.curIdx)
        end if
        if m.mode = "live" then showBanner()
    end if
end sub

sub onVideoState()
    st = m.video.state
    ccApply()                   ' a new stream: multiview or On Demand may have started or ended
    if m.rec <> invalid then
        recState(st)
        return
    end if
    if m.vod <> invalid then
        vodState(st)
        return
    end if
    if m.mv <> invalid then
        mvVideoState(st)
        return
    end if
    if st = "playing" then
        m.retries = 0
        if m.savedGuideWait then startSavedGuide()
    else if st = "error" or st = "finished" then
        ' a live channel with backups: one more try on this feed, then the next feed in Setup's order
        if m.extern = invalid and m.playIdx >= 0 and m.retries >= 1 and m.alt < chAlts(m.playIdx) then
            m.retryTimer.control = "stop"
            showToast("Trying backup feed " + (m.alt + 1).ToStr() + "...")
            playChannelFeed(m.playIdx, m.alt + 1)
        else if m.retries < 3 then
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
        showDialog("info", "Stream stats", [m.extern.num + " " + m.extern.name, "State: " + v.state, "Video: " + v.videoFormat + "    Audio: " + v.audioFormat, ccStatsLine(), m.extern.url], ["OK"], ["close"])
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
    lines.Push(ccStatsLine())
    if m.alt > 0 then lines.Push("Feed: backup " + m.alt.ToStr() + " of " + chAlts(m.playIdx).ToStr())
    lines.Push(streamUrl({ url: withAlt(ch.url, m.alt), numStr: ch.numStr }))
    showDialog("info", "Stream stats", lines, ["OK"], ["close"])
end sub

sub onRetryTimer()
    if m.vod <> invalid then
        if m.mode = "vod" then vodStart(vodPos())
        return
    end if
    if m.mv <> invalid then
        mvStartStream()
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

' ============================================================ closed captions
' Broadcast TV carries its captions (CEA-608) inside the picture, and TunerBox passes them on (every version:
' -c:v copy keeps them, and libx264 writes them back when it converts). The Video node decodes and draws
' them itself, so this is only the switch. It's Roku's own caption setting (Settings > Accessibility >
' Captions mode), kept for the whole device, so other apps follow it too and it's still set next launch.
' They're held back over multiview's tiles and under On Demand's library subtitles (those win, as on the web).
function ccLabel() as String
    md = m.video.globalCaptionMode
    if md = "On" or md = "Off" then return UCase(md)
    return md                   ' "When mute" or "Instant replay", as set in Roku's settings
end function

sub toggleCaptions()
    if m.video.globalCaptionMode = "On" then
        m.video.globalCaptionMode = "Off"
        showToast("Closed captions: Off")
    else
        m.video.globalCaptionMode = "On"
        if m.mv <> invalid then
            showToast("Closed captions: On (not shown in multiview)")
        else if m.vod <> invalid and m.vod.sub <> invalid then
            showToast("Closed captions: On (shown when subtitles are off)")
        else
            showToast("Closed captions: On (they start in a few seconds)")
        end if
    end if
    ccApply()
    if m.mv = invalid then retuneLive()     ' live TV changes between TS and HLS (ccUrl)
end sub

' The Video node only reads CEA-608 from HLS (Roku's closed caption docs list HLS, not a plain TS stream),
' so while captions are on, TunerBox's own live streams are asked for over HLS. Every TunerBox has
' /api/hls/{n} and /api/feed/hls (pasiegel 1.0 to v1.10.0 and main), taking the same alt, client, mode and
' buf as /api/stream/{n} and /api/feed/stream (name is ignored there). Other URLs are left as they are.
' cc=1 (richakev's fork): a master playlist naming the captions (CC1), which Roku needs to find them in a
' live HLS stream. Older servers ignore it and send the plain playlist; ccPickTrack still asks for CC1 then.
function ccUrl(u as String) as String
    if m.video.globalCaptionMode = "Off" or m.base = "" or Left(u, Len(m.base)) <> m.base then return u
    h = u
    if Instr(1, u, "/api/stream/") > 0 then
        h = u.Replace("/api/stream/", "/api/hls/")
    else if Instr(1, u, "/api/feed/stream?") > 0 then
        h = u.Replace("/api/feed/stream?", "/api/feed/hls?")
    else
        return u
    end if
    sep = "?"
    if Instr(1, h, "?") > 0 then sep = "&"
    return h + sep + "cc=1"
end function

sub ccApply()
    hold = (m.mv <> invalid) or (m.vod <> invalid and m.vod.sub <> invalid)
    if m.video.suppressCaptions <> hold then m.video.suppressCaptions = hold
    ccPickTrack()
end sub

' The Video node lists the captions it found in the stream (availableSubtitleTracks: "eia608/1" for CC1)
' but doesn't always switch one on by itself, so with captions on, CC1 (else the first one) is picked here
function ccTrack() as String
    tracks = m.video.availableSubtitleTracks
    if Type(tracks) <> "roArray" then return ""
    first = ""
    for each t in tracks
        nm = anyStr(t.TrackName)
        if nm = "eia608/1" then return nm
        if first = "" and Left(LCase(nm), 6) = "eia608" then first = nm
    end for
    return first
end function

sub ccPickTrack()
    if m.video.globalCaptionMode <> "On" then return
    want = ccTrack()
    ' none listed (a playlist that doesn't name them): ask for CC1 anyway, as broadcast TV carries it
    if want = "" and m.mv = invalid then want = "eia608/1"
    if want <> "" and m.video.subtitleTrack <> want then
        print "[TunerBox] captions: picking " + want + " (was '" + m.video.subtitleTrack + "')"
        m.video.subtitleTrack = want
    end if
end sub

sub onCcTracks()
    tracks = m.video.availableSubtitleTracks
    n = 0
    if Type(tracks) = "roArray" then n = tracks.Count()
    print "[TunerBox] captions: " + n.ToStr() + " track(s) " + FormatJson(tracks)
    ccPickTrack()
end sub

' Stream stats: what the Video node knows about captions, to tell "none in the stream" from "not switched on"
function ccStatsLine() as String
    v = m.video
    tracks = v.availableSubtitleTracks
    names = []
    if Type(tracks) = "roArray" then
        for each t in tracks
            names.Push(anyStr(t.TrackName))
        end for
    end if
    found = "none found"
    if names.Count() > 0 then found = names.Join(", ")
    sel = v.subtitleTrack
    if sel = "" then sel = "-"
    s = "Captions: " + v.globalCaptionMode + "    track: " + sel + "    in stream: " + found
    if v.suppressCaptions then s = s + "    (held back)"
    return s
end function

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
        if nx <> invalid then info.nextText = "up next: " + nx.title
    else
        if m.guideLoading then
            info.subtitle = "Guide loading..."
        else
            info.subtitle = "No guide data"
        end if
    end if
    ' catch-up: on the line under the times (as the web banner's CATCH-UP flag)
    d = cuDaysOf(ch.numStr)
    if d > 0 then info.flag = "CATCH-UP " + cuDaysText(d) + "   " + Chr(183) + "   More > Start this show over, or earlier shows in the Guide"
    return info
end function

sub showBanner()
    if m.mv <> invalid then return          ' multiview labels its own pictures
    if m.extern <> invalid then
        m.hud.callFunc("showBanner", externInfo())
        return
    end if
    if m.curIdx < 0 then return
    updateHudFav()
    odHudSync(false)        ' the bar's Watch On Demand button, when the show on now is in On Demand
    m.hud.callFunc("showBanner", bannerInfo(m.channels[m.curIdx]))
end sub

sub showToast(text as String)
    m.toastLbl.text = plainText(text)
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

    m.homeAuto = false
    if m.mode = "vod" then return vodKey(key)
    if m.mode = "stats" then
        if key = "play" then toggleMute()
        return true
    end if
    if m.mode = "rec" then return recKey(key)

    if m.mode <> "live" then return false
    if m.mv <> invalid then return mvKey(key)

    if key = "up" then
        changeChannel(1)
    else if key = "down" then
        changeChannel(-1)
    else if key = "OK" then
        odHudSync(true)
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
        ' back flips to the last channel watched; only asks to exit when there isn't one yet
        if m.lastIdx >= 0 and m.lastIdx <> m.curIdx then goLast() else confirmExit()
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
    else if lc = "x" then
        openStats()
    else if lc = "l" then
        goLast()
    else if lc = "m" then
        toggleMute()
    else if lc = "c" then
        toggleCaptions()
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
    else if lc = "h" and m.homeOn then
        openHome()
    else if lc = "w" then
        mvOpen()
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
    hudAction(m.hud.buttonSelected)
end sub

' the bar's screens, and the More list's actions
sub hudAction(id as String)
    if id = "more" then
        showMore()
    else if id = "odprog" then
        showOdChoices()
    else if id = "startover" then
        m.hud.callFunc("hideAll")
        if m.curIdx >= 0 and m.extern = invalid then
            ch = m.channels[m.curIdx]
            playCatchup(ch.numStr, progAt(ch, nowEpoch()))
        end if
    else if id = "record" then
        m.hud.callFunc("hideAll")
        if m.curIdx >= 0 and m.extern = invalid then dvrRecord(m.curIdx, progAt(m.channels[m.curIdx], nowEpoch()))
    else if id = "home" then
        m.hud.callFunc("hideAll")
        openHome()
    else if id = "chup" then
        changeChannel(1)
    else if id = "chdn" then
        changeChannel(-1)
    else if id = "info" then
        showBanner()
    else if id = "stats" then
        m.hud.callFunc("hideAll")
        openStats()
    else if id = "last" then
        goLast()
    else if id = "mute" then
        toggleMute()
    else if id = "cc" then
        toggleCaptions()
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

' More on the bar: the same tile menu as * (Options), so it works on TVs where the system takes * during
' video (Roku TVs open their own picture settings). Multiview and Switch feed first, then this show and channel.
sub showMore()
    m.hud.callFunc("hideAll")
    m.menuPage = "more"
    m.menu.heading = "More"
    m.menu.items = moreItems()
    if m.extern = invalid and m.curIdx >= 0 then
        ch = m.channels[m.curIdx]
        m.menu.subtitle = ch.numStr + " " + ch.name
    else
        m.menu.subtitle = ""
    end if
    m.menu.callFunc("openMenu")
end sub

' at most 14 tiles (7 rows): the menu doesn't scroll
function moreItems() as Object
    items = []
    if m.mv <> invalid then
        items.Push({ id: "mv", label: "Multiview", value: "ON" })
    else if mvMaxPics() >= 2 and mvMainTile() <> invalid then
        items.Push({ id: "mv", label: "Multiview", value: "up to " + mvMaxPics().ToStr() })
    end if
    if canSwitchFeed() then
        v = ""
        if m.extern = invalid and chAlts(m.playIdx) > 0 then v = (m.alt + 1).ToStr() + " of " + (chAlts(m.playIdx) + 1).ToStr()
        items.Push({ id: "feeds", label: "Switch feed", value: v })
    end if
    onCh = (m.extern = invalid and m.curIdx >= 0)
    if onCh then
        if m.hud.isFav then items.Push({ id: "fav", label: "Remove from favorites" }) else items.Push({ id: "fav", label: "Add to favorites" })
    end if
    items.Push({ id: "last", label: "Last channel" })
    if onCh then
        ch = m.channels[m.curIdx]
        if cuAvailable(ch.numStr, progAt(ch, nowEpoch())) then items.Push({ id: "startover", label: "Start this show over" })
        if m.odHud <> invalid then items.Push({ id: "odprog", label: "Watch On Demand" })
        if m.dvrOn then items.Push({ id: "record", label: "Record this show" })
    end if
    if m.hud.muted then items.Push({ id: "mute", label: "Unmute" }) else items.Push({ id: "mute", label: "Mute" })
    items.Push({ id: "cc", label: "Closed captions", value: ccLabel() })
    items.Append([
        { id: "favs", label: "Favorites" },
        { id: "stats", label: "Game stats & live scores" },
        { id: "info", label: "Show info" },
        { id: "settings", label: "Settings" },
        { id: "close", label: "Close" }
    ])
    return items
end function

' ============================================================ guide
sub openGuide(startIdx as Integer, view as Object, title as String)
    coverHome()
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
    backToHome()
end sub

sub onGuideTune()
    m.returnHome = false
    idx = m.guide.tuneRequest
    closeGuide()
    tuneTo(idx)
end sub

sub onGuidePreview()
    ' preview stays on the current channel while browsing the guide (no retune)
end sub

sub onGuideNotice()
    if m.mode = "guide" and m.guide.notice <> "" then showToast(m.guide.notice)
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
    ' the show in On Demand: its answer first (asked now unless it's known), so the buttons come up together
    m.optWait = invalid
    m.optWaitTimer.control = "stop"
    if req.prog <> invalid and odProgCan(ch.numStr, req.prog) and odProgCached(ch.numStr, req.prog) = invalid then
        m.optWait = { req: req, key: odProgKey(ch.numStr, req.prog) }
        odProgAsk(ch.numStr, req.prog, "opts")
        m.optWaitTimer.control = "start"
        return
    end if
    showGuideOpts(req)
end sub

sub showGuideOpts(req as Object)
    ch = m.channels[req.chIdx]
    title = ch.name
    msg = [ch.numStr + " " + ch.name]
    buttons = ["Watch channel"]
    actions = ["watch"]
    m.optOd = invalid
    if req.prog <> invalid then
        p = req.prog
        t = nowEpoch()
        title = p.title
        msg = [fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop), ch.numStr + " " + ch.name]
        ended = (p.stop <= t)
        od = invalid
        if odProgCan(ch.numStr, p) then
            c = odProgCached(ch.numStr, p)
            if c <> invalid and c.m <> invalid then od = { mt: c.m, choices: odChoices(c.m, p) }
        end if
        if cuAvailable(ch.numStr, p) then
            ' from the channel's archive, in the On Demand player
            if ended then buttons.Unshift("Watch (catch-up)") else buttons.Push("Start over (from the beginning)")
            if ended then actions.Unshift("catchup") else actions.Push("catchup")
        else if ended then
            gone = "This show has ended"
            if od <> invalid and od.mt.show = invalid then
                gone = gone + ", but it's in On Demand"
            else if cuDaysOf(ch.numStr) > 0 then
                gone = gone + " and is no longer in the channel's archive"
            end if
            msg.Push(gone)
        end if
        ' the same movie or episode in On Demand: under Watch / Start over
        if od <> invalid then
            m.optOd = od
            for i = 0 to od.choices.Count() - 1
                buttons.Push(odChoiceLabel(od.choices[i], od.mt, false))
                actions.Push("od" + i.ToStr())
            end for
        end if
        if m.dvrOn and not ended then
            buttons.Push("Record")
            actions.Push("record")
        end if
    end if
    buttons.Push("Jump to channel #")
    actions.Push("jump")
    buttons.Push("Cancel")
    actions.Push("cancel")
    m.optReq = req
    showDialog("opts", title, msg, buttons, actions)
end sub

' ------------------------------------------------------------ filtered guides
' ============================================================ Sports & Events
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
    coverHome()
    if m.mode = "guide" then closeGuide()
    if m.mode = "search" then closeSearch()
    m.hud.callFunc("hideAll")
    m.mode = "sports"
    m.sportsGroupName = ""
    m.sports.callFunc("openSports")
    m.gamesAsked = false
    runSportsTask("sports", "")
    runGamesTask()
end sub

' live game schedule for the leagues picked in MENU > Live sports leagues, matched to the guide
sub runGamesTask()
    sel = sportsLeagueSel()
    ' TunerBox already matched them (Enhanced shows its rows' games): nothing to fetch or match here
    if m.serverGames and m.sports.isSameNode(m.sportsEnh) then sel = ""
    if sel = "" then
        m.sports.games = { ok: true, leagues: "", games: [] }
        return
    end if
    m.gamesAsked = true
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

' ============================================================ game stats (TunerBox /api/sports/stats)
' A see-through card in the top right corner with the box score of the game on this channel (a slim panel
' down the right on Live scores); the picture stays full size behind it. Opened from Menu or More > Game stats & live scores (or X on a keyboard remote).
sub openStats()
    if m.mode <> "live" then
        showToast("Game stats open while watching TV")
        return
    end if
    if m.curIdx < 0 and m.extern = invalid then
        showToast("Tune to a game to see its stats")
        return
    end if
    m.hud.callFunc("hideAll")
    m.mode = "stats"
    m.stats.callFunc("openStats")
    m.stats.message = "Loading..."
    setStatsPreview()
    loadStats()
end sub

sub closeStats()
    m.stats.callFunc("closeStats")
    m.stats.message = ""
    m.mode = "live"
    setPreviewSize(false)
    m.top.setFocus(true)
end sub

' the picture stays full size: the panel is a see-through card over it (StatsView)
sub setStatsPreview()
    setPreviewSize(false)
end sub

' what's on: an event feed by key, else the channel number
function statsQuery() as String
    if m.mv <> invalid then
        t = mvTile(m.mv.focus)
        if t <> invalid and t.key <> "" then return "feed=" + urlEncode(t.key)
        if t <> invalid then return "ch=" + urlEncode(t.num)
    end if
    if m.extern <> invalid then
        if m.extern.key <> invalid then return "feed=" + urlEncode(m.extern.key)
        return "ch=" + urlEncode(m.extern.num)
    end if
    if m.curIdx >= 0 then return "ch=" + urlEncode(m.channels[m.curIdx].numStr)
    return ""
end function

sub loadStats()
    q = statsQuery()
    if q = "" then return
    m.statsSeq = m.statsSeq + 1
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = "/api/sports/stats?" + q
    t.apiTag = "gstats"
    t.apiCtx = { seq: m.statsSeq }
    t.observeField("result", "onStatsResult")
    m.statsTasks.Push(t)
    if m.statsTasks.Count() > 4 then m.statsTasks.Shift()
    t.control = "RUN"
end sub

sub onStatsResult(event as Object)
    r = event.getData()
    if r = invalid or r.tag <> "gstats" or m.mode <> "stats" then return
    if r.ctx = invalid or r.ctx.seq <> m.statsSeq then return       ' an older answer (the channel changed)
    if r.ok = true and Type(r.data) = "roAssociativeArray" then
        d = r.data
        if Type(d.others) = "roArray" then
            for each o in d.others
                if Type(o) = "roAssociativeArray" then statsLineupOnly(o)
            end for
        end if
        m.stats.data = d
    else if m.stats.message <> "" then
        m.stats.message = "Couldn't get the stats from TunerBox."
    else
        m.stats.failed = true
    end if
end sub

' a Live scores game's ch / also cut to the channels in this Roku's lineup (the ones statsWatch can tune),
' so its "places to watch" count matches what OK offers
sub statsLineupOnly(o as Object)
    chans = []
    if Type(o.ch) = "roAssociativeArray" then chans.Push(o.ch)
    if Type(o.also) = "roArray" then
        for each c in o.also
            if Type(c) = "roAssociativeArray" then chans.Push(c)
        end for
    end if
    keep = []
    for each c in chans
        if chIndexByNum(numToStr(c.number)) >= 0 then keep.Push(c)
    end for
    o.ch = invalid
    if keep.Count() > 0 then
        o.ch = keep.Shift()
    end if
    o.also = keep
end sub

sub onStatsRequest()
    req = m.stats.request
    if req = invalid then return
    if req.type = "close" then
        closeStats()
    else if req.type = "refresh" then
        loadStats()
    else if req.type = "watch" then
        statsWatch(req.o)
    end if
end sub

' another game from Live scores: one place to watch goes straight there; more asks which, as the
' Sports screen does (feeds checked live first, then the channels, then the unchecked feeds)
sub statsWatch(o as Object)
    opts = gameOpts(o, "", "")
    if opts.Count() = 0 then
        showToast("None of your channels or event feeds has this game")
        return
    end if
    if opts.Count() = 1 then
        statsGo(opts[0])
        return
    end if
    buttons = []
    actions = []
    n = opts.Count()
    if n > 6 then n = 6
    for i = 0 to n - 1
        op = opts[i]
        if op.ch <> invalid then
            buttons.Push("Ch " + numToStr(op.ch.number) + "  " + anyStr(op.ch.name))
        else
            lbl = anyStr(op.f.name)
            if Len(lbl) > 48 then lbl = Left(lbl, 47) + "..."
            if anyStr(op.f.status) = "ok" then lbl = "LIVE  " + lbl
            buttons.Push(lbl)
        end if
        actions.Push("o" + i.ToStr())
    end for
    buttons.Push("Cancel")
    actions.Push("cancel")
    m.gswOpts = opts
    showDialog("gsw", anyStr(o.name), [opts.Count().ToStr() + " places have this game. If one doesn't work, try the next."], buttons, actions)
end sub

' every place a game is on ({ ch } or { f }), best first as the Sports screen orders them: event feeds
' checked live, then the channels in this Roku's lineup, then the feeds nobody has checked. ch, also and
' feeds (or a single feed) as TunerBox's sports games carry them; skipNum / skipFeed: what's on now
function gameOpts(o as Object, skipNum as String, skipFeed as String) as Object
    live = []
    rest = []
    chans = []
    if Type(o.ch) = "roAssociativeArray" then chans.Push(o.ch)
    if Type(o.also) = "roArray" then
        for each c in o.also
            if Type(c) = "roAssociativeArray" then chans.Push(c)
        end for
    end if
    feeds = []
    if Type(o.feeds) = "roArray" then
        feeds = o.feeds
    else if Type(o.feed) = "roAssociativeArray" then
        feeds = [o.feed]
    end if
    for each f in feeds
        if Type(f) = "roAssociativeArray" and anyStr(f.key) <> "" and anyStr(f.key) <> skipFeed then
            if anyStr(f.status) = "ok" then live.Push({ f: f }) else rest.Push({ f: f })
        end if
    end for
    opts = []
    for each x in live
        opts.Push(x)
    end for
    for each c in chans
        num = numToStr(c.number)
        if num <> skipNum and chIndexByNum(num) >= 0 then opts.Push({ ch: c })
    end for
    for each x in rest
        opts.Push(x)
    end for
    return opts
end function

' watch it, then put the panel back over the new game
sub statsGo(op as Object)
    if op.ch <> invalid then
        watchChannelNum(numToStr(op.ch.number), anyStr(op.ch.name))
    else
        watchFeed(op.f)
    end if
    m.hud.callFunc("hideAll")
    m.mode = "stats"
    m.stats.setFocus(true)
    m.stats.message = "Loading..."
    setStatsPreview()
    loadStats()
end sub

sub onSportsTaskResult(event as Object)
    t = event.getRoSGNode()
    r = event.getData()
    if m.mode <> "sports" then return
    md = t.mode
    if md = "sports" then
        if r.ok = true then
            sg = false
            v = r.data.server_games
            if Type(v) = "Boolean" or Type(v) = "roBoolean" then sg = v
            if sg <> m.serverGames then
                m.serverGames = sg
                if sg then regWrite("sportsServerGames", "1") else regWrite("sportsServerGames", "0")
            end if
            useSportsLayout(r.data.layout)
            m.sports.data = r.data
            ' this Roku skipped its own matching, but TunerBox no longer does it: match them here after all
            if not sg and m.sports.isSameNode(m.sportsEnh) and sportsLeagueSel() <> "" and not m.gamesAsked then runGamesTask()
        else if sportsLeagueSel() <> "" then
            ' live games can still be listed without the TunerBox sports feed
            m.sports.data = { on_now: [], upcoming: [], channels: [], groups: [] }
            showToast("Could not load Sports & Events from TunerBox")
        else
            m.sports.message = "Could not load Sports & Events from TunerBox. Press Back."
        end if
    else if md = "espn" then
        ' TunerBox turned out to match the games itself: the Enhanced layout shows those
        if m.serverGames and m.sports.isSameNode(m.sportsEnh) then return
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

' TunerBox says which layout Sports & Events uses ("enhanced"; anything else, or an older TunerBox
' without the setting, is Basic). The one already open is swapped for the other, and the Roku remembers.
sub useSportsLayout(layout as Dynamic)
    want = "basic"
    if Type(layout) = "String" or Type(layout) = "roString" then
        if layout = "enhanced" then want = "enhanced"
    end if
    node = m.sportsBasic
    if want = "enhanced" then node = m.sportsEnh
    if m.sports.isSameNode(node) then return
    regWrite("sportsLayout", want)
    m.sports.callFunc("closeSports")
    m.sports = node
    m.sports.callFunc("openSports")
    runGamesTask()           ' the live games went to the other one
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
        backToHome()
    else if ty = "program" then
        p = req.p
        if p = invalid or p.ch = invalid then return
        num = numToStr(p.ch.number)
        if p.start > nowEpoch() + 60 and not m.dvrOn then
            showToast("Hasn't started yet: " + fmtDay(p.start) + " " + fmtClock(p.start))
        else if p.start > nowEpoch() + 60 then
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
    if not started and not m.dvrOn then
        ' recordings are off: just where it's on
        on = []
        for each c in chans
            on.Push(c.number + " " + c.name + "  (" + fmtClock(c.start) + ")")
        end for
        msg.Push("On " + on.Join(", "))
        showDialog("info", g.title, msg, ["OK"], ["close"])
        return
    end if
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
    if t = "Float" or t = "roFloat" or t = "Double" then return Int(v).ToStr()
    return anyStr(v)
end function

' tune a TunerBox channel number: use the loaded list when it's there, otherwise stream it directly
sub watchChannelNum(num as String, name as String)
    m.returnHome = false
    idx = chIndexByNum(num)
    closeSports()
    if idx >= 0 then
        tuneTo(idx)
    else
        if mvRoute({ num: num, name: name }) then return
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
    m.returnHome = false
    esc = urlEncode(f.key)
    u = m.base + "/api/feed/stream?key=" + esc
    closeSports()
    if mvRoute({ f: f }) then return
    playExternal({ num: "EVENT", name: f.group, title: f.name, url: u, key: f.key })
    showBanner()
end sub

sub playExternal(ex as Object)
    mvForget()
    m.extern = ex
    u = withDevice(withBuffer(ccUrl(ex.url)))
    if isCompat() then
        sep = "?"
        if Instr(1, u, "?") > 0 then sep = "&"
        u = u + sep + "mode=roku720"
    end if
    c = CreateObject("roSGNode", "ContentNode")
    c.url = u
    c.title = ex.title
    c.live = true
    c.streamFormat = "ts"
    if ccUrl(ex.url) <> ex.url then c.streamFormat = "hls"
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.playIdx = -1
    m.retries = 0
    m.underruns = 0
    placesSoon()
end sub

function externInfo() as Object
    return { num: m.extern.num, name: m.extern.name, logo: "", title: m.extern.title, subtitle: "", times: "", pct: 0.0, nextText: "", rating: "" }
end function


' ============================================================ search
sub openSearch()
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if m.mode = "search" then return
    coverHome()
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
        if m.searchFrom = "guide" then
            openGuide(m.curIdx, invalid, "")
        else
            backToHome()
        end if
    else if ty = "channel" then
        searchWatch(req.num, req.name)
    else if ty = "vod" then
        ' a movie or an episode: its play menu over Search (no On Demand screen first); a show opens its page
        v = req.v
        if anyStr(v.kind) = "series" then
            closeSearch()
            openOnDemand({ showId: v.id })
        else if anyStr(v.kind) = "episode" then
            m.svod = v
            showDialog("svodep", anyStr(v.name), [anyStr(v["sub"])], ["Play", "All episodes", "Close"], ["play", "all", "close"])
        else
            openOdOverlay(anyStr(v.id))
        end if
    else if ty = "feed" then
        f = req.f
        if f.slot = true and f.status <> "ok" then
            showToast("That slot is empty or the event has ended")
            return
        end if
        closeSearch()
        m.returnHome = false
        if mvRoute({ f: f }) then return
        playExternal({ num: "EVENT", name: f.group, title: f.name, url: m.base + "/api/feed/stream?key=" + urlEncode(f.key), key: f.key })
        showBanner()
    else if ty = "program" then
        p = req.prog
        if p.start > nowEpoch() + 60 then
            m.srReq = { num: req.num, name: req.name, start: p.start, title: p.title }
            buttons = ["Watch channel now", "Cancel"]
            actions = ["watch", "cancel"]
            if m.dvrOn then
                buttons.Unshift("Record")
                actions.Unshift("record")
            end if
            showDialog("srec", p.title, [fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop), req.num + " " + req.name, "Hasn't started yet."], buttons, actions)
        else
            searchWatch(req.num, req.name)
        end if
    end if
end sub

' tune a channel number: from the loaded list if it's there, otherwise stream it straight from TunerBox
sub searchWatch(num as String, name as String)
    m.returnHome = false
    closeSearch()
    idx = chIndexByNum(num)
    if idx >= 0 then
        tuneTo(idx)
    else
        if mvRoute({ num: num, name: name }) then return
        playExternal({ num: num, name: name, title: name, url: m.base + "/api/stream/" + num })
        showBanner()
    end if
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
    if not m.dvrOn then
        showToast("Recordings are off. Turn them on in TunerBox Setup > Settings > DVR.")
        return
    end if
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "record"
    t.baseUrl = m.base
    t.recNumber = num
    t.recStart = startAt.ToStr()     ' Str() would send "1.794834e+09"
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
' dialogs in the theme's colours (as the web's dialogs)
function dialogPalette() as Object
    p = CreateObject("roSGNode", "RSGPalette")
    p.colors = {
        DialogBackgroundColor: thm("0x0B1D46FF"),
        DialogItemColor: thm("0xDCE8FFFF"),
        DialogTextColor: thm("0xDCE8FFFF"),
        DialogFocusColor: thm("0xFFC845FF"),
        DialogFocusItemColor: thm("0x111111FF"),
        DialogSecondaryTextColor: thm("0x9FB3DCFF"),
        DialogSecondaryItemColor: thm("0x4F86E8FF"),
        DialogInputFieldColor: thm("0x10244AFF"),
        DialogKeyboardColor: thm("0x10244AFF"),
        DialogFootprintColor: thm("0x9FB3DCFF")
    }
    return p
end function

sub showDialog(kind as String, title as String, message as Object, buttons as Object, actions as Object)
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.palette = dialogPalette()
    ' names and titles from playlists can hold characters the Roku font lacks (plainText)
    dlg.title = plainText(title)
    msg = []
    for each t in message
        msg.Push(plainText(t))
    end for
    dlg.message = msg
    btns = []
    for each b in buttons
        btns.Push(plainText(b))
    end for
    dlg.buttons = btns
    m.dlgKind = kind
    m.dlgActions = actions
    m.dlg = dlg
    dlg.observeFieldScoped("buttonSelected", "onDlgButton")
    dlg.observeFieldScoped("wasClosed", "onDlgClosed")
    m.top.dialog = dlg
end sub

sub showKeyboard(kind as String, title as String, message as Object, initial as String)
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.palette = dialogPalette()
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
        launchDialogDone()
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
    else if m.mode = "stats" then
        m.stats.setFocus(true)
    else if m.mode = "search" then
        m.search.setFocus(true)
    else if m.mode = "ondemand" then
        m.od.setFocus(true)
    else if m.mode = "home" then
        m.home.setFocus(true)
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
        else if action = "catchup" then
            playCatchup(m.channels[m.optReq.chIdx].numStr, m.optReq.prog)
        else if action = "record" then
            dvrRecord(m.optReq.chIdx, m.optReq.prog)
        else if action = "jump" then
            promptJump()
        else if Left(action, 2) = "od" and m.optOd <> invalid then
            odPickAct(m.optOd, Int(Val(Mid(action, 3))))
        end if
        m.optOd = invalid
    else if kind = "odprog" then
        od = m.odPick
        m.odPick = invalid
        if od <> invalid and Left(action, 2) = "od" then odPickAct(od, Int(Val(Mid(action, 3))))
    else if kind = "srec" then
        if m.srReq <> invalid then
            if action = "record" then
                dvrRecordRaw(m.srReq.num, m.srReq.start, m.srReq.title)
            else if action = "watch" then
                searchWatch(m.srReq.num, m.srReq.name)
            end if
        end if
        m.srReq = invalid
    else if kind = "gsw" then
        opts = m.gswOpts
        m.gswOpts = invalid
        if opts <> invalid and Left(action, 1) = "o" then
            i = Int(Val(Mid(action, 2)))
            if i >= 0 and i < opts.Count() then statsGo(opts[i])
        end if
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
    else if kind = "vodav" then
        if action = "audio" then
            avAudioMenu()
        else if action = "subs" then
            avSubsMenu()
        else if action = "cc" then
            toggleCaptions()
        end if
    else if kind = "vodaudio" then
        if Left(action, 1) = "a" then avPickAudio(Int(Val(Mid(action, 2))))
    else if kind = "vodsubs" then
        if action = "off" then
            avSubsOff()
        else if Left(action, 1) = "s" then
            avPickSub(Int(Val(Mid(action, 2))))
        end if
    else if kind = "hvod" or kind = "hrec" or kind = "hsched" then
        it = m.homeReq
        m.homeReq = invalid
        if it <> invalid then homeDialogAction(kind, action, it)
    else if kind = "svod" or kind = "svodep" then
        d = m.svod
        m.svod = invalid
        if d <> invalid and action <> "close" then searchVodAction(kind, action, d)
    else if kind = "menu" then
        runMenuAction(action)
    else if kind = "gmenu" then
        runGuideMenuAction(action)
    else if kind = "gcat" then
        if Left(action, 2) = "g:" and m.mode = "guide" then m.guide.callFunc("setGenre", Mid(action, 3))
    else if kind = "mvswap" then
        mvSwapAction(action)
    end if
end sub

sub onGuideTuneIdx(idx as Integer)
    closeGuide()
    tuneTo(idx)
end sub

sub promptHost()
    showKeyboard("host", "TunerBox server", ["Enter the IP address of the machine running TunerBox.", "Example: 192.168.1.50  (port 8642 is assumed)"], regRead("host", ""))
end sub

sub promptSearch()
    openSearch()
end sub

' Jump to channel: our own number pad (JumpPad), the same on every Roku
sub promptJump()
    m.hud.callFunc("hideAll")
    m.jump.callFunc("openPad")
end sub

sub onJumpResult()
    num = m.jump.result
    m.jump.callFunc("closePad")
    restoreFocus()
    if num = "" then return
    if m.mode = "guide" then
        m.guide.callFunc("jumpToNumber", num)
    else
        tuneNumber(num)
    end if
end sub

sub onJumpClose()
    m.jump.callFunc("closePad")
    restoreFocus()
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
    if isCompat() then return "ON"
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
    for each n in [m.sportsBasic, m.sportsEnh, m.search, m.od, m.menu, m.statusGroup, m.toast]
        n.scale = [m.fitScale, m.fitScale]
        n.translation = m.fitOff
    end for
    ' game stats draws itself at the fitted size (a scaled box over the game blurred its small text)
    m.stats.scale = [1.0, 1.0]
    m.stats.translation = m.fitOff
    m.stats.fit = m.fitScale
    ' Home and the live-TV bar / banner move into the safe area at full size and lay out inside it, so their
    ' text and pictures stay sharp (shrinking them blurs both)
    ins = [m.fitOff[0], m.fitOff[1], m.fitOff[0], m.fitOff[1]]
    for each n in [m.home, m.hud]
        n.scale = [1.0, 1.0]
        n.translation = m.fitOff
        n.safe = ins
    end for
    ' the guide re-flows into the safe area at full size instead of being shrunk
    m.guide.safe = [m.fitOff[0], m.fitOff[1], m.fitOff[0], m.fitOff[1]]
    if m.mode = "guide" or (m.mode = "fitcal" and m.calPrev = "guide") then setPreviewSize(true)
    if m.mode = "ondemand" then setOdPreview()
    if m.mode = "stats" then setStatsPreview()
    if m.mode = "home" or (m.mode = "fitcal" and m.calPrev = "home") then setPanelPreview(m.home)
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

' the main menu: what's used while watching; this Roku's settings and the rarely used items are under Settings
function menuItems() as Object
    items = []
    if m.homeOn then items.Push({ id: "home", label: "Home" })
    if m.mv <> invalid then
        items.Push({ id: "mv", label: "Multiview", value: "ON" })
    else if mvMaxPics() >= 2 and mvMainTile() <> invalid then
        items.Push({ id: "mv", label: "Multiview", value: "up to " + mvMaxPics().ToStr() })
    end if
    if canSwitchFeed() then
        ' which of the channel's own feeds is on, when it has backups ("1 of 3")
        v = ""
        if m.extern = invalid and chAlts(m.playIdx) > 0 then v = (m.alt + 1).ToStr() + " of " + (chAlts(m.playIdx) + 1).ToStr()
        items.Push({ id: "feeds", label: "Switch feed", value: v })
    end if
    items.Append([
        { id: "favorites", label: "Favorites" },
        { id: "gamestats", label: "Game stats & live scores" },
        { id: "jump", label: "Jump to channel #" },
        { id: "settings", label: "Settings" },
        { id: "close", label: "Close" }
    ])
    return items
end function

function settingsItems() as Object
    items = []
    if m.homeOn then items.Push({ id: "homestart", label: "Start on Home (this Roku)", value: onOff(homeAtStart()) })
    items.Append([
        { id: "cc", label: "Closed captions (all apps)", value: ccLabel() },
        { id: "compat", label: "720p mode (all channels)", value: compatLabel() },
        { id: "fmt", label: "Stream format", value: UCase(regRead("fmt", "auto")) },
        { id: "buffer", label: "Stream cache", value: bufferMenuLabel() },
        { id: "theme", label: "Theme", value: themeMenuLabel() },
        { id: "fit", label: "Screen fit (overscan)", value: fitLabel() },
        { id: "hideun", label: "Hide unmapped (20000+)", value: hideLabel() },
        { id: "leagues", label: "Live sports leagues", value: leaguesLabel() },
        { id: "reload", label: "Reload channels and guide" },
        { id: "server", label: "Change server address" },
        { id: "stats", label: "Stream stats" },
        { id: "about", label: "About" },
        { id: "setback", label: settingsBackLabel() }
    ])
    return items
end function

function settingsBackLabel() as String
    if m.settingsFrom = "more" then return "Back to More"
    return "Back to menu"
end function

sub showSettings()
    m.menuPage = "settings"
    m.menu.heading = "Settings"
    m.menu.items = settingsItems()
    m.menu.subtitle = "This Roku's settings. Server: " + m.base
    m.menu.callFunc("openMenu")
end sub

' ------------------------------------------------------------ switch feed
' A channel's own feeds (main and backups), and the other channels and event feeds showing the game that's
' on (TunerBox /api/sports/places, only in newer servers: without it, just the channel's own feeds)
function canSwitchFeed() as Boolean
    if m.vod <> invalid or m.rec <> invalid then return false
    if m.extern = invalid and m.playIdx >= 0 and chAlts(m.playIdx) > 0 then return true
    return placeOpts().Count() > 0
end function

' what's playing, as /api/sports/places is asked about it: "f:<feed key>", "c:<channel number>", "" nothing
function placesKey() as String
    if m.vod <> invalid or m.rec <> invalid then return ""
    if m.extern <> invalid then
        if m.extern.key <> invalid and anyStr(m.extern.key) <> "" then return "f:" + anyStr(m.extern.key)
        if anyStr(m.extern.num) <> "" and m.extern.num <> "EVENT" then return "c:" + anyStr(m.extern.num)
        return ""
    end if
    if m.playIdx >= 0 and m.playIdx < m.channels.Count() then return "c:" + m.channels[m.playIdx].numStr
    return ""
end function

' from playChannelFeed / playExternal: look the places up in a moment (not again for a retry or another
' feed of the same channel, which keep the key)
sub placesSoon()
    k = placesKey()
    if m.places <> invalid and m.places.key = k then return
    m.places = invalid
    m.placesTimer.control = "stop"
    if k <> "" then m.placesTimer.control = "start"
end sub

sub onPlacesTimer()
    loadPlaces(false)
end sub

' forMenu: Switch feed is waiting for the answer (swfDone)
sub loadPlaces(forMenu as Boolean)
    k = placesKey()
    if k = "" then return
    q = "ch="
    if Left(k, 2) = "f:" then q = "feed="
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = "/api/sports/places?" + q + urlEncode(Mid(k, 3))
    t.apiTimeout = 8000
    t.apiTag = "places"
    t.apiCtx = { key: k, menu: forMenu, seq: m.swfSeq }
    t.observeField("result", "onPlacesApi")
    if forMenu then m.placesMenuTask = t else m.placesTask = t
    t.control = "RUN"
end sub

' an older TunerBox has no /api/sports/places (404) or isn't following a game there: no places
sub onPlacesApi(event as Object)
    r = event.getData()
    if r = invalid or r.ctx = invalid then return
    if r.ctx.key = placesKey() then
        game = invalid
        if r.ok = true and Type(r.data) = "roAssociativeArray" and Type(r.data.game) = "roAssociativeArray" then game = r.data.game
        m.places = { key: r.ctx.key, game: game }
    end if
    if r.ctx.menu = true and m.swf <> invalid and r.ctx.seq = m.swf.seq then swfDone()
end sub

' the places other than what's on now, best first ({ ch } or { f }), for what's playing
function placeOpts() as Object
    k = placesKey()
    if k = "" or m.places = invalid or m.places.key <> k or m.places.game = invalid then return []
    skipNum = ""
    skipFeed = ""
    if Left(k, 2) = "f:" then skipFeed = Mid(k, 3) else skipNum = Mid(k, 3)
    return gameOpts(m.places.game, skipNum, skipFeed)
end function

function feedLabel(alt as Integer) as String
    if alt = 0 then return "Main"
    return "Backup " + alt.ToStr()
end function

' playlist names often carry decorations ("##### NEWS #####"): leave those out
function tidyFeedName(s as String) as String
    t = CreateObject("roRegex", "#{2,}", "").ReplaceAll(s, " ")
    t = CreateObject("roRegex", "\s{2,}", "").ReplaceAll(t, " ").Trim()
    if t = "" then return s
    return t
end function

' menu rows for a channel's feeds (/api/channels/{n}/feeds), "ON" by the one playing (onAlt; -1 none)
function feedItems(feeds as Object, onAlt as Integer) as Object
    items = []
    for i = 0 to feeds.Count() - 1
        f = feeds[i]
        if Type(f) <> "roAssociativeArray" then f = {}
        a = i
        if f.alt <> invalid then a = Int(numv(f.alt))
        lbl = feedLabel(a) + ": " + tidyFeedName(anyStr(f.name))
        if anyStr(f.source) <> "" then lbl = lbl + dotSep() + anyStr(f.source)
        if anyStr(f.status) = "dead" then lbl = lbl + " (failed last scan)"
        v = ""
        if a = onAlt then v = "ON"
        items.Push({ id: "fd_" + a.ToStr(), label: lbl, value: v })
    end for
    return items
end function

' menu rows for the other places showing the game (pl_<i> plays m.placeOpts[i])
function placeItems(opts as Object) as Object
    items = []
    for i = 0 to opts.Count() - 1
        op = opts[i]
        if op.ch <> invalid then
            nm = anyStr(op.ch.label)
            if nm = "" then nm = anyStr(op.ch.name)
            items.Push({ id: "pl_" + i.ToStr(), label: numToStr(op.ch.number) + " " + nm, value: "CH" })
        else
            lbl = plainText(anyStr(op.f.name))
            if anyStr(op.f.group) <> "" then lbl = lbl + dotSep() + anyStr(op.f.group)
            v = "FEED"
            if anyStr(op.f.status) = "ok" then v = "LIVE"
            items.Push({ id: "pl_" + i.ToStr(), label: lbl, value: v })
        end if
    end for
    return items
end function

' the channel's feeds come from TunerBox each time, so they follow Setup's current order; the places are
' asked again too. Both answers in, the list shows (swfDone)
sub showFeeds()
    k = placesKey()
    if k = "" then return
    m.swfSeq = m.swfSeq + 1
    m.swf = { key: k, idx: -1, wait: 1, feeds: invalid, seq: m.swfSeq }
    if m.extern = invalid and m.playIdx >= 0 then
        m.swf.idx = m.playIdx
        m.swf.wait = 2
        t = CreateObject("roSGNode", "LoadTask")
        t.mode = "api"
        t.baseUrl = m.base
        t.apiPath = "/api/channels/" + m.channels[m.playIdx].numStr + "/feeds"
        t.apiTag = "feeds"
        t.apiCtx = { key: k, seq: m.swfSeq }
        t.observeField("result", "onFeedsApi")
        m.feedTask = t
        t.control = "RUN"
    end if
    loadPlaces(true)
end sub

sub onFeedsApi(event as Object)
    r = event.getData()
    if r = invalid or r.ctx = invalid or m.swf = invalid or r.ctx.seq <> m.swf.seq then return
    if r.ok = true and Type(r.data) = "roArray" and r.data.Count() > 0 then m.swf.feeds = r.data
    swfDone()
end sub

sub swfDone()
    s = m.swf
    if s = invalid then return
    s.wait = s.wait - 1
    if s.wait > 0 then return
    m.swf = invalid
    if s.key <> placesKey() then return          ' changed channel meanwhile
    ' the answers can be slow: not when another screen, a dialog or the menu is up by then
    if m.mode <> "live" or m.dlg <> invalid or m.menu.visible then return
    isFeed = (m.extern <> invalid)
    own = []
    if s.feeds <> invalid and s.idx >= 0 and s.idx = m.playIdx then
        m.channels[s.idx].alts = s.feeds.Count() - 1     ' Setup may have changed them since the list loaded
        if s.feeds.Count() > 1 then own = s.feeds
    end if
    m.placeOpts = placeOpts()
    others = m.placeOpts.Count()
    if own.Count() = 0 and others = 0 then
        if isFeed then
            showToast("Nothing else has this game")
        else if s.feeds = invalid then
            showToast("Can't list this channel's feeds")
        else
            showToast("This channel has only one feed now")
        end if
        return
    end if
    items = feedItems(own, m.alt)
    items.Append(placeItems(m.placeOpts))
    if m.feedsFrom = "more" then items.Push({ id: "fdback", label: "Back to More" }) else items.Push({ id: "fdback", label: "Back to menu" })
    what = "this game"
    if m.places <> invalid and m.places.game <> invalid and anyStr(m.places.game.name) <> "" then what = anyStr(m.places.game.name)
    if own.Count() > 0 and others > 0 then
        blurb = "Pick a feed of this channel, or another place showing " + what + "."
    else if own.Count() > 0 then
        blurb = "Pick a feed to watch it now. Setup > Channels sets which one plays first."
    else if others = 1 then
        blurb = "One other place has " + what + ". If this one doesn't work, try it."
    else
        blurb = others.ToStr() + " other places have " + what + ". If this one doesn't work, try the next."
    end if
    m.hud.callFunc("hideAll")
    m.menuPage = "feeds"
    if isFeed then
        m.menu.heading = "Switch feed: " + plainText(anyStr(m.extern.title))
    else
        ch = m.channels[m.playIdx]
        m.menu.heading = "Switch feed: " + ch.numStr + " " + ch.name
    end if
    m.menu.subtitle = blurb
    m.menu.items = items
    m.menu.callFunc("openMenu")
end sub

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
    items.Push({ id: "lgback", label: "Back to settings" })
    return items
end function

sub showLeagues()
    m.menuPage = "leagues"
    m.menu.heading = "Live sports leagues"
    m.menu.items = leagueItems()
    m.menu.subtitle = "Games from these leagues are matched to your guide in Sports > On Now / Coming Up"
    m.menu.callFunc("openMenu")
end sub

' ------------------------------------------------------------ colour theme (settings page inside the menu)
' As the web TV screens: TunerBox's Setup > Settings > Screens > Theme is the default for every screen, and this
' Roku can pick its own in Menu > Theme.
function themeMenuLabel() as String
    lbl = themeLabel(themeName())
    if regRead("theme", "") = "" then return lbl + " (default)"
    return lbl
end function

function themeItems() as Object
    own = regRead("theme", "")
    def = themeLabel(regRead("themeServer", "midnight"))
    items = [{ id: "th_", label: "Use the default (" + def + ")", value: onOff(own = "") }]
    for each t in themeList()
        items.Push({ id: "th_" + t[0], label: t[1], value: onOff(own = t[0]) })
    end for
    items.Push({ id: "thback", label: "Back to settings" })
    return items
end function

sub showThemes()
    m.menuPage = "themes"
    m.menu.heading = "Theme"
    m.menu.items = themeItems()
    m.menu.subtitle = "Colours for this Roku. TunerBox's Setup > Settings > Screens sets the default."
    m.menu.callFunc("openMenu")
end sub

' recolour everything on screen from the current theme to another
sub applyTheme(name as String)
    if not themeValid(name) then name = "midnight"
    old = themeName()
    if old = name then return
    m.global.theme = name
    themeWalk(m.top, themeReverse(themeMap(old)), themeMap(name), true)
    if m.mode = "home" then m.home.callFunc("reload")
end sub

' ------------------------------------------------------------ stream cache (settings page inside the menu)
' As the web TV screens: TunerBox's Setup > Settings > Stream cache is the default for every screen, and this
' Roku can pick its own here. The server holds back that many seconds before it starts sending, so a stream
' that hiccups plays from the cache instead of freezing; each channel change takes that long to start.
function bufferChoices() as Object
    return [0, 5, 10, 20, 30, 60]
end function

function bufferLabel(secs as Integer) as String
    if secs <= 0 then return "Off"
    return secs.ToStr() + " seconds"
end function

' this Roku's own choice ("" = use the server's default)
function bufferOwn() as String
    return regRead("buffer", "")
end function

function bufferSecs() as Integer
    v = bufferOwn()
    if v = "" then v = regRead("bufferServer", "0")
    return Int(Val(v))
end function

function bufferMenuLabel() as String
    lbl = bufferLabel(bufferSecs())
    if bufferOwn() = "" then return lbl + " (default)"
    return lbl
end function

function bufferItems() as Object
    own = bufferOwn()
    def = bufferLabel(Int(Val(regRead("bufferServer", "0"))))
    items = [{ id: "buf_", label: "Use the default (" + def + ")", value: onOff(own = "") }]
    for each b in bufferChoices()
        lbl = bufferLabel(b)
        if b = 0 then lbl = "Off: fastest channel changes"
        items.Push({ id: "buf_" + b.ToStr(), label: lbl, value: onOff(own = b.ToStr()) })
    end for
    items.Push({ id: "bufback", label: "Back to settings" })
    return items
end function

sub showBuffers()
    m.menuPage = "buffer"
    m.menu.heading = "Stream cache"
    m.menu.items = bufferItems()
    m.menu.subtitle = "Keeps more video ready so a slow or hiccuping stream doesn't freeze. Bigger = smoother, but each channel change takes that long to start."
    m.menu.callFunc("openMenu")
end sub

' tells TunerBox which Roku a live channel or event stream is for: Setup > Tuners shows this Roku's name,
' and changing channel lets go of the one it was on (so a 1-connection account can change channels)
function withDevice(u as String) as String
    if Left(u, Len(m.base)) <> m.base then return u
    if Instr(1, u, "/api/stream/") = 0 and Instr(1, u, "/api/hls/") = 0 and Instr(1, u, "/api/feed/") = 0 then return u
    if Instr(1, u, "client=") > 0 then return u
    sep = "?"
    if Instr(1, u, "?") > 0 then sep = "&"
    return u + sep + "client=" + urlEncode(vodClientId()) + "&name=" + urlEncode(deviceName())
end function

' adds this Roku's stream cache to a live channel or event stream from TunerBox (without one, the server
' uses its own default)
function withBuffer(u as String) as String
    own = bufferOwn()
    if own = "" then return u
    if Left(u, Len(m.base)) <> m.base then return u
    if Instr(1, u, "/api/stream/") = 0 and Instr(1, u, "/api/hls/") = 0 and Instr(1, u, "/api/feed/") = 0 then return u
    sep = "?"
    if Instr(1, u, "?") > 0 then sep = "&"
    return u + sep + "buf=" + own
end function

' restart what's playing live so a new stream cache takes effect
sub retuneLive()
    if m.vod <> invalid or m.mode = "rec" then return
    if m.extern <> invalid then
        playExternal(m.extern)
    else if m.playIdx >= 0 then
        playChannel(m.playIdx)
    end if
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

' Back: a page of Settings goes back to Settings, Settings and Switch feed to the menu, the menu closes
sub onMenuClose()
    if mvMenuBack() then return
    if m.menuPage = "leagues" or m.menuPage = "themes" or m.menuPage = "buffer" then
        showSettings()
        return
    end if
    if m.menuPage = "feeds" then
        feedsBack()
        return
    end if
    if m.menuPage = "settings" then
        settingsBack()
        return
    end if
    closeMenuView()
end sub

' Settings' Back: to More or the menu, whichever opened it
sub settingsBack()
    if m.settingsFrom = "more" then showMore() else showMenu()
end sub

' Switch feed's Back: to More or the menu, whichever opened it
sub feedsBack()
    if m.feedsFrom = "more" then showMore() else showMenu()
end sub

sub onMenuSelected()
    id = m.menu.selected
    if mvMenuSelected(id) then return
    if m.menuPage = "leagues" then
        if Left(id, 3) = "lg_" then
            toggleLeague(Mid(id, 4))
            m.menu.items = leagueItems()
        else if id = "lgmissing" then
            if regRead("sportsUnmatched", "1") = "1" then regWrite("sportsUnmatched", "0") else regWrite("sportsUnmatched", "1")
            m.menu.items = leagueItems()
        else if id = "lgback" then
            showSettings()
        end if
        return
    end if
    if m.menuPage = "themes" then
        if Left(id, 3) = "th_" then
            regWrite("theme", Mid(id, 4))
            applyTheme(themeChosen())
            m.menu.items = themeItems()
        else if id = "thback" then
            showSettings()
        end if
        return
    end if
    if m.menuPage = "feeds" then
        if Left(id, 3) = "fd_" then
            alt = Int(Val(Mid(id, 4)))
            closeMenuView()
            if alt <> m.alt and m.playIdx >= 0 then
                showToast(m.channels[m.playIdx].numStr + ": " + LCase(feedLabel(alt)) + " feed")
                playChannelFeed(m.playIdx, alt)
            end if
        else if Left(id, 3) = "pl_" then
            ' another channel or event feed showing the game
            i = Int(Val(Mid(id, 4)))
            opts = m.placeOpts
            m.placeOpts = []
            closeMenuView()
            if i >= 0 and i < opts.Count() then
                op = opts[i]
                if op.ch <> invalid then
                    watchChannelNum(numToStr(op.ch.number), anyStr(op.ch.name))
                else
                    watchFeed(op.f)
                end if
            end if
        else if id = "fdback" then
            feedsBack()
        end if
        return
    end if
    if m.menuPage = "more" then
        if id = "feeds" then
            m.feedsFrom = "more"
            closeMenuView()
            showFeeds()
        else if id = "settings" then
            m.settingsFrom = "more"
            showSettings()
        else if id = "close" then
            closeMenuView()
        else if id = "mv" then
            closeMenuView()
            runMenuAction("mv")
        else
            closeMenuView()
            hudAction(id)
        end if
        return
    end if
    if m.menuPage = "buffer" then
        if Left(id, 4) = "buf_" then
            regWrite("buffer", Mid(id, 5))
            m.menu.items = bufferItems()
            showToast("Stream cache: " + bufferLabel(bufferSecs()))
            retuneLive()
        else if id = "bufback" then
            showSettings()
        end if
        return
    end if
    if m.menuPage = "settings" then
        if id = "leagues" then
            showLeagues()
        else if id = "buffer" then
            showBuffers()
        else if id = "theme" then
            showThemes()
        else if id = "fmt" or id = "compat" or id = "homestart" or id = "cc" then
            ' toggles keep Settings open and refresh the value in place
            runMenuAction(id)
            m.menu.items = settingsItems()
        else if id = "setback" then
            settingsBack()
        else
            closeMenuView()
            runMenuAction(id)
        end if
        return
    end if
    if id = "feeds" then
        m.feedsFrom = "main"
        closeMenuView()
        showFeeds()
    else if id = "settings" then
        m.settingsFrom = "main"
        showSettings()
    else if id = "close" then
        closeMenuView()
    else
        closeMenuView()
        runMenuAction(id)
    end if
end sub

sub runMenuAction(action as String)
    if action = "mv" then
        mvOpen()
    else if action = "home" then
        openHome()
    else if action = "homestart" then
        if homeAtStart() then regWrite("homeStart", "0") else regWrite("homeStart", "1")
    else if action = "server" then
        promptHost()
    else if action = "reload" then
        m.useCache = false
        loadAll()
    else if action = "favorites" then
        openFavorites()
    else if action = "gamestats" then
        openStats()
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
    else if action = "cc" then
        toggleCaptions()
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
        ' the manifest's version (major.minor.build), so it's easy to see which build is installed
        appInfo = CreateObject("roAppInfo")
        showDialog("info", "About", ["TunerBox TV " + appInfo.GetVersion(), "Server: " + m.base, "Channels: " + m.channels.Count().ToStr() + "   With guide data: " + m.epgCount.ToStr()], ["OK"], ["close"])
    end if
end sub

' ============================================================ On Demand (browse screen)
' args: {} | { kind } | { showId } | { movieId } | { episode } (see OnDemandView.openOD)
sub openOnDemand(args as Object)
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" then return
    if not m.vodOn then
        showToast("On Demand is off: no playlist or library in TunerBox has it")
        return
    end if
    coverHome()
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if m.mode = "vod" then vodStop(false)
    m.hud.callFunc("hideAll")
    m.odOverlay = false
    m.mode = "ondemand"
    m.od.baseUrl = m.base
    m.od.callFunc("openOD", args)
    setOdPreview()
end sub

' live TV keeps playing in the panel's corner
sub setOdPreview()
    setPanelPreview(m.od)
end sub

' a panel's live-TV corner (its previewRect, in the panel's own coordinates) on screen
sub setPanelPreview(view as Object)
    pr = view.previewRect
    if pr = invalid or pr.Count() <> 4 then return
    if pr[2] >= 1920 then
        ' full screen behind the panel (Home): the whole picture, not fitted to the safe area
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
        return
    end if
    s = m.fitScale
    m.video.translation = [m.fitOff[0] + Int(pr[0] * s), m.fitOff[1] + Int(pr[1] * s)]
    m.video.width = Int(pr[2] * s)
    m.video.height = Int(pr[3] * s)
end sub

sub closeOnDemand()
    m.od.callFunc("closeOD")
    pvResume()          ' live TV paused for Pick a version: back on
    setPreviewSize(false)
    m.mode = "live"
    m.top.setFocus(true)
end sub

' a movie picked in Search or on Home: On Demand's movie panel (and Pick a version) over the Search screen
sub openOdOverlay(id as String)
    m.odOverlay = true
    m.od.baseUrl = m.base
    m.od.callFunc("openMovie", { id: id })
end sub

sub endOdOverlay()
    if not truthy(m.odOverlay) then return
    m.odOverlay = false
    m.od.callFunc("closeOD")
    pvResume()          ' live TV paused for Pick a version: back on
    restoreFocus()      ' Search or Home, where it was opened
end sub

sub onOdRequest()
    req = m.od.request
    if req = invalid then return
    ty = req.type
    if ty = "changed" then
        ' My List / watched / Continue Watching changed from the panel over Home: its rows again
        if m.mode = "home" then m.home.callFunc("reload")
        return
    end if
    if truthy(m.odOverlay) then
        if ty = "overlayDone" then
            endOdOverlay()
        else if ty = "toast" then
            showToast(req.text)
        else if ty = "pvhold" then
            m.od.pvHeld = pvHold()
        else if ty = "pvresume" then
            pvResume()
        else if ty = "play" then
            endOdOverlay()
            playVod(req.id, req.start, false)
        end if
        return
    end if
    if m.mode <> "ondemand" then return
    if ty = "close" then
        closeOnDemand()
        if not backToHome() then showBanner()
    else if ty = "toast" then
        showToast(req.text)
    else if ty = "dialog" then
        showDialog("vod", req.title, req.message, req.buttons, req.actions)
    else if ty = "pvhold" then
        m.od.pvHeld = pvHold()
    else if ty = "pvresume" then
        pvResume()
    else if ty = "keyboard" then
        showKeyboard("vodsearch", "Search On Demand", ["A title, a year or an actor"], req.text)
    else if ty = "play" then
        playVod(req.id, req.start, true)
    end if
end sub

' Pick a version needs the playlist's connection that the live-TV preview holds: stop the preview for the
' reads (On Demand tells TunerBox it's let go). -> true when there was a live channel to stop. An event
' feed has no channel to go back to: left playing.
function pvHold() as Boolean
    if m.vod <> invalid or m.rec <> invalid or m.extern <> invalid or m.playIdx < 0 then return false
    st = m.video.state
    if st <> "playing" and st <> "buffering" and st <> "paused" then return false
    m.retryTimer.control = "stop"
    m.video.control = "stop"
    m.pvHeldIdx = m.playIdx
    showToast("Live TV paused while the versions are read")
    return true
end function

' the reads are done (or the dialog was closed): the channel comes back on, unless something else started
sub pvResume()
    idx = m.pvHeldIdx
    m.pvHeldIdx = -1
    if idx = invalid or idx < 0 then return
    if m.vod <> invalid or m.rec <> invalid or m.extern <> invalid or m.playIdx <> idx then return
    st = m.video.state
    if st = "playing" or st = "buffering" then return
    playChannel(idx)
end sub

' small GET / POST to TunerBox for playback (results come back in onVodApi)
sub vodApi(tag as String, path as String, body as Dynamic, ctx as Object)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = path
    if tag = "vodsubs" then t.apiTimeout = 150000
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
    if r = invalid then return
    if r.tag = "vodtracks" then
        gotTracks(r)
        return
    else if r.tag = "vodsubs" then
        gotSubs(r)
        return
    else if r.tag = "odprog" then
        gotOdProg(r)
        return
    end if
    if r.tag <> "vodplay" then return
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

' ============================================================ audio tracks and subtitles
' Titles from your own libraries (TunerBox /api/vod/tracks): * while one plays picks the audio track (the
' stream restarts at the same spot with &a=) or subtitles (timed lines from /api/vod/subs, drawn here over the
' picture by the title's position, so they stay in step after a skip). The choice is kept per movie or show
' (an episode picks the same language as the last one), for the 40 titles played most recently.
function avKey(it as Object) as String
    k = anyStr(it.title_id)
    if k = "" then k = anyStr(it.id)
    return k
end function

function avAll() as Object
    d = invalid
    txt = regRead("avPrefs", "")
    if txt <> "" then d = ParseJson(txt)
    if Type(d) <> "roAssociativeArray" then d = {}
    if Type(d.order) <> "roArray" then d.order = []
    if Type(d.t) <> "roAssociativeArray" then d.t = {}
    return d
end function

' before the first stream: the audio track (and subtitles) picked last time for this movie or show
sub avInit(v as Object)
    p = avAll().t[avKey(v.it)]
    if Type(p) <> "roAssociativeArray" then return
    v.audio = Int(numv(p.a))
    if Type(p.s) = "roAssociativeArray" then v.subPick = p.s
end sub

sub avSave(v as Object)
    if v.cu then return
    s = invalid
    if v.sub <> invalid then s = { label: anyStr(v.sub.label), lang: anyStr(v.sub.lang), forced: truthy(v.sub.forced) }
    d = avAll()
    k = avKey(v.it)
    d.t[k] = { a: v.audio, s: s }
    order = []
    for each x in d.order
        if x <> k then order.Push(x)
    end for
    order.Push(k)
    while order.Count() > 40
        d.t.Delete(order.Shift())
    end while
    d.order = order
    regWrite("avPrefs", FormatJson(d))
end sub

function avHas(v as Dynamic) as Boolean
    if v = invalid or v.tracks = invalid then return false
    return v.tracks.audio.Count() > 1 or v.tracks.subs.Count() > 0
end function

function avAudioLabel(v as Object) as String
    for each a in v.tracks.audio
        if Int(numv(a.n)) = v.audio then return anyStr(a.label)
    end for
    return ""
end function

' GET /api/vod/tracks: { audio: [{ n, label }], subs: [{ id, label, lang, forced, picture }] } (empty for playlist titles)
sub gotTracks(r as Object)
    v = m.vod
    if v = invalid or r.ctx = invalid or r.ctx.seq <> m.vodSeq then return
    d = r.data
    if not r.ok or Type(d) <> "roAssociativeArray" or Type(d.audio) <> "roArray" or Type(d.subs) <> "roArray" then return
    v.tracks = d
    if v.audio > 0 and v.audio >= d.audio.Count() then
        ' this episode has fewer tracks than the one the choice was made on
        v.audio = 0
        vodStart(vodPos())
    end if
    p = v.subPick
    if p <> invalid then
        s = invalid
        for each x in d.subs
            if not truthy(x.picture) and anyStr(x.label) = anyStr(p.label) then
                s = x
                exit for
            end if
        end for
        if s = invalid and anyStr(p.lang) <> "" then
            for each x in d.subs
                if not truthy(x.picture) and anyStr(x.lang) = anyStr(p.lang) and truthy(x.forced) = truthy(p.forced) then
                    s = x
                    exit for
                end if
            end for
        end if
        if s <> invalid then subsOn(s, true)
    end if
end sub

sub avMenu()
    v = m.vod
    if not avHas(v) then return
    buttons = []
    actions = []
    if v.tracks.audio.Count() > 1 then
        buttons.Push("Audio: " + plainText(avAudioLabel(v)))
        actions.Push("audio")
    end if
    if v.tracks.subs.Count() > 0 then
        sl = "Off"
        if v.sub <> invalid then sl = anyStr(v.sub.label)
        buttons.Push("Subtitles: " + plainText(sl))
        actions.Push("subs")
    end if
    buttons.Push("Closed captions: " + ccLabel())
    actions.Push("cc")
    buttons.Push("Close")
    actions.Push("close")
    showDialog("vodav", anyStr(v.it.title), ["This title"], buttons, actions)
end sub

sub avAudioMenu()
    v = m.vod
    if v = invalid or v.tracks = invalid then return
    buttons = []
    actions = []
    for each a in v.tracks.audio
        n = Int(numv(a.n))
        lbl = plainText(anyStr(a.label))
        if n = v.audio then lbl = lbl + "   (playing)"
        buttons.Push(lbl)
        actions.Push("a" + n.ToStr())
    end for
    showDialog("vodaudio", "Audio", [anyStr(v.it.title)], buttons, actions)
end sub

sub avPickAudio(n as Integer)
    v = m.vod
    if v = invalid or v.tracks = invalid or n = v.audio then return
    v.audio = n
    avSave(v)
    showToast("Audio: " + plainText(avAudioLabel(v)))
    vodStart(vodPos())          ' the same spot, with that track
end sub

sub avSubsMenu()
    v = m.vod
    if v = invalid or v.tracks = invalid then return
    cur = ""
    if v.sub <> invalid then cur = anyStr(v.sub.id)
    lbl = "Off"
    if cur = "" then lbl = "Off   (on)"
    buttons = [lbl]
    actions = ["off"]
    for i = 0 to v.tracks.subs.Count() - 1
        s = v.tracks.subs[i]
        lbl = plainText(anyStr(s.label))
        if truthy(s.picture) then
            lbl = lbl + " (picture subtitles: not available yet)"
        else if anyStr(s.id) = cur then
            lbl = lbl + "   (on)"
        end if
        buttons.Push(lbl)
        actions.Push("s" + i.ToStr())
    end for
    showDialog("vodsubs", "Subtitles", [anyStr(v.it.title)], buttons, actions)
end sub

sub avPickSub(i as Integer)
    v = m.vod
    if v = invalid or v.tracks = invalid or i < 0 or i >= v.tracks.subs.Count() then return
    s = v.tracks.subs[i]
    if truthy(s.picture) then
        showToast("Picture subtitles (PGS, VobSub) can't be shown yet. Pick a text track if there is one.")
        return
    end if
    subsOn(s, false)
    avSave(v)
end sub

sub avSubsOff()
    v = m.vod
    if v = invalid then return
    v.sub = invalid
    v.cues = invalid
    m.subsTimer.control = "stop"
    subsShow("")
    ccApply()
    avSave(v)
end sub

sub subsOn(s as Object, quiet as Boolean)
    v = m.vod
    v.sub = s
    v.cues = invalid
    subsShow("")
    ccApply()
    if not quiet then showToast("Loading subtitles... (the first time takes a minute for a long film)")
    vodApi("vodsubs", "/api/vod/subs/" + urlEncode(v.id) + "/" + urlEncode(anyStr(s.id)), invalid, { seq: m.vodSeq, sid: anyStr(s.id), quiet: quiet })
end sub

' GET /api/vod/subs: { cues: [[start, end, text]] } (seconds into the title)
sub gotSubs(r as Object)
    v = m.vod
    if v = invalid or r.ctx = invalid or r.ctx.seq <> m.vodSeq or v.sub = invalid or anyStr(v.sub.id) <> r.ctx.sid then return
    d = r.data
    if not r.ok or Type(d) <> "roAssociativeArray" or Type(d.cues) <> "roArray" then
        v.sub = invalid
        ccApply()
        if not r.ctx.quiet then
            why = ""
            if Type(d) = "roAssociativeArray" and d.detail <> invalid then why = ": " + anyStr(d.detail)
            showToast("Can't show those subtitles" + why)
        end if
        return
    end if
    v.cues = d.cues
    if not r.ctx.quiet then showToast("Subtitles: " + plainText(anyStr(v.sub.label)))
    m.subsTimer.control = "start"
    subsTick()
end sub

' the lines on screen at the title's position (several when they overlap)
sub subsTick()
    v = m.vod
    txt = ""
    if v <> invalid and v.cues <> invalid and m.mode = "vod" and v.target < 0 and not v.parked and not v.done then
        c = v.cues
        t = vodPos()
        lo = 0
        hi = c.Count() - 1
        i = -1
        while lo <= hi
            mid = Int((lo + hi) / 2)
            if numv(c[mid][0]) <= t then
                i = mid
                lo = mid + 1
            else
                hi = mid - 1
            end if
        end while
        lines = []
        j = i
        while j >= 0 and j > i - 6
            if numv(c[j][1]) > t then lines.Unshift(anyStr(c[j][2]))
            j = j - 1
        end while
        txt = lines.Join(Chr(10))
        txt = txt.Replace("<i>", "")
        txt = txt.Replace("</i>", "")
    end if
    subsShow(txt)
end sub

sub subsShow(txt as String)
    if txt = "" then
        if m.subs.visible then m.subs.visible = false
        return
    end if
    if m.subs.visible and m.subsLbl.text = txt then return
    ' as wide as the longest line (up to 1500, then it wraps), centred, with a dark box behind it
    lbl = m.subsLbl
    lbl.wrap = false
    lbl.width = 0
    w = 0
    for each ln in txt.Split(Chr(10))
        lbl.text = ln
        lw = Int(lbl.boundingRect().width)
        if lw > w then w = lw
    end for
    if w > 1500 then w = 1500
    if w < 40 then w = 40
    lbl.width = w + 4
    lbl.wrap = true
    lbl.text = txt
    h = Int(lbl.boundingRect().height)
    y = 1000 - h
    x = 960 - Int(w / 2)
    lbl.translation = [x - 2, y]
    m.subsBg.translation = [x - 20, y - 8]
    m.subsBg.width = w + 40
    m.subsBg.height = h + 16
    m.subs.visible = true
end sub

' ============================================================ catch-up TV
' A channel whose playlist keeps an archive can play shows that already aired, and the one on now from the
' beginning. They play in the On Demand player as the title "cu-<channel>-<start>" (TunerBox catchup.py).
function cuDaysOf(num as String) as Integer
    if m.cuDays = invalid then return 0
    return Int(numv(m.cuDays[num]))
end function

function cuDaysText(d as Integer) as String
    if d = 1 then return "1 DAY"
    return d.ToStr() + " DAYS"
end function

' is this show in the channel's archive? (started at least a minute ago, and not too long ago)
function cuAvailable(num as String, p as Dynamic) as Boolean
    if p = invalid then return false
    d = cuDaysOf(num)
    t = nowEpoch()
    st = epochOf(p.start)
    return d > 0 and st <= t - 60 and st >= t - d * 86400
end function

sub playCatchup(num as String, p as Dynamic)
    if not cuAvailable(num, p) then
        if cuDaysOf(num) > 0 then
            showToast("That show is no longer in the channel's archive")
        else
            showToast("Channel " + num + " has no catch-up")
        end if
        return
    end if
    st = epochOf(p.start)
    playVod("cu-" + num + "-" + st.ToStr(), 0, false)
end sub

' ============================================================ the show in On Demand
' A movie or episode on a channel that's also in On Demand: watch it there from the beginning, carry on from
' about where the broadcast is, or resume where you stopped (as the web TV). TunerBox looks it up:
' GET /api/vod/for-program/<channel>/<start> -> { match: invalid | { show } | { id, kind, title, sub,
' duration, position }, slot }. Only richakev's fork has it: pasiegel's TunerBox (v1.9.2 and older, main)
' answers 404, so there are no On Demand choices, and it isn't asked again for 10 minutes.
function odProgKey(num as String, p as Object) as String
    return num + "-" + epochOf(p.start).ToStr()
end function

' can this channel's show be looked up? (whole channel numbers only: the endpoint takes an int)
function odProgCan(num as String, p as Dynamic) as Boolean
    if not m.vodOn or p = invalid or anyStr(p.title) = "" or num = "" then return false
    if m.odProgOff > 0 and nowEpoch() - m.odProgOff < 600 then return false
    r = CreateObject("roRegex", "^[0-9]+$", "")
    return r.IsMatch(num)
end function

' the answer as last heard (5 minutes): { m: match or invalid }, or invalid when it has to be asked
function odProgCached(num as String, p as Object) as Dynamic
    c = m.odProg[odProgKey(num, p)]
    if c <> invalid and nowEpoch() - c.t < 300 then return c
    return invalid
end function

sub odProgAsk(num as String, p as Object, why as String)
    key = odProgKey(num, p)
    if m.odProg.Count() > 200 then m.odProg = {}
    vodApi("odprog", "/api/vod/for-program/" + num + "/" + epochOf(p.start).ToStr(), invalid, { key: key, why: why })
end sub

sub gotOdProg(r as Object)
    ctx = r.ctx
    mt = invalid
    if r.ok and Type(r.data) = "roAssociativeArray" then
        if Type(r.data.match) = "roAssociativeArray" then mt = r.data.match
        m.odProgOff = 0                 ' it answers: an earlier miss was only a hiccup
    else
        m.odProgOff = nowEpoch()        ' an older TunerBox without it (or it didn't answer)
    end if
    m.odProg[ctx.key] = { t: nowEpoch(), m: mt }
    if ctx.why = "opts" then
        if m.optWait <> invalid and m.optWait.key = ctx.key then optWaitDone()
    else if ctx.why = "hud" then
        if m.odHudAsking = ctx.key then m.odHudAsking = ""
        odHudSync(false)
    end if
end sub

' how far into the On Demand copy the broadcast is now: the time since it started, less the adverts' share
' (a 42-minute episode in an hour's slot is 30 minutes in after 43 minutes on the air)
function odSpot(mt as Object, p as Object) as Float
    n = nowEpoch()
    st = epochOf(p.start)
    sp = epochOf(p.stop)
    if n < st or n >= sp then return 0
    slot = sp - st
    if slot < 1 then slot = 1
    dur = numv(mt.duration)
    at = (n - st) * 1.0
    if dur > 0 and slot > dur then at = at * dur / slot
    if dur > 0 and at > dur - 60 then at = dur - 60
    if at < 0 then at = 0
    return at
end function

' what can be done with it: [{ id: show | start | here | resume, at }] ([] when it isn't in On Demand)
function odChoices(mt as Dynamic, p as Object) as Object
    out = []
    if mt = invalid then return out
    if mt.show <> invalid then
        out.Push({ id: "show", at: 0 })
        return out
    end if
    if anyStr(mt.id) = "" then return out
    at = odSpot(mt, p)
    out.Push({ id: "start", at: 0 })
    if at > 60 then out.Push({ id: "here", at: at })
    ps = numv(mt.position)
    if ps > 30 and Abs(ps - at) > 120 then out.Push({ id: "resume", at: ps })
    return out
end function

' the guide dialog's wording (long), or the player bar's (short)
function odChoiceLabel(c as Object, mt as Object, short as Boolean) as String
    if short then
        if c.id = "show" then return "Find this show"
        if c.id = "start" then return "Start from the beginning"
        if c.id = "here" then return "Continue" + dotSep() + fmtDur(c.at) + " in"
        return "Resume" + dotSep() + fmtDur(c.at)
    end if
    if c.id = "show" then return "Find this show in On Demand"
    if c.id = "start" then
        what = "this movie"
        if anyStr(mt.kind) = "episode" then
            ep = anyStr(mt["sub"]).Split(" " + Chr(183) + " ")[0]
            what = "this episode"
            if ep <> invalid and ep <> "" then what = what + " (" + ep + ")"
        end if
        return "Watch " + what + " On Demand from the beginning"
    end if
    if c.id = "here" then return "Continue On Demand from here (about " + fmtDur(c.at) + " in)"
    return "Resume On Demand where you stopped (" + fmtDur(c.at) + ")"
end function

function odWhat(mt as Object) as String
    if mt.show <> invalid then return "This show is in On Demand"
    if anyStr(mt.kind) = "episode" then return "This episode is in On Demand"
    return "This movie is in On Demand"
end function

' a choice picked: On Demand's page for the show, or play it (Back / Stop: back to the channel)
sub odPickAct(od as Object, i as Integer)
    if i >= 0 and i < od.choices.Count() then odAct(od.choices[i], od.mt)
end sub

sub odAct(c as Object, mt as Object)
    if c.id = "show" then
        openOnDemand({ showId: anyStr(mt.show) })
    else
        playVod(anyStr(mt.id), c.at, false)
    end if
end sub

' ------------------------------------------------------------ on the player bar, and under More
' A "Watch On Demand" button before More, only while the show on now is in On Demand; it opens its choices.
' showBanner and OK (the bar) call odHudSync. askNow: OK asks straight away; the banner (tuning) asks after
' m.odHudTimer, each tune restarting it, so surfing past a channel never asks.
sub onOdHudTimer()
    odHudSync(true)
end sub

sub odHudSync(askNow as Boolean)
    ch = invalid
    p = invalid
    if m.mode = "live" and m.extern = invalid and m.mv = invalid and m.curIdx >= 0 and m.curIdx < m.channels.Count() then
        ch = m.channels[m.curIdx]
        p = progAt(ch, nowEpoch())
    end if
    if ch = invalid or not odProgCan(ch.numStr, p) then
        odHudSet(invalid, invalid, invalid)
        return
    end if
    key = odProgKey(ch.numStr, p)
    c = odProgCached(ch.numStr, p)
    if c <> invalid then
        odHudSet(key, c.m, p)
        return
    end if
    if m.odHud = invalid or m.odHud.key <> key then odHudSet(invalid, invalid, invalid)
    if m.odHudAsking <> key then
        if not askNow then
            m.odHudTimer.control = "stop"
            m.odHudTimer.control = "start"
            return
        end if
        m.odHudTimer.control = "stop"
        m.odHudAsking = key         ' one question per show (the bar opens many times)
        odProgAsk(ch.numStr, p, "hud")
    end if
end sub

sub odHudSet(key as Dynamic, mt as Dynamic, p as Dynamic)
    shown = (mt <> invalid and odChoices(mt, p).Count() > 0)
    if shown then m.odHud = { key: key, mt: mt, p: p } else m.odHud = invalid
    if m.hud.odButton <> shown then m.hud.odButton = shown
end sub

' the bar's button (or More's entry): its choices, worked out as of now ("Continue · 30:06 in")
sub showOdChoices()
    m.hud.callFunc("hideAll")
    h = m.odHud
    if h = invalid then return
    m.odPick = { mt: h.mt, choices: odChoices(h.mt, h.p) }
    buttons = []
    actions = []
    for i = 0 to m.odPick.choices.Count() - 1
        buttons.Push(odChoiceLabel(m.odPick.choices[i], h.mt, true))
        actions.Push("od" + i.ToStr())
    end for
    buttons.Push("Cancel")
    actions.Push("cancel")
    msg = [anyStr(h.p.title)]
    sl = subLine(h.p)
    if sl <> "" then msg.Push(sl)
    showDialog("odprog", odWhat(h.mt), msg, buttons, actions)
end sub

' ------------------------------------------------------------ in the guide's OK dialog
' The answer is waited for (up to 1.2s) before the dialog opens, so its buttons don't move under the
' highlight; one that comes later is kept for the next time.
sub onOptWait()
    optWaitDone()
end sub

sub optWaitDone()
    w = m.optWait
    m.optWait = invalid
    m.optWaitTimer.control = "stop"
    if w = invalid or m.mode <> "guide" or m.dlg <> invalid then return
    showGuideOpts(w.req)
end sub

' the guide went back before the listings it has: load the catch-up channels' shows from there (a few hours
' at a time, so a provider with archives on hundreds of channels stays a small download)
sub onGuidePast()
    t0 = m.guide.pastRequest
    if m.cuFrom = 0 then m.cuFrom = nowEpoch() - 3600
    if t0 >= m.cuFrom or m.cuDays = invalid or m.cuDays.Count() = 0 then return
    nums = []
    for each k in m.cuDays
        nums.Push(k)
    end for
    stopAt = m.cuFrom
    fromAt = t0 - 3 * 3600
    m.cuFrom = fromAt
    homeApi("cuguide", "/api/guide?start=" + fromAt.ToStr() + "&stop=" + stopAt.ToStr() + "&numbers=" + nums.Join(","), "", invalid, { fromAt: fromAt, stopAt: stopAt })
end sub

' the guide's focused show has no description (guide.json?desc=0): that channel's from /api/guide
sub onGuideDesc()
    q = m.guide.descRequest
    if q = invalid or q.num = invalid then return
    homeApi("gdesc", "/api/guide?start=" + epochOf(q.start).ToStr() + "&stop=" + epochOf(q.stop).ToStr() + "&numbers=" + q.num, "", invalid, { idx: q.idx, num: q.num })
end sub

sub gotGuideDesc(r as Object)
    if not r.ok or Type(r.data) <> "roAssociativeArray" then return
    list = r.data[r.ctx.num]
    if Type(list) <> "roArray" then return
    descs = {}
    for each p in list
        if Type(p) = "roAssociativeArray" and p.start <> invalid then
            d = anyStr(p.descr)
            if d <> "" then descs[epochOf(p.start).ToStr()] = d
        end if
    end for
    if descs.Count() > 0 then m.guide.descReply = { idx: r.ctx.idx, descs: descs }
end sub

' GET /api/guide: { "<number>": [{ start, stop, title, subtitle, descr, category, episode, rating }] }
sub gotPastGuide(r as Object)
    if not r.ok or Type(r.data) <> "roAssociativeArray" or r.data.detail <> invalid then
        if m.cuFrom = r.ctx.fromAt then m.cuFrom = r.ctx.stopAt      ' try again next time
        return
    end if
    out = {}
    for i = 0 to m.channels.Count() - 1
        ch = m.channels[i]
        list = r.data[ch.numStr]
        if Type(list) = "roArray" and list.Count() > 0 then
            add = []
            for each p in list
                if Type(p) = "roAssociativeArray" then
                    add.Push({ start: epochOf(p.start), stop: epochOf(p.stop), title: anyStr(p.title), subtitle: anyStr(p.subtitle), desc: anyStr(p.descr), cat: anyStr(p.category), ep: anyStr(p.episode), rating: anyStr(p.rating) })
                end if
            end for
            merged = mergeProgs(ch.programs, add)
            ch.programs = merged
            out[i.ToStr()] = merged
        end if
    end for
    if out.Count() > 0 then m.guide.guideData = out
end sub

' a channel's shows with earlier ones added (one per start time), in time order
function mergeProgs(have as Dynamic, add as Object) as Object
    seen = {}
    out = []
    if Type(have) = "roArray" then
        for each p in have
            seen[p.start.ToStr()] = true
            out.Push(p)
        end for
    end if
    for each p in add
        if seen[p.start.ToStr()] = invalid then
            seen[p.start.ToStr()] = true
            out.Push(p)
        end if
    end for
    out.SortBy("start")
    return out
end function

' ============================================================ On Demand playback
' TunerBox streams a title from a start time (ss) like a live channel, so the position is
' base + how long it has been playing, and skipping asks for a new stream from the new time.
function vodClientId() as String
    if m.vodClient = invalid then m.vodClient = "roku-" + CreateObject("roDeviceInfo").GetChannelClientId()
    return m.vodClient
end function

' the name set for this Roku in Settings > System > About (e.g. "Bedroom Roku"), shown in TunerBox's
' Setup > Tuners as who is watching
function deviceName() as String
    if m.devName = invalid then
        di = CreateObject("roDeviceInfo")
        n = ""
        if FindMemberFunction(di, "GetFriendlyName") <> invalid then n = di.GetFriendlyName()
        if n = invalid or n = "" then n = di.GetModelDisplayName()
        if n = invalid or n = "" then n = "Roku"
        m.devName = n
    end if
    return m.devName
end function

' start < 0 = resume where you stopped
sub playVod(id as String, start as Float, back as Boolean)
    m.vodSeq = m.vodSeq + 1
    m.pvHeldIdx = -1        ' live TV paused for Pick a version stays off: this plays instead
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
    coverHome()
    if m.mode = "ondemand" then m.od.callFunc("closeOD")
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if mvVodRoute(it, start) then return        ' multiview: in a small picture
    if m.vod <> invalid then vodLeave()
    setPreviewSize(false)
    m.mode = "vod"
    m.top.setFocus(true)
    cu = truthy(it.catchup)
    m.vod = { it: it, id: anyStr(it.id), dur: numv(it.duration), base: start, back: back, retries: 0, target: -1.0, paused: false, parked: false, done: false, acc: 0.0, running: false, clock: CreateObject("roTimespan"), ticks: 0, cu: cu, audio: 0, tracks: invalid, sub: invalid, subPick: invalid, cues: invalid }
    if not cu then avInit(m.vod)
    if start > 0 then
        showToast("Resuming from " + fmtDur(start))
    else if cu then
        showToast("Catch-up: " + anyStr(it.title))
    else
        showToast(anyStr(it.title))
    end if
    vodStart(start)
    m.vodTimer.control = "start"
    if not cu then vodApi("vodtracks", "/api/vod/tracks/" + urlEncode(m.vod.id), invalid, { seq: m.vodSeq })
end sub

sub vodStart(at as Float)
    v = m.vod
    if v = invalid then return
    mvForget()
    m.seekTimer.control = "stop"
    m.parkTimer.control = "stop"
    m.retryTimer.control = "stop"
    if v.dur > 0 and at > v.dur - 5 then at = v.dur - 5
    if at < 0 then at = 0
    if v.cu then at = Int(at / 60) * 60       ' the archive starts on the minute
    v.base = at
    v.target = -1.0
    v.parked = false
    v.paused = false
    v.acc = 0.0
    v.running = false
    u = m.base + "/api/vod/stream/" + urlEncode(v.id) + "?ss=" + Int(at).ToStr() + "&client=" + urlEncode(vodClientId()) + "&name=" + urlEncode(deviceName())
    if isCompat() then u = u + "&mode=roku720"
    if v.audio > 0 then u = u + "&a=" + v.audio.ToStr()
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
    subsShow("")
    if not v.cu then vodApi("watched", "/api/vod/watched", { id: v.id, watched: true }, {})
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
    if v = invalid or v.done or v.cu then return       ' catch-up shows aren't resumed later
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
    m.subsTimer.control = "stop"
    subsShow("")
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
    else if not backToHome() then
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
    if v.cu then
        jump = Abs(delta)
        if jump < 60 then jump = 60
        if delta < 0 then jump = -jump
        delta = jump
    end if
    t = vodPos() + delta
    if v.dur > 0 and t > v.dur - 10 then t = v.dur - 10
    if v.cu and epochOf(v.it.stop) > nowEpoch() then
        lim = nowEpoch() - epochOf(v.it.start) - 90
        if t > lim then t = lim
    end if
    if t < 0 then t = 0
    if v.cu then t = Int(t / 60) * 60
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
    if m.rec <> invalid then
        recTick()
        return
    end if
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
    name = "On Demand"
    if v.cu then
        hint = "Left/Right 1 min   Rew/FF 5 min   OK Pause   Back Live TV"
        name = "Catch-up"
    else if avHas(v) then
        hint = hint + "   * Audio & subtitles"
    end if
    return { num: "VOD", name: name, logo: "", title: plainText(anyStr(v.it.title)), subtitle: plainText(anyStr(v.it["sub"])), times: times, pct: pct, nextText: hint, rating: badge }
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
    else if key = "options" then
        if avHas(v) then avMenu() else showVodHud()
    else if key = "up" or key = "down" then
        showVodHud()
    else if key = "back" then
        vodStop(v.back)
    else if Left(key, 4) = "Lit_" then
        lc = LCase(Mid(key, 5))
        if lc = "m" then
            toggleMute()
        else if lc = "c" then
            toggleCaptions()
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


' ============================================================ Home (TunerBox GET /api/home)
' Only when TunerBox's Setup > Settings "Home screen" is on, as the web screens. Opens at launch unless
' "Start on Home" is off in this Roku's Menu; Back goes to live TV, and screens opened from Home come back to it.
function homeAtStart() as Boolean
    return m.homeOn and regRead("homeStart", "1") = "1"
end function

' channels this Roku tuned to, newest first (Home > Recent channels)
sub noteRecent(num as String)
    if num = "" then return
    out = [num]
    for each n in regRead("recent", "").Split(",")
        if n <> "" and n <> num and out.Count() < 12 then out.Push(n)
    end for
    regWrite("recent", out.Join(","))
end sub

sub fetchSettings()
    homeApi("settings", "/api/settings", "", invalid, {})
    homeApi("catchup", "/api/catchup", "", invalid, {})
end sub

' small call to TunerBox for Home (results come back in onHomeApi)
sub homeApi(tag as String, path as String, method as String, body as Dynamic, ctx as Object)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = path
    t.apiMethod = method
    if body <> invalid then t.apiBody = FormatJson(body)
    t.apiTag = tag
    t.apiCtx = ctx
    t.observeField("result", "onHomeApi")
    m.homeTasks.Push(t)
    if m.homeTasks.Count() > 8 then m.homeTasks.Shift()
    t.control = "RUN"
end sub

sub onHomeApi(event as Object)
    r = event.getData()
    if r = invalid then return
    if r.tag = "settings" then
        if r.ok and Type(r.data) = "roAssociativeArray" then applySettings(r.data)
        m.homeAuto = false
    else if r.tag = "hchange" then
        if r.ok then showToast(r.ctx.ok) else showToast(r.ctx.fail)
        if m.mode = "home" then m.home.callFunc("reload")
    else if r.tag = "catchup" then
        ' an older TunerBox has no /api/catchup: no catch-up
        if r.ok and Type(r.data) = "roAssociativeArray" and r.data.detail = invalid then
            m.cuDays = r.data
            m.guide.cuDays = r.data
        end if
    else if r.tag = "cuguide" then
        gotPastGuide(r)
    else if r.tag = "gdesc" then
        gotGuideDesc(r)
    end if
end sub

' ============================================================ On Demand episodes picked in Search
sub searchVodAction(kind as String, action as String, d as Object)
    id = anyStr(d.id)
    if kind = "svodep" then
        if action = "play" then
            playVod(id, -1, false)
        else if action = "all" then
            closeSearch()
            openOnDemand({ showId: anyStr(d.title_id) })
        end if
    else if action = "resume" then
        playVod(id, numv(d.position), false)
    else if action = "play" then
        playVod(id, 0, false)
    else if action = "list" then
        on = not truthy(d.in_list)
        msg = plainText(anyStr(d.name)) + " removed from My List"
        if on then msg = plainText(anyStr(d.name)) + " added to My List"
        homeApi("hchange", "/api/vod/list", "POST", { id: id, on: on }, { ok: msg, fail: "Couldn't reach TunerBox" })
    else if action = "watched" then
        w = not truthy(d.watched)
        msg = "Marked as not watched"
        if w then msg = "Marked as watched"
        homeApi("hchange", "/api/vod/watched", "POST", { id: id, watched: w }, { ok: msg, fail: "Couldn't reach TunerBox" })
    else if action = "forget" then
        homeApi("hchange", "/api/vod/forget", "POST", { id: id }, { ok: "Removed from Continue Watching", fail: "Couldn't reach TunerBox" })
    end if
end sub

sub setFeatures(vodOn as Boolean, dvrOn as Boolean)
    if dvrOn <> m.dvrOn then
        m.dvrOn = dvrOn
        if dvrOn then regWrite("dvrOn", "1") else regWrite("dvrOn", "0")
    end if
    if vodOn = m.vodOn then return
    m.vodOn = vodOn
    if vodOn then regWrite("vodOn", "1") else regWrite("vodOn", "0")
    m.hud.showOnDemand = vodOn
    m.home.vodOn = vodOn
    if m.mode = "home" then m.home.callFunc("reload")
    if not vodOn and m.mode = "ondemand" then
        closeOnDemand()
        if not backToHome() then showBanner()
    end if
end sub

sub applySettings(d as Object)
    ' TunerBox's theme for every screen (Light is for Setup and phones; TV screens stay dark with it)
    th = d.theme
    if th <> invalid and GetInterface(th, "ifString") <> invalid then
        if not themeValid(th) then th = "midnight"
        if th <> regRead("themeServer", "") then regWrite("themeServer", th)
        applyTheme(themeChosen())
    end if
    ' TunerBox's stream cache for every screen (this Roku's own choice in Menu > Stream cache wins)
    sb = d.stream_buffer
    if sb <> invalid and (GetInterface(sb, "ifInt") <> invalid or GetInterface(sb, "ifFloat") <> invalid or GetInterface(sb, "ifDouble") <> invalid or GetInterface(sb, "ifLongInt") <> invalid) then
        sbs = anyStr(sb)
        if sbs <> regRead("bufferServer", "") then regWrite("bufferServer", sbs)
    end if
    ' optional features (an older TunerBox doesn't say: both on)
    vo = true
    if d.vod_available <> invalid and GetInterface(d.vod_available, "ifBoolean") <> invalid then vo = d.vod_available
    dv = true
    if d.dvr_enabled <> invalid and GetInterface(d.dvr_enabled, "ifBoolean") <> invalid then dv = d.dvr_enabled
    setFeatures(vo, dv)
    mvSettings(d)
    on = false
    v = d.home_screen
    if v <> invalid and GetInterface(v, "ifBoolean") <> invalid then on = v
    if on <> m.homeOn then
        m.homeOn = on
        if on then regWrite("homeOn", "1") else regWrite("homeOn", "0")
        m.hud.showHome = on
    end if
    if not on and m.mode = "home" then
        leaveHome()
        showBanner()
    else if on and m.homeAuto and m.mode = "live" and homeAtStart() then
        openHome()
    end if
end sub

sub openHome()
    if m.mode = "boot" or m.mode = "needhost" or m.mode = "error" or m.mode = "fitcal" or m.mode = "vod" or m.mode = "rec" then return
    if not m.homeOn then
        ' Home is off in TunerBox: the guide, as the web screens do
        if m.mode <> "guide" then openGuide(m.curIdx, invalid, "")
        return
    end if
    if m.channels.Count() = 0 then return
    m.homeAuto = false
    m.hud.callFunc("hideAll")
    if m.menu.visible then m.menu.callFunc("closeMenu")
    if m.mode = "guide" then closeGuide()
    if m.mode = "sports" then closeSports()
    if m.mode = "search" then closeSearch()
    if m.mode = "ondemand" then m.od.callFunc("closeOD")
    m.returnHome = false
    m.mode = "home"
    m.home.baseUrl = m.base
    m.home.recent = regRead("recent", "")
    m.home.callFunc("openHome")
    setPanelPreview(m.home)
end sub

' Home off the screen (the video back to full size), mode unchanged
sub hideHome()
    m.home.callFunc("closeHome")
    setPreviewSize(false)
end sub

' from Home to live TV
sub leaveHome()
    if m.home.visible then hideHome()
    if m.mode = "home" then m.mode = "live"
    m.returnHome = false
    m.top.setFocus(true)
end sub

' another screen opens over Home: Back from it comes back here
sub coverHome()
    if m.mode <> "home" then return
    hideHome()
    m.mode = "live"
    m.returnHome = true
end sub

' the screen that was opened from Home just closed (now on live TV): show Home again
function backToHome() as Boolean
    if not m.returnHome then return false
    m.returnHome = false
    if not m.homeOn or m.mode <> "live" then return false
    openHome()
    return true
end function

sub onHomeRequest()
    req = m.home.request
    if req = invalid or m.mode <> "home" then return
    ty = req.type
    if ty = "close" then
        leaveHome()
        showBanner()
    else if ty = "fav" then
        if anyStr(req.num) <> "" then toggleFav(anyStr(req.num))
    else if ty = "nav" then
        homeNav(req.id)
    else if ty = "pick" then
        homePick(req.item)
    else if ty = "play" then
        homePlay(req.item)
    end if
end sub

' Play on a Home tile: play or resume it straight away (a show with no episode started opens its page)
sub homePlay(it as Object)
    if Type(it) <> "roAssociativeArray" then return
    if it.t = "vod" then
        if anyStr(it.kind) <> "series" then
            playVod(anyStr(it.id), -1, false)
        else if anyStr(it.resume) <> "" then
            playVod(anyStr(it.resume), -1, false)     ' an Up next episode starts from the beginning
        else
            homePick(it)
        end if
    else if it.t = "rec" then
        at = numv(it.position)
        if truthy(it.watched) or at <= 30 then at = 0
        playRecording(it, at)
    else
        homePick(it)
    end if
end sub

sub homeNav(id as String)
    if id = "tv" then
        leaveHome()
        showBanner()
    else if id = "guide" then
        openGuide(m.curIdx, invalid, "")
    else if id = "ondemand" then
        openOnDemand({})
    else if id = "sports" then
        openSports()
    else if id = "search" then
        openSearch()
    else if id = "menu" then
        showMenu()
    end if
end sub

sub homePick(it as Object)
    if Type(it) <> "roAssociativeArray" then return
    t = it.t
    if t = "nav" then
        homeNav(it.id)
    else if t = "chan" then
        homeTune(anyStr(it.number))
    else if t = "vod" then
        id = anyStr(it.id)
        if anyStr(it.kind) <> "series" then
            openOdOverlay(id)      ' On Demand's movie panel over Home, not the On Demand screen
        else if anyStr(it.resume) = "" then
            openOnDemand({ showId: id })
        else
            ' Continue Watching: TunerBox sends a show once, at its latest episode; an Up next tile (the episode
            ' before it was finished) plays its episode from the start
            sb = anyStr(it["sub"])
            ep = anyStr(it.ep)
            if ep = "" then ep = sb
            if ep = "" then ep = "episode"
            verb = "Resume "
            if truthy(it.upnext) then verb = "Play "
            m.homeReq = it
            showDialog("hvod", anyStr(it.name), [sb], [verb + ep, "All episodes", "Mark " + ep + " as watched", "Remove from Continue Watching", "Close"], ["resume", "all", "watched", "forget", "close"])
        end if
    else if t = "rec" then
        homeRecDialog(it)
    else if t = "game" then
        homeGame(it.p)
    else
        homeSchedDialog(it)
    end if
end sub

sub homeTune(num as String)
    idx = chIndexByNum(num)
    if idx < 0 then
        showToast("Channel " + num + " is not available")
        return
    end if
    tuneTo(idx)
end sub

' a game on now: straight to the best place showing it (an event feed checked live, else its channel),
' no asking; Menu > Switch feed lists the other places
sub homeGame(p as Dynamic)
    if Type(p) <> "roAssociativeArray" then return
    opts = gameOpts(p, "", "")
    ' its channel outside this Roku's list (gameOpts leaves it out) still beats a feed nobody has checked
    if opts.Count() > 0 and opts[0].f <> invalid and anyStr(opts[0].f.status) <> "ok" and Type(p.ch) = "roAssociativeArray" then opts = []
    if opts.Count() > 0 and opts[0].f <> invalid then
        f = opts[0].f
        leaveHome()
        if mvRoute({ f: f }) then return
        playExternal({ num: "EVENT", name: anyStr(f.group), title: plainText(anyStr(f.name)), url: m.base + "/api/feed/stream?key=" + urlEncode(anyStr(f.key)), key: anyStr(f.key) })
        showBanner()
    else if opts.Count() > 0 then
        leaveHome()
        watchChannelNum(numToStr(opts[0].ch.number), anyStr(opts[0].ch.name))
    else if Type(p.ch) = "roAssociativeArray" then
        ' its channel isn't in this Roku's list: TunerBox can still stream it
        leaveHome()
        watchChannelNum(numToStr(p.ch.number), anyStr(p.ch.name))
    else
        showToast("None of your channels carry this game")
    end if
end sub

sub homeRecDialog(it as Object)
    at = numv(it.position)
    watched = truthy(it.watched)
    resume = (not watched and at > 30)
    buttons = []
    actions = []
    if resume then
        buttons.Push("Resume from " + fmtDur(at))
        actions.Push("resume")
        buttons.Push("Play from the beginning")
    else
        buttons.Push("Play")
    end if
    actions.Push("play")
    if resume then
        buttons.Push("Remove from Continue Watching")
        actions.Push("forget")
    end if
    buttons.Append(["Delete recording", "Close"])
    actions.Append(["delete", "close"])
    startAt = Int(numv(it.start))
    msg = [anyStr(it.number) + " " + anyStr(it.channel_name), fmtDay(startAt) + "  " + fmtClock(startAt) + dashSep() + fmtClock(Int(numv(it.stop)))]
    if resume then
        msg.Push("You stopped at " + fmtDur(at))
    else if watched then
        msg.Push("Watched")
    end if
    if anyStr(it.error) <> "" then msg.Push(anyStr(it.error))
    m.homeReq = it
    showDialog("hrec", anyStr(it.title), msg, buttons, actions)
end sub

' a recording to come or a reminder: watch it if it's on, or cancel it
sub homeSchedDialog(it as Object)
    num = anyStr(it.number)
    t = nowEpoch()
    onAir = (numv(it.start) <= t and t < numv(it.stop))
    buttons = []
    actions = []
    if onAir and chIndexByNum(num) >= 0 then
        buttons.Push("Watch now")
        actions.Push("watch")
    end if
    if it.t = "sched" then
        if anyStr(it.status) = "recording" then buttons.Push("Stop recording") else buttons.Push("Cancel recording")
        actions.Push("cancelrec")
    else
        buttons.Push("Cancel reminder")
        actions.Push("cancelrem")
    end if
    buttons.Push("Close")
    actions.Push("close")
    startAt = Int(numv(it.start))
    msg = [num + " " + anyStr(it.channel_name), fmtDay(startAt) + "  " + fmtClock(startAt) + dashSep() + fmtClock(Int(numv(it.stop)))]
    m.homeReq = it
    showDialog("hsched", anyStr(it.title), msg, buttons, actions)
end sub

sub homeDialogAction(kind as String, action as String, it as Object)
    id = anyStr(it.id)
    if kind = "hvod" then
        if action = "resume" then
            playVod(anyStr(it.resume), -1, false)
        else if action = "all" then
            openOnDemand({ showId: id })
        else if action = "watched" then
            homeApi("hchange", "/api/vod/watched", "POST", { id: anyStr(it.resume), watched: true }, { ok: "Marked as watched", fail: "Couldn't reach TunerBox" })
        else if action = "forget" then
            homeApi("hchange", "/api/vod/forget", "POST", { id: id }, { ok: "Removed from Continue Watching", fail: "Couldn't reach TunerBox" })
        end if
    else if kind = "hrec" then
        if action = "resume" then
            playRecording(it, numv(it.position))
        else if action = "play" then
            playRecording(it, 0)
        else if action = "forget" then
            ' back to the start without marking it watched: TunerBox's Continue Watching only lists recordings
            ' stopped part-way through
            homeApi("hchange", "/api/recordings/" + id + "/progress", "POST", { position: 0, duration: numv(it.duration) }, { ok: "Removed from Continue Watching", fail: "Couldn't reach TunerBox" })
        else if action = "delete" then
            homeApi("hchange", "/api/recordings/" + id + "?delete=1", "DELETE", invalid, { ok: "Recording deleted", fail: "Couldn't delete the recording" })
        end if
    else if kind = "hsched" then
        if action = "watch" then
            homeTune(anyStr(it.number))
        else if action = "cancelrec" then
            msg = "Recording cancelled"
            if anyStr(it.status) = "recording" then msg = "Recording stopped"
            homeApi("hchange", "/api/recordings/" + id, "DELETE", invalid, { ok: msg, fail: "Couldn't reach TunerBox" })
        else if action = "cancelrem" then
            homeApi("hchange", "/api/reminders/" + id, "DELETE", invalid, { ok: "Reminder cancelled: " + anyStr(it.title), fail: "Couldn't reach TunerBox" })
        end if
    end if
end sub

' ============================================================ recordings (played from Home)
' The recorded file is played as it is (GET /api/recordings/<id>/file), so skipping is a normal seek.
' Where you got to is saved on TunerBox, so any screen can resume it.
sub playRecording(it as Object, from as Float)
    mvForget()
    if m.menu.visible then m.menu.callFunc("closeMenu")
    coverHome()
    m.hud.callFunc("hideAll")
    setPreviewSize(false)
    m.mode = "rec"
    m.top.setFocus(true)
    id = anyStr(it.id)
    f = LCase(anyStr(it.file))
    fmt = "ts"
    if Right(f, 4) = ".mp4" or Right(f, 4) = ".m4v" then fmt = "mp4"
    if Right(f, 4) = ".mkv" then fmt = "mkv"
    c = CreateObject("roSGNode", "ContentNode")
    c.url = m.base + "/api/recordings/" + id + "/file"
    c.title = anyStr(it.title)
    c.streamFormat = fmt
    if from > 0 then c.PlayStart = from
    m.rec = { it: it, id: id, ticks: 0, paused: false, ended: false }
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.vodTimer.control = "start"
    if from > 0 then showToast("Resuming from " + fmtDur(from)) else showToast(plainText(anyStr(it.title)))
    showRecHud(5)
end sub

sub recState(st as String)
    r = m.rec
    if st = "finished" then
        recSave(true)
        r.ended = true
        recStop()
    else if st = "error" then
        showToast("Can't play this recording")
        recStop()
    end if
end sub

sub recTick()
    r = m.rec
    if m.mode <> "rec" then return
    m.hud.callFunc("updateVod", recInfo())
    if r.paused then return
    r.ticks = r.ticks + 1
    if r.ticks mod 15 = 0 then recSave(false)
end sub

sub recSave(ended as Boolean)
    r = m.rec
    if r = invalid or r.ended then return
    dur = m.video.duration
    at = m.video.position
    if ended and dur > 0 then at = dur
    if at < 5 then return
    homeApi("recprog", "/api/recordings/" + r.id + "/progress", "", { position: at, duration: dur }, {})
end sub

function recInfo() as Object
    r = m.rec
    at = m.video.position
    dur = m.video.duration
    times = fmtDur(at)
    pct = 0.0
    if dur > 0 then
        times = times + " / " + fmtDur(dur)
        pct = at / dur
    end if
    badge = ""
    if r.paused then badge = "PAUSED"
    sb = anyStr(r.it.subtitle)
    if sb = "" then sb = anyStr(r.it.episode)
    hint = "Left -10s   Right +30s   Rew/FF 5 min   OK Pause   Back Stop"
    return { num: "REC", name: plainText(anyStr(r.it.channel_name)), logo: "", title: plainText(anyStr(r.it.title)), subtitle: plainText(sb), times: times, pct: pct, nextText: hint, rating: badge }
end function

sub showRecHud(secs as Integer)
    if m.rec = invalid then return
    m.hud.callFunc("showVod", recInfo(), secs)
end sub

sub recSeek(delta as Float)
    t = m.video.position + delta
    dur = m.video.duration
    if dur > 0 and t > dur - 5 then t = dur - 5
    if t < 0 then t = 0
    m.video.seek = t
    showRecHud(5)
end sub

function recKey(key as String) as Boolean
    r = m.rec
    if r = invalid then
        m.mode = "live"
        return false
    end if
    if key = "OK" or key = "play" then
        if r.paused then
            r.paused = false
            m.video.control = "resume"
            showRecHud(5)
        else
            r.paused = true
            m.video.control = "pause"
            recSave(false)
            showRecHud(0)
        end if
    else if key = "left" or key = "replay" then
        recSeek(-10)
    else if key = "right" then
        recSeek(30)
    else if key = "rewind" then
        recSeek(-300)
    else if key = "fastforward" then
        recSeek(300)
    else if key = "up" or key = "down" or key = "options" then
        showRecHud(5)
    else if key = "back" then
        recStop()
    else if Left(key, 4) = "Lit_" then
        lc = LCase(Mid(key, 5))
        if lc = "m" then
            toggleMute()
        else if lc = "i" then
            showRecHud(5)
        else if lc = "s" then
            recStop()
        end if
    else
        return false
    end if
    return true
end function

' Back / the end: return to the channel you were on, and to Home if you came from there
sub recStop()
    if m.rec = invalid then return
    recSave(false)
    m.rec = invalid
    if m.vod = invalid then m.vodTimer.control = "stop"
    m.hud.callFunc("hideAll")
    m.video.control = "stop"
    m.mode = "live"
    m.top.setFocus(true)
    if m.extern <> invalid then
        playExternal(m.extern)
    else if m.curIdx >= 0 then
        playChannel(m.curIdx)
    end if
    if not backToHome() then showBanner()
end sub
