-- Execute este arquivo uma vez se você instalou a versão 0.1.5.
-- As duas tabelas abaixo deixaram de ser usadas pelo recurso.
DROP TABLE IF EXISTS `fort_domination_cooldowns`;
DROP TABLE IF EXISTS `fort_domination_rewards`;

-- MariaDB 10.4: adiciona o controle da recompensa à posse atual.
ALTER TABLE `fort_domination_ownership`
    ADD COLUMN IF NOT EXISTS `reward_claimed` TINYINT(1) NOT NULL DEFAULT 0
    AFTER `challenge_available_at`;

ALTER TABLE `fort_domination_ownership`
    ADD COLUMN IF NOT EXISTS `owner_name` VARCHAR(100) DEFAULT NULL
    AFTER `owner_charid`;

-- Versão 0.4.0: nome exibido no menu de membros.
ALTER TABLE `fort_domination_members`
    ADD COLUMN IF NOT EXISTS `member_name` VARCHAR(100) NOT NULL DEFAULT ''
    AFTER `member_charid`;
