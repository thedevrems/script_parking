-- Table pour stocker les parkings de job
CREATE TABLE IF NOT EXISTS `job_parkings` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `job` varchar(50) NOT NULL,
  `points` longtext NOT NULL,
  `height` float NOT NULL DEFAULT 2.0,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`) USING BTREE,
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

-- Ajouter une colonne pour stocker les coordonnées de parking des véhicules
ALTER TABLE `owned_vehicles` ADD COLUMN IF NOT EXISTS `parking_coords` longtext DEFAULT NULL;

