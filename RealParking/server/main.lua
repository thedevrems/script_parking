ESX = exports['es_extended']:getSharedObject()

ParkedVehicles = {}

VehiclesInCell = {}

ImpoundingVehicles = {}

IsVehicleParked = function(plate)
    return ParkedVehicles[plate] ~= nil
end
GetVehicleParking = function(plate)
    return ParkedVehicles[plate] and ParkedVehicles[plate].parking or nil
end
GetVehiclesInParking = function(parking)
    local vehicles = {}
    for plate, vehicle in pairs(ParkedVehicles) do
        if vehicle.parking == parking then
            table.insert(vehicles, plate)
        end
    end

    return vehicles
end

exports('IsVehicleParked', IsVehicleParked)
exports('GetVehicleParking', GetVehicleParking)
exports('GetVehiclesInParking', GetVehiclesInParking)

RegisterCommand('remp', function(source, args, raw)
   if args[1] then
    local length = #("remp")
    local plate = raw:sub(length+1, #raw)
    exports['qs-advancedgarages']:removeVehicleFromPersistent(plate)
    print("removed persistence from", plate)
   end 
end)

Citizen.CreateThread(function()
    while not exports.ParkingCreator:IsLoaded() do Wait(100) end

    MySQL.query('SELECT * FROM `parked_vehicles` WHERE 1', {}, function(response)
        if response then
            local all_data = {}
            for i = 1, #response do
                local row = response[i]

                if exports.ParkingCreator:DoesParkingExist(row.parking) then
                    local position = json.decode(row.position)
                    local properties = json.decode(row.properties)
                    local data = json.decode(row.data)
                    
                    AddParkedVehicle({
                        parking = row.parking,
                        plate = row.plate,
                        position = vec3(position.x, position.y, position.z),
                        rotation = vec3(position.rx, position.ry, position.rz),
                        properties = properties,
                        data = data
                    })
                else
                    MySQL.query('DELETE FROM `parked_vehicles` WHERE `plate` = ?', {row.plate}, function(rowsChanged)
                        print('impounding', row.plate)
                        -- exports['qs-advancedgarages']:impound(plate)
                    end)
                end

            end
            Wait(5000)
            TriggerClientEvent(ResourceName .. ':Load', -1, VehiclesInCell, ParkedVehicles)
        end
    end)
end)

AddParkedVehicle = function(vehData, update, vehicle)
    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if not VehiclesInCell[gridX] then
        VehiclesInCell[gridX] = {}
    end
    if not VehiclesInCell[gridX][gridY] then
        VehiclesInCell[gridX][gridY] = {}
    end
    
    if ParkedVehicles[vehData.plate] == nil then
        ParkedVehicles[vehData.plate] = vehData
        VehiclesInCell[gridX][gridY][vehData.plate] = vehData.position

        print(vehData.position)
        
        if update then 
            exports['qs-advancedgarages']:removeVehicleFromPersistent(vehData.plate)
            TriggerClientEvent(ResourceName .. ':VehicleAdded', -1, vehData, vehicle)
        end

        return true
    else
        return false
    end
end

exports('RemoveParkedVehicle', function(plate, cb)
    if ParkedVehicles[plate] then
        MySQL.query('DELETE FROM `parked_vehicles` WHERE `plate` = ?', {plate}, function(rowsChanged)
            cb()
            RemoveParkedVehicle(ParkedVehicles[plate], true, nil)
        end)
    end
end)

function RemoveParkedVehicle(vehData, update, vehicle)
    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if ParkedVehicles[vehData.plate] ~= nil then
        ParkedVehicles[vehData.plate] = nil
    
        if VehiclesInCell[gridX] and VehiclesInCell[gridX][gridY] then
            VehiclesInCell[gridX][gridY][vehData.plate] = nil
        end
    
        if update then
            -- exports['qs-advancedgarages']:setVehicleToPersistent(vehicle)
            TriggerClientEvent(ResourceName .. ':VehicleRemoved', -1, vehData.plate, vehicle)
        end

        return true
    else
        return false
    end
end

RegisterServerEvent(ResourceName .. ':SetVehiclePersistent', function(vehicle, netID)
    local net_to_veh = NetworkGetEntityFromNetworkId(netID)
    print(vehicle, netID, net_to_veh, DoesEntityExist(veh), DoesEntityExist(netID), DoesEntityExist(net_to_veh))
    exports['qs-advancedgarages']:setVehicleToPersistent(net_to_veh)
end)

RegisterServerEvent('setpersistent')
AddEventHandler('setpersistent', function(veh)
    print("setting veh pers", veh)
exports['qs-advancedgarages']:setVehicleToPersistent(veh)
end)

function ImpoundVehicle(vehData, cb)
    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if ParkedVehicles[vehData.plate] ~= nil then

        MySQL.query('DELETE FROM `parked_vehicles` WHERE `plate` = ?', {vehData.plate}, function(rowsChanged)
            MySQL.query('UPDATE `owned_vehicles` SET `garage` = ?, `impound_data` = ? WHERE `plate` = ?', {
                "Hayes Autos",
                json.encode({
                    time = os.time(),
                    note = "Greetings from RealParking",
                    selectedGarage = "Hayes Autos",
                    price = 1000,
                    getByPay = "yes"
                }),
                vehData.plate
            }, function(rowsChanged)
                ParkedVehicles[vehData.plate] = nil
            
                if VehiclesInCell[gridX] and VehiclesInCell[gridX][gridY] then
                    VehiclesInCell[gridX][gridY][vehData.plate] = nil
                end
        
                cb(true)
            end)
        end)

    else
        cb(false)
    end
end

exports('ImpoundVehicle', function(plate, cb)
    if ImpoundingVehicles[plate] then
        cb(false, "This vehicle is currently being impounded")
        return
    end

    if not ParkedVehicles[plate] then
        cb(false, "This vehicle is not parked")
        return
    end

    ImpoundVehicle(ParkedVehicles[plate], function(success)
        if success then
            TriggerClientEvent(ResourceName .. ':VehicleImpounded', -1, plate)
            cb(true, "Successfuly impounded the vehicle")

        else
            cb(false, "Failed to impound vehicle")
        end
    end)
end)

AddEventHandler('esx:playerLoaded', function(player, xPlayer, isNew)
    TriggerClientEvent(ResourceName .. ':Load', player, VehiclesInCell, ParkedVehicles)
end)

ESX.RegisterServerCallback(ResourceName .. ':ImpoundVehicle', function(source, cb, plate)
    if ImpoundingVehicles[plate] then
        cb(false, "This vehicle is currently being impounded")
        return
    end

    if not ParkedVehicles[plate] then
        cb(false, "This vehicle is not parked")
        return
    end

    ImpoundVehicle(ParkedVehicles[plate], function(success)
        if success then
            TriggerClientEvent(ResourceName .. ':VehicleImpounded', -1, plate)
            cb(true, "Successfuly impounded the vehicle")

        else
            cb(false, "Failed to impound vehicle")
        end
    end)

end)
RegisterServerEvent(ResourceName ..':FinalizeImpound', function(plate, vehicle)
    local src = source

    -- if not ParkedVehicles[plate] then
    --     print("Vehicle is not parked")
    --     return
    -- end

    -- local vehData = ParkedVehicles[plate]

    -- if not ImpoundingVehicles[plate] then
    --     print("Vehicle not being impounded")
    --     TriggerClientEvent(ResourceName .. ':VehicleAdded', -1, vehData)
    --     return
    -- end

    -- if ImpoundingVehicles[plate].by ~= src then
    --     print("You are not the one impounding this vehicle")
    --     TriggerClientEvent(ResourceName .. ':VehicleAdded', -1, vehData)
    --     return
    -- end

    MySQL.query('DELETE FROM `parked_vehicles` WHERE `plate` = ?', {plate}, function(rowsChanged)
        MySQL.query('UPDATE `parked_vehicles` SET `garage` = ?, `impound_data` = ? WHERE `plate` = ?', {
            "Strawberry",
            json.encode({
                time = os.time(),
                note = "Greetings from RealParking",
                selectedGarage = "Strawberry",
                price = 1000,
                getByPay = "yes"
            }),
            plate
        }, function(rowsChanged)
            -- DeleteVehicle(vehicle)
            RemoveParkedVehicle(ParkedVehicles[plate], true)
        end)
        -- exports['qs-advancedgarages']:impound(plate)
        --[[
            {"time":1729675352,"note":"huh","selectedGarage":"Strawberry","price":"1000","getByPay":"yes"}
        ]]
    end)
    
end)

ESX.RegisterServerCallback(ResourceName .. ':ParkVehicle', function(source, cb, vehData, vehicle, parking)

    if ImpoundingVehicles[vehData.plate] then
        cb(false, "This vehicle is currently being impounded")
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local playerJob = xPlayer.getJob().name

    MySQL.query('SELECT `jobVehicle`, `owner` FROM `owned_vehicles` WHERE plate = ?', { vehData.plate }, function(response)
        if not response[1] then
            cb(false, 'This vehicle does not belong to anyone')
            return
        end

        -- local vehicleJob = response[1].job
        local vehicleJob = response[1].jobVehicle -- JOB EDIT
        
        if vehicleJob ~= '' then
            -- job vehicle

            print("vehicleJob",vehicleJob)
            if exports.ParkingCreator:IsPublicParking(parking) then
                cb(false, 'This parking is reserved for personal vehicles')
                return
            end

            if playerJob ~= vehicleJob then
                -- player is not part of the organization from which the vehicle belongs to
                cb(false, 'This vehicle does not belong to your organization')
                return
            else
                if not exports.ParkingCreator:IsJobAllowed(vehicleJob, parking) then
                    cb(false, 'This vehicle cannot be parked here')
                    return
                end
            end
        else
            -- personal vehicle

            if not exports.ParkingCreator:IsPublicParking(parking) then
                cb(false, 'This parking is reserved for organization vehicles')
                return
            end

            local owner = response[1].owner

            if owner ~= identifier then
                cb(false, 'This vehicle does not belong to you')
                return
            end
        end

        MySQL.query('INSERT INTO `parked_vehicles` (plate, owner, name, position, properties, data, time, parking) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            vehData.plate, xPlayer.getIdentifier(), xPlayer.getName(), json.encode({
                x = vehData.position.x,
                y = vehData.position.y,
                z = vehData.position.z,
                rx = vehData.rotation.x,
                ry = vehData.rotation.y,
                rz = vehData.rotation.z
            }),
            json.encode(vehData.properties), json.encode(vehData.data), os.time(), parking
        }, function(rowsChanged)
            cb(true)
            AddParkedVehicle(vehData, true, vehicle)
        end)
    end)
