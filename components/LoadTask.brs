' Background loader (runs off the UI thread).
'   mode "boot":  channel list.  cache -> TunerBox /channels.json (older TunerBox: M3U parse)
'   mode "guide": programme guide. TunerBox /guide.json (1.9.0 and older: /api/guide, then epg.xml parse)
' Caches live in cachefs:/ so the second launch is nearly instant.

sub init()
    m.top.functionName = "loadData"
end sub

sub loadData()
    mode = m.top.mode
    if mode = "guide" then
        loadGuide()
    else if mode = "savedguide" then
        t0 = CreateObject("roTimespan")
        g = readGuideCache()
        print "[TunerBox] saved guide read in " + t0.TotalMilliseconds().ToStr() + " ms"
        m.top.result = { ok: true, guideOnly: true, guide: g }
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

' ============================================================ cache helpers
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

' GET /channels.json: { channels: [[number, name, logo, group, url, tvg-id, tvg-name]] }, saved as the channel
' cache (the same shape). invalid when TunerBox doesn't have it (older versions: the M3U instead).
function fetchChannelsJson() as Dynamic
    txt = fetchText(m.top.baseUrl + "/channels.json?unmapped=" + unmappedFlag(), 60000)
    if txt = "" then return invalid
    data = ParseJson(txt)
    if Type(data) <> "roAssociativeArray" or Type(data.channels) <> "roArray" or data.channels.Count() = 0 then return invalid
    writeCache("channels", txt)
    return data
end function

function rowsToChannels(rows as Object) as Object
    out = []
    for each r in rows
        ' r[7]: how many backup feeds the channel has (older TunerBox and older caches: none listed)
        alts = 0
        if r.Count() > 7 then alts = Int(numv(r[7]))
        out.Push({ numStr: r[0], name: r[1], logo: r[2], group: r[3], url: r[4], tvgId: r[5], tvgName: r[6], alts: alts, numVal: Val(r[0]) + 0.0, programs: invalid })
    end for
    return out
end function

function channelsToRows(channels as Object) as Object
    out = []
    for each c in channels
        alts = 0
        if c.alts <> invalid then alts = c.alts
        out.Push([c.numStr, c.name, c.logo, c.group, c.url, c.tvgId, c.tvgName, alts])
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
    txt = ""     ' memory: the text goes once parsed, the parsed file once turned into the guide
    if data = invalid or data.programs = invalid then return invalid
    progs = data.programs
    data = invalid
    t = nowEpoch()
    g = guideFromJson(progs, t - 3 * 3600, t + 48 * 3600)
    progs = invalid
    if g.Count() = 0 then return invalid
    return g
end function

' ============================================================ Sports & Events, DVR (TunerBox /api/sports, /api/recordings)
function getObj(path as String, timeoutMs as Integer) as Object
    txt = fetchText(m.top.baseUrl + path, timeoutMs)
    if txt = "" then return invalid
    return ParseJson(txt)
end function

sub loadSports()
    result = { ok: false, data: invalid }
    d = getObj("/api/sports", 30000)
    if d <> invalid and d.on_now <> invalid and d.upcoming <> invalid and d.channels <> invalid and d.groups <> invalid then
        ' TunerBox Settings > Sports > "List games you have no channel for" (absent = on)
        st = getObj("/api/settings", 8000)
        if Type(st) = "roAssociativeArray" then
            v = st.sports_show_unmatched
            if (Type(v) = "Boolean" or Type(v) = "roBoolean") and v = false then d.show_unmatched = false
        end if
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
        g.Delete("ms")
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
                    print "[TunerBox] HTTP " + msg.GetResponseCode().ToStr() + " " + urls[e.i]
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
    ' anyStr keeps every digit (Str() writes big numbers such as start times as "1.794834e+09")
    return anyStr(v)
end function

' lower-case, punctuation -> spaces, padded so " word " tests whole words
function normText(s as String) as String
    if m.normRe = invalid then m.normRe = CreateObject("roRegex", "[^a-z0-9]+", "")
    return " " + m.normRe.ReplaceAll(foldAccents(LCase(s)), " ").Trim() + " "
