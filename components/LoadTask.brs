' Background loader (runs off the UI thread).
'   mode "boot":  channel list.  cache -> sidecar /channels.json -> M3U parse
'   mode "guide": programme guide. sidecar /guide.json -> epg.xml parse
' Caches live in cachefs:/ so the second launch is nearly instant.

sub init()
    m.top.functionName = "loadData"
end sub

sub loadData()
    mode = m.top.mode
    if mode = "guide" then
        loadGuide()
    else if mode = "favs" then
        loadFavs()
    else if mode = "setfav" then
        setFav()
    else if mode = "sports" then
        loadSports()
    else if mode = "sgroup" then
        loadSportsGroup()
    else if mode = "scheck" then
        startSportsCheck()
    else if mode = "scheckstate" then
        loadSportsCheckState()
    else if mode = "record" then
        postRecord()
    else if mode = "search" then
        loadSearch()
    else if mode = "espn" then
        loadLiveSports()
    else if mode = "api" then
        callApi()
    else
        loadBoot()
    end if
end sub

' ============================================================ cache + sidecar helpers
function cachePath(kind as String) as String
    if kind = "channels" and m.top.hideUnmapped then kind = "channels_h"
    safe = hostOnly(m.top.baseUrl)
    r = CreateObject("roRegex", "[^A-Za-z0-9]", "")
    safe = r.ReplaceAll(safe, "_")
    return "cachefs:/tbx_" + safe + "_" + kind + ".json"
end function

function readCache(kind as String) as String
    path = cachePath(kind)
    fs = CreateObject("roFileSystem")
    if not fs.Exists(path) then return ""
    return ReadAsciiFile(path)
end function

sub writeCache(kind as String, txt as String)
    ok = WriteAsciiFile(cachePath(kind), txt)
    print "[TunerBox] cache write " + kind + ": " + ok.ToStr() + " (" + Len(txt).ToStr() + " chars)"
end sub

' drop the 20000+ "unmapped" channels (no real channel number / no guide match)
function filterMapped(channels as Object) as Object
    if not m.top.hideUnmapped then return channels
    out = []
    for each c in channels
        if c.numVal < 20000 then out.Push(c)
    end for
    if out.Count() = 0 then return channels
    return out
end function

function unmappedFlag() as String
    if m.top.hideUnmapped then return "0"
    return "1"
end function

function sidecarBase() as String
    return "http://" + hostOnly(m.top.baseUrl) + ":8643"
end function

function sidecarUp() as Boolean
    return fetchText(sidecarBase() + "/health", 2500) <> ""
end function

function rowsToChannels(rows as Object) as Object
    out = []
    for each r in rows
        out.Push({ numStr: r[0], name: r[1], logo: r[2], group: r[3], url: r[4], tvgId: r[5], tvgName: r[6], numVal: Val(r[0]) + 0.0, programs: invalid })
    end for
    return out
end function

function channelsToRows(channels as Object) as Object
    out = []
    for each c in channels
        out.Push([c.numStr, c.name, c.logo, c.group, c.url, c.tvgId, c.tvgName])
    end for
    return out
end function

' { numStr: [rows] } -> { numStr: [prog] } within the time window
function guideFromJson(programs as Object, tFrom as Integer, tTo as Integer) as Object
    out = {}
    for each key in programs.Keys()
        list = jsonProgs(programs[key], tFrom, tTo)
        if list.Count() > 0 then out[key] = list
    end for
    return out
end function

function progsToRows(byNum as Object) as Object
    out = {}
    for each key in byNum.Keys()
        rows = []
        for each p in byNum[key]
            rows.Push([p.start, p.stop, p.title, p.subtitle, p.desc, p.cat, p.ep, p.rating])
        end for
        out[key] = rows
    end for
    return out
end function

function readGuideCache() as Object
    txt = readCache("guide")
    if txt = "" then return invalid
    data = ParseJson(txt)
    if data = invalid or data.programs = invalid then return invalid
    t = nowEpoch()
    g = guideFromJson(data.programs, t - 3 * 3600, t + 48 * 3600)
    if g.Count() = 0 then return invalid
    return g
end function

' ============================================================ Sports & PPV, DVR (TunerBox /api/sports, /api/recordings)
function getObj(path as String, timeoutMs as Integer) as Object
    txt = fetchText(m.top.baseUrl + path, timeoutMs)
    if txt = "" then return invalid
    return ParseJson(txt)
end function

sub loadSports()
    result = { ok: false, data: invalid }
    d = getObj("/api/sports", 30000)
    if d <> invalid and d.on_now <> invalid and d.upcoming <> invalid and d.channels <> invalid and d.groups <> invalid then
        result.data = d
        result.ok = true
    end if
    print "[TunerBox] sports: ok=" + result.ok.ToStr()
    m.top.result = result
