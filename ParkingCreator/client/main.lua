ESX = exports['es_extended']:getSharedObject()

ParkingAreas = {}

GetParkingAreaByCoords = function(coords)
    local parkingArea = nil
    for k,v in pairs(ParkingAreas) do
        if v.poly:contains(coords) then
            parkingArea = k
            break
        end
    end
    return parkingArea
end

GetParkingAreaById = function(id)
    local parkingArea = nil
    for k,v in pairs(ParkingAreas) do
        if v.poly.id == id then
            parkingArea = k
            break
        end
    end
    return parkingArea
end

IsJobAllowed = function(parkingArea)
    local playerJob = ESX.GetPlayerData().job.name
    local restrictedJobs = ParkingAreas[parkingArea].restricted
    local restrictedJobCount = #restrictedJobs

    if restrictedJobCount > 0 then
        for i=1,restrictedJobCount do
            if playerJob == restrictedJobs[i] then
                return true
            end
        end
        
        return false

    else
        return true
    end
    
end

GetNearestParkingAreas = function(dist)
    -- return all the nearest parking areas from player's location
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)

    local parkingAreas = {}
    for k, v in pairs(ParkingAreas) do
        local closestPoint, closestDistance = findClosestCoord(playerPos, v.poly.points, dist)

        if closestPoint ~= nil then
            parkingAreas[k] = true
            -- table.insert( parkingAreas, k )
        end
    end
    
    return parkingAreas
end

GetNearestParkingArea = function(dist)
    -- return nearest parking area from player's location
    local ped = PlayerPedId()
    local playerPos = GetEntityCoords(ped)

    local parkingArea = GetParkingAreaByCoords(playerPos)

    if parkingArea == nil then
        print("not inside area. finding nearby areas")
        local closestPoint, closestDistance = nil, nil
        for k, v in pairs(ParkingAreas) do
            local _closestPoint, _closestDistance = findClosestCoord(playerPos, v.poly.points, dist)

            if _closestPoint ~= nil then
                if closestPoint == nil or _closestDistance < closestDistance then
                    closestPoint = _closestPoint
                    closestDistance = _closestDistance
                    parkingArea = k
                end
            end
        end
    end
    
    return parkingArea
end

function findAllClosestCoords(targetCoord, coordList, radius)
    local closestCoords = {}

    for _, coord in ipairs(coordList) do
        local distance = #(targetCoord - coord)
        if radius == -1 or distance <= radius then
            table.insert(closestCoords, {coord = coords, distance = distance})
        end
    end

    return closestCoords
end

function findClosestCoord(targetCoord, coordList, radius)
    local closestCoord = nil
    local closestDistance = math.huge

    for _, coord in ipairs(coordList) do
        local distance = #(vector3(targetCoord.x, targetCoord.y, targetCoord.z) - vector3(coord.x, coord.y, coord.z))
        if (radius == -1 or distance <= radius) and distance < closestDistance then
            closestDistance = distance
            closestCoord = coord
        end
    end

    return closestCoord, closestCoord ~= nil and closestDistance or 0
end

-- RegisterCommand('GetNearestParkingArea', function(source, args)
--     local radius = (args[1] and tonumber(args[1])) and tonumber(args[1]) or 50.0
--     local parkingArea = GetNearestParkingArea(radius)
--     ESX.ShowNotification( "Nearest Parking Area ("..radius.."): " .. tostring(parkingArea) )
-- end)
-- RegisterCommand('GetNearestParkingAreas', function(source, args)
--     local radius = (args[1] and tonumber(args[1])) and tonumber(args[1]) or 50.0
--     local parkingAreas = GetNearestParkingAreas(radius)
--     ESX.ShowNotification( "Nearest Parking Areas ("..radius.."): " .. table.concat( parkingAreas, ", ") )
-- end)

exports('GetParkingAreaByCoords', GetParkingAreaByCoords)
exports('GetNearestParkingArea', GetNearestParkingArea)
exports('GetNearestParkingAreas', GetNearestParkingAreas)
exports('GetParkingAreaById', GetParkingAreaById)
exports('GetAllParkings', GetAllParkings)
exports('IsJobAllowed', IsJobAllowed)