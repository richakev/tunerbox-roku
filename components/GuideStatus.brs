' The guide's progress, as a card in the top right corner: "Loading the guide" with a sliding bar while it
' downloads, then "Guide ready" with how many channels and how far ahead it goes (the bar counting down
' until the card fades), and "Guide extended" when the second, longer pass arrives. Drawn at full size in
' screen pixels inside the safe area (a scaled card blurs its text).

sub init()
    m.W = 560
    m.MARGIN = 40
    m.card = m.top.findNode("card")
    m.cardBg = m.top.findNode("cardBg")
    m.accent = m.top.findNode("accent")
    m.glyph = m.top.findNode("glyph")
    m.titleLbl = m.top.findNode("titleLbl")
    m.subLbl = m.top.findNode("subLbl")
    m.seg = m.top.findNode("seg")
    m.fill = m.top.findNode("fill")
    m.fadeIn = m.top.findNode("fadeIn")
    m.slideIn = m.top.findNode("slideIn")
    m.fadeOut = m.top.findNode("fadeOut")
    m.sweep = m.top.findNode("sweep")
    m.countdown = m.top.findNode("countdown")
    m.countdown.observeField("state", "onCountdown")
    m.fadeOut.observeField("state", "onFadedOut")
    m.titleLbl.font.size = 30
    m.subLbl.font.size = 24
    m.top.findNode("barClip").clippingRect = [0, 0, 420, 5]
    m.cardBg.blendColor = thm("0x0B2A6AFF")
    m.up = false
    m.safeIns = [0, 0, 0, 0]
    drawGlyph()
    m.top.visible = false
end sub

sub onSafe()
    s = m.top.safe
    if Type(s) = "roArray" and s.Count() = 4 then m.safeIns = s
    m.card.translation = homeAt()
end sub

' where the card sits: the top right corner of the safe area
function homeAt() as Object
    return [1920 - m.safeIns[2] - m.MARGIN - m.W, m.safeIns[1] + m.MARGIN]
end function

' a little guide: three rows of shows, one of them picked (yellow, as the guide's focus)
sub drawGlyph()
    rows = [[30, 22], [18, 34], [40, 12]]
    cols = [thm("0x4F86E8FF"), thm("0x2E5DB8FF")]
    for r = 0 to 2
        x = 0
        for c = 0 to 1
            w = rows[r][c]
            col = cols[c]
            if r = 1 and c = 1 then col = thm("0xFFC845FF")
            m.glyph.appendChild(mkRect(x, r * 18, w, 12, col))
            x = x + w + 4
        end for
    end for
end sub

sub onShow()
    s = m.top.show
    if Type(s) <> "roAssociativeArray" then return
    kind = anyStr(s.kind)
    if kind = "hide" then
        hideCard()
        return
    end if
    n = Int(numv(s.channels))
    reach = Int(numv(s.through))
    m.countdown.control = "stop"
    if kind = "loading" then
        m.titleLbl.text = "Loading the guide"
        m.subLbl.text = "Getting the listings for your channels..."
        m.accent.color = thm("0x4F86E8FF")
        m.fill.visible = false
        m.seg.visible = true
        m.sweep.control = "start"
    else
        if kind = "extended" then m.titleLbl.text = "Guide extended" else m.titleLbl.text = "Guide ready"
        info = ""
        if n > 0 then info = n.ToStr() + " channels"
        if reach > 0 then
            if info <> "" then info = info + dotSep()
            info = info + "through " + whenText(reach)
        end if
        m.subLbl.text = info
        m.accent.color = thm("0x2ED47AFF")
        m.sweep.control = "stop"
        m.seg.visible = false
        m.fill.width = 420
        m.fill.visible = true
        m.countdown.control = "start"
    end if
    showCard()
end sub

' "11:00 PM" today, "Sat 9:00 PM" another day
function whenText(t as Integer) as String
    dt = localDT(t)
    today = localDT(nowEpoch())
    s = fmtClock(t)
    if dt.GetDayOfMonth() <> today.GetDayOfMonth() then s = Left(dt.GetWeekday(), 3) + " " + s
    return s
end function

sub showCard()
    m.fadeOut.control = "stop"
    m.top.visible = true
    at = homeAt()
    if m.up then
        m.card.translation = at
        m.card.opacity = 1.0
        return
    end if
    m.up = true
    ' slides in from a little to the right as it fades in
    m.slideIn.keyValue = [[at[0] + 40, at[1]], at]
    m.fadeIn.control = "start"
end sub

sub hideCard()
    m.countdown.control = "stop"
    if not m.up then return
    m.up = false
    m.fadeIn.control = "stop"
    m.fadeOut.control = "start"
end sub

sub onCountdown()
    if m.countdown.state = "stopped" and m.fill.visible and m.fill.width < 1 then hideCard()
end sub

sub onFadedOut()
    if m.fadeOut.state = "stopped" and not m.up then
        m.sweep.control = "stop"
        m.top.visible = false
    end if
end sub
