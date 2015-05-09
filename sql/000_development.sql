-- Silently drop everything in reverse (for development)
SET client_min_messages TO WARNING;
DROP SCHEMA "public" CASCADE;
SET client_min_messages TO NOTICE;
