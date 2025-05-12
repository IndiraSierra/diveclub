--
-- PostgreSQL database dump
--

-- Dumped from database version 16.8 (Ubuntu 16.8-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.8 (Ubuntu 16.8-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pg_cron; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION pg_cron; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_cron IS 'Job scheduler for PostgreSQL';


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: topology; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA topology;


--
-- Name: SCHEMA topology; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA topology IS 'PostGIS Topology schema';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: auto_set_geo_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.auto_set_geo_location() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.geo_location IS NULL AND NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.geo_location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: generate_dive_code(integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_dive_code(site_id integer, dive_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    site_code TEXT;
BEGIN
    SELECT code INTO site_code FROM dive_sites WHERE id = site_id;

    IF site_code IS NULL THEN
        RAISE EXCEPTION 'No dive site code found for site ID %', site_id;
    END IF;

    RETURN site_code || '-' || TO_CHAR(dive_date, 'YYMMDD');
END;
$$;


--
-- Name: generate_review_code(integer, integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_review_code(user_id integer, dive_id integer, review_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'REW-' || user_id || '-' || dive_id || '-' || TO_CHAR(review_date, 'YYYYMMDD');
END;
$$;


--
-- Name: generate_site_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_site_code(region_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    region_code TEXT;
    next_num INT;
BEGIN
    -- Obtener código de región (3 primeras letras, sin espacios, solo letras)
    region_code := UPPER(SUBSTRING(REGEXP_REPLACE(region_name, '[^a-zA-Z]', '', 'g') FROM 1 FOR 3));
    
    -- Completar con 'X' si es más corto
    IF LENGTH(region_code) < 3 THEN
        region_code := RPAD(region_code, 3, 'X');
    END IF;

    -- Obtener siguiente número disponible para esa región
    SELECT COALESCE(MAX(SUBSTRING(code FROM 8 FOR 3)::INT), 0) + 1 INTO next_num
    FROM dive_sites
    WHERE code LIKE 'ST-' || region_code || '-%';

    RETURN 'ST-' || region_code || '-' || LPAD(next_num::TEXT, 3, '0');
END;
$$;


--
-- Name: generate_user_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_user_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    tipo_text TEXT;
BEGIN
    -- Obtener tipo (Diver o Instructor)
    SELECT 
        CASE value_name
            WHEN 'Diver' THEN 'DIV'
            WHEN 'Instructor' THEN 'INS'
            ELSE 'UNK' -- fallback por si acaso
        END
    INTO tipo_text
    FROM event_categories
    WHERE id = NEW.diver_type;

    -- Asignar código
    NEW.code := 'USR-' || tipo_text || '-' || NEW.id;
    RETURN NEW;
END;
$$;


--
-- Name: generate_waitlist_code(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_waitlist_code(user_id integer, dive_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    dive_date DATE;
BEGIN
    -- Obtener la fecha de la inmersión
    SELECT date INTO dive_date
    FROM dives
    WHERE id = dive_id;

    IF dive_date IS NULL THEN
        RAISE EXCEPTION 'No dive date found for dive_id %', dive_id;
    END IF;

    -- Construir el código
    RETURN 'WTL-' || user_id || '-' || dive_id || '-' || TO_CHAR(dive_date, 'YYYYMMDD');
END;
$$;


--
-- Name: log_new_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_new_table() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
    active_status_id INT;
BEGIN
    -- Obtener el ID del estado 'Active'
    SELECT id INTO active_status_id FROM status_events WHERE status = 'Active';

    -- Iterar sobre los comandos DDL ejecutados
    FOR obj IN
        SELECT * FROM pg_event_trigger_ddl_commands()
        WHERE command_tag = 'CREATE TABLE'
          AND schema_name = 'public'
          AND object_type = 'table'
          AND NOT object_identity LIKE 'pg_%'
          AND NOT object_identity LIKE 'pg_temp_%'
    LOOP
        INSERT INTO master_tables_list (
            schema_name, table_name, created_at, last_updated, status_id, is_active
        )
        VALUES (
            obj.schema_name,
            obj.object_name,
            now(),
            now(),
            active_status_id,
            true
        )
        ON CONFLICT (schema_name, table_name) DO NOTHING;
    END LOOP;
END;
$$;


--
-- Name: log_table_creation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_table_creation() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
    tbl_exists BOOLEAN;
    has_commands BOOLEAN;
BEGIN
    -- Verificar si la tabla master_tables_list existe
    SELECT EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_name = 'master_tables_list'
    ) INTO tbl_exists;

    -- Verificar si hay comandos DDL relevantes
    SELECT EXISTS (
        SELECT 1 FROM pg_event_trigger_ddl_commands()
        WHERE command_tag = 'CREATE TABLE'
          AND schema_name = 'public'
    ) INTO has_commands;

    -- Solo insertar si la tabla existe y hay comandos relevantes
    IF tbl_exists AND has_commands THEN
        FOR obj IN
            SELECT * FROM pg_event_trigger_ddl_commands()
            WHERE command_tag = 'CREATE TABLE'
              AND schema_name = 'public'
        LOOP
            INSERT INTO master_tables_list (table_name, schema_name, created_at)
            VALUES (obj.object_identity, obj.schema_name, NOW());
        END LOOP;
    END IF;
END;
$$;


--
-- Name: log_table_deletion(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_table_deletion() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
BEGIN
    FOR obj IN
        SELECT *
        FROM pg_event_trigger_ddl_commands()
        WHERE command_tag = 'DROP TABLE'
    LOOP
        DELETE FROM master_tables_list
        WHERE table_name = obj.object_identity
          AND schema_name = obj.schema_name;
    END LOOP;
END;
$$;


--
-- Name: mark_table_as_deleted(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_table_as_deleted() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
    deleted_status_id INT;
BEGIN
    -- Obtener el ID del estado 'Deleted'
    SELECT id INTO deleted_status_id FROM status_events WHERE status = 'Deleted';

    -- Iterar sobre los objetos eliminados
    FOR obj IN
        SELECT * FROM pg_event_trigger_dropped_objects()
        WHERE object_type = 'table'
          AND schema_name = 'public'
          AND object_identity NOT LIKE 'pg_%'
          AND object_identity NOT LIKE 'pg_temp_%'
    LOOP
        UPDATE master_tables_list
        SET
            status_id = deleted_status_id,
            status_changed_at = now(),
            is_active = false,
            deletion_reason = 'Table dropped'
        WHERE schema_name = obj.schema_name
          AND table_name = obj.object_name;
    END LOOP;
END;
$$;


--
-- Name: normalize_user_levels_by_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_user_levels_by_type() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    diver_type_value TEXT;
BEGIN
    SELECT value_name INTO diver_type_value
    FROM event_categories
    WHERE id = NEW.diver_type;

    IF diver_type_value = 'Instructor' THEN
        -- Si es instructor, forzar diving_level a 0 (dummy) si está mal seteado
        IF NEW.diving_level IS DISTINCT FROM 0 THEN
            NEW.diving_level := 0;
        END IF;

    ELSIF diver_type_value = 'Diver' THEN
        -- Si es diver, forzar instructor_level a NULL
        IF NEW.instructor_level IS NOT NULL THEN
            NEW.instructor_level := NULL;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: promote_waitlisted_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.promote_waitlisted_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    promoted_user_id INT;
    next_code TEXT;
    max_code_suffix INT;
BEGIN
    -- Obtener el primer usuario en lista de espera por orden de listed_date
    SELECT user_id
    INTO promoted_user_id
    FROM waitlist
    WHERE dive_id = OLD.dive_id AND status_id = (SELECT id FROM status_events WHERE status = 'Active')
    ORDER BY listed_date ASC
    LIMIT 1;

    -- Si no hay nadie, salimos
    IF promoted_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Generar nuevo código para dive_registrations
    SELECT COALESCE(MAX(SUBSTRING(code FROM '.+-(\d+)$')::INT), 0) + 1
    INTO max_code_suffix
    FROM dive_registrations
    WHERE dive_id = OLD.dive_id;

    next_code := 'DR-' || promoted_user_id || '-' || OLD.dive_id || '-' || LPAD(max_code_suffix::TEXT, 2, '0');

    -- Insertar nuevo registro en dive_registrations
    INSERT INTO dive_registrations (user_id, dive_id, registration_date, attendants, waitlist, code)
    VALUES (promoted_user_id, OLD.dive_id, now(), 1, 0, next_code);

    -- Eliminar de la lista de espera
    DELETE FROM waitlist
    WHERE dive_id = OLD.dive_id AND user_id = promoted_user_id;

    -- Actualizar contador de lista de espera
    UPDATE dive_registrations
    SET waitlist = (
        SELECT COUNT(*) 
        FROM waitlist 
        WHERE dive_id = OLD.dive_id 
          AND status_id = (SELECT id FROM status_events WHERE status = 'Active')
    )
    WHERE dive_id = OLD.dive_id;

    RETURN NULL;
END;
$_$;


--
-- Name: set_defaults_on_insert_master_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_defaults_on_insert_master_table() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.status_changed_at IS NULL THEN
        NEW.status_changed_at := now();
    END IF;

    IF NEW.deletion_reason IS NULL THEN
        NEW.deletion_reason := 'Table created';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: set_defaults_on_update_master_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_defaults_on_update_master_table() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Actualiza la fecha de cambio de estado si el estado cambia
    IF NEW.status_id IS DISTINCT FROM OLD.status_id THEN
        NEW.status_changed_at := now();
    END IF;

    -- Si se marca como inactiva y no se ha especificado motivo, se asigna un valor por defecto
    IF NEW.is_active = false AND OLD.is_active = true AND NEW.deletion_reason IS NULL THEN
        NEW.deletion_reason := 'Marked inactive manually';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: set_dive_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_dive_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.code IS NULL OR TRIM(NEW.code) = '' THEN
        NEW.code := generate_dive_code(NEW.id_site, NEW.dive_date);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: set_review_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_review_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Solo generar si no se proporcionó manualmente
    IF NEW.code IS NULL OR NEW.code = '' THEN
        NEW.code := generate_review_code(NEW.user_id, NEW.dive_id, NEW.review_date);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: set_site_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_site_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.code IS NULL OR TRIM(NEW.code) = '' THEN
        NEW.code := generate_site_code(NEW.region);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: set_waitlist_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_waitlist_code() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.code IS NULL THEN
        NEW.code := generate_waitlist_code(NEW.user_id, NEW.dive_id);
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: trg_check_event_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_check_event_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM update_all_event_statuses();
    RETURN NEW;
END;
$$;


--
-- Name: trg_enforce_exclusive_levels(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_enforce_exclusive_levels() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.diving_level IS NOT NULL AND NEW.instructor_level IS NOT NULL THEN
    RAISE EXCEPTION 'User cannot have both a diving level and an instructor level at the same time.';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: update_all_event_statuses(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_all_event_statuses() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Llamar a función de actualización de inmersiones
    PERFORM update_dive_status();

    -- Llamar a función de actualización de cursos
    PERFORM update_course_status();
END;
$$;


--
-- Name: update_course_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_course_status() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    course_rec RECORD;
    enrolled_count INT;
BEGIN
    FOR course_rec IN 
        SELECT * FROM courses
    LOOP
        -- Omitir cursos cancelados, finalizados o eliminados
        IF course_rec.status IN (5, 6, 7) THEN
            CONTINUE;
        END IF;

        -- Número de inscritos (con estado activo o pendiente, suponiendo estado 1 o 2)
        SELECT COUNT(*) INTO enrolled_count
        FROM course_enrollments
        WHERE course_id = course_rec.id AND enrollment_status IN (1, 2);

        -- Actualizar a Next si faltan más de 7 días
        IF now() < course_rec.date - INTERVAL '7 days' THEN
            UPDATE courses SET status = 1 WHERE id = course_rec.id; -- Next
        -- Actualizar a Active si está entre 7 y 3 días antes
        ELSIF now() >= course_rec.date - INTERVAL '3 days' AND now() < course_rec.date THEN
            UPDATE courses SET status = 2 WHERE id = course_rec.id; -- Active
        -- Ongoing si ya empezó y aún no terminó
        ELSIF now() >= course_rec.date AND now() < (course_rec.date + (course_rec.duration || ' minutes')::INTERVAL) THEN
            UPDATE courses SET status = 4 WHERE id = course_rec.id; -- Ongoing
        -- Finished si ya pasó el tiempo completo
        ELSIF now() >= (course_rec.date + (course_rec.duration || ' minutes')::INTERVAL) THEN
            UPDATE courses SET status = 6 WHERE id = course_rec.id; -- Finished
        END IF;

        -- Si el curso está en Next o Active pero ya está lleno
        IF course_rec.status IN (1, 2) AND enrolled_count >= course_rec.max_students THEN
            UPDATE courses SET status = 3 WHERE id = course_rec.id; -- Full
        END IF;
    END LOOP;
END;
$$;


--
-- Name: update_dive_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_dive_status() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Finished
    UPDATE dives
    SET status = 6
    WHERE date < now() AND status NOT IN (5, 6);

    -- Ongoing
    UPDATE dives
    SET status = 4
    WHERE date::date = current_date AND status NOT IN (4, 5, 6);

    -- Active
    UPDATE dives
    SET status = 2
    WHERE date::date <= current_date + INTERVAL '3 days'
      AND date::date > current_date
      AND status NOT IN (4, 5, 6);

    -- Next
    UPDATE dives
    SET status = 1
    WHERE date::date > current_date + INTERVAL '3 days'
      AND status NOT IN (4, 5, 6);

    -- Full (solo si está en estado 'Next' o 'Active' Y no hay plazas)
    UPDATE dives
    SET status = 3
    WHERE (status = 1 OR status = 2)
      AND max_divers <= (
          SELECT COUNT(*) FROM dive_registrations
          WHERE dive_id = dives.id
      );
END;
$$;


--
-- Name: update_geo_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_geo_location() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Si geo_location está vacío y lat/lon tienen valor, lo generamos
  IF NEW.geo_location IS NULL AND NEW.latitude IS NOT NULL AND NEW.longitude IS NOT NULL THEN
    NEW.geo_location := ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: update_waitlist_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_waitlist_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE dive_registrations
    SET waitlist = (
        SELECT COUNT(*) 
        FROM waitlist 
        WHERE dive_id = NEW.dive_id 
          AND status_id = (SELECT id FROM status_events WHERE status = 'Active')
    )
    WHERE dive_id = NEW.dive_id;

    RETURN NEW;
END;
$$;


--
-- Name: validate_certification_entity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_certification_entity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM diver_levels 
        WHERE id = NEW.certification 
        AND certifying_entity_id = NEW.certifying_entity
    ) THEN
        RAISE EXCEPTION 'La certificación no pertenece a la entidad certificadora especificada';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: validate_course_requirements(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_course_requirements() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.requirements = NEW.certification THEN
        RAISE EXCEPTION 'Los requisitos no pueden ser iguales a la certificación del curso';
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: validate_diver_type_levels(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_diver_type_levels() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    diver_id INT;
    instructor_id INT;
BEGIN
    -- Obtener los IDs correctos desde event_categories para comparación
    SELECT id INTO diver_id FROM event_categories WHERE category_name = 'Diver Type' AND value_name = 'Diver' LIMIT 1;
    SELECT id INTO instructor_id FROM event_categories WHERE category_name = 'Diver Type' AND value_name = 'Instructor' LIMIT 1;

    -- Si es un buceador, el campo instructor_level debe ser NULL o 0
    IF NEW.diver_type = diver_id THEN
        IF NEW.instructor_level IS NOT NULL AND NEW.instructor_level <> 0 THEN
            RAISE EXCEPTION 'Users with diver_type = Diver cannot have an instructor_level.';
        END IF;
    END IF;

    -- Si es un instructor, el campo diving_level debe ser 0
    IF NEW.diver_type = instructor_id THEN
        IF NEW.diving_level IS DISTINCT FROM 0 THEN
            RAISE EXCEPTION 'Users with diver_type = Instructor must have diving_level = 0.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: validate_user_uniqueness(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_user_uniqueness() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Verificación de email duplicado
    IF EXISTS (
        SELECT 1 FROM users
        WHERE email = NEW.email AND id <> NEW.id
    ) THEN
        RAISE EXCEPTION 'Email "%", already registered.', NEW.email;
    END IF;

    -- Verificación de username duplicado
    IF EXISTS (
        SELECT 1 FROM users
        WHERE username = NEW.username AND id <> NEW.id
    ) THEN
        RAISE EXCEPTION 'Username"%", already exists.', NEW.username;
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_logs (
    id integer NOT NULL,
    user_id integer NOT NULL,
    action_type integer NOT NULL,
    target_table character varying(100) NOT NULL,
    target_id integer NOT NULL,
    action_date timestamp without time zone NOT NULL,
    description text,
    ip_address character varying(45),
    code character varying(30) NOT NULL
);


--
-- Name: COLUMN action_logs.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.user_id IS 'ID of the user who performed the action';


--
-- Name: COLUMN action_logs.action_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.action_type IS 'Type of action based on event_categories (Log Action)';


--
-- Name: COLUMN action_logs.target_table; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.target_table IS 'Name of the target table affected by the action';


--
-- Name: COLUMN action_logs.target_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.target_id IS 'ID of the affected record in the target table (optional)';


--
-- Name: COLUMN action_logs.action_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.action_date IS 'Timestamp when the action occurred';


--
-- Name: COLUMN action_logs.description; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.description IS 'Details or error message describing the event';


--
-- Name: COLUMN action_logs.ip_address; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.ip_address IS 'IP address from which the action originated';


--
-- Name: COLUMN action_logs.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.action_logs.code IS 'Unique code of the event (can refer to various entities)';


--
-- Name: action_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_logs_id_seq OWNED BY public.action_logs.id;


--
-- Name: certification_courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certification_courses (
    id integer NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(50) NOT NULL,
    certification character varying(30) NOT NULL,
    certifying_entity integer NOT NULL,
    requirements character varying(30) NOT NULL,
    course_type character varying(30) NOT NULL,
    course_type_id integer NOT NULL
);


--
-- Name: certification_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.certification_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: certification_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.certification_courses_id_seq OWNED BY public.certification_courses.id;


--
-- Name: certification_equivalences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certification_equivalences (
    id integer NOT NULL,
    certifying_entity integer NOT NULL,
    category character varying(50) NOT NULL,
    level character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    level_code character varying(30) NOT NULL,
    category_course_id integer NOT NULL
);


--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.certification_equivalences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.certification_equivalences_id_seq OWNED BY public.certification_equivalences.id;


--
-- Name: certifying_entities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.certifying_entities (
    id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    acronym character varying(20) NOT NULL,
    code character varying(30) NOT NULL,
    country_id integer NOT NULL
);


--
-- Name: certifying_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.certifying_entities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: certifying_entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.certifying_entities_id_seq OWNED BY public.certifying_entities.id;


--
-- Name: country_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.country_codes (
    id integer NOT NULL,
    country_code character varying(2) NOT NULL,
    country_name character varying(50) NOT NULL,
    phone_code character varying(10) NOT NULL,
    active boolean DEFAULT true NOT NULL
);


--
-- Name: country_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.country_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: country_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.country_codes_id_seq OWNED BY public.country_codes.id;


--
-- Name: course_enrollments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.course_enrollments (
    id integer NOT NULL,
    course_id integer NOT NULL,
    student_id integer NOT NULL,
    enrollment_date timestamp without time zone NOT NULL,
    code character varying(30) NOT NULL,
    enrollment_status integer NOT NULL
);


--
-- Name: course_enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.course_enrollments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: course_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.course_enrollments_id_seq OWNED BY public.course_enrollments.id;


--
-- Name: courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courses (
    id integer NOT NULL,
    course_id integer NOT NULL,
    location character varying(150) NOT NULL,
    duration integer NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    instructor_id integer NOT NULL,
    num_practices integer DEFAULT 5 NOT NULL,
    organizing_club character varying(100) NOT NULL,
    price integer NOT NULL,
    payment integer,
    status integer NOT NULL,
    speciality_course_id integer,
    created_at timestamp without time zone DEFAULT now(),
    max_students integer DEFAULT 0 NOT NULL,
    CONSTRAINT chk_only_one_course_type CHECK ((((course_id <> 0) AND (speciality_course_id = 0)) OR ((course_id = 0) AND (speciality_course_id <> 0)))),
    CONSTRAINT courses_check CHECK ((end_date > start_date))
);


--
-- Name: courses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.courses_id_seq OWNED BY public.courses.id;


--
-- Name: deletions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deletions (
    id integer NOT NULL,
    log_id integer NOT NULL,
    deleted_record integer NOT NULL,
    deleted_id integer NOT NULL,
    deleted_by integer NOT NULL,
    deletion_date timestamp without time zone NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.deletions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.deletions_id_seq OWNED BY public.deletions.id;


--
-- Name: dive_cancellations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dive_cancellations (
    id integer NOT NULL,
    dive_id integer NOT NULL,
    status_id integer NOT NULL,
    canceled_by integer NOT NULL,
    date timestamp without time zone NOT NULL,
    information text NOT NULL,
    code character varying(30) NOT NULL,
    reasons integer DEFAULT 41 NOT NULL
);


--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dive_cancellations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dive_cancellations_id_seq OWNED BY public.dive_cancellations.id;


--
-- Name: dive_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dive_registrations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    dive_id integer NOT NULL,
    registration_date timestamp without time zone NOT NULL,
    attendants integer NOT NULL,
    waitlist integer DEFAULT 0 NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: dive_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dive_registrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dive_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dive_registrations_id_seq OWNED BY public.dive_registrations.id;


--
-- Name: dive_sites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dive_sites (
    id integer NOT NULL,
    name character varying(150) NOT NULL,
    location character varying(150) NOT NULL,
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    geo_location public.geography(Point,4326),
    depth integer NOT NULL,
    region character varying(50) NOT NULL,
    country integer NOT NULL,
    code character varying(30) NOT NULL,
    water integer NOT NULL,
    kind_of_dive integer DEFAULT 16 NOT NULL,
    dive_access integer DEFAULT 21 NOT NULL
);


--
-- Name: dive_sites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dive_sites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dive_sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dive_sites_id_seq OWNED BY public.dive_sites.id;


--
-- Name: diver_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diver_levels (
    id integer NOT NULL,
    certifying_entity_id integer NOT NULL,
    level character varying(20) NOT NULL,
    certification character varying(255) NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: diver_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.diver_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: diver_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.diver_levels_id_seq OWNED BY public.diver_levels.id;


--
-- Name: diver_specialities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.diver_specialities (
    id integer NOT NULL,
    diver_level integer NOT NULL,
    code character varying(30) NOT NULL,
    required boolean DEFAULT false NOT NULL,
    name character varying(100) NOT NULL
);


--
-- Name: diver_specialities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.diver_specialities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: diver_specialities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.diver_specialities_id_seq OWNED BY public.diver_specialities.id;


--
-- Name: dives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dives (
    id integer NOT NULL,
    id_site integer NOT NULL,
    name character varying(100) NOT NULL,
    date timestamp without time zone NOT NULL,
    meeting_point character varying(150) NOT NULL,
    meeting_time timestamp without time zone NOT NULL,
    duration integer NOT NULL,
    planned_depth integer NOT NULL,
    dive_plan text NOT NULL,
    practician_admited boolean DEFAULT false NOT NULL,
    min_level_required integer NOT NULL,
    max_divers integer NOT NULL,
    status integer NOT NULL,
    credits integer NOT NULL,
    description text NOT NULL,
    code character varying(30) NOT NULL,
    day_light_id integer DEFAULT 24 NOT NULL,
    weather_conditions integer NOT NULL
);


--
-- Name: dives_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dives_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dives_id_seq OWNED BY public.dives.id;


--
-- Name: event_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_categories (
    id integer NOT NULL,
    category_name character varying(100) NOT NULL,
    value_name character varying(100) NOT NULL,
    description text
);


--
-- Name: event_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_categories_id_seq OWNED BY public.event_categories.id;


--
-- Name: instructor_levels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.instructor_levels (
    id integer NOT NULL,
    certifying_entity_id integer NOT NULL,
    level character varying(20) NOT NULL,
    certification character varying(255) NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: instructor_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.instructor_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: instructor_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.instructor_levels_id_seq OWNED BY public.instructor_levels.id;


--
-- Name: master_tables_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.master_tables_list (
    id integer NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    status_id integer DEFAULT 2 NOT NULL,
    last_updated timestamp without time zone DEFAULT now() NOT NULL,
    notes text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    status_changed_at timestamp without time zone NOT NULL,
    deletion_reason text NOT NULL
);


--
-- Name: master_tables_list_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.master_tables_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: master_tables_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.master_tables_list_id_seq OWNED BY public.master_tables_list.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id integer NOT NULL,
    dive_id integer NOT NULL,
    user_id integer NOT NULL,
    review_date timestamp without time zone NOT NULL,
    visibility integer NOT NULL,
    water_temperature numeric NOT NULL,
    surface_temperature numeric NOT NULL,
    reached_depth integer NOT NULL,
    photos text,
    comment text NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reviews_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: speciality_courses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.speciality_courses (
    id integer NOT NULL,
    speciality_id integer NOT NULL,
    code character varying(30),
    name character varying(50) NOT NULL,
    certification character varying(30),
    requirements character varying(50) NOT NULL,
    course_type character varying(50) NOT NULL
);


--
-- Name: speciality_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.speciality_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: speciality_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.speciality_courses_id_seq OWNED BY public.speciality_courses.id;


--
-- Name: status_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.status_events (
    id integer NOT NULL,
    status character varying(20) NOT NULL,
    code character varying(30) NOT NULL
);


--
-- Name: status_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.status_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: status_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.status_events_id_seq OWNED BY public.status_events.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id integer NOT NULL,
    code character varying(30) NOT NULL,
    name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    birth_date date NOT NULL,
    country integer NOT NULL,
    phone character varying(20) NOT NULL,
    gender integer NOT NULL,
    weight integer NOT NULL,
    height integer NOT NULL,
    size integer NOT NULL,
    role integer DEFAULT 9 NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(255) NOT NULL,
    diver_type integer DEFAULT 11 NOT NULL,
    certifying_entity integer NOT NULL,
    diving_level integer NOT NULL,
    instructor_level integer,
    federation_license character varying(20) NOT NULL,
    insurance boolean DEFAULT false,
    insurance_policy character varying(50) NOT NULL,
    registration_date timestamp without time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    total_dives integer DEFAULT 0 NOT NULL,
    credits integer DEFAULT 0 NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: waitlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.waitlist (
    id integer NOT NULL,
    user_id integer NOT NULL,
    dive_id integer NOT NULL,
    code character varying(30) NOT NULL,
    notified boolean DEFAULT false NOT NULL,
    listed_date timestamp without time zone DEFAULT now() NOT NULL,
    status_id integer DEFAULT 2 NOT NULL
);


--
-- Name: waitlist_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.waitlist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: waitlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.waitlist_id_seq OWNED BY public.waitlist.id;


--
-- Name: action_logs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs ALTER COLUMN id SET DEFAULT nextval('public.action_logs_id_seq'::regclass);


--
-- Name: certification_courses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_courses ALTER COLUMN id SET DEFAULT nextval('public.certification_courses_id_seq'::regclass);


--
-- Name: certification_equivalences id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_equivalences ALTER COLUMN id SET DEFAULT nextval('public.certification_equivalences_id_seq'::regclass);


--
-- Name: certifying_entities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certifying_entities ALTER COLUMN id SET DEFAULT nextval('public.certifying_entities_id_seq'::regclass);


--
-- Name: country_codes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_codes ALTER COLUMN id SET DEFAULT nextval('public.country_codes_id_seq'::regclass);


--
-- Name: course_enrollments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments ALTER COLUMN id SET DEFAULT nextval('public.course_enrollments_id_seq'::regclass);


--
-- Name: courses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses ALTER COLUMN id SET DEFAULT nextval('public.courses_id_seq'::regclass);


--
-- Name: deletions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions ALTER COLUMN id SET DEFAULT nextval('public.deletions_id_seq'::regclass);


--
-- Name: dive_cancellations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations ALTER COLUMN id SET DEFAULT nextval('public.dive_cancellations_id_seq'::regclass);


--
-- Name: dive_registrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations ALTER COLUMN id SET DEFAULT nextval('public.dive_registrations_id_seq'::regclass);


--
-- Name: dive_sites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites ALTER COLUMN id SET DEFAULT nextval('public.dive_sites_id_seq'::regclass);


--
-- Name: diver_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_levels ALTER COLUMN id SET DEFAULT nextval('public.diver_levels_id_seq'::regclass);


--
-- Name: diver_specialities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_specialities ALTER COLUMN id SET DEFAULT nextval('public.diver_specialities_id_seq'::regclass);


--
-- Name: dives id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives ALTER COLUMN id SET DEFAULT nextval('public.dives_id_seq'::regclass);


--
-- Name: event_categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_categories ALTER COLUMN id SET DEFAULT nextval('public.event_categories_id_seq'::regclass);


--
-- Name: instructor_levels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instructor_levels ALTER COLUMN id SET DEFAULT nextval('public.instructor_levels_id_seq'::regclass);


--
-- Name: master_tables_list id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_tables_list ALTER COLUMN id SET DEFAULT nextval('public.master_tables_list_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: speciality_courses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.speciality_courses ALTER COLUMN id SET DEFAULT nextval('public.speciality_courses_id_seq'::regclass);


--
-- Name: status_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_events ALTER COLUMN id SET DEFAULT nextval('public.status_events_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: waitlist id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist ALTER COLUMN id SET DEFAULT nextval('public.waitlist_id_seq'::regclass);


--
-- Data for Name: job; Type: TABLE DATA; Schema: cron; Owner: -
--

INSERT INTO cron.job (jobid, schedule, command, nodename, nodeport, database, username, active, jobname) VALUES (1, '0 * * * *', 'SELECT update_dive_status();', 'localhost', 5432, 'dive_app', 'postgres', true, 'update_dive_status_hourly');
INSERT INTO cron.job (jobid, schedule, command, nodename, nodeport, database, username, active, jobname) VALUES (2, '15 * * * *', 'SELECT update_course_status();', 'localhost', 5432, 'dive_app', 'postgres', true, 'update_course_status_hourly');


--
-- Data for Name: job_run_details; Type: TABLE DATA; Schema: cron; Owner: -
--

INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 1, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 22, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 2, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 3, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 4, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 23, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 5, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 6, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 7, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 8, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 9, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 10, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 11, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 12, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 13, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 14, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 15, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 16, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 17, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 18, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 19, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (1, 20, NULL, 'dive_app', 'postgres', 'SELECT update_dive_status();', 'failed', 'connection failed', NULL, NULL);
INSERT INTO cron.job_run_details (jobid, runid, job_pid, database, username, command, status, return_message, start_time, end_time) VALUES (2, 21, NULL, 'dive_app', 'postgres', 'SELECT update_course_status();', 'failed', 'connection failed', NULL, NULL);


--
-- Data for Name: action_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: certification_courses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (0, 'CU-D-SYS00-00', 'No Certification Course', 'D-SYS00-00', 0, 'diver level 0', 'Undefined', 0);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (4, 'CU-D-FE34-GG', 'Group Guide Course', 'D-FE34-GG', 1, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (16, 'CU-D-BS44-GG', '1st Class Diver Course', 'D-BS44-GG', 5, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (29, 'CU-D-GC34-03', 'Guardia Civil Diver Course', 'D-GC34-03', 10, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (33, 'CU-D-FA34-GG1', 'Combat Diver Course', 'D-FA34-GG1', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (34, 'CU-D-FA34-GG2', 'Mine Diver Course', 'D-FA34-GG2', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (35, 'CU-D-FA34-GG3', 'Fitness GP Diver Course', 'D-FA34-GG3', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (36, 'CU-D-FA34-GG4', 'Assault Diver Course', 'D-FA34-GG4', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (37, 'CU-D-FA34-GG5', 'Amphibious Sapper Course', 'D-FA34-GG5', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (38, 'CU-D-FA34-GG6', 'Dive Technology Course', 'D-FA34-GG6', 11, 'diver level 3', 'Guide', 67);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (1, 'CU-D-FE34-01', '1 Star Diver (B1E) Course', 'D-FE34-01', 1, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (2, 'CU-D-FE34-02', '2 Star Diver (B2E) Course', 'D-FE34-02', 1, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (3, 'CU-D-FE34-03', '3 Star Diver (B3E) Course', 'D-FE34-03', 1, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (5, 'CU-D-CM33-01', 'CMAS 1 Star Diver Course', 'D-CM33-01', 2, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (6, 'CU-D-CM33-02', 'CMAS 2 Star Diver Course', 'D-CM33-02', 2, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (7, 'CU-D-CM33-03', 'CMAS 3 Star Diver Course', 'D-CM33-03', 2, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (8, 'CU-D-PA01-01', 'Open Water Diver Course', 'D-PA01-01', 3, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (9, 'CU-D-PA01-02', 'Rescue Diver Course', 'D-PA01-02', 3, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (10, 'CU-D-PA01-03', 'Divemaster - Master Scuba Diver Course', 'D-PA01-03', 3, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (11, 'CU-D-MA33-02', '2nd Class Diver Course', 'D-MA34-02', 4, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (12, 'CU-D-MA33-03', '1st Class Diver Course', 'D-MA34-03', 4, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (13, 'CU-D-BS44-01', 'Ocean Diver - Club Diver - Sport Diver Course', 'D-BS44-01', 5, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (14, 'CU-D-BS44-02', 'Dive Leader Course', 'D-BS44-02', 5, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (15, 'CU-D-BS44-03', 'Advanced Diver Course', 'D-BS44-03', 5, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (17, 'CU-D-SS01-01', 'Open Water Diver Course', 'D-SS01-01', 6, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (18, 'CU-D-SS01-02', 'Advanced Open Water Diver Course', 'D-SS01-02', 6, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (19, 'CU-D-SS01-03', 'Divemaster - Master Diver - Diver Con. Course', 'D-SS01-03', 6, 'diver level 3', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (20, 'CU-D-AC01-01', 'Open Water Diver Course', 'D-AC01-01', 7, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (21, 'CU-D-AC01-02', 'Advanced Diver Course', 'D-AC01-02', 7, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (22, 'CU-D-AC01-03', 'Divemaster - Master Diver Course', 'D-AC01-03', 7, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (23, 'CU-D-NA01-01', 'Scuba Diver Course', 'D-NA01-01', 8, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (24, 'CU-D-NA01-02', 'Rescue Diver Course', 'D-NA01-02', 8, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (25, 'CU-D-NA01-03', 'Master Scuba Diver Course', 'D-NA01-03', 8, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (26, 'CU-D-PD01-01', 'Starter Course', 'D-PD01-01', 9, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (27, 'CU-D-PD01-02', '2nd Restricted Course', 'D-PD01-02', 9, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (28, 'CU-D-PD01-03', '2nd Professional Course', 'D-PD01-03', 9, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (30, 'CU-D-FA34-01', 'Scientific Diver Course', 'D-FA34-01', 11, 'diver level 0', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (31, 'CU-D-FA34-02', 'Support Diver Course', 'D-FA34-02', 11, 'diver level 1', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (32, 'CU-D-FA34-03', 'Elementary Diver Course', 'D-FA34-03', 11, 'diver level 2', 'Diver', 65);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (40, 'CU-I-FE34-01', '1 Star Intructor Course', 'I-FE34-01', 1, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (41, 'CU-I_FE34-02', '2 Star Instructor Course', 'I-FE34-02', 1, 'instructor level 1', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (42, 'CU-I_FE34-03', '3 Star Instructor Course', 'I-FE34-03', 1, 'instructor level 2', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (43, 'CU-I-BS44-02', 'Open Water Instructor Course', 'I-BS44-00', 5, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (44, 'CU-I-PA01-02', 'Open Water Instructor Course', 'I-PA01-02', 3, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (45, 'CU-I-SS01-02', 'Open Water Instructor Course', 'I-SS01-02', 6, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (46, 'CU-I-AC01-02', 'Open Water Instructor Course', 'I-AC01-02', 7, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (47, 'CU-I-NA01-02', 'Scuba Instructor Course', 'I-NA01-02', 8, 'diver level 3', 'Instructor', 66);
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) VALUES (39, 'CU-D-FA34-GG7', 'Dive Speciality Course', 'D-FA34-GG7', 11, 'diver level 3', 'Guide', 67);


--
-- Data for Name: certification_equivalences; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (5, 1, 'instructor', 'Level 1', '1 Star Instructor', 'I-FE34-01', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (6, 1, 'instructor', 'Level 2', '2 Star Instructor', 'I-FE34-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (7, 1, 'instructor', 'Level 3', '3 Star Instructor', 'I-FE34-03', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (11, 2, 'instructor', 'Level 1', '1 Star Instructor', 'I-CM33-01', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (12, 2, 'instructor', 'Level 2', '2 Star Instructor', 'I-CM33-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (13, 2, 'instructor', 'Level 3', '3 Star Instructor', 'I-CM33-03', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (17, 3, 'instructor', 'Level 2', 'Open Water Instructor', 'I-PA01-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (24, 5, 'instructor', 'Level 2', 'Open Water Instructor', 'I-BS44-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (28, 6, 'instructor', 'Level 2', 'Open Water Instructor', 'I-SS01-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (32, 7, 'instructor', 'Level 2', 'Open Water Instructor', 'I-AC01-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (36, 8, 'instructor', 'Level 2', 'Scuba Instructor', 'I-NA01-02', 66);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (1, 1, 'diver', 'Level 1', '1 Star Diver (B1E)', 'D-FE34-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (2, 1, 'diver', 'Level 2', '2 Star Diver (B2E)', 'D-FE34-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (3, 1, 'diver', 'Level 3', '3 Star Diver (B3E)', 'D-FE34-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (4, 1, 'diver', 'Guide', 'Group Guide', 'D-FE34-GG', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (8, 2, 'diver', 'Level 1', 'CMAS 1 Star Diver', 'D-CM33-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (9, 2, 'diver', 'Level 2', 'CMAS 2 Star Diver', 'D-CM33-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (10, 2, 'diver', 'Level 3', 'CMAS 3 Star Diver', 'D-CM33-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (14, 3, 'diver', 'Level 1', 'Open Water Diver', 'D-PA01-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (15, 3, 'diver', 'Level 2', 'Rescue Diver', 'D-PA01-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (16, 3, 'diver', 'Level 3', 'Divemaster - Master Scuba Diver', 'D-PA01-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (18, 4, 'diver', 'Level 2', '2nd Class Diver', 'D-MA34-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (19, 4, 'diver', 'Level 3', '1st Class Diver', 'D-MA34-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (20, 5, 'diver', 'Level 1', 'Ocean Diver - Club Diver - Sport Diver', 'D-BS44-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (21, 5, 'diver', 'Level 2', 'Dive Leader', 'D-BS44-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (22, 5, 'diver', 'Level 3', 'Advanced Diver', 'D-BS44-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (23, 5, 'diver', 'Guide', '1st Class Diver', 'D-BS44-GG', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (25, 6, 'diver', 'Level 1', 'Open Water Diver', 'D-SS01-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (26, 6, 'diver', 'Level 2', 'Advanced Open Water Diver', 'D-SS01-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (27, 6, 'diver', 'Level 3', 'Divemaster - Master Diver - Diver Con.', 'D-SS01-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (29, 7, 'diver', 'Level 1', 'Open Water Diver', 'D-AC01-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (30, 7, 'diver', 'Level 2', 'Advanced Diver', 'D-AC01-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (31, 7, 'diver', 'Level 3', 'Divemaster - Master Diver', 'D-AC01-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (33, 8, 'diver', 'Level 1', 'Scuba Diver', 'D-NA01-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (34, 8, 'diver', 'Level 2', 'Rescue Diver', 'D-NA01-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (35, 8, 'diver', 'Level 3', 'Master Scuba Diver', 'D-NA01-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (37, 9, 'diver', 'Level 1', 'Starter', 'D-PD01-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (38, 9, 'diver', 'Level 2', '2nd Restricted', 'D-PD01-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (39, 9, 'diver', 'Level 3', '2nd Professional', 'D-PD01-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (40, 10, 'diver', 'Level 3', 'Guardia Civil Diver', 'D-GC34-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (41, 11, 'diver', 'Level 1', 'Scientific Diver', 'D-FA34-01', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (42, 11, 'diver', 'Level 2', 'Support Diver', 'D-FA34-02', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (43, 11, 'diver', 'Level 3', 'Elementary Diver', 'D-FA34-03', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (44, 11, 'diver', 'Guide', 'Combat Diver', 'D-FA34-GG1', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (45, 11, 'diver', 'Guide', 'Mine Diver', 'D-FA34-GG2', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (46, 11, 'diver', 'Guide', 'Fitness GP Diver', 'D-FA34-GG3', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (47, 11, 'diver', 'Guide', 'Assault Diver', 'D-FA34-GG4', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (48, 11, 'diver', 'Guide', 'Amphibious Sapper', 'D-FA34-GG5', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (49, 11, 'diver', 'Guide', 'Dive Technology', 'D-FA34-GG6', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (50, 11, 'diver', 'Guide', 'Dive Speciality', 'D-FA34-GG7', 65);
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) VALUES (51, 0, 'diver', 'level 0', 'No Certification / Entry Level', 'D-NONE-00', 65);


--
-- Data for Name: certifying_entities; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (9, 'Professional Dive', 'PROFESSIONAL DIVE', 'PD01', 0);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (0, 'System', 'SYS', 'SYS00', 0);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (1, 'Federación Española de Actividades Subacuáticas', 'FEDAS', 'FE34', 58);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (4, 'Mediterranean Aquatic Professions Association', 'MAPA', 'MA34', 58);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (11, 'EMB Fuerzas Armadas Ejército Español', 'ARMADA', 'FA34', 58);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (10, 'GEAS Guardia Civil', 'GUARDIA CIVIL', 'GC34', 58);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (2, 'Confédération Mondiale des Activités Subaquatiques', 'CMAS', 'CM33', 65);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (3, 'Professional Association of Diving Instructors', 'PADI', 'PA01', 59);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (8, 'National Association of Underwater Instructors', 'NAUI', 'NA01', 59);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (5, 'British Sub-Aqua Club', 'BSAC', 'BS44', 143);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (6, 'Scuba Schools International', 'SSI', 'SS01', 3);
INSERT INTO public.certifying_entities (id, full_name, acronym, code, country_id) VALUES (7, 'American and Canadian Underwater Certifications', 'ACUC', 'AC01', 34);


--
-- Data for Name: country_codes; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (1, 'AF', 'Afghanistan', '+93', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (2, 'AL', 'Albania', '+355', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (3, 'DE', 'Germany', '+49', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (4, 'AD', 'Andorra', '+376', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (5, 'AO', 'Angola', '+244', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (6, 'AG', 'Antigua and Barbuda', '+1268', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (7, 'SA', 'Saudi Arabia', '+966', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (8, 'DZ', 'Algeria', '+213', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (9, 'AR', 'Argentina', '+54', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (10, 'AM', 'Armenia', '+374', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (11, 'AU', 'Australia', '+61', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (12, 'AT', 'Austria', '+43', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (13, 'AZ', 'Azerbaijan', '+994', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (14, 'BS', 'Bahamas', '+1242', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (15, 'BD', 'Bangladesh', '+880', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (16, 'BB', 'Barbados', '+1246', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (17, 'BH', 'Bahrain', '+973', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (18, 'BE', 'Belgium', '+32', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (19, 'BZ', 'Belize', '+501', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (20, 'BJ', 'Benin', '+229', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (21, 'BT', 'Bhutan', '+975', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (22, 'BY', 'Belarus', '+375', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (23, 'BO', 'Bolivia', '+591', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (24, 'BA', 'Bosnia and Herzegovina', '+387', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (25, 'BW', 'Botswana', '+267', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (26, 'BR', 'Brazil', '+55', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (27, 'BN', 'Brunei', '+673', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (28, 'BG', 'Bulgaria', '+359', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (29, 'BF', 'Burkina Faso', '+226', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (30, 'BI', 'Burundi', '+257', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (31, 'CV', 'Cabo Verde', '+238', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (32, 'KH', 'Cambodia', '+855', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (33, 'CM', 'Cameroon', '+237', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (34, 'CA', 'Canada', '+1', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (35, 'QA', 'Qatar', '+974', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (36, 'TD', 'Chad', '+235', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (37, 'CL', 'Chile', '+56', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (38, 'CN', 'China', '+86', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (39, 'CY', 'Cyprus', '+357', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (40, 'VA', 'Vatican City', '+379', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (41, 'CO', 'Colombia', '+57', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (42, 'KM', 'Comoros', '+269', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (43, 'KP', 'North Korea', '+850', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (44, 'KR', 'South Korea', '+82', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (45, 'CI', 'Ivory Coast', '+225', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (46, 'CR', 'Costa Rica', '+506', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (47, 'HR', 'Croatia', '+385', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (48, 'CU', 'Cuba', '+53', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (49, 'DK', 'Denmark', '+45', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (50, 'DM', 'Dominica', '+1767', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (51, 'EC', 'Ecuador', '+593', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (52, 'EG', 'Egypt', '+20', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (53, 'SV', 'El Salvador', '+503', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (54, 'AE', 'United Arab Emirates', '+971', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (55, 'ER', 'Eritrea', '+291', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (56, 'SK', 'Slovakia', '+421', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (57, 'SI', 'Slovenia', '+386', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (58, 'ES', 'Spain', '+34', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (59, 'US', 'United States', '+1', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (60, 'EE', 'Estonia', '+372', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (61, 'ET', 'Ethiopia', '+251', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (62, 'FJ', 'Fiji', '+679', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (63, 'PH', 'Philippines', '+63', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (64, 'FI', 'Finland', '+358', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (65, 'FR', 'France', '+33', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (66, 'GA', 'Gabon', '+241', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (67, 'GM', 'Gambia', '+220', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (68, 'GE', 'Georgia', '+995', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (69, 'GH', 'Ghana', '+233', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (70, 'GD', 'Grenada', '+1473', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (71, 'GR', 'Greece', '+30', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (72, 'GT', 'Guatemala', '+502', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (73, 'GN', 'Guinea', '+224', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (74, 'GQ', 'Equatorial Guinea', '+240', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (75, 'GW', 'Guinea-Bissau', '+245', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (76, 'GY', 'Guyana', '+592', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (77, 'HT', 'Haiti', '+509', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (78, 'HN', 'Honduras', '+504', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (79, 'HU', 'Hungary', '+36', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (80, 'IN', 'India', '+91', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (81, 'ID', 'Indonesia', '+62', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (82, 'IQ', 'Iraq', '+964', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (83, 'IR', 'Iran', '+98', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (84, 'IE', 'Ireland', '+353', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (85, 'IS', 'Iceland', '+354', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (86, 'MH', 'Marshall Islands', '+692', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (87, 'SB', 'Solomon Islands', '+677', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (88, 'IL', 'Israel', '+972', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (89, 'IT', 'Italy', '+39', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (90, 'JM', 'Jamaica', '+1876', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (91, 'JP', 'Japan', '+81', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (92, 'JO', 'Jordan', '+962', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (93, 'KZ', 'Kazakhstan', '+7', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (94, 'KE', 'Kenya', '+254', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (95, 'KG', 'Kyrgyzstan', '+996', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (96, 'KI', 'Kiribati', '+686', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (97, 'KW', 'Kuwait', '+965', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (98, 'LA', 'Laos', '+856', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (99, 'LS', 'Lesotho', '+266', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (100, 'LV', 'Latvia', '+371', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (101, 'LB', 'Lebanon', '+961', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (102, 'LR', 'Liberia', '+231', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (103, 'LY', 'Libya', '+218', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (104, 'LI', 'Liechtenstein', '+423', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (105, 'LT', 'Lithuania', '+370', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (106, 'LU', 'Luxembourg', '+352', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (107, 'MK', 'North Macedonia', '+389', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (108, 'MG', 'Madagascar', '+261', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (109, 'MY', 'Malaysia', '+60', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (110, 'MW', 'Malawi', '+265', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (111, 'MV', 'Maldives', '+960', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (112, 'ML', 'Mali', '+223', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (113, 'MT', 'Malta', '+356', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (114, 'MA', 'Morocco', '+212', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (115, 'MU', 'Mauritius', '+230', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (116, 'MR', 'Mauritania', '+222', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (117, 'MX', 'Mexico', '+52', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (118, 'FM', 'Micronesia', '+691', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (119, 'MD', 'Moldova', '+373', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (120, 'MC', 'Monaco', '+377', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (121, 'MN', 'Mongolia', '+976', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (122, 'ME', 'Montenegro', '+382', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (123, 'MZ', 'Mozambique', '+258', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (124, 'MM', 'Myanmar', '+95', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (125, 'NA', 'Namibia', '+264', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (126, 'NR', 'Nauru', '+674', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (127, 'NP', 'Nepal', '+977', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (128, 'NI', 'Nicaragua', '+505', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (129, 'NE', 'Niger', '+227', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (130, 'NG', 'Nigeria', '+234', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (131, 'NO', 'Norway', '+47', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (132, 'NZ', 'New Zealand', '+64', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (133, 'OM', 'Oman', '+968', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (134, 'NL', 'Netherlands', '+31', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (135, 'PK', 'Pakistan', '+92', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (136, 'PW', 'Palau', '+680', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (137, 'PA', 'Panama', '+507', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (138, 'PG', 'Papua New Guinea', '+675', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (139, 'PY', 'Paraguay', '+595', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (140, 'PE', 'Peru', '+51', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (141, 'PL', 'Poland', '+48', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (142, 'PT', 'Portugal', '+351', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (143, 'GB', 'United Kingdom', '+44', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (144, 'CF', 'Central African Republic', '+236', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (145, 'CZ', 'Czech Republic', '+420', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (146, 'CD', 'Democratic Republic of the Congo', '+243', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (147, 'DO', 'Dominican Republic', '+1809', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (148, 'CG', 'Republic of the Congo', '+242', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (149, 'RO', 'Romania', '+40', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (150, 'RW', 'Rwanda', '+250', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (151, 'RU', 'Russia', '+7', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (152, 'WS', 'Samoa', '+685', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (153, 'KN', 'Saint Kitts and Nevis', '+1869', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (154, 'SM', 'San Marino', '+378', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (155, 'VC', 'Saint Vincent and the Grenadines', '+1784', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (156, 'LC', 'Saint Lucia', '+1758', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (157, 'ST', 'Sao Tome and Principe', '+239', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (158, 'SN', 'Senegal', '+221', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (159, 'RS', 'Serbia', '+381', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (160, 'SC', 'Seychelles', '+248', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (161, 'SL', 'Sierra Leone', '+232', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (162, 'SG', 'Singapore', '+65', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (163, 'SY', 'Syria', '+963', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (164, 'SO', 'Somalia', '+252', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (165, 'LK', 'Sri Lanka', '+94', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (166, 'SZ', 'Eswatini', '+268', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (167, 'ZA', 'South Africa', '+27', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (168, 'SD', 'Sudan', '+249', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (169, 'SS', 'South Sudan', '+211', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (170, 'SE', 'Sweden', '+46', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (171, 'CH', 'Switzerland', '+41', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (172, 'SR', 'Suriname', '+597', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (173, 'TH', 'Thailand', '+66', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (174, 'TW', 'Taiwan', '+886', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (175, 'TZ', 'Tanzania', '+255', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (176, 'TJ', 'Tajikistan', '+992', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (177, 'TL', 'East Timor', '+670', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (178, 'TG', 'Togo', '+228', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (179, 'TO', 'Tonga', '+676', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (180, 'TT', 'Trinidad and Tobago', '+1868', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (181, 'TN', 'Tunisia', '+216', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (182, 'TM', 'Turkmenistan', '+993', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (183, 'TR', 'Turkey', '+90', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (184, 'TV', 'Tuvalu', '+688', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (185, 'UA', 'Ukraine', '+380', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (186, 'UG', 'Uganda', '+256', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (187, 'UY', 'Uruguay', '+598', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (188, 'UZ', 'Uzbekistan', '+998', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (189, 'VU', 'Vanuatu', '+678', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (190, 'VE', 'Venezuela', '+58', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (191, 'VN', 'Vietnam', '+84', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (192, 'YE', 'Yemen', '+967', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (193, 'DJ', 'Djibouti', '+253', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (194, 'ZM', 'Zambia', '+260', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (195, 'ZW', 'Zimbabwe', '+263', true);
INSERT INTO public.country_codes (id, country_code, country_name, phone_code, active) VALUES (0, 'II', 'International', '+00', false);


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: deletions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_cancellations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_registrations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_sites; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (1, 'Muelle Don Luis', 'Paseo de Ocharam Masas, Castro Urdiales', 43.386944, -3.218333, '0101000020E6100000BD19355F25BF09C014B1886187B14540', 12, 'Cantabria', 58, 'ST-CAN-001', 13, 15, 22);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (3, 'El Pedregal', 'Playa El Pedregal, Castro Urdiales', 43.381389, -3.225278, '0101000020E6100000F910548D5ECD09C0EE06D15AD1B04540', 8, 'Cantabria', 58, 'ST-CAN-002', 13, 15, 20);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (5, 'Cañones Napoleónicos', 'Acantilado de la Iglesia, Castro Urdiales', 43.388611, -3.215278, '0101000020E6100000E5620CACE3B809C0D4EE5701BEB14540', 15, 'Cantabria', 58, 'ST-CAN-003', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (6, 'Pecio Bajo Vitruvio', 'Bahía de Laredo', 43.411389, -3.191667, '0101000020E61000008AC745B5888809C092770E65A8B44540', 22, 'Cantabria', 58, 'ST-CAN-004', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (7, 'Bajo San Carlos', 'Reserva de Santoña', 43.441667, -3.456944, '0101000020E6100000D0D38041D2A70BC0795C548B88B84540', 16, 'Cantabria', 58, 'ST-CAN-005', 13, 15, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (8, 'Pecio Baldur', 'Saltacaballos', 43.401389, -3.191667, '0101000020E61000008AC745B5888809C0B1FCF9B660B34540', 32, 'Cantabria', 58, 'ST-CAN-006', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (9, 'Grúa Portuaria', 'Exterior Puerto Bilbao', 43.346111, -3.033889, '0101000020E61000009B8D9598674508C097E4805D4DAC4540', 15, 'Vizcaya', 58, 'ST-VIZ-001', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (10, 'Pecio Diana', 'Abra del Nervión', 43.350000, -3.030000, '0101000020E61000003D0AD7A3703D08C0CDCCCCCCCCAC4540', 30, 'Vizcaya', 58, 'ST-VIZ-002', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (11, 'Bajo Culebras', 'Azkorri, Sopelana', 43.380278, -2.992222, '0101000020E610000044F9821612F007C0B3B112F3ACB04540', 30, 'Vizcaya', 58, 'ST-VIZ-003', 13, 15, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (12, 'Bajo de los Chipirones', 'Sopelana', 43.378611, -2.988889, '0101000020E61000003FFED2A23EE907C0F373435376B04540', 25, 'Vizcaya', 58, 'ST-VIZ-004', 13, 15, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (13, 'Pecio Mina Mary', 'Bermeo', 43.420833, -2.721667, '0101000020E6100000C8D11C59F9C505C0EE0912DBDDB54540', 38, 'Vizcaya', 58, 'ST-VIZ-005', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (15, 'Pecio Mari Puri', 'Plentzia', 43.405000, -2.950000, '0101000020E61000009A999999999907C0A4703D0AD7B34540', 26, 'Vizcaya', 58, 'ST-VIZ-006', 13, 16, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (16, 'Arco de Ogoño', 'Bermeo', 43.453056, -2.745833, '0101000020E61000007638BA4A77F705C0D7A02FBDFDB94540', 18, 'Vizcaya', 58, 'ST-VIZ-007', 13, 17, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (18, 'Túnel de Otzarreta', 'Elantxobe', 43.403611, -2.638056, '0101000020E6100000F321A81ABD1A05C026A77686A9B34540', 12, 'Vizcaya', 58, 'ST-VIZ-008', 13, 17, 21);
INSERT INTO public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) VALUES (19, 'La Boya', 'Desembocadura de Mundaka', 43.406944, -2.698611, '0101000020E6100000C1012D5DC19605C0D7A6B1BD16B44540', 15, 'Vizcaya', 58, 'ST-VIZ-009', 13, 19, 21);


--
-- Data for Name: diver_levels; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (1, 1, 'Level 1', '1 Star Diver (B1E)', 'D-FE34-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (2, 1, 'Level 2', '2 Star Diver (B2E)', 'D-FE34-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (3, 1, 'Level 3', '3 Star Diver (B3E)', 'D-FE34-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (4, 1, 'Guide', 'Group Guide', 'D-FE34-GG');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (5, 2, 'Level 1', 'CMAS 1 Star Diver', 'D-CM33-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (6, 2, 'Level 2', 'CMAS 2 Star Diver', 'D-CM33-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (7, 2, 'Level 3', 'CMAS 3 Star Diver', 'D-CM33-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (8, 3, 'Level 1', 'Open Water Diver', 'D-PA01-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (9, 3, 'Level 2', 'Rescue Diver', 'D-PA01-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (10, 3, 'Level 3', 'Divemaster - Master Scuba Diver', 'D-PA01-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (11, 4, 'Level 2', '2nd Class Diver', 'D-MA34-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (12, 4, 'Level 3', '1st Class Diver', 'D-MA34-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (13, 5, 'Level 1', 'Ocean Diver - Club Diver - Sport Diver', 'D-BS44-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (14, 5, 'Level 2', 'Dive Leader', 'D-BS44-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (15, 5, 'Level 3', 'Advanced Diver', 'D-BS44-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (16, 5, 'Guide', '1st Class Diver', 'D-BS44-GG');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (17, 6, 'Level 1', 'Open Water Diver', 'D-SS01-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (18, 6, 'Level 2', 'Advanced Open Water Diver', 'D-SS01-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (19, 6, 'Level 3', 'Divemaster - Master Diver - Diver Con.', 'D-SS01-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (20, 7, 'Level 1', 'Open Water Diver', 'D-AC01-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (21, 7, 'Level 2', 'Advanced Diver', 'D-AC01-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (22, 7, 'Level 3', 'Divemaster - Master Diver', 'D-AC01-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (23, 8, 'Level 1', 'Scuba Diver', 'D-NA01-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (24, 8, 'Level 2', 'Rescue Diver', 'D-NA01-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (25, 8, 'Level 3', 'Master Scuba Diver', 'D-NA01-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (26, 9, 'Level 1', 'Starter', 'D-PD01-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (27, 9, 'Level 2', '2nd Restricted', 'D-PD01-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (28, 9, 'Level 3', '2nd Professional', 'D-PD01-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (29, 10, 'Level 3', 'Guardia Civil Diver', 'D-GC34-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (30, 11, 'Level 1', 'Scientific Diver', 'D-FA34-01');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (31, 11, 'Level 2', 'Support Diver', 'D-FA34-02');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (32, 11, 'Level 3', 'Elementary Diver', 'D-FA34-03');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (33, 11, 'Guide', 'Combat Diver', 'D-FA34-GG1');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (34, 11, 'Guide', 'Mine Diver', 'D-FA34-GG2');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (35, 11, 'Guide', 'Fitness GP Diver', 'D-FA34-GG3');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (36, 11, 'Guide', 'Assault Diver', 'D-FA34-GG4');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (37, 11, 'Guide', 'Amphibious Sapper', 'D-FA34-GG5');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (38, 11, 'Guide', 'Dive Technology', 'D-FA34-GG6');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (39, 11, 'Guide', 'Dive Speciality', 'D-FA34-GG7');
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (0, 0, 'level 0', 'No Certification / Entry Level', 'D-SYS00-00');


--
-- Data for Name: diver_specialities; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (1, 1, 'BLS01', false, 'Basic Life Support (BLS)');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (2, 1, 'OXAD01', false, 'Oxygen Administration');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (3, 1, 'NDV01', false, 'Night Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (4, 1, 'NXDV01', false, 'Nitrox Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (5, 1, 'UWNAV01', false, 'Underwater Navigation');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (6, 1, 'DSDV01', false, 'Dry Suit Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (7, 2, 'WRDV02', false, 'Wreck Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (8, 2, 'CRNDV02', false, 'Cavern Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (9, 2, 'ADDV02', false, 'Adaptive Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (10, 2, 'SRDV02', false, 'Search and Rescue Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (11, 2, 'CVDV02', false, 'Cave Diving (Introductory)');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (12, 2, 'UIDV02', false, 'Under Ice Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (13, 3, 'FCVDV03', false, 'Full Cave Diving');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (14, 3, 'TCHDV03', false, 'Technical Nitrox');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (15, 3, 'NRTMX03', false, 'Normoxic Trimix');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (16, 3, 'HPTMX03', false, 'Hypoxic Trimix');
INSERT INTO public.diver_specialities (id, diver_level, code, required, name) VALUES (0, 0, 'SYS00', false, 'System');


--
-- Data for Name: dives; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: event_categories; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (1, 'Gender', 'Fem', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (2, 'Gender', 'Masc', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (3, 'Size', 'XS', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (4, 'Size', 'S', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (5, 'Size', 'M', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (6, 'Size', 'L', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (7, 'Size', 'XL', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (8, 'Size', 'XXL', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (9, 'Role', 'User', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (10, 'Role', 'Admin', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (11, 'Diver Type', 'Diver', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (12, 'Diver Type', 'Instructor', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (13, 'Water', 'Salt', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (14, 'Water', 'Fresh', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (15, 'Kind of Dive', 'Reef', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (16, 'Kind of Dive', 'Wreck', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (17, 'Kind of Dive', 'Cave', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (18, 'Kind of Dive', 'Under Ice', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (20, 'Dive Access', 'Shore', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (21, 'Dive Access', 'Boat', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (22, 'Dive Access', 'Pier', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (23, 'Dive Access', 'Cave', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (24, 'Daylight', 'Day Dive', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (25, 'Daylight', 'Night Dive', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (26, 'Weather', 'Cloudy', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (27, 'Weather', 'Sunny', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (28, 'Weather', 'Rainy', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (29, 'Weather', 'Surge', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (30, 'Weather', 'Windy', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (31, 'Payment', 'Currency', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (32, 'Payment', 'Credits', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (33, 'Visibility', 'Bad (-3m)', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (34, 'Visibility', 'Regular (3~5m)', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (35, 'Visibility', 'Good (+5m)', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (36, 'Visibility', 'Very Good (+10m)', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (37, 'Visibility', 'Night Dive', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (38, 'Cancellation Reason', 'Bad Weather', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (39, 'Cancellation Reason', 'Close Access Road', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (40, 'Cancellation Reason', 'Slack of Responsible Instructor', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (41, 'Cancellation Reason', 'Not Enough Attendants', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (42, 'Cancellation Reason', 'Unexpected Surge', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (43, 'Cancellation Reason', 'Rain', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (44, 'Cancellation Reason', 'Personal Reasons', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (45, 'Log Action', 'CREATE', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (46, 'Log Action', 'UPDATE', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (47, 'Log Action', 'DELETE', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (48, 'Log Action', 'LOGIN', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (49, 'Log Action', 'LOGOUT', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (50, 'Log Action', 'VIEW', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (51, 'Log Action', 'FAILED_LOGIN', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (52, 'Log Action', 'ENROLLMENT', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (53, 'Log Action', 'PASSWORD_CHANGE', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (54, 'Log Action', 'ATTEND', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (55, 'Log Action', 'REVIEW', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (56, 'Deleted Record', 'users', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (57, 'Deleted Record', 'dives', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (58, 'Deleted Record', 'dive_sites', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (59, 'Deleted Record', 'courses', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (60, 'Deleted Record', 'dive_registrations', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (61, 'Deleted Record', 'course_enrollments', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (62, 'Deleted Record', 'dive_cancellations', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (63, 'Deleted Record', 'certification_courses', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (64, 'Deleted Record', 'reviews', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (65, 'Course Type', 'Diver', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (66, 'Course Type', 'Instructor', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (67, 'Course Type', 'Guide', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (68, 'Course Type', 'Specialty', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (0, 'Undefined', 'Undefined', NULL);
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (19, 'Kind of Dive', 'Drift', NULL);


--
-- Data for Name: instructor_levels; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (1, 1, 'Level 1', '1 Star Instructor', 'I-FE34-01');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (2, 1, 'Level 2', '2 Star Instructor', 'I-FE34-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (3, 1, 'Level 3', '3 Star Instructor', 'I-FE34-03');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (7, 5, 'Level 2', 'Open Water Instructor', 'I-BS44-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (8, 3, 'Level 2', 'Open Water Instructor', 'I-PA01-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (9, 6, 'Level 2', 'Open Water Instructor', 'I-SS01-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (10, 7, 'Level 2', 'Open Water Instructor', 'I-AC01-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (11, 8, 'Level 2', 'Scuba Instructor', 'I-NA01-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (4, 2, 'Level 1', 'CMAS 1 Star Instructor', 'I-CM33-01');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (5, 2, 'Level 2', 'CMAS 2 Star Instructor', 'I-CM33-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (6, 2, 'Level 3', 'CMAS 3 Star Instructor', 'I-CM33-03');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (0, 0, 'level 0', 'Max Diving Level', 'I-SYS00-00');


--
-- Data for Name: master_tables_list; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (1, 'public', 'action_logs', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Registra acciones de usuarios para auditoría del sistema.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (2, 'public', 'certification_courses', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Contiene los cursos oficiales de certificación para buceadores e instructores.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (3, 'public', 'certification_equivalences', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Relación de equivalencias entre certificaciones de distintas entidades.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (4, 'public', 'certifying_entities', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Listado de entidades certificadoras de buceo reconocidas.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (5, 'public', 'course_enrollments', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Inscripciones de usuarios en cursos de buceo.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (6, 'public', 'courses', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Cursos de buceo programados, con instructor, fechas y lugar.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (7, 'public', 'deletions', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Historial de registros eliminados en el sistema.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (8, 'public', 'dive_cancellations', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Cancelaciones de inmersiones y sus motivos.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (9, 'public', 'dive_registrations', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Registro de buceadores en inmersiones programadas.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (10, 'public', 'dive_sites', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Sitios de buceo con coordenadas, profundidad y tipo de inmersión.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (11, 'public', 'diver_levels', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Niveles de certificación de buceadores.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (13, 'public', 'dives', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Categorías de valores para enums reutilizables.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (12, 'public', 'diver_specialities', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Inmersiones programadas con información logística.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (14, 'public', 'event_categories', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Niveles de certificación de instructores.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (15, 'public', 'instructor_levels', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Reseñas y comentarios de los usuarios sobre inmersiones.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (16, 'public', 'reviews', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Sistema de referencia geoespacial (SRID 4326 y otros).', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (17, 'public', 'spatial_ref_sys', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Estados utilizados para eventos como inmersiones o cursos.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (18, 'public', 'status_events', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Usuarios registrados en la aplicación.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (19, 'public', 'users', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Lista de espera para inmersiones completas.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (20, 'public', 'waitlist', '2025-04-27 16:55:01.727141', 2, '2025-05-10 12:19:55.163599', 'Especialidades que puede obtener un buceador.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (21, 'public', 'public.speciality_courses', '2025-04-28 02:56:30.819801', 2, '2025-05-10 12:19:55.163599', 'Cursos asociados a especialidades de buceo.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (22, 'public', 'public.country_codes', '2025-05-07 12:59:51.05719', 2, '2025-05-10 12:19:55.163599', 'Listado de países con códigos y prefijos telefónicos.', true, '2025-05-10 13:33:39.30762', 'Table created');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) VALUES (23, 'public', 'public.users', '2025-05-08 11:43:15.929329', 2, '2025-05-10 12:19:55.163599', 'Vista redundante o réplica de la tabla de usuarios.', true, '2025-05-10 13:33:39.30762', 'Table created');


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: speciality_courses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (1, 1, 'CU-BLS01', 'Basic Life Support (BLS) Course', 'BLS01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (2, 2, 'CU-OXAD01', 'Oxygen Administration Course', 'OXAD01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (3, 3, 'CU-NDV01', 'Night Diving Course', 'NDV01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (4, 4, 'CU-NXDV01', 'Nitrox Diving Course', 'NXDV01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (5, 5, 'CU-UWNAV01', 'Underwater Navigation Course', 'UWNAV01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (6, 6, 'CU-DSDV01', 'Dry Suit Diving Course', 'DSDV01', 'diver level 1', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (7, 7, 'CU-WRDV02', 'Wreck Diving Course', 'WRDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (8, 8, 'CU-CRNDV02', 'Cavern Diving Course', 'CRNDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (9, 9, 'CU-ADDV02', 'Adaptive Diving Course', 'ADDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (10, 10, 'CU-SRDV02', 'Search and Rescue Diving Course', 'SRDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (11, 11, 'CU-CVDV02', 'Introductory Cave Diving Course', 'CVDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (12, 12, 'CU-UIDV02', 'Under Ice Diving Course', 'UIDV02', 'diver level 2', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (13, 13, 'CU-FCVDV03', 'Full Cave Diving Course', 'FCVDV03', 'diver level 3', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (14, 14, 'CU-TCHDV03', 'Technical Nitrox Course', 'TCHDV03', 'diver level 3', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (15, 15, 'CU-NRTMX03', 'Normoxic Trimix Course', 'NRTMX03', 'diver level 3', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (16, 16, 'CU-HPTMX03', 'Hypoxic Trimix Course', 'HPTMX03', 'diver level 3', 'Diver');
INSERT INTO public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) VALUES (0, 0, 'CU-SYS00', 'No Speciality Course', 'SYS00', 'diver level 0', 'Undefined');


--
-- Data for Name: status_events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.status_events (id, status, code) VALUES (1, 'Next', 'ST01');
INSERT INTO public.status_events (id, status, code) VALUES (2, 'Active', 'ST02');
INSERT INTO public.status_events (id, status, code) VALUES (3, 'Full', 'ST03');
INSERT INTO public.status_events (id, status, code) VALUES (4, 'Ongoing', 'ST04');
INSERT INTO public.status_events (id, status, code) VALUES (5, 'Canceled', 'ST05');
INSERT INTO public.status_events (id, status, code) VALUES (6, 'Finished', 'ST06');
INSERT INTO public.status_events (id, status, code) VALUES (0, 'Undefined', 'ST00');
INSERT INTO public.status_events (id, status, code) VALUES (7, 'Deleted', 'ST07');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: waitlist; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Name: jobid_seq; Type: SEQUENCE SET; Schema: cron; Owner: -
--

SELECT pg_catalog.setval('cron.jobid_seq', 2, true);


--
-- Name: runid_seq; Type: SEQUENCE SET; Schema: cron; Owner: -
--

SELECT pg_catalog.setval('cron.runid_seq', 23, true);


--
-- Name: action_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.action_logs_id_seq', 1, false);


--
-- Name: certification_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.certification_courses_id_seq', 47, true);


--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.certification_equivalences_id_seq', 51, true);


--
-- Name: certifying_entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.certifying_entities_id_seq', 1, false);


--
-- Name: country_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.country_codes_id_seq', 195, true);


--
-- Name: course_enrollments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.course_enrollments_id_seq', 1, false);


--
-- Name: courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.courses_id_seq', 1, false);


--
-- Name: deletions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.deletions_id_seq', 1, false);


--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dive_cancellations_id_seq', 1, false);


--
-- Name: dive_registrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dive_registrations_id_seq', 1, false);


--
-- Name: dive_sites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dive_sites_id_seq', 19, true);


--
-- Name: diver_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.diver_levels_id_seq', 1, false);


--
-- Name: diver_specialities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.diver_specialities_id_seq', 1, false);


--
-- Name: dives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.dives_id_seq', 1, false);


--
-- Name: event_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.event_categories_id_seq', 74, true);


--
-- Name: instructor_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instructor_levels_id_seq', 1, false);


--
-- Name: master_tables_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.master_tables_list_id_seq', 23, true);


--
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.reviews_id_seq', 1, false);


--
-- Name: speciality_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.speciality_courses_id_seq', 17, true);


--
-- Name: status_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.status_events_id_seq', 6, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_id_seq', 1, false);


--
-- Name: waitlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.waitlist_id_seq', 1, false);


--
-- Name: action_logs action_logs_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT action_logs_code_key UNIQUE (code);


--
-- Name: action_logs action_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT action_logs_pkey PRIMARY KEY (id);


--
-- Name: certification_courses certification_courses_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_code_key UNIQUE (code);


--
-- Name: certification_courses certification_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_pkey PRIMARY KEY (id);


--
-- Name: certification_equivalences certification_equivalences_level_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_level_code_key UNIQUE (level_code);


--
-- Name: certification_equivalences certification_equivalences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_pkey PRIMARY KEY (id);


--
-- Name: certifying_entities certifying_entities_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_code_key UNIQUE (code);


--
-- Name: certifying_entities certifying_entities_full_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_full_name_key UNIQUE (full_name);


--
-- Name: certifying_entities certifying_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_pkey PRIMARY KEY (id);


--
-- Name: country_codes country_codes_country_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_country_code_key UNIQUE (country_code);


--
-- Name: country_codes country_codes_country_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_country_name_key UNIQUE (country_name);


--
-- Name: country_codes country_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_pkey PRIMARY KEY (id);


--
-- Name: course_enrollments course_enrollments_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_code_key UNIQUE (code);


--
-- Name: course_enrollments course_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_pkey PRIMARY KEY (id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- Name: deletions deletions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_code_key UNIQUE (code);


--
-- Name: deletions deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_pkey PRIMARY KEY (id);


--
-- Name: dive_cancellations dive_cancellations_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_code_key UNIQUE (code);


--
-- Name: dive_cancellations dive_cancellations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_pkey PRIMARY KEY (id);


--
-- Name: dive_registrations dive_registrations_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_code_key UNIQUE (code);


--
-- Name: dive_registrations dive_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_pkey PRIMARY KEY (id);


--
-- Name: dive_sites dive_sites_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_code_key UNIQUE (code);


--
-- Name: dive_sites dive_sites_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_name_key UNIQUE (name);


--
-- Name: dive_sites dive_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_pkey PRIMARY KEY (id);


--
-- Name: diver_levels diver_levels_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_code_key UNIQUE (code);


--
-- Name: diver_levels diver_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_pkey PRIMARY KEY (id);


--
-- Name: diver_specialities diver_specialities_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialities_code_key UNIQUE (code);


--
-- Name: diver_specialities diver_specialties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialties_pkey PRIMARY KEY (id);


--
-- Name: dives dives_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_code_key UNIQUE (code);


--
-- Name: dives dives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_pkey PRIMARY KEY (id);


--
-- Name: event_categories event_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT event_categories_pkey PRIMARY KEY (id);


--
-- Name: instructor_levels instructor_levels_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_code_key UNIQUE (code);


--
-- Name: instructor_levels instructor_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_pkey PRIMARY KEY (id);


--
-- Name: master_tables_list master_tables_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_tables_list
    ADD CONSTRAINT master_tables_list_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_code_key UNIQUE (code);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: speciality_courses speciality_courses_certification_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_certification_key UNIQUE (certification);


--
-- Name: speciality_courses speciality_courses_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_code_key UNIQUE (code);


--
-- Name: speciality_courses speciality_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_pkey PRIMARY KEY (id);


--
-- Name: status_events status_events_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_code_key UNIQUE (code);


--
-- Name: status_events status_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_pkey PRIMARY KEY (id);


--
-- Name: status_events status_events_status_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_status_key UNIQUE (status);


--
-- Name: event_categories unique_category_value; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT unique_category_value UNIQUE (category_name, value_name);


--
-- Name: users users_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_code_key UNIQUE (code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_federation_license_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_federation_license_key UNIQUE (federation_license);


--
-- Name: users users_insurance_policy_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_insurance_policy_key UNIQUE (insurance_policy);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: waitlist waitlist_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_code_key UNIQUE (code);


--
-- Name: waitlist waitlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_pkey PRIMARY KEY (id);


--
-- Name: idx_action_logs_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_action_logs_user_date ON public.action_logs USING btree (user_id, action_date);


--
-- Name: idx_certification_courses_composite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_certification_courses_composite ON public.certification_courses USING btree (certification, certifying_entity);


--
-- Name: idx_certification_courses_entity_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_certification_courses_entity_type ON public.certification_courses USING btree (certifying_entity, course_type);


--
-- Name: idx_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_country_code ON public.country_codes USING btree (country_code);


--
-- Name: idx_courses_course_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_course_date ON public.courses USING btree (course_id, start_date);


--
-- Name: idx_courses_speciality_course_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_speciality_course_id ON public.courses USING btree (speciality_course_id);


--
-- Name: idx_dive_sites_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dive_sites_country ON public.dive_sites USING btree (country);


--
-- Name: idx_dive_sites_geo_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dive_sites_geo_location ON public.dive_sites USING gist (geo_location);


--
-- Name: idx_diver_levels_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_diver_levels_entity ON public.diver_levels USING btree (certifying_entity_id);


--
-- Name: idx_dives_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dives_date ON public.dives USING btree (date);


--
-- Name: idx_dives_day_light; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dives_day_light ON public.dives USING btree (day_light_id);


--
-- Name: idx_dives_weather; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dives_weather ON public.dives USING btree (weather_conditions);


--
-- Name: idx_event_categories_category_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_event_categories_category_value ON public.event_categories USING btree (category_name, value_name);


--
-- Name: idx_instructor_levels_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_instructor_levels_entity ON public.instructor_levels USING btree (certifying_entity_id);


--
-- Name: idx_phone_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_phone_code ON public.country_codes USING btree (phone_code);


--
-- Name: idx_reviews_dive_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_dive_user ON public.reviews USING btree (dive_id, user_id);


--
-- Name: idx_speciality_courses_speciality_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_speciality_courses_speciality_id ON public.speciality_courses USING btree (speciality_id);


--
-- Name: idx_users_active_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_active_role ON public.users USING btree (is_active, role);


--
-- Name: idx_waitlist_dive_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_waitlist_dive_status ON public.waitlist USING btree (dive_id, status_id);


--
-- Name: dives trg_dive_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_dive_code BEFORE INSERT ON public.dives FOR EACH ROW EXECUTE FUNCTION public.set_dive_code();


--
-- Name: users trg_exclusive_user_levels; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_exclusive_user_levels BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_exclusive_levels();


--
-- Name: users trg_generate_user_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_generate_user_code BEFORE INSERT ON public.users FOR EACH ROW WHEN ((new.code IS NULL)) EXECUTE FUNCTION public.generate_user_code();


--
-- Name: waitlist trg_generate_waitlist_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_generate_waitlist_code BEFORE INSERT ON public.waitlist FOR EACH ROW EXECUTE FUNCTION public.set_waitlist_code();


--
-- Name: master_tables_list trg_master_table_defaults; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_master_table_defaults BEFORE INSERT ON public.master_tables_list FOR EACH ROW EXECUTE FUNCTION public.set_defaults_on_insert_master_table();


--
-- Name: master_tables_list trg_master_table_update_defaults; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_master_table_update_defaults BEFORE UPDATE ON public.master_tables_list FOR EACH ROW EXECUTE FUNCTION public.set_defaults_on_update_master_table();


--
-- Name: users trg_normalize_user_levels_by_type; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_normalize_user_levels_by_type BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.normalize_user_levels_by_type();


--
-- Name: dive_registrations trg_promote_from_waitlist; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_promote_from_waitlist AFTER DELETE ON public.dive_registrations FOR EACH ROW EXECUTE FUNCTION public.promote_waitlisted_user();


--
-- Name: reviews trg_review_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_review_code BEFORE INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.set_review_code();


--
-- Name: dive_sites trg_site_code; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_site_code BEFORE INSERT ON public.dive_sites FOR EACH ROW EXECUTE FUNCTION public.set_site_code();


--
-- Name: dive_sites trg_update_geo_location; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_geo_location BEFORE INSERT OR UPDATE ON public.dive_sites FOR EACH ROW EXECUTE FUNCTION public.auto_set_geo_location();


--
-- Name: dives trg_update_geo_location_dives; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_geo_location_dives BEFORE INSERT OR UPDATE ON public.dives FOR EACH ROW EXECUTE FUNCTION public.auto_set_geo_location();


--
-- Name: courses trg_update_status_on_courses; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_status_on_courses AFTER INSERT OR UPDATE ON public.courses FOR EACH STATEMENT EXECUTE FUNCTION public.trg_check_event_status();


--
-- Name: dives trg_update_status_on_dives; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_status_on_dives AFTER INSERT OR UPDATE ON public.dives FOR EACH STATEMENT EXECUTE FUNCTION public.trg_check_event_status();


--
-- Name: waitlist trg_update_waitlist_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_update_waitlist_count AFTER INSERT OR DELETE OR UPDATE ON public.waitlist FOR EACH ROW EXECUTE FUNCTION public.update_waitlist_count();


--
-- Name: users trg_validate_diver_type_levels; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_diver_type_levels BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.validate_diver_type_levels();


--
-- Name: users trg_validate_user_uniqueness; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_validate_user_uniqueness BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.validate_user_uniqueness();


--
-- Name: certification_courses certification_courses_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: certification_equivalences certification_equivalences_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: certifying_entities certifying_entities_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country_codes(id);


--
-- Name: course_enrollments course_enrollments_enrollment_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_enrollment_status_fkey FOREIGN KEY (enrollment_status) REFERENCES public.status_events(id);


--
-- Name: courses courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.certification_courses(id);


--
-- Name: courses courses_speciality_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_speciality_course_id_fkey FOREIGN KEY (speciality_course_id) REFERENCES public.speciality_courses(id);


--
-- Name: courses courses_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_status_fkey FOREIGN KEY (status) REFERENCES public.status_events(id);


--
-- Name: deletions deletions_log_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_log_id_fkey FOREIGN KEY (log_id) REFERENCES public.action_logs(id);


--
-- Name: dive_cancellations dive_cancellations_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: dive_cancellations dive_cancellations_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: dive_registrations dive_registrations_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: dive_sites dive_sites_dive_access_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_dive_access_fkey FOREIGN KEY (dive_access) REFERENCES public.event_categories(id);


--
-- Name: dive_sites dive_sites_kind_of_dive_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_kind_of_dive_fkey FOREIGN KEY (kind_of_dive) REFERENCES public.event_categories(id);


--
-- Name: dive_sites dive_sites_water_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_water_fkey FOREIGN KEY (water) REFERENCES public.event_categories(id);


--
-- Name: diver_levels diver_levels_certifying_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_certifying_entity_id_fkey FOREIGN KEY (certifying_entity_id) REFERENCES public.certifying_entities(id);


--
-- Name: diver_specialities diver_specialties_diver_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialties_diver_level_fkey FOREIGN KEY (diver_level) REFERENCES public.diver_levels(id);


--
-- Name: dives dives_id_site_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_id_site_fkey FOREIGN KEY (id_site) REFERENCES public.dive_sites(id);


--
-- Name: dives dives_min_level_required_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_min_level_required_fkey FOREIGN KEY (min_level_required) REFERENCES public.diver_levels(id);


--
-- Name: dives dives_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_status_fkey FOREIGN KEY (status) REFERENCES public.status_events(id);


--
-- Name: action_logs fk_action_logs_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT fk_action_logs_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: certification_equivalences fk_certification_category; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT fk_certification_category FOREIGN KEY (category_course_id) REFERENCES public.event_categories(id);


--
-- Name: certification_courses fk_certification_courses_type; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT fk_certification_courses_type FOREIGN KEY (course_type_id) REFERENCES public.event_categories(id);


--
-- Name: course_enrollments fk_course_enrollments_course; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT fk_course_enrollments_course FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_enrollments fk_course_enrollments_student; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT fk_course_enrollments_student FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dives fk_daylight; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT fk_daylight FOREIGN KEY (day_light_id) REFERENCES public.event_categories(id) ON DELETE SET NULL;


--
-- Name: deletions fk_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT fk_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: deletions fk_deleted_record; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT fk_deleted_record FOREIGN KEY (deleted_record) REFERENCES public.event_categories(id);


--
-- Name: dive_cancellations fk_dive_cancellations_canceled_by; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT fk_dive_cancellations_canceled_by FOREIGN KEY (canceled_by) REFERENCES public.users(id);


--
-- Name: dive_cancellations fk_dive_cancellations_reasons; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT fk_dive_cancellations_reasons FOREIGN KEY (reasons) REFERENCES public.event_categories(id);


--
-- Name: dive_registrations fk_dive_registrations_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT fk_dive_registrations_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dive_sites fk_dive_sites_country; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT fk_dive_sites_country FOREIGN KEY (country) REFERENCES public.country_codes(id);


--
-- Name: dives fk_dives_weather; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT fk_dives_weather FOREIGN KEY (weather_conditions) REFERENCES public.event_categories(id);


--
-- Name: action_logs fk_log_action; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT fk_log_action FOREIGN KEY (action_type) REFERENCES public.event_categories(id);


--
-- Name: master_tables_list fk_master_table_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.master_tables_list
    ADD CONSTRAINT fk_master_table_status FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: courses fk_payment; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT fk_payment FOREIGN KEY (payment) REFERENCES public.event_categories(id);


--
-- Name: reviews fk_reviews_user_id; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_reviews_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reviews fk_visibility; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_visibility FOREIGN KEY (visibility) REFERENCES public.event_categories(id);


--
-- Name: waitlist fk_waitlist_status; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT fk_waitlist_status FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: waitlist fk_waitlist_user; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT fk_waitlist_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: instructor_levels instructor_levels_certifying_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_certifying_entity_id_fkey FOREIGN KEY (certifying_entity_id) REFERENCES public.certifying_entities(id);


--
-- Name: reviews reviews_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: speciality_courses speciality_courses_speciality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_speciality_id_fkey FOREIGN KEY (speciality_id) REFERENCES public.diver_specialities(id);


--
-- Name: users users_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: users users_country_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_country_fkey FOREIGN KEY (country) REFERENCES public.country_codes(id);


--
-- Name: users users_diver_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_diver_type_fkey FOREIGN KEY (diver_type) REFERENCES public.event_categories(id);


--
-- Name: users users_diving_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_diving_level_fkey FOREIGN KEY (diving_level) REFERENCES public.diver_levels(id);


--
-- Name: users users_gender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_gender_fkey FOREIGN KEY (gender) REFERENCES public.event_categories(id);


--
-- Name: users users_instructor_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_instructor_level_fkey FOREIGN KEY (instructor_level) REFERENCES public.instructor_levels(id);


--
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.event_categories(id);


--
-- Name: users users_size_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_size_fkey FOREIGN KEY (size) REFERENCES public.event_categories(id);


--
-- Name: waitlist waitlist_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: track_table_deletion; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER track_table_deletion ON ddl_command_end
         WHEN TAG IN ('DROP TABLE')
   EXECUTE FUNCTION public.log_table_deletion();

ALTER EVENT TRIGGER track_table_deletion DISABLE;


--
-- Name: trg_log_new_table; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER trg_log_new_table ON ddl_command_end
         WHEN TAG IN ('CREATE TABLE')
   EXECUTE FUNCTION public.log_new_table();


--
-- Name: trg_mark_deleted; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER trg_mark_deleted ON sql_drop
         WHEN TAG IN ('DROP TABLE')
   EXECUTE FUNCTION public.mark_table_as_deleted();

ALTER EVENT TRIGGER trg_mark_deleted DISABLE;


--
-- Name: trg_mark_table_as_deleted; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER trg_mark_table_as_deleted ON sql_drop
   EXECUTE FUNCTION public.mark_table_as_deleted();


--
-- PostgreSQL database dump complete
--

