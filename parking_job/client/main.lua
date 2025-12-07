ESX = exports['es_extended']:getSharedObject()

local JobParkings = {}
local ParkingZones = {}
local CurrentParking = nil
local InCreationMode = false
local CreationData = {
    points = {},
    height = 2.0,
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
        ParkingZones[i]:remove()
    end
    ParkingZones = {}

    -- Créer les nouvelles zones avec ox_lib
    for id, parking in pairs(JobParkings) do
        -- Convertir les points en format vec3
        local points = {}
        for i = 1, #parking.points do
            table.insert(points, vec3(parking.points[i].x, parking.points[i].y, parking.points[i].z))
        end

        local zone = lib.zones.poly({
            points = points,
            thickness = parking.height,
            debug = Config.Debug,
            onEnter = function()
                CurrentParking = parking
            end,
            onExit = function()
                if CurrentParking and CurrentParking.id == parking.id then
                    CurrentParking = nil
                end
            end
        })

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

        -- Demander le job et la hauteur
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
        CreationData.height = input2[2]
        CreationData.points = {}

        -- Démarrer le mode création
        InCreationMode = true

        -- Créer une zone de prévisualisation
        CreatePreviewZone()

        lib.notify({
            title = 'Mode création',
            description = 'Appuyez sur E pour placer un point. Minimum 3 points. ENTER pour valider, BACKSPACE pour annuler.',
            type = 'info',
            duration = 8000
        })
    end)
end

-- Créer une zone de prévisualisation
function CreatePreviewZone()
    local previewZone = nil

    -- Thread pour gérer les contrôles
    CreateThread(function()
        while InCreationMode do
            Wait(0)

            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)

            -- Afficher les instructions
            local instructionText = '~g~Parking: ~w~' .. CreationData.name .. '\n~g~Job: ~w~' .. CreationData.job .. '\n~g~Points placés: ~w~' .. #CreationData.points
            instructionText = instructionText .. '\n~y~[E]~w~ Placer un point | ~y~[ENTER]~w~ Valider | ~r~[BACKSPACE]~w~ Annuler'

            DrawText3D(coords.x, coords.y, coords.z + 1.0, instructionText)

            -- Placer un point avec E
            if IsControlJustPressed(0, 38) then -- E
                local newPoint = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
                table.insert(CreationData.points, newPoint)

                lib.notify({
                    title = 'Point ajouté',
                    description = 'Point ' .. #CreationData.points .. ' placé',
                    type = 'success'
                })

                -- Recréer la zone de prévisualisation si on a au moins 3 points
                if #CreationData.points >= 3 then
                    if previewZone then
                        previewZone:remove()
                    end

                    local points = {}
                    for i = 1, #CreationData.points do
                        table.insert(points, vec3(CreationData.points[i].x, CreationData.points[i].y, CreationData.points[i].z))
                    end

                    previewZone = lib.zones.poly({
                        points = points,
                        thickness = CreationData.height,
                        debug = true
                    })
                end
            end

            -- Valider avec ENTER
            if IsControlJustPressed(0, 191) then -- ENTER
                if #CreationData.points < 3 then
                    lib.notify({
                        title = 'Erreur',
                        description = 'Vous devez placer au moins 3 points',
                        type = 'error'
                    })
                else
                    InCreationMode = false
                    if previewZone then
                        previewZone:remove()
                    end

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

                    CreationData = {points = {}, height = 2.0, job = nil, name = nil}
                end
            end

            -- Annuler avec BACKSPACE
            if IsControlJustPressed(0, 194) then -- BACKSPACE
                InCreationMode = false
                if previewZone then
                    previewZone:remove()
                end

                lib.notify({
                    title = 'Annulé',
                    description = 'Création du parking annulée',
                    type = 'error'
                })

                CreationData = {points = {}, height = 2.0, job = nil, name = nil}
            end

            -- Dessiner les markers pour chaque point placé
            for i = 1, #CreationData.points do
                local point = CreationData.points[i]
                DrawMarker(28, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 200, false, true, 2, false, nil, nil, false)
                DrawText3D(point.x, point.y, point.z + 0.5, '~g~Point ' .. i)
            end

            -- Dessiner une ligne entre les points
            if #CreationData.points >= 2 then
                for i = 1, #CreationData.points do
                    local point1 = CreationData.points[i]
                    local point2 = CreationData.points[i % #CreationData.points + 1]
                    DrawLine(point1.x, point1.y, point1.z, point2.x, point2.y, point2.z, 0, 255, 0, 255)
                end
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
