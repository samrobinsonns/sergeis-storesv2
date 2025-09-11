CREATE TABLE IF NOT EXISTS `sergeis_stores` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(100) NOT NULL,
  `owner_cid` VARCHAR(50) NOT NULL,
  `account_balance` INT NOT NULL DEFAULT 0,
  `points` LONGTEXT NULL,
  `location_code` VARCHAR(100) NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sergeis_store_employees` (
  `store_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `permission` TINYINT NOT NULL DEFAULT 1,
  PRIMARY KEY (`store_id`, `citizenid`),
  CONSTRAINT `fk_store_emp_store` FOREIGN KEY (`store_id`) REFERENCES `sergeis_stores` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sergeis_store_items` (
  `store_id` INT NOT NULL,
  `item` VARCHAR(50) NOT NULL,
  `label` VARCHAR(100) NOT NULL,
  `price` INT NOT NULL DEFAULT 0,
  `stock` INT NOT NULL DEFAULT 0,
  PRIMARY KEY (`store_id`, `item`),
  CONSTRAINT `fk_store_items_store` FOREIGN KEY (`store_id`) REFERENCES `sergeis_stores` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sergeis_store_transactions` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `store_id` INT NOT NULL,
  `citizenid` VARCHAR(50) NOT NULL,
  `amount` INT NOT NULL,
  `payload` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_store_id` (`store_id`),
  CONSTRAINT `fk_store_tx_store` FOREIGN KEY (`store_id`) REFERENCES `sergeis_stores` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `sergeis_store_vehicles` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `store_id` INT NOT NULL,
  `model` VARCHAR(50) NOT NULL,
  `plate` VARCHAR(20) NOT NULL,
  `stored` TINYINT NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  KEY `idx_store_id` (`store_id`),
  CONSTRAINT `fk_store_veh_store` FOREIGN KEY (`store_id`) REFERENCES `sergeis_stores` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Add capacity override column for store upgrades
ALTER TABLE `sergeis_stores` 
  ADD COLUMN IF NOT EXISTS `capacity` INT NULL AFTER `location_code`;


