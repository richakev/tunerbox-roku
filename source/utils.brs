' Shared helpers (included by every component that needs them)

' ------------------------------------------------------------ registry
function regRead(key as String, fallback = "" as String) as String
    sec = CreateObject("roRegistrySection", "tunerbox")
    if sec.Exists(key) then return sec.Read(key)
    return fallback
end function

sub regWrite(key as String, value as String)
    sec = CreateObject("roRegistrySection", "tunerbox")
    sec.Write(key, value)
    sec.Flush()
end sub

' "192.168.1.50" -> "http://192.168.1.50:8642"
function normalizeBase(raw as String) as String
    s = raw.Trim()
    while Right(s, 1) = "/"
        s = Left(s, Len(s) - 1)
    end while
    if s = "" then return ""
    if LCase(Left(s, 4)) <> "http" then s = "http://" + s
    if Instr(1, Mid(s, 8), ":") = 0 then s = s + ":8642"
    return s
end function

' ------------------------------------------------------------ time
function nowEpoch() as Integer
    dt = CreateObject("roDateTime")
    return dt.AsSeconds()
end function

function floor30(t as Integer) as Integer
    return t - (t mod 1800)
end function

function localDT(t as Integer) as Object
    dt = CreateObject("roDateTime")
    dt.FromSeconds(t)
    dt.ToLocalTime()
    return dt
end function

function fmtClock(t as Integer) as String
    dt = localDT(t)
    h = dt.GetHours()
    mi = dt.GetMinutes()
    ap = "AM"
    if h >= 12 then ap = "PM"
    h = h mod 12
    if h = 0 then h = 12
    ms = mi.ToStr()
    if mi < 10 then ms = "0" + ms
    return h.ToStr() + ":" + ms + " " + ap
end function

function fmtDay(t as Integer) as String
    dt = localDT(t)
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return Left(dt.GetWeekday(), 3) + ", " + months[dt.GetMonth() - 1] + " " + dt.GetDayOfMonth().ToStr()
end function

function dotSep() as String
    return " " + Chr(183) + " "
end function

function dashSep() as String
    return " " + Chr(8211) + " "
end function

' ------------------------------------------------------------ guide data
function progAt(ch as Object, t as Integer) as Object
    if ch.programs = invalid then return invalid
    for each p in ch.programs
        if p.start <= t and p.stop > t then return p
    end for
    return invalid
end function

function progAfter(ch as Object, t as Integer) as Object
    if ch.programs = invalid then return invalid
    for each p in ch.programs
        if p.start >= t then return p
    end for
    return invalid
end function

function subLine(p as Object) as String
    s = ""
    if p.ep <> "" then s = p.ep
    if p.subtitle <> "" then
        if s <> "" then s = s + dotSep()
        s = s + p.subtitle
    end if
    return s
end function

' category -> cell colour (blue / teal / purple / brown / green scheme)
function catColor(cat as String) as String
    c = LCase(cat)
    if Instr(1, c, "movie") > 0 or Instr(1, c, "film") > 0 then return "0x40307AFF"
    if Instr(1, c, "sport") > 0 then return "0x1B6B2FFF"
    if Instr(1, c, "news") > 0 or Instr(1, c, "weather") > 0 then return "0x7A4510FF"
    if Instr(1, c, "child") > 0 or Instr(1, c, "kid") > 0 or Instr(1, c, "famil") > 0 or Instr(1, c, "anim") > 0 then return "0x006B6BFF"
    return "0x13499CFF"
end function

' ------------------------------------------------------------ string helpers
' value of key="..." inside s
function attrVal(s as String, key as String) as String
    needle = key + "=" + Chr(34)
    p = Instr(1, s, needle)
    if p = 0 then return ""
    st = p + Len(needle)
    e = Instr(st, s, Chr(34))
    if e = 0 then return ""
    return Mid(s, st, e - st)
end function

' ------------------------------------------------------------ JSON values (any type) and durations
' ============================================================ value helpers (JSON can hold any type)
function anyStr(v as Dynamic) as String
    if v = invalid then return ""
    if GetInterface(v, "ifString") <> invalid then return v
    if GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then
        if v = Int(v) then return Int(v).ToStr()
        return Str(v).Trim()
    end if
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid then return Str(v).Trim()
    return ""
end function

' any JSON number (Integer / roInt / LongInteger / Float / Double, boxed or not) or numeric string -> Float
function numv(v as Dynamic) as Float
    if v = invalid then return 0
    if GetInterface(v, "ifString") <> invalid then return Val(v)
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid or GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then return v
    return 0
end function

' 105 min -> "1h 45m"
function fmtLen(secs as Float) as String
    mins = Int(secs / 60 + 0.5)
    if mins <= 0 then return ""
    if mins < 60 then return mins.ToStr() + " min"
    return (mins \ 60).ToStr() + "h " + (mins mod 60).ToStr() + "m"
end function

' 3725 -> "1:02:05"
function fmtDur(secs as Float) as String
    s = Int(secs)
    if s < 0 then s = 0
    h = s \ 3600
    mi = (s mod 3600) \ 60
    se = s mod 60
    ss = se.ToStr()
    if se < 10 then ss = "0" + ss
    if h > 0 then
        ms = mi.ToStr()
        if mi < 10 then ms = "0" + ms
        return h.ToStr() + ":" + ms + ":" + ss
    end if
    return mi.ToStr() + ":" + ss
end function

