
-- Piecewise Polynomial Regression Viewer (deg 1..4) for Sine Curve
-- 10,000 points, error tolerance from slider (0.0..0.1)
-- Original (gray), piecewise polynomial (red)
-- Degree toggle + "Best" selector (fewest segments)
-- Zoom + pan (drag inside plot), extrema & inflections marked
-- Binary output: data.bin and segments.bin (float32, little-endian)

NPOINTS   = 10000
VIEW_SIZE = 1000

x = {}
y = {}

-- segmentsByDegree[d] = { list of segments for degree d }
-- each segment: { iStart, iEnd, deg, coefs = {a_n, ..., a_0} }
segmentsByDegree = {}
segmentCounts    = {}

currentDegree = 1
bestDegree    = 1
segments      = nil

-- error tolerance controlled by slider
errorTol = 0.0001

-- view window in index space
viewFirst  = 1
viewLast   = NPOINTS
block      = 0        -- 0 = full view, 1..ceil(N/VIEW_SIZE) = 1k blocks

-- vertical zoom & pan offsets (applied to plot contents only)
zoomFactor = 1.0
panX, panY = 0, 0
isPanning  = false
panLastX, panLastY = 0, 0

navButtons    = {}
degreeButtons = {}
slider        = nil

-- feature markers
extremaIndices     = {}
inflectionIndices  = {}

----------------------------------------------------
-- SETUP
----------------------------------------------------

function setup()
    -- generate data and detect extrema/inflections
    generateData()
    detectFeatures()
    
    -- init slider
    slider = {
        x = 20,
        y = 90,
        w = WIDTH - 40,
        h = 20,
        min = 0.0,
        max = 0.1,
        value = 0.0001,
        isDragging = false
    }
    errorTol = slider.value
    
    -- build piecewise regression for degrees 1..4
    recomputeAllSegments()
    
    -- start with degree 1
    currentDegree = 1
    segments      = segmentsByDegree[currentDegree]
    
    -- initial view = all 10k
    block = 0
    updateViewFromBlock()
    
    -- UI setup
    setupButtons()
    
    print("Setup complete.")
end

function generateData()
    -- sine over 0..20π
    local maxT = 20 * math.pi
    for i = 1, NPOINTS do
        local t = (i-1) * maxT / (NPOINTS-1)
        x[i] = t
        y[i] = math.sin(t)
    end
end

function detectFeatures()
    extremaIndices = {}
    inflectionIndices = {}
    
    -- discrete extrema
    for i = 2, NPOINTS-1 do
        local y0, y1, y2 = y[i-1], y[i], y[i+1]
        if (y1 > y0 and y1 > y2) or (y1 < y0 and y1 < y2) then
            table.insert(extremaIndices, i)
        end
    end
    
    -- discrete inflection (sign change of second difference)
    local prevS = nil
    for i = 2, NPOINTS-1 do
        local s = y[i+1] - 2*y[i] + y[i-1]
        if prevS ~= nil and s * prevS < 0 then
            table.insert(inflectionIndices, i)
        end
        if s ~= 0 then
            prevS = s
        end
    end
end

----------------------------------------------------
-- BINARY PACKING (float32 + uint32) for Codea
----------------------------------------------------

local function packUInt32(n)
    -- assumes 0 <= n < 2^32, little-endian
    local b4 = n % 256; n = (n - b4) / 256
    local b3 = n % 256; n = (n - b3) / 256
    local b2 = n % 256; n = (n - b2) / 256
    local b1 = n % 256
    return string.char(b4, b3, b2, b1)
end

local function packInt32(n)
    -- treat as signed 32-bit, stored little-endian
    if n < 0 then
        n = n + 4294967296  -- 2^32
    end
    return packUInt32(n)
end