end function

' "procházka" -> "prochazka", so a guide that writes a name either way still matches. Only text with
' something past ASCII is looked at (nearly all of it has nothing to fold), a character at a time: roRegex
' may compare bytes, not characters.
function foldAccents(s as String) as String
    if m.wideRe = invalid then
        m.wideRe = CreateObject("roRegex", "[^\x00-\x7F]", "")
        m.folds = {}
        m.folds.SetModeCaseSensitive()
        ' lower case and capitals: LCase may leave an accented capital as it is ("PROCHÁZKA")
        for each f in [["àáâãäåāăąÀÁÂÃÄÅĀĂĄ", "a"], ["çćčÇĆČ", "c"], ["ďđĎĐ", "d"], ["èéêëēėęěÈÉÊËĒĖĘĚ", "e"], ["ğĞ", "g"],
                       ["ìíîïīįıÌÍÎÏĪĮİ", "i"], ["łŁ", "l"], ["ñńňÑŃŇ", "n"], ["òóôõöøōőÒÓÔÕÖØŌŐ", "o"], ["řŘ", "r"],
                       ["śšşŚŠŞ", "s"], ["ťţŤŢ", "t"], ["ùúûüūůűÙÚÛÜŪŮŰ", "u"], ["ýÿÝŸ", "y"], ["źżžŹŻŽ", "z"]]
            for i = 1 to Len(f[0])
                m.folds[Mid(f[0], i, 1)] = f[1]
            end for
        end for
    end if
    if not m.wideRe.IsMatch(s) then return s
    out = ""
    for i = 1 to Len(s)
        ch = Mid(s, i, 1)
        if m.folds.DoesExist(ch) then ch = m.folds[ch]
        out = out + ch
    end for
    return out
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
    if lg.card <> invalid and lg.card then return espnCard(ev, lg, now)
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
        ms: start
        chans: []
    }
end function

