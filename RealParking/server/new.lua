-- ESX = exports['es_extended']:getSharedObject()

-- Parkings = {}
-- Vehicles = {}

-- AddEventHandler('onResourceStart', function(_resName)
--     if _resName == ResourceName then
--         -- fetch data from sql and then call the Load function with the data

--         MySQL.query('SELECT * FROM `parked_vehicles` WHERE 1', {}, function(response)
--             if response then
--                 local all_data = {}
--                 for i = 1, #response do
--                     local row = response[i]

--                     all_data[i] = {
--                         parking = row.parking,
--                         vehicle_info = {
--                             plate = row.plate,
--                             position = row.position,
--                             properties = row.properties,
--                             data = row.data
--                         }
--                     }
--                 end
--                 Load(all_data)
--                 -- Wait(1000)
--                 -- TriggerClientEvent(ResourceName .. ':Load', -1, ParkedVehicles)
--             end
--         end)
--     end
-- end)

-- RegisterNetEvent('esx:playerLoaded', function(player, xPlayer, isNew)
--     TriggerClientEvent('eventName:InitParkings', player, Parkings)
-- end)

-- Load = function(all_data)
--     for k,data in pairs(all_data) do
--         if isNew(data.parking) then
--             CreateParking(data.parking, function()
--                 AddVehicle(data.parking, data.vehicle_info)
--             end)
--         else
--             AddVehicle(data.parking, data.vehicle_info)
--         end
--     end
-- end

-- isNew = function(parking)
--     return not Parkings[parking]
-- end

-- doesExist = function(plate, parking)
--     return Parkings[parking] and Parkings[parking][plate]
-- end

-- CreateParking = function(parking, cb)
--     Parkings[parking] = true
--     if cb ~= nil then cb() end
-- end

-- AddVehicle = function(parking, vehicle_info)
--     local plate = vehicle_info.plate

--     if not doesExist(plate, parking) then
--         Vehicles[plate] = parking

--         Parkings[parking][plate] = vehicle_info
--     end
-- end

-- RemoveVehicle = function(plate)
--     local parking = Vehicles[plate]
--     if doesExist(plate, parking) then
--         Parkings[parking][plate] = nil
--         Vehicles[plate] = nil
--     end
-- end