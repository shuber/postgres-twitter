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

CREATE FUNCTION delete_stale_tag()
  RETURNS trigger AS $$
    BEGIN
      DELETE FROM tags WHERE id = OLD.id;
      RETURN OLD;
    END;
  $$ LANGUAGE plpgsql;
