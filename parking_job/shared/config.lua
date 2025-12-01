Config = {}

-- Groupe admin qui peut gérer les parkings
Config.AdminGroup = 'admin'

-- Commande pour ouvrir le menu de gestion des parkings
Config.AdminCommand = 'jobparking'

-- Distance maximale pour interagir avec les véhicules
Config.InteractionDistance = 3.0

-- Système de clés (configurez selon votre script de clés)
Config.KeySystem = 'qs-vehiclekeys' -- Options: 'qs-vehiclekeys', 'qb-vehiclekeys', 'wasabi_carlock', 'none'

-- Debug mode (affiche les polyzones)
Config.Debug = false

-- Couleur du texte pour les polyzones (debug)
Config.DebugColor = {r = 255, g = 0, b = 0, a = 100}

-- Garage name prefix pour les parkings de job
Config.GaragePrefix = 'JobParking_'

-- Messages de notification
Config.Notifications = {
    noPermission = 'Vous n\'avez pas la permission',
    notInVehicle = 'Vous devez être dans un véhicule',
    notJobVehicle = 'Ce véhicule n\'appartient pas à ce job',
    vehicleStored = 'Véhicule garé avec succès',
    vehicleRetrieved = 'Véhicule récupéré avec succès',
    noVehicleNearby = 'Aucun véhicule de job à proximité',
    parkingCreated = 'Parking créé avec succès',
    parkingDeleted = 'Parking supprimé avec succès',
    parkingUpdated = 'Parking mis à jour avec succès',
    invalidData = 'Données invalides',
    alreadyExists = 'Un parking avec ce nom existe déjà',
    wrongJob = 'Vous n\'avez pas le bon métier'
}
