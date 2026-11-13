' On-screen button bar (top) + info banner (bottom) for the live-viewing screen.

sub init()
    m.bar = m.top.findNode("bar")
    m.banner = m.top.findNode("banner")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "onHideTimer")

    m.chNum = m.top.findNode("chNum")
    m.chLogo = m.top.findNode("chLogo")
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

    m.chNum.font.size = 72
    m.chName.font.size = 27
    m.titleLbl.font.size = 50
    m.badgeLbl.font.size = 24
    m.subLbl.font.size = 32
    m.timesLbl.font.size = 28
    m.nextLbl.font.size = 28
    m.clockLbl.font.size = 52
    m.dateLbl.font.size = 28

    m.barActive = false
    m.focusIdx = 0
    m.ids = ["guide", "favs", "dvr", "search", "sports", "ondemand", "menu", "last", "mute", "fav"]
    m.labels = ["GUIDE", "FAVS", "DVR", "SEARCH", "SPORTS", "ON DEMAND", "MENU", "LAST", "MUTE", "+ FAV"]
    m.btnRect = []
    m.btnText = []
    buildBar()
end sub

sub buildBar()
    pad = 22
    gap = 8
    h = 62
    widths = []
    total = 0
    for i = 0 to m.labels.Count() - 1
        w = Len(m.labels[i]) * 18 + pad * 2
        if m.ids[i] = "mute" then w = Len("UNMUTE") * 18 + pad * 2
        widths.Push(w)
        total = total + w + gap
    end for
    total = total - gap
    x0 = Int((1920 - total) / 2)
    m.bar.appendChild(mkRect(x0 - 12, 18, total + 24, h + 24, "0x08224FF0"))
    x = x0
    for i = 0 to m.labels.Count() - 1
        r = mkRect(x, 30, widths[i], h, "0x1E56B3FF")
        l = mkLabel(x, 30, widths[i], h, m.labels[i], 27, true, "0xFFFFFFFF")
        l.horizAlign = "center"
        m.bar.appendChild(r)
        m.bar.appendChild(l)
        m.btnRect.Push(r)
        m.btnText.Push(l)
        x = x + widths[i] + gap
    end for
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
            m.btnRect[k].color = "0xFFC845FF"
            m.btnText[k].color = "0x10244AFF"
        else
            m.btnRect[k].color = "0x1E56B3FF"
            m.btnText[k].color = "0xFFFFFFFF"
        end if
    end for
end sub

function idxOf(id as String) as Integer
    for k = 0 to m.ids.Count() - 1
        if m.ids[k] = id then return k
    end for
    return 0
end function

sub onMuted()
    if m.top.muted then
        m.btnText[idxOf("mute")].text = "UNMUTE"
    else
        m.btnText[idxOf("mute")].text = "MUTE"
    end if
end sub

sub onFav()
    if m.top.isFav then
        m.btnText[idxOf("fav")].text = "- FAV"
    else
        m.btnText[idxOf("fav")].text = "+ FAV"
    end if
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

sub fillBanner(info as Object)
    m.chNum.text = info.num
    m.chLogo.uri = info.logo
    m.chName.text = info.name
    ' natural width, truncated before it reaches the clock (leaves room for the rating badge)
    maxW = 1150
    if info.rating <> "" then maxW = 1040
    m.titleLbl.width = 0
    m.titleLbl.text = Left(info.title, 60)
    if m.titleLbl.boundingRect().width > maxW then m.titleLbl.width = maxW
    m.subLbl.text = info.subtitle
    m.timesLbl.text = info.times
    m.nextLbl.text = info.nextText
    hasTimes = (info.times <> "")
    m.progBg.visible = hasTimes
    m.progFill.visible = hasTimes
    pct = info.pct
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1
    m.progFill.width = Int(480 * pct)

    if info.rating <> "" then
        m.badgeLbl.text = info.rating
        w = Len(info.rating) * 15 + 24
        m.badgeRect.width = w
        m.badgeLbl.width = w
        bb = m.titleLbl.boundingRect()
        m.badge.translation = [316 + bb.width + 18, 25]
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