end sub

sub loadSportsGroup()
    result = { ok: false, data: invalid }
    esc = CreateObject("roUrlTransfer").Escape(m.top.sportsGroup)
    d = getObj("/api/sports/group?name=" + esc, 20000)
    if d <> invalid and d.feeds <> invalid then
        result.data = d
        result.ok = true
    end if
    m.top.result = result
end sub

sub startSportsCheck()
    result = { ok: false, data: invalid }
    txt = postText(m.top.baseUrl + "/api/sports/check", FormatJson({ group: m.top.sportsGroup }), 15000)
    if txt <> "" then
        d = ParseJson(txt)
        if d <> invalid then
            result.data = d
            result.ok = true
        end if
    end if
    m.top.result = result
end sub

sub loadSportsCheckState()
    result = { ok: false, data: invalid }
    d = getObj("/api/sports/check", 8000)
    if d <> invalid then
        result.data = d
        result.ok = true
    end if
    m.top.result = result
end sub

sub loadSearch()
    q = m.top.searchQuery
    result = { ok: false, data: invalid, query: q }
    esc = CreateObject("roUrlTransfer").Escape(q.Trim())
    d = getObj("/api/search?q=" + esc, 15000)
    if d <> invalid and d.channels <> invalid and d.programs <> invalid then
        result.data = d
        result.ok = true
    end if
    m.top.result = result
end sub

sub postRecord()
    result = { ok: false }
    body = FormatJson({ number: Val(m.top.recNumber, 10), start: Val(m.top.recStart, 10) })
    txt = postText(m.top.baseUrl + "/api/recordings", body, 15000)
    if txt <> "" then result.ok = true
    print "[TunerBox] record " + m.top.recNumber + " @" + m.top.recStart + " ok=" + result.ok.ToStr()
    m.top.result = result
end sub

' ============================================================ live sports (ESPN public scoreboards, matched to the guide)
' result.games = [{ id, lg, league, title, start, state ("pre"|"in"), detail, score, nets, chans: [{ number, name, label, start, stop }] }]
' Matching runs against the cached guide (cachefs), so nothing big has to be copied over from the scene.
sub loadLiveSports()
    t0 = CreateObject("roTimespan")
    result = { ok: false, games: [], matched: 0, hasGuide: false }
    now = nowEpoch()
    sel = m.top.leagues
    lgs = []
    urls = []
    ' ESPN dates are US Eastern; yesterday..tomorrow catches late games still running after midnight.
    ' One request per day: ESPN answers a "from-to" date range with HTTP 400. All of them go out together.
    days = [espnDate(now - 86400), espnDate(now), espnDate(now + 86400)]
    for each lg in sportsLeagues()
        if leagueOn(sel, lg.id) then
            for each day in days
                lgs.Push(lg)
                urls.Push(espnUrl(lg, day))
            end for
        end if
    end for
    if urls.Count() = 0 then
        result.ok = true
        m.top.result = result
        return
    end if

    texts = fetchMany(urls, 20000)
    games = []
    seenEv = {}
    for i = 0 to lgs.Count() - 1
        if addEspnGames(texts[i], lgs[i], now, games, seenEv) then result.ok = true
        texts[i] = ""
    end for
    print "[TunerBox] live sports: " + games.Count().ToStr() + " games from " + urls.Count().ToStr() + " requests in " + t0.TotalMilliseconds().ToStr() + " ms"

    result.hasGuide = matchGames(games, now)
    for each g in games
        if g.chans.Count() > 0 then result.matched = result.matched + 1
        g.Delete("teams")
        g.Delete("kw")
    end for
    games.SortBy("start")
    result.games = games
    print "[TunerBox] live sports: " + result.matched.ToStr() + "/" + games.Count().ToStr() + " matched to the guide, " + t0.TotalMilliseconds().ToStr() + " ms total"
    m.top.result = result
end sub

function espnUrl(lg as Object, dates as String) as String
    u = "https://site.api.espn.com/apis/site/v2/sports/" + lg.path + "/scoreboard?limit=500&dates=" + dates
    if lg.groups <> "" then u = u + "&groups=" + lg.groups
    return u
end function

' Adds the games from one scoreboard reply; an event already added (same league + id) is skipped.
' Returns false when the reply is missing or isn't a scoreboard.
function addEspnGames(txt as String, lg as Object, now as Integer, games as Object, seenEv as Object) as Boolean
    if txt = "" then return false
    d = ParseJson(txt)
    if Type(d) <> "roAssociativeArray" or Type(d.events) <> "roArray" then return false
    for each ev in d.events
        if Type(ev) = "roAssociativeArray" then
            k = lg.id + "|" + jsStr(ev.id)
            if jsStr(ev.id) = "" or seenEv[k] = invalid then
                seenEv[k] = true
                g = espnGame(ev, lg, now)
                if g <> invalid then games.Push(g)
            end if
        end if
    end for
    return true
