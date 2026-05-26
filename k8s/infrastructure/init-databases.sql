-- Script de inicialização do PostgreSQL — base para gerar o SealedSecret postgres-init-secret.
-- Substitua os placeholders __*_PASSWORD__ pelas senhas reais antes de criar o Secret.

CREATE ROLE users_app WITH LOGIN PASSWORD '__USERS_APP_PASSWORD__';
CREATE ROLE catalog_app WITH LOGIN PASSWORD '__CATALOG_APP_PASSWORD__';
CREATE ROLE payments_app WITH LOGIN PASSWORD '__PAYMENTS_APP_PASSWORD__';

CREATE DATABASE postech_users OWNER users_app;
CREATE DATABASE postech_catalog OWNER catalog_app;
CREATE DATABASE postech_payments OWNER payments_app;

REVOKE ALL ON DATABASE postech_users FROM PUBLIC;
REVOKE ALL ON DATABASE postech_catalog FROM PUBLIC;
REVOKE ALL ON DATABASE postech_payments FROM PUBLIC;

GRANT ALL PRIVILEGES ON DATABASE postech_users TO users_app;
GRANT ALL PRIVILEGES ON DATABASE postech_catalog TO catalog_app;
GRANT ALL PRIVILEGES ON DATABASE postech_payments TO payments_app;
