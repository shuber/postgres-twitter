
-- Silently drop everything in reverse (for development)
SET client_min_messages TO WARNING;
DROP SCHEMA "public" CASCADE;
SET client_min_messages TO NOTICE;
CREATE SCHEMA "public";
CREATE EXTENSION "uuid-ossp";
-- Parse tokens like tags and mentions from text
--
-- `content` - the text to parse tokens from
-- `prefix`  - the character that tokens start with e.g. # or @
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
  $$ LANGUAGE plpgsql STABLE;

-- Returns the uuid of a random user record
CREATE FUNCTION random_user_id()
  RETURNS uuid AS $$
    DECLARE
      user_id uuid;
    BEGIN
      SELECT id FROM users ORDER BY random() LIMIT 1 INTO user_id;
      RETURN user_id;
    END;
  $$ LANGUAGE plpgsql VOLATILE;
-- ############################################################################
-- # tags
-- ############################################################################

CREATE FUNCTION delete_stale_tag()
  RETURNS trigger AS $$
    BEGIN
      DELETE FROM tags WHERE id = OLD.id;
      RETURN OLD;
    END;
  $$ LANGUAGE plpgsql;


-- ############################################################################
-- # tweets
-- ############################################################################

CREATE FUNCTION parse_mentions_from_post()
  RETURNS trigger AS $$
    BEGIN
      NEW.mentions = parse_tokens(NEW.post, '@');
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
          EXECUTE 'SELECT id FROM users WHERE username = $1'
          INTO user_id
          USING LOWER(username);

          IF user_id IS NOT NULL THEN
            INSERT INTO mentions (user_id, tweet_id)
            VALUES (user_id, NEW.id);
          END IF;
        EXCEPTION WHEN unique_violation THEN
        END;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION delete_old_mentions()
  RETURNS trigger AS $$
    DECLARE
      mention text;
    BEGIN
      FOREACH mention IN ARRAY OLD.mentions LOOP
        IF NOT NEW.mentions @> ARRAY[mention] THEN
          DELETE FROM mentions USING users
          WHERE mentions.user_id = users.id
          AND mentions.tweet_id = NEW.id
          AND users.username = mention;
        END IF;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------

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
          EXECUTE 'SELECT id FROM tags WHERE name = $1'
          INTO user_id
          USING tag;

          INSERT INTO taggings (tag_id, tweet_id)
          VALUES (user_id, NEW.id);
        EXCEPTION WHEN unique_violation THEN
        END;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION delete_old_taggings()
  RETURNS trigger AS $$
    DECLARE
      tag text;
    BEGIN
      FOREACH tag IN ARRAY OLD.tags LOOP
        IF NOT NEW.tags @> ARRAY[tag] THEN
          DELETE FROM taggings USING tags
          WHERE taggings.tag_id = tags.id
          AND taggings.tweet_id = NEW.id
          AND tags.name = tag;
        END IF;
      END LOOP;

      RETURN NEW;
    END;
  $$ LANGUAGE plpgsql;
CREATE FUNCTION counter_cache()
  RETURNS trigger AS $$
    DECLARE
      table_name text;
      column_name text;
      foreign_key_name text;
      id_name text;

      foreign_key uuid;
      increment integer;
      incrementor text;

      record record;
    BEGIN
      table_name := quote_ident(TG_ARGV[0]);
      column_name := quote_ident(TG_ARGV[1]);
      foreign_key_name := quote_ident(TG_ARGV[2]);
      id_name := quote_ident(TG_ARGV[3]);

      IF TG_OP = 'INSERT' THEN
        record := NEW;
        increment := 1;
      ELSE
        record := OLD;
        increment := -1;
      END IF;

      EXECUTE 'SELECT ($1).' || quote_ident(foreign_key_name)
      INTO foreign_key
      USING record;

      incrementor := column_name || ' = ' || column_name || ' + ' || increment;
      EXECUTE 'UPDATE ' || table_name || ' SET ' || incrementor || ' WHERE id = $1'
      USING foreign_key;

      RETURN record;
    END;
  $$ LANGUAGE plpgsql;
CREATE TABLE mentions (
  user_id   uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(user_id, tweet_id)
);

