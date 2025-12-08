-- Gestion des interactions ox_target pour les véhicules de job

local ParkedVehicles = {} -- Liste des véhicules garés {entity = netId}

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

            -- Vérifier que le véhicule n'est pas déjà garé
            if ParkedVehicles[entity] then return false end

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

            -- Récupérer les coordonnées du véhicule
            local vehCoords = GetEntityCoords(vehicle)
            local vehHeading = GetEntityHeading(vehicle)
            local vehicleCoords = {
                x = vehCoords.x,
                y = vehCoords.y,
                z = vehCoords.z,
                heading = vehHeading
            }

            -- Récupérer le netId du véhicule
            local netId = NetworkGetNetworkIdFromEntity(vehicle)

            -- Garer le véhicule
            local success, message = lib.callback.await('parking_job:storeVehicle', false, plate, CurrentParking.name, vehicleCoords, netId)

            if success then
                -- Marquer le véhicule comme garé
                ParkedVehicles[vehicle] = netId

                -- Retirer les clés
                exports['qs-vehiclekeys']:RemoveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))

                -- Verrouiller le véhicule
                SetVehicleDoorsLocked(vehicle, 2)

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
        end
    }
})

-- Récupérer un véhicule garé
exports.ox_target:addGlobalVehicle({
    {
        name = 'retrieve_job_vehicle',
        label = 'Récupérer le véhicule',
        icon = 'fa-solid fa-car',
        distance = Config.InteractionDistance,
        canInteract = function(entity, distance, coords, name, bone)
            -- Vérifier que le véhicule est garé
            if not ParkedVehicles[entity] then return false end

            -- Vérifier qu'on est dans une zone de parking
            if not CurrentParking then return false end

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

            -- Récupérer le netId du véhicule
            local netId = ParkedVehicles[vehicle]

            -- Récupérer le véhicule
            local success, message = lib.callback.await('parking_job:retrieveVehicle', false, plate, CurrentParking.job, netId)

            if success then
                -- Retirer de la liste des véhicules garés
                ParkedVehicles[vehicle] = nil

                -- Donner les clés
                exports['qs-vehiclekeys']:GiveKeys(plate, GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)), true)

                -- Déverrouiller le véhicule
                SetVehicleDoorsLocked(vehicle, 1)

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
        end
    }
})

-- Event pour synchroniser les véhicules garés
-- Cet événement reconstruit la liste des véhicules garés depuis la source autoritaire (serveur)
-- et nettoie automatiquement les véhicules qui n'existent plus
RegisterNetEvent('parking_job:syncParkedVehicles', function(parkedVehicles)
    ParkedVehicles = {}

    for i = 1, #parkedVehicles do
        local netId = parkedVehicles[i]
        local vehicle = NetworkGetEntityFromNetworkId(netId)

        if DoesEntityExist(vehicle) then
            ParkedVehicles[vehicle] = netId

            -- Verrouiller le véhicule garé
            SetVehicleDoorsLocked(vehicle, 2)
        end
    end
end)
