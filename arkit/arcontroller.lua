
local arc  = require("arkit.arcoordinate")

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
local INTERVAL_UPDATE = 0.75
local SCALE_FACTOR = 1.0
local HEADING_NOT_SET = -1.0
local DEGREE_TO_UPDATE = 1

local kCLLocationAccuracyNearestTenMeters = 10

local M = {
}


function M:new(view, parentGroup, delegate)
    local c = {}
    c.latestHeading = HEADING_NOT_SET
    c.prevHeading = HEADING_NOT_SET
    c.degreeRange = view.contentWidth / ADJUST_BY;
    c.viewAngle = 0
    c.cameraOrientation = system.orientation
    
    c.parentGroup = parentGroup
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
    
    
    function c:enterFrame()
        if not isSimulator then
            self.displayView.preview.fill = { type="camera" }
        end
    end
    
    function c:unload()
        Runtime:removeEventListener("enterFrame", c)
        self.displayView:removeSelf()
        self.displayView = nil
    end
    
    function c:updateCenterCoordinate()
        local adjustment = 0;
        if self.cameraOrientation=="landscapeLeft" then
            adjustment = degreesToRadian(270); 
        elseif self.cameraOrientation=="landscapeRight" then
            adjustment = degreesToRadian(90)
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
        --print("Location of phone changed!")
        if self.delegate and self.delegate.location and type(self.delegate.location)=="function" then
            self.delegate:location(event)
        end
    end
    
    function c:heading(event)
        if event.geographic ~= nil then
            self.latestHeading = math.rad(event.geographic)
        else
            self.latestHeading = math.rad(event.magnetic)
        end
        if (math.abs(self.latestHeading-self.prevHeading) >= math.rad(DEGREE_TO_UPDATE) or self.prevHeading == HEADING_NOT_SET) then 
            self.prevHeading = self.latestHeading
            self:updateCenterCoordinate()
            if self.delegate and self.delegate.heading and type(self.delegate.heading)=="function" then
                self.delegate:heading(event)
            end
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
                self.displayView.preview.rotation = -90
            elseif self.cameraOrientation == "portrait" then
                self.displayView.preview.rotation = 0
            elseif self.cameraOrientation == "landscapeLeft" then
                self.displayView.preview.rotation = 90
            elseif self.cameraOrientation == "portraitUpsideDown" then
                self.displayView.preview.rotation = 180 
            end
        else
            --faceup/facedown
        end
        self.displayView.x=display.contentCenterX
        self.displayView.y = display.contentCenterY
        self.degreeRange = self.displayView.contentWidth / ADJUST_BY;
        self:updateDebugMode(true)
    end
    
    function c:startListening()
        
        system.setLocationAccuracy( kCLLocationAccuracyNearestTenMeters )
        system.setLocationThreshold( DISTANCE_FILTER )
        system.setAccelerometerInterval( 1/INTERVAL_UPDATE )
        
        Runtime:addEventListener( "location", c )
        Runtime:addEventListener( "heading", c )
        Runtime:addEventListener( "accelerometer", c )
        Runtime:addEventListener("orientation", c)
        Runtime:addEventListener("resize", c)
        if self.centerCoordinate == nil then
            self.centerCoordinate = arc.new(1.0,0,0)
        end
    end
    
    function c:stopListening()
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
                geoLocation:calibrateUsingOrigin(self.centerLocation)
                if geoLocation.radialDistance > self.maximumScaleDistance then
                    self.maximumScaleDistance = geoLocation.radialDistance
                end
            end
        end
    end
    
    
    local previewLayer =  display.newRect(view, 0,0,display.contentWidth, display.contentHeight)
    previewLayer.x = 0
    previewLayer.y = 0
    --
    view.preview = previewLayer
    
    
    Runtime:addEventListener("enterFrame", c)
    
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
        print("shouldDisplayCoordinate", result)
        
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
        
	point.y =  (radianToDegrees(M_2PI + self.viewAngle)  * 2.0) -(realityBounds.contentHeight / 2) --+
  	
	return point; 
    end
    function c:setDebugText(text)
        if self.debugView then
            self.debugView.text = text
            self.debugView.x = -display.contentWidth*0.5 + self.debugView.contentWidth*0.5 + 20
            self.debugView.y = display.contentHeight*0.5 - 20
        end
    end
    function c:updateLocations()
        self:setDebugText( string.format("%.3f %.3f ", -radianToDegrees(self.viewAngle), radianToDegrees(self.centerCoordinate.azimuth)))
        local i=0
        for k,v in pairs(self.coordinates) do
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
                self.debugView.x = -display.contentWidth*0.5 + self.debugView.contentWidth*0.5 + 20
                self.debugView.y = display.contentHeight*0.5 - 20
                self.debugView.alpha = 1
            else
                self.debugView.alpha = 0
            end
        end
    end
    
    local newCenter = {}
    newCenter.longitude = -122.02528
    newCenter.latitude = 37.41711
    c:setCenterLocation(newCenter)
    
    c.displayView = view
    c:startListening()
    c:resize()
    return c
end


return M

