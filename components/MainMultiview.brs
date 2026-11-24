' ============================================================ multiview
' Two to four live channels on the screen at once, as TunerBox's web TV does. A Roku's player can only play
' one video at a time ("only one playing instance supported"), so TunerBox tiles the pictures into one stream
' for it (GET /api/mv/stream, richakev's fork only): each picture is read on the server as "<this Roku>~<slot>"
' (slot 1 as "<this Roku>"), the client ids the web's tiles use, so the playlists' connection limits count
' every picture. The sound is one track TunerBox mixes from the highlighted picture; moving the highlight
' asks it to switch (POST /api/mv/sound) without restarting anything; this app draws the labels, the highlight and the
' "+ Add a channel" places over the picture (MultiView).
'
' Every channel put in a picture goes through TunerBox's planner (POST /api/mv/plan), as on the web: when the
' channel is only on a playlist whose connections the other pictures use, one that's also on another playlist
' moves there first; when nothing can move, it says what's using them and offers to swap a picture out.
'
' Remote, as the web's: arrows move the highlight (the highlighted picture has the sound). OK swaps the big and
' small pictures in picture in picture, brings the highlighted one into the big place in "one big, ...", on
' "+ Add a channel" adds one, else watches the highlighted one full screen. Back leaves multiview keeping the
' highlighted channel; Options opens the Multiview menu. The Guide, Sports, Search and channel numbers put
' what you pick in the highlighted picture (or a new one, while adding).
'
' On Demand picked in multiview (Pick the channel to add > From On Demand, or any title started while it's on)
' plays in the highlighted small picture, or a new one, as on the web: TunerBox runs the title like the
' full-screen player and says how far in it is (/api/mv/status pos), so its place is saved as it plays, and
' OK or Back carries on with it full screen in the On Demand player from the same spot.
'
' Older TunerBox (pasiegel's, or this fork before the tiled stream): /api/settings has no multiview_max, or
' /api/mv/status isn't there; Menu shows no Multiview.

sub mvInit()
    m.mv = invalid          ' while on: { tiles, order, focus, layout, sound, streamSound, retries, why, room }
    m.mvMax = 1             ' how many pictures TunerBox allows (its multiview_max; 1: none)
    m.mvEnabled = true      ' Setup > Settings > Screens > Multiview
    m.mvTiled = -1          ' this TunerBox makes the tiled stream: -1 not asked yet, 0 no, 1 yes
    m.mvAdd = 0             ' picking a channel to add (from the Guide, Sports or Search) since then (epoch secs)
    m.mvSeq = 0             ' the latest plan asked for (older answers are ignored)
    m.mvPick = invalid      ' the "Pick the channel to add" list: { layout, slot, opts }
    m.mvSwapOpts = invalid  ' the "Can't add" dialog's swaps: { slot, ch }
    m.mvVodAdd = 0          ' picking an On Demand title for a new picture since then (epoch secs)
    m.mvVodFull = false     ' the next On Demand title plays full screen (leaving multiview with one)
    m.mvSaved = 0           ' when On Demand pictures' places were last saved (epoch secs)
    m.mvTasks = []
    m.mvPref = {}           ' the layout picked for each number of pictures ("2": "pip", ...)
    p = ParseJson(regRead("mvLayout", "{}"))
    if Type(p) = "roAssociativeArray" then m.mvPref = p
    m.mvView = m.top.findNode("mvView")
    m.mvPoll = CreateObject("roSGNode", "Timer")
    m.mvPoll.repeat = true
    m.mvPoll.duration = 3
    m.mvPoll.observeField("fire", "onMvPoll")
    m.mvHintTimer = CreateObject("roSGNode", "Timer")
    m.mvHintTimer.repeat = false
    m.mvHintTimer.duration = 6
    m.mvHintTimer.observeField("fire", "onMvHintTimer")
    m.mvVis = CreateObject("roSGNode", "Timer")
    m.mvVis.repeat = true
    m.mvVis.duration = 0.3
    m.mvVis.observeField("fire", "onMvVis")
end sub

' the labels only while live TV is up: the Guide, Sports, Home and the rest draw over the picture
sub onMvVis()
    show = (m.mv <> invalid and m.mode = "live")
    if show and not m.mvView.visible then mvRender()
    m.mvView.visible = show
end sub

' /api/settings: multiview_max (richakev's fork; missing on older TunerBox: no multiview)
sub mvSettings(d as Object)
    mx = d.multiview_max
    if mx <> invalid and (GetInterface(mx, "ifInt") <> invalid or GetInterface(mx, "ifFloat") <> invalid or GetInterface(mx, "ifDouble") <> invalid or GetInterface(mx, "ifLongInt") <> invalid) then
        m.mvMax = Int(mx)
    else
        m.mvMax = 1
    end if
    en = d.multiview_enabled
    if en <> invalid and GetInterface(en, "ifBoolean") <> invalid then m.mvEnabled = en
end sub

' ------------------------------------------------------------ layouts
function mvSizes() as Object
    return { pip: 2, split: 2, big: 3, big3: 4, grid: 4 }
end function

function mvSize(l as String) as Integer
    sz = mvSizes()
    if sz.DoesExist(l) then return sz[l]
    return 4
end function

function mvLayoutName(l as String) as String
    names = { pip: "Picture in picture", split: "Side by side", big: "One big, two small", big3: "One big, three small", grid: "Four squares" }
    if names.DoesExist(l) then return names[l]
    return l
end function

