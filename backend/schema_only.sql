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