-- Pure Lua IEEE-754 float32 pack (little-endian)
local function packFloat32(xv)
    if xv == 0 then
        return string.char(0,0,0,0)
    end
    local sign = 0
    if xv < 0 then
        sign = 1
        xv = -xv
    end
    
    local m, e = math.frexp(xv)  -- xv = m * 2^e, 0.5 <= m < 1
    -- IEEE-754 float32: value = (-1)^sign * (1.fraction) * 2^(exp-127)
    e = e - 1
    m = m * 2 - 1  -- now 0 <= m < 1
    local exp = e + 127
    if exp <= 0 then
        -- denormal (very small); just zero it
        return string.char(0,0,0,0)
    elseif exp >= 255 then
        -- overflow -> inf
        local b3 = 0
        local b2 = 0
        local b1 = 0x80 + sign
        local b0 = 0x7F
        return string.char(b3,b2,b1,b0)
    end
    
    local frac = math.floor(m * 2^23 + 0.5)
    if frac == 2^23 then
        -- round overflow
        frac = 0
        exp = exp + 1
        if exp >= 255 then
            exp = 255
            frac = 0
        end
    end
    
    local bits = (sign << 31) | (exp << 23) | frac
    -- But Lua 5.1 has no bit ops, so do manual composition:
    local b4 = bits % 256; bits = (bits - b4) / 256
    local b3 = bits % 256; bits = (bits - b3) / 256
    local b2 = bits % 256; bits = (bits - b2) / 256
    local b1 = bits % 256
    return string.char(b4, b3, b2, b1)
end

-- Fallback bit-shift using arithmetic (no bit operators)
do
    local _packFloat32 = packFloat32
    packFloat32 = function(xv)
        if xv == 0 then
            return string.char(0,0,0,0)
        end
        local sign = 0
        if xv < 0 then
            sign = 1
            xv = -xv
        end
        local m, e = math.frexp(xv)
        e = e - 1
        m = m * 2 - 1
        local exp = e + 127
        if exp <= 0 or exp >= 255 then
            -- just use a crude zero/inf fallback
            if exp <= 0 then
                return string.char(0,0,0,0)
            else
                -- sign * inf
                local b4 = 0
                local b3 = 0
                local b2 = 0x80 + sign
                local b1 = 0x7F
                return string.char(b4,b3,b2,b1)
            end
        end
        local frac = math.floor(m * 2^23 + 0.5)
        if frac == 2^23 then
            frac = 0
            exp = exp + 1
            if exp >= 255 then
                exp = 255
                frac = 0
            end
        end
        
        -- compose bits without bit ops
        local bits = frac
        bits = bits + exp * 2^23
        bits = bits + sign * 2^31
        
        local b4 = bits % 256; bits = (bits - b4) / 256
        local b3 = bits % 256; bits = (bits - b3) / 256
        local b2 = bits % 256; bits = (bits - b2) / 256
        local b1 = bits % 256
        return string.char(b4, b3, b2, b1)
    end
end

----------------------------------------------------
-- SAVE BINARY FILES
----------------------------------------------------

function saveBinaryFiles()
    -- Data file: NPOINTS (uint32), then x[i], y[i] as float32
    local dataStr = ""
    dataStr = dataStr .. packUInt32(NPOINTS)
    for i = 1, NPOINTS do
        dataStr = dataStr .. packFloat32(x[i]) .. packFloat32(y[i])
    end
    saveText("data.bin", dataStr)
    
    -- Segments file: for each segment across degrees:
    -- [uint32 recordBytes][int32 iStart][int32 iEnd][int32 degree][int32 nCoefs][float32 coefs...]
    local segStr = ""
    for d = 1, 4 do
        local segs = segmentsByDegree[d]
        for _, seg in ipairs(segs) do
            local coefs = seg.coefs
            local nCoefs = #coefs
            local recordBytes = 4*4 + 4*nCoefs  -- 4 ints + nCoefs floats
            
            local rec = ""
            rec = rec .. packInt32(seg.iStart)
            rec = rec .. packInt32(seg.iEnd)
            rec = rec .. packInt32(seg.deg)
            rec = rec .. packInt32(nCoefs)
            for i = 1, nCoefs do
                rec = rec .. packFloat32(coefs[i])
            end
            
            segStr = segStr .. packUInt32(recordBytes) .. rec
        end
    end
    saveText("segments.bin", segStr)
    
    print("Saved data.bin and segments.bin")
end

----------------------------------------------------
-- SMALL SYSTEM SOLVERS (3x3, 4x4, 5x5)
----------------------------------------------------

