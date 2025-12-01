local isOpenCretor, Cam = false, nil
local MAX_CAM_DISTANCE = 100
local MinY, MaxY = -90.0, 90.0
local MoveSpeed = 0.15
local zoneHeight = 4
local zonePoints = {}
local currentZone, currentZoneName, currentZ = nil, nil, nil
local debugColour = {r = 255, g = 255, b = 255, a = 50}

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isOpenCretor then
            FreezeEntityPosition(PlayerPedId(), false)
        end
    end
end)

function rgb2hex(r,g,b)
    -- EXPLANATION:
    -- The integer form of RGB is 0xRRGGBB
    -- Hex for red is 0xRR0000
    -- Multiply red value by 0x10000(65536) to get 0xRR0000
    -- Hex for green is 0x00GG00
    -- Multiply green value by 0x100(256) to get 0x00GG00
    -- Blue value does not need multiplication.

    -- Final step is to add them together
    -- (r * 0x10000) + (g * 0x100) + b =
    -- 0xRR0000 +
    -- 0x00GG00 +
    -- 0x0000BB =
    -- 0xRRGGBB
    local rgb = (r * 0x10000) + (g * 0x100) + b
    return string.format("%06x", rgb)
end

function hex2rgb (hex)
    local hex = hex:gsub("#","")
    if hex:len() == 3 then
      return (tonumber("0x"..hex:sub(1,1))*17), (tonumber("0x"..hex:sub(2,2))*17), (tonumber("0x"..hex:sub(3,3))*17)
    else
      return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6))
    end
end

----------------------------------------SCALEFORM----------------------------------------
local form = nil

local function ButtonMessage(text)
    BeginTextCommandScaleformString("STRING")
    AddTextComponentScaleform(text)
    EndTextCommandScaleformString()
end

local function Button(ControlButton)
    N_0xe83a3e3557a56640(ControlButton)
end

local function setupScaleform(scaleform)
    local scaleform = RequestScaleformMovie(scaleform)
    while not HasScaleformMovieLoaded(scaleform) do
        Citizen.Wait(0)
    end

    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 0, 0)

    PushScaleformMovieFunction(scaleform, "CLEAR_ALL")
    PopScaleformMovieFunctionVoid()
    
    PushScaleformMovieFunction(scaleform, "SET_CLEAR_SPACE")
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    
    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(0)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.CLICK_SAVE_POLYZONE], true))
    ButtonMessage("Done")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(1)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.CLICK_CANCEL_POLYZONE], true))
    ButtonMessage("Cancel")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(2)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.CLICK_ADD_POINT], true))
    ButtonMessage("Add Point")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(3)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.CLICK_DELETE_POINT], true))
    ButtonMessage("Undo Last")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(4)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_DOWN], true))
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_UP], true))
    ButtonMessage("Up +/-")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(5)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_RIGHT], true))
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_LEFT], true))
    ButtonMessage("Right +/-")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(6)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_BACKWARDS], true))
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.MOVE_FORWARDS], true))
    ButtonMessage("Forward +/-")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(7)
    Button(GetControlInstructionalButton(2, Keys[ZoneConfig.CHANGE_COLOUR], true))
    ButtonMessage("Set Colour")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_DATA_SLOT")
    PushScaleformMovieFunctionParameterInt(8)
    ButtonMessage("Points: " .. #zonePoints)
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, "SET_BACKGROUND_COLOUR")
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieFunctionParameterInt(80)
    PopScaleformMovieFunctionVoid()

    return scaleform
end

-- Citizen.CreateThread(function()
--     form = setupScaleform("instructional_buttons")
-- end)
-----------------------------------------------------------------------------------------

function toggleCretor(polyzoneName)
    local playerPed = PlayerPedId()
    if not isOpenCretor then
        currentZoneName = polyzoneName;
        local x, y, z = table.unpack(GetGameplayCamCoord())
        local pitch, roll, yaw = table.unpack(GetGameplayCamRot(2))
        local fov = GetGameplayCamFov()
        Cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
        SetCamCoord(Cam, x, y, z + 5.0)
        SetCamRot(Cam, pitch, roll, yaw, 2)
        SetCamFov(Cam, fov)
        RenderScriptCams(true, true, 500, true, true)
        FreezeEntityPosition(playerPed, true)
        
        -----------------------------------------------------------------------
        form = setupScaleform("instructional_buttons")
        -----------------------------------------------------------------------
    else
        -- SendReactMessage('polyzoneMode', {
        --     mod = false
        -- })
        destroyZone(currentZone)
        G_CallBackFuntion = nil;
        currentZoneName, currentZone, currentZ, zonePoints, zoneHeight = polyzoneName, nil, nil, {}, 4
        FreezeEntityPosition(playerPed, false)
        if Cam then
            RenderScriptCams(false, true, 500, true, true)
            SetCamActive(Cam, false)
            DetachCam(Cam)
            DestroyCam(Cam, true)
            Cam = nil
        end
    end
    isOpenCretor = not isOpenCretor
    ToggleInputThread()
