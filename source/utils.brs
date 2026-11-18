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
    if Instr(1, c, "movie") > 0 or Instr(1, c, "film") > 0 then return thm("0x40307AFF")
    if Instr(1, c, "sport") > 0 then return thm("0x1B6B2FFF")
    if Instr(1, c, "news") > 0 or Instr(1, c, "weather") > 0 then return thm("0x7A4510FF")
    if Instr(1, c, "child") > 0 or Instr(1, c, "kid") > 0 or Instr(1, c, "famil") > 0 or Instr(1, c, "anim") > 0 then return thm("0x006B6BFF")
    return thm("0x13499CFF")
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
    ' ToStr keeps every digit; Str() would write a big number such as a start time as "1.794834e+09"
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid then return v.ToStr()
    if GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then
        d# = v
        whole& = d#
        if whole& = d# then return whole&.ToStr()
        return Str(v).Trim()
    end if
    return ""
end function

' any JSON number (Integer / roInt / LongInteger / Float / Double, boxed or not) or numeric string -> Float
function numv(v as Dynamic) as Float
    if v = invalid then return 0
    if GetInterface(v, "ifString") <> invalid then return Val(v)
    if GetInterface(v, "ifInt") <> invalid or GetInterface(v, "ifLongInt") <> invalid or GetInterface(v, "ifFloat") <> invalid or GetInterface(v, "ifDouble") <> invalid then return v
    return 0
end function

' a time (seconds since 1970) from JSON, exactly: numv's Float would round it by up to a minute
function epochOf(v as Dynamic) as Integer
    if v = invalid then return 0
    if GetInterface(v, "ifString") <> invalid then return Int(Val(v, 10))
    if GetInterface(v, "ifInt") <> invalid then return v
    if GetInterface(v, "ifLongInt") <> invalid or GetInterface(v, "ifDouble") <> invalid or GetInterface(v, "ifFloat") <> invalid then return Int(v)
    return 0
end function

' JSON true / non-zero number (TunerBox sends some flags as 0/1) -> true; anything else -> false
function truthy(v as Dynamic) as Boolean
    if v = invalid then return false
    if GetInterface(v, "ifBoolean") <> invalid then return v
    return numv(v) <> 0
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