local function solve3x3(A, b)
    local M = {
        {A[1][1], A[1][2], A[1][3]},
        {A[2][1], A[2][2], A[2][3]},
        {A[3][1], A[3][2], A[3][3]}
    }
    local v = {b[1], b[2], b[3]}
    
    for k = 1, 3 do
        local maxRow = k
        local maxVal = math.abs(M[k][k])
        for r = k+1, 3 do
            local val = math.abs(M[r][k])
            if val > maxVal then
                maxVal = val
                maxRow = r
            end
        end
        
        if maxVal < 1e-12 then return nil end
        
        if maxRow ~= k then
            M[k], M[maxRow] = M[maxRow], M[k]
            v[k], v[maxRow] = v[maxRow], v[k]
        end
        
        local pivot = M[k][k]
        for r = k+1, 3 do
            local factor = M[r][k] / pivot
            for c = k, 3 do
                M[r][c] = M[r][c] - factor * M[k][c]
            end
            v[r] = v[r] - factor * v[k]
        end
    end
    
    local xsol = {0,0,0}
    for i = 3, 1, -1 do
        local s = v[i]
        for c = i+1, 3 do
            s = s - M[i][c] * xsol[c]
        end
        xsol[i] = s / M[i][i]
    end
    
    return xsol[1], xsol[2], xsol[3]
end

local function solve4x4(A, b)
    local M = {
        {A[1][1], A[1][2], A[1][3], A[1][4]},
        {A[2][1], A[2][2], A[2][3], A[2][4]},
        {A[3][1], A[3][2], A[3][3], A[3][4]},
        {A[4][1], A[4][2], A[4][3], A[4][4]}
    }
    local v = {b[1], b[2], b[3], b[4]}
    
    for k = 1, 4 do
        local maxRow = k
        local maxVal = math.abs(M[k][k])
        for r = k+1, 4 do
            local val = math.abs(M[r][k])
            if val > maxVal then
                maxVal = val
                maxRow = r
            end
        end
        
        if maxVal < 1e-12 then return nil end
        
        if maxRow ~= k then
            M[k], M[maxRow] = M[maxRow], M[k]
            v[k], v[maxRow] = v[maxRow], v[k]
        end
        
        local pivot = M[k][k]
        for r = k+1, 4 do
            local factor = M[r][k] / pivot
            for c = k, 4 do
                M[r][c] = M[r][c] - factor * M[k][c]
            end
            v[r] = v[r] - factor * v[k]
        end
    end
    
    local xsol = {0,0,0,0}
    for i = 4, 1, -1 do
        local s = v[i]
        for c = i+1, 4 do
            s = s - M[i][c] * xsol[c]
        end
        xsol[i] = s / M[i][i]
    end
    
    return xsol[1], xsol[2], xsol[3], xsol[4]
end

local function solve5x5(A, b)
    local M = {
        {A[1][1], A[1][2], A[1][3], A[1][4], A[1][5]},
        {A[2][1], A[2][2], A[2][3], A[2][4], A[2][5]},
        {A[3][1], A[3][2], A[3][3], A[3][4], A[3][5]},
        {A[4][1], A[4][2], A[4][3], A[4][4], A[4][5]},
        {A[5][1], A[5][2], A[5][3], A[5][4], A[5][5]}
    }
    local v = {b[1], b[2], b[3], b[4], b[5]}
    
    for k = 1, 5 do
        local maxRow = k
        local maxVal = math.abs(M[k][k])
        for r = k+1, 5 do
            local val = math.abs(M[r][k])
            if val > maxVal then
                maxVal = val
                maxRow = r
            end
        end
        
        if maxVal < 1e-12 then return nil end
        
        if maxRow ~= k then
            M[k], M[maxRow] = M[maxRow], M[k]
            v[k], v[maxRow] = v[maxRow], v[k]
        end
        
        local pivot = M[k][k]
        for r = k+1, 5 do
            local factor = M[r][k] / pivot
            for c = k, 5 do
                M[r][c] = M[r][c] - factor * M[k][c]
            end
            v[r] = v[r] - factor * v[k]
        end
    end
    
    local xsol = {0,0,0,0,0}
    for i = 5, 1, -1 do
        local s = v[i]
        for c = i+1, 5 do
            s = s - M[i][c] * xsol[c]
        end
        xsol[i] = s / M[i][i]
    end
    
    return xsol[1], xsol[2], xsol[3], xsol[4], xsol[5]
end

----------------------------------------------------
-- NORMAL-EQUATION HELPERS
----------------------------------------------------

local function solveQuadraticFromSums(sumX, sumX2, sumX3, sumX4,
                                      sumY, sumXY, sumX2Y, n)
    local A = {
        {sumX4, sumX3, sumX2},
        {sumX3, sumX2, sumX },
        {sumX2, sumX,  n    }
    }
    local b = {sumX2Y, sumXY, sumY}
    return solve3x3(A, b)
end

