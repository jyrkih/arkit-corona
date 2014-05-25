local crypto = require "crypto"
local M = {}

function M:new(radialDistance, inclination, azimuth)
    local c = {}
    c.radialDistance = radialDistance
    c.inclination = inclination
    c.azimuth = azimuth
    c.title = ""
    c.subtitle = ""
    
    function c:isEqualToCoordinate(other)
        if other == self then
            return true
        end
        local equal = self.radialDistance == other.radialDistance
        equal = equal and self.inclination == other.inclination
        equal = equal and self.azimuth == other.azimuth
        
        if ((self.title and other.title) or (self.title and not other.title) or (not self.title and other.title)) then
		equal = equal and self.title == other.title
        end     
        return equal
    end
    
    function c:isEqual(other)
        if (other == self) then
            return true
        end
	if ( not other or other.azimuth == nil) then
            return false
        end
        
	return self:isEqualToCoordinate(other)
    end
    
    function c:description()
        return string.format("r: %.3fm φ: %.3f° θ: %.3f°", self.title, self.radialDistance, math.deg(self.azimuth), math.deg(self.inclination))
    end
    
    function c:hash()
        local input = self.title..self.subtitle..tostring(self.radialDistance + self.inclination + self.azimuth)
        return crypto.hmac(crypto.MD5, input, "mykey12345")
    end
    
    return c
end

return M

