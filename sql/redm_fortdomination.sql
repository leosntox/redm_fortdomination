-- POSSE ATUAL DE CADA FORTE
-- Guarda Dominador, conquista atual, cooldown global e retirada da recompensa.
CREATE TABLE IF NOT EXISTS `fort_domination_ownership` (
    `fort_id` VARCHAR(64) NOT NULL,
    `owner_identifier` VARCHAR(64) DEFAULT NULL,
    `owner_charid` INT DEFAULT NULL,
    `owner_name` VARCHAR(100) DEFAULT NULL,
    `conquest_id` BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `conquered_at` BIGINT NOT NULL DEFAULT 0,
    `challenge_available_at` BIGINT NOT NULL DEFAULT 0,
    `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`fort_id`),
    INDEX `idx_fort_owner` (`owner_identifier`, `owner_charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- MEMBROS AUTORIZADOS PELO DOMINADOR
-- As permissões de baú e fabricação podem ser controladas separadamente.
CREATE TABLE IF NOT EXISTS `fort_domination_members` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `fort_id` VARCHAR(64) NOT NULL,
    `owner_identifier` VARCHAR(64) NOT NULL,
    `owner_charid` INT NOT NULL,
    `member_identifier` VARCHAR(64) NOT NULL,
    `member_charid` INT NOT NULL,
    `member_name` VARCHAR(100) NOT NULL DEFAULT '',
    `chest_access` TINYINT(1) NOT NULL DEFAULT 1,
    `crafting_access` TINYINT(1) NOT NULL DEFAULT 1,
    `added_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_fort_member` (`fort_id`, `member_identifier`, `member_charid`),
    INDEX `idx_fort_members_owner` (`fort_id`, `owner_identifier`, `owner_charid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
