-- Think-a-Dot (3-2-3) emulator for Codea (compatibility-first)
-- COMPLETE SKETCH (with routing FIX for Hole 3 so bottom-right toggles)
--
-- No displayMode(), no rectMode(), no strokeCapStyle()

local BLUE   = color( 60, 140, 255)
local YELLOW = color(255, 220,  70)
local REDB   = color(210,  30,  35)
local BG     = color(250, 250, 250)

local PATH   = color(200, 200, 200, 220)
local MARBLE_BLACK = color( 20,  20,  25, 255)
local MARBLE_GRAY  = color(140, 140, 145, 255)

-- state: 0=blue, 1=yellow
-- routing: BLUE -> Right, YELLOW -> Left
local BLUE_ROUTES_RIGHT = true

local TRAVEL_SPEED = 0.85
local DWELL_TIME   = 0.22

local board = {}
local nodes = {}
local marbles = {}

local A,B,C,D,E,F,G,H = "A","B","C","D","E","F","G","H"
local CORNERS = {A, C, F, H}

local whiteImg = nil

local function inRect(x,y, x1,y1,x2,y2)
    if x==nil or y==nil or x1==nil or y1==nil or x2==nil or y2==nil then return false end
    return x>=x1 and x<=x2 and y>=y1 and y<=y2
end

local function isCorner(id)
    for _,cid in ipairs(CORNERS) do
        if cid == id then return true end
    end
    return false
end

local function routeDir(state)
    if BLUE_ROUTES_RIGHT then
        return (state == 0) and "R" or "L"
    else
        return (state == 0) and "L" or "R"
    end
end

local function makeNode(id, pos)
    nodes[id] = {id=id, pos=pos, state=0, L=nil, R=nil}
end

local function makeExit(id, pos)
    nodes[id] = {id=id, pos=pos, isExit=true}
end

local function drawRectXYWH(x, y, w, h, col)
    pushStyle()
    tint(col)
    sprite(whiteImg, x, y, w, h)
    noTint()
    popStyle()
end

-- =======================
-- GEOMETRY
-- =======================
local function initGeometry()
    local w, h = WIDTH, HEIGHT
    
    board.border = math.max(28, math.min(w,h) * 0.05)
    board.left   = w * 0.08
    board.right  = w * 0.92
    board.bottom = h * 0.18
    board.top    = h * 0.86
    
    local bw = board.right - board.left
    local bh = board.top - board.bottom
    
    board.dotR = math.min(bw, bh) * 0.070
    
    local cx = (board.left + board.right) * 0.5
    local x1 = cx - bw * 0.22
    local x2 = cx
    local x3 = cx + bw * 0.22
    
    local y1 = board.top - bh * 0.24
    local y2 = board.top - bh * 0.52
    local y3 = board.top - bh * 0.80
    
    board.pos = {}
    board.pos[A] = vec2(x1, y1)
    board.pos[B] = vec2(x2, y1)
    board.pos[C] = vec2(x3, y1)
    
    board.pos[D] = vec2((x1+x2)/2, y2)
    board.pos[E] = vec2((x2+x3)/2, y2)
    
    board.pos[F] = vec2(x1, y3)
    board.pos[G] = vec2(x2, y3)
    board.pos[H] = vec2(x3, y3)
    
    -- DROP buttons embedded in the TOP red border
    board.entryR = board.dotR * 0.55
    board.entryY = board.top - board.border * 0.5
    
    board.entries = {
        {pos=vec2(x1, board.entryY), dropTo=A},
        {pos=vec2(x2, board.entryY), dropTo=B},
        {pos=vec2(x3, board.entryY), dropTo=C},
    }
    
    board.exitY = y3 - board.dotR * 2.0
    board.exits = {
        left  = vec2(x1, board.exitY),
        mid   = vec2(x2, board.exitY),
        right = vec2(x3, board.exitY),
    }
end

