ESX = exports['es_extended']:getSharedObject()

local JobParkings = {}

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

-- Récupérer tous les parkings
lib.callback.register('parking_job:getParkings', function(source)
    return JobParkings
end)

-- Récupérer tous les jobs disponibles
lib.callback.register('parking_job:getJobs', function(source)
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
lib.callback.register('parking_job:storeVehicle', function(source, plate, parkingName)
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

    -- Mettre à jour le véhicule dans la base de données
    local garageName = Config.GaragePrefix .. parkingName
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, jobGarage = ?, stored = 1 WHERE plate = ?', {
        garageName,
        parkingName,
        plate
    })

    -- Retirer le véhicule du système de persistence de qs-advancedgarages
    exports['qs-advancedgarages']:removeVehicleFromPersistent(plate)

    return true, 'vehicleStored'
end)

-- Récupérer un véhicule
lib.callback.register('parking_job:retrieveVehicle', function(source, plate, parkingJob)
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

    -- Mettre à jour le véhicule dans la base de données
    MySQL.update.await('UPDATE owned_vehicles SET garage = ?, stored = 0 WHERE plate = ?', {
        'OUT',
        plate
    })

    return true, 'vehicleRetrieved', vehicle
end)

-- Récupérer les véhicules d'un parking
lib.callback.register('parking_job:getParkingVehicles', function(source, parkingName)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return {} end

    -- Trouver le parking pour vérifier le job
    local parking = nil
    for id, p in pairs(JobParkings) do
        if p.name == parkingName then
            parking = p
            break
        end
    end

    -- Vérifier que le parking existe
    if not parking then return {} end

    -- Vérifier que le joueur a le bon job
    if xPlayer.job.name ~= parking.job then
        return {}
    end

    local garageName = Config.GaragePrefix .. parkingName
    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE jobGarage = ? AND stored = 1', {parkingName})

    return vehicles or {}
end)

-- Spawn des véhicules au démarrage
CreateThread(function()
    Wait(5000) -- Attendre que les autres ressources soient chargées

    local vehicles = MySQL.query.await('SELECT * FROM owned_vehicles WHERE jobGarage != "" AND stored = 0 AND garage = "OUT"', {})

    if vehicles then
        for i = 1, #vehicles do
            local vehicle = vehicles[i]
            local parkingName = vehicle.jobGarage

            -- Trouver le parking correspondant
            for id, parking in pairs(JobParkings) do
                if parking.name == parkingName then
                    -- Spawn le véhicule
                    local coords = parking.coords
                    local spawnCoords = vector4(coords.x, coords.y, coords.z, parking.heading)

                    local vehicleProps = json.decode(vehicle.vehicle)

                    -- Utiliser l'export de qs-advancedgarages pour spawn le véhicule
                    exports['qs-advancedgarages']:SpawnVehicle(
                        vehicle.id,
                        vehicle.owner,
                        vehicle.type,
                        spawnCoords,
                        vehicleProps,
                        nil,
                        false
                    )

                    Wait(100) -- Petite pause entre chaque spawn
                    break
                end
            end
        end

        print('^2[Job Parking]^0 Spawned ' .. #vehicles .. ' job vehicle(s)')
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
end)

-- Note: Les vérifications de job se font côté serveur dans les callbacks
-- Cela permet de gérer automatiquement les changements de job sans événements supplémentaires
-- À chaque action (garer/récupérer), le job du joueur est vérifié en temps réel
