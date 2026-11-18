' On-screen button bar (top) + info banner (bottom) for the live-viewing screen.

sub init()
    themeInit()
    m.bar = m.top.findNode("bar")
    m.banner = m.top.findNode("banner")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHideTimer")

    m.chNum = m.top.findNode("chNum")
    m.chLogo = m.top.findNode("chLogo")
    m.chLogoBg = m.top.findNode("chLogoBg")
    m.chName = m.top.findNode("chName")
    m.titleLbl = m.top.findNode("titleLbl")
    m.badge = m.top.findNode("badge")
    m.badgeRect = m.top.findNode("badgeRect")
    m.badgeLbl = m.top.findNode("badgeLbl")
    m.subLbl = m.top.findNode("subLbl")
    m.timesLbl = m.top.findNode("timesLbl")
    m.progBg = m.top.findNode("progBg")
    m.progFill = m.top.findNode("progFill")
    m.nextLbl = m.top.findNode("nextLbl")
    m.clockLbl = m.top.findNode("clockLbl")
    m.dateLbl = m.top.findNode("dateLbl")

    m.chNum.font.size = 92
    m.titleLbl.font.size = 46
    m.badgeLbl.font.size = 20
    m.subLbl.font.size = 27
    m.nextLbl.font.size = 25
    m.clockLbl.font.size = 46
    m.dateLbl.font.size = 26

    m.inX = 0               ' left + right insets: the right-hand things move in by this much
    m.barActive = false
    m.focusIdx = 0
    buildBar()
end sub

sub onSafe()
    sf = m.top.safe
    if sf = invalid or sf.Count() < 4 then return
    m.inX = sf[0] + sf[2]
    m.banner.translation = [0, 840 - sf[1] - sf[3]]
    m.clockLbl.translation = [1480 - m.inX, 62]
    m.dateLbl.translation = [1480 - m.inX, 122]
end sub

sub onShowHome()
    m.focusIdx = 0
    buildBar()
end sub

' The bar at the top, as the web TV's: TunerBox, then the screens, in one rounded capsule; the highlighted
' item gets an accent pill. Everything else (favorite, last channel, record, mute, menu) is under More.
sub buildBar()
    m.ids = ["guide", "ondemand", "sports", "search", "more"]
    m.labels = ["Guide", "On Demand", "Sports & Events", "Search", "More"]
    if not m.top.showOnDemand then
        m.ids.Delete(1)
        m.labels.Delete(1)
    end if
    if m.top.showHome then
        m.ids.Unshift("home")
        m.labels.Unshift("Home")
    end if
    m.btnRect = []
    m.btnText = []
    m.bar.removeChildrenIndex(m.bar.getChildCount(), 0)
    x0 = 40
    y0 = 30
    h = 76
    panel = CreateObject("roSGNode", "Poster")
    panel.uri = "pkg:/images/pill.9.png"
    panel.translation = [x0, y0]
    panel.height = h
    panel.blendColor = thm("0x08224FFF")
    panel.opacity = 0.94
    m.bar.appendChild(panel)
    brand = mkLabel(x0 + 30, y0, 0, h, "Tuner", 34, true, thm("0xFFFFFFFF"))
    m.bar.appendChild(brand)
    brand2 = mkLabel(x0 + 30 + Int(brand.boundingRect().width), y0, 0, h, "Box", 34, true, thm("0xFFC845FF"))
    m.bar.appendChild(brand2)
    x = x0 + 30 + Int(brand.boundingRect().width) + Int(brand2.boundingRect().width) + 26
    for i = 0 to m.labels.Count() - 1
        l = mkLabel(x, y0 + 8, 0, h - 16, m.labels[i], 28, true, thm("0xDCE8FFFF"))
        w = Int(l.boundingRect().width) + 44
        l.width = w
        l.horizAlign = "center"
        r = mkPill(x, y0 + 8, w, h - 16, thm("0xFFC845FF"))
        m.bar.appendChild(r)
        m.bar.appendChild(l)
        m.btnRect.Push(r)
        m.btnText.Push(l)
        x = x + w + 4
    end for
    panel.width = x - x0 + 12
    setFocusIdx(m.focusIdx)
end sub

sub setFocusIdx(i as Integer)
    n = m.ids.Count()
    if i < 0 then i = n - 1
    if i >= n then i = 0
    m.focusIdx = i
    paintBar(m.barActive)
end sub

' active = bar has remote focus (highlight selection); otherwise display-only
sub paintBar(active as Boolean)
    for k = 0 to m.ids.Count() - 1
        if active and k = m.focusIdx then
            m.btnRect[k].visible = true
            m.btnRect[k].blendColor = thm("0xFFC845FF")
            m.btnText[k].color = thm("0x10244AFF")
        else
            m.btnRect[k].visible = false
            m.btnText[k].color = thm("0xDCE8FFFF")
        end if
    end for
end sub

function idxOf(id as String) as Integer
    for k = 0 to m.ids.Count() - 1
        if m.ids[k] = id then return k
    end for
    return 0
end function

' mute and favorite live in More now; the scene reads these fields for its labels
sub onMuted()
end sub

sub onFav()
end sub

