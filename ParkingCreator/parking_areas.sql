CREATE TABLE `parking_areas` (
  `id` int(11) NOT NULL,
  `name` text NOT NULL,
  `data` longtext NOT NULL,
  `restricted` longtext NOT NULL DEFAULT '[]'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `parking_areas`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `parking_areas`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=1;
COMMIT;