' where each place of a layout is: left, top, width, height in % of the screen (TunerBox's mvstream.PLACES)
function mvPlacesPct(l as String) as Object
    if l = "split" then return [[0, 25, 50, 50], [50, 25, 50, 50]]
    if l = "pip" then return [[0, 0, 100, 100], [67, 4, 30, 30]]
    if l = "big" then return [[0, 16.7, 66.7, 66.7], [66.7, 16.7, 33.3, 33.3], [66.7, 50, 33.3, 33.3]]
    if l = "big3" then return [[0, 12.5, 75, 75], [75, 12.5, 25, 25], [75, 37.5, 25, 25], [75, 62.5, 25, 25]]
    return [[0, 0, 50, 50], [50, 0, 50, 50], [0, 50, 50, 50], [50, 50, 50, 50]]
end function

' the same places in screen pixels
function mvRects(l as String) as Object
    out = []
    for each p in mvPlacesPct(l)
        out.Push([Int(1920 * p[0] / 100 + 0.5), Int(1080 * p[1] / 100 + 0.5), Int(1920 * p[2] / 100 + 0.5), Int(1080 * p[3] / 100 + 0.5)])
    end for
    return out
end function

' how many pictures this screen may show (TunerBox's multiview_max, at most 4; 1: no multiview)
function mvMaxPics() as Integer
    if not m.mvEnabled or m.mvMax < 2 then return 1
    if m.mvMax > 4 then return 4
    return m.mvMax
end function

function mvOn() as Boolean
    return m.mv <> invalid
end function

function mvCount() as Integer
    if m.mv = invalid then return 1
    return m.mv.tiles.Count()
end function

' the layouts that hold n pictures and no more places than this screen may fill (in the web's order)
function mvFits(n as Integer) as Object
    sz = mvSizes()
    most = mvMaxPics()
    if n > most then most = n
    out = []
    for each l in ["pip", "split", "big", "big3", "grid"]
        if sz[l] >= n and sz[l] <= most then out.Push(l)
    end for
    return out
end function

function mvLayoutFor(n as Integer) as String
    fits = mvFits(n)
    if fits.Count() = 0 then return "grid"
    p = m.mvPref[n.ToStr()]
    if p <> invalid then
        for each l in fits
            if l = p then return p
        end for
    end if
    return fits[0]
end function

' use layout l from now until its places are full (so adding to its spare places keeps it)
sub mvSetLayoutPref(l as String)
    n = mvCount()
    if n < 2 then n = 2
    most = mvSize(l)
    for i = n to most
        m.mvPref[i.ToStr()] = l
    end for
    regWrite("mvLayout", FormatJson(m.mvPref))
end sub

function mvCanAdd() as Boolean
    if m.mv = invalid then return m.mode = "live" and mvMainTile() <> invalid and mvMaxPics() >= 2
    return m.mv.tiles.Count() < mvMaxPics()
end function

' ------------------------------------------------------------ pictures
' a picture: { slot, num ("" for an event feed), key ("" for a channel), alt, name, vod (an On Demand id, else ""),
' at (where the title started), dur, cu (a catch-up show: its place isn't kept) }
function mvNewTile(slot as Integer, num as String, key as String, alt as Integer, name as String) as Object
    return { slot: slot, num: num, key: key, alt: alt, name: name, vod: "", at: 0.0, dur: 0, cu: false }
end function

function mvTile(slot as Integer) as Dynamic
    if m.mv = invalid then return invalid
    for each t in m.mv.tiles
        if t.slot = slot then return t
    end for
    return invalid
end function

function mvFreeSlot() as Integer
    if m.mv = invalid then return 2         ' what's on now is picture 1
    for s = 1 to 4
        if mvTile(s) = invalid then return s
    end for
    return 0
end function

' what's on now as multiview's first picture (slot 1), or invalid
function mvMainTile() as Dynamic
    if m.vod <> invalid or m.rec <> invalid then return invalid
    if m.extern <> invalid then
        if m.extern.key <> invalid and anyStr(m.extern.key) <> "" then return mvNewTile(1, "", anyStr(m.extern.key), 0, plainText(anyStr(m.extern.title)))
        n = anyStr(m.extern.num)
        if n <> "" and n <> "EVENT" then return mvNewTile(1, n, "", 0, n + " " + anyStr(m.extern.name))
        return invalid
    end if
    if m.curIdx < 0 or m.curIdx >= m.channels.Count() then return invalid
    ch = m.channels[m.curIdx]
    alt = 0
    if ch.numStr = m.altNum then alt = m.alt
    return mvNewTile(1, ch.numStr, "", alt, ch.numStr + " " + ch.name)
end function

' the pictures' slots in place order (place 1 is the big one): as swapped, then any new picture at the end
function mvOrder() as Object
    out = []
    for each s in m.mv.order
        if mvTile(s) <> invalid then out.Push(s)
    end for
    slots = []
    for each t in m.mv.tiles
        slots.Push(t.slot)
    end for
    slots.Sort()
    for each s in slots
        found = false
        for each o in out
            if o = s then found = true
        end for
        if not found then out.Push(s)
    end for
    m.mv.order = out
    return out
end function

' a channel (or feed) for a picture, from the scene's ways of picking one:
' { idx } a lineup channel, { f } an event feed, { num, name } a channel number
function mvChFrom(what as Object) as Dynamic
    if what.idx <> invalid then
        if what.idx < 0 or what.idx >= m.channels.Count() then return invalid
        ch = m.channels[what.idx]
        return { num: ch.numStr, key: "", name: ch.numStr + " " + ch.name }
    end if
    if what.f <> invalid then
        f = what.f
        if anyStr(f.key) = "" then return invalid
        return { num: "", key: anyStr(f.key), name: plainText(anyStr(f.name)) }
    end if
    if what.num <> invalid and anyStr(what.num) <> "" then return { num: anyStr(what.num), key: "", name: anyStr(what.num) + " " + anyStr(what.name) }
    return invalid
end function

