

local M = {}

M.RADIUS = 100.0

local M_PI = math.pi

function M:new(parent, radarSize)
    local c = display.newGroup()
    
    local radarSize = radarSize or M.RADIUS
    c.pois = {}
    c.radius = 0.0
    c.poiColor = {1,1,1,1}
    c.radarBgColor = {14/255, 140/255, 14/255, 0.2}
    c.radarStrokeColor = {0, 1, 0, 0.5}
    if parent then
        parent:insert(c)
    end
    
    function c:draw(pois, radius)
        self.pois = pois or {}
        self.radius = radius or 0.0
        self.range = self.radius --* 1000;
        local scale = self.range / radarSize;
        if not c.radar then 
            c.radar = display.newCircle(c, 0, 0, radarSize)
            c.radar:setFillColor(c.radarBgColor[1],c.radarBgColor[2],c.radarBgColor[3],c.radarBgColor[4])
            c.radar:setStrokeColor(c.radarStrokeColor[1],c.radarStrokeColor[2],c.radarStrokeColor[3],c.radarStrokeColor[4])
        end
        
        if self.poiGroup then
            self.poiGroup:removeSelf()
            self.poiGroup = nil
        end
        self.poiGroup = display.newGroup()
        self.poiGroup.x = 0
        self.poiGroup.y = 0
        self:insert(self.poiGroup)
        
        if self.pois and next(self.pois) then
            for i=1, #self.pois do
                local poi = self.pois[i]
                local x, y;
                local rs = 0
                --case1: azimiut is in the 1 quadrant of the radar
                if (poi.azimuth >= 0 and poi.azimuth < M_PI / 2) then
                    x = rs + math.cos((M_PI / 2) - poi.azimuth) * (poi.radialDistance / scale);
                    y = rs - math.sin((M_PI / 2) - poi.azimuth) * (poi.radialDistance / scale);
                elseif (poi.azimuth > M_PI / 2 and poi.azimuth < M_PI) then
                    --case2: azimiut is in the 2 quadrant of the radar
                    x = rs + math.cos(poi.azimuth - (M_PI / 2)) * (poi.radialDistance / scale);
                    y = rs + math.sin(poi.azimuth - (M_PI / 2)) * (poi.radialDistance / scale);
                elseif (poi.azimuth > M_PI and poi.azimuth < (3 * M_PI / 2)) then
                    --case3: azimiut is in the 3 quadrant of the radar
                    x = rs - math.cos((3 * M_PI / 2) - poi.azimuth) * (poi.radialDistance / scale);
                    y = rs + math.sin((3 * M_PI / 2) - poi.azimuth) * (poi.radialDistance / scale);
                elseif(poi.azimuth > (3 * M_PI / 2) and poi.azimuth < (2 * M_PI)) then
                    --case4: azimiut is in the 4 quadrant of the radar
                    x = rs - math.cos(poi.azimuth - (3 * M_PI / 2)) * (poi.radialDistance / scale);
                    y = rs - math.sin(poi.azimuth - (3 * M_PI / 2)) * (poi.radialDistance / scale);
                elseif (poi.azimuth == 0) then
                    x = rs;
                    y = rs - poi.radialDistance / scale;
                elseif(poi.azimuth == M_PI/2) then
                    x = rs + poi.radialDistance / scale;
                    y = rs;
                elseif(poi.azimuth == (3 * M_PI / 2)) then
                    x = rs;
                    y = rs + poi.radialDistance / scale;
                elseif (poi.azimuth == (3 * M_PI / 2)) then
                    x = rs - poi.radialDistance / scale;
                    y = rs;
                else 
                    ---If none of the above match we use the scenario where azimuth is 0
                    x = rs;
                    y = rs - poi.radialDistance / scale;
                end
                if (x <= radarSize and x>=-radarSize and  y <= radarSize and y>= -radarSize ) then
                    local p = display.newCircle(self.poiGroup, x, y, 2)
                    p:setFillColor(self.poiColor[1],self.poiColor[2],self.poiColor[3],self.poiColor[4])
                end
            end
        end
    end
    c:draw()
    
    return c
end


return M


