' Cable-box style programme guide: preview + info panel on top, time grid below.
' Layout constants are for a 1920x1080 scene.

sub init()
    themeInit()
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
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onHoldTimer")
    m.descTimer = m.top.findNode("descTimer")
    m.descTimer.observeField("fire", "onDescTimer")
    m.descWant = invalid
    m.wholeNum = CreateObject("roRegex", "^\d+$", "")
    m.holdKey = ""

    m.favSet = {}
    m.chs = []
    m.view = []
    m.row = 0
    m.rowTop = 0
    m.focusT = 0
    m.winStart = 0
    m.minT = 0
    m.maxT = 0
    m.cuDays = {}           ' catch-up days by channel number (TunerBox /api/catchup)
    m.cuMax = 0
    m.dataMax = 0
    m.jumpBuf = ""
    m.fCell = invalid
    m.nowLine = invalid
    m.rowCells = []
    m.chanNodes = []

    ' category filter (as the web guide): only channels with a show of that genre on in the hours shown;
    ' other shows are dimmed. Same word matching as TunerBox (epg.GENRES).
    m.GENRES = [["", "All"], ["movies", "Movies"], ["sports", "Sports"], ["news", "News"], ["kids", "Kids"]]
    m.genre = ""
    m.genreNone = false     ' that genre isn't on anywhere: every channel shown, all dimmed
    m.pick = false          ' the highlight is on the filter pills
    m.pickI = 0             ' which pill: 0 = Favorites, 1.. = m.GENRES
    m.favOnly = false       ' showing favorites only (the scene opened the guide with title "FAVORITES")
    m.PILL_H = 44
    m.baseView = []         ' the channels before filtering (all, or favorites only)

    m.bgGroup = m.top.findNode("bgGroup")
    m.hdrBar = m.top.findNode("hdrBar")
    m.pillsGroup = m.top.findNode("pillsGroup")
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
    bg = thm("0x0B1D46FF")
    m.bgGroup.removeChildrenIndex(m.bgGroup.getChildCount(), 0)
    m.bgGroup.appendChild(mkRect(0, 0, 1920, py, bg))
    m.bgGroup.appendChild(mkRect(0, py, px, m.PV_H, bg))
    m.bgGroup.appendChild(mkRect(pr, py, 1920 - pr, m.PV_H, bg))
    m.bgGroup.appendChild(mkRect(0, pb, 1920, 1080 - pb, bg))
    bc = thm("0x4F86E8FF")
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
    m.FILT_X = L
    m.FILT_Y = pb + 14
    m.HDR_Y = m.FILT_Y + m.PILL_H + 12
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
    if data = invalid or data.Count() = 0 then return
    ' memory: the listings now live in m.chs; the field's copy of them is let go (the {} comes back here
    ' and stops at the line above)
    m.top.guideData = {}
    for each key in data.Keys()
        idx = Int(Val(key))
        if idx >= 0 and idx < m.chs.Count() then m.chs[idx].programs = data[key]
    end for
    computeDataMax()
    if m.top.visible and m.view.Count() > 0 then
        if m.maxT < m.dataMax then m.maxT = m.dataMax
        if m.genre <> "" then refilter(false) else redraw()
    end if
end sub

sub onCuDays()
    m.cuDays = m.top.cuDays
    if m.cuDays = invalid then m.cuDays = {}
    m.cuMax = 0
    for each k in m.cuDays
        d = Int(numv(m.cuDays[k]))
        if d > m.cuMax then m.cuMax = d
    end for
    if m.top.visible then m.minT = earliestT()
end sub

' how far back the guide goes: now, or as far as the longest catch-up archive
function earliestT() as Integer
    t = nowEpoch()
    if m.cuMax > 0 then return floor30(t - m.cuMax * 86400)
    return floor30(t)
end function

function hasCatchup(ch as Object) as Boolean
    return Int(numv(m.cuDays[ch.numStr])) > 0
end function

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
    m.favOnly = (info.title <> invalid and info.title = "FAVORITES")
    ' Favorites shows as a pill; any other title stays in the corner
    if info.title <> invalid and not m.favOnly then m.filterLbl.text = plainText(info.title)
    m.baseView = m.view
    m.genre = ""
    m.genreNone = false
    m.pick = false

    t = nowEpoch()
    m.minT = earliestT()
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
    holdStop()
    ' forget everything about where the user was scrolling
    m.fCell = invalid
    m.fRow = invalid
    m.jumpBuf = ""
    m.jumpLbl.visible = false
    m.pick = false
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
    drawPicker()

    for k = 0 to 3
        cx = m.TIME_X + Int(k * 30 * m.PPM)
        m.rowsGroup.appendChild(mkRect(cx, m.HDR_Y + 8, 2, m.HDR_H - 16, thm("0x5A87D8FF")))
        m.rowsGroup.appendChild(mkLabel(cx + 12, m.HDR_Y, 300, m.HDR_H, fmtClock(ws + k * 1800), 31, true, thm("0xFFFFFFFF")))
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

        crect = mkRect(m.CH_X, y, m.CH_W, h, thm("0x12408FFF"))
        star = CreateObject("roSGNode", "Poster")
        star.translation = [m.CH_X + 10, y + Int((h - 30) / 2)]
        star.width = 30
        star.height = 30
        if m.favSet[ch.numStr] <> invalid then
            star.uri = "pkg:/images/star_on.png"
        else
            star.uri = "pkg:/images/star_off.png"
        end if
        cnum = mkLabel(m.CH_X + 48, y, 88, h, ch.numStr, 36, true, thm("0xFFFFFFFF"))
        logo = CreateObject("roSGNode", "Poster")
        logo.translation = [m.CH_X + 138, y + 10]
        logo.width = 84
        logo.height = h - 20
        logo.loadDisplayMode = "scaleToFit"
        logo.uri = ch.logo
        cname = mkLabel(m.CH_X + 230, y, 164, h, ch.name, 29, true, thm("0xFFFFFFFF"))
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
    m.nowLine = mkRect(0, m.HDR_Y + m.HDR_H, 3, shown * m.ROW_H, thm("0xFF3B3BFF"))
    m.rowsGroup.appendChild(m.nowLine)
    updateNowLine()

    applyFocus()
end sub

' a cell's text: "College Football: Texas at Texas A&M" when the guide knows the teams (guide.json?teams=1)
function progTitle(p as Object) as String
    teams = anyStr(p.teams)
    if teams = "" then return p.title
    return p.title + ": " + teams
end function

function buildRowCells(ch as Object, ws as Integer, we as Integer) as Object
    cells = []
    t = ws
    if ch.programs <> invalid then
        for each p in ch.programs
            if p.stop > ws and p.start < we then
                if p.start > t then cells.Push(emptyCell(t, p.start))
                s = p.start
                if s < t then s = t
                if m.genre <> "" and genreOf(p.cat) <> m.genre then
                    cells.Push({ start: s, stop: p.stop, title: progTitle(p), prog: p, base: thm("0x1C2B4EFF"), txtColor: thm("0x8FA3C8FF") })
                else
                    cells.Push({ start: s, stop: p.stop, title: progTitle(p), prog: p, base: catColor(p.cat), txtColor: thm("0xFFFFFFFF") })
                end if
                if p.stop > t then t = p.stop
            end if
        end for
    end if
    if t < we then cells.Push(emptyCell(t, we))
    return cells
end function

function emptyCell(s as Integer, e as Integer) as Object
    return { start: s, stop: e, title: "No Data", prog: invalid, base: thm("0x1A2A4DFF"), txtColor: thm("0x8FA3C8FF") }
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
    styleCell(pick, not m.pick)
    styleChannel(r, not m.pick)
    if m.pick then pickerInfo() else updateInfo(pick)

end sub

sub styleCell(c as Object, focused as Boolean)
    if focused then
        c.rect.color = thm("0xFFC845FF")
        if c.lbl <> invalid then c.lbl.color = thm("0x111111FF")
    else
        c.rect.color = c.base
        if c.lbl <> invalid then c.lbl.color = c.txtColor
    end if
end sub

sub styleChannel(r as Integer, focused as Boolean)
    if r < 0 or r >= m.chanNodes.Count() then return
    n = m.chanNodes[r]
    if focused then
        n.rect.color = thm("0x2A66C8FF")
        n.num.color = thm("0xFFC845FF")
    else
        n.rect.color = thm("0x12408FFF")
        n.num.color = thm("0xFFFFFFFF")
    end if
end sub

' ------------------------------------------------------------ descriptions, fetched when shown
' TunerBox's guide.json?desc=0 leaves descriptions out of the bulk download (most of its bytes); the one for
' the focused show comes from /api/guide (every TunerBox has it), with the next hours of that channel's, once
' focus rests on it. An older TunerBox sends them all anyway: then this only runs for shows that have none.
sub wantDesc(idx as Integer, ch as Object, p as Object)
    if truthy(p.descTried) then return
    ' /api/guide takes whole channel numbers only (anything else would answer with every channel)
    if not m.wholeNum.IsMatch(ch.numStr) then return
    m.descWant = { idx: idx, num: ch.numStr, start: p.start }
    m.descTimer.control = "stop"
    m.descTimer.control = "start"
end sub

sub onDescTimer()
    w = m.descWant
    m.descWant = invalid
    if w = invalid or w.idx < 0 or w.idx >= m.chs.Count() then return
    ' this show and the 6 hours after it on that channel: one request, and asked for once each
    stopAt = w.start + 6 * 3600
    ch = m.chs[w.idx]
    if ch.programs <> invalid then
        for each p in ch.programs
            if p.stop > w.start and p.start < stopAt then p.descTried = true
        end for
    end if
    m.top.descRequest = { idx: w.idx, num: w.num, start: w.start, stop: stopAt }
end sub

sub onDescReply()
    r = m.top.descReply
    if r = invalid or r.descs = invalid or r.idx = invalid then return
    if r.idx < 0 or r.idx >= m.chs.Count() then return
    ch = m.chs[r.idx]
    if ch.programs = invalid then return
    for each p in ch.programs
        d = r.descs[p.start.ToStr()]
        if d <> invalid then p.desc = d
    end for
    ' the focused show is one of them: show its description now
    if m.top.visible and not m.pick and m.fCell <> invalid and m.row >= 0 and m.row < m.view.Count() then
        if m.view[m.row] = r.idx then updateInfo(m.fCell)
    end if
end sub

sub updateInfo(c as Object)
    ch = m.chs[m.view[m.row]]
    chText = ch.numStr + " " + ch.name
    if c.prog <> invalid then
        p = c.prog
        setTitle(Left(p.title, 60), p.rating <> "")
        m.subLbl.text = plainText(subLine(p))
        meta = fmtDay(p.start) + "  " + fmtClock(p.start) + dashSep() + fmtClock(p.stop) + dotSep() + chText
        if p.cat <> "" then meta = meta + dotSep() + p.cat
        m.metaLbl.text = plainText(meta)
        m.descLbl.text = plainText(p.desc)
        if anyStr(p.desc) = "" then wantDesc(m.view[m.row], ch, p)
        if p.rating <> "" then
            showBadge(p.rating)
        else
            m.badge.visible = false
        end if
    else
        setTitle(ch.name, false)
        m.subLbl.text = ""
        m.metaLbl.text = plainText(chText)
        m.descLbl.text = "No guide data for this time slot."
        m.badge.visible = false
    end if
end sub

' natural-width title, truncated (with ellipsis) when it would run into the clock / badge
sub setTitle(txt as String, hasBadge as Boolean)
    maxW = m.TITLE_MAXW
    if hasBadge then maxW = maxW - 110
    m.titleLbl.width = 0
    m.titleLbl.text = plainText(txt)
    if m.titleLbl.boundingRect().width > maxW then m.titleLbl.width = maxW
end sub

sub showBadge(txt as String)
    w = Len(txt) * 15 + 24
    m.badgeRect.width = w
    m.badgeLbl.width = w
    bb = m.titleLbl.boundingRect()
    m.badge.translation = [m.TITLE_X + bb.width + 18, m.TITLE_Y + 14]
    m.badgeLbl.text = plainText(txt)
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
        ' the show before this one, from its start (as Right goes to the next show's start). The cell's own
        ' start is cut off at the left edge of the hours shown, so a long show would go back 30 min a step.
        s = m.fCell.start
        if m.fCell.prog <> invalid then s = m.fCell.prog.start
        if s <= m.minT then return
        nt = prevShowStart(s)
        if nt < m.minT then nt = m.minT
    else
        nt = m.fCell.stop
        if nt >= m.maxT then return
    end if
    m.focusT = nt
    if nt < m.winStart or nt >= m.winStart + m.WIN then
        m.winStart = floor30(nt)
        ' before the listings loaded at startup (they begin an hour ago): the scene fetches the archive's shows
        if m.cuMax > 0 and m.winStart < nowEpoch() - 3600 then m.top.pastRequest = m.winStart
        ' other hours: the channels showing the category change too
        if m.genre <> "" then refilter(false) else redraw()
    else
        applyFocus()
    end if
