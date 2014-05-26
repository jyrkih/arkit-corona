
local ar = require("arkit.arkit")

print(ar.deviceSupportsAR())
local isSimulator = system.getInfo("environment")=="simulator"

local pointsOfInterest = {
    
    {longitude = -73.994901,latitude = 41.145495,altitude = 30, title="New York"},
    {longitude = 24.9354500,latitude = 60.1695200,altitude = 30, title="Helsinki"},
    {longitude = 33.0788,latitude = 68.969,altitude = 30, title="Murmansk"},
    {longitude =  -3.696111,latitude = 40.416667,altitude = 30, title="Madrid"},
}


local ds = display.getCurrentStage()
local delegate = {}

local _locations=nil
local _userLocation = nil

local controller = nil


local function setMarkerView(coord)
    coord.displayView = display.newGroup()
    coord.displayView.anchorChildren = true
    coord.displayView.x = 0
    coord.displayView.y = 0
    local c = display.newCircle(coord.displayView, 0, 0, 20)
    c:setFillColor(1,0,0,0.5)
    local opts = 
    {
        text = coord.title,
        parent = coord.displayView,
        x = 0,
        y = 30,     --required for multi-line and alignment
        font = native.systemFont,
        fontSize = 18
    }
    display.newText(opts)
end


local function setupLocations()
    _locations = {}
    for i=1, #pointsOfInterest do
        local poi = pointsOfInterest[i]
        local c1 = ar.argeocoordinate:coordinateWithLocation(poi, poi.title)
        c1:calibrateUsingOrigin(_userLocation)
        setMarkerView(c1)
        controller:addCoordinate(c1)
        _locations[#_locations+1] = c1
    end
end

function delegate:location(event)
    local init = false
    if not _userLocation then
        init = true
    end
    _userLocation = event
    if init then
        pcall(self.geoLocations)
    end
    --print("delegate.location()", event.longitude, event.latitude, event.altitude)
end

function delegate:heading(event)
    --print("delegate.heading()", event)
end

function delegate:orientation(event)
    --print("delegate.orientation()", event.type)
end



function delegate:geoLocations()
    if  _locations == nil then
        setupLocations()
    end
    return _locations
end

controller = ar.arcontroller:new(ds, delegate)
controller.radarRange = 3000
controller:setShowsRadar(true)
controller.onlyShowItemsWithinRadarRange = true

local function updater()
    
    local event = {}
    event.name = "location"
    event.longitude = 24.9354500
    event.latitude = 60.16952
    event.altitude = 40
    Runtime:dispatchEvent(event)
    
end

local gHeading = 240  
local function header()
    local event = {}
    event.name = "heading"
    event.magnetic = gHeading
    Runtime:dispatchEvent(event)
    gHeading = gHeading - 30
end

if isSimulator then
    timer.performWithDelay(1000,updater)
    timer.performWithDelay(1100,header, 1)
end
