function IsSpawnLocationAvailable(coords, radius)
    radius = radius or 3.0

    local vehicles = GetAllVehicles()

    for _, vehicle in ipairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(vector3(coords.x, coords.y, coords.z) - vehCoords)

            if distance < radius then
                return false
            end
        end
    end

    return true
end

function SpawnVehicle(model, coords, heading)
    if not model or not coords or not heading then
        return false, "Incorrect parameters"
    end

    print("^3[DEBUG]^0 Attempting to spawn vehicle:")
    print("  Model: " .. tostring(model) .. " (type: " .. type(model) .. ")")
    print("  Coords: " .. coords.x .. ", " .. coords.y .. ", " .. coords.z)
    print("  Heading: " .. tostring(heading))

    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, heading, true, true)
    print("^3[DEBUG]^0 CreateVehicle returned: " .. tostring(vehicle))

    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

    print("^3[DEBUG]^0 DoesEntityExist check - Timeout: " .. timeout .. "/100, Exists: " .. tostring(DoesEntityExist(vehicle)))

    if timeout >= 100 then
        return false, "Timeout during vehicle spawning"
    end

    local networkTimeout = 0
    while NetworkGetNetworkIdFromEntity(vehicle) == 0 and networkTimeout < 50 do
        Wait(10)
        networkTimeout = networkTimeout + 1
    end

    if networkTimeout >= 50 then
        DeleteEntity(vehicle)
        return false, "Network synchronization timeout for vehicle"
    end

    return true, vehicle
end

function TrySpawnVehicle(name, coords, heading, radius)
    if not IsSpawnLocationAvailable(coords, radius) then
        return false, "Spawn location is blocked by another vehicle"
    end

    return SpawnVehicle(name, coords, heading)
end