' ------------------------------------------------------------ text the Roku font can draw
' Playlists and guides decorate names with characters the Roku's font doesn't have, which draw as white boxes:
' superscript / small-cap letters (a superscript "RAW" after "ESPN"), "bold", "script" or "double-struck" maths
' letters, full-width, circled and boxed letters, emoji and pictographs. The decorative letters and digits become
' ordinary ones and emoji are left out (with the space next to them); every other character, in any language, is
' kept as it is. Every screen's text goes through this (mkLabel, dialogs, toasts and the views' labels).
function plainText(s as Dynamic) as String
    if s = invalid then return ""
    if GetInterface(s, "ifString") = invalid then return anyStr(s)
    if m.plainMap = invalid then
        ' superscript, subscript, modifier and small-cap letters and digits, then the double-struck / script /
        ' fraktur letters Unicode keeps in Letterlike Symbols (the rest of those alphabets are maths letters)
        codes = [178, 179, 185, 610, 618, 628, 640, 655, 665, 668, 671, 688, 690, 691, 695, 696, 737, 738, 739, 7424, 7428, 7429, 7431, 7434, 7435, 7437, 7439, 7448, 7451, 7452, 7456, 7457, 7458, 7468, 7470, 7472, 7473, 7475, 7476, 7477, 7478, 7479, 7480, 7481, 7482, 7484, 7486, 7487, 7488, 7489, 7490, 7491, 7495, 7496, 7497, 7501, 7503, 7504, 7506, 7510, 7511, 7512, 7515, 7580, 7584, 7611, 8304, 8305, 8308, 8309, 8310, 8311, 8312, 8313, 8314, 8315, 8317, 8318, 8319, 8320, 8321, 8322, 8323, 8324, 8325, 8326, 8327, 8328, 8329, 11389, 42800, 42801, 8450, 8458, 8459, 8460, 8461, 8462, 8464, 8465, 8466, 8467, 8469, 8473, 8474, 8475, 8476, 8477, 8484, 8488, 8492, 8493, 8495, 8496, 8497, 8499, 8500]
        repl = "231GINRYBHLhjrwylsxACDEJKMOPTUVWZABDEGHIJKLMNOPRTUWabdegkmoptuvcfz0i456789+-()n0123456789VFS" + "CgHHHhIILlNPQRRRZZBCeEFMo"
        mp = {}
        for i = 0 to codes.Count() - 1
            mp[codes[i].ToStr()] = Mid(repl, i + 1, 1)
        end for
        m.plainMap = mp
        m.plainRe = CreateObject("roRegex", "[^\x00-\x7F]", "")
    end if
    if not m.plainRe.IsMatch(s) then return s
    out = ""
    gap = false         ' just left something out: a space now would double the one before it
    for i = 1 to Len(s)
        c = Mid(s, i, 1)
        n = Asc(c)
        r = c
        if n >= 128 then
            r = m.plainMap[n.ToStr()]
            if r = invalid then r = glyphFor(n, c)
        end if
        if r = "" then
            gap = true
        else if gap and r = " " and (out = "" or Right(out, 1) = " ") then
            ' the space after a dropped emoji
        else if gap and (r = ")" or r = "]") and (Right(out, 1) = "(" or Right(out, 1) = "[") then
            ' brackets that held only an emoji: "USA (emoji)" -> "USA"
            out = Left(out, Len(out) - 1)
            if Right(out, 1) = " " then out = Left(out, Len(out) - 1)
            gap = false
        else
            out = out + r
            gap = false
        end if
    end for
    ' an emoji at the end leaves the space before it
    if gap and Right(out, 1) = " " then out = Left(out, Len(out) - 1)
    return out
end function

' one character above ASCII (code n): a plain letter or digit for the decorative copies of them, "" for emoji,
' pictographs and the other kinds the Roku font lacks, and the character itself for everything else
function glyphFor(n as Integer, c as String) as String
    ' full-width ASCII
    if n >= 65281 and n <= 65374 then return Chr(n - 65248)
    ' maths bold / italic / script / fraktur / double-struck / sans / mono letters: 52 per style (A-Z a-z)
    if n >= 119808 and n <= 120483 then
        k = (n - 119808) mod 52
        if k < 26 then return Chr(65 + k)
        return Chr(97 + k - 26)
    end if
    ' maths digits: 10 per style
    if n >= 120782 and n <= 120831 then return Chr(48 + (n - 120782) mod 10)
    ' circled letters and digits
    if n >= 9398 and n <= 9423 then return Chr(65 + n - 9398)
    if n >= 9424 and n <= 9449 then return Chr(97 + n - 9424)
    if n >= 9312 and n <= 9320 then return Chr(49 + n - 9312)
    ' squared / negative circled / negative squared letters
    if n >= 127280 and n <= 127305 then return Chr(65 + n - 127280)
    if n >= 127312 and n <= 127337 then return Chr(65 + n - 127312)
    if n >= 127344 and n <= 127369 then return Chr(65 + n - 127344)
    ' left out: emoji and pictographs (incl. flags, mahjong, cards), emoji modifiers and tags
    if n >= 126976 and n <= 129791 then return ""
    if n >= 917504 and n <= 917631 then return ""
    ' misc technical, geometric shapes, misc symbols, dingbats, misc symbols and arrows (clocks, stars, ticks...)
    if (n >= 8960 and n <= 9215) or (n >= 9632 and n <= 10175) or (n >= 11008 and n <= 11263) then return ""
    ' variation selectors, zero-width joiner / spaces, keycap, byte-order mark; surrogate halves and private use
    if (n >= 65024 and n <= 65039) or (n >= 8203 and n <= 8205) or n = 8288 or n = 8419 or n = 65279 then return ""
    if n >= 55296 and n <= 63743 then return ""
    return c
end function

' ------------------------------------------------------------ colour themes
' The same themes as TunerBox's TV screens (Light is only for Setup and phones there, so it isn't here).
' Every colour in this app is written in the Classic Blue palette; thm() swaps it for the current theme's.
' The maps come from TunerBox's web/tv.css palettes, matched by role (background, cell, accent, text...).
function themeList() as Object
    return [["midnight", "Midnight"], ["classic", "Classic Blue"], ["retro", "Retro 90s"], ["contrast", "High Contrast"]]
end function

function themeLabel(id as String) as String
    for each t in themeList()
        if t[0] = id then return t[1]
    end for
    return "Midnight"
end function

function themeValid(id as String) as Boolean
    for each t in themeList()
        if t[0] = id then return true
    end for
    return false
end function

' this Roku's own pick (Menu > Theme), else TunerBox's (Setup > Settings > Screens > Theme), else Midnight
function themeChosen() as String
    t = regRead("theme", "")
    if not themeValid(t) then t = regRead("themeServer", "midnight")
    if not themeValid(t) then t = "midnight"
    return t
end function

' the theme in use right now (set on the global node by main.brs and by MainScene when it changes)
function themeName() as String
    g = m.global
    if g <> invalid and g.hasField("theme") then return g.theme
    return "midnight"
end function

' a Classic Blue colour -> the same colour in the current theme
function thm(c as String) as String
    name = themeName()
    if m.thmMap = invalid or m.thmName <> name then
        m.thmMap = themeMap(name)
        m.thmName = name
    end if
    v = themeLookup(m.thmMap, c)
    if v = invalid then return c
    return v
end function

' a colour in a theme map; one that's only there with another transparency (e.g. 0x08163AF7 when the map has
' 0x08163AFF) uses that entry's colour, scaled to its own transparency. invalid when the colour isn't mapped.
function themeLookup(mp as Object, c as String) as Dynamic
    v = mp[c]
    if v <> invalid then return v
    if Len(c) <> 10 then return invalid
    e = mp["rgb:" + LCase(Left(c, 8))]
    if e = invalid then return invalid
    ka = Val(Right(e.k, 2), 16)
    if ka = 0 then return invalid
    a = Int(Val(Right(c, 2), 16) * Val(Right(e.v, 2), 16) / ka + 0.5)
    if a > 255 then a = 255
    hx = "0123456789ABCDEF"
    return Left(e.v, 8) + Mid(hx, (a \ 16) + 1, 1) + Mid(hx, (a mod 16) + 1, 1)
end function

' { "0xCLASSIC": "0xTHEMED" } (case doesn't matter: the keys are looked up case-insensitively)
function themeMap(name as String) as Object
    s = ""
    if name = "classic" then
        return {}
    else if name = "midnight" then
        s = ""
        s = s + "006B6BFF=0F5059FF,07102EFF=05060AFF,08163AFF=07090FFF,08183AFF=07090FFF,08224FF0=10141DF0,0B1D46EE=0B0E16EE,0B1D46FF=0B0E16FF,0B2A6AF6=121722F6,0B2A6AF8=121722F8,0D3B86F2=1A2133F2,"
        s = s + "0D6C74FF=0F5059FF,10244AFF=0D1119FF,111111FF=141006FF,12408FFF=1A2030FF,13499CFF=1E2536FF,145A3AFF=134A33FF,153A80FF=1A1F2EFF,16397AFF=161B28FF,163A7DFF=161B28FF,1A2A4DFF=10141DFF,"
        s = s + "1A4597FF=1A2030FF,1B2B50FF=10141DFF,1B4FA8FF=1E2536FF,1B6B2FFF=134A33FF,1C2B4EFF=10141DFF,1C3F86FF=1A2133FF,1C4FA855=1E253655,1E56B3FF=1E2536FF,1F4FA3FF=1E2536FF,2052B8FF=1E2536FF,"
        s = s + "2A66C8FF=3A4258FF,2B3A57FF=121722FF,2F5FB0FF=3A4258FF,2F5FC0FF=3A4258FF,2F66C8FF=3A4258FF,34415FFF=2D3B57FF,34466BFF=2D3B57FF,3A63A8FF=3A4258FF,3B4F78FF=2D3B57FF,3B5B96FF=3A4258FF,"
        s = s + "3F2A7EFF=3B2C66FF,40307AFF=3B2C66FF,4A6FC0FF=FFFFFF24,4F86E8FF=FFFFFF24,5A87D8FF=FFFFFF24,6A3A12FF=57331AFF,6FA0F0FF=FFFFFF24,7A4510FF=57331AFF,8FA3C8FF=8D97ADFF,9FB3DCFF=8D97ADFF,"
        s = s + "A9BEE8FF=AAB3C8FF,AFC8F5FF=B8C1D6FF,C5D3EFFF=C9D1E3FF,CFE0FFFF=C9D1E3FF,D5E1FBFF=C9D1E3FF,D7E3FFFF=C9D1E3FF,DCE8FFFF=EEF2FAFF,E0243CFF=FF4757FF,E0263AFF=FF4757FF,E6EEFFFF=EEF2FAFF,"
        s = s + "F2F6FFFF=EEF2FAFF,FF3B3BFF=FF4757FF,FFC845FF=FFC83DFF,FFD84AFF=FFC83DFF,FFFFFFCC=FFFFFFCC,FFFFFFFF=FFFFFFFF"
    else if name = "retro" then
        s = ""
        s = s + "006B6BFF=1A5A6EFF,07102EFF=12061FFF,08163AFF=1A0B2EFF,08183AFF=1A0B2EFF,08224FF0=23103FF0,0B1D46EE=1D0C34EE,0B1D46FF=1D0C34FF,0B2A6AF6=2F1551F6,0B2A6AF8=2F1551F8,0D3B86F2=40206DF2,"
        s = s + "0D6C74FF=1A5A6EFF,10244AFF=200E39FF,111111FF=06201DFF,12408FFF=442373FF,13499CFF=4A277CFF,145A3AFF=1E5A4AFF,153A80FF=3A1C63FF,16397AFF=371A5EFF,163A7DFF=371A5EFF,1A2A4DFF=23103FFF,"
        s = s + "1A4597FF=442373FF,1B2B50FF=23103FFF,1B4FA8FF=4A277CFF,1B6B2FFF=1E5A4AFF,1C2B4EFF=23103FFF,1C3F86FF=40206DFF,1C4FA855=4A277C55,1E56B3FF=4A277CFF,1F4FA3FF=4A277CFF,2052B8FF=4A277CFF,"
        s = s + "2A66C8FF=5B4A8FFF,2B3A57FF=2F1551FF,2F5FB0FF=5B4A8FFF,2F5FC0FF=5B4A8FFF,2F66C8FF=5B4A8FFF,34415FFF=3F3A78FF,34466BFF=3F3A78FF,3A63A8FF=5B4A8FFF,3B4F78FF=3F3A78FF,3B5B96FF=5B4A8FFF,"
        s = s + "3F2A7EFF=5A2A7EFF,40307AFF=5A2A7EFF,4A6FC0FF=FFFFFF2E,4F86E8FF=FFFFFF2E,5A87D8FF=FFFFFF2E,6A3A12FF=7A3A2AFF,6FA0F0FF=FFFFFF2E,7A4510FF=7A3A2AFF,8FA3C8FF=A993CFFF,9FB3DCFF=A993CFFF,"
        s = s + "A9BEE8FF=BFAEE0FF,AFC8F5FF=CDBDE9FF,C5D3EFFF=DCCFF2FF,CFE0FFFF=DCCFF2FF,D5E1FBFF=DCCFF2FF,D7E3FFFF=DCCFF2FF,DCE8FFFF=F6EFFFFF,E0243CFF=FF4757FF,E0263AFF=FF4757FF,E6EEFFFF=F6EFFFFF,"
        s = s + "F2F6FFFF=F6EFFFFF,FF3B3BFF=FF4757FF,FFC845FF=2EE6D6FF,FFD84AFF=2EE6D6FF,FFFFFFCC=FFFFFFCC,FFFFFFFF=FFFFFFFF"
    else if name = "contrast" then
        s = ""
        s = s + "006B6BFF=0A3A40FF,07102EFF=000000FF,08163AFF=000000FF,08183AFF=000000FF,08224FF0=080808F0,0B1D46EE=000000EE,0B1D46FF=000000FF,0B2A6AF6=0D0D0DF6,0B2A6AF8=0D0D0DF8,0D3B86F2=1A1A1AF2,"
        s = s + "0D6C74FF=0A3A40FF,10244AFF=050505FF,111111FF=000000FF,12408FFF=1F1F1FFF,13499CFF=242424FF,145A3AFF=0A3A20FF,153A80FF=171717FF,16397AFF=141414FF,163A7DFF=141414FF,1A2A4DFF=080808FF,"
        s = s + "1A4597FF=1F1F1FFF,1B2B50FF=080808FF,1B4FA8FF=242424FF,1B6B2FFF=0A3A20FF,1C2B4EFF=080808FF,1C3F86FF=1A1A1AFF,1C4FA855=24242455,1E56B3FF=242424FF,1F4FA3FF=242424FF,2052B8FF=242424FF,"
        s = s + "2A66C8FF=4D4D4DFF,2B3A57FF=0D0D0DFF,2F5FB0FF=4D4D4DFF,2F5FC0FF=4D4D4DFF,2F66C8FF=4D4D4DFF,34415FFF=333333FF,34466BFF=333333FF,3A63A8FF=4D4D4DFF,3B4F78FF=333333FF,3B5B96FF=4D4D4DFF,"
        s = s + "3F2A7EFF=2A1A4AFF,40307AFF=2A1A4AFF,4A6FC0FF=FFFFFFCC,4F86E8FF=FFFFFFCC,5A87D8FF=FFFFFFCC,6A3A12FF=4A2A0AFF,6FA0F0FF=FFFFFFCC,7A4510FF=4A2A0AFF,8FA3C8FF=E0E0E0FF,9FB3DCFF=E0E0E0FF,"
        s = s + "A9BEE8FF=E6E6E6FF,AFC8F5FF=F2F2F2FF,C5D3EFFF=FFFFFFFF,CFE0FFFF=FFFFFFFF,D5E1FBFF=FFFFFFFF,D7E3FFFF=FFFFFFFF,DCE8FFFF=FFFFFFFF,E0243CFF=FF4757FF,E0263AFF=FF4757FF,E6EEFFFF=FFFFFFFF,"
        s = s + "F2F6FFFF=FFFFFFFF,FF3B3BFF=FF4757FF,FFC845FF=FFFF00FF,FFD84AFF=FFFF00FF,FFFFFFCC=FFFFFFCC,FFFFFFFF=FFFFFFFF"
    end if
    mp = {}
    for each pair in s.Split(",")
        kv = pair.Split("=")
        if kv.Count() = 2 then
            k = "0x" + kv[0]
            mp[k] = "0x" + kv[1]
            rk = "rgb:" + LCase(Left(k, 8))
            if mp[rk] = invalid then mp[rk] = { k: k, v: "0x" + kv[1] }
        end if
    end for
    return mp
end function

' a colour field's value as "0xRRGGBBAA" (SceneGraph may hand it back as a string or as an integer)
function colorHex(v as Dynamic) as String
    if GetInterface(v, "ifString") <> invalid then return "0x" + UCase(Mid(v, 3))
    hx = "0123456789ABCDEF"
    out = "0x"
    for each sh in [24, 16, 8, 0]
        b = (v >> sh) and 255
        out = out + Mid(hx, (b \ 16) + 1, 1) + Mid(hx, (b mod 16) + 1, 1)
    end for
    return out
end function

function themeReverse(mp as Object) as Object
    out = {}
    for each k in mp
        if Left(LCase(k), 4) = "rgb:" then continue for
        v = "0x" + UCase(Mid(mp[k], 3))
        o = "0x" + UCase(Mid(k, 3))
        if out[v] = invalid then out[v] = o
        rk = "rgb:" + LCase(Left(v, 8))
        if out[rk] = invalid then out[rk] = { k: v, v: o }
    end for
    return out
end function

' recolour a node and its children: back = themed -> Classic (the theme they're in now), fwd = Classic -> new theme.
' With deep = false the walk doesn't go into the app's other screens (each recolours its own in init).
sub themeWalk(node as Object, back as Object, fwd as Object, deep as Boolean)
    if node = invalid then return
    if node.hasField("color") then
        c = colorHex(node.color)
        o = themeLookup(back, c)
        if o = invalid then o = c
        v = themeLookup(fwd, o)
        if v <> invalid then
            node.color = v
        else if o <> c then
            node.color = o
        end if
    else if node.subtype() = "Poster" then
        ' tinted pills, rounded boxes and fades (other pictures keep their white tint, which no theme maps)
        c = colorHex(node.blendColor)
        o = themeLookup(back, c)
        if o = invalid then o = c
        v = themeLookup(fwd, o)
        if v <> invalid then
            node.blendColor = v
        else if o <> c then
            node.blendColor = o
        end if
    end if
    views = { GuideView: 1, PlayerHud: 1, SportsView: 1, StatsView: 1, SearchView: 1, OnDemandView: 1, HomeView: 1, MenuView: 1 }
    for i = 0 to node.getChildCount() - 1
        ch = node.getChild(i)
        if deep or views[ch.subtype()] = invalid then themeWalk(ch, back, fwd, deep)
    end for
end sub

' first thing in each screen's init: its XML colours into the current theme
sub themeInit()
    if themeName() = "classic" then return
    themeWalk(m.top, {}, themeMap(themeName()), false)
end sub

' ------------------------------------------------------------ UI builders
function mkRect(x, y, w, h, color as String) as Object
    r = CreateObject("roSGNode", "Rectangle")
    r.translation = [x, y]
    r.width = w
    r.height = h
    r.color = color
    return r
end function

' a rounded pill (stretchable 9-patch image, tinted): h at least 40
function mkPill(x, y, w, h, color as String) as Object
    p = CreateObject("roSGNode", "Poster")
    p.uri = "pkg:/images/pill.9.png"
    p.translation = [x, y]
    p.width = w
    p.height = h
    p.blendColor = color
    return p
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
    l.text = plainText(text)
    return l
end function

' key hints as the web footers: a rounded key cap, then what it does. Shrinks to fit maxW.
sub buildKeyHints(g as Object, hints as Object, h as Integer, maxW as Integer)
    g.removeChildrenIndex(g.getChildCount(), 0)
    x = 0
    for each hnt in hints
        cap = mkLabel(0, 0, 0, h, hnt[0], 24, true, thm("0xFFFFFFFF"))
        capW = Int(cap.boundingRect().width) + 24
        if capW < 44 then capW = 44
        keyCap = CreateObject("roSGNode", "Poster")
        keyCap.uri = "pkg:/images/round.9.png"
        keyCap.translation = [x, 0]
        keyCap.width = capW
        keyCap.height = h
        keyCap.blendColor = thm("0x2B3A57FF")
        g.appendChild(keyCap)
        cap.translation = [x, 0]
        cap.width = capW
        cap.horizAlign = "center"
        g.appendChild(cap)
        x = x + capW + 10
        lbl = mkLabel(x, 0, 0, h, hnt[1], 24, false, thm("0x9FB3DCFF"))
        g.appendChild(lbl)
        x = x + Int(lbl.boundingRect().width) + 30
    end for
    sc = 1.0
    if x - 30 > maxW then sc = maxW / (x - 30)
    g.scale = [sc, sc]
end sub

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