end function

' GET several URLs at once; returns their bodies in the same order ("" on failure)
function fetchMany(urls as Object, timeoutMs as Integer) as Object
    port = CreateObject("roMessagePort")
    xfers = {}
    out = []
    for i = 0 to urls.Count() - 1
        out.Push("")
        x = CreateObject("roUrlTransfer")
        x.SetPort(port)
        x.SetUrl(urls[i])
        x.EnableEncodings(true)
        x.SetCertificatesFile("common:/certs/ca-bundle.crt")
        x.InitClientCertificates()
        x.AddHeader("Accept", "application/json")
        if x.AsyncGetToString() then xfers[x.GetIdentity().ToStr()] = { x: x, i: i }
    end for
    timer = CreateObject("roTimespan")
    while xfers.Count() > 0
        remain = timeoutMs - timer.TotalMilliseconds()
        if remain <= 0 then exit while
        msg = Wait(remain, port)
        if Type(msg) = "roUrlEvent" then
            k = msg.GetSourceIdentity().ToStr()
            e = xfers[k]
            if e <> invalid then
                if msg.GetResponseCode() = 200 then
                    out[e.i] = msg.GetString()
                else
                    print "[TunerBox] live sports: HTTP " + msg.GetResponseCode().ToStr() + " " + urls[e.i]
                end if
                xfers.Delete(k)
            end if
        else if msg = invalid then
            exit while
        end if
    end while
    for each k in xfers
        xfers[k].x.AsyncCancel()
    end for
    return out
end function

' local date as YYYYMMDD
function espnDate(t as Integer) as String
    dt = localDT(t)
    s = dt.GetYear().ToStr()
    mo = dt.GetMonth()
    d = dt.GetDayOfMonth()
    if mo < 10 then s = s + "0"
    s = s + mo.ToStr()
    if d < 10 then s = s + "0"
    return s + d.ToStr()
end function

' "2026-11-12T00:15Z" (UTC) -> epoch seconds, 0 if unparseable
function isoEpoch(s as Dynamic) as Integer
    x = jsStr(s)
    if Right(x, 1) = "Z" then x = Left(x, Len(x) - 1)
    p = Instr(1, x, "T")
    if p = 0 then return 0
    if Len(Mid(x, p + 1)) = 5 then x = x + ":00"
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(x)
    return dt.AsSeconds()
end function

function jsStr(v as Dynamic) as String
    if v = invalid then return ""
    t = Type(v)
    if t = "String" or t = "roString" then return v
    if t = "Integer" or t = "roInt" or t = "Float" or t = "roFloat" or t = "Double" or t = "LongInteger" then return Str(v).Trim()
    return ""
end function

' lower-case, punctuation -> spaces, padded so " word " tests whole words
function normText(s as String) as String
    if m.normRe = invalid then m.normRe = CreateObject("roRegex", "[^a-z0-9]+", "")
    return " " + m.normRe.ReplaceAll(LCase(s), " ").Trim() + " "
end function

sub addNeedle(list as Object, s as String)
    n = normText(s)
    if Len(n) < 5 then return   ' " ab " : too short to be safe
    for each e in list
        if e = n then return
    end for
    list.Push(n)
end sub

function hasAny(txt as String, needles as Object) as Boolean
    for each n in needles
        if Instr(1, txt, n) > 0 then return true
    end for
    return false
end function