end sub

' on the focused channel: the start of the show that's on just before t. When nothing is listed then (a gap,
' shown as "No Data"), where the gap starts: the end of the last show before it; t - 1 when there's none.
function prevShowStart(t as Integer) as Integer
    ch = m.chs[m.view[m.row]]
    gapAt = 0
    if ch <> invalid and ch.programs <> invalid then
        for each p in ch.programs
            if p.start < t and p.stop >= t then return p.start
            if p.stop < t and p.stop > gapAt then gapAt = p.stop
        end for
    end if
    if gapAt > 0 then return gapAt
    return t - 1
end function

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
    ' on a channel with catch-up, the show on now can be started over: OK asks, as for other shows
    cuNow = (isNow and c.prog <> invalid and hasCatchup(m.chs[ci]))
    if forceOptions or cuNow or (not isNow and c.prog <> invalid) then
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

' ------------------------------------------------------------ arrows held
' holding Up or Down keeps moving a channel at a time, Left or Right a show at a time (after a short pause,
' so a tap is still one step)
sub holdStart(key as String)
    m.holdKey = key
    m.holdTimer.control = "stop"
    m.holdTimer.duration = 0.4
    m.holdTimer.control = "start"
end sub

sub holdStop()
    if m.holdKey = "" then return
    m.holdKey = ""
    m.holdTimer.control = "stop"
end sub

sub onHoldTimer()
    if m.holdKey = "" or m.pick or not m.top.visible or m.fCell = invalid then
        holdStop()
        return
    end if
    sideways = (m.holdKey = "left" or m.holdKey = "right")
    if m.holdTimer.duration > 0.3 then
        ' a show a step is a little slower than a channel: it often moves the hours shown, a bigger redraw
        m.holdTimer.control = "stop"
        if sideways then m.holdTimer.duration = 0.18 else m.holdTimer.duration = 0.1
        m.holdTimer.control = "start"
    end if
    if sideways then
        ' stops at either end of the guide: as far back as catch-up goes, the last listings ahead
        before = m.focusT
        if m.holdKey = "left" then moveTime(-1) else moveTime(1)
        if m.focusT = before then holdStop()
        return
    end if
    before = m.row
    ' held Up stops on the first channel (it doesn't carry on into the filter pills)
    if m.holdKey = "up" then moveRow(-1) else moveRow(1)
    if m.row = before then holdStop()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then
        if m.holdKey <> "" and key = m.holdKey then
            holdStop()
            return true
        end if
        return false
    end if
    holdStop()
    if not m.top.visible or m.fCell = invalid then return false
    if m.pick then
        if key = "left" or key = "right" then
            ' along the pills; a category pill filters as soon as it's highlighted, Favorites waits for OK
            ni = m.pickI + 1
            if key = "left" then ni = m.pickI - 1
            if ni < 0 or ni > m.GENRES.Count() then return true
            m.pickI = ni
            if ni >= 1 then
                m.genre = m.GENRES[ni - 1][0]
                refilter(false)
            else
                drawPicker()
                pickerInfo()
            end if
            return true
        else if key = "OK" and m.pickI = 0 then
            m.top.menuRequest = "favview"
            return true
        else if key = "OK" or key = "down" or key = "back" or key = "up" then
            setPick(false)
            return true
        end if
        ' anything else: back on the channels, and the key does its usual thing
        setPick(false)
    end if
    if key = "up" and m.row = 0 then
        ' Up on the first channel: the filter pills
        setPick(true)
        return true
    end if
    if key = "left" then
        moveTime(-1)
        holdStart("left")
    else if key = "right" then
        moveTime(1)
        holdStart("right")
    else if key = "up" then
        moveRow(-1)
        holdStart("up")
    else if key = "down" then
        moveRow(1)
        holdStart("down")
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
    else if lc = "c" then
        cycleGenre(1, true)
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
    ' as the web guide's shorter footer; the filters are on the pills now
    hints = [["OK", "Watch / Options"], ["*", "Options"], ["< >", "Time"], ["REW/FF", "Page"], ["UP", "Filters"], ["BACK", "Close"]]
    buildKeyHints(m.hintsGroup, hints, m.HINT_H, maxW)
    sc = m.hintsGroup.scale[0]
    m.hintsGroup.translation = [x0, y + Int(m.HINT_H * (1 - sc) / 2)]
