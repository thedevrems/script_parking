ESX = exports['es_extended']:getSharedObject()

local Spawned = {}

ParkedVehicles = {}
VehiclesInCell = {}

ped = nil
pCoords = nil

PlayerCell = {}
ActiveCells = {}

local myVeh = nil

RegisterNetEvent(ResourceName .. ':Load', function(_VehiclesInCell, _ParkedVehicles)
    VehiclesInCell = _VehiclesInCell
    ParkedVehicles = _ParkedVehicles
end)

AddEventHandler('onResourceStop', function(resName)
    if ResourceName == resName then
        for plate, spawned in pairs(Spawned) do
            print("Deleted", plate, spawned.vehicle)
            DeleteVehicle(spawned.vehicle)
        end
    end
end)

Citizen.CreateThread(function()
    local PreviousActiveCells = {}
    
    while true do
        ped = PlayerPedId()
        pCoords = GetEntityCoords(ped)

        PreviousActiveCells = shallow_copy(ActiveCells)
        ActiveCells = GetSurroundingGridCells(pCoords.x, pCoords.y)

        local gridX, gridY = ActiveCells[1].x, ActiveCells[1].y

        if PlayerCell.x == nil or PlayerCell.y == nil then
            PlayerCell = { x = gridX, y = gridY }
        end

        if PlayerCell.x ~= gridX or PlayerCell.y ~= gridY then
            PlayerCell = { x = gridX, y = gridY }

            TrashCells = GetTrashGridCells(PreviousActiveCells, ActiveCells)

            for k,grid in pairs(TrashCells) do
                if VehiclesInCell[grid.x] ~= nil and VehiclesInCell[grid.x][grid.y] ~= nil then
                    for plate,position in pairs(VehiclesInCell[grid.x][grid.y]) do
                        if Spawned[plate] ~= nil then
                            print("(-) Deleted", plate, Spawned[plate].vehicle)

                            DeleteVehicle(Spawned[plate].vehicle)

                            Spawned[plate] = nil
                        end
                    end
                end
            end
            
            for plate,vehicle in pairs(Spawned) do
                if not ParkedVehicles[plate] then
                    DeleteVehicle(vehicle)
                    Spawned[plate] = nil
                end
            end
        end

        Wait(1000)
    end
end)

Citizen.CreateThread(function()
    while true do
        
        for k,grid in pairs(ActiveCells) do
            if VehiclesInCell[grid.x] ~= nil and VehiclesInCell[grid.x][grid.y] ~= nil then
                local dist
                for plate,position in pairs(VehiclesInCell[grid.x][grid.y]) do

                    if not Spawned[plate] then
                        local vehData = ParkedVehicles[plate]
                        
                        
                        Spawned[plate] = {
                            vehicle = CreateParkingCar(vehData),
                            coords = vehData.position
                        }

                        print("(+) Spawned", plate, Spawned[plate].vehicle)
                    end
                end
            end
        end

        Wait(1000)
    end
end)

