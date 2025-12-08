function SpawnVehicle(model, coords, heading)
    if not model or not coords or not heading then
        return false, "Incorrect parameters"
    end

    -- Convertir le modèle en hash si c'est une string
    local modelHash = type(model) == 'string' and GetHashKey(model) or model

    -- Créer le véhicule (le streaming du modèle est géré automatiquement par les clients)
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, true)

    -- Attendre que l'entité existe
    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if timeout >= 100 then
        return false, "Timeout during vehicle spawning - Model: " .. tostring(model)
    end

    -- Attendre la synchronisation réseau
    local networkTimeout = 0
    while NetworkGetNetworkIdFromEntity(vehicle) == 0 and networkTimeout < 50 do
        Wait(10)
        networkTimeout = networkTimeout + 1
    end

    if networkTimeout >= 50 then
        DeleteEntity(vehicle)
        return false, "Network synchronization timeout for vehicle - Model: " .. tostring(model)
    end

    return true, vehicle
end