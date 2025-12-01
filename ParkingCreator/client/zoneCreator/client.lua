local Jobs = {}
local polyzoneMode = {}
local deleting = false
G_CallBackFuntion = nil;

local Debug = false

RegisterCommand('pdebug', function()
    Debug = not Debug

    if Debug then
        for k,v in pairs(ParkingAreas) do
            v.poly:setDebug(true, v.debugColour)
        end
    else
        for k,v in pairs(ParkingAreas) do
            v.poly:setDebug(false, v.debugColour)
        end
    end
end)

polyzoneMode.start = function(cbFunc)
    G_CallBackFuntion = cbFunc;
    toggleCretor(GetCurrentResourceName() .. "_areaCreate")
end

function PolyZoneMode()
    return polyzoneMode
end

CreateAreaInput = function()
    local options = {}
    for k,v in pairs(Jobs) do
        table.insert( options, {
            label = v.label .. ' ('..k..')',
            value = k
        } )
    end
    return lib.inputDialog('Test', {
        {
            type = 'input',
            label = 'Area name',
            required = true
        },
        {
            type = 'multi-select',
            label = 'Job',
            description = 'Restrict Jobs. Leave it blank for public garage',
            options = options,
            required = false,
            clearable = true,
            searchable = true
        }
    })
end

StartCreateZone = function()

    if not Debug then
        for k,v in pairs(ParkingAreas) do
            v.poly:setDebug(true, v.debugColour)
        end
    end

    PolyZoneMode().start(function(data)
        if data.succes then

            if not Debug then
                for k,v in pairs(ParkingAreas) do
                    v.poly:setDebug(false)
                end
            end

            local created = false
            local input
            while not created do

                input = CreateAreaInput()
 
                while input do
                    if ParkingAreas[input[1]] == nil then break end
                    lib.notify({
                        id = GetCurrentResourceName() .. '_notify_error',
                        title = 'Parking Area',
                        description = input[1] .. ( ParkingAreas[input[1]] == true and ' is currently in creation' or ' already exists'),
                        showDuration = false,
                        position = 'center-right',
                        type = 'error'
                    })
                    input = CreateAreaInput()
                end
            
                local waiting = false
                if input then

                    waiting = true
                    ESX.TriggerServerCallback(GetCurrentResourceName() .. ':createZone', function(success)
                        created = success
                        waiting = false
                    end, input, data)
                else
                    break
                end

                while waiting do Wait(1000) end
            end

            if input then
                lib.notify({
                    id = GetCurrentResourceName() .. '_notify_success',
                    title = 'Parking Area',
                    description = input[1]:gsub("%s+", "") .. ' created successfully',
                    showDuration = false,
                    position = 'center-right',
                    type = 'success'
                })
            end
        else
            print(data.error)
            lib.notify({
                id = GetCurrentResourceName() .. '_notify_error',
                title = 'Parking Area',
                description = "Failed to create area (Reason: "..data.error..")",
                showDuration = false,
                position = 'center-right',
                type = 'error'
            })
            
            if not Debug then
                for k,v in pairs(ParkingAreas) do
                    v.poly:setDebug(false)
                end
            end
        end

    end)
end

TryDeleteArea = function(areaName)
    ESX.TriggerServerCallback(GetCurrentResourceName() .. ':deleteZone', function(success) 
        if success then
        
            lib.notify({
                id = GetCurrentResourceName() .. '_notify_info',
                title = 'Parking Area',
                description = 'Deleted ' .. areaName,
                showDuration = false,
                position = 'center-right',
                type = 'success'
            })
        end
        deleting = false
    end, areaName)
end