end sub

' ------------------------------------------------------------ category filter
' "movies" / "sports" / "news" / "kids" for a program category, "" for anything else (TunerBox epg.genre)
function genreOf(cat as Dynamic) as String
    if cat = invalid then return ""
    c = LCase(cat)
    if c = "" then return ""
    if Instr(1, c, "movie") > 0 or Instr(1, c, "film") > 0 then return "movies"
    if Instr(1, c, "sport") > 0 then return "sports"
    if Instr(1, c, "news") > 0 then return "news"
    for each w in ["kids", "children", "family", "animation", "cartoon"]
        if Instr(1, c, w) > 0 then return "kids"
    end for
    return ""
end function

function genreLabel() as String
    for each g in m.GENRES
        if g[0] = m.genre then return g[1]
    end for
    return "All"
end function

' does this channel have a show of the genre on between ws and we?
function hasGenre(ch as Object, g as String, ws as Integer, we as Integer) as Boolean
    if ch.programs = invalid then return false
    for each p in ch.programs
        if p.start >= we then return false
        if p.stop > ws and genreOf(p.cat) = g then return true
    end for
    return false
end function

' called by the scene (guide menu > Category)
sub setGenre(id as String)
    m.genre = id
    m.pick = false
    refilter(true)
end sub

sub cycleGenre(stepBy as Integer, announce as Boolean)
    i = 0
    for k = 0 to m.GENRES.Count() - 1
        if m.GENRES[k][0] = m.genre then i = k
    end for
    n = m.GENRES.Count()
    m.genre = m.GENRES[(i + stepBy + n) mod n][0]
    refilter(announce)