-- =======================
-- NETWORK (ROUTING)
-- =======================
local function initNetwork()
    nodes = {}
    
    makeNode(A, board.pos[A]); makeNode(B, board.pos[B]); makeNode(C, board.pos[C])
    makeNode(D, board.pos[D]); makeNode(E, board.pos[E])
    makeNode(F, board.pos[F]); makeNode(G, board.pos[G]); makeNode(H, board.pos[H])
    
    makeExit("Xl", board.exits.left)
    makeExit("Xm", board.exits.mid)
    makeExit("Xr", board.exits.right)
    
    -- Top row:
    -- A: yellow exits left, blue goes inward to D (with BLUE_ROUTES_RIGHT)
    nodes[A].L, nodes[A].R = F, D
    
    nodes[B].L, nodes[B].R = E, D   -- should be E,D
    
    nodes[C].L, nodes[C].R = E, H 
    
    -- Middle row:
    nodes[D].L, nodes[D].R = G, F    -- should be G, F
    
    nodes[E].L, nodes[E].R = H, G     -- should be H, G
    
    -- Bottom row:
    nodes[F].L, nodes[F].R = "Xl", "Xl"
    nodes[G].L, nodes[G].R = "Xr", "Xl" -- should be xr, xl
    nodes[H].L, nodes[H].R = "Xr", "Xr"
    
    marbles = {}
end

-- =======================
-- BORDER PATTERNS
-- =======================
local function setLeftBorderPattern()
    for id,n in pairs(nodes) do
        if not n.isExit then
            n.state = isCorner(id) and 0 or 1  -- corners blue, others yellow
        end
    end
end

local function setRightBorderPattern()
    for id,n in pairs(nodes) do
        if not n.isExit then
            n.state = isCorner(id) and 1 or 0  -- corners yellow, others blue
        end
    end
end

-- =======================
-- MARBLES
-- =======================
local function startMove(m, fromPos, toPos, nextId)
    m.segA = fromPos
    m.segB = toPos
    m.nextId = nextId
    m.t = 0
    m.mode = "move"
end

local function startDwell(m)
    m.mode = "dwell"
    m.dwell = DWELL_TIME
end

local function processArrivalAt(m, id)
    local n = nodes[id]
    if not n then m.alive=false; return end
    if n.isExit then m.alive=false; return end
    
    local dir = routeDir(n.state)
    local nextId = (dir=="L") and n.L or n.R
    n.state = 1 - n.state
    
    startMove(m, n.pos, nodes[nextId].pos, nextId)
end

local function newMarble(entry)
    local start = entry.pos
    local firstId = entry.dropTo
    local firstPos = nodes[firstId].pos
    
    return {
        alive = true,
        color = MARBLE_BLACK,
        pos = start,
        
        mode = "move",
        speed = TRAVEL_SPEED,
        dwell = 0,
        
        segA = start,
        segB = firstPos,
        t = 0,
        
        nextId = firstId,
        phase = "entry"
    }
end

