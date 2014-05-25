
local M = {}

function M:new(delegate)
    local c = {}
    c.delegate = delegate
    
    function c:returnLocations()
        if self.delegate and type(self.delegate.geoLocations) == "table" then
            return (self.delegate.geoLocations)
        end
    end
    return c
end

return M
