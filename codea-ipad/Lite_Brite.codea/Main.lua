-- Lite-Brite Honeycomb (Codea) — FULL SKETCH (NO displayMode calls)
-- Updated Save/Load dialogs + scroll list + textbox focus + drag paint
--
-- Note: Codea chrome (expand arrows) cannot be removed if displayMode() isn't available.

----------------------------------------
-- Constants / Codes
----------------------------------------
local CODE_HOLE  = -1
local CODE_BLACK = -2
local CODE_WHITE = -3

local CODE_GRAY_0 = -10
local CODE_GRAY_1 = -11
local CODE_GRAY_2 = -12
local CODE_GRAY_3 = -13
local CODE_GRAY_4 = -14

local MULTI_CLICK_MS = 650
local ANIM_FPS = 8
local ANIM_INTERVAL = 1.0 / ANIM_FPS

-- Size modes
local SIZE_SMALL  = 0
local SIZE_MEDIUM = 1
local SIZE_LARGE  = 2

----------------------------------------
-- Geometry (match Processing-like defaults)
----------------------------------------
local MED_R,    MED_SP    = 12, 6
local SMALL_R,  SMALL_SP  = 6,  3
local LARGE_R,  LARGE_SP  = 24, 12

-- Base lattice = small pitch/vstep
local basePitch, baseVStep

-- Current view
local sizeMode = SIZE_MEDIUM
local viewStep = 2
local r = MED_R

----------------------------------------
-- State
----------------------------------------
-- master map: packed(q,rr) -> code
local colorByKey = {}
-- events: { key="q,rr", c=code }
local events = {}

-- animation
local animPlaying = false
local animIndex = 1
local animAccum = 0

-- visible pegs for view: {x,y,q,rr}
local viewPegs = {}

-- brush selection
local currentBrush = CODE_BLACK

-- multi-click tracking
local lastClickedKey = nil
local lastClickTimeMs = -1e9

-- drag tracking (avoid repainting same peg repeatedly)
local lastDragKey = nil

-- UI layout
local uiHidden = false
local panelH = 116
local hiddenHintUntil = -1e9

-- palette layout
local paletteXPad = 16
local palettePad = 6

-- Buttons
local buttons = {}

----------------------------------------
-- Save system (ProjectData keys)
----------------------------------------
local META_KEY = "litebrite_saves_meta_v2" -- JSON list of names
local function keyCells(name)  return "lb_cells_"  .. name end
local function keyEvents(name) return "lb_events_" .. name end
local function keyMode(name)   return "lb_mode_"   .. name end

----------------------------------------
-- Dialog (popup) state
----------------------------------------
local popup = {
    open = false,
    mode = nil,           -- "save" or "load"
    name = "pattern1",
    msg = "",

    -- list selection
    selectedIndex = 0,    -- 1..N
    scrollY = 0,          -- pixels
    draggingList = false,
    dragStartY = 0,
    scrollStartY = 0,

    -- textbox focus
    textFocused = false,
    cursorOn = true,
    cursorBlinkT = 0
}

local savedNames = {}

----------------------------------------
-- Utilities
----------------------------------------
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end
local function insideRect(px,py,x,y,w,h) return px>=x and px<=x+w and py>=y and py<=y+h end

local function packKey(q, rr) return tostring(q) .. "," .. tostring(rr) end
local function unpackKey(key)
    local a,b = key:match("^(-?%d+),(-?%d+)$")
    return tonumber(a), tonumber(b)
end

local function getColor(q, rr)
    local v = colorByKey[packKey(q, rr)]
    if v == nil then return CODE_HOLE end
    return v
end

local function setColor(q, rr, code)
    colorByKey[packKey(q, rr)] = code
end

