ESX = exports['es_extended']:getSharedObject()

local JobParkings = {}
local ParkingZones = {}
local CurrentParking = nil
local InCreationMode = false
local CreationData = {
    coords = nil,
    size = nil,
    height = 2.0,
    heading = 0.0,
    job = nil,
    name = nil
}

-- Recevoir les parkings depuis le serveur
RegisterNetEvent('parking_job:updateParkings', function(parkings)
    JobParkings = parkings
    CreateParkingZones()
end)

-- Créer les zones de parking
function CreateParkingZones()
    -- Supprimer les anciennes zones
    for i = 1, #ParkingZones do
        ParkingZones[i]:destroy()
    end
    ParkingZones = {}

    -- Créer les nouvelles zones
    for id, parking in pairs(JobParkings) do
        local zone = BoxZone:Create(
            vector3(parking.coords.x, parking.coords.y, parking.coords.z),
            parking.size.x,
            parking.size.y,
            {
                name = 'job_parking_' .. parking.name,
                heading = parking.heading,
                debugPoly = Config.Debug,
                minZ = parking.coords.z - 1.0,
                maxZ = parking.coords.z + parking.height
            }
        )

        zone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                CurrentParking = parking
            else
                if CurrentParking and CurrentParking.id == parking.id then
                    CurrentParking = nil
                end
            end
        end)

        table.insert(ParkingZones, zone)
    end
end

-- Event pour ouvrir le menu admin (envoyé par le serveur après vérification des permissions)
RegisterNetEvent('parking_job:openAdminMenu', function()
    lib.callback('parking_job:getParkings', false, function(parkings)
        JobParkings = parkings
        OpenAdminMenu()
    end)
end)

-- Menu admin
function OpenAdminMenu()
    local elements = {}

    -- Bouton pour créer un parking
    table.insert(elements, {
        title = 'Créer un nouveau parking',
        icon = 'plus',
        onSelect = function()
            StartParkingCreation()
        end
    })

    -- Liste des parkings existants
    table.insert(elements, {
        title = 'Liste des parkings',
        icon = 'list',
        description = 'Gérer les parkings existants'
    })

    for id, parking in pairs(JobParkings) do
        table.insert(elements, {
            title = parking.name,
            description = 'Job: ' .. parking.job,
            icon = 'parking',
            onSelect = function()
                OpenParkingOptions(parking)
            end
        })
    end

    lib.registerContext({
        id = 'parking_admin_menu',
        title = 'Gestion des Parkings',
        options = elements
    })

    lib.showContext('parking_admin_menu')
end

-- Options pour un parking spécifique
function OpenParkingOptions(parking)
    local elements = {
        {
            title = 'Supprimer ce parking',
            icon = 'trash',
            iconColor = 'red',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Confirmation',
                    content = 'Êtes-vous sûr de vouloir supprimer ce parking ?',
                    centered = true,
                    cancel = true
                })

                if confirm == 'confirm' then
                    lib.callback('parking_job:deleteParking', false, function(success, message)
                        if success then
                            lib.notify({
                                title = 'Succès',
                                description = Config.Notifications[message],
                                type = 'success'
                            })
                            OpenAdminMenu()
                        else
                            lib.notify({
                                title = 'Erreur',
                                description = Config.Notifications[message],
                                type = 'error'
                            })
                        end
                    end, parking.id)
                end
            end
        },
        {
            title = 'Retour',
            icon = 'arrow-left',
            onSelect = function()
                OpenAdminMenu()
            end
        }
    }

    lib.registerContext({
        id = 'parking_options_menu',
        title = 'Options - ' .. parking.name,
        menu = 'parking_admin_menu',
        options = elements
    })

    lib.showContext('parking_options_menu')
end

-- Démarrer la création d'un parking
function StartParkingCreation()
    -- Demander le nom du parking
    local input = lib.inputDialog('Créer un parking', {
        {
            type = 'input',
            label = 'Nom du parking',
            description = 'Nom unique du parking',
            required = true,
            min = 3,
            max = 50
        }
    })

    if not input or not input[1] then return end

    CreationData.name = input[1]

    -- Récupérer la liste des jobs
    lib.callback('parking_job:getJobs', false, function(jobs)
        local jobOptions = {}

        for i = 1, #jobs do
            table.insert(jobOptions, {
                value = jobs[i].name,
                label = jobs[i].label
            })
        end

        -- Demander le job
        local input2 = lib.inputDialog('Sélectionner le job', {
            {
                type = 'select',
                label = 'Job',
                description = 'Job autorisé pour ce parking',
                required = true,
                options = jobOptions
            },
            {
                type = 'number',
                label = 'Largeur (X)',
                description = 'Largeur de la zone en mètres',
                required = true,
                default = 10.0,
                min = 1.0,
                max = 100.0
            },
            {
                type = 'number',
                label = 'Longueur (Y)',
                description = 'Longueur de la zone en mètres',
                required = true,
                default = 10.0,
                min = 1.0,
                max = 100.0
            },
            {
                type = 'number',
                label = 'Hauteur (Z)',
                description = 'Hauteur de la zone en mètres',
                required = true,
                default = 2.0,
                min = 1.0,
                max = 10.0
            }
        })

        if not input2 then return end

        CreationData.job = input2[1]
        CreationData.size = {x = input2[2], y = input2[3]}
        CreationData.height = input2[4]

        -- Démarrer le mode création
        InCreationMode = true
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local heading = GetEntityHeading(playerPed)

        CreationData.coords = {x = coords.x, y = coords.y, z = coords.z}
        CreationData.heading = heading

        -- Créer une zone de prévisualisation
        CreatePreviewZone()

        lib.notify({
            title = 'Mode création',
            description = 'Utilisez les flèches pour ajuster la position. Appuyez sur ENTER pour valider ou BACKSPACE pour annuler.',
            type = 'info',
            duration = 8000
        })
    end)