local function solveCubicFromSums(sumX, sumX2, sumX3, sumX4, sumX5, sumX6,
                                  sumY, sumXY, sumX2Y, sumX3Y, n)
    local A = {
        {sumX6, sumX5, sumX4, sumX3},
        {sumX5, sumX4, sumX3, sumX2},
        {sumX4, sumX3, sumX2, sumX },
        {sumX3, sumX2, sumX,  n    }
    }
    local b = {sumX3Y, sumX2Y, sumXY, sumY}
    return solve4x4(A, b)
end

local function solveQuarticFromSums(sumX, sumX2, sumX3, sumX4,
                                    sumX5, sumX6, sumX7, sumX8,
                                    sumY, sumXY, sumX2Y, sumX3Y, sumX4Y, n)
    local A = {
        {sumX8, sumX7, sumX6, sumX5, sumX4},
        {sumX7, sumX6, sumX5, sumX4, sumX3},
        {sumX6, sumX5, sumX4, sumX3, sumX2},
        {sumX5, sumX4, sumX3, sumX2, sumX },
        {sumX4, sumX3, sumX2, sumX,  n    }
    }
    local b = {sumX4Y, sumX3Y, sumX2Y, sumXY, sumY}
    return solve5x5(A, b)
end

----------------------------------------------------
-- POLY HELPERS
----------------------------------------------------

local function embedCoeffs(baseCoefs, degWanted)
    -- baseCoefs: highest-degree first, actual degree may be < degWanted
    local coefs = {}
    for i = 1, #baseCoefs do
        coefs[i] = baseCoefs[i]
    end
    while #coefs < degWanted + 1 do
        table.insert(coefs, 1, 0)
    end
    return coefs
end

local function evalPoly(coefs, xx)
    local acc = 0
    for i = 1, #coefs do
        acc = acc * xx + coefs[i]
    end
    return acc
end