' one ESPN event -> game, or invalid when it's finished / unusable
function espnGame(ev as Object, lg as Object, now as Integer) as Object
    if ev.competitions = invalid or ev.competitions.Count() = 0 then return invalid
    comp = ev.competitions[0]
    st = ev.status
    if st = invalid then st = comp.status
    if st = invalid or st.type = invalid then return invalid
    state = jsStr(st.type.state)
    if state <> "pre" and state <> "in" then return invalid
    start = isoEpoch(ev.date)
    if start = 0 then return invalid
    if state = "pre" and start < now - 6 * 3600 then return invalid   ' stale / never updated
    if comp.competitors = invalid or comp.competitors.Count() < 2 then return invalid

    awayIdx = -1
    homeIdx = -1
    teams = []
    for each c in comp.competitors
        t = c.team
        if t <> invalid then
            strong = []
            weak = []
            addNeedle(strong, jsStr(t.displayName))
            addNeedle(strong, jsStr(t.shortDisplayName))
            ' college nicknames (Tigers, Bulldogs...) are shared by dozens of schools
            if not lg.college then addNeedle(strong, jsStr(t.name))
            loc = normText(jsStr(t.location))
            if Len(loc) >= 5 and not hasAny(loc, strong) then weak.Push(loc)
            tm = { short: jsStr(t.shortDisplayName), abbr: jsStr(t.abbreviation), score: jsStr(c.score), strong: strong, weak: weak }
            if tm.short = "" then tm.short = jsStr(t.displayName)
            if tm.abbr = "" then tm.abbr = tm.short
            if c.homeAway = "home" then
                homeIdx = teams.Count()
            else
                awayIdx = teams.Count()
            end if
            teams.Push(tm)
        end if
    end for
    if teams.Count() < 2 then return invalid
    if homeIdx < 0 then homeIdx = 1
    if awayIdx < 0 or awayIdx = homeIdx then awayIdx = 1 - (homeIdx mod 2)
    away = teams[awayIdx]
    home = teams[homeIdx]

    sep = " at "
    if comp.neutralSite = true then sep = " vs "
    score = ""
    if state = "in" then score = away.abbr + " " + away.score + dashSep() + home.abbr + " " + home.score

    nets = []
    if comp.broadcasts <> invalid then
        for each b in comp.broadcasts
            if b.names <> invalid then
                for each nm in b.names
                    addNet(nets, jsStr(nm))
                end for
            end if
        end for
    end if
    if comp.geoBroadcasts <> invalid then
        for each b in comp.geoBroadcasts
            if b.media <> invalid then addNet(nets, jsStr(b.media.shortName))
        end for
    end if

    return {
        id: jsStr(ev.id)
        lg: lg.id
        league: lg.abbr
        kw: lg.kw
        title: away.short + sep + home.short
        start: start
        state: state
        detail: jsStr(st.type.shortDetail)
        score: score
        nets: nets.Join(", ")
        teams: teams
        chans: []
    }
end function

sub addNet(nets as Object, s as String)
    s = s.Trim()
    if s = "" then return
    for each e in nets
        if e = s then return
    end for
    nets.Push(s)
end sub

' {numStr: channel name} from the cached channel list
function cachedChannelNames() as Object
    out = {}
    txt = readCache("channels")
    if txt = "" then return out
    d = ParseJson(txt)
    if d = invalid or d.channels = invalid then return out
    for each r in d.channels
        out[r[0]] = r[1]
    end for
    return out
end function