end

-- Créer une zone de prévisualisation
function CreatePreviewZone()
    local previewZone = BoxZone:Create(
        vector3(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z),
        CreationData.size.x,
        CreationData.size.y,
        {
            name = 'preview_zone',
            heading = CreationData.heading,
            debugPoly = true,
            minZ = CreationData.coords.z - 1.0,
            maxZ = CreationData.coords.z + CreationData.height
        }
    )

    -- Thread pour gérer les contrôles
    CreateThread(function()
        while InCreationMode do
            Wait(0)

            -- Afficher les instructions
            DrawText3D(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z + 1.0, '~g~Parking: ~w~' .. CreationData.name .. '\n~g~Job: ~w~' .. CreationData.job .. '\n~y~[ENTER]~w~ Valider | ~r~[BACKSPACE]~w~ Annuler')

            -- Valider avec ENTER
            if IsControlJustPressed(0, 191) then -- ENTER
                InCreationMode = false
                previewZone:destroy()

                -- Envoyer au serveur
                lib.callback('parking_job:createParking', false, function(success, message)
                    if success then
                        lib.notify({
                            title = 'Succès',
                            description = Config.Notifications[message],
                            type = 'success'
                        })
                    else
                        lib.notify({
                            title = 'Erreur',
                            description = Config.Notifications[message],
                            type = 'error'
                        })
                    end
                end, CreationData)

                CreationData = {coords = nil, size = nil, height = 2.0, heading = 0.0, job = nil, name = nil}
            end

            -- Annuler avec BACKSPACE
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                InCreationMode = false
                previewZone:destroy()

                lib.notify({
                    title = 'Annulé',
                    description = 'Création du parking annulée',
                    type = 'error'
                })

                CreationData = {coords = nil, size = nil, height = 2.0, heading = 0.0, job = nil, name = nil}
            end

            -- Déplacer avec les flèches
            if IsControlPressed(0, 172) then -- ARROW UP
                CreationData.coords.y = CreationData.coords.y + 0.1
                previewZone:destroy()
                previewZone = BoxZone:Create(
                    vector3(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z),
                    CreationData.size.x,
                    CreationData.size.y,
                    {
                        name = 'preview_zone',
                        heading = CreationData.heading,
                        debugPoly = true,
                        minZ = CreationData.coords.z - 1.0,
                        maxZ = CreationData.coords.z + CreationData.height
                    }
                )
            end

            if IsControlPressed(0, 173) then -- ARROW DOWN
                CreationData.coords.y = CreationData.coords.y - 0.1
                previewZone:destroy()
                previewZone = BoxZone:Create(
                    vector3(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z),
                    CreationData.size.x,
                    CreationData.size.y,
                    {
                        name = 'preview_zone',
                        heading = CreationData.heading,
                        debugPoly = true,
                        minZ = CreationData.coords.z - 1.0,
                        maxZ = CreationData.coords.z + CreationData.height
                    }
                )
            end

            if IsControlPressed(0, 174) then -- ARROW LEFT
                CreationData.coords.x = CreationData.coords.x - 0.1
                previewZone:destroy()
                previewZone = BoxZone:Create(
                    vector3(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z),
                    CreationData.size.x,
                    CreationData.size.y,
                    {
                        name = 'preview_zone',
                        heading = CreationData.heading,
                        debugPoly = true,
                        minZ = CreationData.coords.z - 1.0,
                        maxZ = CreationData.coords.z + CreationData.height
                    }
                )
            end

            if IsControlPressed(0, 175) then -- ARROW RIGHT
                CreationData.coords.x = CreationData.coords.x + 0.1
                previewZone:destroy()
                previewZone = BoxZone:Create(
                    vector3(CreationData.coords.x, CreationData.coords.y, CreationData.coords.z),
                    CreationData.size.x,
                    CreationData.size.y,
                    {
                        name = 'preview_zone',
                        heading = CreationData.heading,
                        debugPoly = true,
                        minZ = CreationData.coords.z - 1.0,
                        maxZ = CreationData.coords.z + CreationData.height
                    }
                )
            end
        end
    end)
end

-- Fonction pour afficher du texte 3D
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = GetDistanceBetweenCoords(px, py, pz, x, y, z, 1)
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov

    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- Charger les parkings au démarrage (accessible à tous pour les polyzones)
CreateThread(function()
    Wait(2000)
    lib.callback('parking_job:getAllParkings', false, function(parkings)
        JobParkings = parkings
        CreateParkingZones()
    end)
end)