function CreateParkingCar(vehData)
    if not vehData.properties then return false end
    local model = (type(vehData.properties.model) == 'number' and vehData.properties.model or GetHashKey(vehData.properties.model))
    RequestModel(model)
    while not HasModelLoaded(model) do
        Citizen.Wait(0)
    end
    local vehicle = CreateVehicle(model, vehData.position, 0.0, false, false)
    SetEntityCoordsNoOffset(vehicle, vehData.position)
    SetEntityRotation(vehicle, vehData.rotation, 2, true)
    SetVehicleOnGroundProperly(vehicle)
    
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)
    SetVehicleUndriveable(vehicle, true)

    SetVehicleProperties(vehicle, vehData.properties)
    SetVehicleEngineOn(vehicle, false, false, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityInvincible(vehicle, true)
    FreezeEntityPosition(vehicle, true)
    if vehData.data then
        SetVehicleExtraData(vehicle, vehData.data)
    end
    return vehicle
end

RegisterNetEvent(ResourceName .. ':VehicleAdded', function(vehData, vehicle)
    if vehicle == myVeh and DoesEntityExist(vehicle) then
        myVeh = nil
        DeleteVehicle(vehicle)
    end

    ParkedVehicles[vehData.plate] = vehData

    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if not VehiclesInCell[gridX] then
        VehiclesInCell[gridX] = {}
    end
    if not VehiclesInCell[gridX][gridY] then
        VehiclesInCell[gridX][gridY] = {}
    end

    VehiclesInCell[gridX][gridY][vehData.plate] = vehData.position
end)


RegisterNetEvent(ResourceName .. ':VehicleRemoved', function(plate, vehicle)
    local vehData = ParkedVehicles[plate]

    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if VehiclesInCell[gridX] and VehiclesInCell[gridX][gridY] then
        VehiclesInCell[gridX][gridY][plate] = nil
    end

    if vehicle == myVeh then
        myVeh = nil
        while not NetworkGetEntityIsNetworked(vehicle) do
            NetworkRegisterEntityAsNetworked(vehicle)
            Citizen.Wait(100)
        end
        FreezeEntityPosition(vehicle, false)
        SetEntityInvincible(vehicle, false)
        SetVehicleDoorsLocked(vehicle, 0)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        SetVehicleUndriveable(vehicle, false)
		print(vehicle)
		TriggerServerEvent(ResourceName .. ':SetVehiclePersistent', vehicle)

    end
    Spawned[plate] = nil

    ParkedVehicles[plate] = nil
end)

RegisterCommand('setvp', function()

	local ped = PlayerPedId()
	local veh = GetVehiclePedIsIn(ped, true)
	print(DoesEntityExist(veh), veh)
	TriggerServerEvent(ResourceName .. ':SetVehiclePersistent', veh, NetworkGetNetworkIdFromEntity(veh))
end)

RegisterNetEvent(ResourceName .. ':VehicleImpounded', function(plate)
    local vehData = ParkedVehicles[plate]

    local gridX, gridY = GetGridCell(vehData.position.x, vehData.position.y)

    if VehiclesInCell[gridX] and VehiclesInCell[gridX][gridY] then
        VehiclesInCell[gridX][gridY][plate] = nil
    end
    
    ParkedVehicles[plate] = nil
    
    if Spawned[plate] then
        DeleteVehicle(Spawned[plate].vehicle)
        
        Spawned[plate] = nil
    end

end)

local wait = false
Citizen.CreateThread(function()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'ox_target:parkVeh',
            icon = 'fa-solid fa-square-parking',
            label = "Park Vehicle",
            distance = 2,
            canInteract = function(entity, distance, coords, name)
				if not DoesEntityExist(entity) then return false end
                local plate = GetVehicleNumberPlateText(entity)
				plate = plate:gsub("^%s*(.-)%s*$", "%1")
                return not wait and not IsPedInAnyVehicle(ped, true) and not ParkedVehicles[plate] -- CanPark(entity)
            end,
            args = {},
            onSelect = function(d1)
                if not wait then
                    local plate = GetVehicleNumberPlateText(d1.entity):gsub("^%s*(.-)%s*$", "%1")
					local vehnetid = NetworkGetNetworkIdFromEntity(d1.entity)
					print(d1.entity, vehnetid, "'"..plate)
					TriggerServerEvent('setpersistent', vehnetid)
    
                    -- local coords = GetEntityCoords(d1.entity)
                    -- local ParkingArea = exports.ParkingCreator:GetParkingAreaByCoords(coords)
    
                    -- if ParkingArea == nil then
                    --     ESX.ShowNotification("You can only park in parking area")
                    -- else
                    --     wait = true
                    --     myVeh = d1.entity
                    --     ESX.TriggerServerCallback(ResourceName .. ':ParkVehicle', function(success, message)
                    --         if not success then
                    --             myVeh = nil
                    --             ESX.ShowNotification(message)
                    --         end
                    --         wait = false
                    --     end, {
                    --         plate       = plate,
                    --         position    = GetEntityCoords(myVeh),
                    --         rotation    = GetEntityRotation(myVeh, 2),
                    --         data        = GetVehicleExtraData(myVeh),
                    --         properties  = GetVehicleProperties(myVeh),
                    --     }, myVeh, ParkingArea)
                    -- end
                end
            end
        }
    })

    exports.ox_target:addGlobalVehicle({
        {
            name = 'ox_target:retVeh',
            icon = 'fa-solid fa-square-parking',
            label = "Retrieve Vehicle",
            distance = 2,
            canInteract = function(entity, distance, coords, name)
				if not DoesEntityExist(entity) then return false end
                local plate = GetVehicleNumberPlateText(entity)
				plate = plate:gsub("^%s*(.-)%s*$", "%1")
                return not wait and not IsPedInAnyVehicle(ped, true) and ParkedVehicles[plate] and Spawned[plate] and Spawned[plate].vehicle == entity
            end,
            args = {},
            onSelect = function(d1)
                if not wait then
                    local plate = GetVehicleNumberPlateText(d1.entity):gsub("^%s*(.-)%s*$", "%1")
    
                    local coords = GetEntityCoords(d1.entity)
                    local ParkingArea = exports.ParkingCreator:GetParkingAreaByCoords(coords)
    
                    if ParkingArea == nil then
                        ESX.ShowNotification("This vehicle doesnt belong here. Sending it to impound")
                        -- send vehicle to impound code here
                    else
                        wait = true
                        myVeh = d1.entity
                        ESX.TriggerServerCallback(ResourceName .. ':RetrieveVehicle', function(success, message)
                            if not success then
                                ESX.ShowNotification(message)
                            end
                            wait = false
                        end, plate, myVeh, ParkingArea)
                    end
                end
            end
        }
    })

    exports.ox_target:addGlobalVehicle({
        {
            name = 'ox_target:impVeh',
            icon = 'fa-solid fa-truck-pickup',
            label = "Impound Vehicle",
            distance = 2,
            canInteract = function(entity, distance, coords, name)
				if not DoesEntityExist(entity) then return false end
                local plate = GetVehicleNumberPlateText(entity)
				plate = plate:gsub("^%s*(.-)%s*$", "%1")
                return not wait and not IsPedInAnyVehicle(ped, true) and ParkedVehicles[plate] and Spawned[plate] and Spawned[plate].vehicle == entity and ESX.GetPlayerData().job.name == 'police'
            end,
            args = {},
            onSelect = function(d1)
                if not wait then
                    wait = true

                    local plate = GetVehicleNumberPlateText(d1.entity):gsub("^%s*(.-)%s*$", "%1")
    
                    local vehicle = d1.entity
                    
                    -- myVeh = vehicle

                    ESX.TriggerServerCallback(ResourceName .. ':ImpoundVehicle', function(success, message)
                        if not success then
                            -- myVeh = nil
                        else

                            -- while not NetworkGetEntityIsNetworked(vehicle) do
                            --     NetworkRegisterEntityAsNetworked(vehicle)
                            --     Citizen.Wait(100)
                            -- end

                            -- ESX.TriggerServerCallback(ResourceName .. ':FinalizeImpound', function(success, message)
                            --     if not success then
                            --         NetworkUnregisterNetworkedEntity(vehicle)
                            --     end
                            --     ESX.ShowNotification(message)
                            -- end, args)
                        end
                        ESX.ShowNotification(message)

                        wait = false
                    end, plate)
                end
            end
        }
    })
