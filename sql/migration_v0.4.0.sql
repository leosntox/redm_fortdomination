-- Atualização para a versão 0.4.0.
-- O recurso também executa esta alteração automaticamente ao iniciar.
ALTER TABLE `fort_domination_members`
    ADD COLUMN IF NOT EXISTS `member_name` VARCHAR(100) NOT NULL DEFAULT ''
    AFTER `member_charid`;