' ------------------------------------------------------------ callable from the scene
sub showBanner(info as Object)
    ' bar is interactive whenever it is visible: Left/Right move, OK selects,
    ' Up/Down still bubble to the scene for channel surfing
    fillBanner(info)
    m.banner.visible = true
    m.bar.visible = true
    m.barActive = true
    paintBar(true)
    m.top.visible = true
    m.top.setFocus(true)
    startTimer(6)
end sub

sub showBar(info as Object)
    fillBanner(info)
    m.banner.visible = true
    m.bar.visible = true
    m.barActive = true
    paintBar(true)
    m.top.visible = true
    m.top.setFocus(true)
    startTimer(9)
end sub

' On Demand playback: the banner only (no button bar, keys stay with the scene).
' seconds = 0 keeps it up (paused)
sub showVod(info as Object, seconds as Integer)
    if m.barActive then
        m.barActive = false
        m.top.getScene().setFocus(true)
    end if
    fillBanner(info)
    m.bar.visible = false
    m.banner.visible = true
    m.top.visible = true
    if seconds > 0 then
        startTimer(seconds)
    else
        m.hideTimer.control = "stop"
    end if
end sub

' refresh the banner text while it is up (playback clock), without touching the timer
sub updateVod(info as Object)
    if m.banner.visible and not m.bar.visible then fillBanner(info)
end sub

sub hideAll()
    m.hideTimer.control = "stop"
    m.bar.visible = false
    m.banner.visible = false
    m.top.visible = false
    if m.barActive then
        m.barActive = false
        m.top.getScene().setFocus(true)
    end if
end sub

' ------------------------------------------------------------ internals
sub startTimer(seconds as Integer)
    m.hideTimer.control = "stop"
    m.hideTimer.duration = seconds
    m.hideTimer.control = "start"
end sub

sub onHideTimer()
    hideAll()
end sub

' one row, as the web banner: number, logo card, then title (+ rating), one line of details and the progress
sub fillBanner(info as Object)
    m.chNum.width = 0
    m.chNum.text = plainText(info.num)
    x = 40 + Int(m.chNum.boundingRect().width) + 22
    hasLogo = (info.logo <> invalid and info.logo <> "")
    m.chLogo.uri = info.logo
    m.chLogo.visible = hasLogo
    m.chLogoBg.visible = hasLogo
    if hasLogo then
        m.chLogoBg.translation = [x, 78]
        m.chLogo.translation = [x + 10, 84]
        x = x + 150 + 26
    end if

    ' natural width, truncated before it reaches the clock (leaves room for the rating badge)
    rating = plainText(info.rating)
    maxW = 1440 - m.inX - x
    if rating <> "" then maxW = maxW - 110
    m.titleLbl.translation = [x, 60]
    m.titleLbl.width = 0
    m.titleLbl.text = plainText(Left(info.title, 60))
    if m.titleLbl.boundingRect().width > maxW then m.titleLbl.width = maxW

    ' details: what it is, when, and what's next (On Demand puts its key hints on their own line)
    nxt = info.nextText
    hint = ""
    if nxt <> "" and LCase(Left(nxt, 8)) <> "up next:" then
        hint = nxt
        nxt = ""
    end if
    sep = " " + Chr(183) + " "
    parts = []
    for each t in [info.name, info.subtitle, info.times, nxt]
        if t <> invalid and t <> "" and not (hasLogo and t = info.name) then parts.Push(t)
    end for
    ' the channel name is in its logo; without one, it leads the details
    m.subLbl.translation = [x, 120]
    m.subLbl.width = 1460 - m.inX - x
    m.subLbl.text = plainText(parts.Join(sep))
    m.nextLbl.translation = [x, 186]
    m.nextLbl.width = 1760 - m.inX - x
    ' a channel's catch-up flag goes on that line when it has no key hints
    if hint = "" and info.flag <> invalid then hint = info.flag
    m.nextLbl.text = plainText(hint)
    hasTimes = (info.times <> "")
    m.progBg.translation = [x, 168]
    m.progFill.translation = [x, 168]
    m.progBg.visible = hasTimes
    pct = info.pct
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1
    ' the rounded fill needs its full 10px to look right
    fw = Int(440 * pct)
    m.progFill.visible = hasTimes and fw >= 10
    m.progFill.width = fw

    if rating <> "" then
        m.badgeLbl.text = rating
        w = Len(rating) * 13 + 22
        m.badgeRect.width = w
        m.badgeLbl.width = w
        bb = m.titleLbl.boundingRect()
        m.badge.translation = [x + bb.width + 16, 73]
        m.badge.visible = true
    else
        m.badge.visible = false
    end if

    t = nowEpoch()
    m.clockLbl.text = fmtClock(t)
    m.dateLbl.text = fmtDay(t)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not m.barActive then return false
    if not press then return false
    startTimer(9)
    if key = "left" then
        setFocusIdx(m.focusIdx - 1)
        return true
    else if key = "right" then
        setFocusIdx(m.focusIdx + 1)
        return true
    else if key = "OK" then
        m.top.buttonSelected = m.ids[m.focusIdx]
        return true
    else if key = "back" then
        hideAll()
        return true
    end if
    ' up / down etc. bubble to the scene (channel change)
    return false
end function
