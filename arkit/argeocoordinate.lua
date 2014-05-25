
local arc = require("arkit.arcoordinate")
local R = {km=6373, mile=3961}

local function distance(pos1, pos2)
    local lat1 = math.rad(pos1.latitude);
    local lon1 = math.rad(pos1.longitude);
    local lat2 = math.rad(pos2.latitude);
    local lon2 = math.rad(pos2.longitude);
    
    local dlon = lon2 - lon1
    local dlat = lat2 - lat1
    local a = (math.sin(dlat/2))^2 + math.cos(lat1) * math.cos(lat2) * (math.sin(dlon/2))^2
    local c = 2 * math.atan2( math.sqrt(a), math.sqrt(1-a) )
    local distance = R.km * c
    return distance
end

local function bearing(pos1, pos2)
    --bearing
    local lat1 = math.rad(pos1.latitude);
    local lon1 = math.rad(pos1.longitude);
    local lat2 = math.rad(pos2.latitude);
    local lon2 = math.rad(pos2.longitude);
    local y = math.sin(lon2-lon1) * math.cos(lat2)
    local x = math.cos(lat1)*math.sin(lat2) - math.sin(lat1)*math.cos(lat2)*math.cos(lon2-lon1);
    local bearing = math.deg(math.atan2(y, x));
    return  bearing
end

local function angleFromCoordinate(first, second)
    local longitudinalDifference	= second.longitude - first.longitude;
    local latitudinalDifference		= second.latitude  - first.latitude;
    local possibleAzimuth           = (math.pi * .5) - math.atan(latitudinalDifference / longitudinalDifference);
    
    if (longitudinalDifference > 0) then
        return possibleAzimuth;
    elseif (longitudinalDifference < 0) then
        return possibleAzimuth + math.pi;
    elseif (latitudinalDifference < 0) then
        return math.pi;
    end
    return 0.0;
end

local M  = {}

function M:coordinateWithLocation(location, title, fromOrigin)
    local argeo = arc.new()
    function argeo:calibrateUsingOrigin(origin)
        if not self.geoLocation then
            return
        end
        self.distanceFromOrigin = distance(origin, self.geoLocation)
        self.radialDistance = math.sqrt(math.pow(origin.altitude - self.geoLocation.altitude, 2) + math.pow(self.distanceFromOrigin, 2))
        local angle = math.sin(math.abs(origin.altitude - self.geoLocation.altitude) / self.radialDistance);
        if (origin.altitude > self.geoLocation.altitude)  then
            angle = -angle;
        end
        self.setInclination = angle;
        self.azimuth = angleFromCoordinate(origin, self.geoLocation);
        print(string.format("distance from %s is %f, angle is %f, azimuth is %f",self.title, self.distanceFromOrigin, angle, self.azimuth))
    end
    
    argeo.geoLocation = location
    argeo.title = title
    argeo.distanceFromOrigin = 0.0
    argeo.displayView = nil
    
    if fromOrigin then
        argeo:calibrateUsingOrigin(fromOrigin)
    end
    return argeo
end

return M;
