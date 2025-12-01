ESX = exports['es_extended']:getSharedObject()

local Jobs = {
    ['ambulance'] = true,
    ['bahama'] = true,
    ['burgershot'] = true,
    ['cardealer'] = true,
    ['casino'] = true,
    ['cityhall'] = true,
    ['farmer'] = true,
    ['hornys'] = true,
    ['koi'] = true,
    ['mechanic'] = true,
    ['offpolice'] = true,
    ['offsheriff'] = true,
    ['pearl'] = true,
    ['pizza'] = true,
    ['police'] = true,
    ['realestate'] = true,
    ['sheriff'] = true,
    ['tattoo_artist_city'] = true,
    ['tattoo_artist_north'] = true,
    ['unemployed'] = true,
    ['unicorn'] = true,
    ['uwu'] = true
}

local AvailableJobs = {}
local ParkingAreas = {}


IsJobAllowed = function(playerJob, parkingArea)
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

IsPublicParking = function(parkingArea)
    
    local restrictedJobs = ParkingAreas[parkingArea].restricted
    local restrictedJobCount = #restrictedJobs

    return not (restrictedJobCount > 0)
end

DoesParkingExist = function(parking)
    return ParkingAreas[parking] ~= nil
end

exports('IsJobAllowed', IsJobAllowed)
exports('IsPublicParking', IsPublicParking)
exports('DoesParkingExist', DoesParkingExist)

local IsLoaded = false
exports('IsLoaded', function() return IsLoaded end)

Citizen.CreateThread(function()
    while not MySQL.isReady() do Wait(1) end

    local jobs = MySQL.query.await("SELECT * FROM jobs")

    AvailableJobs = {}
    for _,v in ipairs(jobs) do
        if Jobs[v.name] then
            print("adding job",v.name)
            AvailableJobs[v.name] = {label = v.label}
        else
            print("not adding job",v.name)
        end
    end

    MySQL.query('SELECT `name`, `data`, `restricted` FROM `parking_areas` WHERE 1', {}, function(response)
        if response then
            for i = 1, #response do
                local row = response[i]
                ParkingAreas[row.name] = {data = json.decode(row.data), restricted = row.restricted and json.decode(row.restricted) or {}}
            end
            Wait(5000)
            print("sending data")
            TriggerClientEvent(GetCurrentResourceName() .. ':Load', -1, ParkingAreas, AvailableJobs)
            IsLoaded = true
        end
    end)
end)

-- AddEventHandler('onResourceStart', function(resName)
--     if resName == GetCurrentResourceName() then
--     end
-- end)

AddEventHandler('esx:playerLoaded', function(player, xPlayer, isNew)
    TriggerClientEvent(GetCurrentResourceName() .. ':Load', player, ParkingAreas, AvailableJobs)
end)

ESX.RegisterServerCallback(GetCurrentResourceName() .. ':createZone', function(source, cb, input, data)
    data = {
        name = data.name,
        points = data.points,
        thickness = data.thickness,
        debugColour = data.debugColour
    }
    local restrictedJobs = input[2] and input[2] or {}
    print("restricted: ",json.encode(restrictedJobs))
    local name = input[1]
    name = name:gsub("%s+", "")
    if name == nil or name == "" or name == " " or ParkingAreas[name] ~= nil or name == 'public' then
        cb(false)
    else
        MySQL.insert('INSERT INTO `parking_areas` (name, data, restricted) VALUES (?, ?, ?)', {
            name, json.encode(data), json.encode(restrictedJobs)
        }, function(id)
            print("created", name, id)
            ParkingAreas[name] = {data = data, restricted = restrictedJobs}
            TriggerClientEvent(GetCurrentResourceName() .. ':AddParkingArea', -1, name, ParkingAreas[name])
            cb(true)
        end)
    end
end)

ESX.RegisterServerCallback(GetCurrentResourceName() .. ':deleteZone', function(source, cb, name)
    name = name:gsub("%s+", "")
    if name == nil or name == "" or name == " " or ParkingAreas[name] == nil then
        cb(false)
    else
        local vehiclesInParking = exports.RealParking:GetVehiclesInParking(name)
        print("#vehiclesInParking", #vehiclesInParking)
        if #vehiclesInParking then
            for k,plate in pairs(vehiclesInParking) do
                print("impounding", plate)
                exports.RealParking:ImpoundVehicle(plate, function(success, message)
                    print(success, message)
                end)
            end
        end
        -- cb(true)
        MySQL.query('DELETE FROM `parking_areas` WHERE `name` = ?', {
            name
        }, function(rowsChanged)
            print("deleted", name)
            ParkingAreas[name] = nil
            TriggerClientEvent(GetCurrentResourceName() .. ':RemoveParkingArea', -1, name)
            cb(true)
        end)
    end
end)