' Find each game's TV guide listings. A listing matches a game when it starts between 60 min before and 45 min
' after the first pitch / kickoff, isn't a pre/post-game show, and names the teams. Score:
'   +2 per team named by full / short name (e.g. "Red Sox"), +1 per team named only by city ("Boston")
'   +1 when the listing mentions the sport ("MLB", "Baseball"), +1 when the channel is one ESPN lists (ESPN, FOX...)
'   needs team points >= 2 and total >= 4 (two teams by name; or one team + sport + network)
' Returns false when there's no cached guide to match against.
function matchGames(games as Object, now as Integer) as Boolean
    if games.Count() = 0 then return true
    t0 = CreateObject("roTimespan")
    ' The cached guide rows ([start, stop, title, subtitle, desc, category, ...] per channel) are scanned as they are:
    ' only listings that start near a game are looked at, and nothing is built for the rest.
    txt = readCache("guide")
    if txt = "" then return false
    data = ParseJson(txt)
    txt = ""
    if Type(data) <> "roAssociativeArray" or Type(data.programs) <> "roAssociativeArray" then return false
    programs = data.programs
    tParse = t0.TotalMilliseconds()
    names = invalid   ' channel names: only loaded once a listing looks like a game

    lo = games[0].start
    hi = lo
    for i = 0 to games.Count() - 1
        gs = games[i].start
        if gs < lo then lo = gs
        if gs > hi then hi = gs
        nn = []
        for each n in games[i].nets.Split(", ")
            addNeedle(nn, n)
        end for
        games[i].netNeedles = nn
    end for
    ' a listing can only match a game that starts 45 min before .. 60 min after it
    lo = lo - 3600
    hi = hi + 2700
    ' slots[n] = the games a listing starting in that 15-minute slot could be (one array lookup per listing)
    base = Int(lo / 900)
    slots = CreateObject("roArray", Int(hi / 900) - base + 1, true)
    slots[Int(hi / 900) - base] = invalid
    for i = 0 to games.Count() - 1
        gs = games[i].start
        for b = Int((gs - 3600) / 900) to Int((gs + 2700) / 900)
            if slots[b - base] = invalid then slots[b - base] = []
            slots[b - base].Push(i)
        end for
    end for
    nNear = 0
    nTeam = 0
    tFrom = now - 3 * 3600
    tTo = now + 48 * 3600
    hasGuide = false
    skip = [" pregame ", " postgame ", " pre game ", " post game ", " highlights ", " classic ", " classics ", " replay ", " rewind ", " preview ", " recap ", " encore "]

    for each num in programs
        rows = programs[num]
        chName = ""
        chNorm = invalid
        if Type(rows) <> "roArray" then rows = []
        for each r in rows
            st = Int(r[0])
            if not hasGuide then
                if Int(r[1]) > tFrom and st < tTo then hasGuide = true
            end if
            cands = invalid
            if st >= lo and st <= hi then cands = slots[Int(st / 900) - base]
            if cands <> invalid then
                sp = Int(r[1])
                if sp > tFrom and st < tTo then
                    nNear = nNear + 1
                    txt = normText(jsStr(r[2]) + " " + jsStr(r[3]))
                    if not hasAny(txt, skip) then
                        catTxt = invalid
                        for each gi in cands
                            g = games[gi]
                            if g.start >= st - 2700 and g.start <= st + 3600 then
                                ts = 0
                                for each tm in g.teams
                                    if hasAny(txt, tm.strong) then
                                        ts = ts + 2
                                    else if hasAny(txt, tm.weak) then
                                        ts = ts + 1
                                    end if
                                end for
                                if ts >= 2 then
                                    nTeam = nTeam + 1
                                    total = ts
                                    if catTxt = invalid then catTxt = txt + normText(jsStr(r[5]))
                                    for each k in g.kw
                                        if Instr(1, catTxt, " " + k + " ") > 0 then
                                            total = total + 1
                                            exit for
                                        end if
                                    end for
                                    if chNorm = invalid then
                                        if names = invalid then names = cachedChannelNames()
                                        if names[num] <> invalid then chName = jsStr(names[num])
                                        chNorm = normText(chName)
                                    end if
                                    netHit = hasAny(chNorm, g.netNeedles)
                                    if netHit then total = total + 1
                                    if total >= 4 then addChan(g, num, chName, { start: st, stop: sp }, netHit)
                                end if
                            end if
                        end for
                    end if
                end if
            end if
        end for
    end for
    print "[TunerBox] live sports: guide read " + tParse.ToStr() + " ms, matching " + (t0.TotalMilliseconds() - tParse).ToStr() + " ms"
    print "[TunerBox] live sports: " + nNear.ToStr() + " listings start near a game, " + nTeam.ToStr() + " name a team"
    if not hasGuide then
        for each g in games
            g.Delete("netNeedles")
        end for
        return false
    end if

    for each g in games
        g.Delete("netNeedles")
        if g.chans.Count() > 1 then
            ' network channels first, then by channel number
            for each c in g.chans
                c.sk = c.numVal
                if c.net then c.sk = c.sk - 1000000
            end for
            g.chans.SortBy("sk")
        end if
        for each c in g.chans
            c.Delete("sk")
            c.Delete("numVal")
            c.Delete("net")
        end for
    end for
    return true
end function

sub addChan(g as Object, num as String, name as String, p as Object, net as Boolean)
    for each c in g.chans
        if c.number = num then return   ' one listing per channel (the first block of a long game)
    end for
    if name = "" then name = "Channel " + num
    g.chans.Push({ number: num, name: name, label: name, start: p.start, stop: p.stop, numVal: Val(num), net: net })
end sub

'' ============================================================ generic JSON call (On Demand: /api/vod/...)
' GET apiPath, or POST apiBody to it when apiBody is set. result = { ok, data, tag, ctx }
sub callApi()
    result = { ok: false, data: invalid, tag: m.top.apiTag, ctx: m.top.apiCtx }
    url = m.top.baseUrl + m.top.apiPath
    if m.top.apiBody <> "" then
        txt = postText(url, m.top.apiBody, 15000)
    else
        txt = fetchText(url, 30000)
    end if
    if txt <> "" then
        d = ParseJson(txt)
        if d <> invalid then
            result.data = d
            result.ok = true
        end if
    end if
    m.top.result = result
end sub

' ============================================================ favorites (TunerBox /api/favorites)
sub loadFavs()
    result = { ok: false, favs: [] }
    txt = fetchText(m.top.baseUrl + "/api/favorites", 8000)
    if txt <> "" then
        arr = ParseJson(txt)
        if arr <> invalid and Type(arr) = "roArray" then
            result.favs = arr
            result.ok = true
        end if
    end if
    print "[TunerBox] favorites: ok=" + result.ok.ToStr() + " count=" + result.favs.Count().ToStr()
    m.top.result = result
end sub

sub setFav()
    result = { ok: false, favs: [] }
    body = FormatJson({ number: Int(Val(m.top.favNumber)), on: m.top.favOn })
    txt = postText(m.top.baseUrl + "/api/favorites", body, 8000)
    if txt <> "" then
        arr = ParseJson(txt)
        if arr <> invalid and Type(arr) = "roArray" then
            result.favs = arr
            result.ok = true
        end if
    end if
    print "[TunerBox] set favorite " + m.top.favNumber + "=" + m.top.favOn.ToStr() + " ok=" + result.ok.ToStr()
    m.top.result = result
