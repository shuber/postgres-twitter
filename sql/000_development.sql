-- Silently drop everything in reverse (for development)
SET client_min_messages TO WARNING;
DROP SCHEMA "public" CASCADE;
DROP SCHEMA "random" CASCADE;
DROP SCHEMA "views" CASCADE;
SET client_min_messages TO NOTICE;