' A fight card (UFC, PFL) as a game: the card's name ("UFC Fight Night: Procházka vs. Stirling"), and the
' main event's two fighters (the card's last fight) as its teams. It starts with the prelims; guides list
' the main card, hours later, so that's what it is matched by (ms).
function espnCard(ev as Object, lg as Object, now as Integer) as Object
    st = ev.status
    if st = invalid or st.type = invalid then return invalid
    state = jsStr(st.type.state)
    if state <> "pre" and state <> "in" then return invalid
    start = isoEpoch(ev.date)
    if start = 0 then return invalid
    fights = []
    for each c in ev.competitions
        if Type(c) = "roAssociativeArray" and c.competitors <> invalid and c.competitors.Count() = 2 then fights.Push(c)
    end for
    if fights.Count() = 0 then return invalid
    last = fights[fights.Count() - 1]
    main = start
    for each c in fights
        t = isoEpoch(c.date)
        if t > main then main = t
    end for
    if state = "pre" and main < now - 6 * 3600 then return invalid   ' stale / never updated
    tv = last.timeValid
    if state = "pre" and (Type(tv) = "Boolean" or Type(tv) = "roBoolean") then
        if not tv then return invalid                                ' "TBD": the date is a placeholder
    end if

    teams = []
    for each c in last.competitors
        a = c.athlete
        if a = invalid then return invalid
        full = jsStr(a.displayName)
        if full = "" then return invalid
        parts = full.Split(" ")
        lastName = parts[parts.Count() - 1]
        strong = []
        addNeedle(strong, full)
        addNeedle(strong, lastName)
        ord = 0
        if c.order <> invalid then ord = c.order
        teams.Push({ short: lastName, abbr: lastName, score: "", strong: strong, weak: [], ord: ord })
    end for
    if teams.Count() < 2 then return invalid
    if teams[0].ord > teams[1].ord then teams = [teams[1], teams[0]]

    detail = ""
    if state = "in" and main > start then
        ' which part of the card is on: the first fight that isn't over
        detail = "Main card"
        for each c in fights
            cs = c.status
            if cs = invalid or cs.type = invalid or jsStr(cs.type.state) <> "post" then
                if isoEpoch(c.date) < main then detail = "Prelims"
                exit for
            end if
        end for
    end if
    nets = []
    if last.broadcasts <> invalid then
        for each b in last.broadcasts
            if b.names <> invalid then
                for each nm in b.names
                    addNet(nets, jsStr(nm))
                end for
            end if
        end for
    end if
    title = jsStr(ev.name)
    if title = "" then title = teams[0].short + " vs " + teams[1].short
    return {
        id: jsStr(ev.id)
        lg: lg.id
        league: lg.abbr
        kw: lg.kw
        title: title
        start: start
        state: state
        detail: detail
        score: ""
        nets: nets.Join(", ")
        teams: teams
        ms: main
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

    ' a game is matched by when its listings start: kickoff, or a fight card's main card (ms)
    lo = games[0].ms
    hi = lo
    for i = 0 to games.Count() - 1
        gs = games[i].ms
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
        gs = games[i].ms
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
                            if g.ms >= st - 2700 and g.ms <= st + 3600 then
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
    if m.top.apiMethod = "DELETE" then
        txt = deleteText(url, 15000)
    else if m.top.apiBody <> "" then
        res = postFull(url, m.top.apiBody, 15000)
        txt = res.text
        ' refused (4xx): FastAPI's {"detail": "why"}, for the screen to say
        if res.code >= 400 then
            e = ParseJson(res.body)
            if Type(e) = "roAssociativeArray" and e.detail <> invalid and GetInterface(e.detail, "ifString") <> invalid then result.detail = e.detail
        end if
    else
        ms = m.top.apiTimeout
        if ms <= 0 then ms = 30000
        txt = fetchText(url, ms)
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
    url = m.top.baseUrl + "/api/favorites"
    why = ""
    txt = ""
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    if xfer.AsyncGetToString() then
        msg = Wait(8000, port)
        if Type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            if code = 200 then
                txt = msg.GetString()
            else
                why = "HTTP " + code.ToStr() + " " + msg.GetFailureReason()
            end if
        else
            xfer.AsyncCancel()
            why = "no answer in 8 s"
        end if
    else
        why = "request not started"
    end if
    if txt <> "" then
        arr = ParseJson(txt)
        if arr <> invalid and Type(arr) = "roArray" then
            result.favs = arr
            result.ok = true
        else
            why = "not a JSON list: " + Left(txt, 80)
        end if
    end if
    line = "[TunerBox] favorites: ok=" + result.ok.ToStr() + " count=" + result.favs.Count().ToStr()
    if not result.ok then line = line + " (" + url + ": " + why + ")"
    print line
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

' POST a JSON body: { code, text (the reply when it's 2xx, else ""), body (the reply whatever the code) }
function postFull(url as String, body as String, timeoutMs as Integer) as Object
    out = { code: 0, text: "", body: "" }
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    xfer.RetainBodyOnError(true)
    xfer.AddHeader("Content-Type", "application/json")
    if xfer.AsyncPostFromString(body) then
        msg = Wait(timeoutMs, port)
        if Type(msg) = "roUrlEvent" then
            out.code = msg.GetResponseCode()
            out.body = msg.GetString()
            if out.code >= 200 and out.code < 300 then out.text = out.body
        else
            xfer.AsyncCancel()
        end if
    end if
    return out
end function

