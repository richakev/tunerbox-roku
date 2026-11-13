' Cable-box style programme guide: preview + info panel on top, time grid below.
' Layout constants are for a 1920x1080 scene.

sub init()
    m.PAD = 20              ' gap between the safe-area edge and the content
    m.CH_W = 400
    m.WIN = 7200            ' seconds visible
    m.HDR_H = 50
    m.MIN_ROW_H = 76
    m.PV_W = 592            ' live preview (16:9)
    m.PV_H = 333
    m.HINT_H = 40

    m.titleLbl = m.top.findNode("titleLbl")
    m.badge = m.top.findNode("badge")
    m.badgeRect = m.top.findNode("badgeRect")
    m.badgeLbl = m.top.findNode("badgeLbl")
    m.subLbl = m.top.findNode("subLbl")
    m.metaLbl = m.top.findNode("metaLbl")
    m.descLbl = m.top.findNode("descLbl")
    m.clockLbl = m.top.findNode("clockLbl")
    m.dateTopLbl = m.top.findNode("dateTopLbl")
    m.filterLbl = m.top.findNode("filterLbl")
    m.jumpLbl = m.top.findNode("jumpLbl")
    m.dateLbl = m.top.findNode("dateLbl")
    m.rowsGroup = m.top.findNode("rowsGroup")
    m.hintsGroup = m.top.findNode("hintsGroup")

    m.titleLbl.font.size = 60
    m.badgeLbl.font.size = 24
    m.subLbl.font.size = 35
    m.metaLbl.font.size = 32
    m.descLbl.font.size = 31
    m.clockLbl.font.size = 52
    m.dateTopLbl.font.size = 30
    m.filterLbl.font.size = 30
    m.jumpLbl.font.size = 52
    m.dateLbl.font.size = 30

    m.previewTimer = m.top.findNode("previewTimer")
    m.clockTimer = m.top.findNode("clockTimer")
    m.jumpTimer = m.top.findNode("jumpTimer")
    m.previewTimer.observeField("fire", "onPreviewTimer")
    m.clockTimer.observeField("fire", "onClockTimer")
    m.jumpTimer.observeField("fire", "onJumpTimer")

    m.favSet = {}
    m.chs = []
    m.view = []
    m.row = 0
    m.rowTop = 0
    m.focusT = 0
    m.winStart = 0
    m.minT = 0
    m.maxT = 0
    m.dataMax = 0
    m.jumpBuf = ""
    m.fCell = invalid
    m.nowLine = invalid
    m.rowCells = []
    m.chanNodes = []

    m.bgGroup = m.top.findNode("bgGroup")
    m.hdrBar = m.top.findNode("hdrBar")
    m.safe = [0, 0, 0, 0]
    layout()
end sub

sub onSafe()
    sf = m.top.safe
    if sf = invalid or sf.Count() < 4 then return
    m.safe = sf
    layout()
    if m.top.visible and m.view.Count() > 0 then
        clampTop()
        redraw()
    end if
end sub

