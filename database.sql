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
DROP TRIGGER IF EXISTS parse_mentions ON tweets;
DROP TRIGGER IF EXISTS parse_tags ON tweets;
DROP TRIGGER IF EXISTS create_taggings ON tweets;

DROP FUNCTION IF EXISTS parse_mentions_from_post();
DROP FUNCTION IF EXISTS parse_tags_from_post();
DROP FUNCTION IF EXISTS parse_tokens(text, text);
DROP FUNCTION IF EXISTS create_new_taggings();

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
  mentions  text[] NOT NULL DEFAULT '{}',
  tags      text[] NOT NULL DEFAULT '{}',
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
CREATE FUNCTION parse_tokens(content text, prefix text)
  RETURNS text[] AS $$
    DECLARE
      regex text;
      matches text;
      subquery text;
      captures text;
      tokens text[];
    BEGIN
      regex := prefix || '(\S+)';
      matches := 'regexp_matches($1, $2, $3) as captures';
      subquery := '(SELECT ' || matches || ' ORDER BY captures) as matches';
      captures := 'array_agg(matches.captures[1])';

      EXECUTE 'SELECT ' || captures || ' FROM ' || subquery
      INTO tokens
      USING LOWER(content), regex, 'g';

      IF tokens IS NULL THEN
        tokens = '{}';
      END IF;

      RETURN tokens;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION parse_mentions_from_post()
  RETURNS trigger AS $$
    BEGIN
      NEW.mentions = parse_tokens(NEW.post, '@');
      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION parse_tags_from_post()
  RETURNS trigger AS $$
    BEGIN
      NEW.tags = parse_tokens(NEW.post, '#');
      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION create_new_taggings()
  RETURNS trigger AS $$
    DECLARE
      tag text;
      id uuid;
    BEGIN
      FOREACH tag IN ARRAY NEW.tags LOOP
        BEGIN
          tag := LOWER(tag);
          INSERT INTO tags (name) VALUES (tag);
        EXCEPTION WHEN unique_violation THEN
        END;

        BEGIN
          EXECUTE 'SELECT id FROM tags WHERE name = $1' INTO id USING tag;
          INSERT INTO taggings (tag_id, tweet_id) VALUES (id, NEW.id);
        EXCEPTION WHEN unique_violation THEN
        END;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;


-- ############################################################################
-- # Triggers
-- ############################################################################
CREATE TRIGGER parse_mentions
  BEFORE INSERT OR UPDATE ON tweets
  FOR EACH ROW EXECUTE PROCEDURE parse_mentions_from_post();

CREATE TRIGGER parse_tags
  BEFORE INSERT OR UPDATE ON tweets
  FOR EACH ROW EXECUTE PROCEDURE parse_tags_from_post();

CREATE TRIGGER create_taggings
  AFTER INSERT OR UPDATE ON tweets
  FOR EACH ROW EXECUTE PROCEDURE create_new_taggings();


-- ############################################################################
-- # Seed data
-- ############################################################################
INSERT INTO tweets (post) VALUES
  ('My first tweet!'),
  ('Another tweet with a tag! #hello-world'),
  ('My second tweet! #hello-world #hello-world-again'),
  ('Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane'),
  ('@steve hola!'),
  ('@bob I am! #imhungry #metoo #gimmefood #now');


-- ############################################################################
-- # Debug output
-- ############################################################################
SELECT post, mentions, tags FROM tweets;
SELECT * FROM taggings;
SELECT name, tweets FROM tags;
