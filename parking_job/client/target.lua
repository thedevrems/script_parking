-- Gestion des interactions ox_target pour les véhicules de job

local StoredVehicles = {} -- Liste des véhicules garés (avec entity)

-- Fonction pour obtenir les véhicules proches
local function GetNearbyVehicles(radius)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success

    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(playerCoords - vehicleCoords)

        if distance <= radius then
            table.insert(vehicles, vehicle)
        end

        success, vehicle = FindNextVehicle(handle)
    until not success

    EndFindVehicle(handle)

    return vehicles
end

-- Garer un véhicule de job
exports.ox_target:addGlobalVehicle({
    {
        name = 'park_job_vehicle',
        label = 'Garer le véhicule',
        icon = 'fa-solid fa-warehouse',
        distance = Config.InteractionDistance,
        canInteract = function(entity, distance, coords, name, bone)
            -- Vérifier qu'on est dans une zone de parking
            if not CurrentParking then return false end

            -- Vérifier que le joueur est dans le véhicule
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            if vehicle ~= entity then return false end

            return true
        end,
        onSelect = function(data)
            local vehicle = data.entity
            local plate = GetVehicleNumberPlateText(vehicle)

            if not plate then
                lib.notify({
                    title = 'Erreur',
                    description = 'Impossible de lire la plaque du véhicule',
                    type = 'error'
                })
                return
            end

            -- Retirer les espaces de la plaque
            plate = plate:gsub("%s+", "")

            -- Faire sortir le joueur du véhicule
            local playerPed = PlayerPedId()
            TaskLeaveVehicle(playerPed, vehicle, 0)

            Wait(2000)

            -- Garer le véhicule
            lib.callback('parking_job:storeVehicle', false, function(success, message)
                if success then
                    -- Supprimer le véhicule
                    DeleteVehicle(vehicle)

                    -- Retirer les clés
                    TriggerServerEvent('parking_job:removeKeys', plate)

                    lib.notify({
                        title = 'Succès',
                        description = Config.Notifications[message],
                        type = 'success'
                    })
                else
                    lib.notify({
                        title = 'Erreur',
                        description = Config.Notifications[message],
                        type = 'error'
                    })
                end
            end, plate, CurrentParking.name)
        end
    }
})

-- Créer des zones pour récupérer les véhicules
function CreateVehicleRetrievalZones()
    for id, parking in pairs(JobParkings) do
        -- Zone pour récupérer les véhicules
        exports.ox_target:addBoxZone({
            coords = vector3(parking.coords.x, parking.coords.y, parking.coords.z),
            size = vector3(parking.size.x, parking.size.y, parking.height),
            rotation = parking.heading,
            debug = Config.Debug,
            options = {
                {
                    name = 'retrieve_job_vehicle_' .. parking.name,
                    label = 'Récupérer un véhicule',
                    icon = 'fa-solid fa-car',
                    distance = Config.InteractionDistance,
                    onSelect = function()
                        OpenVehicleList(parking)
                    end
                }
            }
        })
    end
end

-- Ouvrir la liste des véhicules garés
function OpenVehicleList(parking)
    lib.callback('parking_job:getParkingVehicles', false, function(vehicles)
        if not vehicles or #vehicles == 0 then
            lib.notify({
                title = 'Information',
                description = 'Aucun véhicule dans ce parking',
                type = 'info'
            })
            return
        end

        local elements = {}

        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            local vehicleData = json.decode(vehicle.vehicle)
            local model = vehicleData.model or 'Inconnu'

            table.insert(elements, {
                title = GetDisplayNameFromVehicleModel(model),
                description = 'Plaque: ' .. vehicle.plate,
                icon = 'car',
                onSelect = function()
                    RetrieveVehicle(parking, vehicle)
                end
            })
        end

        lib.registerContext({
            id = 'vehicle_list_menu',
            title = 'Véhicules - ' .. parking.name,
            options = elements
        })

        lib.showContext('vehicle_list_menu')
    end, parking.name)
end

-- Récupérer un véhicule
function RetrieveVehicle(parking, vehicleData)
    lib.callback('parking_job:retrieveVehicle', false, function(success, message, vehicle)
        if success then
            -- Spawn le véhicule
            local spawnCoords = vector4(parking.coords.x, parking.coords.y, parking.coords.z, parking.heading)
            local vehicleProps = json.decode(vehicle.vehicle)
            local model = vehicleProps.model

            -- Charger le modèle
            RequestModel(model)
            while not HasModelLoaded(model) do
                Wait(100)
            end

            -- Créer le véhicule
            local veh = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.w, true, false)

            -- Attendre que le véhicule existe
            local timeout = 0
            while not DoesEntityExist(veh) and timeout < 50 do
                Wait(100)
                timeout = timeout + 1
            end

            if DoesEntityExist(veh) then
                -- Appliquer les propriétés du véhicule
                ESX.Game.SetVehicleProperties(veh, vehicleProps)

                -- Définir la plaque
                SetVehicleNumberPlateText(veh, vehicle.plate)

                -- Ajouter le véhicule au système de persistence
                local netId = NetworkGetNetworkIdFromEntity(veh)
                exports['qs-advancedgarages']:setVehicleToPersistent(netId)

                -- Donner les clés
                TriggerServerEvent('parking_job:giveKeys', vehicle.plate)

                lib.notify({
                    title = 'Succès',
                    description = Config.Notifications[message],
                    type = 'success'
                })

                -- Libérer le modèle
                SetModelAsNoLongerNeeded(model)
            else
                lib.notify({
                    title = 'Erreur',
                    description = 'Impossible de créer le véhicule',
                    type = 'error'
                })
            end
        else
            lib.notify({
                title = 'Erreur',
                description = Config.Notifications[message],
                type = 'error'
            })
        end
    end, vehicleData.plate, parking.job)
end

-- Event pour mettre à jour les zones
RegisterNetEvent('parking_job:updateParkings', function(parkings)
    JobParkings = parkings

    -- Recréer les zones
    Wait(1000)
    CreateVehicleRetrievalZones()
end)

-- Créer les zones au démarrage
CreateThread(function()
    Wait(5000)
    CreateVehicleRetrievalZones()
end)
