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
