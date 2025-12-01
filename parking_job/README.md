# Job Parking System

Script de parking pour jobs compatible avec **qs-advancedgarages**, **ESX** et **ox_lib**.

## Fonctionnalités

- ✅ Création de parkings de job par les admins
- ✅ Polyzones avec prévisualisation et debug
- ✅ Stockage des véhicules de job avec ox_target
- ✅ Récupération des véhicules par job
- ✅ Gestion automatique des clés (qs-vehiclekeys, qb-vehiclekeys, wasabi_carlock)
- ✅ Intégration complète avec qs-advancedgarages
- ✅ Spawn automatique des véhicules au démarrage
- ✅ Sécurité : vérification du job pour garer/récupérer

## Installation

### 1. Base de données

Exécutez le fichier SQL dans votre base de données :

```sql
resources/parking_job/sql/parking.sql
```

### 2. Configuration

Éditez le fichier `shared/config.lua` selon vos besoins :

```lua
Config.AdminGroup = 'admin' -- Groupe admin
Config.KeySystem = 'qs-vehiclekeys' -- Système de clés
Config.Debug = false -- Mode debug (affiche les polyzones)
```

### 3. Dépendances

Assurez-vous d'avoir installé :
- es_extended
- ox_lib
- oxmysql
- ox_target
- qs-advancedgarages
- PolyZone

### 4. Server.cfg

Ajoutez dans votre `server.cfg` :

```cfg
ensure parking_job
```

## Utilisation

### Pour les admins

1. **Créer un parking** :
   - Tapez `/jobparking` dans le chat
   - Cliquez sur "Créer un nouveau parking"
   - Entrez le nom du parking
   - Sélectionnez le job
   - Définissez la taille de la zone (largeur, longueur, hauteur)
   - Utilisez les flèches directionnelles pour ajuster la position
   - Appuyez sur **ENTER** pour valider ou **BACKSPACE** pour annuler

2. **Supprimer un parking** :
   - Tapez `/jobparking`
   - Sélectionnez le parking à supprimer
   - Cliquez sur "Supprimer ce parking"

### Pour les joueurs

1. **Garer un véhicule de job** :
   - Conduisez le véhicule dans la polyzone du parking
   - Utilisez **ox_target** sur le véhicule (oeil)
   - Cliquez sur "Garer le véhicule"
   - Le véhicule sera supprimé et stocké en base de données

2. **Récupérer un véhicule** :
   - Entrez dans la polyzone du parking
   - Utilisez **ox_target** sur la zone (oeil)
   - Cliquez sur "Récupérer un véhicule"
   - Sélectionnez le véhicule à récupérer

## Sécurité

Le script vérifie automatiquement :
- ✅ Le joueur a le bon job
- ✅ Le véhicule appartient au job du parking
- ✅ Le véhicule est bien un véhicule de job
- ✅ Les permissions admin pour créer/supprimer des parkings

## Intégration avec qs-advancedgarages

Le script utilise les exports de qs-advancedgarages :
- `SpawnVehicle` : pour spawn les véhicules au démarrage
- `setVehicleToPersistent` : pour rendre les véhicules persistants
- `removeVehicleFromPersistent` : pour retirer les véhicules du système de persistence

## Base de données

### Table `job_parkings`
Stocke les parkings créés par les admins.

### Table `owned_vehicles`
Utilise les colonnes existantes :
- `jobVehicle` : le job du véhicule
- `jobGarage` : le nom du parking où le véhicule est garé
- `garage` : préfixé avec `JobParking_` pour les parkings de job
- `stored` : 1 si le véhicule est garé, 0 sinon

## Support

Pour toute question ou problème, contactez le développeur.

## License

MIT License