end sub

' rebuild the channel list for the category; the highlighted channel stays if it's still listed
sub refilter(announce as Boolean)
    cur = -1
    if m.row >= 0 and m.row < m.view.Count() then cur = m.view[m.row]
    m.genreNone = false
    if m.genre = "" then
        m.view = m.baseView
    else
        ws = m.winStart
        we = ws + m.WIN
        list = []
        for each ci in m.baseView
            if hasGenre(m.chs[ci], m.genre, ws, we) then list.Push(ci)
        end for
        if list.Count() = 0 then
            m.genreNone = true
            list = m.baseView
        end if
        m.view = list
    end if
    m.row = 0
    for i = 0 to m.view.Count() - 1
        if m.view[i] = cur then
            m.row = i
            exit for
        end if
    end for
    m.rowTop = m.row - 2
    clampTop()
    redraw()
    if announce then
        if m.genre = "" then
            m.top.notice = "All channels"
        else if m.genreNone then
            m.top.notice = "No " + LCase(genreLabel()) + " on in these hours"
        else
            n = m.view.Count()
            txt = genreLabel() + ": " + n.ToStr() + " channel"
            if n <> 1 then txt = txt + "s"
            m.top.notice = txt
        end if
    end if
end sub

sub setPick(on as Boolean)
    m.pick = on
    if on then
        ' start on the category in use
        m.pickI = 1
        for k = 0 to m.GENRES.Count() - 1
            if m.GENRES[k][0] = m.genre then m.pickI = k + 1
        end for
    end if
    drawPicker()
    applyFocus()