' what the pictures play now, for the planner
function mvState() as Object
    out = []
    tiles = []
    if m.mv <> invalid then
        tiles = m.mv.tiles
    else
        t = mvMainTile()
        if t <> invalid then tiles = [t]
    end if
    for each t in tiles
        if t.vod = "" then out.Push(mvSpec(t))     ' On Demand pictures can't move: the planner leaves them be
    end for
    return out
end function

function mvSpec(t as Object) as Object
    if t.vod <> "" then return { slot: t.slot, vod: t.vod, at: t.at }
    if t.key <> "" then return { slot: t.slot, number: invalid, key: t.key, alt: t.alt }
    return { slot: t.slot, number: Int(Val(t.num)), key: invalid, alt: t.alt }
end function

function mvAdding() as Boolean
    return m.mvAdd > 0 and nowEpoch() - m.mvAdd < 300
end function

' tuneTo / watchFeed / watchChannelNum while in multiview, or while picking a channel to add: true when this
' took it (it goes in the highlighted picture, or a new one)
function mvRoute(what as Object) as Boolean
    adding = mvAdding()
    if m.mv = invalid and not adding then return false
    ch = mvChFrom(what)
    if ch = invalid then return false
    m.mvAdd = 0
    if m.mode = "home" then leaveHome()
    m.returnHome = false
    if adding then
        if not mvCanAdd() then
            showToast("There's room for " + mvMaxPics().ToStr() + " channels at once")
            return true
        end if
        mvPut(mvFreeSlot(), ch)
    else if m.mv.focus > 0 then
        mvPut(m.mv.focus, ch)
    else
        mvPut(mvFreeSlot(), ch)
    end if
    return true
end function

' ------------------------------------------------------------ the planner
' put ch in picture `slot` (new, or replacing what's there); TunerBox says which feed, and which other
' pictures move to another playlist first
sub mvPut(slot as Integer, ch as Object)
    if slot < 1 then return
    m.mvSeq = m.mvSeq + 1
    want = { number: invalid, key: invalid }
    if ch.key <> "" then want.key = ch.key else want.number = Int(Val(ch.num))
    body = { client: vodClientId(), tiles: mvState(), slot: slot, want: want }
    mvApi("mvplan", "/api/mv/plan", body, { seq: m.mvSeq, slot: slot, ch: ch, wasOn: (m.mv <> invalid) })
end sub

sub mvApi(tag as String, path as String, body as Dynamic, ctx as Object)
    t = CreateObject("roSGNode", "LoadTask")
    t.mode = "api"
    t.baseUrl = m.base
    t.apiPath = path
    if body <> invalid then t.apiBody = FormatJson(body)
    t.apiTimeout = 15000
    t.apiTag = tag
    t.apiCtx = ctx
    t.observeField("result", "onMvApi")
    m.mvTasks.Push(t)
    if m.mvTasks.Count() > 8 then m.mvTasks.Shift()
    t.control = "RUN"
end sub

sub onMvApi(event as Object)
    r = event.getData()
    if r = invalid then return
    if r.tag = "mvplan" then
        mvPlanDone(r)
    else if r.tag = "mvprobe" then
        if r.ok = true and Type(r.data) = "roAssociativeArray" and r.data.tiles <> invalid then m.mvTiled = 1 else m.mvTiled = 0
        if r.ctx <> invalid and r.ctx.open = true then mvOpen()
    else if r.tag = "mvstatus" then
        mvStatusDone(r)
    else if r.tag = "mvsound" then
        mvSoundDone(r)
    else if r.tag = "mvroom" then
        if m.mv <> invalid and r.ok = true and Type(r.data) = "roArray" then
            parts = []
            for each s in r.data
                free = Int(numv(s.limit)) - Int(numv(s.used))
                if free < 0 then free = 0
                parts.Push(anyStr(s.source) + ": " + free.ToStr() + " of " + anyStr(s.limit) + " free")
            end for
            m.mv.room = parts.Join("  " + Chr(183) + "  ")
            mvRender()
        end if
    else if r.tag = "mvstop" then
        if r.ctx <> invalid and r.ctx.keep <> invalid then mvPlaySingle(r.ctx.keep)
    end if
end sub

sub mvPlanDone(r as Object)
    c = r.ctx
    if c = invalid or c.seq <> m.mvSeq then return
    ' multiview ended while it was asked (Back, or something else plays now): it stays ended
    if c.wasOn = true and m.mv = invalid then return
    if m.vod <> invalid or m.rec <> invalid then return
    if r.ok <> true or Type(r.data) <> "roAssociativeArray" then
        why = "TunerBox didn't answer"
        if r.detail <> invalid and anyStr(r.detail) <> "" then why = anyStr(r.detail)
        showToast("Can't play that: " + why)
        return
    end if
    d = r.data
    if d.ok <> true then
        mvNoRoom(d, c.slot, c.ch)
        return
    end if
    ' the pictures as they'll be: the ones that move to another playlist, then the new one
    tiles = []
    if m.mv <> invalid then
        for each t in m.mv.tiles
            tiles.Push(t)
        end for
    else
        t = mvMainTile()
        if t <> invalid then tiles.Push(t)
    end if
    if Type(d.moves) = "roArray" then
        for each mo in d.moves
            for each t in tiles
                if t.slot = Int(numv(mo.slot)) then t.alt = Int(numv(mo.alt))
            end for
        end for
    end if
    nt = mvNewTile(c.slot, c.ch.num, c.ch.key, Int(numv(d.alt)), c.ch.name)
    put = false
    for i = 0 to tiles.Count() - 1
        if tiles[i].slot = c.slot then
            mvSaveVod(tiles[i])
            tiles[i] = nt
            put = true
        end if
    end for
    if not put then tiles.Push(nt)
    if anyStr(d.note) <> "" then showToast(anyStr(d.note))
    starting = (m.mv = invalid)
    if starting then
        m.mv = { tiles: tiles, order: [], focus: 1, layout: "", sound: 1, streamSound: 0, retries: 0, why: {}, room: "" }
    else
        m.mv.tiles = tiles
    end if
    mvOrder()
    ' a new picture keeps the highlight where it was (it plays without sound until you highlight it)
    order = mvOrder()
    if m.mv.focus < 0 or mvTile(m.mv.focus) = invalid then m.mv.focus = order[0]
    m.mv.layout = mvLayoutFor(tiles.Count())
    mvStartStream()
    if starting then mvHint("Arrows move  " + Chr(183) + "  OK swap or full screen  " + Chr(183) + "  Options menu  " + Chr(183) + "  Back leave multiview")
