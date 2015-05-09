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
DROP TRIGGER IF EXISTS create_mentions ON tweets;
DROP TRIGGER IF EXISTS update_tweets ON taggings;
DROP TRIGGER IF EXISTS update_mentions ON mentions;

DROP FUNCTION IF EXISTS parse_mentions_from_post();
DROP FUNCTION IF EXISTS parse_tags_from_post();
DROP FUNCTION IF EXISTS parse_tokens(text, text);
DROP FUNCTION IF EXISTS create_new_taggings();
DROP FUNCTION IF EXISTS create_new_mentions();
DROP FUNCTION IF EXISTS update_tweets_count();
DROP FUNCTION IF EXISTS update_mentions_count();
DROP FUNCTION IF EXISTS random_user_id();

DROP TABLE IF EXISTS "mentions";
DROP TABLE IF EXISTS "taggings";
DROP TABLE IF EXISTS "tags";
DROP TABLE IF EXISTS "tweets";
DROP TABLE IF EXISTS "users";

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

-- Users
CREATE TABLE users (
  id        uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  username  text NOT NULL UNIQUE,
  mentions  integer NOT NULL DEFAULT 0,
  created   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

ALTER TABLE users ADD CONSTRAINT mentions_count CHECK (mentions >= 0);


-- Tweets
CREATE TABLE tweets (
  id        uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  user_id   uuid NOT NULL,
  post      text NOT NULL,
  mentions  text[] NOT NULL DEFAULT '{}',
  tags      text[] NOT NULL DEFAULT '{}',
  created   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

ALTER TABLE tweets
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

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


-- Mentions
CREATE TABLE mentions (
  user_id   uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(user_id, tweet_id)
);

ALTER TABLE mentions
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE mentions
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
      user_id uuid;
    BEGIN
      FOREACH tag IN ARRAY NEW.tags LOOP
        BEGIN
          tag := LOWER(tag);
          INSERT INTO tags (name) VALUES (tag);
        EXCEPTION WHEN unique_violation THEN
        END;

        BEGIN
          EXECUTE 'SELECT id FROM tags WHERE name = $1' INTO user_id USING tag;
          INSERT INTO taggings (tag_id, tweet_id) VALUES (user_id, NEW.id);
        EXCEPTION WHEN unique_violation THEN
        END;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION update_tweets_count()
  RETURNS trigger AS $$
    DECLARE
      increment integer;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        increment := 1;
      ELSE
        increment := -1;
      END IF;

      UPDATE tags SET tweets = tweets + increment WHERE id = NEW.tag_id;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION update_mentions_count()
  RETURNS trigger AS $$
    DECLARE
      increment integer;
    BEGIN
      IF TG_OP = 'INSERT' THEN
        increment := 1;
      ELSE
        increment := -1;
      END IF;

      UPDATE users SET mentions = mentions + increment WHERE id = NEW.user_id;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION create_new_mentions()
  RETURNS trigger AS $$
    DECLARE
      username text;
      user_id uuid;
    BEGIN
      FOREACH username IN ARRAY NEW.mentions LOOP
        BEGIN
          EXECUTE 'SELECT id FROM users WHERE username = $1' INTO user_id USING LOWER(username);

          IF user_id IS NOT NULL THEN
            INSERT INTO mentions (user_id, tweet_id) VALUES (user_id, NEW.id);
          END IF;
        EXCEPTION WHEN unique_violation THEN
        END;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION random_user_id()
  RETURNS uuid AS $$
    DECLARE
      user_id uuid;
    BEGIN
      SELECT id FROM users ORDER BY random() LIMIT 1 INTO user_id;
      RETURN user_id;
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

CREATE TRIGGER create_mentions
  AFTER INSERT OR UPDATE ON tweets
  FOR EACH ROW EXECUTE PROCEDURE create_new_mentions();

CREATE TRIGGER update_tweets
  AFTER INSERT OR DELETE ON taggings
  FOR EACH ROW EXECUTE PROCEDURE update_tweets_count();

CREATE TRIGGER update_mentions
  AFTER INSERT OR DELETE ON mentions
  FOR EACH ROW EXECUTE PROCEDURE update_mentions_count();


-- ############################################################################
-- # Seed data
-- ############################################################################
INSERT INTO users (username) VALUES
  ('bob'),
  ('doug'),
  ('jane'),
  ('steve'),
  ('tom');

INSERT INTO tweets (post, user_id) VALUES
  ('My first tweet!', random_user_id()),
  ('Another tweet with a tag! #hello-world @missing', random_user_id()),
  ('My second tweet! #hello-world #hello-world-again', random_user_id()),
  ('Is anyone else hungry? #imHUNGRY #gimmefood @TOM @jane', random_user_id()),
  ('@steve hola!', random_user_id()),
  ('@bob I am! #imhungry #metoo #gimmefood #now', random_user_id());


-- ############################################################################
-- # Debug output
-- ############################################################################
SELECT id, username, mentions FROM users;
SELECT * FROM mentions;
SELECT username, post, tweets.mentions, tags FROM tweets JOIN users on tweets.user_id = users.id;
SELECT * FROM taggings;
SELECT name, tweets FROM tags;