end sub

function postText(url as String, body as String, timeoutMs as Integer) as String
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    xfer.AddHeader("Content-Type", "application/json")
    if xfer.AsyncPostFromString(body) then
        msg = Wait(timeoutMs, port)
        if Type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            if code >= 200 and code < 300 then return msg.GetString()
        else
            xfer.AsyncCancel()
        end if
    end if
    return ""
end function

' ============================================================ boot (channels)
sub loadBoot()
    t0 = CreateObject("roTimespan")
    base = m.top.baseUrl
    result = { ok: false, channels: [], error: "", fromCache: false, guide: invalid }

    ' ---- 1) cache
    if m.top.useCache then
        txt = readCache("channels")
        if txt <> "" then
            data = ParseJson(txt)
            if data <> invalid and data.channels <> invalid and data.channels.Count() > 0 then
                result.channels = rowsToChannels(data.channels)
                result.fromCache = true
                result.guide = readGuideCache()
                result.ok = true
                print "[TunerBox] cache: " + result.channels.Count().ToStr() + " channels in " + t0.TotalMilliseconds().ToStr() + " ms"
                m.top.result = result
                return
            end if
        end if
    end if

    ' ---- 2) sidecar
    m.top.status = "Loading channel list..."
    if sidecarUp() then
        txt = fetchText(sidecarBase() + "/channels.json?unmapped=" + unmappedFlag(), 60000)
        if txt <> "" then
            data = ParseJson(txt)
            if data <> invalid and data.channels <> invalid and data.channels.Count() > 0 then
                writeCache("channels", txt)
                result.channels = rowsToChannels(data.channels)
                result.guide = readGuideCache()
                result.ok = true
                print "[TunerBox] sidecar channels: " + result.channels.Count().ToStr() + " in " + t0.TotalMilliseconds().ToStr() + " ms"
                m.top.result = result
                return
            end if
        end if
    end if

    ' ---- 3) M3U
    m3u = fetchText(base + "/playlist.m3u", 30000)
    print "[TunerBox] playlist: " + Len(m3u).ToStr() + " chars in " + t0.TotalMilliseconds().ToStr() + " ms"
    if m3u = "" then
        result.error = "Could not load " + base + "/playlist.m3u"
        m.top.result = result
        return
    end if
    channels = parseM3U(m3u)
    if channels.Count() = 0 then
        result.error = "The playlist loaded but contains no channels."
        m.top.result = result
        return
    end if
    channels.SortBy("numVal")
    channels = filterMapped(channels)
    writeCache("channels", FormatJson({ channels: channelsToRows(channels) }))
    result.channels = channels
    result.guide = readGuideCache()
    result.ok = true
    print "[TunerBox] parsed " + channels.Count().ToStr() + " channels, " + t0.TotalMilliseconds().ToStr() + " ms total"
    m.top.result = result
end sub

' ============================================================ guide
sub loadGuide()
    t0 = CreateObject("roTimespan")
    base = m.top.baseUrl
    hours = m.top.guideHours
    now = nowEpoch()
    tFrom = now - 3 * 3600
    tTo = now + hours * 3600
    result = { ok: false, guide: {}, count: 0, source: "" }
    guide = invalid
    usedSidecar = false

    m.top.status = "Checking for guide service..."
    if sidecarUp() then
        usedSidecar = true
        txt = fetchText(sidecarBase() + "/guide.json?hours=" + hours.ToStr(), 60000)
        if txt <> "" then
            data = ParseJson(txt)
            if data <> invalid and data.programs <> invalid then
                writeCache("guide", txt)
                guide = guideFromJson(data.programs, tFrom, tTo)
                result.source = "sidecar"
            end if
        end if
        print "[TunerBox] sidecar guide ok=" + (guide <> invalid).ToStr() + " " + t0.TotalMilliseconds().ToStr() + " ms"
    end if

    if guide = invalid then
        guide = guideFromEpgXml(base, tFrom, tTo, t0)
        result.source = "epg.xml"
        if guide <> invalid and guide.Count() > 0 then
            writeCache("guide", FormatJson({ programs: progsToRows(guide) }))
        end if
    end if

    if guide <> invalid and guide.Count() > 0 then
        result.guide = guide
        result.count = guide.Count()
        result.ok = true
    end if
    print "[TunerBox] guide ready (" + result.source + "): " + result.count.ToStr() + " channels, " + t0.TotalMilliseconds().ToStr() + " ms"
    m.top.result = result

    ' ---- afterwards (result already delivered): refresh the channel cache for next launch
    if m.top.refreshCache then
        if usedSidecar then
            txt = fetchText(sidecarBase() + "/channels.json?unmapped=" + unmappedFlag(), 60000)
            if txt <> "" and ParseJson(txt) <> invalid then writeCache("channels", txt)
        else
            m3u = fetchText(base + "/playlist.m3u", 30000)
            if m3u <> "" then
                chs = parseM3U(m3u)
                if chs.Count() > 0 then
                    chs.SortBy("numVal")
                    chs = filterMapped(chs)
                    writeCache("channels", FormatJson({ channels: channelsToRows(chs) }))
                end if
            end if
        end if
        print "[TunerBox] channel cache refreshed, " + t0.TotalMilliseconds().ToStr() + " ms"
    end if
