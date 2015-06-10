CREATE FUNCTION increment_counter(table_name text, column_name text, pk_name text, pk_value uuid, step integer)
  RETURNS VOID AS $$
    DECLARE
      table_name text := quote_ident(table_name);
      column_name text := quote_ident(column_name);
      conditions text := ' WHERE ' || quote_ident(pk_name) || ' = $1';
      updates text := column_name || '=' || column_name || '+' || step;
    BEGIN
      EXECUTE 'UPDATE ' || table_name || ' SET ' || updates || conditions
      USING pk_value;
    END;
  $$ LANGUAGE plpgsql;

CREATE FUNCTION counter_cache()
  RETURNS trigger AS $$
    DECLARE
      table_name text := quote_ident(TG_ARGV[0]);
      counter_name text := quote_ident(TG_ARGV[1]);
      fk_name text := quote_ident(TG_ARGV[2]);
      pk_name text := quote_ident(TG_ARGV[3]);
      fk_changed boolean := false;
      fk_value uuid;
      record record;
    BEGIN
      IF TG_OP = 'UPDATE' THEN
        record := NEW;
        EXECUTE 'SELECT ($1).' || fk_name || ' != ' || '($2).' || fk_name
        INTO fk_changed
        USING OLD, NEW;
      END IF;

      IF TG_OP = 'DELETE' OR fk_changed THEN
        record := OLD;
        EXECUTE 'SELECT ($1).' || fk_name INTO fk_value USING record;
        PERFORM increment_counter(table_name, counter_name, pk_name, fk_value, -1);
      END IF;

      IF TG_OP = 'INSERT' OR fk_changed THEN
        record := NEW;
        EXECUTE 'SELECT ($1).' || fk_name INTO fk_value USING record;
        PERFORM increment_counter(table_name, counter_name, pk_name, fk_value, 1);
      END IF;

      RETURN record;
    END;
  $$ LANGUAGE plpgsql;
