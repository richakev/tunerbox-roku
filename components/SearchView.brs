' Search panel (mirrors the TunerBox web search): on-screen keyboard on the left,
' live results (matching channels, then matching upcoming programs) on the right.
' The scene does the matching (it owns the channel list) and handles watch / record.

sub init()
    m.KX = 60
    m.KY = 222
    m.KW = 76
    m.KH = 66
    m.KGAP = 10
    m.ROW_X = 690
    m.ROW_Y = 222
    m.ROW_H = 70
    m.ROW_W = 1170
    m.NROWS = 11

    m.countLbl = m.top.findNode("countLbl")
    m.queryLbl = m.top.findNode("queryLbl")
    m.boxBorder = m.top.findNode("boxBorder")
    m.keysGroup = m.top.findNode("keysGroup")
    m.rowsGroup = m.top.findNode("rowsGroup")
    m.msgLbl = m.top.findNode("msgLbl")
    m.footLbl = m.top.findNode("footLbl")
    m.debounce = m.top.findNode("debounce")
    m.debounce.observeField("fire", "onDebounce")
    m.top.findNode("titleLbl").font.size = 52
    m.countLbl.font.size = 27
    m.queryLbl.font.size = 40
    m.msgLbl.font.size = 32
    m.footLbl.font.size = 27

    ' keyboard: { t: text shown, v: value, row, col, span }
    m.keys = []
    chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ123456789"
    for i = 0 to Len(chars) - 1
        c = Mid(chars, i + 1, 1)
        m.keys.Push({ t: c, v: LCase(c), row: i \ 7, col: i mod 7, span: 1 })
    end for
    m.keys.Push({ t: "0", v: "0", row: 5, col: 0, span: 1 })
    m.keys.Push({ t: "Space", v: "space", row: 5, col: 1, span: 2 })
    m.keys.Push({ t: "Del", v: "del", row: 5, col: 3, span: 1 })
    m.keys.Push({ t: "Clear", v: "clear", row: 5, col: 4, span: 2 })

    m.q = ""
    m.items = []
    m.focus = "keys"
    m.krow = 0
    m.kcol = 0
    m.sel = 0
    m.top0 = 0
end sub

' ------------------------------------------------------------ open / close
sub openSearch()
    m.q = ""
    m.items = []
    m.focus = "keys"
    m.krow = 0
    m.kcol = 0
    m.sel = 0
    m.top0 = 0
    m.top.visible = true
    m.top.setFocus(true)
    render()
end sub

sub closeSearch()
    m.debounce.control = "stop"
    m.top.visible = false
    m.top.setFocus(false)
end sub

sub onResults()
    r = m.top.results
    if r = invalid or r.items = invalid then return
    ' ignore stale results for an older query
    if r.query <> m.q then return
    m.items = r.items
    m.sel = 0
    m.top0 = 0
    if m.items.Count() = 0 and m.focus = "results" then m.focus = "keys"
    render()
end sub

' ------------------------------------------------------------ query editing
sub setQuery(q as String)
    m.q = q
    if q.Trim() = "" then
        m.debounce.control = "stop"
        m.items = []
        m.sel = 0
        m.top0 = 0
        m.top.query = ""
    else
        m.debounce.control = "stop"
        m.debounce.control = "start"
    end if
    render()
end sub

sub onDebounce()
    m.top.query = m.q
end sub

sub typeKey(v as String)
    if v = "space" then
        if m.q <> "" and Right(m.q, 1) <> " " then setQuery(m.q + " ")
    else if v = "del" then
        if Len(m.q) > 0 then setQuery(Left(m.q, Len(m.q) - 1))
    else if v = "clear" then
        if m.q <> "" then setQuery("")
    else
        if Len(m.q) < 40 then setQuery(m.q + v)
    end if
end sub

' ------------------------------------------------------------ keyboard navigation
function keyAt(row as Integer, col as Integer) as Integer
    last = -1
    for i = 0 to m.keys.Count() - 1
        k = m.keys[i]
        if k.row = row then
            last = i
            if col >= k.col and col < k.col + k.span then return i
        end if
    end for
    return last
end function

sub keyMove(dr as Integer, dc as Integer)
    ki = keyAt(m.krow, m.kcol)
    k = m.keys[ki]
    if dc > 0 then
        nc = k.col + k.span
        if keyAt(m.krow, nc) = ki or nc > 6 then
            ' off the right edge: into the results
            if m.items.Count() > 0 then
                m.focus = "results"
                render()
            end if
            return
        end if
        m.kcol = m.keys[keyAt(m.krow, nc)].col
    else if dc < 0 then
        if k.col = 0 then return
        m.kcol = m.keys[keyAt(m.krow, k.col - 1)].col
    else
        nr = m.krow + dr
        if nr < 0 or nr > 5 then return
        m.krow = nr
        m.kcol = m.keys[keyAt(nr, m.kcol)].col
    end if
    render()