' ------------------------------------------------------------ fancy Unicode letters -> plain
' Playlists decorate names with superscripts / modifier letters / small caps (superscript "4K 3840P", "Dolby Vision") that the
' Roku font doesn't have (they draw as white boxes). Turn them into ordinary letters and digits.
function plainText(s as String) as String
    if m.plainMap = invalid then
        codes = [178, 179, 185, 610, 618, 628, 640, 655, 665, 668, 671, 688, 690, 691, 695, 696, 737, 738, 739, 7424, 7428, 7429, 7431, 7434, 7435, 7437, 7439, 7448, 7451, 7452, 7456, 7457, 7458, 7468, 7470, 7472, 7473, 7475, 7476, 7477, 7478, 7479, 7480, 7481, 7482, 7484, 7486, 7487, 7488, 7489, 7490, 7491, 7495, 7496, 7497, 7501, 7503, 7504, 7506, 7510, 7511, 7512, 7515, 7580, 7584, 7611, 8304, 8305, 8308, 8309, 8310, 8311, 8312, 8313, 8314, 8315, 8317, 8318, 8319, 8320, 8321, 8322, 8323, 8324, 8325, 8326, 8327, 8328, 8329, 11389, 42800, 42801]
        repl = "231GINRYBHLhjrwylsxACDEJKMOPTUVWZABDEGHIJKLMNOPRTUWabdegkmoptuvcfz0i456789+-()n0123456789VFS"
        mp = {}
        for i = 0 to codes.Count() - 1
            mp[codes[i].ToStr()] = Mid(repl, i + 1, 1)
        end for
        m.plainMap = mp
        m.plainRe = CreateObject("roRegex", "[^\x00-\x7F]", "")
    end if
    if not m.plainRe.IsMatch(s) then return s
    out = ""
    for i = 1 to Len(s)
        c = Mid(s, i, 1)
        r = m.plainMap[Asc(c).ToStr()]
        if r <> invalid then out = out + r else out = out + c
    end for
    return out
end function

' ------------------------------------------------------------ UI builders
function mkRect(x, y, w, h, color as String) as Object
    r = CreateObject("roSGNode", "Rectangle")
    r.translation = [x, y]
    r.width = w
    r.height = h
    r.color = color
    return r
end function

function mkLabel(x, y, w, h, text as String, size, bold as Boolean, color as String) as Object
    l = CreateObject("roSGNode", "Label")
    l.translation = [x, y]
    if w > 0 then l.width = w
    if h > 0 then l.height = h
    l.vertAlign = "center"
    if bold then
        l.font = "font:MediumBoldSystemFont"
    else
        l.font = "font:MediumSystemFont"
    end if
    l.font.size = size
    l.color = color
    l.text = text
    return l
end function

' percent-encode for query strings (roUrlTransfer can't be created on the render thread)
function urlEncode(s as String) as String
    out = ""
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(s)
    hex = "0123456789ABCDEF"
    for i = 0 to ba.Count() - 1
        c = ba[i]
        if (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c = 45 or c = 46 or c = 95 or c = 126 then
            out = out + Chr(c)
        else
            out = out + "%" + Mid(hex, (c \ 16) + 1, 1) + Mid(hex, (c mod 16) + 1, 1)
        end if
    end for
    return out
end function

' ------------------------------------------------------------ live sports leagues (ESPN public scoreboard API)
' path = site.api.espn.com/apis/site/v2/sports/<path>/scoreboard; groups = whole division for college (not just the top 25)
' kw = words a TV guide listing for this sport usually contains
function sportsLeagues() as Object
    return [
        { id: "mlb", label: "MLB Baseball", abbr: "MLB", path: "baseball/mlb", groups: "", college: false, kw: ["mlb", "baseball"] },
        { id: "nfl", label: "NFL Football", abbr: "NFL", path: "football/nfl", groups: "", college: false, kw: ["nfl", "football"] },
        { id: "ncaaf", label: "College Football", abbr: "NCAAF", path: "football/college-football", groups: "80", college: true, kw: ["college football", "football", "ncaa"] },
        { id: "nba", label: "NBA Basketball", abbr: "NBA", path: "basketball/nba", groups: "", college: false, kw: ["nba", "basketball"] },
        { id: "wnba", label: "WNBA Basketball", abbr: "WNBA", path: "basketball/wnba", groups: "", college: false, kw: ["wnba", "basketball"] },
        { id: "ncaab", label: "Men's College Hoops", abbr: "NCAAM", path: "basketball/mens-college-basketball", groups: "50", college: true, kw: ["college basketball", "basketball", "ncaa"] },
        { id: "ncaaw", label: "Women's College Hoops", abbr: "NCAAW", path: "basketball/womens-college-basketball", groups: "50", college: true, kw: ["college basketball", "basketball", "ncaa"] },
        { id: "nhl", label: "NHL Hockey", abbr: "NHL", path: "hockey/nhl", groups: "", college: false, kw: ["nhl", "hockey"] },
        { id: "mls", label: "MLS Soccer", abbr: "MLS", path: "soccer/usa.1", groups: "", college: false, kw: ["mls", "soccer"] },
        { id: "epl", label: "Premier League", abbr: "EPL", path: "soccer/eng.1", groups: "", college: false, kw: ["premier league", "soccer", "football"] }
    ]
end function

' comma-separated league ids picked in MENU > Live sports leagues
function sportsLeagueSel() as String
    return regRead("sportsLeagues", "mlb,nfl,nba")
end function

function leagueOn(sel as String, id as String) as Boolean
    return Instr(1, "," + sel + ",", "," + id + ",") > 0
end function
