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

CREATE FUNCTION random.id(table_name text)
  RETURNS uuid AS $$
    DECLARE
      record record;
    BEGIN
      record := random.record(table_name);
      RETURN record.id;
    END;
  $$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION random.id(table_name text, exclude uuid)
  RETURNS uuid AS $$
    DECLARE
      record record;
    BEGIN
      record := random.record(table_name, exclude);
      RETURN record.id;
    END;
  $$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION random.record(table_name text)
  RETURNS record AS $$
    DECLARE
      exclude uuid := uuid_generate_v4();
    BEGIN
      RETURN random.record(table_name, exclude);
    END;
  $$ LANGUAGE plpgsql VOLATILE;

CREATE FUNCTION random.record(table_name text, exclude uuid)
  RETURNS record AS $$
    DECLARE
      record record;
    BEGIN
      EXECUTE 'SELECT * FROM ' || table_name || ' WHERE id != $1 ORDER BY random() LIMIT 1'
      INTO record
      USING exclude;

      RETURN record;
    END;
  $$ LANGUAGE plpgsql VOLATILE;