' Positions everything inside the safe area. Text keeps its full size; the time grid gets
' narrower/wider and the number of rows adapts to the available height.
sub layout()
    L = m.safe[0] + m.PAD
    T = m.safe[1] + m.PAD
    R = 1920 - m.safe[2] - m.PAD
    B = 1080 - m.safe[3] - m.PAD

    ' --- top panel: preview window + programme info
    px = L
    py = T
    m.top.previewRect = [px, py, m.PV_W, m.PV_H]
    pr = px + m.PV_W
    pb = py + m.PV_H
    bg = "0x0B1D46FF"
    m.bgGroup.removeChildrenIndex(m.bgGroup.getChildCount(), 0)
    m.bgGroup.appendChild(mkRect(0, 0, 1920, py, bg))
    m.bgGroup.appendChild(mkRect(0, py, px, m.PV_H, bg))
    m.bgGroup.appendChild(mkRect(pr, py, 1920 - pr, m.PV_H, bg))
    m.bgGroup.appendChild(mkRect(0, pb, 1920, 1080 - pb, bg))
    bc = "0x4F86E8FF"
    m.bgGroup.appendChild(mkRect(px - 2, py - 2, m.PV_W + 4, 2, bc))
    m.bgGroup.appendChild(mkRect(px - 2, pb, m.PV_W + 4, 2, bc))
    m.bgGroup.appendChild(mkRect(px - 2, py - 2, 2, m.PV_H + 4, bc))
    m.bgGroup.appendChild(mkRect(pr, py - 2, 2, m.PV_H + 4, bc))

    m.TITLE_X = pr + 32
    infoW = R - m.TITLE_X
    m.TITLE_MAXW = infoW - 240     ' keeps the program title clear of the clock
    m.TITLE_Y = T - 4
    m.titleLbl.translation = [m.TITLE_X, m.TITLE_Y]
    m.subLbl.translation = [m.TITLE_X, T + 66]
    m.subLbl.width = infoW - 240
    m.metaLbl.translation = [m.TITLE_X, T + 112]
    m.metaLbl.width = infoW - 240
    m.descLbl.translation = [m.TITLE_X, T + 160]
    m.descLbl.width = infoW
    m.descLbl.height = pb - (T + 160)
    m.clockLbl.translation = [R - 418, T - 6]
    m.dateTopLbl.translation = [R - 418, T + 56]
    m.filterLbl.translation = [R - 398, T + 88]
    m.jumpLbl.translation = [R - 598, pb - 57]

    ' --- grid
    m.CH_X = L
    m.TIME_X = L + m.CH_W
    m.PPM = (R - m.TIME_X) / 120.0     ' pixels per minute (2-hour window)
    m.HDR_Y = pb + 15
    m.hdrBar.translation = [L, m.HDR_Y]
    m.hdrBar.width = R - L
    m.dateLbl.translation = [L + 14, m.HDR_Y]
    m.ROWS_Y = m.HDR_Y + m.HDR_H + 4

    hintY = B - m.HINT_H
    avail = hintY - 12 - m.ROWS_Y
    m.NROWS = Int(avail / m.MIN_ROW_H)
    if m.NROWS < 3 then m.NROWS = 3
    m.ROW_H = Int(avail / m.NROWS)

    buildHints(L, hintY, R - L)
end sub

sub clampTop()
    maxTop = m.view.Count() - m.NROWS
    if maxTop < 0 then maxTop = 0
    if m.row >= m.rowTop + m.NROWS then m.rowTop = m.row - m.NROWS + 1
    if m.row < m.rowTop then m.rowTop = m.row
    if m.rowTop > maxTop then m.rowTop = maxTop
    if m.rowTop < 0 then m.rowTop = 0
end sub

' guide data arrives later from the background task: { "<channel index>": [programs] }
sub onGuideData()
    data = m.top.guideData
    for each key in data.Keys()
        idx = Int(Val(key))
        if idx >= 0 and idx < m.chs.Count() then m.chs[idx].programs = data[key]
    end for
    computeDataMax()
    if m.top.visible and m.view.Count() > 0 then
        if m.maxT < m.dataMax then m.maxT = m.dataMax
        redraw()
    end if
end sub

sub onFavs()
    m.favSet = m.top.favs
    if m.favSet = invalid then m.favSet = {}
    if m.top.visible and m.view.Count() > 0 then redraw()
end sub

sub onChannels()
    m.chs = m.top.channels
    computeDataMax()
end sub

sub computeDataMax()
    m.dataMax = 0
    for each ch in m.chs
        if ch.programs <> invalid and ch.programs.Count() > 0 then
            lastP = ch.programs[ch.programs.Count() - 1]
            if lastP.stop > m.dataMax then m.dataMax = lastP.stop
        end if
    end for
end sub

