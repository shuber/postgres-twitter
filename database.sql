-- ############################################################################
-- # Notes and ideas
-- ############################################################################

-- Consider dropping tags.id and making tags.name the primary key.
-- Then taggings.tag_id can be replaced with taggings.name.

-- Make tables "private". Create views for application to interact with.
-- This should make "migrations" easier as well since applications don't
-- interact with the tables directly.

-- Use default schemas for different parts of the application since they
-- can be replicated with different rules. Maybe there can even be some
-- kind of "cache" schema.


-- ############################################################################
-- # Drop everything in reverse (for development)                        DANGER
-- ############################################################################
DROP TRIGGER IF EXISTS parse_hashtags ON tweets;
DROP FUNCTION IF EXISTS parse_hashtags_from_post();
DROP TABLE IF EXISTS "taggings";
DROP TABLE IF EXISTS "tags";
DROP TABLE IF EXISTS "tweets";
DROP EXTENSION IF EXISTS "uuid-ossp";
DROP SCHEMA IF EXISTS "public";


-- ############################################################################
-- # Schemas
-- ############################################################################
CREATE SCHEMA "public";


-- ############################################################################
-- # Extensions
-- ############################################################################
CREATE EXTENSION "uuid-ossp";


-- ############################################################################
-- # Tables
-- ############################################################################

-- Tweets
CREATE TABLE tweets (
  id        uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  post      text NOT NULL,
  hashtags  text[] NOT NULL DEFAULT '{}',
  created   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

ALTER TABLE tweets ADD CONSTRAINT post_length CHECK (char_length(post) <= 140);



-- Tags
CREATE TABLE tags (
  id       uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  name     text NOT NULL UNIQUE,
  tweets   integer NOT NULL DEFAULT 0,
  created  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

ALTER TABLE tags ADD CONSTRAINT tweets_count CHECK (tweets >= 0);


-- Taggings
CREATE TABLE taggings (
  tag_id    uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(tag_id, tweet_id)
);

ALTER TABLE taggings
  ADD CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES tags (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE taggings
  ADD CONSTRAINT tweet_fk FOREIGN KEY (tweet_id) REFERENCES tweets (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


-- ############################################################################
-- # Functions
-- ############################################################################
CREATE FUNCTION parse_hashtags_from_post()
  RETURNS trigger AS $$
    BEGIN
      -- Parse tweets.post with something like the following regex below and
      -- update tweets.hashtag.
      --
      --   regexp_matches(NEW.post, '#(\S+)', 'g');

      RETURN NULL;
    END;
  $$ LANGUAGE plpgsql;


-- ############################################################################
-- # Triggers
-- ############################################################################
CREATE TRIGGER parse_hashtags
  AFTER INSERT ON tweets
  FOR EACH ROW EXECUTE PROCEDURE parse_hashtags_from_post();


-- ############################################################################
-- # Seed data
-- ############################################################################
INSERT INTO tweets (post) VALUES
  ('My first tweet! #hello-world'),
  ('My second tweet! #hello-world #hello-world-again'),
  ('Is anyone else hungry? #imHUNGRY #gimmefood'),
  ('I am! #imhungry #metoo #gimmefood #now');


-- ############################################################################
-- # Debug output
-- ############################################################################
SELECT * FROM tweets;
SELECT * FROM taggings;
SELECT * FROM tags;
