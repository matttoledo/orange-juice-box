-- ========================================
-- Redash Database and User
-- ========================================
-- This script runs automatically when PostgreSQL initializes
-- for the first time (only on empty data directory)

-- Create Redash database
CREATE DATABASE redash
    WITH
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.utf8'
    LC_CTYPE = 'en_US.utf8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

-- Create Redash user
-- Password from SOPS: redash_db_password
CREATE USER redash_user WITH PASSWORD 'tg08JtQk1Hq1xXf7Q/voFflVnIq4wMWb';

-- Grant all privileges on redash database to redash_user
GRANT ALL PRIVILEGES ON DATABASE redash TO redash_user;

-- Make redash_user the owner
ALTER DATABASE redash OWNER TO redash_user;

-- Grant schema permissions
\c redash
GRANT ALL ON SCHEMA public TO redash_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO redash_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO redash_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO redash_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO redash_user;

-- Log success
\echo 'Redash database and user created successfully!'