end sub

' the filter pills (as the web guide): the one in use filled in, the highlighted one in the accent colour.
' A category with nothing on in these hours says so ("none"); every channel stays listed, dimmed.
sub drawPicker()
    m.dateLbl.text = fmtDay(m.winStart)
    g = m.pillsGroup
    g.removeChildrenIndex(g.getChildCount(), 0)
    x = m.FILT_X
    y = m.FILT_Y
    for i = 0 to m.GENRES.Count()
        if i = 0 then
            txt = "Favorites"
            isOn = m.favOnly
        else
            txt = m.GENRES[i - 1][1]
            isOn = (m.GENRES[i - 1][0] = m.genre)
            if isOn and m.genreNone then txt = txt + " " + Chr(183) + " none"
        end if
        focus = m.pick and m.pickI = i
        if focus then
            bg = thm("0xFFC845FF")
            fg = thm("0x111111FF")
        else if isOn then
            bg = thm("0xE6EEFFFF")
            fg = thm("0x10244AFF")
        else
            bg = thm("0x163A7DFF")
            fg = thm("0x9FB3DCFF")
        end if
        lbl = mkLabel(0, y, 0, m.PILL_H, txt, 26, true, fg)
        tw = lbl.boundingRect().width
        if tw <= 0 then tw = Len(txt) * 14
        pad = 22
        starW = 0
        if i = 0 then starW = 30
        w = tw + pad * 2 + starW
        g.appendChild(mkPill(x, y, w, m.PILL_H, bg))
        if i = 0 then
            star = CreateObject("roSGNode", "Poster")
            star.translation = [x + pad - 4, y + 9]
            star.width = 26
            star.height = 26
            if isOn and not focus then star.uri = "pkg:/images/star_on.png" else star.uri = "pkg:/images/star_off.png"
            g.appendChild(star)
        end if
        lbl.translation = [x + pad + starW, y]
        g.appendChild(lbl)
        x = x + w + 12
    end for
end sub

sub pickerInfo()
    m.badge.visible = false
    if m.pickI = 0 then
        if m.favOnly then
            setTitle("Favorites only", false)
            m.subLbl.text = "OK: show every channel again"
        else
            setTitle("Favorites", false)
            m.subLbl.text = "OK: show only your favorite channels"
        end if
        m.metaLbl.text = "Right: categories      Down: back to the channels"
        m.descLbl.text = "Press * on a channel (Options > Favorite) to add it to your favorites."
        return
    end if
    setTitle("Filter by category", false)
    m.subLbl.text = "Left / Right: All channels, Movies, Sports, News or Kids"
    m.metaLbl.text = "OK or Down to go back to the channels"
    m.descLbl.text = "Lists only the channels with a show of that category on in the hours shown. Shows of other categories are dimmed."
end sub