end)

ESX.RegisterServerCallback(ResourceName .. ':RetrieveVehicle', function(source, cb, plate, vehicle, parking)

    if ImpoundingVehicles[plate] then
        cb(false, "This vehicle is currently being impounded")
        return
    end

    if not ParkedVehicles[plate] then
        cb(false, 'This vehicle is not parked')
        return
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    local identifier = xPlayer.getIdentifier()
    local playerJob = xPlayer.getJob().name

    MySQL.query('SELECT `owner`, `jobVehicle` FROM `owned_vehicles` WHERE `plate` = ?', { plate }, function(response)
        if not response[1] then
            cb(false, 'This vehicle is not owned by anyone')
            return
        end
        
        if exports.ParkingCreator:IsPublicParking(parking) then
            local owner = response[1].owner

            if owner ~= identifier then
                cb(false, 'This vehicle does not belong to you')
                return
            end
        else
            -- local vehicleJob = response[1].job
            local vehicleJob = response[1].jobVehicle -- JOB EDIT

            print(playerJob, vehicleJob)

            if vehicleJob ~= playerJob then
                cb(false, 'This vehicle does not belong to your organization')
                return
            end
        end

        MySQL.query('DELETE FROM `parked_vehicles` WHERE `plate` = ?', {plate}, function(rowsChanged)
            cb(true)
            RemoveParkedVehicle(ParkedVehicles[plate], true, vehicle)
        end)
    end)
end)