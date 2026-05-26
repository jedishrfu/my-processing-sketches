-- Codea sketch: 12x12 grid with row/column highlight + on-screen formula buttons
-- - Labels outside the grid
-- - Hover (drag) to preview row/col
-- - Tap to lock: tapped cell = light green, same row/col = mellow yellow
-- - Auto-scales cell size to fit screen
-- - Buttons [1..5] switch formulas
-- NOTE: Make sure to paste this whole file so functions like inGrid() exist.

-- Grid & UI settings
local rows, cols = 12, 12
local margin = 50
local gap = 4
local cell = 50      -- will be auto-scaled in setup()

-- State
local formulaId = 2
local lockHighlight = false
local lockedI, lockedJ = -1, -1
local hoverI,  hoverJ  = -1, -1

-- Buttons
local buttons = {}
local btnW, btnH = 56, 32
local btnPad = 10

----------------------------------------------------------------
-- Helpers (define before use to avoid nil references)
----------------------------------------------------------------
local function inGrid(i, j)
    return i >= 0 and i < rows and j >= 0 and j < cols
end

local function ijFromPoint(x, y)
    local gx = x - margin
    local gy = y - margin
    if gx >= 0 and gy >= 0 and gx < cols*cell and gy < rows*cell then
        local j = math.floor(gx / cell)
        local i = math.floor(gy / cell)
        return i, j
    end
    return -1, -1
end

local function gcd(a, b)
    a = math.abs(a); b = math.abs(b)
    while b ~= 0 do
        a, b = b, a % b
    end
    return a
end

local function f(i, j)
    if     formulaId == 1 then return i + j
    elseif formulaId == 2 then return i * j
    elseif formulaId == 3 then return i - j
    elseif formulaId == 4 then return gcd(i, j)
    elseif formulaId == 5 then return (i*i + j*j) % 10
    else return 0 end
end

local function formulaName(id)
    if     id == 1 then return "f(i,j) = i + j"
    elseif id == 2 then return "f(i,j) = i * j"
    elseif id == 3 then return "f(i,j) = i - j"
    elseif id == 4 then return "f(i,j) = gcd(i, j)"
    elseif id == 5 then return "f(i,j) = (i^2 + j^2) mod 10"
    else return "" end
end

local function autoScaleCell()
    -- Space for labels + legend + buttons
    local usableW = WIDTH  - margin*2
    local usableH = HEIGHT - margin*3 - 100
    local cellW = usableW / cols
    local cellH = usableH / rows
    cell = math.floor(math.min(cellW, cellH))
end

local function setupButtons()
    local gridW = cols * cell
    local totalW = 5*btnW + 4*btnPad
    local startX = margin + (gridW - totalW)/2
    local baseY  = margin + rows*cell + 70
    buttons = {}
    for k = 1, 5 do
        local x = startX + (k-1)*(btnW + btnPad)
        local y = baseY
        table.insert(buttons, {id=k, x=x, y=y, w=btnW, h=btnH, label=tostring(k)})
    end
end

local function hitButton(x, y)
    for _, b in ipairs(buttons) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return b.id
        end
    end
    return nil
end

local function drawIndexLabels()
    fill(80)
    -- column labels below grid
    for j = 0, cols-1 do
        local x = margin + j*cell + cell/2
        local y = margin + rows*cell + 12
        text(j, x, y)
    end
    -- row labels left of grid
    for i = 0, rows-1 do
        local x = margin - 12
        local y = margin + i*cell + cell/2
        text(i, x, y)
    end
end

local function drawButtons()
    for _, b in ipairs(buttons) do
        if b.id == formulaId then fill(210) else fill(235) end
        stroke(120)
        rect(b.x, b.y, b.w, b.h, 6)
        fill(30)
        noStroke()
        text(b.label, b.x + b.w/2, b.y + b.h/2)
    end
end

----------------------------------------------------------------
-- Codea callbacks
----------------------------------------------------------------
function setup()
    font("Courier")
    textMode(CENTER)
    strokeWidth(1)
    autoScaleCell()
    setupButtons()
end

function draw()
    background(250)

    -- Hover underlay (only when not locked)
    if not lockHighlight and inGrid(hoverI, hoverJ) then
        noStroke()
        fill(220,235,255,140)
        rect(margin, margin + hoverI*cell, cols*cell, cell)
        rect(margin + hoverJ*cell, margin, cell, rows*cell)
    end

    -- Cells
    for i = 0, rows-1 do
        for j = 0, cols-1 do
            local x = margin + j*cell
            local y = margin + i*cell

            -- Background color
            if lockHighlight then
                if i == lockedI and j == lockedJ then
                    fill(204,255,204)         -- light green
                elseif i == lockedI or j == lockedJ then
                    fill(255,248,210)         -- mellow yellow
                else
                    fill(255)
                end
            else
                fill(255)
            end

            -- Filled tile
            noStroke()
            rect(x + gap/2, y + gap/2, cell - gap, cell - gap)

            -- Border on top (crisp)
            stroke(40)
            strokeWidth(1)
            noFill()
            rect(x + gap/2, y + gap/2, cell - gap, cell - gap)
            noStroke()

            -- Value text
            fill(20)
            text(f(i, j), x + cell/2, y + cell/2)
        end
    end

    -- Emphasize locked cell
    if lockHighlight and inGrid(lockedI, lockedJ) then
        local lx = margin + lockedJ*cell
        local ly = margin + lockedI*cell
        noFill()
        stroke(0)
        strokeWidth(2)
        rect(lx + gap/2, ly + gap/2, cell - gap, cell - gap)
        strokeWidth(1)
        noStroke()
    end

    -- Labels outside + legend
    drawIndexLabels()
    fill(20)
    textMode(CORNER)
    local status = lockHighlight
        and string.format("Locked on (%d,%d). Tap same cell to unlock.", lockedI, lockedJ)
        or "Drag to preview. Tap a cell to lock."
    local legend = string.format("Formula %d: %s    %s",
        formulaId, formulaName(formulaId), status)
    text(legend, margin, margin + rows*cell + 24)
    textMode(CENTER)

    -- Buttons
    drawButtons()
end

function touched(t)
    if t.state == MOVING then
        if not lockHighlight then
            hoverI, hoverJ = ijFromPoint(t.x, t.y)
        end
    elseif t.state == BEGAN then
        local bid = hitButton(t.x, t.y)
        if bid then
            formulaId = bid
            return
        end
        local hi, hj = ijFromPoint(t.x, t.y)
        if inGrid(hi, hj) then
            if lockHighlight and hi == lockedI and hj == lockedJ then
                lockHighlight = false
                lockedI, lockedJ = -1, -1
            else
                lockHighlight = true
                lockedI, lockedJ = hi, hj
            end
        end
    elseif t.state == ENDED or t.state == CANCELLED then
        if not lockHighlight then
            hoverI, hoverJ = -1, -1
        end
    end
end