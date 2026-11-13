' Main menu: two-column tile grid that fits the screen without scrolling.
' items = [{ id, label, value }]; value (optional) is shown on the right of the tile.

sub init()
    m.panel = m.top.findNode("panel")
    m.sel = 0
    m.COLS = 2
    m.TW = 600
    m.TH = 96
    m.GAP = 14
end sub

sub openMenu()
    m.sel = 0
    m.top.visible = true
    m.top.setFocus(true)
    render()
end sub

sub closeMenu()
    m.top.visible = false
end sub

sub onItems()
    if m.top.visible then render()
end sub

sub render()
    m.panel.removeChildrenIndex(m.panel.getChildCount(), 0)
    items = m.top.items
    if items = invalid then return
    n = items.Count()
    rows = Int((n + m.COLS - 1) / m.COLS)
    w = m.COLS * m.TW + (m.COLS - 1) * m.GAP + 80
    h = 160 + rows * (m.TH + m.GAP) + 70
    if m.sel > n - 1 then m.sel = n - 1
    ' keep the panel centred whatever the item count
    py = Int((1080 - h) / 2)
    if py < 0 then py = 0
    m.panel.translation = [Int((1920 - w) / 2), py]

    m.panel.appendChild(mkRect(0, 0, w, h, "0x0B2A6AF8"))
    m.panel.appendChild(mkRect(0, 0, w, 4, "0xFFC845FF"))
    m.panel.appendChild(mkLabel(40, 18, w - 80, 62, m.top.heading, 52, true, "0xFFFFFFFF"))
    sl = mkLabel(40, 82, w - 80, 38, m.top.subtitle, 28, false, "0xAFC8F5FF")
    m.panel.appendChild(sl)
    m.panel.appendChild(mkRect(40, 130, w - 80, 2, "0x3B5B96FF"))

    for i = 0 to n - 1
        it = items[i]
        col = i mod m.COLS
        row = Int(i / m.COLS)
        x = 40 + col * (m.TW + m.GAP)
        y = 156 + row * (m.TH + m.GAP)
        if i = m.sel then
            bg = "0xFFC845FF"
            tc = "0x10244AFF"
            vc = "0x5A3F00FF"
        else
            bg = "0x1E56B3FF"
            tc = "0xFFFFFFFF"
            vc = "0xFFD98AFF"
        end if
        m.panel.appendChild(mkRect(x, y, m.TW, m.TH, bg))
        if it.value <> invalid and it.value <> "" then
            m.panel.appendChild(mkLabel(x + 24, y, m.TW - 170, m.TH, it.label, 32, true, tc))
            vl = mkLabel(x + m.TW - 140, y, 116, m.TH, it.value, 30, true, vc)
            vl.horizAlign = "right"
            m.panel.appendChild(vl)
        else
            m.panel.appendChild(mkLabel(x + 24, y, m.TW - 48, m.TH, it.label, 32, true, tc))
        end if
    end for

    m.panel.appendChild(mkLabel(40, h - 58, w - 80, 40, "Arrows  Move      OK  Select      Back  Close", 26, false, "0xC5D3EFFF"))
end sub

sub moveSel(dc as Integer, dr as Integer)
    items = m.top.items
    n = items.Count()
    rows = Int((n + m.COLS - 1) / m.COLS)
    col = m.sel mod m.COLS
    row = Int(m.sel / m.COLS)
    col = (col + dc + m.COLS) mod m.COLS
    row = (row + dr + rows) mod rows
    i = row * m.COLS + col
    if i > n - 1 then
        if dc <> 0 then i = row * m.COLS else i = n - 1
    end if
    m.sel = i
    render()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.top.visible then return false
    if key = "left" then
        moveSel(-1, 0)
    else if key = "right" then
        moveSel(1, 0)
    else if key = "up" then
        moveSel(0, -1)
    else if key = "down" then
        moveSel(0, 1)
    else if key = "OK" then
        m.top.selected = m.top.items[m.sel].id
    else if key = "back" or key = "options" then
        m.top.closeRequest = true
    else
        return false
    end if
    return true
end function