end sub

' nothing could make room: say what's using the connections, and offer to swap one of this screen's own pictures
sub mvNoRoom(d as Object, slot as Integer, ch as Object)
    lines = []
    if anyStr(d.reason) <> "" then lines.Push(anyStr(d.reason) + ".")
    buttons = []
    actions = []
    swaps = []
    if Type(d.full) = "roArray" then
        for each f in d.full
            lines.Push(anyStr(f.source) + " allows " + anyStr(f.limit) + " at a time.")
            if Type(f.using) = "roArray" then
                for each u in f.using
                    us = Int(numv(u.slot))
                    if us > 0 and us <> slot then
                        buttons.Push("Swap " + anyStr(u.title) + " for " + ch.name)
                        actions.Push("s" + swaps.Count().ToStr())
                        swaps.Push({ slot: us, ch: ch })
                    else if us = 0 then
                        who = []
                        if Type(u.viewers) = "roArray" then
                            for each v in u.viewers
                                who.Push(anyStr(v.name))
                            end for
                        end if
                        lines.Push("In use: " + anyStr(u.title) + " (" + who.Join(", ") + ")")
                    end if
                end for
            end if
        end for
    end if
    lines.Push("Your channels that are on another playlist were already checked.")
    buttons.Push("OK")
    actions.Push("cancel")
    m.mvSwapOpts = swaps
    showDialog("mvswap", "Can't add " + ch.name, lines, buttons, actions)
end sub

sub mvSwapAction(action as String)
    opts = m.mvSwapOpts
    m.mvSwapOpts = invalid
    if opts = invalid or Left(action, 1) <> "s" then return
    i = Int(Val(Mid(action, 2)))
    if i >= 0 and i < opts.Count() then mvPut(opts[i].slot, opts[i].ch)
end sub

' ------------------------------------------------------------ the tiled stream
function mvStreamUrl() as String
    list = []
    for each s in mvOrder()
        list.Push(mvSpec(mvTile(s)))
    end for
    order = mvOrder()
    snd = m.mv.sound
    if m.mv.focus > 0 then snd = m.mv.focus
    if mvTile(snd) = invalid then snd = order[0]
    m.mv.streamSound = snd
    u = m.base + "/api/mv/stream?client=" + urlEncode(vodClientId()) + "&layout=" + m.mv.layout
    u = u + "&tiles=" + urlEncode(FormatJson(list)) + "&sound=" + snd.ToStr() + "&name=" + urlEncode(deviceName())
    if isCompat() then u = u + "&mode=roku720"
    return u
end function

' (re)start the tiled stream for the pictures as they are now
sub mvStartStream()
    if m.mv = invalid then return
    ' on live TV (a change you made): the menu closes and the picture fills the screen. A retry while the
    ' Guide, Sports or Search is up only restarts the picture, leaving that screen and its focus alone.
    onTv = (m.mode = "live")
    if onTv and m.menu.visible then closeMenuView()
    if onTv then m.hud.callFunc("hideAll")
    m.placesTimer.control = "stop"
    c = CreateObject("roSGNode", "ContentNode")
    c.url = mvStreamUrl()
    c.title = "Multiview"
    c.live = true
    c.streamFormat = "ts"
    m.extern = invalid
    m.playIdx = -1
    if onTv then setPreviewSize(false)
    m.video.control = "stop"
    m.video.content = c
    m.video.control = "play"
    m.video.mute = m.hud.muted
    m.retryTimer.control = "stop"
    m.mvPoll.control = "start"
    m.mvVis.control = "start"
    if onTv then m.top.setFocus(true)
    mvRender()
    if mvCanAdd() then mvApi("mvroom", "/api/mv/room", invalid, {})
end sub

sub mvVideoState(st as String)
    if st = "playing" then
        m.mv.retries = 0
        mvSound()
    else if st = "error" or st = "finished" then
        if m.mv.retries < 2 then
            m.mv.retries = m.mv.retries + 1
            m.retryTimer.control = "stop"
            m.retryTimer.control = "start"
        else
            showToast("Multiview stopped: TunerBox couldn't make the picture")
            mvEnd(m.mv.focus)
        end if
    end if
end sub

' the highlighted picture's sound: TunerBox turns it up in the stream that's playing (POST /api/mv/sound), so
' the pictures don't stop; heard once the Roku's buffer catches up. If that fails (no stream playing yet),
' the stream is asked for again with that sound.
sub mvSound()
    if m.mv = invalid then return
    want = m.mv.focus
    if want <= 0 or mvTile(want) = invalid then return
    m.mv.sound = want
    if want = m.mv.streamSound then return
    m.mv.streamSound = want
    mvApi("mvsound", "/api/mv/sound", { client: vodClientId(), slot: want }, { slot: want })
end sub

sub mvSoundDone(r as Object)
    if m.mv = invalid or r.ctx = invalid then return
    if r.ok = true and Type(r.data) = "roAssociativeArray" and r.data.ok = true then return
    if r.ctx.slot = m.mv.sound and m.video.state = "playing" then mvStartStream()
end sub

sub onMvPoll()
    if m.mv = invalid then
        m.mvPoll.control = "stop"
        return
    end if
    mvApi("mvstatus", "/api/mv/status?client=" + urlEncode(vodClientId()), invalid, {})