' ------------------------------------------------------------ open / close
' info = { chIdx: Integer, view: [Integer] (optional), title: String (optional) }
sub openGuide(info as Object)
    m.view = []
    if info.view <> invalid and info.view.Count() > 0 then
        m.view = info.view
    else
        for i = 0 to m.chs.Count() - 1
            m.view.Push(i)
        end for
    end if
    m.filterLbl.text = ""
    if info.title <> invalid then m.filterLbl.text = info.title

    t = nowEpoch()
    m.minT = floor30(t)
    m.maxT = m.dataMax
    if m.maxT < t + 6 * 3600 then m.maxT = t + 6 * 3600
    m.focusT = t
    m.winStart = m.minT
    m.jumpBuf = ""
    m.jumpLbl.visible = false

    m.row = 0
    for i = 0 to m.view.Count() - 1
        if m.view[i] = info.chIdx then
            m.row = i
            exit for
        end if
    end for
    maxTop = m.view.Count() - m.NROWS
    if maxTop < 0 then maxTop = 0
    m.rowTop = m.row - 2
    if m.rowTop < 0 then m.rowTop = 0
    if m.rowTop > maxTop then m.rowTop = maxTop

    updateClock()
    m.clockTimer.control = "start"
    m.top.visible = true
    m.top.setFocus(true)
    redraw()
end sub

sub closeGuide()
    m.previewTimer.control = "stop"
    m.clockTimer.control = "stop"
    m.jumpTimer.control = "stop"
    ' forget everything about where the user was scrolling
    m.fCell = invalid
    m.fRow = invalid
    m.jumpBuf = ""
    m.jumpLbl.visible = false
    m.top.focusedChannel = -1
    m.top.visible = false
    m.top.setFocus(false)
end sub

' ------------------------------------------------------------ drawing
sub redraw()
    m.rowsGroup.removeChildrenIndex(m.rowsGroup.getChildCount(), 0)
    m.fCell = invalid
    m.nowLine = invalid
    m.chanNodes = []
    m.rowCells = []

    ws = m.winStart
    we = ws + m.WIN
    m.dateLbl.text = fmtDay(ws)

    for k = 0 to 3
        cx = m.TIME_X + Int(k * 30 * m.PPM)
        m.rowsGroup.appendChild(mkRect(cx, m.HDR_Y + 8, 2, m.HDR_H - 16, "0x5A87D8FF"))
        m.rowsGroup.appendChild(mkLabel(cx + 12, m.HDR_Y, 300, m.HDR_H, fmtClock(ws + k * 1800), 31, true, "0xFFFFFFFF"))
    end for

    count = m.view.Count()
    shown = 0
    for r = 0 to m.NROWS - 1
        vi = m.rowTop + r
        if vi >= count then exit for
        shown = shown + 1
        ch = m.chs[m.view[vi]]
        y = m.ROWS_Y + r * m.ROW_H
        h = m.ROW_H - 3

        crect = mkRect(m.CH_X, y, m.CH_W, h, "0x12408FFF")
        star = CreateObject("roSGNode", "Poster")
        star.translation = [m.CH_X + 10, y + Int((h - 30) / 2)]
        star.width = 30
        star.height = 30
        if m.favSet[ch.numStr] <> invalid then
            star.uri = "pkg:/images/star_on.png"
        else
            star.uri = "pkg:/images/star_off.png"
        end if
        cnum = mkLabel(m.CH_X + 48, y, 88, h, ch.numStr, 36, true, "0xFFFFFFFF")
        logo = CreateObject("roSGNode", "Poster")
        logo.translation = [m.CH_X + 138, y + 10]
        logo.width = 84
        logo.height = h - 20
        logo.loadDisplayMode = "scaleToFit"
        logo.uri = ch.logo
        cname = mkLabel(m.CH_X + 230, y, 164, h, ch.name, 29, true, "0xFFFFFFFF")
        m.rowsGroup.appendChild(crect)
        m.rowsGroup.appendChild(star)
        m.rowsGroup.appendChild(cnum)
        m.rowsGroup.appendChild(logo)
        m.rowsGroup.appendChild(cname)
        m.chanNodes.Push({ rect: crect, num: cnum })

        cells = buildRowCells(ch, ws, we)
        for each c in cells
            l = c.start
            if l < ws then l = ws
            rr = c.stop
            if rr > we then rr = we
            x = m.TIME_X + Int((l - ws) / 60.0 * m.PPM) + 1
            w = Int((rr - l) / 60.0 * m.PPM) - 3
            if w < 4 then w = 4
            c.rect = mkRect(x, y, w, h, c.base)
            m.rowsGroup.appendChild(c.rect)
            c.lbl = invalid
            if w > 60 then
                txt = c.title
                if c.start < ws then txt = "< " + txt
                c.lbl = mkLabel(x + 12, y, w - 20, h, txt, 34, true, c.txtColor)
                m.rowsGroup.appendChild(c.lbl)
            end if
        end for
        m.rowCells.Push(cells)
    end for

    ' "now" marker
    m.nowLine = mkRect(0, m.HDR_Y + m.HDR_H, 3, shown * m.ROW_H, "0xFF3B3BFF")
    m.rowsGroup.appendChild(m.nowLine)
    updateNowLine()

    applyFocus()
