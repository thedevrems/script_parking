function SpawnVehicle(name, coords, heading)
    if not name or not coords or not heading then
        return false, "Incorrect parameters"
    end

    print(name)
    print(coords)
    print(heading)
    local vehicle = CreateVehicle(name, coords.x, coords.y, coords.z, heading, true, true)

    local timeout = 0
    while not DoesEntityExist(vehicle) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end

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