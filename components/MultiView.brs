' Multiview's labels over the tiled picture (see MultiView.xml). Redrawn whenever the scene sets cells.

sub init()
    m.layer = m.top.findNode("layer")
end sub

sub render()
    m.layer.removeChildrenIndex(m.layer.getChildCount(), 0)
    sf = m.top.safe
    if sf = invalid or sf.Count() <> 4 then sf = [0, 0, 0, 0]
    cells = m.top.cells
    if cells <> invalid then
        for each c in cells
            drawCell(c, sf)
        end for
    end if
    hint = m.top.hint
    if hint <> invalid and hint <> "" then
        lb = mkLabel(0, 0, 0, 52, hint, 26, false, "0xFFFFFFFF")
        w = Int(lb.boundingRect().width) + 60
        if w > 1920 - sf[0] - sf[2] then w = 1920 - sf[0] - sf[2]
        x = Int((1920 - w) / 2)
        m.layer.appendChild(mkRect(x, sf[1] + 10, w, 52, "0x000000C8"))
        lb.translation = [x + 30, sf[1] + 10]
        lb.width = w - 60
        lb.horizAlign = "center"
        m.layer.appendChild(lb)
    end if
end sub

sub drawCell(c as Object, sf as Object)
    x = c.x
    y = c.y
    w = c.w
    h = c.h
    ' text keeps clear of the screen's edges (overscan), the picture itself doesn't
    left = x
    if x <= 0 then left = sf[0]
    right = x + w
    if right >= 1920 then right = 1920 - sf[2]
    bottom = y + h
    if bottom >= 1080 then bottom = 1080 - sf[3]
    small = (h < 400)
    if c.kind = "add" then
        m.layer.appendChild(mkRect(x, y, w, h, "0x0B2A6AC0"))
        size = 64
        if small then size = 48
        plus = mkLabel(x, y + Int(h / 2) - 90, w, 80, "+", size, true, "0xFFC845FF")
        plus.horizAlign = "center"
        m.layer.appendChild(plus)
        txt = mkLabel(x, y + Int(h / 2) - 10, w, 44, "Add a channel", 30, true, "0xFFFFFFFF")
        txt.horizAlign = "center"
        m.layer.appendChild(txt)
        if c.room <> invalid and c.room <> "" then
            rm = mkLabel(left + 16, y + Int(h / 2) + 34, right - left - 32, 64, c.room, 22, false, "0xAFC8F5FF")
            rm.horizAlign = "center"
            rm.wrap = true
            m.layer.appendChild(rm)
        end if
    else
        if c.msg <> invalid and c.msg <> "" then
            m.layer.appendChild(mkRect(x, y, w, h, "0x141414FF"))
            ms = mkLabel(left + 20, y + Int(h / 2) - 40, right - left - 40, 80, c.msg, 34, true, "0xFFFFFFFF")
            ms.horizAlign = "center"
            ms.wrap = true
            m.layer.appendChild(ms)
        end if
        ' the channel and its show along the picture's foot, the sound picture marked
        barH = 56
        if small then barH = 46
        m.layer.appendChild(mkRect(x, bottom - barH, w, barH, "0x000000A8"))
        tx = left + 16
        if c.sound = true then
            chip = mkLabel(0, 0, 0, barH - 14, "SOUND", 20, true, "0x10244AFF")
            cw = Int(chip.boundingRect().width) + 20
            m.layer.appendChild(mkRect(tx, bottom - barH + 7, cw, barH - 14, "0xFFC845FF"))
            chip.translation = [tx + 10, bottom - barH + 7]
            m.layer.appendChild(chip)
            tx = tx + cw + 12
        end if
        txt = c.label
        if c.now <> invalid and c.now <> "" then txt = txt + "  " + Chr(183) + "  " + c.now
        size = 28
        if small then size = 22
        lb = mkLabel(tx, bottom - barH, right - tx - 12, barH, txt, size, true, "0xFFFFFFFF")
        m.layer.appendChild(lb)
    end if
    if c.focus = true then
        ' the highlight: a frame just inside the picture's edges
        b = 6
        col = "0xFFC845FF"
        m.layer.appendChild(mkRect(x, y, w, b, col))
        m.layer.appendChild(mkRect(x, y + h - b, w, b, col))
        m.layer.appendChild(mkRect(x, y, b, h, col))
        m.layer.appendChild(mkRect(x + w - b, y, b, h, col))
    end if
end sub