end sub

function buildRowCells(ch as Object, ws as Integer, we as Integer) as Object
    cells = []
    t = ws
    if ch.programs <> invalid then
        for each p in ch.programs
            if p.stop > ws and p.start < we then
                if p.start > t then cells.Push(emptyCell(t, p.start))
                s = p.start
                if s < t then s = t
                cells.Push({ start: s, stop: p.stop, title: p.title, prog: p, base: catColor(p.cat), txtColor: "0xFFFFFFFF" })
                if p.stop > t then t = p.stop
            end if
        end for
    end if
    if t < we then cells.Push(emptyCell(t, we))
    return cells
end function

function emptyCell(s as Integer, e as Integer) as Object
    return { start: s, stop: e, title: "No Data", prog: invalid, base: "0x1A2A4DFF", txtColor: "0x8FA3C8FF" }
end function

sub updateNowLine()
    if m.nowLine = invalid then return
    t = nowEpoch()
    ws = m.winStart
    if t >= ws and t < ws + m.WIN then
        m.nowLine.translation = [m.TIME_X + Int((t - ws) / 60.0 * m.PPM), m.HDR_Y + m.HDR_H]
        m.nowLine.visible = true
    else
        m.nowLine.visible = false
    end if
end sub

sub updateClock()
    t = nowEpoch()
    m.clockLbl.text = fmtClock(t)
    m.dateTopLbl.text = fmtDay(t)
end sub

sub onClockTimer()
    updateClock()
    updateNowLine()
end sub

' ------------------------------------------------------------ focus
sub applyFocus()
    if m.fCell <> invalid then styleCell(m.fCell, false)
    if m.fRow <> invalid then styleChannel(m.fRow, false)

    r = m.row - m.rowTop
    if r < 0 or r >= m.rowCells.Count() then return
    cells = m.rowCells[r]
    pick = invalid
    for each c in cells
        if m.focusT >= c.start and m.focusT < c.stop then
            pick = c
            exit for
        end if
    end for
    if pick = invalid then pick = cells[cells.Count() - 1]

    m.fCell = pick
    m.fRow = r
    m.top.focusedChannel = m.view[m.row]
    styleCell(pick, true)
    styleChannel(r, true)
    updateInfo(pick)

end sub

sub styleCell(c as Object, focused as Boolean)
    if focused then
        c.rect.color = "0xFFC845FF"
        if c.lbl <> invalid then c.lbl.color = "0x111111FF"
    else
        c.rect.color = c.base
        if c.lbl <> invalid then c.lbl.color = c.txtColor
    end if
end sub

sub styleChannel(r as Integer, focused as Boolean)
    if r < 0 or r >= m.chanNodes.Count() then return
    n = m.chanNodes[r]
    if focused then
        n.rect.color = "0x2A66C8FF"
        n.num.color = "0xFFC845FF"
    else
        n.rect.color = "0x12408FFF"
        n.num.color = "0xFFFFFFFF"
    end if
