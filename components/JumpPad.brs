' Jump to channel: a number pad of our own (Roku's keyboard and PIN dialogs show letters, hide the digits or
' stop taking input on some models). The number typed so far is shown above the keys; Go sends it as `result`.
' Arrows + OK use the pad; Replay deletes a digit, Play goes, Back cancels; a keyboard's digits work too.

sub init()
    themeInit()
    m.panel = m.top.findNode("panel")
    m.KEYS = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "go"]
    m.MAXLEN = 5
    m.CW = 170
    m.CH = 96
    m.GAP = 16
    m.sel = 0
    m.num = ""
end sub

sub openPad()
    m.num = ""
    m.sel = 0
    m.top.visible = true
    m.top.setFocus(true)
    render()
end sub

sub closePad()
    m.top.visible = false
end sub

sub render()
    m.panel.removeChildrenIndex(m.panel.getChildCount(), 0)
    gridW = 3 * m.CW + 2 * m.GAP
    w = gridW + 80
    gridY = 270
    h = gridY + 4 * m.CH + 3 * m.GAP + 80
    m.panel.translation = [Int((1920 - w) / 2), Int((1080 - h) / 2)]

    m.panel.appendChild(mkRect(0, 0, w, h, thm("0x0B2A6AF8")))
    m.panel.appendChild(mkRect(0, 0, w, 4, thm("0xFFC845FF")))
    m.panel.appendChild(mkLabel(40, 18, w - 80, 62, "Jump to channel", 48, true, thm("0xFFFFFFFF")))

    ' the number so far
    m.panel.appendChild(mkRect(40, 100, w - 80, 140, thm("0x12408FFF")))
    if m.num = "" then
        hint = mkLabel(40, 100, w - 80, 140, "Type a channel number", 32, false, thm("0xAFC8F5FF"))
        hint.horizAlign = "center"
        m.panel.appendChild(hint)
    else
        big = mkLabel(40, 100, w - 80, 140, m.num, 84, true, thm("0xFFFFFFFF"))
        big.horizAlign = "center"
        m.panel.appendChild(big)
    end if

    for i = 0 to m.KEYS.Count() - 1
        k = m.KEYS[i]
        x = 40 + (i mod 3) * (m.CW + m.GAP)
        y = gridY + Int(i / 3) * (m.CH + m.GAP)
        lbl = k
        size = 48
        if k = "del" then
            lbl = "Delete"
            size = 32
        else if k = "go" then
            lbl = "Go"
            size = 36
        end if
        if i = m.sel then
            bg = thm("0xFFC845FF")
            tc = thm("0x10244AFF")
        else if k = "go" then
            bg = thm("0x1F6B3AFF")
            tc = thm("0xFFFFFFFF")
        else
            bg = thm("0x16397AFF")
            tc = thm("0xFFFFFFFF")
        end if
        m.panel.appendChild(mkRect(x, y, m.CW, m.CH, bg))
        l = mkLabel(x, y, m.CW, m.CH, lbl, size, true, tc)
        l.horizAlign = "center"
        m.panel.appendChild(l)
    end for

    foot = mkLabel(40, h - 62, w - 80, 40, "Play  Go      Replay  Delete      Back  Cancel", 24, false, thm("0xC5D3EFFF"))
    foot.horizAlign = "center"
    m.panel.appendChild(foot)
end sub

sub pressKey(k as String)
    if k = "del" then
        if Len(m.num) > 0 then m.num = Left(m.num, Len(m.num) - 1)
    else if k = "go" then
        if m.num <> "" then m.top.result = m.num
    else if Len(m.num) < m.MAXLEN then
        m.num = m.num + k
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.top.visible then return false
    if key = "up" then
        if m.sel >= 3 then m.sel = m.sel - 3
    else if key = "down" then
        if m.sel + 3 < m.KEYS.Count() then m.sel = m.sel + 3
    else if key = "left" then
        if m.sel mod 3 > 0 then m.sel = m.sel - 1
    else if key = "right" then
        if m.sel mod 3 < 2 then m.sel = m.sel + 1
    else if key = "OK" then
        pressKey(m.KEYS[m.sel])
    else if key = "replay" then
        pressKey("del")
    else if key = "play" then
        pressKey("go")
    else if key = "back" then
        m.top.closeRequest = true
        return true
    else if Left(key, 4) = "Lit_" then
        d = Mid(key, 5)
        if Len(d) = 1 and d >= "0" and d <= "9" then pressKey(d)
    end if
    if m.top.visible then render()
    return true      ' the pad keeps every key while it's open
end function