end

function ToggleInputThread()
    Citizen.CreateThread(function()
        while isOpenCretor do
            DrawScaleformMovieFullscreen(form, 255, 255, 255, 255, 0)

            local camPos = GetCamCoord(Cam)
            for k, v in pairs(ParkingAreas) do
                -- local closestPoint, closestDistance = nil, nil
                for i, j in pairs(v.poly.points) do
                    local pointPosition = vector3(j.x, j.y, j.z)
                    local distance = #(camPos - pointPosition)
            
                    if distance < 15.0 then
                        local maxHeight = pointPosition.z + (v.poly.thickness/2)
                        local minHeight = pointPosition.z - (v.poly.thickness/2)
                        local adjustedZ = camPos.z
                
                        if camPos.z > maxHeight then
                            adjustedZ = maxHeight
                        elseif camPos.z < minHeight then
                            adjustedZ = minHeight
                        end
                
                        local adjustedPoint = vector3(pointPosition.x, pointPosition.y, adjustedZ)
                        
                        ESX.Game.Utils.DrawText3D(adjustedPoint, k, 2.0, 2)
                    end
                    -- if closestDistance == nil or distance < closestDistance then
                    --     closestDistance = distance
                    --     closestPoint = pointPosition
                    -- end
                end
            
                -- if closestPoint and closestDistance < 50.0 then
                --     local maxHeight = closestPoint.z + (v.poly.thickness/2)
                --     local minHeight = closestPoint.z - (v.poly.thickness/2)
                --     local adjustedZ = camPos.z
            
                --     if camPos.z > maxHeight then
                --         adjustedZ = maxHeight
                --     elseif camPos.z < minHeight then
                --         adjustedZ = minHeight
                --     end
            
                --     local adjustedPoint = vector3(closestPoint.x, closestPoint.y, adjustedZ)
                    
                --     ESX.Game.Utils.DrawText3D(adjustedPoint, k, 2.0, 2)
                -- end
            end
            
            
            camControls()
            DisabledControls()
            Citizen.Wait(0)
        end
    end)
    Citizen.CreateThread(function()
        debugColour = {r = math.random( 0,255 ), g = math.random( 0,255 ), b = math.random( 0,255 ), a = 50}
        
        while isOpenCretor do
            startRaycast()
            Citizen.Wait(0)
        end
    end)
end

-- #region Raycasting Functions
function startRaycast()
    local position = GetCamCoord(Cam)
    local hit, coords = RayCastGamePlayCamera(80.0)
    if hit then
        DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 15.0, 250.0, 80.0, 0.0, 250.0)
        keyControls(coords)
    end
end

function RayCastGamePlayCamera(distance)
    local playerPed = PlayerPedId()
    local cameraRotation = GetCamRot(Cam, 2)
    local cameraCoord = GetCamCoord(Cam)
    local direction = RotationToDirection(cameraRotation)
    local destination = {
        x = cameraCoord.x + direction.x * distance,
        y = cameraCoord.y + direction.y * distance,
        z = cameraCoord.z + direction.z * distance
    }
    local _, hits, coords, _, entity = GetShapeTestResult(StartShapeTestRay(cameraCoord.x, cameraCoord.y, cameraCoord.z,
        destination.x, destination.y, destination.z, -1, playerPed, 0))
    return hits, coords, entity
end

function RotationToDirection(rotation)
    local adjustedRotation = {
        x = (math.pi / 180) * rotation.x,
        y = (math.pi / 180) * rotation.y,
        z = (math.pi / 180) * rotation.z
    }
    local direction = {
        x = -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        y = math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        z = math.sin(adjustedRotation.x)
    }
    return direction
end

-- #endregion

