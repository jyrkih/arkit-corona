

local M = {}
M.argeocoordinate = require("arkit.argeocoordinate")
M.arcontroller = require("arkit.arcontroller")
M.argeolocations = require("arkit.geolocations")

function M:deviceSupportsAR()
    local res = true
    if system.getInfo("environment")=="simulator" then
        res = false
    end
    if not system.hasEventSource( "gyroscope" ) and not system.hasEventSource( "heading" ) then
       res = false 
    end
    
    return res
end

return M