end)

-- Get vehicle extra data, you can use this to store extra data (such as fuel) for the vehicle to database
-- Args: (number) vehicle
-- Return: table
function GetVehicleExtraData(vehicle)
    -- For Standalone
    return {
        damage = exports.VehicleDeformation:GetVehicleDeformation(vehicle) -- GetVehicleDamageData(vehicle),
    }
end

-- Set vehicle extra data
-- Args: (number) vehicle, (table) data
function SetVehicleExtraData(vehicle, data)
    -- For Standalone
    if data and data.damage then
		exports.VehicleDeformation:SetVehicleDeformation(vehicle, data.damage)
        -- SetVehicleDamageData(vehicle, data.damage)
    end
end

-- Get vehicle properties
function GetVehicleProperties(vehicle)
    if not DoesEntityExist(vehicle) then
        return {}
    end
    local color1, color2               = GetVehicleColours(vehicle)
	local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
	local c1r, c1g, c1b                = GetVehicleCustomPrimaryColour(vehicle)
	local c2r, c2g, c2b                = GetVehicleCustomSecondaryColour(vehicle)
	local customcolor1                 = { r = c1r, g = c1g, b = c1b }
	local customcolor2                 = { r = c2r, g = c2g, b = c2b }
	local modExtras                    = {}
	local windowIntact                 = {}
	local tyreBurst                    = {}
	local doorDamage                   = {}

	for i = 0, 14 do
		table.insert(modExtras, IsVehicleExtraTurnedOn(vehicle, i))
	end

	for i = 0, 7 do
		table.insert(windowIntact, IsVehicleWindowIntact(vehicle, i))
	end

	for i = 0, 5 do
		local complete = IsVehicleTyreBurst(vehicle, i, true)
		if complete then
			table.insert(tyreBurst, 2)
		else
			local onRim = IsVehicleTyreBurst(vehicle, i, false)
			table.insert(tyreBurst, onRim and 1 or 0)
		end
	end

	for i = 0, 5 do
		table.insert(doorDamage, IsVehicleDoorDamaged(vehicle, i))
	end

	return {
		model             = GetEntityModel(vehicle),
		plate             = GetVehicleNumberPlateText(vehicle):gsub("^%s*(.-)%s*$", "%1"),
		plateIndex        = GetVehicleNumberPlateTextIndex(vehicle),
		health            = GetEntityHealth(vehicle),
		dirtLevel         = GetVehicleDirtLevel(vehicle),
		color1            = color1,
		color2            = color2,
		livery            = GetVehicleLivery(vehicle),
		fuelLevel         = GetVehicleFuelLevel(vehicle),
		bodyHealth        = GetVehicleBodyHealth(vehicle),
		engineHealth      = GetVehicleEngineHealth(vehicle),
		tankHealth        = GetVehiclePetrolTankHealth(vehicle),
		pearlescentColor  = pearlescentColor,
		wheelColor        = wheelColor,
		dashColor         = GetVehicleDashboardColor(vehicle),
		interiorColor     = GetVehicleInteriorColor(vehicle),
		wheels            = GetVehicleWheelType(vehicle),
		windowTint        = GetVehicleWindowTint(vehicle),
		tyresCanBurst     = GetVehicleTyresCanBurst(vehicle),
		neonEnabled       = {
			IsVehicleNeonLightEnabled(vehicle, 0),
			IsVehicleNeonLightEnabled(vehicle, 1),
			IsVehicleNeonLightEnabled(vehicle, 2),
			IsVehicleNeonLightEnabled(vehicle, 3)
		},
		neonColor         = table.pack(GetVehicleNeonLightsColour(vehicle)),
		tyreSmokeColor    = table.pack(GetVehicleTyreSmokeColor(vehicle)),
		xenonColor        = GetVehicleXenonLightsColour(vehicle),
		modSpoilers       = GetVehicleMod(vehicle, 0),
		modFrontBumper    = GetVehicleMod(vehicle, 1),
		modRearBumper     = GetVehicleMod(vehicle, 2),
		modSideSkirt      = GetVehicleMod(vehicle, 3),
		modExhaust        = GetVehicleMod(vehicle, 4),
		modFrame          = GetVehicleMod(vehicle, 5),
		modGrille         = GetVehicleMod(vehicle, 6),
		modHood           = GetVehicleMod(vehicle, 7),
		modFender         = GetVehicleMod(vehicle, 8),
		modRightFender    = GetVehicleMod(vehicle, 9),
		modRoof           = GetVehicleMod(vehicle, 10),
		modEngine         = GetVehicleMod(vehicle, 11),
		modBrakes         = GetVehicleMod(vehicle, 12),
		modTransmission   = GetVehicleMod(vehicle, 13),
		modHorns          = GetVehicleMod(vehicle, 14),
		modSuspension     = GetVehicleMod(vehicle, 15),
		modArmor          = GetVehicleMod(vehicle, 16),
		modTurbo          = IsToggleModOn(vehicle, 18),
		modSmokeEnabled   = IsToggleModOn(vehicle, 20),
		modXenon          = IsToggleModOn(vehicle, 22),
		modFrontWheels    = GetVehicleMod(vehicle, 23),
		modBackWheels     = GetVehicleMod(vehicle, 24),
		modPlateHolder    = GetVehicleMod(vehicle, 25),
		modVanityPlate    = GetVehicleMod(vehicle, 26),
		modTrimA          = GetVehicleMod(vehicle, 27),
		modOrnaments      = GetVehicleMod(vehicle, 28),
		modDashboard      = GetVehicleMod(vehicle, 29),
		modDial           = GetVehicleMod(vehicle, 30),
		modDoorSpeaker    = GetVehicleMod(vehicle, 31),
		modSeats          = GetVehicleMod(vehicle, 32),
		modSteeringWheel  = GetVehicleMod(vehicle, 33),
		modShifterLeavers = GetVehicleMod(vehicle, 34),
		modAPlate         = GetVehicleMod(vehicle, 35),
		modSpeakers       = GetVehicleMod(vehicle, 36),
		modTrunk          = GetVehicleMod(vehicle, 37),
		modHydrolic       = GetVehicleMod(vehicle, 38),
		modEngineBlock    = GetVehicleMod(vehicle, 39),
		modAirFilter      = GetVehicleMod(vehicle, 40),
		modStruts         = GetVehicleMod(vehicle, 41),
		modArchCover      = GetVehicleMod(vehicle, 42),
		modAerials        = GetVehicleMod(vehicle, 43),
		modTrimB          = GetVehicleMod(vehicle, 44),
		modTank           = GetVehicleMod(vehicle, 45),
		modWindows        = GetVehicleMod(vehicle, 46),
		modLivery         = GetVehicleMod(vehicle, 48),
		modExtras		  = modExtras,
		windowIntact	  = windowIntact,
		tyreBurst		  = tyreBurst,
		doorDamage		  = doorDamage,
	}
