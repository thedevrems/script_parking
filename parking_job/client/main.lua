local JobParkings = {}
local ParkingZones = {}
local ParkingSpawnPoints = {} -- Points de détection pour le spawn (1000m)
CurrentParking = nil -- Variable globale accessible depuis target.lua
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

    -- Supprimer les anciens points de spawn
    for i = 1, #ParkingSpawnPoints do
        ParkingSpawnPoints[i]:remove()
    end
    ParkingSpawnPoints = {}

    -- Créer les nouvelles zones avec ox_lib
    for id, parking in pairs(JobParkings) do
        -- Convertir les points en format vec3
        local points = {}
        for i = 1, #parking.points do
            table.insert(points, vec3(parking.points[i].x, parking.points[i].y, parking.points[i].z))
        end

        -- Créer la polyzone pour le parking
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

        -- Ne créer un point de spawn que si le parking a des véhicules (optimisation : pas de points pour parkings vides)
        if parking.center and parking.vehicleCount and parking.vehicleCount > 0 then
            -- Distance adaptative selon le nombre de véhicules (optimisation : plus de véhicules = plus loin)
            local distance = parking.spawnDistance or 1000.0

            -- Créer un point de détection pour le spawn
            local spawnPoint = lib.points.new({
                coords = vec3(parking.center.x, parking.center.y, parking.center.z),
                distance = distance,
                parkingName = parking.name,
                onEnter = function(self)
                    -- Demander au serveur de spawner les véhicules de ce parking
                    TriggerServerEvent('parking_job:playerApproachingParking', self.parkingName)
                    -- Retirer le point après utilisation (on n'a besoin de spawner qu'une fois)
                    self:remove()
                end
            })

            table.insert(ParkingSpawnPoints, spawnPoint)
        end
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
            title = 'Mode création activé',
            description = 'E: Placer | SUPPR: Retirer | ↑/↓: Hauteur | ENTER: Valider | BACKSPACE: Annuler',
            type = 'info',
            duration = 10000
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

            -- Désactiver les contrôles conflictuels pendant la création (empêche interactions E)
            DisableControlAction(0, 38, true) -- E (interaction)
            DisableControlAction(0, 46, true) -- E (alternative)
            DisableControlAction(0, 47, true) -- G
            DisableControlAction(0, 74, true) -- H

            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)

            -- Afficher les contrôles (en bas)
            local controlsText = '~y~[E]~w~ Placer  ~y~[SUPPR]~w~ Retirer'
            controlsText = controlsText .. '\n~y~[UP/DOWN]~w~ Hauteur  ~g~[ENTER]~w~ Valider  ~r~[BACKSPACE]~w~ Annuler'

            DrawText3D(coords.x, coords.y, coords.z + 1.0, controlsText)

            -- Placer un point avec E (utiliser IsDisabledControlJustPressed car on a désactivé le contrôle)
            if IsDisabledControlJustPressed(0, 38) then -- E
                local newPoint = {
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                }
                table.insert(CreationData.points, newPoint)

                lib.notify({
                    title = 'Point ajouté',
                    description = 'Point ' .. #CreationData.points .. ' placé aux coordonnées ' .. string.format("%.2f, %.2f, %.2f", coords.x, coords.y, coords.z),
                    type = 'success',
                    duration = 3000
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

            -- Supprimer le dernier point avec SUPPR/DEL
            if IsControlJustPressed(0, 178) then -- SUPPR/DEL
                if #CreationData.points == 0 then
                    lib.notify({
                        title = 'Erreur',
                        description = 'Aucun point à supprimer',
                        type = 'error',
                        duration = 3000
                    })
                else
                    local removedPoint = table.remove(CreationData.points)
                    lib.notify({
                        title = 'Point supprimé',
                        description = 'Point ' .. (#CreationData.points + 1) .. ' supprimé. Il reste ' .. #CreationData.points .. ' point(s)',
                        type = 'warning',
                        duration = 3000
                    })

                    -- Recréer la zone de prévisualisation
                    if previewZone then
                        previewZone:remove()
                        previewZone = nil
                    end

                    if #CreationData.points >= 3 then
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
            end

            -- Augmenter la hauteur avec FLÈCHE HAUT
            if IsControlPressed(0, 172) then -- ARROW UP
                CreationData.height = CreationData.height + 0.1
                if CreationData.height > 10.0 then
                    CreationData.height = 10.0
                end

                -- Recréer la zone si elle existe
                if previewZone and #CreationData.points >= 3 then
                    previewZone:remove()

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
                Wait(100)
            end

            -- Diminuer la hauteur avec FLÈCHE BAS
            if IsControlPressed(0, 173) then -- ARROW DOWN
                CreationData.height = CreationData.height - 0.1
                if CreationData.height < 1.0 then
                    CreationData.height = 1.0
                end

                -- Recréer la zone si elle existe
                if previewZone and #CreationData.points >= 3 then
                    previewZone:remove()

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
                Wait(100)
            end

            -- Valider avec ENTER
            if IsControlJustPressed(0, 191) then -- ENTER
                if #CreationData.points < 3 then
                    lib.notify({
                        title = 'Erreur',
                        description = 'Vous devez placer au moins 3 points pour créer une polyzone',
                        type = 'error',
                        duration = 5000
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
                                description = Config.Notifications[message] .. ' (' .. #CreationData.points .. ' points, hauteur: ' .. CreationData.height .. 'm)',
                                type = 'success',
                                duration = 5000
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
                local confirm = lib.alertDialog({
                    header = 'Annuler la création ?',
                    content = 'Voulez-vous vraiment annuler la création de ce parking ? Tous les points seront perdus.',
                    centered = true,
                    cancel = true
                })

                if confirm == 'confirm' then
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
            end

            -- Dessiner les markers pour chaque point placé
            for i = 1, #CreationData.points do
                local point = CreationData.points[i]
                -- Marker vert pour les points normaux
                if i == #CreationData.points then
                    -- Marker jaune pour le dernier point placé
                    DrawMarker(28, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, 255, 255, 0, 200, false, true, 2, false, nil, nil, false)
                else
                    DrawMarker(28, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.3, 0.3, 0, 255, 0, 200, false, true, 2, false, nil, nil, false)
                end
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

            -- Dessiner un marker à la position actuelle du joueur pour prévisualiser où sera placé le prochain point
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.5, 0.5, 0.5, 255, 255, 255, 100, false, true, 2, false, nil, nil, false)
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

-- Les parkings sont chargés automatiquement via l'événement 'parking_job:updateParkings'
-- envoyé par le serveur au démarrage de la ressource et à la connexion du joueur
-- Les points de détection (lib.points) déclenchent automatiquement le spawn à 1000m