end sub

' each picture's trouble from TunerBox ("No Signal", "All connections in use"), shown on it
sub mvStatusDone(r as Object)
    if m.mv = invalid or r.ok <> true or Type(r.data) <> "roAssociativeArray" then return
    why = {}
    if Type(r.data.tiles) = "roArray" then
        for each t in r.data.tiles
            if t.ok <> true and anyStr(t.why) <> "" then why[anyStr(t.slot)] = anyStr(t.why)
            ' an On Demand picture: how far in it is (kept for saving its place, and for full screen)
            pt = mvTile(Int(numv(t.slot)))
            if pt <> invalid and pt.vod <> "" and t.pos <> invalid then
                pt.pos = numv(t.pos)
                if numv(t.duration) > 0 then pt.dur = Int(numv(t.duration))
            end if
        end for
    end if
    m.mv.why = why
    if nowEpoch() - m.mvSaved >= 15 then
        m.mvSaved = nowEpoch()
        for each t in m.mv.tiles
            mvSaveVod(t)
        end for
    end if
    mvRender()
end sub

' how far into its title an On Demand picture is (what TunerBox last said, else where it started)
function mvVodPos(t as Object) as Float
    if t.pos <> invalid then return t.pos
    return t.at
end function

' keep an On Demand picture's place, as the full-screen player does (not a catch-up show's)
sub mvSaveVod(t as Object)
    if t.vod = "" or t.cu = true then return
    at = mvVodPos(t)
    if at < 5 then return
    mvApi("mvprog", "/api/vod/progress", { id: t.vod, position: at, duration: t.dur }, {})
end sub

' startVod: an On Demand title started while multiview is on (or picked for a new picture) plays in a small
' picture, the highlighted one, else the first; true when this took it
function mvVodRoute(it as Object, start as Float) as Boolean
    if m.mvVodFull then
        m.mvVodFull = false
        return false
    end if
    adding = m.mvVodAdd > 0 and nowEpoch() - m.mvVodAdd < 300
    m.mvVodAdd = 0
    if m.mv = invalid and not adding then return false
    if m.vod <> invalid then return false
    ' startVod has closed the On Demand screen (and the Guide, Sports, Search): back on live TV
    if m.mode <> "live" then m.mode = "live"
    slot = 0
    if adding and mvCanAdd() then
        ' a small picture: never picture 1 (the main one, as on the web)
        for s = 2 to 4
            if slot = 0 and mvTile(s) = invalid then slot = s
        end for
    end if
    if slot = 0 and m.mv <> invalid then
        if m.mv.focus > 1 then
            slot = m.mv.focus
        else
            order = mvOrder()
            for each s in order
                if slot = 0 and s > 1 then slot = s
            end for
        end if
    end if
    if slot = 0 then
        if adding then showToast("There's room for " + mvMaxPics().ToStr() + " channels at once")
        return adding
    end if
    if m.mv = invalid then
        main = mvMainTile()
        if main = invalid then return false
        m.mv = { tiles: [main], order: [], focus: 1, layout: "", sound: 1, streamSound: 0, retries: 0, why: {}, room: "" }
        mvHint("Arrows move  " + Chr(183) + "  OK full screen  " + Chr(183) + "  Options menu  " + Chr(183) + "  Back leave multiview")
    end if
    nt = mvNewTile(slot, "", "", 0, plainText(anyStr(it.title)))
    nt.vod = anyStr(it.id)
    nt.at = start
    nt.dur = Int(numv(it.duration))
    nt.cu = truthy(it.catchup)
    tiles = []
    put = false
    for each t in m.mv.tiles
        if t.slot = slot then
            mvSaveVod(t)
            tiles.Push(nt)
            put = true
        else
            tiles.Push(t)
        end if
    end for
    if not put then tiles.Push(nt)
    m.mv.tiles = tiles
    order = mvOrder()
    if mvTile(m.mv.focus) = invalid then m.mv.focus = order[0]
    m.mv.layout = mvLayoutFor(tiles.Count())
    m.returnHome = false
    mvStartStream()
    return true
end function

' ------------------------------------------------------------ drawing
' the places on screen, in place order: { x, y, w, h, kind, slot (0 for "+ Add") }
function mvPlaces() as Object
    rects = mvRects(m.mv.layout)
    order = mvOrder()
    spare = 0
    if mvCanAdd() then spare = rects.Count() - order.Count()
    out = []
    for i = 0 to rects.Count() - 1
        rc = rects[i]
        if i < order.Count() then
            out.Push({ x: rc[0], y: rc[1], w: rc[2], h: rc[3], kind: "pic", slot: order[i], place: i + 1 })
        else if i - order.Count() < spare then
            out.Push({ x: rc[0], y: rc[1], w: rc[2], h: rc[3], kind: "add", slot: 0, place: i + 1 })
        end if
    end for
    return out
end function

sub mvRender()
    if m.mv = invalid then
        m.mvView.visible = false
        return
    end if
    cells = []
    for each p in mvPlaces()
        c = { x: p.x, y: p.y, w: p.w, h: p.h, kind: p.kind, label: "", now: "", msg: "", focus: false, sound: false, room: m.mv.room }
        if p.kind = "pic" then
            t = mvTile(p.slot)
            c.label = t.name
            c.focus = (m.mv.focus = p.slot)
            c.sound = (m.mv.focus = p.slot or (m.mv.focus < 0 and m.mv.sound = p.slot))
            w = m.mv.why[p.slot.ToStr()]
            if w <> invalid then c.msg = w
            if t.vod <> "" then
                c.now = "On Demand"
                at = mvVodPos(t)
                if at > 0 then c.now = c.now + "  " + fmtDur(at)
                if t.dur > 0 then c.now = c.now + " of " + fmtDur(t.dur)
            else if t.key = "" then
                idx = chIndexByNum(t.num)
                if idx >= 0 then
                    pg = progAt(m.channels[idx], nowEpoch())
                    if pg <> invalid then c.now = anyStr(pg.title)
                end if
            end if
        else
            c.focus = (m.mv.focus = -p.place)
        end if
        cells.Push(c)
    end for
    m.mvView.safe = [m.fitOff[0], m.fitOff[1], m.fitOff[0], m.fitOff[1]]
    m.mvView.cells = cells
    m.mvView.visible = (m.mode = "live")
end sub

sub mvHint(text as String)
    m.mvView.hint = text
    m.mvHintTimer.control = "stop"
    m.mvHintTimer.control = "start"
end sub

sub onMvHintTimer()
    m.mvView.hint = ""
end sub

' ------------------------------------------------------------ the remote in multiview
function mvKey(key as String) as Boolean
    m.mvView.hint = ""
    if key = "up" or key = "down" or key = "left" or key = "right" then
        mvMove(key)
    else if key = "OK" then
        mvOk()
    else if key = "back" then
        mvEnd(m.mv.focus)
    else if key = "options" then
        mvMenu()
    else if key = "play" then
        toggleMute()
    else if Left(key, 4) = "Lit_" then
        if LCase(Mid(key, 5)) = "w" then
            mvMenu()
            return true
        end if
        return liveLit(Mid(key, 5))
    end if
    return true
end function

' the place next to the highlighted one in direction k (as the web: by the places' centres)
sub mvMove(k as String)
    places = mvPlaces()
    cur = invalid
    for each p in places
        if (p.kind = "pic" and m.mv.focus = p.slot) or (p.kind = "add" and m.mv.focus = -p.place) then cur = p
    end for
    if cur = invalid then cur = places[0]
    cx = cur.x + cur.w / 2
    cy = cur.y + cur.h / 2
    best = invalid
    bestD = 99999999
    for each p in places
        if p.place <> cur.place then
            dx = (p.x + p.w / 2) - cx
            dy = (p.y + p.h / 2) - cy
            along = dx
            across = Abs(dy)
            if k = "left" then along = -dx
            if k = "down" then along = dy
            if k = "up" then along = -dy
            if k = "up" or k = "down" then across = Abs(dx)
            if along > 10 then
                dist = along + 2 * across
                if dist < bestD then
                    bestD = dist
                    best = p
                end if
            end if
        end if
    end for
    if best = invalid then return
    if best.kind = "pic" then m.mv.focus = best.slot else m.mv.focus = -best.place
    mvRender()
    mvSound()