end

-- Set vehicle properties
function SetVehicleProperties(vehicle, props)
    SetVehicleModKit(vehicle, 0)

	if props.plate ~= nil then
		SetVehicleNumberPlateText(vehicle, props.plate)
	end

	if props.plateIndex ~= nil then
		SetVehicleNumberPlateTextIndex(vehicle, props.plateIndex)
	end

	if props.health ~= nil then
		SetEntityHealth(vehicle, props.health)
	end

	if props.dirtLevel ~= nil then
		SetVehicleDirtLevel(vehicle, props.dirtLevel)
	end

	if props.color1 ~= nil then
		local color1, color2 = GetVehicleColours(vehicle)
		SetVehicleColours(vehicle, props.color1, color2)
	end

	if props.color2 ~= nil then
		local color1, color2 = GetVehicleColours(vehicle)
		SetVehicleColours(vehicle, color1, props.color2)
	end

	if props.pearlescentColor ~= nil then
		local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
		SetVehicleExtraColours(vehicle, props.pearlescentColor, wheelColor)
	end

	if props.wheelColor ~= nil then
		local pearlescentColor, wheelColor = GetVehicleExtraColours(vehicle)
		SetVehicleExtraColours(vehicle, pearlescentColor, props.wheelColor)
	end

	if props.dashColor ~= nil then
		SetVehicleDashboardColor(vehicle, props.dashColor)
	end

	if props.interiorColor ~= nil then
		SetVehicleInteriorColor(vehicle, props.interiorColor)
	end

	if props.wheels ~= nil then
		SetVehicleWheelType(vehicle, props.wheels)
	end

	if props.windowTint ~= nil then
		SetVehicleWindowTint(vehicle, props.windowTint)
	end

	if props.tyresCanBurst ~= nil then
		SetVehicleTyresCanBurst(vehicle, tonumber(props.tyresCanBurst) == 1 and true or false)
	end

	if props.neonEnabled ~= nil then
		SetVehicleNeonLightEnabled(vehicle, 0, props.neonEnabled[1])
		SetVehicleNeonLightEnabled(vehicle, 1, props.neonEnabled[2])
		SetVehicleNeonLightEnabled(vehicle, 2, props.neonEnabled[3])
		SetVehicleNeonLightEnabled(vehicle, 3, props.neonEnabled[4])
	end

	if props.neonColor ~= nil then
		SetVehicleNeonLightsColour(vehicle, props.neonColor[1], props.neonColor[2], props.neonColor[3])
	end
	
	if props.xenonColor ~= nil then
		SetVehicleXenonLightsColour(vehicle, props.xenonColor)
	end

	if props.modSmokeEnabled ~= nil then
		ToggleVehicleMod(vehicle, 20, true)
	end

	if props.tyreSmokeColor ~= nil then
		SetVehicleTyreSmokeColor(vehicle, props.tyreSmokeColor[1], props.tyreSmokeColor[2], props.tyreSmokeColor[3])
	end

	if props.modSpoilers ~= nil then
		SetVehicleMod(vehicle, 0, props.modSpoilers, false)
	end

	if props.modFrontBumper ~= nil then
		SetVehicleMod(vehicle, 1, props.modFrontBumper, false)
	end

	if props.modRearBumper ~= nil then
		SetVehicleMod(vehicle, 2, props.modRearBumper, false)
	end

	if props.modSideSkirt ~= nil then
		SetVehicleMod(vehicle, 3, props.modSideSkirt, false)
	end

	if props.modExhaust ~= nil then
		SetVehicleMod(vehicle, 4, props.modExhaust, false)
	end

	if props.modFrame ~= nil then
		SetVehicleMod(vehicle, 5, props.modFrame, false)
	end

	if props.modGrille ~= nil then
		SetVehicleMod(vehicle, 6, props.modGrille, false)
	end

	if props.modHood ~= nil then
		SetVehicleMod(vehicle, 7, props.modHood, false)
	end

	if props.modFender ~= nil then
		SetVehicleMod(vehicle, 8, props.modFender, false)
	end

	if props.modRightFender ~= nil then
		SetVehicleMod(vehicle, 9, props.modRightFender, false)
	end

	if props.modRoof ~= nil then
		SetVehicleMod(vehicle, 10, props.modRoof, false)
	end

	if props.modEngine ~= nil then
		SetVehicleMod(vehicle, 11, props.modEngine, false)
	end

	if props.modBrakes ~= nil then
		SetVehicleMod(vehicle, 12, props.modBrakes, false)
	end

	if props.modTransmission ~= nil then
		SetVehicleMod(vehicle, 13, props.modTransmission, false)
	end

	if props.modHorns ~= nil then
		SetVehicleMod(vehicle, 14, props.modHorns, false)
	end

	if props.modSuspension ~= nil then
		SetVehicleMod(vehicle, 15, props.modSuspension, false)
	end

	if props.modArmor ~= nil then
		SetVehicleMod(vehicle, 16, props.modArmor, false)
	end

	if props.modTurbo ~= nil then
		ToggleVehicleMod(vehicle,  18, props.modTurbo)
	end

	if props.modXenon ~= nil then
		ToggleVehicleMod(vehicle,  22, props.modXenon)
	end

	if props.modFrontWheels ~= nil then
		SetVehicleMod(vehicle, 23, props.modFrontWheels, false)
	end

	if props.modBackWheels ~= nil then
		SetVehicleMod(vehicle, 24, props.modBackWheels, false)
	end

	if props.modPlateHolder ~= nil then
		SetVehicleMod(vehicle, 25, props.modPlateHolder, false)
	end

	if props.modVanityPlate ~= nil then
		SetVehicleMod(vehicle, 26, props.modVanityPlate, false)
	end

	if props.modTrimA ~= nil then
		SetVehicleMod(vehicle, 27, props.modTrimA, false)
	end

	if props.modOrnaments ~= nil then
		SetVehicleMod(vehicle, 28, props.modOrnaments, false)
	end

	if props.modDashboard ~= nil then
		SetVehicleMod(vehicle, 29, props.modDashboard, false)
	end

	if props.modDial ~= nil then
		SetVehicleMod(vehicle, 30, props.modDial, false)
	end

	if props.modDoorSpeaker ~= nil then
		SetVehicleMod(vehicle, 31, props.modDoorSpeaker, false)
	end

	if props.modSeats ~= nil then
		SetVehicleMod(vehicle, 32, props.modSeats, false)
	end

	if props.modSteeringWheel ~= nil then
		SetVehicleMod(vehicle, 33, props.modSteeringWheel, false)
	end

	if props.modShifterLeavers ~= nil then
		SetVehicleMod(vehicle, 34, props.modShifterLeavers, false)
	end

	if props.modAPlate ~= nil then
		SetVehicleMod(vehicle, 35, props.modAPlate, false)
	end

	if props.modSpeakers ~= nil then
		SetVehicleMod(vehicle, 36, props.modSpeakers, false)
	end

	if props.modTrunk ~= nil then
		SetVehicleMod(vehicle, 37, props.modTrunk, false)
	end

	if props.modHydrolic ~= nil then
		SetVehicleMod(vehicle, 38, props.modHydrolic, false)
	end

	if props.modEngineBlock ~= nil then
		SetVehicleMod(vehicle, 39, props.modEngineBlock, false)
	end

	if props.modAirFilter ~= nil then
		SetVehicleMod(vehicle, 40, props.modAirFilter, false)
	end

	if props.modStruts ~= nil then
		SetVehicleMod(vehicle, 41, props.modStruts, false)
	end

	if props.modArchCover ~= nil then
		SetVehicleMod(vehicle, 42, props.modArchCover, false)
	end

	if props.modAerials ~= nil then
		SetVehicleMod(vehicle, 43, props.modAerials, false)
	end

	if props.modTrimB ~= nil then
		SetVehicleMod(vehicle, 44, props.modTrimB, false)
	end

	if props.modTank ~= nil then
		SetVehicleMod(vehicle, 45, props.modTank, false)
	end

	if props.modWindows ~= nil then
		SetVehicleMod(vehicle, 46, props.modWindows, false)
	end

	if props.modLivery ~= nil then
		SetVehicleMod(vehicle, 48, props.modLivery, false)
	end
	
	if props.livery ~= nil then
		SetVehicleLivery(vehicle, props.livery)
	end
	
	if props.bodyHealth ~= nil then
		SetVehicleBodyHealth(vehicle, props.bodyHealth)
	end
	
	if props.engineHealth ~= nil then
		SetVehicleEngineHealth(vehicle, props.engineHealth)
	end
	
	if props.tankHealth ~= nil then
		SetVehiclePetrolTankHealth(vehicle, props.tankHealth)
	end

	if props.modExtras ~= nil and type(props.modExtras) == 'table' then
		for k, v in pairs(props.modExtras) do
			SetVehicleExtra(vehicle, tonumber(k - 1), not v)
		end
	end

	if props.windowIntact ~= nil and type(props.windowIntact) == 'table' then
		for k, v in pairs(props.windowIntact) do
			if not v then
				SmashVehicleWindow(vehicle, k - 1)
			end
		end
	end

	if props.tyreBurst ~= nil and type(props.tyreBurst) == 'table' then
		for k, v in pairs(props.tyreBurst) do
			if v == 1 then
				SetVehicleTyreBurst(vehicle, k - 1, true, 0.0)
			elseif v == 2 then
				SetVehicleTyreBurst(vehicle, k - 1, true, 1000.0)
			end
		end
	end

	if props.doorDamage ~= nil and type(props.doorDamage) == 'table' then
		for k, v in pairs(props.doorDamage) do
			if v then
				SetVehicleDoorBroken(vehicle, k - 1, true)
			end
		end
	end

	if props.fuelLevel then
		SetVehicleFuelLevel(vehicle, tonumber(props.fuelLevel) + 0.0)
		if DecorGetFloat(vehicle,'_FUEL_LEVEL') then
			DecorSetFloat(vehicle,'_FUEL_LEVEL', tonumber(props.fuelLevel) + 0.0)
		end
	end