end sub

sub moveSel(delta as Integer)
    if m.items.Count() = 0 then return
    n = m.sel + delta
    if n < 0 then n = 0
    if n > m.items.Count() - 1 then n = m.items.Count() - 1
    if n = m.sel then return
    m.sel = n
    render()
end sub

' ------------------------------------------------------------ drawing
sub render()
    m.queryLbl.text = m.q + "_"
    if m.focus = "keys" then
        m.boxBorder.color = "0xFFC845FF"
    else
        m.boxBorder.color = "0x4F86E8FF"
    end if
    drawKeys()
    drawRows()
    if m.focus = "results" then
        m.footLbl.text = "OK  Watch / Record / Open      Left  Keyboard      Back  Close"
    else
        m.footLbl.text = "OK  Type      Right  Results      Replay  Delete      Back  Close"
    end if
end sub

sub drawKeys()
    m.keysGroup.removeChildrenIndex(m.keysGroup.getChildCount(), 0)
    cur = keyAt(m.krow, m.kcol)
    for i = 0 to m.keys.Count() - 1
        k = m.keys[i]
        x = m.KX + k.col * (m.KW + m.KGAP)
        y = m.KY + k.row * (m.KH + m.KGAP)
        w = k.span * m.KW + (k.span - 1) * m.KGAP
        if i = cur and m.focus = "keys" then
            bg = "0xFFC845FF"
            tc = "0x10244AFF"
        else
            bg = "0x2052B8FF"
            tc = "0xFFFFFFFF"
        end if
        m.keysGroup.appendChild(mkRect(x, y, w, m.KH, bg))
        l = mkLabel(x, y, w, m.KH, k.t, 30, true, tc)
        l.horizAlign = "center"
        m.keysGroup.appendChild(l)
    end for
end sub

function whenText(t as Integer) as String
    if t <= nowEpoch() then return "Now"
    if fmtDay(t) = fmtDay(nowEpoch()) then return fmtClock(t)
    return Left(localDT(t).GetWeekday(), 3) + " " + fmtClock(t)
end function

sub drawRows()
    m.rowsGroup.removeChildrenIndex(m.rowsGroup.getChildCount(), 0)
    n = m.items.Count()
    if m.q.Trim() = "" then
        m.countLbl.text = ""
        m.msgLbl.text = "Type a channel name, show title or movie"
        return
    end if
    if n = 0 then
        m.countLbl.text = ""
        if m.top.query = m.q then
            m.msgLbl.text = "No matches for " + Chr(34) + m.q.Trim() + Chr(34)
        else
            m.msgLbl.text = "Searching..."
        end if
        return
    end if
    m.msgLbl.text = ""
    if n = 1 then
        m.countLbl.text = "1 result"
    else
        m.countLbl.text = n.ToStr() + " results"
    end if

    if m.sel > n - 1 then m.sel = n - 1
    if m.sel < 0 then m.sel = 0
    if m.sel < m.top0 then m.top0 = m.sel
    if m.sel >= m.top0 + m.NROWS then m.top0 = m.sel - m.NROWS + 1

    for r = 0 to m.NROWS - 1
        i = m.top0 + r
        if i >= n then exit for
        drawRow(m.items[i], r, (i = m.sel and m.focus = "results"))
    end for
end sub

function sv(v as Dynamic) as String
    if v = invalid then return ""
    t = Type(v)
    if t = "String" or t = "roString" then return v
    return ""
end function

function feedBadge(f as Object) as Object
    if f.status = "ok" then return { t: "LIVE", c: "0xE0243CFF" }
    if f.ended = true then return { t: "ENDED", c: "0x4A5568FF" }
    if f.slot = true then return { t: "EMPTY", c: "0x4A5568FF" }
    if f.status = "dead" then return { t: "OFF AIR", c: "0x4A5568FF" }
    if f.kind = "ppv" then return { t: "PPV", c: "0x7A3FB5FF" }
    return { t: "EVENT", c: "0x3B5B96FF" }
end function

