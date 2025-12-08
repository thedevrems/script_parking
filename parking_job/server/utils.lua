function SpawnVehicle(model, coords, heading)
    if not model or not coords or not heading then
        return false, "Incorrect parameters"
    end

    -- Convertir le modèle en hash si c'est une string
    local modelHash = type(model) == 'string' and GetHashKey(model) or model

    -- Charger le modèle
    RequestModel(modelHash)

    -- Attendre que le modèle soit chargé
    local loadTimeout = 0
    while not HasModelLoaded(modelHash) and loadTimeout < 100 do
        Wait(10)
        loadTimeout = loadTimeout + 1
    end

    if loadTimeout >= 100 then
        return false, "Model loading timeout: " .. tostring(model)
    end

    -- Créer le véhicule
    local vehicle = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, true)

    -- Attendre que l'entité existe
    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    if timeout >= 100 then
        SetModelAsNoLongerNeeded(modelHash)
        return false, "Timeout during vehicle spawning"
    end

    -- Attendre la synchronisation réseau
    local networkTimeout = 0
    while NetworkGetNetworkIdFromEntity(vehicle) == 0 and networkTimeout < 50 do
        Wait(10)
        networkTimeout = networkTimeout + 1
    end

    if networkTimeout >= 50 then
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(modelHash)
        return false, "Network synchronization timeout for vehicle"
    end

    -- Libérer le modèle de la mémoire
    SetModelAsNoLongerNeeded(modelHash)

    return true, vehicle
end