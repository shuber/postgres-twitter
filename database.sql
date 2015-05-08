-- Notes/ideas
--
-- * Consider dropping tags.id and making tags.name the primary key.
--   Then taggings.tag_id can be replaced with taggings.name.
-- * Make tables "private". Create views for application to interact with.
--   This should make "migrations" easier as well since applications don't
--   interact with the tables directly.
-- * Use default schemas for different parts of the application since they
--   can be replicated with different rules. Maybe there can even be some
--   kind of "cache" schema.


-- Drop everything (in reverse)
DROP TABLE IF EXISTS "taggings";
DROP TABLE IF EXISTS "tags";
DROP TABLE IF EXISTS "tweets";
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP SCHEMA IF EXISTS "public";


-- Schemas
CREATE SCHEMA IF NOT EXISTS "public";


-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- Tweets
CREATE TABLE IF NOT EXISTS tweets (
  id       uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  post     varchar(140) NOT NULL,
  created  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);


-- Tags
CREATE TABLE IF NOT EXISTS tags (
  id       uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  name     varchar(140) NOT NULL UNIQUE,
  tweets   integer NOT NULL DEFAULT 0 CHECK (tweets >= 0),
  created  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

CREATE UNIQUE INDEX ON tags (lower(name));


-- Taggings
CREATE TABLE IF NOT EXISTS taggings (
  tag_id    uuid NOT NULL REFERENCES tags (id) ON UPDATE CASCADE ON DELETE CASCADE,
  tweet_id  uuid NOT NULL REFERENCES tweets (id) ON UPDATE CASCADE ON DELETE CASCADE,
  PRIMARY KEY(tag_id, tweet_id)
);


-- Seed data
INSERT INTO tweets (post) VALUES
  ('My first tweet! #hello-world'),
  ('My second tweet! #hello-world #hello-world-again'),
  ('Is anyone else hungry? #imHUNGRY #gimmefood'),
  ('I am! #imhungry #metoo #gimmefood #now');


-- Debug output
SELECT * FROM tweets;
SELECT * FROM taggings;
SELECT * FROM tags;