RegisterCommand("startCreate", function()
    lib.showContext('parking_area')

    local options = {
        {
            title = 'Delete by Name',
            description = 'Delete parking area by name',
            icon = 'magnifying-glass',
            onSelect = function()
                local input = lib.inputDialog('Delete Parking Area', {
                    {
                        type = 'input',
                        label = 'Area name',
                        required = true
                    }
                })

                while input do
                    input[1] = input[1]:gsub("%s+", "")

                    if input[1] ~= "" then
                        if ParkingAreas[input[1]] ~= nil then break end
                        lib.notify({
                            id = GetCurrentResourceName() .. '_notify_error',
                            title = 'Parking Area',
                            description = input[1] .. ' does not exist',
                            showDuration = false,
                            position = 'center-right',
                            type = 'error'
                        })
                    end
                    input = lib.inputDialog('Delete Parking Area', {
                        {
                            type = 'input',
                            label = 'Area name',
                            required = true
                        }
                    })
                end
            
                if not input then
                    deleting = false
                    return
                end

                local alert = lib.alertDialog({
                    header = 'Are you sure?',
                    content = 'Confirming will delete the area: ' .. input[1],
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TryDeleteArea(input[1])
                else
                    deleting = false
                end
            end
        }
    }

    for k,v in pairs(ParkingAreas) do
        local restrictedJobs = v.restricted
        print(v, #restrictedJobs)
        local option = {
            title = k,
            description = (restrictedJobs == nil or #restrictedJobs <= 0) and "Public" or ("Required: " .. table.concat( restrictedJobs, ", ")),
            icon = 'trash',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Are you sure?',
                    content = 'Confirming will delete the area: ' .. k,
                    centered = true,
                    cancel = true
                })

                if alert == 'confirm' then
                    TryDeleteArea(k)
                else
                    deleting = false
                end
            end
          }

          table.insert( options, option )
    end

    lib.registerContext({
        id = 'parking_area_delete',
        menu = 'parking_area',
        onExit = function()
            print("ext")
            deleting = false
        end,
        onBack = function()
            print("bck")
            deleting = false
        end,
        title = 'Delete Parking Area',
        options = options
    })
end)

Citizen.CreateThread(function()
    lib.registerContext({
        id = 'parking_area',
        title = 'Parking Area',
        options = {
          {
            title = 'Create',
            description = 'Create parking area',
            icon = 'square-plus',
            onSelect = function()
                StartCreateZone()
            end
          },
          {
            title = 'Delete',
            description = 'Delete parking area',
            onSelect = function()
                Citizen.CreateThread(function()
                    if not Debug then
                        for k,v in pairs(ParkingAreas) do
                            v.poly:setDebug(true, v.debugColour)
                        end
                    end
                    lib.showContext('parking_area_delete')

                    deleting = true
                    while deleting do
                        local playerPos = GetEntityCoords(PlayerPedId())
                        for k, v in pairs(ParkingAreas) do
                            local closestPoint, closestDistance = nil, nil
                            for i, j in pairs(v.poly.points) do
                                local pointPosition = vector3(j.x, j.y, j.z)
                                local distance = #(playerPos - pointPosition)
                                
                                if closestDistance == nil or distance < closestDistance then
                                    closestDistance = distance
                                    closestPoint = pointPosition
                                end
                            end
                            
                            if closestPoint and closestDistance < 50.0 then
                                local maxHeight = closestPoint.z + (v.poly.thickness/2)
                                local minHeight = closestPoint.z - (v.poly.thickness/2)
                                local adjustedZ = playerPos.z
                        
                                if playerPos.z > maxHeight then
                                    adjustedZ = maxHeight
                                elseif playerPos.z < minHeight then
                                    adjustedZ = minHeight
                                end
                        
                                local adjustedPoint = vector3(closestPoint.x, closestPoint.y, adjustedZ)
                                
                                ESX.Game.Utils.DrawText3D(adjustedPoint, k, 2.0, 2)
                            end
                        end
                        Citizen.Wait(0)
                    end
                    
                    if not Debug then
                        for k,v in pairs(ParkingAreas) do
                            v.poly:setDebug(false)
                        end
                    end
                end)
            end,
            icon = 'square-minus'
          }
        }
    })
end)

RegisterNetEvent(GetCurrentResourceName() .. ':Load', function(_ParkingAreas, _Jobs)
    print("load called")
    Jobs = _Jobs

    for k,v in pairs(_ParkingAreas) do
        poly =
        lib.zones.poly({
            name = k,
            points = v.data.points,
            thickness = v.data.thickness,
            debug = Debug
        })

        ParkingAreas[k] = {
            debugColour = v.data.debugColour,
            poly = poly,
            restricted = v.restricted
        }
    end
end)

RegisterNetEvent(GetCurrentResourceName() .. ':AddParkingArea', function(name, ParkingArea)
    local data = ParkingArea.data

    print("adding parking area", name)
    
    poly =
    lib.zones.poly({
        name = name,
        points = data.points,
        thickness = data.thickness,
        debug = Debug
    })

    ParkingAreas[name] = {
        debugColour = data.debugColour,
        poly = poly,
        restricted = ParkingArea.restricted
    }
end)

RegisterNetEvent(GetCurrentResourceName() .. ':RemoveParkingArea', function(name)
    print("remove parking area", name)
    
    ParkingAreas[name].poly:remove()
        
    ParkingAreas[name] = nil
end)