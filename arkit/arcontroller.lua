
local arc  = require("arkit.arcoordinate")

local radar = require("arkit.radar")
local radarViewport = require("arkit.radarviewport")

local isSimulator = system.getInfo("environment")=="simulator"
local kFilteringFactor = 0.05
local degreesToRadian = math.rad
local radianToDegrees = math.deg
local M_PI = math.pi
local M_2PI = 2.0 * M_PI
local BOX_WIDTH = 150
local BOX_HEIGHT = 100
local BOX_GAP = 10
local ADJUST_BY = 30
local DISTANCE_FILTER = 2.0
local HEADING_FILTER = 1.0
local INTERVAL_UPDATE = 60
local SCALE_FACTOR = 1.0
local HEADING_NOT_SET = -1.0
local DEGREE_TO_UPDATE = 1

local kCLLocationAccuracyNearestTenMeters = 10

local M = {
}


function M:new(parentGroup, delegate)
    local c = {}
    c.latestHeading = HEADING_NOT_SET
    c.prevHeading = HEADING_NOT_SET
    
    c.cameraOrientation = system.orientation
    
    c.displayView = display.newGroup()
    c.displayView.x = display.contentCenterX
    c.displayView.y = display.contentCenterY
    
    c.parentGroup = parentGroup
    
    if c.parentGroup then
        c.parentGroup:insert(c.displayView)
    end
    
    if c.cameraOrientation == "landscapeLeft" or c.cameraOrientation == "landscapeRight" then
        c.cw  = display.contentHeight
        c.ch = display.contentWidth
    else
        c.cw  = display.contentWidth
        c.ch = display.contentHeight
    end
    
    c.degreeRange = c.cw / ADJUST_BY;
    c.viewAngle = 0
    
    c.delegate = delegate
    
    c.scaleViewsBasedOnDistance = false
    c.rotateViewsBasedOnPerspective=false
    
    c.debugMode=true
    
    c.maximumScaleDistance=0.0
    c.minimumScaleFactor= SCALE_FACTOR
    c.maximumRotationAngle= M_PI / 6.0
    
    c.centerLocation = nil
    c.centerCoordinate = nil
    c.coordinates = {}
    
    -- radar support
    c.onlyShowItemsWithinRadarRange = false
    c.showsRadar = false
    c.radarView = nil
    c.radarViewPort = nil
    c.radarRange = 0.0
    c.radarNorthLabel = nil
    
    function c:positionRadar()
        local radarSize = radar.RADIUS + 1;
        local margin = 34;
        
        if self.radarView then
            self.radarView.x = self.cw*0.5 - radarSize - margin
            self.radarView.y = -self.ch*0.5 + radarSize + margin
        end
        if self.radarViewPort then
            self.radarViewPort.x = self.cw*0.5 - radarSize - margin
            self.radarViewPort.y = -self.ch*0.5 + radarSize + margin
        end
        if self.radarNorthLabel then
            self.radarNorthLabel.x = self.radarView.x
            self.radarNorthLabel.y = self.radarView.y - self.radarView.contentHeight*0.5 + self.radarNorthLabel.contentHeight*0.5
        end  
    end
    
    function c:setShowsRadar(showRadar)
        self.showsRadar = showRadar
        if self.radarView then
            self.radarView:removeSelf()
            self.radarView = nil
        end
        if self.radarNorthLabel then
            self.radarNorthLabel:removeSelf()
            self.radarNorthLabel = nil
        end
        if self.radarViewPort then
            self.radarViewPort:removeSelf()
            self.radarViewPort = nil
        end
        
        if self.showsRadar then
            self.radarView = radar:new() 
            self.displayView:insert(self.radarView)
            
            self.radarViewPort = radarViewport:new()
            self.displayView:insert(self.radarViewPort)
            
            local opts = {
                text = "N",
                parent = self.displayView,
                font = native.systemFont,
                width=20,
                height = 20,
                align="center",
                fontSize = 16
            }
            self.radarNorthLabel = display.newText(opts)
            
            self.displayView:insert(self.radarNorthLabel)
            self.radarNorthLabel:setFillColor(1)
            
            self:positionRadar()
        end
        
    end
    
    -- radar end
    
    function c:enterFrame()
        if not isSimulator then
            --     self.displayView.preview.fill = { type="camera" }
        end
    end
    
    function c:unload()
        self:stopListening()
        self.displayView:removeSelf()
        self.displayView = nil
        
    end
    
    function c:updateCenterCoordinate()
        local adjustment = 0;
        if self.cameraOrientation=="landscapeLeft" then
            adjustment = degreesToRadian(90); 
        elseif self.cameraOrientation=="landscapeRight" then
            adjustment = degreesToRadian(-90)
        elseif self.cameraOrientation=="portraitUpsideDown" then
            adjustment = degreesToRadian(180)
        else
            adjustment = 0
        end
        self.centerCoordinate.azimuth = self.latestHeading - adjustment
	self:updateLocations()
    end
    
    function c:location(event)
        self:setCenterLocation(event)
        --print("Location of phone changed!", event.longitude, event.latitude)
        if self.delegate and self.delegate.location and type(self.delegate.location)=="function" then
            self.delegate:location(event)
        end
    end
    
    function c:heading(event)
        --if event.geographic ~= nil then
        --    self.latestHeading = math.rad(event.geographic)
        --else
        self.latestHeading = math.rad(event.magnetic)
        --end
        if (math.abs(self.latestHeading-self.prevHeading) >= math.rad(DEGREE_TO_UPDATE) or self.prevHeading == HEADING_NOT_SET) then 
            self.prevHeading = self.latestHeading
            self:updateCenterCoordinate()
            if self.delegate and self.delegate.heading and type(self.delegate.heading)=="function" then
                self.delegate:heading(event)
            end
        end
        
        if self.showsRadar then
            local gradToRotate = math.deg(self.latestHeading) -- - 22.5;
            if self.cameraOrientation=="landscapeLeft" then
                gradToRotate = gradToRotate - 90;
            end
            if self.cameraOrientation=="landscapeRight" then
                gradToRotate = gradToRotate + 90;
            end
            --if (gradToRotate < 0) then
            --    gradToRotate = 360 + gradToRotate
            --end
            print("gradToRotate",gradToRotate)
            self.radarViewPort.rotation = gradToRotate
        end
    end
    
    function c:accelerometer(acceleration)
        if self.cameraOrientation=="landscapeLeft" then
            self.viewAngle = math.atan2(acceleration.xRaw, acceleration.zRaw)
        elseif self.cameraOrientation=="landscapeRight" then
            self.viewAngle = math.atan2(-acceleration.xRaw, acceleration.zRaw)
        elseif self.cameraOrientation=="portraitUpsideDown" then
            self.viewAngle = math.atan2(-acceleration.yRaw, acceleration.zRaw)
        elseif self.cameraOrientation=="portrait" then
            self.viewAngle = math.atan2(acceleration.yRaw, acceleration.zRaw)
        end
    end
    
    function c:orientation(event)
        self.cameraOrientation = event.type
        if self.delegate and self.delegate.orientation and type(self.delegate.orientation)=="function" then
            self.delegate:orientation(event)
        end
    end
    
    function c:resize(event)
        self.prevHeading = HEADING_NOT_SET
        
        if not self.cameraOrientation:find("face") then
            print(self.cameraOrientation, "1")
            if self.cameraOrientation == "landscapeRight" then
                self.camView.rotation = -90
            elseif self.cameraOrientation == "portrait" then
                self.camView.rotation = 0
            elseif self.cameraOrientation == "landscapeLeft" then
                self.camView.rotation = 90
            elseif self.cameraOrientation == "portraitUpsideDown" then
                self.camView.rotation = 180 
            end
        else
            --faceup/facedown
        end
        c.cw  = display.contentWidth
        c.ch = display.contentHeight
        
        self.displayView.x = display.contentCenterX
        self.displayView.y = display.contentCenterY
        self.degreeRange = self.cw / ADJUST_BY;
        self:positionRadar()
        
        self:updateDebugMode(true)
    end
    
    function c:startListening()
        
        system.setLocationAccuracy( kCLLocationAccuracyNearestTenMeters )
        system.setLocationThreshold( DISTANCE_FILTER )
        system.setAccelerometerInterval( INTERVAL_UPDATE )
        
        Runtime:addEventListener( "location", c )
        Runtime:addEventListener( "heading", c )
        Runtime:addEventListener( "accelerometer", c )
        Runtime:addEventListener("orientation", c)
        Runtime:addEventListener("resize", c)
        if self.centerCoordinate == nil then
            self.centerCoordinate = arc:new(1.0,0,0)
        end
        Runtime:addEventListener("enterFrame", c)
    end
    
    function c:stopListening()
        Runtime:removeEventListener("enterFrame", c)
        
        Runtime:removeEventListener( "location", c )
        Runtime:removeEventListener("orientation", c)
        Runtime:removeEventListener( "heading", c )
        Runtime:removeEventListener( "accelerometer", c )
        Runtime:removeEventListener("resize", c)
    end
    
    
    function c:setCenterLocation(newLocation)
        self.centerLocation = newLocation
        for k,v in pairs(self.coordinates) do
            local geoLocation = k
            if geoLocation.calibrateUsingOrigin then
                local bOk = true
                if self.onlyShowItemsWithinRadarRange and geoLocation.radialDistance/1000 > self.radarRange then
                    bOk = false
                end
                if bOk then
                    geoLocation:calibrateUsingOrigin(self.centerLocation)
                    if geoLocation.radialDistance > self.maximumScaleDistance then
                        self.maximumScaleDistance = geoLocation.radialDistance
                    end
                end
            end
        end
    end
    
    
    c.camView =  display.newRect( 0,0,c.cw, c.ch)
    c.camView.x = 0
    c.camView.y = 0
    if not isSimulator then
        c.camView.fill = { type="camera" }
    else
        c.camView:setFillColor(0.4)
    end
    c.displayView:insert(c.camView)
    c.camView:toBack()
    
    
    -- coordinate methods
    function c:addCoordinate(coordinate)
        self.coordinates[coordinate] = 1
        if coordinate.radialDistance > self.maximumScaleDistance then
            self.maximumScaleDistance = coordinate.radialDistance
        end
    end
    
    function c:removeCoordinate(coordinate)
        self.coordinates[coordinate] = nil
    end
    
    function c:removeCoordinates(coordinates)
        for k,v in ipairs(coordinates) do
            self.coordinates[k] = nil
        end
    end
    
    -- location methods
    function c:findDeltaOfRadianCenter(centerAzimuth, pointAzimuth)
        if centerAzimuth < 0.0 then
            centerAzimuth = M_2PI + centerAzimuth;
        end
        
	if (centerAzimuth > M_2PI) then
            centerAzimuth = centerAzimuth - M_2PI;
        end
        
	local deltaAzimuth = math.abs(pointAzimuth - centerAzimuth);
	local isBetweenNorth = false;
        
	-- If values are on either side of the Azimuth of North we need to adjust it.  Only check the degree range
        if (centerAzimuth < math.rad(self.degreeRange) and pointAzimuth > math.rad(360-self.degreeRange)) then
            deltaAzimuth	= (centerAzimuth + (M_2PI - pointAzimuth))
            isBetweenNorth = true
        elseif (pointAzimuth < math.rad(self.degreeRange) and centerAzimuth > math.rad(360-self.degreeRange)) then
            deltaAzimuth	= (pointAzimuth + (M_2PI - centerAzimuth));
            isBetweenNorth = true
        end
        
        return deltaAzimuth, isBetweenNorth
    end
    
    function c:shouldDisplayCoordinate(coordinate)
        local currentAzimuth = self.centerCoordinate.azimuth
	local pointAzimuth	  = coordinate.azimuth
	local isBetweenNorth	  = false
	local deltaAzimuth,isBetweenNorth = self:findDeltaOfRadianCenter(currentAzimuth,pointAzimuth)
	local result = false
        
	if (deltaAzimuth <= degreesToRadian(self.degreeRange)) then
            result = true
        end
        if self.onlyShowItemsWithinRadarRange then
            print(coordinate.title, self.radarRange, coordinate.radialDistance)
            if(coordinate.radialDistance  > self.radarRange) then
                result = false
            end
        end
        
        
        return result;
    end
    
    function c:pointForCoordinate(coordinate)
        local point = {x=0,y=0}
        
        local realityBounds	=  self.displayView
        local currentAzimuth	= self.centerCoordinate.azimuth
        local pointAzimuth		= coordinate.azimuth
        local isBetweenNorth		= false
        local deltaAzimuth,isBetweenNorth = self:findDeltaOfRadianCenter(currentAzimuth,pointAzimuth)
        
        if ((pointAzimuth > currentAzimuth and not isBetweenNorth) or 
            (currentAzimuth > degreesToRadian(360- self.degreeRange) and pointAzimuth < degreesToRadian(self.degreeRange))) then
            point.x =  ((deltaAzimuth / degreesToRadian(1)) * ADJUST_BY); --+(realityBounds.contentWidth / 2) + -- Right side of Azimuth
            
        else
            point.x =  - ((deltaAzimuth / degreesToRadian(1)) * ADJUST_BY); --(realityBounds.contentWidth / 2)	-- Left side of Azimuth
        end
        local radialDistanceKm = coordinate.radialDistance / 1000;
        local yFactor = radialDistanceKm / self.radarRange;
        local ySpan = realityBounds.contentHeight / 3;
        point.y = - (ySpan / 2) + yFactor * ySpan --(realityBounds.contentHeight / 2) ;
        point.py =  radianToDegrees(M_2PI + self.viewAngle)  * 2.0 -(realityBounds.contentHeight / 2) --+
        
        return point; 
    end
    
    function c:setDebugText(text)
        if self.debugView then
            self.debugView.text = text
            self.debugView.x = -c.cw*0.5 + self.debugView.contentWidth*0.5 + 20
            self.debugView.y = c.ch*0.5 - 20
        end
    end
    
    function c:updateLocations()
        self:setDebugText( string.format("%.3f %.3f", -radianToDegrees(self.viewAngle), radianToDegrees(self.centerCoordinate.azimuth)))
        local i=0
        local radarPointValues = {}
        
        for k,_ in pairs(self.coordinates) do
            i = i + 1
            local marker = k.displayView
            if self:shouldDisplayCoordinate(k) then
                local loc = self:pointForCoordinate(k)
                local scaleFactor = SCALE_FACTOR
                if self.scaleViewsBasedOnDistance then
                    scaleFactor = math.max(0.4,scaleFactor - self.minimumScaleFactor*(k.radialDistance / self.maximumScaleDistance))
                end
                --local width  = marker.contentWidth  * scaleFactor
                --local height = marker.contentHeight * scaleFactor
                marker.x = loc.x -- width / 2.0
                marker.y = loc.y
                
                
                if (self.scaleViewsBasedOnDistance) then
                    --transform = CATransform3DScale(transform, scaleFactor, scaleFactor, scaleFactor);
                    marker:scale(scaleFactor, scaleFactor)
                end
                self.displayView:insert(marker)
                marker.alpha = 1
            else
                marker.alpha = 0
            end
            radarPointValues[#radarPointValues+1] = k
        end
        
        if self.showsRadar then
            self.radarView:draw(radarPointValues, self.radarRange)
        end
    end
    
    local function LocationSortClosestFirst(s1, s2)
        if (s1.radialDistance < s2.radialDistance) then 
            return 1;
        elseif (s1.radialDistance > s2.radialDistance) then 
            return -1;
        else 
            return 0;
        end
    end
    
    --debug functions
    function c:updateDebugMode(flag)
        
        if self.debugMode == flag then
            local opts = 
            {
                text = "aa",
                parent = self.displayView,
                x = 0,
                y = display.contentHeight - 20,     --required for multi-line and alignment
                font = native.systemFont,
                
                fontSize = 18
            }
            
            
            if self.debugView == nil then
                self.debugView = display.newText(opts)
                self.displayView:insert(self.debugView)
                self.debugView:setFillColor(0,0,0)
            end
        end
        if self.debugView then
            if self.debugMode == true then
                self.debugView.text = "Waiting..."
                self.debugView.x = -c.cw*0.5 + self.debugView.contentWidth*0.5 + 20
                self.debugView.y = c.ch*0.5 - self.debugView.contentHeight*0.5 - 10
                self.debugView.alpha = 1
            else
                self.debugView.alpha = 0
            end
        end
    end
    
    --[[local newCenter = {}
    newCenter.longitude = 24.9354500
    newCenter.latitude = 60.16952
    c:setCenterLocation(newCenter)]]--
    
    c:resize()
    
    c:startListening()
    
    return c
end


return M