end sub

sub updateInfo(c as Object)
    ch = m.chs[m.view[m.row]]
    chText = ch.numStr + " " + ch.name
    if c.prog <> invalid then
        p = c.prog
        setTitle(Left(p.title, 60), p.rating <> "")
        m.subLbl.text = subLine(p)
        meta = fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop) + dotSep() + chText
        if p.cat <> "" then meta = meta + dotSep() + p.cat
        m.metaLbl.text = meta
        m.descLbl.text = p.desc
        if p.rating <> "" then
            showBadge(p.rating)
        else
            m.badge.visible = false
        end if
    else
        setTitle(ch.name, false)
        m.subLbl.text = ""
        m.metaLbl.text = chText
        m.descLbl.text = "No guide data for this time slot."
        m.badge.visible = false
    end if
end sub

' natural-width title, truncated (with ellipsis) when it would run into the clock / badge
sub setTitle(txt as String, hasBadge as Boolean)
    maxW = m.TITLE_MAXW
    if hasBadge then maxW = maxW - 110
    m.titleLbl.width = 0
    m.titleLbl.text = txt
    if m.titleLbl.boundingRect().width > maxW then m.titleLbl.width = maxW
end sub

sub showBadge(txt as String)
    w = Len(txt) * 15 + 24
    m.badgeRect.width = w
    m.badgeLbl.width = w
    bb = m.titleLbl.boundingRect()
    m.badge.translation = [m.TITLE_X + bb.width + 18, m.TITLE_Y + 14]
    m.badgeLbl.text = txt
    m.badge.visible = true
end sub

sub onPreviewTimer()
    if m.view.Count() > 0 then m.top.previewRequest = m.view[m.row]
end sub

' ------------------------------------------------------------ navigation
sub moveRow(delta as Integer)
    count = m.view.Count()
    if count = 0 then return
    nr = m.row + delta
    if nr < 0 then nr = 0
    if nr > count - 1 then nr = count - 1
    setRow(nr)
end sub

sub setRow(nr as Integer)
    if nr = m.row then return
    m.row = nr
    oldTop = m.rowTop
    if m.row < m.rowTop then m.rowTop = m.row
    if m.row >= m.rowTop + m.NROWS then m.rowTop = m.row - m.NROWS + 1
    if m.rowTop <> oldTop then
        redraw()
    else
        applyFocus()
    end if
end sub

sub moveTime(dir as Integer)
    if m.fCell = invalid then return
    if dir < 0 then
        nt = m.fCell.start - 1
        if nt < m.minT then return
    else
        nt = m.fCell.stop
        if nt >= m.maxT then return
    end if
    m.focusT = nt
    if nt < m.winStart or nt >= m.winStart + m.WIN then
        m.winStart = floor30(nt)
        redraw()
    else
        applyFocus()
    end if
end sub

sub activate(forceOptions as Boolean)
    if not m.top.visible or m.fCell = invalid then return
    if m.jumpBuf <> "" then
        commitJump()
        return
    end if
    ci = m.view[m.row]
    c = m.fCell
    t = nowEpoch()
    isNow = (c.start <= t and c.stop > t)
    if forceOptions or (not isNow and c.prog <> invalid) then
        req = { chIdx: ci, current: isNow }
        if c.prog <> invalid then req.prog = c.prog
        m.top.optionsRequest = req
    else
        m.top.tuneRequest = ci
    end if
end sub

' channel-number jump (keyboard digits, or called by the scene from the menu)
sub jumpToNumber(numStr as String)
    target = Val(numStr)
    best = -1
    for i = 0 to m.view.Count() - 1
        if m.chs[m.view[i]].numVal >= target then
            best = i
            exit for
        end if
    end for
    if best = -1 then best = m.view.Count() - 1
    if best < 0 then return
    if best = m.row then
        applyFocus()
    else
        setRow(best)
    end if