function deleteText(url as String, timeoutMs as Integer) as String
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    xfer.SetRequest("DELETE")
    if xfer.AsyncGetToString() then
        msg = Wait(timeoutMs, port)
        if Type(msg) = "roUrlEvent" then
            code = msg.GetResponseCode()
            if code >= 200 and code < 300 then
                txt = msg.GetString()
                if txt = "" then txt = "{}"
                return txt
            end if
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
                result.ok = true
                print "[TunerBox] cache: " + result.channels.Count().ToStr() + " channels in " + t0.TotalMilliseconds().ToStr() + " ms"
                sendBoot(result)
                return
            end if
        end if
    end if

    ' ---- 2) TunerBox's channel list for the Roku (GET /channels.json, gzipped, already filtered and sorted)
    m.top.status = "Loading channel list..."
    data = fetchChannelsJson()
    if data <> invalid then
        result.channels = rowsToChannels(data.channels)
        data = invalid
        result.ok = true
        print "[TunerBox] channels.json: " + result.channels.Count().ToStr() + " channels in " + t0.TotalMilliseconds().ToStr() + " ms"
        sendBoot(result)
        return
    end if

    ' ---- 3) an older TunerBox: the M3U
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
    result.ok = true
    print "[TunerBox] parsed " + channels.Count().ToStr() + " channels, " + t0.TotalMilliseconds().ToStr() + " ms total"
    sendBoot(result)
end sub

' Just the channels, so the scene can open Home (or the banner) at once. The saved guide (24 hours of
' listings: seconds of work on a slower Roku) is read by a "savedguide" task the scene starts once the
' video is playing, so the two don't compete while the stream starts.
sub sendBoot(result as Object)
    m.top.result = result
end sub