end sub

function mvBigLayout() as Boolean
    return m.mv.layout = "big" or m.mv.layout = "big3"
end function

' OK on the highlighted place
sub mvOk()
    if m.mv.focus < 0 then
        mvPicker("", 0)
        return
    end if
    order = mvOrder()
    if m.mv.layout = "pip" and order.Count() > 1 then
        mvSwap(order[1])
    else if mvBigLayout() and order[0] <> m.mv.focus then
        mvSwap(m.mv.focus)
    else
        mvEnd(m.mv.focus)
    end if
end sub

' picture `slot` takes the big place (the stream restarts with the pictures moved; their tuners stay)
sub mvSwap(slot as Integer)
    order = mvOrder()
    i = -1
    for j = 0 to order.Count() - 1
        if order[j] = slot then i = j
    end for
    if i <= 0 then return
    first = order[0]
    order[0] = slot
    order[i] = first
    m.mv.order = order
    m.mv.focus = slot
    mvStartStream()
end sub

' ------------------------------------------------------------ menus
' Menu > Multiview (not on yet): the layouts that fit, then the channel to add. Asks TunerBox once whether it
' makes the tiled stream (an older one doesn't).
sub mvOpen()
    if m.mv <> invalid then
        mvMenu()
        return
    end if
    if not m.mvEnabled then
        showToast("Multiview is turned off in Setup > Settings > Screens")
        return
    end if
    if mvMaxPics() < 2 then
        showToast("Your playlists allow one channel at a time")
        return
    end if
    if mvMainTile() = invalid or m.mode <> "live" then
        showToast("Tune to a channel first")
        return
    end if
    if m.mvTiled = -1 then
        mvApi("mvprobe", "/api/mv/status?client=" + urlEncode(vodClientId()), invalid, { open: true })
        return
    end if
    if m.mvTiled = 0 then
        showToast("This TunerBox can't make multiview for a Roku yet: update it")
        return
    end if
    items = []
    for each l in mvFits(2)
        items.Push({ id: "mvl_" + l, label: mvLayoutName(l), value: mvSize(l).ToStr() })
    end for
    items.Push({ id: "mvclose", label: "Cancel" })
    m.hud.callFunc("hideAll")
    m.menuPage = "mvlay"
    m.menu.heading = "Watch two or more channels"
    m.menu.subtitle = "Pick how the pictures share the screen, then the channel to add. Up to " + mvMaxPics().ToStr() + " at once."
    m.menu.items = items
    m.menu.callFunc("openMenu")
end sub