-- #region Manage Polygon Functions
function keyControls(coords)
    if IsDisabledControlJustPressed(0, Keys[ZoneConfig.CLICK_ADD_POINT]) then
        table.insert(zonePoints, coords)

        -----------------------------------------------------------------------
        PushScaleformMovieFunction(form, "SET_DATA_SLOT")
        PushScaleformMovieFunctionParameterInt(8)
        ButtonMessage("Points: " .. #zonePoints)
        PopScaleformMovieFunctionVoid()
    
        PushScaleformMovieFunction(form, "DRAW_INSTRUCTIONAL_BUTTONS")
        PopScaleformMovieFunctionVoid()
        -----------------------------------------------------------------------
        
        refreshPolyzone()
    elseif IsDisabledControlJustPressed(0, Keys[ZoneConfig.CHANGE_COLOUR]) then
        local input = lib.inputDialog('Debug Colour', {
            {type = 'color', label = 'Colour', default = '#'..rgb2hex(debugColour.r, debugColour.g, debugColour.b)},
        })

        if not input then return end

        local r,g,b = hex2rgb(input[1])
        debugColour.r = r
        debugColour.g = g
        debugColour.b = b

        refreshPolyzone()
    elseif IsDisabledControlJustPressed(0, Keys[ZoneConfig.CLICK_DELETE_POINT]) then
        if #zonePoints > 0 then
            table.remove(zonePoints, #zonePoints)

            -----------------------------------------------------------------------
            PushScaleformMovieFunction(form, "SET_DATA_SLOT")
            PushScaleformMovieFunctionParameterInt(8)
            ButtonMessage("Points: " .. #zonePoints)
            PopScaleformMovieFunctionVoid()
        
            PushScaleformMovieFunction(form, "DRAW_INSTRUCTIONAL_BUTTONS")
            PopScaleformMovieFunctionVoid()
            -----------------------------------------------------------------------

            refreshPolyzone()
        end
    elseif IsDisabledControlPressed(0, Keys[ZoneConfig.SCROLL_DOWN]) then
        if zoneHeight > 4 then
            zoneHeight = zoneHeight - 1
            refreshPolyzone()
        end
    elseif IsDisabledControlPressed(0, Keys[ZoneConfig.SCROLL_UP]) then
        zoneHeight = zoneHeight + 1
        refreshPolyzone()
    elseif IsDisabledControlPressed(0, Keys[ZoneConfig.CLICK_SAVE_POLYZONE]) then
        if #zonePoints > 2 then
            SavePolygon(currentZoneName, zonePoints, currentZ, currentZone, zoneHeight)
        end
    elseif IsDisabledControlPressed(0, Keys[ZoneConfig.CLICK_CANCEL_POLYZONE]) then
        cancelPolygonCreator("Cancelled")
    end
end

function destroyZone(zone)
    if zone then
        
        zone:remove();
        
    end
end

function refreshPolyzone()
    destroyZone(currentZone)
    if #zonePoints > 0 then
        if #zonePoints == 1 then
            currentZ = zonePoints[1].z
        end

        zonePoints[#zonePoints] = vector3(zonePoints[#zonePoints].x, zonePoints[#zonePoints].y, currentZ)
        local loading = true
        Citizen.CreateThread(function()
            while loading do
                Wait(2000)
                if loading then
                    loading = false
                    cancelPolygonCreator("Timed out")
                end
            end
        end)
        currentZone = lib.zones.poly({
            name = currentZoneName,
            points = zonePoints,
            thickness = zoneHeight,
            debug = true,
            debugColour = debugColour
        })

        loading = false
    end
end

function SavePolygon(name, points, minZ, zone, zoneHeight)
    local success, result = pcall(function()
        G_CallBackFuntion({
            succes = true,
            name = name,
            points = points,
            minZ = minZ,
            maxZ = minZ + zoneHeight,
            zone = zone,
            thickness = zoneHeight,
            debugColour = debugColour
        })
    end)
    if not success then
        G_CallBackFuntion({
            succes = false,
            error = result
        })
    end
    toggleCretor()
end

function cancelPolygonCreator(_error)
    G_CallBackFuntion({
        succes = false,
        error = _error == nil and "Unknown" or _error
    })
    toggleCretor()
end

-- #endregion

-- #region Cam Controls Functions
function camControls()
    rotateCamInputs()
    moveCamInputs()
end

function rotateCamInputs()
    local newX
    local rAxisX = GetDisabledControlNormal(0, 220)
    local rAxisY = GetDisabledControlNormal(0, 221) -- mouse up mowe down mowe
    local rotation = GetCamRot(Cam, 2)
    local yValue = rAxisY * 5
    local newZ = rotation.z + (rAxisX * -10)
    local newXval = rotation.x - yValue
    if (newXval >= MinY) and (newXval <= MaxY) then
        newX = newXval
    end
    if newX and newZ then
        SetCamRot(Cam, vector3(newX, rotation.y, newZ), 2)
    end
end

function checkInput(index, input)
    return IsDisabledControlPressed(index, Keys[input])
end

function moveCamInputs() --
    local x, y, z = table.unpack(GetCamCoord(Cam))
    local pitch, roll, yaw = table.unpack(GetCamRot(Cam, 2))

    local dx = math.sin(-yaw * math.pi / 180) * MoveSpeed
    local dy = math.cos(-yaw * math.pi / 180) * MoveSpeed
    local dz = math.tan(pitch * math.pi / 180) * MoveSpeed

    local dx2 = math.sin(math.floor(yaw + 90.0) % 360 * -1.0 * math.pi / 180) * MoveSpeed
    local dy2 = math.cos(math.floor(yaw + 90.0) % 360 * -1.0 * math.pi / 180) * MoveSpeed

    if checkInput(0, ZoneConfig.MOVE_FORWARDS) then
        x = x + dx
        y = y + dy
    end
    
    if checkInput(0, ZoneConfig.MOVE_BACKWARDS) then
        x = x - dx
        y = y - dy
    end
    
    if checkInput(0, ZoneConfig.MOVE_RIGHT) then
        x = x - dx2
        y = y - dy2
    end
    
    if checkInput(0, ZoneConfig.MOVE_LEFT) then
        x = x + dx2
        y = y + dy2
    end
    
    if checkInput(0, ZoneConfig.MOVE_UP) then
        z = z + MoveSpeed
    end
    
    if checkInput(0, ZoneConfig.MOVE_DOWN) then
        z = z - MoveSpeed
    end
    local playerPed = PlayerPedId()
    local playercoords = GetEntityCoords(playerPed)
    if GetDistanceBetweenCoords(playercoords , vector3(x, y, z), true) <= MAX_CAM_DISTANCE then
        SetCamCoord(Cam, x, y, z)
    end
end

-- #endregion

function DisabledControls()
    DisableAllControlActions(0)
    -- EnableControlAction(0, 245, true) -- Chat
    
    -- EnableControlAction(0, 0, true)
    -- EnableControlAction(0, 1, true)
    -- EnableControlAction(0, 2, true)
    -- DisableControlAction(0, 32, true) -- W
    -- DisableControlAction(0, 33, true) -- S
    -- DisableControlAction(0, 34, true) -- A
    -- DisableControlAction(0, 35, true) -- D
    -- DisableControlAction(0, 44, true) -- Cover
    -- DisableControlAction(0, 46, true) -- E
    -- DisableControlAction(0, 69, true) -- Left Mouse
    -- DisableControlAction(0, 70, true) -- Right Mouse
    -- DisableControlAction(0, 322, true) -- ESC
    -- DisableControlAction(0, 220, true) -- Mouse Right
    -- DisableControlAction(0, 221, true) -- Mouse Down

    -- DisableControlAction(0, 24, true) -- Attack
    -- DisableControlAction(0, 257, true) -- Attack 2
    -- DisableControlAction(0, 25, true) -- Aim
    -- DisableControlAction(0, 263, true) -- Melee Attack 1
    -- DisableControlAction(0, 45, true) -- Reload
    -- DisableControlAction(0, 73, true) -- Disable clearing animation
    -- DisableControlAction(2, 199, true) -- Disable pause screen
    -- DisableControlAction(0, 59, true) -- Disable steering in vehicle
    -- DisableControlAction(0, 71, true) -- Disable driving forward in vehicle
    -- DisableControlAction(0, 72, true) -- Disable reversing in vehicle
    -- DisableControlAction(2, 36, true) -- Disable going stealth
    -- DisableControlAction(0, 47, true) -- Disable weapon
    -- DisableControlAction(0, 264, true) -- Disable melee
    -- DisableControlAction(0, 140, true) -- Disable melee
    -- DisableControlAction(0, 141, true) -- Disable melee
    -- DisableControlAction(0, 142, true) -- Disable melee
    -- DisableControlAction(0, 143, true) -- Disable melee
end