-- Fit polynomial of degree 'deg' using sums; return coefs (highest degree first)
local function fitPolyDeg(deg,
                          sumX, sumX2, sumX3, sumX4,
                          sumX5, sumX6, sumX7, sumX8,
                          sumY, sumXY, sumX2Y, sumX3Y, sumX4Y,
                          n)
    local avgY = sumY / n
    if deg == 1 then
        if n == 1 then
            return embedCoeffs({avgY}, 1)
        else
            local denom = n * sumX2 - sumX * sumX
            if math.abs(denom) < 1e-12 then
                return embedCoeffs({avgY}, 1)
            else
                local m  = (n * sumXY - sumX * sumY) / denom
                local bb = (sumY - m * sumX) / n
                return embedCoeffs({m, bb}, 1)
            end
        end
    elseif deg == 2 then
        if n == 1 then
            return embedCoeffs({avgY}, 2)
        elseif n == 2 then
            local denom = n * sumX2 - sumX * sumX
            if math.abs(denom) < 1e-12 then
                return embedCoeffs({avgY}, 2)
            else
                local m  = (n * sumXY - sumX * sumY) / denom
                local bb = (sumY - m * sumX) / n
                return embedCoeffs({m, bb}, 2)
            end
        else
            local qa, qb, qc = solveQuadraticFromSums(
                sumX, sumX2, sumX3, sumX4,
                sumY, sumXY, sumX2Y, n
            )
            if qa == nil then
                local denom = n * sumX2 - sumX * sumX
                if math.abs(denom) < 1e-12 then
                    return embedCoeffs({avgY}, 2)
                else
                    local m  = (n * sumXY - sumX * sumY) / denom
                    local bb = (sumY - m * sumX) / n
                    return embedCoeffs({m, bb}, 2)
                end
            else
                return embedCoeffs({qa, qb, qc}, 2)
            end
        end
    elseif deg == 3 then
        if n == 1 then
            return embedCoeffs({avgY}, 3)
        elseif n == 2 then
            local denom = n * sumX2 - sumX * sumX
            if math.abs(denom) < 1e-12 then
                return embedCoeffs({avgY}, 3)
            else
                local m  = (n * sumXY - sumX * sumY) / denom
                local bb = (sumY - m * sumX) / n
                return embedCoeffs({m, bb}, 3)
            end
        elseif n == 3 then
            local qa, qb, qc = solveQuadraticFromSums(
                sumX, sumX2, sumX3, sumX4,
                sumY, sumXY, sumX2Y, n
            )
            if qa == nil then
                return embedCoeffs({avgY}, 3)
            else
                return embedCoeffs({qa, qb, qc}, 3)
            end
        else
            local ca, cb, cc, cd = solveCubicFromSums(
                sumX, sumX2, sumX3, sumX4, sumX5, sumX6,
                sumY, sumXY, sumX2Y, sumX3Y, n
            )
            if ca == nil then
                local qa, qb, qc = solveQuadraticFromSums(
                    sumX, sumX2, sumX3, sumX4,
                    sumY, sumXY, sumX2Y, n
                )
                if qa == nil then
                    return embedCoeffs({avgY}, 3)
                else
                    return embedCoeffs({qa, qb, qc}, 3)
                end
            else
                return embedCoeffs({ca, cb, cc, cd}, 3)
            end
        end
    else -- deg == 4
        if n == 1 then
            return embedCoeffs({avgY}, 4)
        elseif n == 2 then
            local denom = n * sumX2 - sumX * sumX
            if math.abs(denom) < 1e-12 then
                return embedCoeffs({avgY}, 4)
            else
                local m  = (n * sumXY - sumX * sumY) / denom
                local bb = (sumY - m * sumX) / n
                return embedCoeffs({m, bb}, 4)
            end
        elseif n == 3 then
            local qa, qb, qc = solveQuadraticFromSums(
                sumX, sumX2, sumX3, sumX4,
                sumY, sumXY, sumX2Y, n
            )
            if qa == nil then
                return embedCoeffs({avgY}, 4)
            else
                return embedCoeffs({qa, qb, qc}, 4)
            end
        elseif n == 4 then
            local ca, cb, cc, cd = solveCubicFromSums(
                sumX, sumX2, sumX3, sumX4, sumX5, sumX6,
                sumY, sumXY, sumX2Y, sumX3Y, n
            )
            if ca == nil then
                local qa, qb, qc = solveQuadraticFromSums(
                    sumX, sumX2, sumX3, sumX4,
                    sumY, sumXY, sumX2Y, n
                )
                if qa == nil then
                    return embedCoeffs({avgY}, 4)
                else
                    return embedCoeffs({qa, qb, qc}, 4)
                end
            else
                return embedCoeffs({ca, cb, cc, cd}, 4)
            end
        else
            local qa, qb, qc, qd, qe = solveQuarticFromSums(
                sumX, sumX2, sumX3, sumX4,
                sumX5, sumX6, sumX7, sumX8,
                sumY, sumXY, sumX2Y, sumX3Y, sumX4Y, n
            )
            if qa == nil then
                local ca, cb, cc, cd = solveCubicFromSums(
                    sumX, sumX2, sumX3, sumX4, sumX5, sumX6,
                    sumY, sumXY, sumX2Y, sumX3Y, n
                )
                if ca == nil then
                    local qa2, qb2, qc2 = solveQuadraticFromSums(
                        sumX, sumX2, sumX3, sumX4,
                        sumY, sumXY, sumX2Y, n
                    )
                    if qa2 == nil then
                        return embedCoeffs({avgY}, 4)
                    else
                        return embedCoeffs({qa2, qb2, qc2}, 4)
                    end
                else
                    return embedCoeffs({ca, cb, cc, cd}, 4)
                end
            else
                return embedCoeffs({qa, qb, qc, qd, qe}, 4)
            end
        end
    end
end

----------------------------------------------------
-- BUILD SEGMENTS FOR A GIVEN DEGREE
----------------------------------------------------

function buildSegmentsDegree(deg)
    local segs = {}
    local i = 1
    while i <= NPOINTS do
        local sumX, sumX2, sumX3, sumX4 = 0,0,0,0
        local sumX5, sumX6, sumX7, sumX8 = 0,0,0,0
        local sumY, sumXY, sumX2Y, sumX3Y, sumX4Y = 0,0,0,0,0
        
        local j = i
        local bestJ = i
        local bestCoefs = embedCoeffs({y[i]}, deg)
        
        while j <= NPOINTS do
            local xj, yj = x[j], y[j]
            local xj2 = xj * xj
            local xj3 = xj2 * xj
            local xj4 = xj2 * xj2
            local xj5 = xj4 * xj
            local xj6 = xj3 * xj3
            local xj7 = xj4 * xj3
            local xj8 = xj4 * xj4
            
            sumX   = sumX   + xj
            sumX2  = sumX2  + xj2
            sumX3  = sumX3  + xj3
            sumX4  = sumX4  + xj4
            sumX5  = sumX5  + xj5
            sumX6  = sumX6  + xj6
            sumX7  = sumX7  + xj7
            sumX8  = sumX8  + xj8
            sumY   = sumY   + yj
            sumXY  = sumXY  + xj  * yj
            sumX2Y = sumX2Y + xj2 * yj
            sumX3Y = sumX3Y + xj3 * yj
            sumX4Y = sumX4Y + xj4 * yj
            
            local n = j - i + 1
            local coefs = fitPolyDeg(
                deg,
                sumX, sumX2, sumX3, sumX4,
                sumX5, sumX6, sumX7, sumX8,
                sumY, sumXY, sumX2Y, sumX3Y, sumX4Y,
                n
            )
            
            -- compute max error in this candidate segment
            local maxErr = 0
            for k = i, j do
                local xx = x[k]
                local yp = evalPoly(coefs, xx)
                local err = math.abs(yp - y[k])
                if err > maxErr then
                    maxErr = err
                    if maxErr > errorTol then
                        break
                    end
                end
            end
            
            if maxErr <= errorTol then
                bestJ = j
                bestCoefs = coefs
                j = j + 1
            else
                break
            end
        end
        
        table.insert(segs, {
            iStart = i,
            iEnd   = bestJ,
            deg    = deg,
            coefs  = bestCoefs
        })
        
        i = bestJ + 1
    end
    
    return segs
