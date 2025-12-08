local JobParkings = {}
local ParkedVehiclesNetIds = {}
local VehiclesToSpawn = {} -- Liste des véhicules à spawner par parking : {parkingName = {véhicules}}
local ParkingsSpawned = {} -- Flag par parking : {parkingName = true/false}

-- Commande admin pour gérer les parkings (côté serveur pour sécurité)
RegisterCommand(Config.AdminCommand, function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)

    if not xPlayer then return end

    -- Vérifier les permissions
    if xPlayer.getGroup() ~= Config.AdminGroup then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Erreur',
            description = Config.Notifications.noPermission,
            type = 'error'
        })
        return
    end

    -- Envoyer un event au client pour ouvrir le menu
    TriggerClientEvent('parking_job:openAdminMenu', source)
end, false)

-- Charger tous les parkings depuis la base de données
local function LoadParkings()
    MySQL.query('SELECT * FROM job_parkings', {}, function(result)
        if result then
            for i = 1, #result do
                local parking = result[i]
                local points = json.decode(parking.points)

                -- Calculer le centre du parking (optimisation : calculé une seule fois côté serveur)
                local centerX, centerY, centerZ = 0, 0, 0
                local pointCount = #points

                for j = 1, pointCount do
                    centerX = centerX + points[j].x
                    centerY = centerY + points[j].y
                    centerZ = centerZ + points[j].z
                end

                centerX = centerX / pointCount
                centerY = centerY / pointCount
                centerZ = centerZ / pointCount

                JobParkings[parking.id] = {
                    id = parking.id,
                    name = parking.name,
                    job = parking.job,
                    points = points,
                    height = parking.height,
                    center = {x = centerX, y = centerY, z = centerZ} -- Centre pré-calculé
                }
            end
            print('^2[Job Parking]^0 Loaded ' .. #result .. ' parking(s)')
        end
    end)
end

-- Créer un parking
lib.callback.register('parking_job:createParking', function(source, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Vérifier les permissions
    if xPlayer.getGroup() ~= Config.AdminGroup then
        return false, 'noPermission'
    end

    -- Vérifier si le nom existe déjà
    local exists = MySQL.scalar.await('SELECT COUNT(*) FROM job_parkings WHERE name = ?', {data.name})
    if exists > 0 then
        return false, 'alreadyExists'
    end

    -- Insérer dans la base de données
    local insertId = MySQL.insert.await('INSERT INTO job_parkings (name, job, points, height) VALUES (?, ?, ?, ?)', {
        data.name,
        data.job,
        json.encode(data.points),
        data.height
    })

    if insertId then
        -- Calculer le centre du parking
        local centerX, centerY, centerZ = 0, 0, 0
        local pointCount = #data.points

        for i = 1, pointCount do
            centerX = centerX + data.points[i].x
            centerY = centerY + data.points[i].y
            centerZ = centerZ + data.points[i].z
        end

        centerX = centerX / pointCount
        centerY = centerY / pointCount
        centerZ = centerZ / pointCount

        JobParkings[insertId] = {
            id = insertId,
            name = data.name,
            job = data.job,
            points = data.points,
            height = data.height,
            center = {x = centerX, y = centerY, z = centerZ}
        }

        -- Notifier tous les clients
        TriggerClientEvent('parking_job:updateParkings', -1, JobParkings)
        return true, 'parkingCreated'
    end

    return false, 'invalidData'
end)

-- Supprimer un parking
lib.callback.register('parking_job:deleteParking', function(source, parkingId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Vérifier les permissions
    if xPlayer.getGroup() ~= Config.AdminGroup then
        return false, 'noPermission'
    end

    -- Supprimer de la base de données
    local affectedRows = MySQL.update.await('DELETE FROM job_parkings WHERE id = ?', {parkingId})

    if affectedRows > 0 then
        JobParkings[parkingId] = nil

        -- Notifier tous les clients
        TriggerClientEvent('parking_job:updateParkings', -1, JobParkings)
        return true, 'parkingDeleted'
    end

    return false, 'invalidData'
end)

-- Récupérer tous les parkings (pour le menu admin uniquement)
lib.callback.register('parking_job:getParkings', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    -- Vérifier les permissions
    if xPlayer.getGroup() ~= Config.AdminGroup then
        return {}
    end

    return JobParkings
end)

-- Récupérer tous les parkings (pour tous les joueurs - polyzones)
lib.callback.register('parking_job:getAllParkings', function(source)
    return JobParkings
end)

-- Récupérer tous les jobs disponibles (réservé aux admins)
lib.callback.register('parking_job:getJobs', function(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    -- Vérifier les permissions
    if xPlayer.getGroup() ~= Config.AdminGroup then
        return {}
    end

    local jobs = {}
    for jobName, jobData in pairs(ESX.Jobs) do
        table.insert(jobs, {
            name = jobName,
            label = jobData.label
        })
    end
    return jobs
end)

-- Garer un véhicule
lib.callback.register('parking_job:storeVehicle', function(source, plate, parkingName, vehicleCoords, netId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Récupérer les infos du véhicule
    local vehicle = MySQL.single.await('SELECT * FROM owned_vehicles WHERE plate = ?', {plate})

    if not vehicle then
        return false, 'invalidData'
    end

    -- Vérifier que c'est un véhicule de job
    if not vehicle.jobVehicle or vehicle.jobVehicle == '' then
        return false, 'notJobVehicle'
    end

    -- Vérifier que le joueur a le bon job
    if xPlayer.job.name ~= vehicle.jobVehicle then
        return false, 'wrongJob'
    end

    -- Mettre à jour le véhicule dans la base de données avec ses coordonnées
    local garageName = Config.GaragePrefix .. parkingName
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, jobGarage = ?, stored = TRUE, parking_coords = ? WHERE plate = ?', {
        garageName,
        parkingName,
        json.encode(vehicleCoords),
        plate
    })

    -- Ajouter le netId à la liste des véhicules garés
    table.insert(ParkedVehiclesNetIds, netId)

    -- Synchroniser avec tous les clients
    TriggerClientEvent('parking_job:syncParkedVehicles', -1, ParkedVehiclesNetIds)

    return true, 'vehicleStored'
end)

-- Récupérer un véhicule (le véhicule reste spawn, on change juste son statut)
lib.callback.register('parking_job:retrieveVehicle', function(source, plate, parkingJob, netId)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return false end

    -- Récupérer les infos du véhicule
    local vehicle = MySQL.single.await('SELECT * FROM owned_vehicles WHERE plate = ?', {plate})

    if not vehicle then
        return false, 'invalidData'
    end

    -- Vérifier que c'est un véhicule de job
    if not vehicle.jobVehicle or vehicle.jobVehicle == '' then
        return false, 'notJobVehicle'
    end

    -- Vérifier que le véhicule appartient au bon job
    if vehicle.jobVehicle ~= parkingJob then
        return false, 'notJobVehicle'
    end

    -- Vérifier que le joueur a le bon job
    if xPlayer.job.name ~= parkingJob then
        return false, 'wrongJob'
    end

    -- Vérifier que le véhicule est bien garé
    if vehicle.stored ~= 1 then
        return false, 'invalidData'
    end

    -- Mettre à jour le véhicule dans la base de données (le rendre "sorti")
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, stored = FALSE, jobGarage = NULL, parking_coords = NULL WHERE plate = ?', {
        'OUT',
        plate
    })

    -- Retirer le netId de la liste des véhicules garés
    for i = #ParkedVehiclesNetIds, 1, -1 do
        if ParkedVehiclesNetIds[i] == netId then
            table.remove(ParkedVehiclesNetIds, i)
            break
        end
    end

    -- Synchroniser avec tous les clients
    TriggerClientEvent('parking_job:syncParkedVehicles', -1, ParkedVehiclesNetIds)

    return true, 'vehicleRetrieved'
end)

-- Fonction pour charger les véhicules garés depuis la DB (ne les spawn pas encore)
local function LoadParkedVehicles()
    -- Récupérer tous les véhicules garés (stored = 1)
    local dataVehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE jobGarage != "" AND stored = TRUE AND parking_coords IS NOT NULL', {})

    if dataVehicles then
        -- Grouper les véhicules par parking
        for i = 1, #dataVehicles do
            local vehicle = dataVehicles[i]
            local parkingName = vehicle.jobGarage

            if not VehiclesToSpawn[parkingName] then
                VehiclesToSpawn[parkingName] = {}
                ParkingsSpawned[parkingName] = false
            end

            table.insert(VehiclesToSpawn[parkingName], vehicle)
        end

        -- Mettre à jour le nombre de véhicules par parking et calculer la distance adaptative
        for id, parking in pairs(JobParkings) do
            local count = #(VehiclesToSpawn[parking.name] or {})
            parking.vehicleCount = count

            -- Distance adaptative : plus de véhicules = détection plus loin (optimisation streaming)
            -- 1 véhicule = 900m, 2-3 = 1000m, 4-5 = 1100m, 6+ = 1200m (max streaming)
            if count == 0 then
                parking.spawnDistance = 0 -- Pas de point créé
            elseif count == 1 then
                parking.spawnDistance = 900.0
            elseif count <= 3 then
                parking.spawnDistance = 1000.0
            elseif count <= 5 then
                parking.spawnDistance = 1100.0
            else
                parking.spawnDistance = 1200.0 -- Maximum pour rester dans les limites de streaming
            end
        end

        print('^2[Job Parking]^0 Loaded ' .. #dataVehicles .. ' parked job vehicle(s) from database (grouped by parking)')
    end
end

-- Fonction pour spawn les véhicules d'un parking spécifique (appelée quand un joueur entre dans la zone)
local function SpawnParkingVehicles(parkingName)
    if not parkingName then
        print('^1[Job Parking Error]^0 No parking name provided')
        return
    end

    -- Vérifier si les véhicules de ce parking ont déjà été spawnés
    if ParkingsSpawned[parkingName] then
        print('^3[Job Parking]^0 Vehicles for parking "' .. parkingName .. '" already spawned, skipping...')
        return
    end

    -- Vérifier s'il y a des véhicules à spawner pour ce parking
    if not VehiclesToSpawn[parkingName] or #VehiclesToSpawn[parkingName] == 0 then
        print('^3[Job Parking]^0 No vehicles to spawn for parking "' .. parkingName .. '"')
        ParkingsSpawned[parkingName] = true
        return
    end

    local vehicleCount = #VehiclesToSpawn[parkingName]
    print('^2[Job Parking]^0 Spawning ' .. vehicleCount .. ' vehicle(s) for parking "' .. parkingName .. '"...')

    for i = 1, vehicleCount do
        local dataVehicle = VehiclesToSpawn[parkingName][i]

        -- Décoder les coordonnées de parking
        local parkingCoords = json.decode(dataVehicle.parking_coords)
        local propsVehicle = json.decode(dataVehicle.vehicle)
        local spawnCoords = vector3(parkingCoords.x, parkingCoords.y, parkingCoords.z)

        if parkingCoords and propsVehicle and propsVehicle.model and spawnCoords and parkingCoords.heading then
            -- Convertir le hash du modèle en nom de modèle (string)
            local modelName = GetVehicleModelName(propsVehicle.model)

            if modelName == "unknown" then
                print('^1[Job Parking Error]^0 Unknown vehicle model hash: ' .. tostring(propsVehicle.model))
            else
                local validVehicle, resultVehicle = TrySpawnVehicle(modelName, spawnCoords, parkingCoords.heading, 2)

                if validVehicle and resultVehicle > 0 then
                    -- Verrouiller le véhicule
                    SetVehicleDoorsLocked(resultVehicle, 2)

                    local netId = NetworkGetNetworkIdFromEntity(resultVehicle)
                    if netId > 0 then
                        -- Ajouter à la liste des véhicules garés
                        table.insert(ParkedVehiclesNetIds, netId)

                        -- Rendre le véhicule persistant avec qs-advancedgarages
                        exports['qs-advancedgarages']:setVehicleToPersistent(netId)
                    end
                    print("^2[Job Parking]^0 Vehicle spawned successfully (plate: " .. dataVehicle.plate .. ")")
                else
                    print('^1[Job Parking Error]^0 Failed to spawn vehicle (plate: ' .. dataVehicle.plate .. '): ' .. tostring(resultVehicle))
                end
            end

            Wait(100) -- Petite pause entre chaque spawn
        end
    end

    -- Marquer ce parking comme "véhicules déjà spawnés"
    ParkingsSpawned[parkingName] = true
    print('^2[Job Parking]^0 Finished spawning vehicles for parking "' .. parkingName .. '"')

    -- Envoyer les netIds aux clients
    TriggerClientEvent('parking_job:syncParkedVehicles', -1, ParkedVehiclesNetIds)
end

-- Event pour charger les parkings et véhicules au démarrage
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- Charger les parkings depuis la base de données
        Wait(1000)
        LoadParkings()

        -- Charger les véhicules depuis la DB (mais ne pas les spawner encore)
        Wait(1000)
        LoadParkedVehicles()

        -- Envoyer les parkings aux clients déjà connectés
        Wait(1000)
        TriggerClientEvent('parking_job:updateParkings', -1, JobParkings)
    end
end)

-- Event pour envoyer les parkings aux joueurs qui se connectent
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
    -- Envoyer les parkings au joueur
    TriggerClientEvent('parking_job:updateParkings', playerId, JobParkings)

    -- Envoyer aussi la liste des véhicules garés
    Wait(1000)
    TriggerClientEvent('parking_job:syncParkedVehicles', playerId, ParkedVehiclesNetIds)
end)

-- Event appelé par le client quand un joueur s'approche d'un parking (~1000m)
RegisterNetEvent('parking_job:playerApproachingParking', function(parkingName)
    if not parkingName then return end

    -- Spawner les véhicules de ce parking si ce n'est pas déjà fait
    CreateThread(function()
        SpawnParkingVehicles(parkingName)
    end)
end)

-- Note: Les vérifications de job se font côté serveur dans les callbacks
-- Cela permet de gérer automatiquement les changements de job sans événements supplémentaires
-- À chaque action (garer/récupérer), le job du joueur est vérifié en temps réel
