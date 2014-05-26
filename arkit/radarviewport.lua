
local radar = require("arkit.radar")

local M = {}
local function newArc(startAngle, widthAngle, radius )
    startAngle = startAngle or 0
    widthAngle = widthAngle or 90
    radius = radius or 100
    local vert = {}
    vert[#vert+1] = 0 
    vert[#vert+1] = 0
    
    for i = 0, widthAngle do
        local a = (startAngle+i)*math.pi/180
        vert[#vert+1] = 0 + radius * math.cos(a)
        vert[#vert+1] = 0 + radius * math.sin(a)
    end
    
    local arc = display.newPolygon(0, 0, vert)
    arc.anchorX = 0.5
    arc.anchorY = 1
    arc.strokeWidth = 1
    return arc
end

function M:new(newAngle)
    local c = display.newGroup()
    c.referenceAngle = 247.5
    c.viewPortColor = {14/255, 140/255, 14/255, 0.5}
    c.newAngle = newAngle or 45.0
    c.arc = newArc(c.referenceAngle, c.newAngle, radar.RADIUS)
    c.arc:setFillColor(c.viewPortColor[1],c.viewPortColor[2],c.viewPortColor[3],c.viewPortColor[4])
    c.arc:setStrokeColor(c.viewPortColor[1],c.viewPortColor[2],c.viewPortColor[3],c.viewPortColor[4])
    c:insert(c.arc)
    
    return c
end

return M