end

function recomputeAllSegments()
    segmentsByDegree = {}
    segmentCounts    = {}
    
    for d = 1, 4 do
        print("Building segments for degree " .. d .. " (tol=" .. errorTol .. ") ...")
        segmentsByDegree[d] = buildSegmentsDegree(d)
        segmentCounts[d] = #segmentsByDegree[d]
        print("Degree " .. d .. " segments: " .. segmentCounts[d])
    end
    
    -- choose best degree = fewest segments
    bestDegree = 1
    local bestCount = segmentCounts[1]
    for d = 2, 4 do
        if segmentCounts[d] < bestCount then
            bestCount = segmentCounts[d]
            bestDegree = d
        end
    end
    print("Best degree by compression = " .. bestDegree)
    
    -- refresh current segments
    segments = segmentsByDegree[currentDegree]
    
    -- save binaries with current tolerance & segments
    saveBinaryFiles()
end

----------------------------------------------------
-- VIEW MANAGEMENT
----------------------------------------------------

function updateViewFromBlock()
    if block == 0 then
        -- full 10k
        viewFirst = 1
        viewLast  = NPOINTS
    else
        local maxBlock = math.ceil(NPOINTS / VIEW_SIZE)
        if block < 1 then block = 1 end
        if block > maxBlock then block = maxBlock end
        viewFirst = (block - 1) * VIEW_SIZE + 1
        if viewFirst > NPOINTS then
            viewFirst = NPOINTS - VIEW_SIZE + 1
        end
        if viewFirst < 1 then
            viewFirst = 1
        end
        viewLast = math.min(viewFirst + VIEW_SIZE - 1, NPOINTS)
    end
end

----------------------------------------------------
-- BUTTONS + SLIDER
----------------------------------------------------

function setupButtons()
    navButtons = {}
    degreeButtons = {}
    
    -- Navigation / zoom row
    local navLabels = {
        "All 10k", "Home 1k", "Prev 1k",
        "Next 1k", "End 1k", "Zoom +", "Zoom -"
    }
    
    local n = #navLabels
    local margin = 10
    local bh = 30
    local yPos = 10
    local bw = (WIDTH - margin*2) / n
    
    for i, label in ipairs(navLabels) do
        local btn = {
            label = label,
            x = margin + (i-1) * bw,
            y = yPos,
            w = bw - 5,
            h = bh,
            action = function() end
        }
        table.insert(navButtons, btn)
    end
    
    -- Assign nav actions
    navButtons[1].action = function()
        block = 0
        updateViewFromBlock()
        panX, panY = 0, 0
    end
    navButtons[2].action = function()
        block = 1
        updateViewFromBlock()
        panX, panY = 0, 0
    end
    navButtons[3].action = function()
        if block == 0 then
            block = 1
        else
            block = block - 1
        end
        updateViewFromBlock()
        panX, panY = 0, 0
    end
    navButtons[4].action = function()
        local maxBlock = math.ceil(NPOINTS / VIEW_SIZE)
        if block == 0 then
            block = 1
        else
            block = math.min(block + 1, maxBlock)
        end
        updateViewFromBlock()
        panX, panY = 0, 0
    end
    navButtons[5].action = function()
        block = math.ceil(NPOINTS / VIEW_SIZE)
        updateViewFromBlock()
        panX, panY = 0, 0
    end
    navButtons[6].action = function()
        zoomFactor = math.min(zoomFactor * 1.5, 20)
    end
    navButtons[7].action = function()
        zoomFactor = math.max(zoomFactor / 1.5, 0.1)
    end
    
    -- Degree row
    local degLabels = {"Deg1", "Deg2", "Deg3", "Deg4", "Best"}
    local nd = #degLabels
    local bw2 = (WIDTH - margin*2) / nd
    local yPos2 = 50
    
    for i, label in ipairs(degLabels) do
        local btn = {
            label = label,
            x = margin + (i-1) * bw2,
            y = yPos2,
            w = bw2 - 5,
            h = bh,
            action = function() end
        }
        table.insert(degreeButtons, btn)
    end
    
    degreeButtons[1].action = function()
        currentDegree = 1
        segments = segmentsByDegree[currentDegree]
    end
    degreeButtons[2].action = function()
        currentDegree = 2
        segments = segmentsByDegree[currentDegree]
    end
    degreeButtons[3].action = function()
        currentDegree = 3
        segments = segmentsByDegree[currentDegree]
    end
    degreeButtons[4].action = function()
        currentDegree = 4
        segments = segmentsByDegree[currentDegree]
    end
    degreeButtons[5].action = function()
        currentDegree = bestDegree
        segments = segmentsByDegree[currentDegree]
        print("Best degree selected: " .. currentDegree ..
              " (segments = " .. (segmentCounts[currentDegree] or 0) .. ")")
    end