end

function GetVehicleDamageData(vehicle)
    print(vehicle)
	if not vehicle or not DoesEntityExist(vehicle) then
		return false
	end
	local model    = GetEntityModel(vehicle)
	local min, max = GetModelDimensions(model)
	local position = GetDamagePositions(min, max)
	local damages  = {}
	for k, v in pairs(position) do
		local damagePos = GetVehicleDeformationAtPos(vehicle, v)
		if #(damagePos) > 0.05 then
			table.insert(damages, { pos = v, data = #(damagePos) })
		end
	end
	return damages
end

function SetVehicleDamageData(vehicle, damages)
	if not vehicle or not DoesEntityExist(vehicle) or type(damages) ~= 'table' then
		return
	end
	local model    = GetEntityModel(vehicle)
	local min, max = GetModelDimensions(model)
	local size     = #(max - min) * 40.0
	local handling = GetVehicleHandlingFloat(vehicle, "CHandlingData", "fDeformationDamageMult")
	local multiple = 20.0
	local num      = 0
	multipleList = { { k = 0.55, v = 1000.0 }, { k = 0.65, v = 400.0 }, { k = 0.75, v = 200.0 } }
	for k, v in pairs(multipleList) do
		if handling < v.k then
			multiple = v.v
			break
		end
	end
	for k, v in pairs(damages) do v.pos = vec3(v.pos.x, v.pos.y, v.pos.z) end
	while true do
		if not DoesEntityExist(vehicle) then break end
		local find = false
		for k, v in pairs(damages) do
			local damagePos = GetVehicleDeformationAtPos(vehicle, v.pos)
			if #(damagePos) < v.data then
				local offset = v.pos * 2.0
				local damage = v.data * multiple
				SetVehicleDamage(vehicle, offset.x, offset.y, offset.z, damage, size, true)
				find = true
			end
		end
		num = num + 1
		if num > 50 then break end
		Wait(1)
	end
end

function GetDamagePositions(min, max)
	local pos = {
		x = (max.x - min.x) * 0.5, y = (max.y - min.y) * 0.5,
		z = (max.z - min.z) * 0.5, h = (max.y - min.y) * 0.5 * 0.5,
	}
	return {
		vec3(-pos.x, pos.y, 0.0),  vec3(-pos.x, pos.y, pos.z),  vec3(0.0, pos.y, 0.0),
		vec3(0.0, -pos.y, pos.z),  vec3(pos.x, -pos.y, 0.0),    vec3(pos.x, -pos.y, pos.z),
		vec3(0.0, pos.y, pos.z),   vec3(pos.x, pos.y, 0.0),     vec3(pos.x, pos.y, pos.z),
		vec3(-pos.x, -pos.y, 0.0), vec3(-pos.x, -pos.y, pos.z), vec3(0.0, -pos.y, 0.0),
		vec3(-pos.x, pos.h, 0.0),  vec3(-pos.x, pos.h, pos.z),  vec3(0.0, pos.h, 0.0),
		vec3(0.0, -pos.h, pos.z),  vec3(pos.x, -pos.h, 0.0),    vec3(pos.x, -pos.h, pos.z),
		vec3(0.0, pos.h, pos.z),   vec3(pos.x, pos.h, 0.0),     vec3(pos.x, pos.h, pos.z),
		vec3(0.0, 0.0, pos.z),     vec3(pos.x, 0.0, 0.0),       vec3(pos.x, 0.0, pos.z),
		vec3(-pos.x, 0.0, 0.0),    vec3(-pos.x, 0.0, pos.z),    vec3(0.0, 0.0, 0.0),
		vec3(-pos.x, -pos.h, 0.0), vec3(-pos.x, -pos.h, pos.z), vec3(0.0, -pos.h, 0.0),
	}
end

-- Citizen.CreateThread(function()
--     while true do
--         ped = PlayerPedId()
--         pCoords = GetEntityCoords(ped)
--         ActiveCells = GetSurroundingGridCells(GetGridCell(pCoords.x, pCoords.y))

--         for plate,vehData in pairs(Spawned) do
--             local vehCoords = vehData.coords

--             local distance = GetDistanceBetweenCoords(vehCoords, pCoords)

--             if distance > 50.0 then
--                 DeleteVehicle(vehData.entity)
--                 Spawned[plate] = nil
--             end
--         end

--         Wait(3000)
--     end
-- end)
-- RegisterNetEvent('eventName:InitParkings', function(_Parkings)
--     for k,v in pairs(_Parkings) do
--         CreateParkingThread(k, v)
--     end
-- end)

-- CreateParkingThread = function(parking, vehicles)
--     Parkings[parking] = vehicles

--     Citizen.CreateThread(function()
--         while true do
--             Wait(1000)
--         end
--     end)
-- end

-- function drawNearbyGrids(x, y, z)
--     local surroundingGrids = GetSurroundingGridCells(x, y)

--     for k,grid in pairs(surroundingGrids) do
--         draw(grid.x, grid.y, z)
--     end
    
-- end

-- function draw(gridX, gridY, z)
--         -- Get the corners of the player's grid cell
--         local corners = GetGridCellCorners(gridX, gridY)

--         local midX, midY = GetGridCellMidpoint(gridX, gridY)

--         -- local _, groundZ = GetGroundZFor_3dCoord(midX, midY, z) -- Pass a high Z value to ensure it gets the ground level
--         local groundZ = z

--         -- Draw the grid cell by connecting the correct corners
--         -- Top-left to Top-right
--         DrawLine(corners.topLeft.x, corners.topLeft.y, groundZ, corners.topRight.x, corners.topRight.y, groundZ, 255, 0, 0, 255)
--         -- Top-right to Bottom-right
--         DrawLine(corners.topRight.x, corners.topRight.y, groundZ, corners.bottomRight.x, corners.bottomRight.y, groundZ, 255, 0, 0, 255)
--         -- Bottom-right to Bottom-left
--         DrawLine(corners.bottomRight.x, corners.bottomRight.y, groundZ, corners.bottomLeft.x, corners.bottomLeft.y, groundZ, 255, 0, 0, 255)
--         -- Bottom-left to Top-left
--         DrawLine(corners.bottomLeft.x, corners.bottomLeft.y, groundZ, corners.topLeft.x, corners.topLeft.y, groundZ, 255, 0, 0, 255)
        
--         DrawLine(midX, midY, groundZ - 1000.0, midX, midY, groundZ + 1000.0, 0, 255, 0, 255)
-- end

-- -- Use a thread to constantly draw the grid
-- Citizen.CreateThread(function()
--     while true do
--         Citizen.Wait(0) -- Run every frame

--         local ped = PlayerPedId()
--         local coords = GetEntityCoords(ped)

--         -- Get the grid coordinates of the player
--         local gridX, gridY = GetGridCell(coords.x, coords.y)

--         -- Draw the current grid cell at ground Z
--         -- draw(gridX, gridY, coords.z)

--         -- Draw surrounding grids at ground Z
--         drawNearbyGrids(coords.x, coords.y, coords.z)

--         -- Debug message to show the grid coordinates
--         ESX.ShowHelpNotification("You are in grid " .. gridX .. "," .. gridY)
--     end
-- end)


























-- Citizen.CreateThread(function()
--     print("test")
-- end)

-- RegisterNetEvent('eventName:InitParkingThreads', function(_Parkings)
--     for k,v in pairs(_Parkings) do
--         Citizen.CreateThread(function()
--             local parking = k
--             Parkings[parking] = v

--             while next(Parkings[parking]) do
--                 for plate, vehicle_info in pairs(Parkings[parking]) do

--                     local vehPos = vehicle_info.position
--                     local vehCoords = vector3(vehPos.x, vehPos.y, vehPos.z)
--                     local vehRot = vehPos.heading

--                     local distance = GetDistanceBetweenCoords(vehCoords, pCoords)

--                     if distance <= 50.0 then
--                         if not Spawned[plate] then
--                             -- Spawn
--                             local vehicle = CreateVehicle(vehicle_info.model, vehCoords, vehRot, true, false)
--                             Spawned[plate] = {
--                                 entity = vehicle,
--                                 coords = vehCoords
--                             }
--                         end
--                     end
--                 end
--                 Wait(1000)
--             end
--         end)
--     end
-- end)