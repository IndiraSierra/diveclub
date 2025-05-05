DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'indira_sierra') THEN
    CREATE ROLE indira_sierra WITH SUPERUSER LOGIN PASSWORD 'tu_contraseña_indira';
  END IF;
END
$$;

GRANT ALL PRIVILEGES ON DATABASE dive_app TO indira_sierra;
CREATE EXTENSION IF NOT EXISTS postgis;