end

local function drawButtons(btns)
    fontSize(14)
    textMode(CENTER)
    
    for _, btn in ipairs(btns) do
        fill(40, 40, 40, 220)
        stroke(200)
        strokeWidth(1)
        rect(btn.x, btn.y, btn.w, btn.h)
        
        fill(255)
        text(btn.label, btn.x + btn.w/2, btn.y + btn.h/2)
    end
end

local function drawSlider()
    local s = slider
    if not s then return end
    
    -- bar
    fill(60, 60, 60, 220)
    stroke(200)
    strokeWidth(1)
    rect(s.x, s.y, s.w, s.h)
    
    -- knob
    local t = (s.value - s.min) / (s.max - s.min)
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    local knobX = s.x + t * s.w
    local knobW = 12
    fill(220)
    rect(knobX - knobW/2, s.y - 5, knobW, s.h + 10)
    
    -- label
    fill(255)
    fontSize(14)
    textMode(CENTER)
    local label = string.format("Error tol: %.5f", s.value)
    text(label, s.x + s.w/2, s.y + s.h + 15)
end

local function updateSliderFromTouch(tx)
    local s = slider
    local t = (tx - s.x) / s.w
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    s.value = s.min + t * (s.max - s.min)
end

local function onSliderReleased()
    errorTol = slider.value
    print("New error tolerance: " .. errorTol .. "  (recomputing segments...)")
    recomputeAllSegments()
end

----------------------------------------------------
-- TOUCH HANDLING (buttons + slider + panning)
----------------------------------------------------

function touched(t)
    local function hit(btn)
        return t.x >= btn.x and t.x <= btn.x + btn.w and
               t.y >= btn.y and t.y <= btn.y + btn.h
    end
    
    -- slider region
    local s = slider
    local inSlider = s and t.x >= s.x and t.x <= s.x + s.w and
                           t.y >= s.y - 5 and t.y <= s.y + s.h + 10
    
    if t.state == BEGAN then
        -- slider first
        if inSlider then
            s.isDragging = true
            updateSliderFromTouch(t.x)
            return
        end
        
        -- nav buttons
        for _, btn in ipairs(navButtons) do
            if hit(btn) then
                if btn.action then btn.action() end
                return
            end
        end
        
        -- degree buttons
        for _, btn in ipairs(degreeButtons) do
            if hit(btn) then
                if btn.action then btn.action() end
                return
            end
        end
        
        -- If none of the above, begin panning inside plot if inside plot area
        local left   = 40
        local right  = 10
        local bottom = 130
        local top    = 40
        local plotW = WIDTH - left - right
        local plotH = HEIGHT - bottom - top
        if t.x >= left and t.x <= left + plotW and
           t.y >= bottom and t.y <= bottom + plotH then
            isPanning = true
            panLastX, panLastY = t.x, t.y
            return
        end
    
    elseif t.state == MOVING then
        if s.isDragging then
            updateSliderFromTouch(t.x)
            return
        end
        
        if isPanning then
            local dx = t.x - panLastX
            local dy = t.y - panLastY
            panX = panX + dx
            panY = panY + dy
            panLastX, panLastY = t.x, t.y
            return
        end
    
    elseif t.state == ENDED or t.state == CANCELLED then
        if s.isDragging then
            s.isDragging = false
            updateSliderFromTouch(t.x)
            onSliderReleased()
            return
        end
        if isPanning then
            isPanning = false
            return
        end
    end