sub drawRow(it as Object, r as Integer, selected as Boolean)
    y = m.ROW_Y + r * m.ROW_H
    h = m.ROW_H - 6
    x0 = m.ROW_X
    if selected then
        m.rowsGroup.appendChild(mkRect(x0, y, m.ROW_W, h, "0xFFC845FF"))
        tc = "0x111111FF"
        nc = "0x111111FF"
        rc = "0x222222FF"
        sc = "0x34415FFF"
        bb = "0x2052B8FF"
    else
        tc = "0xFFFFFFFF"
        nc = "0xFFC845FF"
        rc = "0xAFC8F5FF"
        sc = "0xA9BEE8FF"
        bb = "0x2F5FC0FF"
    end if
    tx = x0 + 24
    rw = 400
    rightX = x0 + m.ROW_W - rw - 24
    right = sv(it.right)

    if it.k = "ch" then
        badge = "CH"
        bg = bb
    else if it.k = "feed" then
        b = feedBadge(it.f)
        badge = b.t
        bg = b.c
    else if it.k = "vod" then
        badge = it.badge
        bg = "0x7A3FB5FF"
        if badge <> "MOVIE" then bg = "0x006B6BFF"
    else
        badge = whenText(it.start)
        bg = "0x3B4F78FF"
        if badge = "Now" then
            badge = "ON NOW"
            bg = "0x1B6B2FFF"
        end if
        right = it.num + " " + sv(it.name)
    end if
    bw = Len(badge) * 13 + 28
    if bw < 60 then bw = 60
    m.rowsGroup.appendChild(mkRect(tx, y + 16, bw, h - 32, bg))
    bl = mkLabel(tx, y + 16, bw, h - 32, badge, 22, false, "0xFFFFFFFF")
    bl.horizAlign = "center"
    m.rowsGroup.appendChild(bl)
    tx = tx + bw + 20

    if it.k = "ch" then
        m.rowsGroup.appendChild(mkLabel(tx, y, 130, h, it.num, 32, true, nc))
        tx = tx + 140
        title = sv(it.name)
    else
        title = sv(it.title)
    end if
    maxW = rightX - 20 - tx
    if right = "" then maxW = x0 + m.ROW_W - 24 - tx
    tl = mkLabel(tx, y, 0, h, title, 32, false, tc)
    m.rowsGroup.appendChild(tl)
    tw = tl.boundingRect().width
    if tw <= 0 then tw = Len(title) * 16
    if tw > maxW then
        tl.width = maxW
        tw = maxW
    end if
    subt = sv(it.sub)
    if subt <> "" then
        sx = tx + tw + 12
        sw = tx + maxW - sx
        if sw > 60 then m.rowsGroup.appendChild(mkLabel(sx, y, sw, h, Chr(183) + " " + subt, 26, false, sc))
    end if
    if right <> "" then
        rl = mkLabel(rightX, y, rw, h, right, 26, false, rc)
        rl.horizAlign = "right"
        m.rowsGroup.appendChild(rl)
    end if
end sub

' ------------------------------------------------------------ keys
sub activate()
    if m.sel < 0 or m.sel >= m.items.Count() then return
    it = m.items[m.sel]
    if it.k = "ch" then
        m.top.request = { type: "channel", num: it.num, name: sv(it.name) }
    else if it.k = "feed" then
        m.top.request = { type: "feed", f: it.f }
    else if it.k = "vod" then
        m.top.request = { type: "vod", v: it.v }
    else
        m.top.request = { type: "program", num: it.num, name: sv(it.name), prog: { title: sv(it.title), start: it.start, stop: it.stop } }
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false

    if Left(key, 4) = "Lit_" then
        c = LCase(Mid(key, 5))
        if c = " " then
            typeKey("space")
        else if Len(c) = 1 then
            typeKey(c)
        end if
        return true
    end if

    if key = "back" then
        if m.focus = "results" then
            m.focus = "keys"
            render()
        else
            m.top.request = { type: "close" }
        end if
    else if key = "backspace" or key = "replay" then
        typeKey("del")
    else if key = "options" then
        m.top.request = { type: "close" }
    else if m.focus = "keys" then
        if key = "left" then
            keyMove(0, -1)
        else if key = "right" then
            keyMove(0, 1)
        else if key = "up" then
            keyMove(-1, 0)
        else if key = "down" then
            keyMove(1, 0)
        else if key = "OK" then
            typeKey(m.keys[keyAt(m.krow, m.kcol)].v)
        else if key = "play" then
            if m.items.Count() > 0 then
                m.focus = "results"
                render()
            end if
        else
            return false
        end if
    else
        if key = "left" then
            m.focus = "keys"
            render()
        else if key = "up" then
            moveSel(-1)
        else if key = "down" then
            moveSel(1)
        else if key = "rewind" then
            moveSel(0 - m.NROWS)
        else if key = "fastforward" then
            moveSel(m.NROWS)
        else if key = "OK" or key = "play" then
            activate()
        else
            return false
        end if
    end if
    return true
end function