' Options in multiview: the highlighted picture, adding one, the layouts, leaving
sub mvMenu()
    items = []
    t = invalid
    if m.mv.focus > 0 then t = mvTile(m.mv.focus)
    if t <> invalid then
        items.Push({ id: "mvchg", label: "Change channel: " + t.name })
        items.Push({ id: "mvrm", label: "Take " + t.name + " off the screen" })
    end if
    if mvCanAdd() then items.Push({ id: "mvadd", label: "Add a channel" })
    ' every layout this screen may use; one with fewer places says which channels it stops
    for each l in mvFits(2)
        lbl = mvLayoutName(l)
        gone = mvGone(l)
        if gone.Count() > 0 then lbl = lbl + " (stops " + mvNames(gone) + ")"
        v = ""
        if l = m.mv.layout then v = "ON"
        items.Push({ id: "mvl_" + l, label: lbl, value: v })
    end for
    items.Push({ id: "mvend", label: "Leave multiview (keep the highlighted channel)" })
    items.Push({ id: "mvmain", label: "Main menu" })
    items.Push({ id: "mvclose", label: "Close" })
    m.hud.callFunc("hideAll")
    m.menuPage = "mv"
    m.menu.heading = "Multiview"
    m.menu.subtitle = "Up to " + mvMaxPics().ToStr() + " at once. A layout with fewer places stops the channels that don't fit."
    m.menu.items = items
    m.menu.callFunc("openMenu")
end sub

function mvNames(slots as Object) as String
    names = []
    for each s in slots
        t = mvTile(s)
        if t <> invalid then names.Push(t.name)
    end for
    return names.Join(", ")
end function

' layout l with fewer places than there are pictures: which ones stop (the big one and the highlighted one stay)
function mvGone(l as String) as Object
    order = mvOrder()
    keep = []
    cand = [order[0]]
    if m.mv.focus > 0 then cand.Push(m.mv.focus)
    cand.Append(order)
    for each s in cand
        dup = false
        for each k in keep
            if k = s then dup = true
        end for
        if not dup and keep.Count() < mvSize(l) then keep.Push(s)
    end for
    out = []
    for each s in order
        stay = false
        for each k in keep
            if k = s then stay = true
        end for
        if not stay then out.Push(s)
    end for
    return out
end function

' change to layout l, stopping the pictures it has no place for
sub mvFitTo(l as String)
    gone = mvGone(l)
    if gone.Count() > 0 then
        names = mvNames(gone)
        tiles = []
        for each t in m.mv.tiles
            stay = true
            for each s in gone
                if s = t.slot then stay = false
            end for
            if stay then tiles.Push(t) else mvSaveVod(t)
        end for
        m.mv.tiles = tiles
        if tiles.Count() < 2 then
            mvEnd(tiles[0].slot)
            return
        end if
        order = mvOrder()
        if mvTile(m.mv.focus) = invalid then m.mv.focus = order[0]
        showToast("Stopped " + names + " to fit " + mvLayoutName(l))
    end if
    mvSetLayoutPref(l)
    m.mv.layout = l
    mvStartStream()
end sub

' "Pick the channel to add" (slot 0), or the channel for picture `slot` (Change channel): favorites, recent
' channels, or find one in the Guide, Sports or Search. `layout`: the one picked first (starting multiview).
sub mvPicker(layout as String, slot as Integer)
    if slot = 0 and not mvCanAdd() then
        showToast("There's room for " + mvMaxPics().ToStr() + " channels at once")
        return
    end if
    if slot > 0 and m.mv <> invalid then m.mv.focus = slot
    playing = {}
    if m.mv <> invalid then
        for each t in m.mv.tiles
            if t.num <> "" and t.vod = "" then playing[t.num] = true
        end for
    else
        t = mvMainTile()
        if t <> invalid and t.num <> "" then playing[t.num] = true
    end if
    opts = []
    items = []
    for each ch in m.channels
        if opts.Count() >= 6 then exit for
        if m.favs[ch.numStr] <> invalid and playing[ch.numStr] = invalid then
            items.Push({ id: "mvp_" + opts.Count().ToStr(), label: ch.numStr + " " + ch.name, value: "FAV" })
            opts.Push({ num: ch.numStr, key: "", name: ch.numStr + " " + ch.name })
        end if
    end for
    nrec = 0
    for each n in regRead("recent", "").Split(",")
        if nrec >= 4 then exit for
        idx = chIndexByNum(n)
        if n <> "" and idx >= 0 and playing[n] = invalid and m.favs[n] = invalid then
            ch = m.channels[idx]
            items.Push({ id: "mvp_" + opts.Count().ToStr(), label: ch.numStr + " " + ch.name, value: "RECENT" })
            opts.Push({ num: ch.numStr, key: "", name: ch.numStr + " " + ch.name })
            nrec = nrec + 1
        end if
    end for
    items.Push({ id: "mvguide", label: "From the TV Guide..." })
    items.Push({ id: "mvsports", label: "From Sports & Events..." })
    items.Push({ id: "mvsearch", label: "Search..." })
    ' movies and shows play in a small picture (not the main one)
    if m.vodOn and (slot = 0 or slot > 1) then items.Push({ id: "mvod", label: "From On Demand..." })
    items.Push({ id: "mvpback", label: "Cancel" })
    m.mvPick = { layout: layout, slot: slot, opts: opts }
    m.hud.callFunc("hideAll")
    m.menuPage = "mvpick"
    busy = "If its playlist is busy, a channel that's also on another playlist moves there to make room."
    if slot > 0 then
        t = mvTile(slot)
        nm = "this picture"
        if t <> invalid then nm = t.name
        m.menu.heading = "Change " + nm
        m.menu.subtitle = "Pick what plays in this picture instead. " + busy
    else
        l = layout
        if l = "" and m.mv <> invalid then l = m.mv.layout
        m.menu.heading = "Pick the channel to add"
        pre = ""
        if l <> "" then pre = mvLayoutName(l) + ": "
        m.menu.subtitle = pre + "it plays without sound until you highlight it. " + busy
    end if
    m.menu.items = items
    m.menu.callFunc("openMenu")
end sub