end

----------------------------------------------------
-- DRAW
----------------------------------------------------

function draw()
    background(0)
    
    -- plot area margins
    local left   = 40
    local right  = 10
    local bottom = 130
    local top    = 40
    
    local plotW = WIDTH - left - right
    local plotH = HEIGHT - bottom - top
    local cx = left + plotW / 2
    local cy = bottom + plotH / 2
    
    -- frame / axes
    stroke(255)
    strokeWidth(1)
    noFill()
    rect(left, bottom, plotW, plotH)
    
    -- horizontal axis at y=0
    local yZero = cy + panY
    stroke(80, 80, 80, 200)
    line(left, yZero, left + plotW, yZero)
    
    local span = viewLast - viewFirst
    if span < 1 then span = 1 end
    
    -- draw original data (gray)
    stroke(150)
    strokeWidth(1)
    local prevSX, prevSY = nil, nil
    
    for i = viewFirst, viewLast do
        local t = (i - viewFirst) / span
        local sx = left + t * plotW + panX
        local yVal = y[i]
        local sy = cy - yVal * zoomFactor * (plotH * 0.45) + panY
        
        if prevSX then
            line(prevSX, prevSY, sx, sy)
        end
        prevSX, prevSY = sx, sy
    end
    
    -- extrema markers (small vertical bars)
    stroke(0, 255, 0)  -- bright green
    strokeWidth(2)
    for _, idx in ipairs(extremaIndices) do
        if idx >= viewFirst and idx <= viewLast then
            local t = (idx - viewFirst) / span
            local sx = left + t * plotW + panX
            local yVal = y[idx]
            local sy = cy - yVal * zoomFactor * (plotH * 0.45) + panY
            line(sx, sy - 6, sx, sy + 6)
        end
    end
    
    -- inflection markers (diamonds)
    stroke(0, 255, 255)  -- cyan
    strokeWidth(2)
    for _, idx in ipairs(inflectionIndices) do
        if idx >= viewFirst and idx <= viewLast then
            local t = (idx - viewFirst) / span
            local sx = left + t * plotW + panX
            local yVal = y[idx]
            local sy = cy - yVal * zoomFactor * (plotH * 0.45) + panY
            local r = 5
            line(sx, sy + r, sx + r, sy)
            line(sx + r, sy, sx, sy - r)
            line(sx, sy - r, sx - r, sy)
            line(sx - r, sy, sx, sy + r)
        end
    end
    
    -- draw piecewise polynomial regression (red)
    stroke(255, 0, 0)
    strokeWidth(2)
    
    if segments then
        for _, seg in ipairs(segments) do
            local i1 = math.max(seg.iStart, viewFirst)
            local i2 = math.min(seg.iEnd,   viewLast)
            if i2 > i1 then
                local coefs = seg.coefs
                local prevSegSX, prevSegSY = nil, nil
                for k = i1, i2 do
                    local t = (k - viewFirst) / span
                    local sx = left + t * plotW + panX
                    local xx = x[k]
                    local yfit = evalPoly(coefs, xx)
                    local sy = cy - yfit * zoomFactor * (plotH * 0.45) + panY
                    
                    if prevSegSX then
                        line(prevSegSX, prevSegSY, sx, sy)
                    end
                    prevSegSX, prevSegSY = sx, sy
                end
            end
        end
    end
    
    -- status text
    fill(255)
    fontSize(16)
    textMode(CENTER)
    local degInfo = string.format("Degree %d  (segments = %d, best = %d)",
                                  currentDegree,
                                  segmentCounts[currentDegree] or 0,
                                  bestDegree)
    text(degInfo, WIDTH/2, HEIGHT - 20)
    
    local idxInfo = string.format("Indices %d - %d  (zoom = %.2f, tol = %.5f)",
                                  viewFirst, viewLast, zoomFactor, errorTol)
    text(idxInfo, WIDTH/2, HEIGHT - 40)
    
    -- draw buttons + slider
    drawButtons(navButtons)
    drawButtons(degreeButtons)
    drawSlider()
end