end sub

sub typeDigit(d as String)
    if Len(m.jumpBuf) >= 5 then m.jumpBuf = ""
    m.jumpBuf = m.jumpBuf + d
    m.jumpLbl.text = "Ch " + m.jumpBuf
    m.jumpLbl.visible = true
    m.jumpTimer.control = "stop"
    m.jumpTimer.control = "start"
end sub

sub onJumpTimer()
    commitJump()
end sub

sub commitJump()
    m.jumpTimer.control = "stop"
    buf = m.jumpBuf
    m.jumpBuf = ""
    m.jumpLbl.visible = false
    if buf <> "" then jumpToNumber(buf)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible or m.fCell = invalid then return false
    if key = "left" then
        moveTime(-1)
    else if key = "right" then
        moveTime(1)
    else if key = "up" then
        moveRow(-1)
    else if key = "down" then
        moveRow(1)
    else if key = "rewind" or key = "pageup" then
        moveRow(0 - m.NROWS)
    else if key = "fastforward" or key = "pagedown" then
        moveRow(m.NROWS)
    else if key = "OK" then
        activate(false)
    else if key = "options" then
        m.top.menuRequest = "menu"
    else if key = "back" then
        m.top.exitRequest = true
    else if Left(key, 4) = "Lit_" then
        return litKey(Mid(key, 5))
    else
        return false
    end if
    return true
end function

function litKey(ch as String) as Boolean
    lc = LCase(ch)
    if lc >= "0" and lc <= "9" and Len(lc) = 1 then
        typeDigit(lc)
    else if lc = "g" then
        m.top.exitRequest = true
    else if lc = "r" then
        activateRecord()
    else if lc = "/" then
        m.top.menuRequest = "search"
    else if lc = "t" then
        m.top.menuRequest = "sports"
    else if lc = "o" then
        activate(true)
    else if lc = "*" or lc = "f" then
        m.top.menuRequest = "fav"
    else if lc = "v" then
        m.top.menuRequest = "favview"
    else
        return false
    end if
    return true
end function

sub activateRecord()
    if m.fCell = invalid then return
    req = { chIdx: m.view[m.row], current: false, record: true }
    if m.fCell.prog <> invalid then req.prog = m.fCell.prog
    m.top.optionsRequest = req
end sub

' ------------------------------------------------------------ hint bar
sub buildHints(x0 as Integer, y as Integer, maxW as Integer)
    m.hintsGroup.removeChildrenIndex(m.hintsGroup.getChildCount(), 0)
    hints = [["OK", "Watch/Options"], ["*", "Options"], ["R", "Record"], ["/", "Search"], ["T", "Sports"], ["V", "Favs"], ["REW/FF", "Page"], ["< >", "Time"], ["0-9", "Ch#"], ["BACK", "Exit"]]
    x = 0
    for each hnt in hints
        capW = Len(hnt[0]) * 16 + 26
        m.hintsGroup.appendChild(mkRect(x, 0, capW, m.HINT_H, "0x2B3A57FF"))
        m.hintsGroup.appendChild(mkLabel(x, 0, capW, m.HINT_H, hnt[0], 26, true, "0xFFFFFFFF"))
        m.hintsGroup.getChild(m.hintsGroup.getChildCount() - 1).horizAlign = "center"
        x = x + capW + 8
        dW = Len(hnt[1]) * 14 + 8
        m.hintsGroup.appendChild(mkLabel(x, 0, dW, m.HINT_H, hnt[1], 26, false, "0xC5D3EFFF"))
        x = x + dW + 20
    end for
    ' only the hint bar shrinks if a large overscan setting leaves it too little room
    sc = 1.0
    if x - 20 > maxW then sc = maxW / (x - 20)
    m.hintsGroup.scale = [sc, sc]
    m.hintsGroup.translation = [x0, y + Int(m.HINT_H * (1 - sc) / 2)]
end sub
