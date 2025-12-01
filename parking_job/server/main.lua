ESX = exports['es_extended']:getSharedObject()

local JobParkings = {}
local ParkedVehiclesNetIds = {}

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
                JobParkings[parking.id] = {
                    id = parking.id,
                    name = parking.name,
                    job = parking.job,
                    coords = json.decode(parking.coords),
                    size = json.decode(parking.size),
                    height = parking.height,
                    heading = parking.heading
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
    local insertId = MySQL.insert.await('INSERT INTO job_parkings (name, job, coords, size, height, heading) VALUES (?, ?, ?, ?, ?, ?)', {
        data.name,
        data.job,
        json.encode(data.coords),
        json.encode(data.size),
        data.height,
        data.heading
    })

    if insertId then
        JobParkings[insertId] = {
            id = insertId,
            name = data.name,
            job = data.job,
            coords = data.coords,
            size = data.size,
            height = data.height,
            heading = data.heading
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
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, jobGarage = ?, stored = 1, parking_coords = ? WHERE plate = ?', {
        garageName,
        parkingName,
        json.encode(vehicleCoords),
        plate
    })

    -- Ajouter le netId à la liste des véhicules garés
    table.insert(ParkedVehiclesNetIds, netId)

    -- Synchroniser avec tous les clients
    TriggerClientEvent('parking_job:syncParkedVehicles', -1, ParkedVehiclesNetIds)

    -- Retirer le véhicule du système de persistence de qs-advancedgarages
    exports['qs-advancedgarages']:removeVehicleFromPersistent(plate)

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
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, stored = 0, parking_coords = NULL WHERE plate = ?', {
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

-- Spawn des véhicules garés au démarrage
CreateThread(function()
    Wait(5000) -- Attendre que les autres ressources soient chargées

    -- Récupérer tous les véhicules garés (stored = 1)
    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE jobGarage != "" AND stored = 1 AND parking_coords IS NOT NULL', {})

    if vehicles then
        for i = 1, #vehicles do
            local vehicle = vehicles[i]

            -- Décoder les coordonnées de parking
            local parkingCoords = json.decode(vehicle.parking_coords)

            if parkingCoords then
                local spawnCoords = vector4(parkingCoords.x, parkingCoords.y, parkingCoords.z, parkingCoords.heading)
                local vehicleProps = json.decode(vehicle.vehicle)

                -- Utiliser l'export de qs-advancedgarages pour spawn le véhicule
                local netId = exports['qs-advancedgarages']:SpawnVehicle(
                    vehicle.id,
                    vehicle.owner,
                    vehicle.type,
                    spawnCoords,
                    vehicleProps,
                    nil,
                    false
                )

                if netId then
                    table.insert(ParkedVehiclesNetIds, netId)
                end

                Wait(100) -- Petite pause entre chaque spawn
            end
        end

        print('^2[Job Parking]^0 Spawned ' .. #vehicles .. ' parked job vehicle(s)')

        -- Envoyer les netIds aux clients après un délai
        Wait(2000)
        TriggerClientEvent('parking_job:syncParkedVehicles', -1, ParkedVehiclesNetIds)
    end
end)

-- Fonction pour donner les clés
function GiveKeys(source, plate)
    if Config.KeySystem == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:GiveKeys(plate, source, true)
    elseif Config.KeySystem == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:AddKeys', source, plate)
    elseif Config.KeySystem == 'wasabi_carlock' then
        exports.wasabi_carlock:GiveKey(source, plate)
    end
end

-- Fonction pour retirer les clés
function RemoveKeys(source, plate)
    if Config.KeySystem == 'qs-vehiclekeys' then
        exports['qs-vehiclekeys']:RemoveKeys(plate, source)
    elseif Config.KeySystem == 'qb-vehiclekeys' then
        TriggerClientEvent('qb-vehiclekeys:client:RemoveKeys', source, plate)
    elseif Config.KeySystem == 'wasabi_carlock' then
        exports.wasabi_carlock:RemoveKey(source, plate)
    end
end

-- Event pour donner les clés
RegisterNetEvent('parking_job:giveKeys', function(plate)
    GiveKeys(source, plate)
end)

-- Event pour retirer les clés
RegisterNetEvent('parking_job:removeKeys', function(plate)
    RemoveKeys(source, plate)
end)

-- Charger les parkings au démarrage
CreateThread(function()
    Wait(1000)
    LoadParkings()
end)

-- Event pour mettre à jour les parkings côté client
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        TriggerClientEvent('parking_job:updateParkings', -1, JobParkings)
    end
end)

-- Event pour envoyer les parkings aux joueurs qui se connectent
RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
    TriggerClientEvent('parking_job:updateParkings', playerId, JobParkings)

    -- Envoyer aussi la liste des véhicules garés
    Wait(1000)
    TriggerClientEvent('parking_job:syncParkedVehicles', playerId, ParkedVehiclesNetIds)
end)

-- Note: Les vérifications de job se font côté serveur dans les callbacks
-- Cela permet de gérer automatiquement les changements de job sans événements supplémentaires
-- À chaque action (garer/récupérer), le job du joueur est vérifié en temps réel
