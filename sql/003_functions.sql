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

-------------------------------------------------------------------------------

-- Returns the uuid of a random tweet record
CREATE FUNCTION random_tweet_id()
  RETURNS uuid AS $$
    DECLARE
      tweet_id uuid;
    BEGIN
      SELECT id FROM tweets ORDER BY random() LIMIT 1 INTO tweet_id;
      RETURN tweet_id;
    END;
  $$ LANGUAGE plpgsql VOLATILE;

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