' the multiview pages of the menu (MainScene's onMenuSelected): true when it was one of them
function mvMenuSelected(id as String) as Boolean
    pg = m.menuPage
    if pg <> "mv" and pg <> "mvlay" and pg <> "mvpick" then return false
    if id = "mvclose" then
        closeMenuView()
    else if id = "mvmain" then
        showMenu()
    else if Left(id, 4) = "mvl_" then
        l = Mid(id, 5)
        if pg = "mvlay" then
            mvPicker(l, 0)
        else
            closeMenuView()
            if l <> m.mv.layout then mvFitTo(l)
        end if
    else if id = "mvchg" then
        mvPicker("", m.mv.focus)
    else if id = "mvrm" then
        closeMenuView()
        mvRemove(m.mv.focus)
    else if id = "mvadd" then
        mvPicker("", 0)
    else if id = "mvend" then
        closeMenuView()
        mvEnd(m.mv.focus)
    else if Left(id, 4) = "mvp_" then
        pk = m.mvPick
        m.mvPick = invalid
        closeMenuView()
        i = Int(Val(Mid(id, 5)))
        if pk = invalid or i < 0 or i >= pk.opts.Count() then return true
        if pk.layout <> "" then mvSetLayoutPref(pk.layout)
        if pk.slot > 0 then
            mvPut(pk.slot, pk.opts[i])
        else
            mvPut(mvFreeSlot(), pk.opts[i])
        end if
    else if id = "mvguide" or id = "mvsports" or id = "mvsearch" then
        pk = m.mvPick
        m.mvPick = invalid
        closeMenuView()
        if pk <> invalid and pk.layout <> "" then mvSetLayoutPref(pk.layout)
        ' adding: what's picked there goes in a new picture; changing: in the highlighted one
        if pk <> invalid and pk.slot = 0 then m.mvAdd = nowEpoch() else m.mvAdd = 0
        if m.mv <> invalid then m.mvView.visible = false
        if id = "mvguide" then
            openGuide(m.curIdx, invalid, "")
            showToast("Pick a channel for multiview")
        else if id = "mvsports" then
            openSports()
        else
            promptSearch()
        end if
    else if id = "mvod" then
        pk = m.mvPick
        m.mvPick = invalid
        closeMenuView()
        if pk <> invalid and pk.layout <> "" then mvSetLayoutPref(pk.layout)
        m.mvAdd = 0
        if pk <> invalid and pk.slot = 0 then m.mvVodAdd = nowEpoch() else m.mvVodAdd = 0
        if m.mv <> invalid then m.mvView.visible = false
        openOnDemand({})
    else if id = "mvpback" then
        mvMenuBack()
    end if
    return true
end function

' Back on a multiview page of the menu: true when it was one
function mvMenuBack() as Boolean
    pg = m.menuPage
    if pg = "mvpick" then
        pk = m.mvPick
        m.mvPick = invalid
        if pk <> invalid and pk.layout <> "" and m.mv = invalid then
            mvOpen()
        else
            closeMenuView()
        end if
        return true
    end if
    if pg = "mv" or pg = "mvlay" then
        closeMenuView()
        return true
    end if
    return false
end function

' ------------------------------------------------------------ leaving
' take picture `slot` off the screen; down to one picture, multiview ends with that one full screen
sub mvRemove(slot as Integer)
    if m.mv = invalid then return
    tiles = []
    for each t in m.mv.tiles
        if t.slot <> slot then tiles.Push(t) else mvSaveVod(t)
    end for
    if tiles.Count() = 0 then return
    if tiles.Count() = 1 then
        mvEnd(tiles[0].slot)
        return
    end if
    m.mv.tiles = tiles
    order = mvOrder()
    if mvTile(m.mv.focus) = invalid then m.mv.focus = order[0]
    if m.mv.layout <> mvLayoutFor(tiles.Count()) then
        fits = mvFits(tiles.Count())
        keepL = false
        for each l in fits
            if l = m.mv.layout then keepL = true
        end for
        if not keepL then m.mv.layout = mvLayoutFor(tiles.Count())
    end if
    mvStartStream()
end sub

' leave multiview: picture `slot` (the highlighted one) fills the screen, the rest stop. TunerBox stops every
' picture first (POST /api/stop), so the channel kept finds its connection free.
sub mvEnd(slot as Integer)
    if m.mv = invalid then return
    keep = mvTile(slot)
    order = mvOrder()
    if keep = invalid then keep = mvTile(order[0])
    mvForget()
    m.video.control = "stop"
    mvApi("mvstop", "/api/stop", { client: vodClientId() }, { keep: keep })
end sub

' after /api/stop: the picture kept plays as a single channel
sub mvPlaySingle(t as Object)
    if m.mv <> invalid or m.vod <> invalid or m.rec <> invalid then return
    if t.vod <> "" then             ' On Demand: the full-screen player, from where the picture was
        m.mvVodFull = true
        playVod(t.vod, mvVodPos(t), false)
        return
    end if
    if t.key <> "" then
        playExternal({ num: "EVENT", name: "", title: t.name, url: m.base + "/api/feed/stream?key=" + urlEncode(t.key), key: t.key })
    else
        idx = chIndexByNum(t.num)
        if idx >= 0 then
            commitChannel(idx)
            playChannelFeed(idx, t.alt)
        else
            playExternal({ num: t.num, name: t.name, title: t.name, url: m.base + "/api/stream/" + t.num })
        end if
    end if
    showBanner()
end sub

' multiview is over on this Roku (something else plays now); TunerBox stops the pictures when this Roku's
' next stream starts, or a few seconds after the tiled stream ends
sub mvForget()
    m.mvSeq = m.mvSeq + 1       ' a plan still on its way is for multiview that's over
    if m.mv = invalid then return
    for each t in m.mv.tiles
        mvSaveVod(t)
    end for
    m.mv = invalid
    m.mvAdd = 0
    m.mvPoll.control = "stop"
    m.mvVis.control = "stop"
    m.mvHintTimer.control = "stop"
    m.mvView.hint = ""
    m.mvView.visible = false
end sub