local function dropMarble(entry)
    marbles[#marbles+1] = newMarble(entry)
end

local function stepMarble(m, dt)
    if not m.alive then return end
    
    if m.mode == "move" then
        m.t = m.t + dt * m.speed
        local a = math.min(1, m.t)
        m.pos = m.segA + (m.segB - m.segA) * a
        if a >= 1 then
            m.pos = m.segB
            startDwell(m)
        end
        return
    end
    
    m.dwell = m.dwell - dt
    if m.dwell > 0 then return end
    
    if m.phase == "entry" then
        m.phase = "path"
        m.color = MARBLE_GRAY
    end
    
    local id = m.nextId
    if nodes[id] and nodes[id].isExit then
        m.alive = false
        return
    end
    
    processArrivalAt(m, id)
end

local function pruneMarbles()
    local keep = {}
    for _,m in ipairs(marbles) do
        if m.alive then keep[#keep+1] = m end
    end
    marbles = keep
end

-- =======================
-- DRAW
-- =======================
local function drawFrame()
    background(BG)
    
    local cx = (board.left + board.right) * 0.5
    local cy = (board.bottom + board.top) * 0.5
    local w  = (board.right - board.left)
    local h  = (board.top - board.bottom)
    
    drawRectXYWH(cx, cy, w, h, REDB)
    drawRectXYWH(cx, cy, w - board.border*2, h - board.border*2, BG)
end

local function drawPaths()
    pushStyle()
    stroke(PATH)
    strokeWidth(4)
    for id,n in pairs(nodes) do
        if not n.isExit then
            local p = n.pos
            if n.L and nodes[n.L] then
                local q = nodes[n.L].pos
                line(p.x, p.y, q.x, q.y)
            end
            if n.R and nodes[n.R] then
                local q = nodes[n.R].pos
                line(p.x, p.y, q.x, q.y)
            end
        end
    end
    popStyle()
end

local function drawExits()
    pushStyle()
    noStroke()
    fill(210,210,210,160)
    for _,p in pairs(board.exits) do
        ellipse(p.x, p.y, board.entryR*1.6)
    end
    popStyle()
end

local function drawDots()
    pushStyle()
    for id,n in pairs(nodes) do
        if not n.isExit then
            stroke(255)
            strokeWidth(5)
            fill((n.state==0) and BLUE or YELLOW)
            ellipse(n.pos.x, n.pos.y, board.dotR*2.20)
        end
    end
    popStyle()
end

local function drawEntries()
    pushStyle()
    for _,e in ipairs(board.entries) do
        stroke(160,160,160)
        strokeWidth(2)
        fill(245)
        ellipse(e.pos.x, e.pos.y, board.entryR*2.0)
        fill(90)
        fontSize(14)
        textMode(CENTER)
        text("DROP", e.pos.x, e.pos.y + board.entryR*1.6)
    end
    popStyle()
end

local function drawMarbles()
    pushStyle()
    for _,m in ipairs(marbles) do
        if m.alive then
            noStroke()
            fill(m.color)
            ellipse(m.pos.x, m.pos.y, board.dotR*0.75)
        end
    end
    popStyle()
end

local function drawTitle()
    pushStyle()
    fill(30, 30, 35)
    fontSize(28)
    textMode(CENTER)
    text(
    "Think-A-Dot — Mechanical Marble Logic Toy",
    WIDTH / 2,
    HEIGHT - 50
    )
    popStyle()
end

local function drawCaption()
    pushStyle()
    fill(80, 80, 85)
    fontSize(20)
    textMode(CENTER)
    text(
    "Invented by Joe Weisbecker (ESR) 1968 • U.S. Patent 3,771,754",
    WIDTH / 2,
    50
    )
    popStyle()
end

function draw()
    local dt = DeltaTime or (1/60)
    
    for _,m in ipairs(marbles) do
        stepMarble(m, dt)
    end
    pruneMarbles()
    
    drawFrame()
    drawPaths()
    drawExits()
    drawDots()
    drawEntries()
    drawMarbles()
    
    drawTitle()
    drawCaption()
    
    pushStyle()
    fill(50,50,55)
    fontSize(20)
    textMode(CENTER)
    text("Tap TOP circles to drop • Tap DOT to toggle • Tap LEFT frame=reset • RIGHT frame=set",
    WIDTH/2, board.bottom * 0.55)
    popStyle()
end

-- =======================
-- INPUT
-- =======================
function touched(t)
    if not t or t.state ~= BEGAN then return end
    
    local p = t.location or vec2(t.x or 0, t.y or 0)
    local x, y = p.x, p.y
    
    local L,R,B,T = board.left, board.right, board.bottom, board.top
    local bw = board.border
    
    if inRect(x,y, L,B,R,T) then
        if inRect(x,y, L,B, L+bw, T) then
            setLeftBorderPattern()
            marbles = {}
            return
        end
        if inRect(x,y, R-bw,B, R, T) then
            setRightBorderPattern()
            marbles = {}
            return
        end
    end
    
    for _,e in ipairs(board.entries) do
        if e.pos:dist(p) <= board.entryR*1.2 then
            dropMarble(e)
            return
        end
    end
    
    for id,n in pairs(nodes) do
        if not n.isExit and n.pos:dist(p) <= board.dotR*1.15 then
            n.state = 1 - n.state
            return
        end
    end
end

-- =======================
-- SETUP
-- =======================
function setup()
    parameter.clear()        -- removes all parameter controls
    viewer.mode = FULLSCREEN -- then go fullscreen
    
    whiteImg = image(1,1)
    setContext(whiteImg)
    background(255)
    setContext()
    
    math.randomseed(os.time())
    
    initGeometry()
    initNetwork()
    setLeftBorderPattern()
    
end