' ============================================================ guide
' Two passes, so the guide opens quickly but still reaches well ahead: the first asks for guideHours (3)
' and hands it over; the second asks for guideMore (24) and hands that over too, replacing the first.
' result.full is true on the answer that has everything (the scene only then counts the cache as fresh).
sub loadGuide()
    t0 = CreateObject("roTimespan")
    base = m.top.baseUrl
    hours = m.top.guideHours
    more = m.top.guideMore
    now = nowEpoch()
    tFrom = now - 3 * 3600
    result = { ok: false, guide: {}, count: 0, source: "", full: false }

    ' TunerBox's guide for the Roku (GET /guide.json, gzipped): only the hours shown and the channels with
    ' listings, read with the built-in JSON parser. An older TunerBox doesn't have it: epg.xml below.
    ' TunerBox 1.9.0 and older have no /guide.json: their web guide's /api/guide (JSON, only the hours asked
    ' for) instead, a few channels per request. epg.xml (three days of every channel, parsed here) is the last
    ' resort: on a big lineup it can take minutes or run the Roku out of memory.
    ' Both passes' downloads start together: the second (bigger) one comes in while the first is parsed and
    ' handed over, instead of only starting after it.
    ' The saved copy for next launch is written once a pass is handed over, so it doesn't hold the guide up;
    ' with a second pass coming, the first is only kept (m.guideTxt) to be saved if that one doesn't come.
    m.top.status = "Downloading guide..."
    twoPass = (more > hours)
    m.guideTxt = ""
    f2 = invalid
    if twoPass then f2 = startFetch(guideJsonUrl(base, more))
    guide = guideJson(base, hours, tFrom, t0, invalid, twoPass)
    if guide <> invalid then
        result.source = "guide.json"
    else
        ' no /guide.json here: the second pass's download is no use either
        if f2 <> invalid then f2.x.AsyncCancel()
        f2 = invalid
        guide = guideFromApi(base, tFrom, now + hours * 3600, t0)
        if guide <> invalid then
            result.source = "api/guide"
        else
            guide = guideFromEpgXml(base, tFrom, now + hours * 3600, t0)
            result.source = "epg.xml"
        end if
    end if

    if guide <> invalid and guide.Count() > 0 then
        result.guide = guide
        result.count = guide.Count()
        result.ok = true
    end if
    ' epg.xml (an older TunerBox) is downloaded whole each time: no second pass for that
    result.full = (not result.ok or result.source = "epg.xml" or more <= hours)
    src = result.source
    print "[TunerBox] guide ready (" + result.source + ", " + hours.ToStr() + " h): " + result.count.ToStr() + " channels, " + t0.TotalMilliseconds().ToStr() + " ms"
    full = result.full
    ' no second pass after all (e.g. no listings): stop its download
    if full and f2 <> invalid then f2.x.AsyncCancel()
    if full then f2 = invalid
    m.top.result = result
    ' api/guide and epg.xml: the text to save, made from the guide (guide.json keeps the text it downloaded).
    ' Only when there's no second pass: making it would hold that one up
    if full and src <> "guide.json" and guide <> invalid and guide.Count() > 0 then m.guideTxt = FormatJson({ programs: progsToRows(guide) })
    ' the first pass is with the scene now: let this thread's copy go before the second download
    guide = invalid
    result = invalid
    if full then
        if m.guideTxt <> "" then writeCache("guide", m.guideTxt)
        m.guideTxt = ""
    end if

    ' ---- the second pass: the hours after those, while the guide is already usable
    if not full then
        t1 = CreateObject("roTimespan")
        if src = "api/guide" then
            g2 = guideFromApi(base, tFrom, nowEpoch() + more * 3600, t1)
        else
            ' already downloading since the first pass started (or done by now); saved as it's read (the
            ' guide on screen meanwhile is the first pass, so this doesn't hold anything up)
            g2 = guideJson(base, more, tFrom, t1, f2, false)
            f2 = invalid
        end if
        if g2 <> invalid and g2.Count() > 0 then
            n2 = g2.Count()
            print "[TunerBox] guide extended (" + src + ", " + more.ToStr() + " h): " + n2.ToStr() + " channels, " + t1.TotalMilliseconds().ToStr() + " ms"
            res2 = { ok: true, guide: g2, count: n2, source: src, full: true }
            m.top.result = res2
            res2 = invalid
            if src = "api/guide" then writeCache("guide", FormatJson({ programs: progsToRows(g2) }))
            ' the whole guide is saved: the first pass's copy isn't needed
            m.guideTxt = ""
        end if
        g2 = invalid
        ' the second pass didn't come: save the first, so next launch has something to show
        if m.guideTxt <> "" then writeCache("guide", m.guideTxt)
        m.guideTxt = ""
    end if

    ' ---- afterwards (result already delivered): refresh the channel cache for next launch
    if m.top.refreshCache then
        if fetchChannelsJson() = invalid then
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

' /guide.json without descriptions (desc=0: the guide fetches the one it shows); an older TunerBox ignores
' desc=0 and sends them all, which still works
function guideJsonUrl(base as String, hours as Integer) as String
    return base + "/guide.json?hours=" + hours.ToStr() + "&desc=0"
end function

' GET /guide.json for the next `hours` (from 3 hours ago); invalid when it isn't there. Saved for next launch:
' now, or with `keep` held in m.guideTxt for the caller to save once it's handed over.
' `pre`: that download already started with startFetch (invalid: start it now)
function guideJson(base as String, hours as Integer, tFrom as Integer, t0 as Object, pre as Dynamic, keep as Boolean) as Dynamic
    guide = invalid
    if pre = invalid then pre = startFetch(guideJsonUrl(base, hours))
    txt = finishFetch(pre, 60000)
    pre = invalid
    tDl = t0.TotalMilliseconds()
    chars = Len(txt)
    if txt <> "" then
        ' memory: each copy of the listings is several MB, so each is let go as soon as the next is made
        ' (the text once parsed, the parsed reply once turned into the guide)
        data = ParseJson(txt)
        if data <> invalid and Type(data.programs) = "roAssociativeArray" then
            if keep then m.guideTxt = txt else writeCache("guide", txt)
            txt = ""
            progs = data.programs
            data = invalid
            guide = guideFromJson(progs, tFrom, nowEpoch() + hours * 3600)
            progs = invalid
        end if
        data = invalid
        txt = ""
    end if
    print "[TunerBox] guide.json (" + hours.ToStr() + " h): " + chars.ToStr() + " chars, downloaded in " + tDl.ToStr() + " ms, ready in " + t0.TotalMilliseconds().ToStr() + " ms"
    return guide
end function

' fallback for TunerBox 1.9.0 and older (no /guide.json): GET /api/guide?start=&stop=&numbers=, the endpoint
' their web guide uses, for a batch of channels at a time (a few in parallel) so no reply is too big to parse.
' Its rows are objects ({ start, stop, title, subtitle, descr, category, episode, rating, ... }), keyed by
' channel number. Returns { numStr: [prog] }; invalid when the server has no /api/guide either.
function guideFromApi(base as String, tFrom as Integer, tTo as Integer, t0 as Object) as Dynamic
    nums = []
    whole = CreateObject("roRegex", "^\d+$", "")
    for each k in m.top.chanKeys
        ' /api/guide only takes whole channel numbers
        if whole.IsMatch(k.n) then nums.Push(k.n)
    end for
    if nums.Count() = 0 then return invalid
    batch = 60
    parallel = 4
    urls = []
    for i = 0 to nums.Count() - 1 step batch
        last = i + batch - 1
        if last > nums.Count() - 1 then last = nums.Count() - 1
        part = []
        for j = i to last
            part.Push(nums[j])
        end for
        urls.Push(base + "/api/guide?start=" + tFrom.ToStr() + "&stop=" + tTo.ToStr() + "&numbers=" + part.Join(","))
    end for
    out = {}
    answered = 0
    for i = 0 to urls.Count() - 1 step parallel
        group = []
        for j = i to i + parallel - 1
            if j < urls.Count() then group.Push(urls[j])
        end for
        m.top.status = "Downloading guide (" + (i + group.Count()).ToStr() + "/" + urls.Count().ToStr() + ")..."
        bodies = fetchMany(group, 30000)
        for each txt in bodies
            if txt <> "" then
                data = ParseJson(txt)
                txt = ""
                if data <> invalid and Type(data) = "roAssociativeArray" then
                    answered = answered + 1
                    for each key in data.Keys()
                        list = apiProgs(data[key], tFrom, tTo)
                        if list.Count() > 0 then out[key] = list
                    end for
                end if
                data = invalid
            end if
        end for
        bodies = invalid
        ' the first batch got nothing usable: this TunerBox has no /api/guide, don't try the rest
        if answered = 0 then return invalid
    end for
    print "[TunerBox] api/guide: " + out.Count().ToStr() + " channels from " + urls.Count().ToStr() + " requests in " + t0.TotalMilliseconds().ToStr() + " ms"
    return out
end function

function apiProgs(rows as Dynamic, tFrom as Integer, tTo as Integer) as Object
    list = []
    if Type(rows) <> "roArray" then return list
    for each r in rows
        if Type(r) = "roAssociativeArray" and r.start <> invalid and r.stop <> invalid then
            st = Int(r.start)
            sp = Int(r.stop)
            if sp > tFrom and st < tTo then
                list.Push({ start: st, stop: sp, title: anyStr(r.title), subtitle: anyStr(r.subtitle), desc: anyStr(r.descr), cat: anyStr(r.category), ep: anyStr(r.episode), rating: anyStr(r.rating) })
            end if
        end if
    end for
    return list
end function

' last resort: download + parse epg.xml here.  returns { numStr: [prog] }
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
    return finishFetch(startFetch(url), timeoutMs)
end function

' start a GET in the background (the download runs while this thread does other work); finishFetch waits
' for it. Returns { x, port }, or invalid when it couldn't start.
function startFetch(url as String) as Dynamic
    xfer = CreateObject("roUrlTransfer")
    port = CreateObject("roMessagePort")
    xfer.SetPort(port)
    xfer.SetUrl(url)
    xfer.EnableEncodings(true)
    if LCase(Left(url, 6)) = "https:" then
        xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    end if
    if not xfer.AsyncGetToString() then return invalid
    return { x: xfer, port: port }
end function

' the body of a startFetch download ("" on failure, or when it isn't done within timeoutMs from now)
function finishFetch(f as Dynamic, timeoutMs as Integer) as String
    if f = invalid then return ""
    msg = Wait(timeoutMs, f.port)
    if Type(msg) = "roUrlEvent" then
        if msg.GetResponseCode() = 200 then return msg.GetString()
    else
        f.x.AsyncCancel()
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