CREATE TABLE tags (
  id       uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  name     text NOT NULL UNIQUE,
  tweets   integer NOT NULL DEFAULT 0,
  created  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated  timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

CREATE TABLE taggings (
  tag_id    uuid NOT NULL,
  tweet_id  uuid NOT NULL,
  PRIMARY KEY(tag_id, tweet_id)
);

CREATE TABLE tweets (
  id        uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  user_id   uuid NOT NULL,
  post      text NOT NULL,
  mentions  text[] NOT NULL DEFAULT '{}',
  tags      text[] NOT NULL DEFAULT '{}',
  created   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);

CREATE TABLE users (
  id        uuid PRIMARY KEY NOT NULL DEFAULT uuid_generate_v4(),
  username  text NOT NULL UNIQUE,
  mentions  integer NOT NULL DEFAULT 0,
  tweets    integer NOT NULL DEFAULT 0,
  created   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp,
  updated   timestamp WITH TIME ZONE NOT NULL DEFAULT current_timestamp
);
-- ############################################################################
-- # mentions
-- ############################################################################

ALTER TABLE mentions
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE mentions
  ADD CONSTRAINT tweet_fk FOREIGN KEY (tweet_id) REFERENCES tweets (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


-- ############################################################################
-- # tags
-- ############################################################################

ALTER TABLE tags
  ADD CONSTRAINT tweets_count CHECK (tweets >= 0);


-- ############################################################################
-- # taggings
-- ############################################################################

ALTER TABLE taggings
  ADD CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES tags (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE taggings
  ADD CONSTRAINT tweet_fk FOREIGN KEY (tweet_id) REFERENCES tweets (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;


-- ############################################################################
-- # tweets
-- ############################################################################

ALTER TABLE tweets
  ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES users (id)
  MATCH FULL ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE tweets ADD
  CONSTRAINT post_length CHECK (char_length(post) <= 140);


-- ############################################################################
-- # users
-- ############################################################################

ALTER TABLE users
  ADD CONSTRAINT mentions_count CHECK (mentions >= 0);

ALTER TABLE users
  ADD CONSTRAINT tweets_count CHECK (tweets >= 0);
-- ############################################################################
-- # tags
-- ############################################################################

CREATE UNIQUE INDEX ON tags (LOWER(name));


-- ############################################################################
-- # tweets
-- ############################################################################

CREATE INDEX ON tweets (user_id);


-- ############################################################################
-- # users
-- ############################################################################

CREATE UNIQUE INDEX ON users (LOWER(username));
-- ############################################################################
-- # mentions
-- ############################################################################

CREATE TRIGGER update_user_mentions
  AFTER INSERT OR DELETE ON mentions
  FOR EACH ROW
  EXECUTE PROCEDURE counter_cache('users', 'mentions', 'user_id', 'user_id');


-- ############################################################################
-- # tags
-- ############################################################################

CREATE TRIGGER delete_stale_tags
  AFTER UPDATE ON tags
  FOR EACH ROW WHEN (NEW.tweets = 0)
  EXECUTE PROCEDURE delete_stale_tag();


-- ############################################################################
-- # taggings
-- ############################################################################

CREATE TRIGGER update_tag_tweets
  AFTER INSERT OR DELETE ON taggings
  FOR EACH ROW
  EXECUTE PROCEDURE counter_cache('tags', 'tweets', 'tag_id', 'tag_id');


-- ############################################################################
-- # tweets
-- ############################################################################

CREATE TRIGGER update_user_tweets
  AFTER INSERT OR DELETE ON tweets
  FOR EACH ROW
  EXECUTE PROCEDURE counter_cache('users', 'tweets', 'user_id', 'id');

-------------------------------------------------------------------------------

CREATE TRIGGER parse_mentions
  BEFORE INSERT OR UPDATE ON tweets
  FOR EACH ROW EXECUTE PROCEDURE parse_mentions_from_post();

CREATE TRIGGER create_mentions
  AFTER INSERT OR UPDATE ON tweets
  FOR EACH ROW
  EXECUTE PROCEDURE create_new_mentions();

CREATE TRIGGER delete_mentions
  AFTER UPDATE ON tweets
  FOR EACH ROW WHEN (NEW.mentions IS DISTINCT FROM OLD.mentions)
  EXECUTE PROCEDURE delete_old_mentions();

-------------------------------------------------------------------------------

CREATE TRIGGER parse_taggings
  BEFORE INSERT OR UPDATE ON tweets
  FOR EACH ROW
  EXECUTE PROCEDURE parse_tags_from_post();

CREATE TRIGGER create_taggings
  AFTER INSERT OR UPDATE ON tweets
  FOR EACH ROW
  EXECUTE PROCEDURE create_new_taggings();

CREATE TRIGGER delete_taggings
  AFTER UPDATE ON tweets
  FOR EACH ROW WHEN (NEW.tags IS DISTINCT FROM OLD.tags)
  EXECUTE PROCEDURE delete_old_taggings();
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

SELECT id, username, mentions, tweets FROM users;
SELECT * FROM mentions;

-------------------------------------------------------------------------------

SELECT username, post, tweets.mentions, tags
FROM tweets JOIN users on tweets.user_id = users.id;

DELETE FROM tweets
WHERE id IN (
  SELECT t.id
  FROM tweets t
  ORDER BY random()
  LIMIT 1
);

UPDATE tweets
SET post = 'replaced!'
WHERE id IN (
  SELECT t.id
  FROM tweets t
  ORDER BY random()
  LIMIT 1
);

SELECT username, post, tweets.mentions, tags
FROM tweets JOIN users on tweets.user_id = users.id;

-------------------------------------------------------------------------------

SELECT * FROM taggings;
SELECT id, name, tweets FROM tags;