end sub

' fallback: download + parse epg.xml here.  returns { numStr: [prog] }
function guideFromEpgXml(base as String, tFrom as Integer, tTo as Integer, t0 as Object) as Object
    keys = m.top.chanKeys
    m.top.status = "Downloading guide (epg.xml)..."
    xml = fetchText(base + "/epg.xml", 180000)
    print "[TunerBox] epg.xml: " + Len(xml).ToStr() + " chars in " + t0.TotalMilliseconds().ToStr() + " ms"
    if xml = "" then return invalid
    m.top.status = "Processing guide in the background..."
    pieces = xml.Split("</programme>")
    xml = ""
    nameMap = xmlNameMap(pieces[0])
    for each k in keys
        if k.id = "" then
            cid = nameMap[k.name]
            if cid = invalid then cid = nameMap[k.tvgName]
            if cid <> invalid then k.id = LCase(cid)
        end if
    end for
    wanted = {}
    for each k in keys
        if k.id <> "" then wanted[k.id] = true
    end for
    byId = xmlProgs(pieces, wanted, tFrom, tTo)
    pieces = invalid
    out = {}
    for each k in keys
        if k.id <> "" then
            list = byId[k.id]
            if list <> invalid and list.Count() > 0 then out[k.n] = list
        end if
    end for
    return out
end function

function jsonProgs(rows as Object, tFrom as Integer, tTo as Integer) as Object
    list = []
    for each r in rows
        st = Int(r[0])
        sp = Int(r[1])
        if sp > tFrom and st < tTo then
            list.Push({ start: st, stop: sp, title: r[2], subtitle: r[3], desc: r[4], cat: r[5], ep: r[6], rating: r[7] })
        end if
    end for
    return list
end function

' ------------------------------------------------------------ XMLTV fallback
function xmlNameMap(head as String) as Object
    map = {}
    firstProg = Instr(1, head, "<programme")
    if firstProg > 0 then head = Left(head, firstProg - 1)
    for each blk in head.Split("</channel>")
        cid = attrVal(blk, "id")
        if cid <> "" then
            for each part in blk.Split("<display-name")
                gt = Instr(1, part, ">")
                e = Instr(1, part, "</display-name>")
                if gt > 0 and e > gt then
                    dn = LCase(unesc(Mid(part, gt + 1, e - gt - 1)))
                    if dn <> "" and map[dn] = invalid then map[dn] = cid
                end if
            end for
        end if
    end for
    return map
end function

function xmlProgs(pieces as Object, wanted as Object, tFrom as Integer, tTo as Integer) as Object
    byId = {}
    for each piece in pieces
        p = Instr(1, piece, "<programme")
        if p > 0 then
            hdrEnd = Instr(p, piece, ">")
            if hdrEnd > p then
                hdr = Mid(piece, p, hdrEnd - p)
                id = LCase(attrVal(hdr, "channel"))
                if wanted[id] <> invalid then
                    st = xmltvEpoch(attrVal(hdr, "start"))
                    sp = xmltvEpoch(attrVal(hdr, "stop"))
                    if sp = 0 then sp = st + 1800
                    if sp > tFrom and st < tTo and st > 0 then
                        blk = Mid(piece, hdrEnd + 1)
                        if byId[id] = invalid then byId[id] = []
                        byId[id].Push(makeProg(blk, st, sp))
                    end if
                end if
            end if
        end if
    end for
    for each id in byId.Keys()
        byId[id].SortBy("start")
    end for
    return byId
end function

function makeProg(blk as String, st as Integer, sp as Integer) as Object
    rating = ""
    rs = Instr(1, blk, "<rating")
    if rs > 0 then rating = tagText(Mid(blk, rs), "value")
    return {
        title: tagText(blk, "title"),
        subtitle: tagText(blk, "sub-title"),
        desc: Left(tagText(blk, "desc"), 420),
        cat: tagText(blk, "category"),
        ep: onscreenEp(blk),
        rating: rating,
        start: st,
        stop: sp
    }
end function