local function recordEvent(q, rr, code)
    events[#events+1] = { key = packKey(q, rr), c = code }
end

----------------------------------------
-- Color palette (24 hues red -> violet)
----------------------------------------
local function hsvToRgb(h, s, v)
    local c = v*s
    local hh = (h % 360) / 60
    local x = c * (1 - math.abs((hh % 2) - 1))
    local r1,g1,b1 = 0,0,0
    if hh < 1 then r1,g1,b1 = c,x,0
    elseif hh < 2 then r1,g1,b1 = x,c,0
    elseif hh < 3 then r1,g1,b1 = 0,c,x
    elseif hh < 4 then r1,g1,b1 = 0,x,c
    elseif hh < 5 then r1,g1,b1 = x,0,c
    else r1,g1,b1 = c,0,x end
    local m = v - c
    return (r1+m), (g1+m), (b1+m)
end

local huePalette = {}
local function buildHuePalette()
    huePalette = {}
    for i=0,23 do
        local h = 270.0 * (i/23.0)
        local rr,gg,bb = hsvToRgb(h, 1.0, 1.0)
        huePalette[#huePalette+1] = color(rr*255, gg*255, bb*255, 255)
    end
end

local function codeToColor(code)
    if code == CODE_BLACK then return color(0,0,0,255) end
    if code == CODE_WHITE then return color(255,255,255,255) end
    if code <= CODE_GRAY_0 and code >= CODE_GRAY_4 then
        local idx = -(code + 10) -- -10->0 ... -14->4
        local b = (18 + (85-18)*(idx/4.0)) / 100.0
        local c = math.floor(b*255)
        return color(c,c,c,255)
    end
    if code >= 0 and code < 24 then return huePalette[code+1] end
    return color(0,0,0,255)
end

----------------------------------------
-- Cycling order for multi-click on same peg
----------------------------------------
local function cycleNext(cur)
    if cur == CODE_HOLE then return CODE_BLACK end
    if cur == CODE_BLACK then return CODE_GRAY_0 end
    if cur == CODE_GRAY_0 then return CODE_GRAY_1 end
    if cur == CODE_GRAY_1 then return CODE_GRAY_2 end
    if cur == CODE_GRAY_2 then return CODE_GRAY_3 end
    if cur == CODE_GRAY_3 then return CODE_GRAY_4 end
    if cur == CODE_GRAY_4 then return CODE_WHITE end
    if cur == CODE_WHITE then return 0 end
    if cur >= 0 and cur < 23 then return cur+1 end
    if cur == 23 then return CODE_HOLE end
    return CODE_HOLE
end

----------------------------------------
-- Nested lattice view (axial q,rr)
----------------------------------------
local function rebuildViewPegs()
    viewPegs = {}

    -- axial -> pixel in base lattice:
    -- x = basePitch * (q + rr/2)
    -- y = baseVStep  * rr
    local rrMin = math.floor(0 / baseVStep) - 2
    local rrMax = math.ceil(HEIGHT / baseVStep) + 2

    for rr=rrMin, rrMax do
        if (rr % viewStep) == 0 then
            local rrHalf = rr/2.0
            local qMin = math.floor(0 / basePitch - rrHalf) - 10
            local qMax = math.ceil(WIDTH / basePitch - rrHalf) + 10

            for q=qMin, qMax do
                if (q % viewStep) == 0 then
                    local x = basePitch * (q + rrHalf)
                    local y = baseVStep  * rr
                    if x >= r and x <= (WIDTH-r) and y >= r and y <= (HEIGHT-r) then
                        viewPegs[#viewPegs+1] = { x=x, y=y, q=q, rr=rr }
                    end
                end
            end
        end
    end
end

local function setSizeMode(mode)
    sizeMode = mode
    if mode == SIZE_SMALL then
        viewStep = 1
        r = SMALL_R
    elseif mode == SIZE_MEDIUM then
        viewStep = 2
        r = MED_R
    else
        viewStep = 4
        r = LARGE_R
    end
    rebuildViewPegs()
end

----------------------------------------
-- Peg hit tests
----------------------------------------
local function hitPeg(px,py)
    if (not uiHidden) and py <= panelH then
        return nil
    end
    local best, bestD2 = nil, 1e18
    for _,p in ipairs(viewPegs) do
        local dx, dy = px-p.x, py-p.y
        local d2 = dx*dx + dy*dy
        if d2 <= r*r and d2 < bestD2 then
            bestD2 = d2
            best = p
        end
    end
    return best
end

local function nearestPeg(px,py)
    local best, bestD2 = nil, 1e18
    for _,p in ipairs(viewPegs) do
        local dx, dy = px-p.x, py-p.y
        local d2 = dx*dx + dy*dy
        if d2 < bestD2 then
            bestD2 = d2
            best = p
        end
    end
    return best, bestD2
end

local function bottomRightPeg()
    local best = nil
    local bestY, bestX = -1e18, -1e18
    for _,p in ipairs(viewPegs) do
        if p.y > bestY + 1e-6 then
            bestY = p.y; bestX = p.x; best = p
        elseif math.abs(p.y - bestY) < 1e-6 and p.x > bestX then
            bestX = p.x; best = p
        end
    end
    return best
end

----------------------------------------
-- Drawing pegs
----------------------------------------
local function drawPeg(p)
    local code = getColor(p.q, p.rr)

    if code == CODE_HOLE then
        noFill()
        stroke(140,140,140,180)
        strokeWidth(2)
        ellipse(p.x, p.y, r*2)
        return
    end

    local c = codeToColor(code)

    -- halo
    noStroke()
    if code == CODE_BLACK then
        fill(0,0,0,70)
    elseif code == CODE_WHITE then
        fill(255,255,255,50)
    elseif code <= CODE_GRAY_0 and code >= CODE_GRAY_4 then
        fill(160,160,160,50)
    else
        fill(c.r, c.g, c.b, 80)
    end
    ellipse(p.x, p.y, r*3.2)

    -- face
    fill(c)
    ellipse(p.x, p.y, r*2)
end

local function drawBoard()
    background(0,0,0,255)
    for _,p in ipairs(viewPegs) do
        drawPeg(p)
    end
end

----------------------------------------
-- Palette row (HOLE, BLACK, WHITE, 24 hues)
----------------------------------------
local function paletteCount() return 3 + 24 end

local function drawPaletteRow()
    local n = paletteCount()
    local availW = WIDTH - 2*paletteXPad
    local sw = math.floor((availW - (n-1)*palettePad) / n)
    sw = clamp(sw, 12, 28)
    local totalW = n*sw + (n-1)*palettePad
    local x0 = paletteXPad + (availW - totalW)/2
    local y0 = 54

    for i=0,n-1 do
        local x = x0 + i*(sw+palettePad)
        local code
        if i==0 then code = CODE_HOLE
        elseif i==1 then code = CODE_BLACK
        elseif i==2 then code = CODE_WHITE
        else code = i-3 end

        if code == CODE_HOLE then
            fill(0,0,0,255)
            stroke(140,140,140,200)
            strokeWidth(2)
            rect(x,y0,sw,sw,6)
            noFill()
            ellipse(x+sw/2, y0+sw/2, sw*0.55)
        else
            noStroke()
            fill(codeToColor(code))
            rect(x,y0,sw,sw,6)
            stroke(110,110,110,255)
            strokeWidth(1)
            noFill()
            rect(x,y0,sw,sw,6)
        end

        if currentBrush == code then
            stroke(255,255,255,255)
            strokeWidth(2)
            noFill()
            rect(x-2,y0-2,sw+4,sw+4,7)
        end
    end
end

local function paletteHit(px,py)
    local n = paletteCount()
    local availW = WIDTH - 2*paletteXPad
    local sw = math.floor((availW - (n-1)*palettePad) / n)
    sw = clamp(sw, 12, 28)
    local totalW = n*sw + (n-1)*palettePad
    local x0 = paletteXPad + (availW - totalW)/2
    local y0 = 54

    if py < y0 or py > y0 + sw then return nil end
    for i=0,n-1 do
        local x = x0 + i*(sw+palettePad)
        if px >= x and px <= x+sw then
            if i==0 then return CODE_HOLE end
            if i==1 then return CODE_BLACK end
            if i==2 then return CODE_WHITE end
            return (i-3)
        end
    end
    return nil
end

----------------------------------------
-- Buttons
----------------------------------------
local function addButton(id, label, x, y, w, h)
    buttons[id] = { id=id, label=label, x=x, y=y, w=w, h=h, active=false }
end

local function layoutButtons()
    buttons = {}
    local x = 16
    local y = panelH - 38
    local gap = 6

    local function b(id,label,w)
        addButton(id,label,x,y,w,28)
        x = x + w + gap
    end

    b("new","New",70)
    b("load","Load",70)
    b("anim","Animate",90)
    b("save","Save",70)
    b("hide","Hide UI",90)
    b("small","Small",80)
    b("med","Medium",80)
    b("large","Large",80)
end

local function refreshSizeButtons()
    if buttons.small then buttons.small.active = (sizeMode == SIZE_SMALL) end
    if buttons.med then buttons.med.active = (sizeMode == SIZE_MEDIUM) end
    if buttons.large then buttons.large.active = (sizeMode == SIZE_LARGE) end
end

local function drawButton(b)
    local fillCol = b.active and color(70,70,70,255) or color(35,35,35,255)
    fill(fillCol) stroke(120,120,120,255) strokeWidth(2)
    rect(b.x, b.y, b.w, b.h, 10)
    fill(240,240,240,255) noStroke()
    fontSize(16)
    textMode(CENTER)
    text(b.label, b.x + b.w/2, b.y + b.h/2)
end

local function drawBottomPanel()
    if uiHidden then return end
    noStroke()
    fill(12,12,12,255)
    rect(0, 0, WIDTH, panelH)
    stroke(60,60,60,255)
    strokeWidth(2)
    line(0, panelH, WIDTH, panelH)
    noStroke()
    for _,b in pairs(buttons) do drawButton(b) end
    drawPaletteRow()
end

----------------------------------------
-- Hidden hint
----------------------------------------
local function drawHiddenHint()
    if not uiHidden then return end
    if ElapsedTime > hiddenHintUntil then return end
    fill(0,0,0,180); noStroke()
    rect(12, HEIGHT-46, 470, 34, 10)
    fill(255,255,255,255)
    fontSize(16)
    textMode(CORNER)
    text("UI hidden — tap bottom-right corner to show UI", 22, HEIGHT-38)
end

----------------------------------------
-- Save list persistence
----------------------------------------
local function loadSavedNames()
    local meta = readProjectData(META_KEY)
    if not meta then savedNames = {}; return end
    local ok, decoded = pcall(function() return json.decode(meta) end)
    savedNames = (ok and type(decoded)=="table") and decoded or {}
end

local function saveSavedNames()
    saveProjectData(META_KEY, json.encode(savedNames))
end

local function ensureNameInMeta(name)
    for _,n in ipairs(savedNames) do if n==name then return end end
    savedNames[#savedNames+1] = name
    table.sort(savedNames)
    saveSavedNames()
end

----------------------------------------
-- Dialog layout
----------------------------------------
local function popupRect()
    local w, h = math.min(640, WIDTH - 60), math.min(520, HEIGHT - 120)
    local x = (WIDTH - w)/2
    local y = (HEIGHT - h)/2
    return x,y,w,h
end

local function popupListRect(x,y,w,h)
    local pad = 16
    local titleH = 36
    local listH = math.floor(h * 0.52)
    local lx = x + pad
    local ly = y + h - titleH - pad - listH
    local lw = w - 2*pad
    local lh = listH
    return lx,ly,lw,lh
end

local function popupTextRect(x,y,w,h)
    local pad = 16
    local titleH = 36
    local listH = math.floor(h * 0.52)
    local gap = 14
    local tbH = 40
    local tx = x + pad
    local ty = (y + h - titleH - pad - listH) - gap - tbH
    local tw = w - 2*pad
    local th = tbH
    return tx,ty,tw,th
end

local function popupButtonsRect(x,y,w,h)
    local pad = 16
    local btnH = 40
    local by = y + pad
    local bw = w - 2*pad
    return x+pad, by, bw, btnH
end

----------------------------------------
-- Dialog open/close
----------------------------------------
local function popupOpen(mode)
    popup.open = true
    popup.mode = mode
    popup.msg = ""
    popup.textFocused = false
    popup.cursorBlinkT = 0
    popup.cursorOn = true
    popup.draggingList = false

    loadSavedNames()
    if #savedNames > 0 then
        popup.selectedIndex = 1
        popup.name = savedNames[1]
    else
        popup.selectedIndex = 0
        popup.name = "pattern1"
    end
    popup.scrollY = 0
end

local function popupClose()
    popup.open = false
    popup.mode = nil
    popup.textFocused = false
    hideKeyboard()
end

----------------------------------------
-- Dialog drawing (list scroll + clear highlight)
----------------------------------------
local function drawPopup()
    if not popup.open then return end

    local x,y,w,h = popupRect()

    fill(25,25,25,240)
    stroke(160,160,160,255)
    strokeWidth(2)
    rect(x,y,w,h,16)

    noStroke()
    fill(255,255,255,255)
    fontSize(22)
    textMode(CORNER)
    local title = (popup.mode=="save") and "Save Pattern" or "Load Pattern"
    text(title, x+16, y+h-30)

    if popup.msg ~= "" then
        fill(255,200,120,255)
        fontSize(14)
        text(popup.msg, x+16, y+h-54)
    end

    -- list
    local lx,ly,lw,lh = popupListRect(x,y,w,h)
    fill(16,16,16,255)
    stroke(90,90,90,255)
    strokeWidth(2)
    rect(lx,ly,lw,lh,12)

    noStroke()
    fill(190,190,190,255)
    fontSize(14)
    textMode(CORNER)
    text("Patterns", lx+12, ly+lh-26)

    local topPad = 34
    local rowH = 26
    local contentH = math.max(0, #savedNames * rowH)
    local viewH = lh - topPad - 10
    local maxScroll = math.max(0, contentH - viewH)
    popup.scrollY = clamp(popup.scrollY, 0, maxScroll)

    clip(lx+6, ly+8, lw-12, lh-16)

    local contentTop = (ly + lh - topPad) + popup.scrollY
    for i=1,#savedNames do
        local ry = contentTop - i*rowH
        if ry < ly - rowH then break end
        if ry > ly + lh then goto continue end

        local name = savedNames[i]
        local isSel = (i == popup.selectedIndex)

        if isSel then
            fill(90,90,90,255)
            rect(lx+10, ry+2, lw-20, rowH-2, 8)
            fill(255,255,255,255)
        else
            fill(220,220,220,255)
        end

        fontSize(16)
        textMode(CORNER)
        text(name, lx+18, ry+6)
        ::continue::
    end

    clip()

    -- scrollbar
    if maxScroll > 0 then
        local barW = 6
        local trackX = lx + lw - 12
        local trackY = ly + 10
        local trackH = lh - 20
        fill(60,60,60,180); noStroke()
        rect(trackX, trackY, barW, trackH, 3)

        local knobH = math.max(18, trackH * (viewH / contentH))
        local t = popup.scrollY / maxScroll
        local knobY = trackY + (trackH - knobH) * (1.0 - t)
        fill(140,140,140,220)
        rect(trackX, knobY, barW, knobH, 3)
    end

    -- textbox
    local tx,ty,tw,th = popupTextRect(x,y,w,h)
    fill(40,40,40,255)
    stroke(popup.textFocused and color(230,230,230,255) or color(110,110,110,255))
    strokeWidth(2)
    rect(tx,ty,tw,th,10)

    noStroke()
    fill(240,240,240,255)
    fontSize(18)
    textMode(CORNER)

    local shown = popup.name
    if popup.textFocused then
        if ElapsedTime - popup.cursorBlinkT > 0.5 then
            popup.cursorBlinkT = ElapsedTime
            popup.cursorOn = not popup.cursorOn
        end
        if popup.cursorOn then shown = shown .. "|" end
    end
    text(shown, tx+12, ty+10)

    -- buttons
    local bx,by,bw,bh = popupButtonsRect(x,y,w,h)
    local gap = 10

    local function drawBtn(label, px, py, w, h)
        fill(50,50,50,255)
        stroke(180,180,180,255)
        strokeWidth(2)
        rect(px,py,w,h,12)
        noStroke()
        fill(245,245,245,255)
        fontSize(18)
        textMode(CENTER)
        text(label, px+w/2, py+h/2)
    end

    if popup.mode == "load" then
        local btnW = (bw - gap) / 2
        drawBtn("Load JSON", bx, by, btnW, bh)
        drawBtn("Cancel",   bx + btnW + gap, by, btnW, bh)
    else
        local btnW = (bw - 2*gap) / 3
        drawBtn("Save JSON",  bx, by, btnW, bh)
        drawBtn("Export PNG", bx + btnW + gap, by, btnW, bh)
        drawBtn("Cancel",     bx + 2*(btnW + gap), by, btnW, bh)
    end
end

----------------------------------------
-- Dialog interaction
----------------------------------------
local function popupHitBegan(px,py)
    if not popup.open then return false end

    local x,y,w,h = popupRect()
    if not insideRect(px,py,x,y,w,h) then
        popupClose()
        return true
    end

    local lx,ly,lw,lh = popupListRect(x,y,w,h)
    local tx,ty,tw,th = popupTextRect(x,y,w,h)
    local bx,by,bw,bh = popupButtonsRect(x,y,w,h)

    -- textbox focus
    if insideRect(px,py,tx,ty,tw,th) then
        popup.textFocused = true
        popup.cursorOn = true
        popup.cursorBlinkT = ElapsedTime
        showKeyboard()
        return true
    end

    -- list: start drag + allow tap select on ENDED (if small drag)
    if insideRect(px,py,lx,ly,lw,lh) then
        popup.textFocused = false
        hideKeyboard()
        popup.draggingList = true
        popup.dragStartY = py
        popup.scrollStartY = popup.scrollY
        return true
    end

    -- buttons
    if insideRect(px,py,bx,by,bw,bh) then
        popup.textFocused = false
        hideKeyboard()

        local gap = 10
        if popup.mode == "load" then
            local btnW = (bw - gap)/2
            local loadX = bx
            local cancelX = bx + btnW + gap

            if insideRect(px,py,loadX,by,btnW,bh) then
                local name = popup.name
                if name == "" then popup.msg="Name required"; return true end
                local cellsStr = readProjectData(keyCells(name))
                if not cellsStr then popup.msg="No JSON for: "..name; return true end
                local evsStr = readProjectData(keyEvents(name))
                local mode = readProjectData(keyMode(name)) or SIZE_MEDIUM

                -- reset state
                colorByKey = {}
                events = {}
                animPlaying = false
                animIndex = 1
                animAccum = 0
                lastClickedKey = nil
                lastClickTimeMs = -1e9
                lastDragKey = nil

                setSizeMode(mode)
                refreshSizeButtons()

                local ok1, cells = pcall(function() return json.decode(cellsStr) end)
                cells = (ok1 and type(cells)=="table") and cells or {}
                for _,o in ipairs(cells) do
                    setColor(o.q, o.r, o.c)
                end

                if evsStr then
                    local ok2, evs = pcall(function() return json.decode(evsStr) end)
                    evs = (ok2 and type(evs)=="table") and evs or {}
                    for _,o in ipairs(evs) do
                        events[#events+1] = { key = packKey(o.q,o.r), c = o.c }
                    end
                end

                popupClose()
                return true
            end

            if insideRect(px,py,cancelX,by,btnW,bh) then
                popupClose()
                return true
            end
        else
            local btnW = (bw - 2*gap)/3
            local saveX = bx
            local pngX  = bx + btnW + gap
            local cancelX = bx + 2*(btnW + gap)

            if insideRect(px,py,saveX,by,btnW,bh) then
                local name = popup.name
                if name == "" then popup.msg="Name required"; return true end
                ensureNameInMeta(name)

                local cells = {}
                for k,v in pairs(colorByKey) do
                    local q, rr = unpackKey(k)
                    cells[#cells+1] = { q=q, r=rr, c=v }
                end
                local evs = {}
                for i,e in ipairs(events) do
                    local q, rr = unpackKey(e.key)
                    evs[#evs+1] = { q=q, r=rr, c=e.c }
                end

                saveProjectData(keyCells(name),  json.encode(cells))
                saveProjectData(keyEvents(name), json.encode(evs))
                saveProjectData(keyMode(name),   sizeMode)

                popup.msg = "Saved JSON: " .. name
                loadSavedNames()
                for i,nm in ipairs(savedNames) do
                    if nm == name then popup.selectedIndex = i; break end
                end
                return true
            end

            if insideRect(px,py,pngX,by,btnW,bh) then
                local name = popup.name
                if name == "" then popup.msg="Name required"; return true end
                ensureNameInMeta(name)

                local img = image(WIDTH, HEIGHT)
                setContext(img)
                pushStyle()
                background(0,0,0,255)
                for _,p in ipairs(viewPegs) do drawPeg(p) end
                popStyle()
                setContext()
                saveImage("Documents:"..name..".png", img)

                popup.msg = "Exported PNG: Documents:"..name..".png"
                return true
            end

            if insideRect(px,py,cancelX,by,btnW,bh) then
                popupClose()
                return true
            end
        end
        return true
    end

    -- unfocus
    popup.textFocused = false
    hideKeyboard()
    return true
end

local function popupHitMoving(px,py)
    if not popup.open then return false end
    if not popup.draggingList then return false end

    local x,y,w,h = popupRect()
    local lx,ly,lw,lh = popupListRect(x,y,w,h)

    local dy = py - popup.dragStartY
    popup.scrollY = popup.scrollStartY + dy

    local rowH = 26
    local topPad = 34
    local contentH = math.max(0, #savedNames * rowH)
    local viewH = lh - topPad - 10
    local maxScroll = math.max(0, contentH - viewH)
    popup.scrollY = clamp(popup.scrollY, 0, maxScroll)

    return true
end

local function popupHitEnded(px,py)
    if not popup.open then return false end

    local wasDragging = popup.draggingList
    popup.draggingList = false

    local x,y,w,h = popupRect()
    local lx,ly,lw,lh = popupListRect(x,y,w,h)

    if insideRect(px,py,lx,ly,lw,lh) then
        local dragDist = math.abs(py - popup.dragStartY)
        if dragDist < 10 then
            local topPad = 34
            local rowH = 26

            local contentTop = (ly + lh - topPad) + popup.scrollY
            local idx = math.floor((contentTop - py) / rowH) + 1
            if idx >= 1 and idx <= #savedNames then
                popup.selectedIndex = idx
                popup.name = savedNames[idx]
                popup.msg = ""
            end
        end
        return true
    end

    return wasDragging
end

----------------------------------------
-- Two-finger erase
----------------------------------------
local function isTwoFinger()
    if CurrentTouchCount ~= nil then
        return CurrentTouchCount >= 2
    end
    return false
end

----------------------------------------
-- Animation
----------------------------------------
local function toggleAnimation()
    if animPlaying then
        animPlaying = false
        return
    end
    animPlaying = true
    animIndex = 1
    animAccum = 0
    colorByKey = {}
    lastClickedKey = nil
    lastClickTimeMs = -1e9
    lastDragKey = nil
end

local function stepAnimation(dt)
    if not animPlaying then return end
    animAccum = animAccum + dt
    while animAccum >= ANIM_INTERVAL do
        animAccum = animAccum - ANIM_INTERVAL
        if animIndex > #events then
            animPlaying = false
            break
        end
        local e = events[animIndex]
        animIndex = animIndex + 1
        local q, rr = unpackKey(e.key)
        setColor(q, rr, e.c)
    end
end

----------------------------------------
-- Paint/cycle on peg
----------------------------------------
local function applyPeg(p, erase, allowCycle)
    local k = packKey(p.q, p.rr)
    local cur = getColor(p.q, p.rr)
    local nowMs = ElapsedTime * 1000.0

    local doCycle = false
    if allowCycle and (not erase) then
        doCycle = (lastClickedKey == k) and ((nowMs - lastClickTimeMs) <= MULTI_CLICK_MS)
    end

    local newCode
    if erase then
        newCode = CODE_HOLE
    else
        if doCycle then
            newCode = cycleNext(cur)
            currentBrush = newCode
        else
            newCode = currentBrush
        end
    end

    if cur ~= newCode then
        setColor(p.q, p.rr, newCode)
        recordEvent(p.q, p.rr, newCode)
    end

    lastClickedKey = k
    lastClickTimeMs = nowMs
end

----------------------------------------
-- Button handling
----------------------------------------
local function handleButtons(px,py)
    for id,b in pairs(buttons) do
        if insideRect(px,py,b.x,b.y,b.w,b.h) then
            if id=="new" then
                colorByKey = {}
                events = {}
                animPlaying = false
                animIndex = 1
                animAccum = 0
                lastClickedKey=nil
                lastClickTimeMs=-1e9
                lastDragKey=nil
                popupClose()
                return true
            elseif id=="load" then
                popupOpen("load"); return true
            elseif id=="anim" then
                toggleAnimation(); return true
            elseif id=="save" then
                popupOpen("save"); return true
            elseif id=="hide" then
                uiHidden = true
                hiddenHintUntil = ElapsedTime + 5.0
                popupClose()
                return true
            elseif id=="small" then
                setSizeMode(SIZE_SMALL); refreshSizeButtons(); return true
            elseif id=="med" then
                setSizeMode(SIZE_MEDIUM); refreshSizeButtons(); return true
            elseif id=="large" then
                setSizeMode(SIZE_LARGE); refreshSizeButtons(); return true
            end
        end
    end
    return false
end

----------------------------------------
-- Codea entry points
----------------------------------------
function setup()
    buildHuePalette()

    basePitch = 2*SMALL_R + SMALL_SP
    baseVStep  = basePitch * math.sqrt(3) / 2.0

    setSizeMode(SIZE_MEDIUM)
    layoutButtons()
    refreshSizeButtons()

    for _,p in ipairs(viewPegs) do
        setColor(p.q, p.rr, CODE_HOLE)
    end

    loadSavedNames()
end

function draw()
    stepAnimation(DeltaTime)
    drawBoard()
    if not uiHidden then drawBottomPanel() end
    drawHiddenHint()
    drawPopup()
end

function keyboard(key)
    if not popup.open then return end
    if not popup.textFocused then return end

    if key == BACKSPACE then
        if #popup.name > 0 then popup.name = popup.name:sub(1,#popup.name-1) end
    elseif key == RETURN then
        popup.textFocused = false
        hideKeyboard()
    else
        if key:match("[%w _%-]") then
            popup.name = popup.name .. key
        end
    end
end

function touched(t)
    -- popup consumes touches first
    if popup.open then
        if t.state == BEGAN then
            if popupHitBegan(t.x,t.y) then return end
        elseif t.state == MOVING then
            if popupHitMoving(t.x,t.y) then return end
        elseif t.state == ENDED then
            if popupHitEnded(t.x,t.y) then return end
        end
    end

    -- restore UI when hidden: bottom-right corner hot-zone
    if uiHidden and t.state == BEGAN then
        local cornerW, cornerH = 140, 140
        local inCorner = (t.x >= WIDTH - cornerW) and (t.y <= cornerH)
        if inCorner then
            uiHidden = false
            hiddenHintUntil = -1e9
            lastDragKey = nil
            return
        end
        -- also allow near bottom-right peg
        local br = bottomRightPeg()
        local np, d2 = nearestPeg(t.x, t.y)
        local nearBR = (br and np and np.q==br.q and np.rr==br.rr and d2 <= (3.0*r)*(3.0*r))
        if nearBR then
            uiHidden = false
            hiddenHintUntil = -1e9
            lastDragKey = nil
            return
        end
    end

    -- UI interactions on BEGAN in panel
    if (not uiHidden) and t.state == BEGAN and t.y <= panelH then
        local code = paletteHit(t.x, t.y)
        if code ~= nil then
            currentBrush = code
            lastClickedKey=nil
            lastClickTimeMs=-1e9
            lastDragKey=nil
            return
        end
        if handleButtons(t.x, t.y) then
            lastDragKey=nil
            return
        end
        return
    end

    -- no painting during animation
    if animPlaying then return end

    -- paint on BEGAN and MOVING
    if t.state == BEGAN or t.state == MOVING then
        local p = hitPeg(t.x, t.y)
        if not p then return end

        local erase = isTwoFinger()
        local k = packKey(p.q, p.rr)

        if t.state == MOVING then
            if k == lastDragKey then return end
            lastDragKey = k

            -- drag paints only (no cycling)
            lastClickedKey = nil
            lastClickTimeMs = -1e9
            applyPeg(p, erase, false)
        else
            lastDragKey = nil
            applyPeg(p, erase, true)
        end
        return
    end

    if t.state == ENDED then
        lastDragKey = nil
    end
end