function tagText(blk as String, tag as String) as String
    s = Instr(1, blk, "<" + tag)
    if s = 0 then return ""
    gt = Instr(s, blk, ">")
    if gt = 0 then return ""
    if Mid(blk, gt - 1, 1) = "/" then return ""
    e = Instr(gt, blk, "</" + tag + ">")
    if e = 0 then return ""
    return unesc(Mid(blk, gt + 1, e - gt - 1)).Trim()
end function

function onscreenEp(blk as String) as String
    marker = "system=" + Chr(34) + "onscreen" + Chr(34)
    s = Instr(1, blk, marker)
    if s = 0 then return ""
    gt = Instr(s, blk, ">")
    e = Instr(s, blk, "</episode-num>")
    if gt = 0 or e = 0 or e < gt then return ""
    return Mid(blk, gt + 1, e - gt - 1).Trim()
end function

function unesc(s as String) as String
    if Instr(1, s, "&") = 0 then return s
    s = s.Replace("&lt;", "<")
    s = s.Replace("&gt;", ">")
    s = s.Replace("&quot;", Chr(34))
    s = s.Replace("&apos;", "'")
    s = s.Replace("&#39;", "'")
    s = s.Replace("&amp;", "&")
    return s
end function

' "20261105100000 -0500" -> epoch seconds (UTC)
function xmltvEpoch(s as String) as Integer
    if Len(s) < 14 then return 0
    y = Int(Val(Mid(s, 1, 4)))
    mo = Int(Val(Mid(s, 5, 2)))
    d = Int(Val(Mid(s, 7, 2)))
    hh = Int(Val(Mid(s, 9, 2)))
    mi = Int(Val(Mid(s, 11, 2)))
    ss = Int(Val(Mid(s, 13, 2)))
    t = daysFromCivil(y, mo, d) * 86400 + hh * 3600 + mi * 60 + ss
    off = Mid(s, 15).Trim()
    if Len(off) >= 5 then
        sign = Left(off, 1)
        secs = Int(Val(Mid(off, 2, 2))) * 3600 + Int(Val(Mid(off, 4, 2))) * 60
        if sign = "+" then
            t = t - secs
        else if sign = "-" then
            t = t + secs
        end if
    end if
    return t
end function

function daysFromCivil(y as Integer, mon as Integer, d as Integer) as Integer
    if mon <= 2 then y = y - 1
    era = Int(y / 400)
    yoe = y - era * 400
    mp = mon - 3
    if mon <= 2 then mp = mon + 9
    doy = Int((153 * mp + 2) / 5) + d - 1
    doe = yoe * 365 + Int(yoe / 4) - Int(yoe / 100) + doy
    return era * 146097 + doe - 719468
end function

' ============================================================ network / M3U
function hostOnly(base as String) as String
    s = base
    p = Instr(1, s, "://")
    if p > 0 then s = Mid(s, p + 3)
    c = Instr(1, s, ":")
    sl = Instr(1, s, "/")
    if c > 0 then return Left(s, c - 1)
    if sl > 0 then return Left(s, sl - 1)
    return s
end function

function fetchText(url as String, timeoutMs as Integer) as String
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if LCase(Left(url, 6)) = "https:" then
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        xfer.InitClientCertificates()
    end if
    if xfer.AsyncGetToString() then
        msg = Wait(timeoutMs, port)
        if Type(msg) = "roUrlEvent" then
            if msg.GetResponseCode() = 200 then return msg.GetString()
        else
            xfer.AsyncCancel()
        end if
    end if
    return ""
end function

function parseM3U(text as String) as Object
    channels = []
    lines = text.Split(Chr(10))
    cur = invalid
    seq = 0
    for each raw in lines
        line = raw.Trim()
        if line <> "" then
            if Left(line, 8) = "#EXTINF:" then
                cur = {}
                cur.name = extName(line)
                cur.tvgId = attrVal(line, "tvg-id")
                cur.tvgName = attrVal(line, "tvg-name")
                cur.logo = attrVal(line, "tvg-logo")
                cur.group = attrVal(line, "group-title")
                cur.numStr = attrVal(line, "tvg-chno")
                if cur.numStr = "" then cur.numStr = attrVal(line, "channel-number")
            else if Left(line, 1) <> "#" and cur <> invalid then
                seq = seq + 1
                cur.url = line
                if cur.name = "" then cur.name = cur.tvgName
                if cur.numStr = "" then cur.numStr = (20000 + seq).ToStr()
                cur.numVal = Val(cur.numStr) + 0.0
                cur.programs = invalid
                channels.Push(cur)
                cur = invalid
            end if
        end if
    end for
    return channels
end function

function extName(line as String) as String
    parts = line.Split(Chr(34))
    tail = parts[parts.Count() - 1]
    c = Instr(1, tail, ",")
    if c = 0 then return ""
    return Mid(tail, c + 1).Trim()
end function
