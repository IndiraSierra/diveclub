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
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: auto_set_geo_location(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.auto_set_geo_location() OWNER TO indira_sierra;

--
-- Name: generate_dive_code(integer, date); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.generate_dive_code(site_id integer, dive_date date) OWNER TO indira_sierra;

--
-- Name: generate_log_code(integer, text, integer); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.generate_log_code(p_user_id integer, p_table text, p_target_id integer) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'LOG-' || p_user_id || '-' || UPPER(p_table) || '-' || p_target_id || '-' || TO_CHAR(NOW(), 'YYYYMMDDHH24MI');
END;
$$;


ALTER FUNCTION public.generate_log_code(p_user_id integer, p_table text, p_target_id integer) OWNER TO indira_sierra;

--
-- Name: generate_review_code(integer, integer, date); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.generate_review_code(user_id integer, dive_id integer, review_date date) RETURNS text
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN 'REW-' || user_id || '-' || dive_id || '-' || TO_CHAR(review_date, 'YYYYMMDD');
END;
$$;


ALTER FUNCTION public.generate_review_code(user_id integer, dive_id integer, review_date date) OWNER TO indira_sierra;

--
-- Name: generate_site_code(text); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.generate_site_code(region_name text) OWNER TO indira_sierra;

--
-- Name: generate_user_code(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.generate_user_code() OWNER TO indira_sierra;

--
-- Name: generate_waitlist_code(integer, integer); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.generate_waitlist_code(user_id integer, dive_id integer) OWNER TO indira_sierra;

--
-- Name: log_action(integer, integer, text, integer, text, text); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.log_action(p_user_id integer, p_action_type integer, p_target_table text, p_target_id integer, p_description text DEFAULT NULL::text, p_ip text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_code TEXT;
BEGIN
    v_code := generate_log_code(p_user_id, p_target_table, p_target_id);

    INSERT INTO action_logs (
        user_id,
        action_type,
        target_table,
        target_id,
        action_date,
        description,
        ip_address,
        code
    ) VALUES (
        p_user_id,
        p_action_type,
        p_target_table,
        p_target_id,
        NOW(),
        p_description,
        p_ip,
        v_code
    );
END;
$$;


ALTER FUNCTION public.log_action(p_user_id integer, p_action_type integer, p_target_table text, p_target_id integer, p_description text, p_ip text) OWNER TO indira_sierra;

--
-- Name: log_new_table(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.log_new_table() OWNER TO indira_sierra;

--
-- Name: log_table_creation(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.log_table_creation() OWNER TO postgres;

--
-- Name: log_table_deletion(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.log_table_deletion() OWNER TO indira_sierra;

--
-- Name: mark_table_as_deleted(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.mark_table_as_deleted() OWNER TO indira_sierra;

--
-- Name: normalize_user_levels_by_type(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.normalize_user_levels_by_type() OWNER TO indira_sierra;

--
-- Name: promote_waitlisted_user(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.promote_waitlisted_user() OWNER TO indira_sierra;

--
-- Name: set_defaults_on_insert_master_table(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_defaults_on_insert_master_table() OWNER TO indira_sierra;

--
-- Name: set_defaults_on_update_master_table(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_defaults_on_update_master_table() OWNER TO indira_sierra;

--
-- Name: set_dive_code(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_dive_code() OWNER TO indira_sierra;

--
-- Name: set_review_code(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_review_code() OWNER TO indira_sierra;

--
-- Name: set_site_code(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_site_code() OWNER TO indira_sierra;

--
-- Name: set_waitlist_code(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.set_waitlist_code() OWNER TO indira_sierra;

--
-- Name: trg_check_event_status(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_check_event_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    PERFORM update_all_event_statuses();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trg_check_event_status() OWNER TO indira_sierra;

--
-- Name: trg_enforce_exclusive_levels(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.trg_enforce_exclusive_levels() OWNER TO indira_sierra;

--
-- Name: trg_log_certification_courses_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_certification_courses_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.created_by, OLD.created_by); -- Debe existir esta columna
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_courses', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_courses', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_courses', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_certification_courses_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_certification_equivalences_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_certification_equivalences_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.created_by, OLD.created_by); -- Asegúrate de que este campo existe
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_equivalences', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_equivalences', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'certification_equivalences', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_certification_equivalences_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_course_enrollments_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_course_enrollments_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.student_id, OLD.student_id);
    v_target_id INT := COALESCE(NEW.course_id, OLD.course_id);
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'course_enrollments', v_target_id);
    
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'course_enrollments', v_target_id);
    
    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'course_enrollments', v_target_id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_course_enrollments_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_courses_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_courses_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := NEW.instructor_id;  -- quien crea o edita el curso
    v_action_type INT;
    v_target_id INT := COALESCE(NEW.id, OLD.id);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'courses', v_target_id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'courses', v_target_id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'courses', v_target_id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_courses_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_deletions_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_deletions_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_action_type INT;
BEGIN
    SELECT id INTO v_action_type
    FROM event_categories
    WHERE category_name = 'Log Action' AND value_name = 'DELETE'
    LIMIT 1;

    PERFORM log_action(
        NEW.deleted_by,
        v_action_type,
        NEW.deleted_table,
        NEW.deleted_id,
        'Registro marcado como eliminado.',
        NULL
    );

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_deletions_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_dive_cancellations_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_dive_cancellations_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := NEW.canceled_by; -- o OLD si es DELETE
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_cancellations', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_cancellations', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(OLD.canceled_by, v_action_type, 'dive_cancellations', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_dive_cancellations_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_dive_registrations_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_dive_registrations_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_action_type INT;
    v_user_id INT := COALESCE(NEW.user_id, OLD.user_id);
    v_target_id INT := COALESCE(NEW.id, OLD.id);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'ENROLLMENT' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_registrations', v_target_id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_registrations', v_target_id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_dive_registrations_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_dive_sites_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_dive_sites_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.created_by, OLD.created_by); -- Suponemos que esta columna existe
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_sites', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_sites', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dive_sites', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_dive_sites_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_dives_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_dives_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := NEW.created_by; -- o la columna correspondiente
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dives', NEW.id);
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dives', NEW.id);
    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'dives', OLD.id);
    END IF;
    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_dives_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_reviews_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_reviews_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := NEW.user_id; -- o OLD en DELETE
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'reviews', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'reviews', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type 
        FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(OLD.user_id, v_action_type, 'reviews', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_reviews_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_speciality_courses_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_speciality_courses_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.created_by, OLD.created_by); -- Debe existir esta columna en la tabla
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'speciality_courses', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'speciality_courses', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'speciality_courses', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_speciality_courses_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_users_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_users_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.id, OLD.id); -- El usuario es el propio objeto de la acción
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'users', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'users', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'users', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_users_activity() OWNER TO indira_sierra;

--
-- Name: trg_log_waitlist_activity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
--

CREATE FUNCTION public.trg_log_waitlist_activity() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_user_id INT := COALESCE(NEW.user_id, OLD.user_id);
    v_action_type INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'CREATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'waitlist', NEW.id);

    ELSIF TG_OP = 'UPDATE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'UPDATE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'waitlist', NEW.id);

    ELSIF TG_OP = 'DELETE' THEN
        SELECT id INTO v_action_type FROM event_categories 
        WHERE category_name = 'Log Action' AND value_name = 'DELETE' LIMIT 1;

        PERFORM log_action(v_user_id, v_action_type, 'waitlist', OLD.id);
    END IF;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.trg_log_waitlist_activity() OWNER TO indira_sierra;

--
-- Name: update_all_event_statuses(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.update_all_event_statuses() OWNER TO indira_sierra;

--
-- Name: update_course_status(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.update_course_status() OWNER TO indira_sierra;

--
-- Name: update_dive_status(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.update_dive_status() OWNER TO indira_sierra;

--
-- Name: update_geo_location(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.update_geo_location() OWNER TO indira_sierra;

--
-- Name: update_waitlist_count(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.update_waitlist_count() OWNER TO indira_sierra;

--
-- Name: validate_certification_entity(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.validate_certification_entity() OWNER TO indira_sierra;

--
-- Name: validate_course_requirements(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.validate_course_requirements() OWNER TO indira_sierra;

--
-- Name: validate_diver_type_levels(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.validate_diver_type_levels() OWNER TO indira_sierra;

--
-- Name: validate_user_uniqueness(); Type: FUNCTION; Schema: public; Owner: indira_sierra
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


ALTER FUNCTION public.validate_user_uniqueness() OWNER TO indira_sierra;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_logs; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.action_logs OWNER TO indira_sierra;

--
-- Name: COLUMN action_logs.user_id; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.user_id IS 'ID of the user who performed the action';


--
-- Name: COLUMN action_logs.action_type; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.action_type IS 'Type of action based on event_categories (Log Action)';


--
-- Name: COLUMN action_logs.target_table; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.target_table IS 'Name of the target table affected by the action';


--
-- Name: COLUMN action_logs.target_id; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.target_id IS 'ID of the affected record in the target table (optional)';


--
-- Name: COLUMN action_logs.action_date; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.action_date IS 'Timestamp when the action occurred';


--
-- Name: COLUMN action_logs.description; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.description IS 'Details or error message describing the event';


--
-- Name: COLUMN action_logs.ip_address; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.ip_address IS 'IP address from which the action originated';


--
-- Name: COLUMN action_logs.code; Type: COMMENT; Schema: public; Owner: indira_sierra
--

COMMENT ON COLUMN public.action_logs.code IS 'Unique code of the event (can refer to various entities)';


--
-- Name: action_logs_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.action_logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.action_logs_id_seq OWNER TO indira_sierra;

--
-- Name: action_logs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.action_logs_id_seq OWNED BY public.action_logs.id;


--
-- Name: certification_courses; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.certification_courses OWNER TO indira_sierra;

--
-- Name: certification_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.certification_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.certification_courses_id_seq OWNER TO indira_sierra;

--
-- Name: certification_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.certification_courses_id_seq OWNED BY public.certification_courses.id;


--
-- Name: certification_equivalences; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.certification_equivalences OWNER TO indira_sierra;

--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.certification_equivalences_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.certification_equivalences_id_seq OWNER TO indira_sierra;

--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.certification_equivalences_id_seq OWNED BY public.certification_equivalences.id;


--
-- Name: certifying_entities; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.certifying_entities (
    id integer NOT NULL,
    full_name character varying(100) NOT NULL,
    acronym character varying(20) NOT NULL,
    code character varying(30) NOT NULL,
    country_id integer NOT NULL
);


ALTER TABLE public.certifying_entities OWNER TO indira_sierra;

--
-- Name: certifying_entities_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.certifying_entities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.certifying_entities_id_seq OWNER TO indira_sierra;

--
-- Name: certifying_entities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.certifying_entities_id_seq OWNED BY public.certifying_entities.id;


--
-- Name: country_codes; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.country_codes (
    id integer NOT NULL,
    country_code character varying(2) NOT NULL,
    country_name character varying(50) NOT NULL,
    phone_code character varying(10) NOT NULL,
    active boolean DEFAULT true NOT NULL
);


ALTER TABLE public.country_codes OWNER TO indira_sierra;

--
-- Name: country_codes_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.country_codes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.country_codes_id_seq OWNER TO indira_sierra;

--
-- Name: country_codes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.country_codes_id_seq OWNED BY public.country_codes.id;


--
-- Name: course_enrollments; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.course_enrollments (
    id integer NOT NULL,
    course_id integer NOT NULL,
    student_id integer NOT NULL,
    enrollment_date timestamp without time zone NOT NULL,
    code character varying(30) NOT NULL,
    enrollment_status integer NOT NULL
);


ALTER TABLE public.course_enrollments OWNER TO indira_sierra;

--
-- Name: course_enrollments_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.course_enrollments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.course_enrollments_id_seq OWNER TO indira_sierra;

--
-- Name: course_enrollments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.course_enrollments_id_seq OWNED BY public.course_enrollments.id;


--
-- Name: courses; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.courses OWNER TO indira_sierra;

--
-- Name: courses_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.courses_id_seq OWNER TO indira_sierra;

--
-- Name: courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.courses_id_seq OWNED BY public.courses.id;


--
-- Name: deletions; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.deletions OWNER TO indira_sierra;

--
-- Name: deletions_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.deletions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.deletions_id_seq OWNER TO indira_sierra;

--
-- Name: deletions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.deletions_id_seq OWNED BY public.deletions.id;


--
-- Name: dive_cancellations; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.dive_cancellations OWNER TO indira_sierra;

--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.dive_cancellations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dive_cancellations_id_seq OWNER TO indira_sierra;

--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.dive_cancellations_id_seq OWNED BY public.dive_cancellations.id;


--
-- Name: dive_registrations; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.dive_registrations OWNER TO indira_sierra;

--
-- Name: dive_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.dive_registrations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dive_registrations_id_seq OWNER TO indira_sierra;

--
-- Name: dive_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.dive_registrations_id_seq OWNED BY public.dive_registrations.id;


--
-- Name: dive_sites; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.dive_sites OWNER TO indira_sierra;

--
-- Name: dive_sites_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.dive_sites_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dive_sites_id_seq OWNER TO indira_sierra;

--
-- Name: dive_sites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.dive_sites_id_seq OWNED BY public.dive_sites.id;


--
-- Name: diver_levels; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.diver_levels (
    id integer NOT NULL,
    certifying_entity_id integer NOT NULL,
    level character varying(20) NOT NULL,
    certification character varying(255) NOT NULL,
    code character varying(30) NOT NULL
);


ALTER TABLE public.diver_levels OWNER TO indira_sierra;

--
-- Name: diver_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.diver_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.diver_levels_id_seq OWNER TO indira_sierra;

--
-- Name: diver_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.diver_levels_id_seq OWNED BY public.diver_levels.id;


--
-- Name: diver_specialities; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.diver_specialities (
    id integer NOT NULL,
    diver_level integer NOT NULL,
    code character varying(30) NOT NULL,
    required boolean DEFAULT false NOT NULL,
    name character varying(100) NOT NULL
);


ALTER TABLE public.diver_specialities OWNER TO indira_sierra;

--
-- Name: diver_specialities_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.diver_specialities_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.diver_specialities_id_seq OWNER TO indira_sierra;

--
-- Name: diver_specialities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.diver_specialities_id_seq OWNED BY public.diver_specialities.id;


--
-- Name: dives; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.dives OWNER TO indira_sierra;

--
-- Name: dives_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.dives_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dives_id_seq OWNER TO indira_sierra;

--
-- Name: dives_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.dives_id_seq OWNED BY public.dives.id;


--
-- Name: event_categories; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.event_categories (
    id integer NOT NULL,
    category_name character varying(100) NOT NULL,
    value_name character varying(100) NOT NULL,
    description text
);


ALTER TABLE public.event_categories OWNER TO indira_sierra;

--
-- Name: event_categories_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.event_categories_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.event_categories_id_seq OWNER TO indira_sierra;

--
-- Name: event_categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.event_categories_id_seq OWNED BY public.event_categories.id;


--
-- Name: instructor_levels; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.instructor_levels (
    id integer NOT NULL,
    certifying_entity_id integer NOT NULL,
    level character varying(20) NOT NULL,
    certification character varying(255) NOT NULL,
    code character varying(30) NOT NULL
);


ALTER TABLE public.instructor_levels OWNER TO indira_sierra;

--
-- Name: instructor_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.instructor_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.instructor_levels_id_seq OWNER TO indira_sierra;

--
-- Name: instructor_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.instructor_levels_id_seq OWNED BY public.instructor_levels.id;


--
-- Name: master_tables_list; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.master_tables_list OWNER TO indira_sierra;

--
-- Name: master_tables_list_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.master_tables_list_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.master_tables_list_id_seq OWNER TO indira_sierra;

--
-- Name: master_tables_list_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.master_tables_list_id_seq OWNED BY public.master_tables_list.id;


--
-- Name: reviews; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.reviews OWNER TO indira_sierra;

--
-- Name: reviews_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.reviews_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reviews_id_seq OWNER TO indira_sierra;

--
-- Name: reviews_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.reviews_id_seq OWNED BY public.reviews.id;


--
-- Name: speciality_courses; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.speciality_courses OWNER TO indira_sierra;

--
-- Name: speciality_courses_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.speciality_courses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.speciality_courses_id_seq OWNER TO indira_sierra;

--
-- Name: speciality_courses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.speciality_courses_id_seq OWNED BY public.speciality_courses.id;


--
-- Name: status_events; Type: TABLE; Schema: public; Owner: indira_sierra
--

CREATE TABLE public.status_events (
    id integer NOT NULL,
    status character varying(20) NOT NULL,
    code character varying(30) NOT NULL
);


ALTER TABLE public.status_events OWNER TO indira_sierra;

--
-- Name: status_events_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.status_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.status_events_id_seq OWNER TO indira_sierra;

--
-- Name: status_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.status_events_id_seq OWNED BY public.status_events.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: indira_sierra
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
    insurance_policy character varying(50),
    registration_date timestamp without time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    total_dives integer DEFAULT 0 NOT NULL,
    credits integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.users OWNER TO indira_sierra;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO indira_sierra;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: waitlist; Type: TABLE; Schema: public; Owner: indira_sierra
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


ALTER TABLE public.waitlist OWNER TO indira_sierra;

--
-- Name: waitlist_id_seq; Type: SEQUENCE; Schema: public; Owner: indira_sierra
--

CREATE SEQUENCE public.waitlist_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.waitlist_id_seq OWNER TO indira_sierra;

--
-- Name: waitlist_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: indira_sierra
--

ALTER SEQUENCE public.waitlist_id_seq OWNED BY public.waitlist.id;


--
-- Name: action_logs id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.action_logs ALTER COLUMN id SET DEFAULT nextval('public.action_logs_id_seq'::regclass);


--
-- Name: certification_courses id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_courses ALTER COLUMN id SET DEFAULT nextval('public.certification_courses_id_seq'::regclass);


--
-- Name: certification_equivalences id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_equivalences ALTER COLUMN id SET DEFAULT nextval('public.certification_equivalences_id_seq'::regclass);


--
-- Name: certifying_entities id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certifying_entities ALTER COLUMN id SET DEFAULT nextval('public.certifying_entities_id_seq'::regclass);


--
-- Name: country_codes id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.country_codes ALTER COLUMN id SET DEFAULT nextval('public.country_codes_id_seq'::regclass);


--
-- Name: course_enrollments id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments ALTER COLUMN id SET DEFAULT nextval('public.course_enrollments_id_seq'::regclass);


--
-- Name: courses id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses ALTER COLUMN id SET DEFAULT nextval('public.courses_id_seq'::regclass);


--
-- Name: deletions id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions ALTER COLUMN id SET DEFAULT nextval('public.deletions_id_seq'::regclass);


--
-- Name: dive_cancellations id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations ALTER COLUMN id SET DEFAULT nextval('public.dive_cancellations_id_seq'::regclass);


--
-- Name: dive_registrations id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_registrations ALTER COLUMN id SET DEFAULT nextval('public.dive_registrations_id_seq'::regclass);


--
-- Name: dive_sites id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites ALTER COLUMN id SET DEFAULT nextval('public.dive_sites_id_seq'::regclass);


--
-- Name: diver_levels id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_levels ALTER COLUMN id SET DEFAULT nextval('public.diver_levels_id_seq'::regclass);


--
-- Name: diver_specialities id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_specialities ALTER COLUMN id SET DEFAULT nextval('public.diver_specialities_id_seq'::regclass);


--
-- Name: dives id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives ALTER COLUMN id SET DEFAULT nextval('public.dives_id_seq'::regclass);


--
-- Name: event_categories id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.event_categories ALTER COLUMN id SET DEFAULT nextval('public.event_categories_id_seq'::regclass);


--
-- Name: instructor_levels id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.instructor_levels ALTER COLUMN id SET DEFAULT nextval('public.instructor_levels_id_seq'::regclass);


--
-- Name: master_tables_list id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.master_tables_list ALTER COLUMN id SET DEFAULT nextval('public.master_tables_list_id_seq'::regclass);


--
-- Name: reviews id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews ALTER COLUMN id SET DEFAULT nextval('public.reviews_id_seq'::regclass);


--
-- Name: speciality_courses id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.speciality_courses ALTER COLUMN id SET DEFAULT nextval('public.speciality_courses_id_seq'::regclass);


--
-- Name: status_events id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.status_events ALTER COLUMN id SET DEFAULT nextval('public.status_events_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: waitlist id; Type: DEFAULT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist ALTER COLUMN id SET DEFAULT nextval('public.waitlist_id_seq'::regclass);


--
-- Data for Name: action_logs; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.action_logs (id, user_id, action_type, target_table, target_id, action_date, description, ip_address, code) FROM stdin;
\.


--
-- Data for Name: certification_courses; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type, course_type_id) FROM stdin;
0	CU-D-SYS00-00	No Certification Course	D-SYS00-00	0	diver level 0	Undefined	0
4	CU-D-FE34-GG	Group Guide Course	D-FE34-GG	1	diver level 3	Guide	67
16	CU-D-BS44-GG	1st Class Diver Course	D-BS44-GG	5	diver level 3	Guide	67
29	CU-D-GC34-03	Guardia Civil Diver Course	D-GC34-03	10	diver level 3	Guide	67
33	CU-D-FA34-GG1	Combat Diver Course	D-FA34-GG1	11	diver level 3	Guide	67
34	CU-D-FA34-GG2	Mine Diver Course	D-FA34-GG2	11	diver level 3	Guide	67
35	CU-D-FA34-GG3	Fitness GP Diver Course	D-FA34-GG3	11	diver level 3	Guide	67
36	CU-D-FA34-GG4	Assault Diver Course	D-FA34-GG4	11	diver level 3	Guide	67
37	CU-D-FA34-GG5	Amphibious Sapper Course	D-FA34-GG5	11	diver level 3	Guide	67
38	CU-D-FA34-GG6	Dive Technology Course	D-FA34-GG6	11	diver level 3	Guide	67
1	CU-D-FE34-01	1 Star Diver (B1E) Course	D-FE34-01	1	diver level 0	Diver	65
2	CU-D-FE34-02	2 Star Diver (B2E) Course	D-FE34-02	1	diver level 1	Diver	65
3	CU-D-FE34-03	3 Star Diver (B3E) Course	D-FE34-03	1	diver level 2	Diver	65
5	CU-D-CM33-01	CMAS 1 Star Diver Course	D-CM33-01	2	diver level 0	Diver	65
6	CU-D-CM33-02	CMAS 2 Star Diver Course	D-CM33-02	2	diver level 1	Diver	65
7	CU-D-CM33-03	CMAS 3 Star Diver Course	D-CM33-03	2	diver level 2	Diver	65
8	CU-D-PA01-01	Open Water Diver Course	D-PA01-01	3	diver level 0	Diver	65
9	CU-D-PA01-02	Rescue Diver Course	D-PA01-02	3	diver level 1	Diver	65
10	CU-D-PA01-03	Divemaster - Master Scuba Diver Course	D-PA01-03	3	diver level 2	Diver	65
11	CU-D-MA33-02	2nd Class Diver Course	D-MA34-02	4	diver level 0	Diver	65
12	CU-D-MA33-03	1st Class Diver Course	D-MA34-03	4	diver level 1	Diver	65
13	CU-D-BS44-01	Ocean Diver - Club Diver - Sport Diver Course	D-BS44-01	5	diver level 0	Diver	65
14	CU-D-BS44-02	Dive Leader Course	D-BS44-02	5	diver level 1	Diver	65
15	CU-D-BS44-03	Advanced Diver Course	D-BS44-03	5	diver level 2	Diver	65
17	CU-D-SS01-01	Open Water Diver Course	D-SS01-01	6	diver level 0	Diver	65
18	CU-D-SS01-02	Advanced Open Water Diver Course	D-SS01-02	6	diver level 1	Diver	65
19	CU-D-SS01-03	Divemaster - Master Diver - Diver Con. Course	D-SS01-03	6	diver level 3	Diver	65
20	CU-D-AC01-01	Open Water Diver Course	D-AC01-01	7	diver level 0	Diver	65
21	CU-D-AC01-02	Advanced Diver Course	D-AC01-02	7	diver level 1	Diver	65
22	CU-D-AC01-03	Divemaster - Master Diver Course	D-AC01-03	7	diver level 2	Diver	65
23	CU-D-NA01-01	Scuba Diver Course	D-NA01-01	8	diver level 0	Diver	65
24	CU-D-NA01-02	Rescue Diver Course	D-NA01-02	8	diver level 1	Diver	65
25	CU-D-NA01-03	Master Scuba Diver Course	D-NA01-03	8	diver level 2	Diver	65
26	CU-D-PD01-01	Starter Course	D-PD01-01	9	diver level 0	Diver	65
27	CU-D-PD01-02	2nd Restricted Course	D-PD01-02	9	diver level 1	Diver	65
28	CU-D-PD01-03	2nd Professional Course	D-PD01-03	9	diver level 2	Diver	65
30	CU-D-FA34-01	Scientific Diver Course	D-FA34-01	11	diver level 0	Diver	65
31	CU-D-FA34-02	Support Diver Course	D-FA34-02	11	diver level 1	Diver	65
32	CU-D-FA34-03	Elementary Diver Course	D-FA34-03	11	diver level 2	Diver	65
40	CU-I-FE34-01	1 Star Intructor Course	I-FE34-01	1	diver level 3	Instructor	66
41	CU-I_FE34-02	2 Star Instructor Course	I-FE34-02	1	instructor level 1	Instructor	66
42	CU-I_FE34-03	3 Star Instructor Course	I-FE34-03	1	instructor level 2	Instructor	66
43	CU-I-BS44-02	Open Water Instructor Course	I-BS44-00	5	diver level 3	Instructor	66
44	CU-I-PA01-02	Open Water Instructor Course	I-PA01-02	3	diver level 3	Instructor	66
45	CU-I-SS01-02	Open Water Instructor Course	I-SS01-02	6	diver level 3	Instructor	66
46	CU-I-AC01-02	Open Water Instructor Course	I-AC01-02	7	diver level 3	Instructor	66
47	CU-I-NA01-02	Scuba Instructor Course	I-NA01-02	8	diver level 3	Instructor	66
39	CU-D-FA34-GG7	Dive Speciality Course	D-FA34-GG7	11	diver level 3	Guide	67
\.


--
-- Data for Name: certification_equivalences; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.certification_equivalences (id, certifying_entity, category, level, name, level_code, category_course_id) FROM stdin;
5	1	instructor	Level 1	1 Star Instructor	I-FE34-01	66
6	1	instructor	Level 2	2 Star Instructor	I-FE34-02	66
7	1	instructor	Level 3	3 Star Instructor	I-FE34-03	66
11	2	instructor	Level 1	1 Star Instructor	I-CM33-01	66
12	2	instructor	Level 2	2 Star Instructor	I-CM33-02	66
13	2	instructor	Level 3	3 Star Instructor	I-CM33-03	66
17	3	instructor	Level 2	Open Water Instructor	I-PA01-02	66
24	5	instructor	Level 2	Open Water Instructor	I-BS44-02	66
28	6	instructor	Level 2	Open Water Instructor	I-SS01-02	66
32	7	instructor	Level 2	Open Water Instructor	I-AC01-02	66
36	8	instructor	Level 2	Scuba Instructor	I-NA01-02	66
1	1	diver	Level 1	1 Star Diver (B1E)	D-FE34-01	65
2	1	diver	Level 2	2 Star Diver (B2E)	D-FE34-02	65
3	1	diver	Level 3	3 Star Diver (B3E)	D-FE34-03	65
4	1	diver	Guide	Group Guide	D-FE34-GG	65
8	2	diver	Level 1	CMAS 1 Star Diver	D-CM33-01	65
9	2	diver	Level 2	CMAS 2 Star Diver	D-CM33-02	65
10	2	diver	Level 3	CMAS 3 Star Diver	D-CM33-03	65
14	3	diver	Level 1	Open Water Diver	D-PA01-01	65
15	3	diver	Level 2	Rescue Diver	D-PA01-02	65
16	3	diver	Level 3	Divemaster - Master Scuba Diver	D-PA01-03	65
18	4	diver	Level 2	2nd Class Diver	D-MA34-02	65
19	4	diver	Level 3	1st Class Diver	D-MA34-03	65
20	5	diver	Level 1	Ocean Diver - Club Diver - Sport Diver	D-BS44-01	65
21	5	diver	Level 2	Dive Leader	D-BS44-02	65
22	5	diver	Level 3	Advanced Diver	D-BS44-03	65
23	5	diver	Guide	1st Class Diver	D-BS44-GG	65
25	6	diver	Level 1	Open Water Diver	D-SS01-01	65
26	6	diver	Level 2	Advanced Open Water Diver	D-SS01-02	65
27	6	diver	Level 3	Divemaster - Master Diver - Diver Con.	D-SS01-03	65
29	7	diver	Level 1	Open Water Diver	D-AC01-01	65
30	7	diver	Level 2	Advanced Diver	D-AC01-02	65
31	7	diver	Level 3	Divemaster - Master Diver	D-AC01-03	65
33	8	diver	Level 1	Scuba Diver	D-NA01-01	65
34	8	diver	Level 2	Rescue Diver	D-NA01-02	65
35	8	diver	Level 3	Master Scuba Diver	D-NA01-03	65
37	9	diver	Level 1	Starter	D-PD01-01	65
38	9	diver	Level 2	2nd Restricted	D-PD01-02	65
39	9	diver	Level 3	2nd Professional	D-PD01-03	65
40	10	diver	Level 3	Guardia Civil Diver	D-GC34-03	65
41	11	diver	Level 1	Scientific Diver	D-FA34-01	65
42	11	diver	Level 2	Support Diver	D-FA34-02	65
43	11	diver	Level 3	Elementary Diver	D-FA34-03	65
44	11	diver	Guide	Combat Diver	D-FA34-GG1	65
45	11	diver	Guide	Mine Diver	D-FA34-GG2	65
46	11	diver	Guide	Fitness GP Diver	D-FA34-GG3	65
47	11	diver	Guide	Assault Diver	D-FA34-GG4	65
48	11	diver	Guide	Amphibious Sapper	D-FA34-GG5	65
49	11	diver	Guide	Dive Technology	D-FA34-GG6	65
50	11	diver	Guide	Dive Speciality	D-FA34-GG7	65
51	0	diver	level 0	No Certification / Entry Level	D-NONE-00	65
\.


--
-- Data for Name: certifying_entities; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.certifying_entities (id, full_name, acronym, code, country_id) FROM stdin;
9	Professional Dive	PROFESSIONAL DIVE	PD01	0
0	System	SYS	SYS00	0
1	Federación Española de Actividades Subacuáticas	FEDAS	FE34	58
4	Mediterranean Aquatic Professions Association	MAPA	MA34	58
11	EMB Fuerzas Armadas Ejército Español	ARMADA	FA34	58
10	GEAS Guardia Civil	GUARDIA CIVIL	GC34	58
2	Confédération Mondiale des Activités Subaquatiques	CMAS	CM33	65
3	Professional Association of Diving Instructors	PADI	PA01	59
8	National Association of Underwater Instructors	NAUI	NA01	59
5	British Sub-Aqua Club	BSAC	BS44	143
6	Scuba Schools International	SSI	SS01	3
7	American and Canadian Underwater Certifications	ACUC	AC01	34
\.


--
-- Data for Name: country_codes; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.country_codes (id, country_code, country_name, phone_code, active) FROM stdin;
1	AF	Afghanistan	+93	t
2	AL	Albania	+355	t
3	DE	Germany	+49	t
4	AD	Andorra	+376	t
5	AO	Angola	+244	t
6	AG	Antigua and Barbuda	+1268	t
7	SA	Saudi Arabia	+966	t
8	DZ	Algeria	+213	t
9	AR	Argentina	+54	t
10	AM	Armenia	+374	t
11	AU	Australia	+61	t
12	AT	Austria	+43	t
13	AZ	Azerbaijan	+994	t
14	BS	Bahamas	+1242	t
15	BD	Bangladesh	+880	t
16	BB	Barbados	+1246	t
17	BH	Bahrain	+973	t
18	BE	Belgium	+32	t
19	BZ	Belize	+501	t
20	BJ	Benin	+229	t
21	BT	Bhutan	+975	t
22	BY	Belarus	+375	t
23	BO	Bolivia	+591	t
24	BA	Bosnia and Herzegovina	+387	t
25	BW	Botswana	+267	t
26	BR	Brazil	+55	t
27	BN	Brunei	+673	t
28	BG	Bulgaria	+359	t
29	BF	Burkina Faso	+226	t
30	BI	Burundi	+257	t
31	CV	Cabo Verde	+238	t
32	KH	Cambodia	+855	t
33	CM	Cameroon	+237	t
34	CA	Canada	+1	t
35	QA	Qatar	+974	t
36	TD	Chad	+235	t
37	CL	Chile	+56	t
38	CN	China	+86	t
39	CY	Cyprus	+357	t
40	VA	Vatican City	+379	t
41	CO	Colombia	+57	t
42	KM	Comoros	+269	t
43	KP	North Korea	+850	t
44	KR	South Korea	+82	t
45	CI	Ivory Coast	+225	t
46	CR	Costa Rica	+506	t
47	HR	Croatia	+385	t
48	CU	Cuba	+53	t
49	DK	Denmark	+45	t
50	DM	Dominica	+1767	t
51	EC	Ecuador	+593	t
52	EG	Egypt	+20	t
53	SV	El Salvador	+503	t
54	AE	United Arab Emirates	+971	t
55	ER	Eritrea	+291	t
56	SK	Slovakia	+421	t
57	SI	Slovenia	+386	t
58	ES	Spain	+34	t
59	US	United States	+1	t
60	EE	Estonia	+372	t
61	ET	Ethiopia	+251	t
62	FJ	Fiji	+679	t
63	PH	Philippines	+63	t
64	FI	Finland	+358	t
65	FR	France	+33	t
66	GA	Gabon	+241	t
67	GM	Gambia	+220	t
68	GE	Georgia	+995	t
69	GH	Ghana	+233	t
70	GD	Grenada	+1473	t
71	GR	Greece	+30	t
72	GT	Guatemala	+502	t
73	GN	Guinea	+224	t
74	GQ	Equatorial Guinea	+240	t
75	GW	Guinea-Bissau	+245	t
76	GY	Guyana	+592	t
77	HT	Haiti	+509	t
78	HN	Honduras	+504	t
79	HU	Hungary	+36	t
80	IN	India	+91	t
81	ID	Indonesia	+62	t
82	IQ	Iraq	+964	t
83	IR	Iran	+98	t
84	IE	Ireland	+353	t
85	IS	Iceland	+354	t
86	MH	Marshall Islands	+692	t
87	SB	Solomon Islands	+677	t
88	IL	Israel	+972	t
89	IT	Italy	+39	t
90	JM	Jamaica	+1876	t
91	JP	Japan	+81	t
92	JO	Jordan	+962	t
93	KZ	Kazakhstan	+7	t
94	KE	Kenya	+254	t
95	KG	Kyrgyzstan	+996	t
96	KI	Kiribati	+686	t
97	KW	Kuwait	+965	t
98	LA	Laos	+856	t
99	LS	Lesotho	+266	t
100	LV	Latvia	+371	t
101	LB	Lebanon	+961	t
102	LR	Liberia	+231	t
103	LY	Libya	+218	t
104	LI	Liechtenstein	+423	t
105	LT	Lithuania	+370	t
106	LU	Luxembourg	+352	t
107	MK	North Macedonia	+389	t
108	MG	Madagascar	+261	t
109	MY	Malaysia	+60	t
110	MW	Malawi	+265	t
111	MV	Maldives	+960	t
112	ML	Mali	+223	t
113	MT	Malta	+356	t
114	MA	Morocco	+212	t
115	MU	Mauritius	+230	t
116	MR	Mauritania	+222	t
117	MX	Mexico	+52	t
118	FM	Micronesia	+691	t
119	MD	Moldova	+373	t
120	MC	Monaco	+377	t
121	MN	Mongolia	+976	t
122	ME	Montenegro	+382	t
123	MZ	Mozambique	+258	t
124	MM	Myanmar	+95	t
125	NA	Namibia	+264	t
126	NR	Nauru	+674	t
127	NP	Nepal	+977	t
128	NI	Nicaragua	+505	t
129	NE	Niger	+227	t
130	NG	Nigeria	+234	t
131	NO	Norway	+47	t
132	NZ	New Zealand	+64	t
133	OM	Oman	+968	t
134	NL	Netherlands	+31	t
135	PK	Pakistan	+92	t
136	PW	Palau	+680	t
137	PA	Panama	+507	t
138	PG	Papua New Guinea	+675	t
139	PY	Paraguay	+595	t
140	PE	Peru	+51	t
141	PL	Poland	+48	t
142	PT	Portugal	+351	t
143	GB	United Kingdom	+44	t
144	CF	Central African Republic	+236	t
145	CZ	Czech Republic	+420	t
146	CD	Democratic Republic of the Congo	+243	t
147	DO	Dominican Republic	+1809	t
148	CG	Republic of the Congo	+242	t
149	RO	Romania	+40	t
150	RW	Rwanda	+250	t
151	RU	Russia	+7	t
152	WS	Samoa	+685	t
153	KN	Saint Kitts and Nevis	+1869	t
154	SM	San Marino	+378	t
155	VC	Saint Vincent and the Grenadines	+1784	t
156	LC	Saint Lucia	+1758	t
157	ST	Sao Tome and Principe	+239	t
158	SN	Senegal	+221	t
159	RS	Serbia	+381	t
160	SC	Seychelles	+248	t
161	SL	Sierra Leone	+232	t
162	SG	Singapore	+65	t
163	SY	Syria	+963	t
164	SO	Somalia	+252	t
165	LK	Sri Lanka	+94	t
166	SZ	Eswatini	+268	t
167	ZA	South Africa	+27	t
168	SD	Sudan	+249	t
169	SS	South Sudan	+211	t
170	SE	Sweden	+46	t
171	CH	Switzerland	+41	t
172	SR	Suriname	+597	t
173	TH	Thailand	+66	t
174	TW	Taiwan	+886	t
175	TZ	Tanzania	+255	t
176	TJ	Tajikistan	+992	t
177	TL	East Timor	+670	t
178	TG	Togo	+228	t
179	TO	Tonga	+676	t
180	TT	Trinidad and Tobago	+1868	t
181	TN	Tunisia	+216	t
182	TM	Turkmenistan	+993	t
183	TR	Turkey	+90	t
184	TV	Tuvalu	+688	t
185	UA	Ukraine	+380	t
186	UG	Uganda	+256	t
187	UY	Uruguay	+598	t
188	UZ	Uzbekistan	+998	t
189	VU	Vanuatu	+678	t
190	VE	Venezuela	+58	t
191	VN	Vietnam	+84	t
192	YE	Yemen	+967	t
193	DJ	Djibouti	+253	t
194	ZM	Zambia	+260	t
195	ZW	Zimbabwe	+263	t
0	II	International	+00	f
\.


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.course_enrollments (id, course_id, student_id, enrollment_date, code, enrollment_status) FROM stdin;
\.


--
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.courses (id, course_id, location, duration, start_date, end_date, instructor_id, num_practices, organizing_club, price, payment, status, speciality_course_id, created_at, max_students) FROM stdin;
\.


--
-- Data for Name: deletions; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.deletions (id, log_id, deleted_record, deleted_id, deleted_by, deletion_date, code) FROM stdin;
\.


--
-- Data for Name: dive_cancellations; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.dive_cancellations (id, dive_id, status_id, canceled_by, date, information, code, reasons) FROM stdin;
\.


--
-- Data for Name: dive_registrations; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.dive_registrations (id, user_id, dive_id, registration_date, attendants, waitlist, code) FROM stdin;
\.


--
-- Data for Name: dive_sites; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.dive_sites (id, name, location, latitude, longitude, geo_location, depth, region, country, code, water, kind_of_dive, dive_access) FROM stdin;
1	Muelle Don Luis	Paseo de Ocharam Masas, Castro Urdiales	43.386944	-3.218333	0101000020E6100000BD19355F25BF09C014B1886187B14540	12	Cantabria	58	ST-CAN-001	13	15	22
3	El Pedregal	Playa El Pedregal, Castro Urdiales	43.381389	-3.225278	0101000020E6100000F910548D5ECD09C0EE06D15AD1B04540	8	Cantabria	58	ST-CAN-002	13	15	20
5	Cañones Napoleónicos	Acantilado de la Iglesia, Castro Urdiales	43.388611	-3.215278	0101000020E6100000E5620CACE3B809C0D4EE5701BEB14540	15	Cantabria	58	ST-CAN-003	13	16	21
6	Pecio Bajo Vitruvio	Bahía de Laredo	43.411389	-3.191667	0101000020E61000008AC745B5888809C092770E65A8B44540	22	Cantabria	58	ST-CAN-004	13	16	21
7	Bajo San Carlos	Reserva de Santoña	43.441667	-3.456944	0101000020E6100000D0D38041D2A70BC0795C548B88B84540	16	Cantabria	58	ST-CAN-005	13	15	21
8	Pecio Baldur	Saltacaballos	43.401389	-3.191667	0101000020E61000008AC745B5888809C0B1FCF9B660B34540	32	Cantabria	58	ST-CAN-006	13	16	21
9	Grúa Portuaria	Exterior Puerto Bilbao	43.346111	-3.033889	0101000020E61000009B8D9598674508C097E4805D4DAC4540	15	Vizcaya	58	ST-VIZ-001	13	16	21
10	Pecio Diana	Abra del Nervión	43.350000	-3.030000	0101000020E61000003D0AD7A3703D08C0CDCCCCCCCCAC4540	30	Vizcaya	58	ST-VIZ-002	13	16	21
11	Bajo Culebras	Azkorri, Sopelana	43.380278	-2.992222	0101000020E610000044F9821612F007C0B3B112F3ACB04540	30	Vizcaya	58	ST-VIZ-003	13	15	21
12	Bajo de los Chipirones	Sopelana	43.378611	-2.988889	0101000020E61000003FFED2A23EE907C0F373435376B04540	25	Vizcaya	58	ST-VIZ-004	13	15	21
13	Pecio Mina Mary	Bermeo	43.420833	-2.721667	0101000020E6100000C8D11C59F9C505C0EE0912DBDDB54540	38	Vizcaya	58	ST-VIZ-005	13	16	21
15	Pecio Mari Puri	Plentzia	43.405000	-2.950000	0101000020E61000009A999999999907C0A4703D0AD7B34540	26	Vizcaya	58	ST-VIZ-006	13	16	21
16	Arco de Ogoño	Bermeo	43.453056	-2.745833	0101000020E61000007638BA4A77F705C0D7A02FBDFDB94540	18	Vizcaya	58	ST-VIZ-007	13	17	21
18	Túnel de Otzarreta	Elantxobe	43.403611	-2.638056	0101000020E6100000F321A81ABD1A05C026A77686A9B34540	12	Vizcaya	58	ST-VIZ-008	13	17	21
19	La Boya	Desembocadura de Mundaka	43.406944	-2.698611	0101000020E6100000C1012D5DC19605C0D7A6B1BD16B44540	15	Vizcaya	58	ST-VIZ-009	13	19	21
\.


--
-- Data for Name: diver_levels; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.diver_levels (id, certifying_entity_id, level, certification, code) FROM stdin;
1	1	Level 1	1 Star Diver (B1E)	D-FE34-01
2	1	Level 2	2 Star Diver (B2E)	D-FE34-02
3	1	Level 3	3 Star Diver (B3E)	D-FE34-03
4	1	Guide	Group Guide	D-FE34-GG
5	2	Level 1	CMAS 1 Star Diver	D-CM33-01
6	2	Level 2	CMAS 2 Star Diver	D-CM33-02
7	2	Level 3	CMAS 3 Star Diver	D-CM33-03
8	3	Level 1	Open Water Diver	D-PA01-01
9	3	Level 2	Rescue Diver	D-PA01-02
10	3	Level 3	Divemaster - Master Scuba Diver	D-PA01-03
11	4	Level 2	2nd Class Diver	D-MA34-02
12	4	Level 3	1st Class Diver	D-MA34-03
13	5	Level 1	Ocean Diver - Club Diver - Sport Diver	D-BS44-01
14	5	Level 2	Dive Leader	D-BS44-02
15	5	Level 3	Advanced Diver	D-BS44-03
16	5	Guide	1st Class Diver	D-BS44-GG
17	6	Level 1	Open Water Diver	D-SS01-01
18	6	Level 2	Advanced Open Water Diver	D-SS01-02
19	6	Level 3	Divemaster - Master Diver - Diver Con.	D-SS01-03
20	7	Level 1	Open Water Diver	D-AC01-01
21	7	Level 2	Advanced Diver	D-AC01-02
22	7	Level 3	Divemaster - Master Diver	D-AC01-03
23	8	Level 1	Scuba Diver	D-NA01-01
24	8	Level 2	Rescue Diver	D-NA01-02
25	8	Level 3	Master Scuba Diver	D-NA01-03
26	9	Level 1	Starter	D-PD01-01
27	9	Level 2	2nd Restricted	D-PD01-02
28	9	Level 3	2nd Professional	D-PD01-03
29	10	Level 3	Guardia Civil Diver	D-GC34-03
30	11	Level 1	Scientific Diver	D-FA34-01
31	11	Level 2	Support Diver	D-FA34-02
32	11	Level 3	Elementary Diver	D-FA34-03
33	11	Guide	Combat Diver	D-FA34-GG1
34	11	Guide	Mine Diver	D-FA34-GG2
35	11	Guide	Fitness GP Diver	D-FA34-GG3
36	11	Guide	Assault Diver	D-FA34-GG4
37	11	Guide	Amphibious Sapper	D-FA34-GG5
38	11	Guide	Dive Technology	D-FA34-GG6
39	11	Guide	Dive Speciality	D-FA34-GG7
0	0	level 0	No Certification / Entry Level	D-SYS00-00
\.


--
-- Data for Name: diver_specialities; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.diver_specialities (id, diver_level, code, required, name) FROM stdin;
1	1	BLS01	f	Basic Life Support (BLS)
2	1	OXAD01	f	Oxygen Administration
3	1	NDV01	f	Night Diving
4	1	NXDV01	f	Nitrox Diving
5	1	UWNAV01	f	Underwater Navigation
6	1	DSDV01	f	Dry Suit Diving
7	2	WRDV02	f	Wreck Diving
8	2	CRNDV02	f	Cavern Diving
9	2	ADDV02	f	Adaptive Diving
10	2	SRDV02	f	Search and Rescue Diving
11	2	CVDV02	f	Cave Diving (Introductory)
12	2	UIDV02	f	Under Ice Diving
13	3	FCVDV03	f	Full Cave Diving
14	3	TCHDV03	f	Technical Nitrox
15	3	NRTMX03	f	Normoxic Trimix
16	3	HPTMX03	f	Hypoxic Trimix
0	0	SYS00	f	System
\.


--
-- Data for Name: dives; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.dives (id, id_site, name, date, meeting_point, meeting_time, duration, planned_depth, dive_plan, practician_admited, min_level_required, max_divers, status, credits, description, code, day_light_id, weather_conditions) FROM stdin;
\.


--
-- Data for Name: event_categories; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.event_categories (id, category_name, value_name, description) FROM stdin;
1	Gender	Fem	\N
2	Gender	Masc	\N
3	Size	XS	\N
4	Size	S	\N
5	Size	M	\N
6	Size	L	\N
7	Size	XL	\N
8	Size	XXL	\N
9	Role	User	\N
10	Role	Admin	\N
11	Diver Type	Diver	\N
12	Diver Type	Instructor	\N
13	Water	Salt	\N
14	Water	Fresh	\N
15	Kind of Dive	Reef	\N
16	Kind of Dive	Wreck	\N
17	Kind of Dive	Cave	\N
18	Kind of Dive	Under Ice	\N
20	Dive Access	Shore	\N
21	Dive Access	Boat	\N
22	Dive Access	Pier	\N
23	Dive Access	Cave	\N
24	Daylight	Day Dive	\N
25	Daylight	Night Dive	\N
26	Weather	Cloudy	\N
27	Weather	Sunny	\N
28	Weather	Rainy	\N
29	Weather	Surge	\N
30	Weather	Windy	\N
31	Payment	Currency	\N
32	Payment	Credits	\N
33	Visibility	Bad (-3m)	\N
34	Visibility	Regular (3~5m)	\N
35	Visibility	Good (+5m)	\N
36	Visibility	Very Good (+10m)	\N
37	Visibility	Night Dive	\N
38	Cancellation Reason	Bad Weather	\N
39	Cancellation Reason	Close Access Road	\N
40	Cancellation Reason	Slack of Responsible Instructor	\N
41	Cancellation Reason	Not Enough Attendants	\N
42	Cancellation Reason	Unexpected Surge	\N
43	Cancellation Reason	Rain	\N
44	Cancellation Reason	Personal Reasons	\N
45	Log Action	CREATE	\N
46	Log Action	UPDATE	\N
47	Log Action	DELETE	\N
48	Log Action	LOGIN	\N
49	Log Action	LOGOUT	\N
50	Log Action	VIEW	\N
51	Log Action	FAILED_LOGIN	\N
52	Log Action	ENROLLMENT	\N
53	Log Action	PASSWORD_CHANGE	\N
54	Log Action	ATTEND	\N
55	Log Action	REVIEW	\N
56	Deleted Record	users	\N
57	Deleted Record	dives	\N
58	Deleted Record	dive_sites	\N
59	Deleted Record	courses	\N
60	Deleted Record	dive_registrations	\N
61	Deleted Record	course_enrollments	\N
62	Deleted Record	dive_cancellations	\N
63	Deleted Record	certification_courses	\N
64	Deleted Record	reviews	\N
65	Course Type	Diver	\N
66	Course Type	Instructor	\N
67	Course Type	Guide	\N
68	Course Type	Specialty	\N
0	Undefined	Undefined	\N
19	Kind of Dive	Drift	\N
\.


--
-- Data for Name: instructor_levels; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.instructor_levels (id, certifying_entity_id, level, certification, code) FROM stdin;
1	1	Level 1	1 Star Instructor	I-FE34-01
2	1	Level 2	2 Star Instructor	I-FE34-02
3	1	Level 3	3 Star Instructor	I-FE34-03
7	5	Level 2	Open Water Instructor	I-BS44-02
8	3	Level 2	Open Water Instructor	I-PA01-02
9	6	Level 2	Open Water Instructor	I-SS01-02
10	7	Level 2	Open Water Instructor	I-AC01-02
11	8	Level 2	Scuba Instructor	I-NA01-02
4	2	Level 1	CMAS 1 Star Instructor	I-CM33-01
5	2	Level 2	CMAS 2 Star Instructor	I-CM33-02
6	2	Level 3	CMAS 3 Star Instructor	I-CM33-03
0	0	level 0	Max Diving Level	I-SYS00-00
\.


--
-- Data for Name: master_tables_list; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.master_tables_list (id, schema_name, table_name, created_at, status_id, last_updated, notes, is_active, status_changed_at, deletion_reason) FROM stdin;
1	public	action_logs	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Registra acciones de usuarios para auditoría del sistema.	t	2025-05-10 13:33:39.30762	Table created
2	public	certification_courses	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Contiene los cursos oficiales de certificación para buceadores e instructores.	t	2025-05-10 13:33:39.30762	Table created
3	public	certification_equivalences	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Relación de equivalencias entre certificaciones de distintas entidades.	t	2025-05-10 13:33:39.30762	Table created
4	public	certifying_entities	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Listado de entidades certificadoras de buceo reconocidas.	t	2025-05-10 13:33:39.30762	Table created
5	public	course_enrollments	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Inscripciones de usuarios en cursos de buceo.	t	2025-05-10 13:33:39.30762	Table created
6	public	courses	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Cursos de buceo programados, con instructor, fechas y lugar.	t	2025-05-10 13:33:39.30762	Table created
7	public	deletions	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Historial de registros eliminados en el sistema.	t	2025-05-10 13:33:39.30762	Table created
8	public	dive_cancellations	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Cancelaciones de inmersiones y sus motivos.	t	2025-05-10 13:33:39.30762	Table created
9	public	dive_registrations	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Registro de buceadores en inmersiones programadas.	t	2025-05-10 13:33:39.30762	Table created
10	public	dive_sites	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Sitios de buceo con coordenadas, profundidad y tipo de inmersión.	t	2025-05-10 13:33:39.30762	Table created
11	public	diver_levels	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Niveles de certificación de buceadores.	t	2025-05-10 13:33:39.30762	Table created
13	public	dives	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Categorías de valores para enums reutilizables.	t	2025-05-10 13:33:39.30762	Table created
12	public	diver_specialities	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Inmersiones programadas con información logística.	t	2025-05-10 13:33:39.30762	Table created
14	public	event_categories	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Niveles de certificación de instructores.	t	2025-05-10 13:33:39.30762	Table created
15	public	instructor_levels	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Reseñas y comentarios de los usuarios sobre inmersiones.	t	2025-05-10 13:33:39.30762	Table created
16	public	reviews	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Sistema de referencia geoespacial (SRID 4326 y otros).	t	2025-05-10 13:33:39.30762	Table created
17	public	spatial_ref_sys	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Estados utilizados para eventos como inmersiones o cursos.	t	2025-05-10 13:33:39.30762	Table created
18	public	status_events	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Usuarios registrados en la aplicación.	t	2025-05-10 13:33:39.30762	Table created
19	public	users	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Lista de espera para inmersiones completas.	t	2025-05-10 13:33:39.30762	Table created
20	public	waitlist	2025-04-27 16:55:01.727141	2	2025-05-10 12:19:55.163599	Especialidades que puede obtener un buceador.	t	2025-05-10 13:33:39.30762	Table created
21	public	public.speciality_courses	2025-04-28 02:56:30.819801	2	2025-05-10 12:19:55.163599	Cursos asociados a especialidades de buceo.	t	2025-05-10 13:33:39.30762	Table created
22	public	public.country_codes	2025-05-07 12:59:51.05719	2	2025-05-10 12:19:55.163599	Listado de países con códigos y prefijos telefónicos.	t	2025-05-10 13:33:39.30762	Table created
23	public	public.users	2025-05-08 11:43:15.929329	2	2025-05-10 12:19:55.163599	Vista redundante o réplica de la tabla de usuarios.	t	2025-05-10 13:33:39.30762	Table created
\.


--
-- Data for Name: reviews; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.reviews (id, dive_id, user_id, review_date, visibility, water_temperature, surface_temperature, reached_depth, photos, comment, code) FROM stdin;
\.


--
-- Data for Name: spatial_ref_sys; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.spatial_ref_sys (srid, auth_name, auth_srid, srtext, proj4text) FROM stdin;
\.


--
-- Data for Name: speciality_courses; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.speciality_courses (id, speciality_id, code, name, certification, requirements, course_type) FROM stdin;
1	1	CU-BLS01	Basic Life Support (BLS) Course	BLS01	diver level 1	Diver
2	2	CU-OXAD01	Oxygen Administration Course	OXAD01	diver level 1	Diver
3	3	CU-NDV01	Night Diving Course	NDV01	diver level 1	Diver
4	4	CU-NXDV01	Nitrox Diving Course	NXDV01	diver level 1	Diver
5	5	CU-UWNAV01	Underwater Navigation Course	UWNAV01	diver level 1	Diver
6	6	CU-DSDV01	Dry Suit Diving Course	DSDV01	diver level 1	Diver
7	7	CU-WRDV02	Wreck Diving Course	WRDV02	diver level 2	Diver
8	8	CU-CRNDV02	Cavern Diving Course	CRNDV02	diver level 2	Diver
9	9	CU-ADDV02	Adaptive Diving Course	ADDV02	diver level 2	Diver
10	10	CU-SRDV02	Search and Rescue Diving Course	SRDV02	diver level 2	Diver
11	11	CU-CVDV02	Introductory Cave Diving Course	CVDV02	diver level 2	Diver
12	12	CU-UIDV02	Under Ice Diving Course	UIDV02	diver level 2	Diver
13	13	CU-FCVDV03	Full Cave Diving Course	FCVDV03	diver level 3	Diver
14	14	CU-TCHDV03	Technical Nitrox Course	TCHDV03	diver level 3	Diver
15	15	CU-NRTMX03	Normoxic Trimix Course	NRTMX03	diver level 3	Diver
16	16	CU-HPTMX03	Hypoxic Trimix Course	HPTMX03	diver level 3	Diver
0	0	CU-SYS00	No Speciality Course	SYS00	diver level 0	Undefined
\.


--
-- Data for Name: status_events; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.status_events (id, status, code) FROM stdin;
1	Next	ST01
2	Active	ST02
3	Full	ST03
4	Ongoing	ST04
5	Canceled	ST05
6	Finished	ST06
0	Undefined	ST00
7	Deleted	ST07
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.users (id, code, name, last_name, email, birth_date, country, phone, gender, weight, height, size, role, username, password, diver_type, certifying_entity, diving_level, instructor_level, federation_license, insurance, insurance_policy, registration_date, is_active, total_dives, credits) FROM stdin;
\.


--
-- Data for Name: waitlist; Type: TABLE DATA; Schema: public; Owner: indira_sierra
--

COPY public.waitlist (id, user_id, dive_id, code, notified, listed_date, status_id) FROM stdin;
\.


--
-- Name: action_logs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.action_logs_id_seq', 1, false);


--
-- Name: certification_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.certification_courses_id_seq', 47, true);


--
-- Name: certification_equivalences_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.certification_equivalences_id_seq', 51, true);


--
-- Name: certifying_entities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.certifying_entities_id_seq', 1, false);


--
-- Name: country_codes_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.country_codes_id_seq', 195, true);


--
-- Name: course_enrollments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.course_enrollments_id_seq', 1, false);


--
-- Name: courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.courses_id_seq', 1, false);


--
-- Name: deletions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.deletions_id_seq', 1, false);


--
-- Name: dive_cancellations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.dive_cancellations_id_seq', 1, false);


--
-- Name: dive_registrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.dive_registrations_id_seq', 1, false);


--
-- Name: dive_sites_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.dive_sites_id_seq', 19, true);


--
-- Name: diver_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.diver_levels_id_seq', 1, false);


--
-- Name: diver_specialities_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.diver_specialities_id_seq', 1, false);


--
-- Name: dives_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.dives_id_seq', 1, false);


--
-- Name: event_categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.event_categories_id_seq', 74, true);


--
-- Name: instructor_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.instructor_levels_id_seq', 1, false);


--
-- Name: master_tables_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.master_tables_list_id_seq', 23, true);


--
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.reviews_id_seq', 1, false);


--
-- Name: speciality_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.speciality_courses_id_seq', 17, true);


--
-- Name: status_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.status_events_id_seq', 6, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.users_id_seq', 1, false);


--
-- Name: waitlist_id_seq; Type: SEQUENCE SET; Schema: public; Owner: indira_sierra
--

SELECT pg_catalog.setval('public.waitlist_id_seq', 1, false);


--
-- Name: action_logs action_logs_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT action_logs_code_key UNIQUE (code);


--
-- Name: action_logs action_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT action_logs_pkey PRIMARY KEY (id);


--
-- Name: certification_courses certification_courses_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_code_key UNIQUE (code);


--
-- Name: certification_courses certification_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_pkey PRIMARY KEY (id);


--
-- Name: certification_equivalences certification_equivalences_level_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_level_code_key UNIQUE (level_code);


--
-- Name: certification_equivalences certification_equivalences_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_pkey PRIMARY KEY (id);


--
-- Name: certifying_entities certifying_entities_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_code_key UNIQUE (code);


--
-- Name: certifying_entities certifying_entities_full_name_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_full_name_key UNIQUE (full_name);


--
-- Name: certifying_entities certifying_entities_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_pkey PRIMARY KEY (id);


--
-- Name: country_codes country_codes_country_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_country_code_key UNIQUE (country_code);


--
-- Name: country_codes country_codes_country_name_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_country_name_key UNIQUE (country_name);


--
-- Name: country_codes country_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.country_codes
    ADD CONSTRAINT country_codes_pkey PRIMARY KEY (id);


--
-- Name: course_enrollments course_enrollments_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_code_key UNIQUE (code);


--
-- Name: course_enrollments course_enrollments_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_pkey PRIMARY KEY (id);


--
-- Name: courses courses_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_pkey PRIMARY KEY (id);


--
-- Name: deletions deletions_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_code_key UNIQUE (code);


--
-- Name: deletions deletions_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_pkey PRIMARY KEY (id);


--
-- Name: dive_cancellations dive_cancellations_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_code_key UNIQUE (code);


--
-- Name: dive_cancellations dive_cancellations_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_pkey PRIMARY KEY (id);


--
-- Name: dive_registrations dive_registrations_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_code_key UNIQUE (code);


--
-- Name: dive_registrations dive_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_pkey PRIMARY KEY (id);


--
-- Name: dive_sites dive_sites_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_code_key UNIQUE (code);


--
-- Name: dive_sites dive_sites_name_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_name_key UNIQUE (name);


--
-- Name: dive_sites dive_sites_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_pkey PRIMARY KEY (id);


--
-- Name: diver_levels diver_levels_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_code_key UNIQUE (code);


--
-- Name: diver_levels diver_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_pkey PRIMARY KEY (id);


--
-- Name: diver_specialities diver_specialities_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialities_code_key UNIQUE (code);


--
-- Name: diver_specialities diver_specialties_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialties_pkey PRIMARY KEY (id);


--
-- Name: dives dives_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_code_key UNIQUE (code);


--
-- Name: dives dives_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_pkey PRIMARY KEY (id);


--
-- Name: event_categories event_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT event_categories_pkey PRIMARY KEY (id);


--
-- Name: instructor_levels instructor_levels_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_code_key UNIQUE (code);


--
-- Name: instructor_levels instructor_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_pkey PRIMARY KEY (id);


--
-- Name: master_tables_list master_tables_list_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.master_tables_list
    ADD CONSTRAINT master_tables_list_pkey PRIMARY KEY (id);


--
-- Name: reviews reviews_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_code_key UNIQUE (code);


--
-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--
-- Name: speciality_courses speciality_courses_certification_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_certification_key UNIQUE (certification);


--
-- Name: speciality_courses speciality_courses_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_code_key UNIQUE (code);


--
-- Name: speciality_courses speciality_courses_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_pkey PRIMARY KEY (id);


--
-- Name: status_events status_events_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_code_key UNIQUE (code);


--
-- Name: status_events status_events_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_pkey PRIMARY KEY (id);


--
-- Name: status_events status_events_status_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.status_events
    ADD CONSTRAINT status_events_status_key UNIQUE (status);


--
-- Name: event_categories unique_category_value; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.event_categories
    ADD CONSTRAINT unique_category_value UNIQUE (category_name, value_name);


--
-- Name: users users_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_code_key UNIQUE (code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_federation_license_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_federation_license_key UNIQUE (federation_license);


--
-- Name: users users_insurance_policy_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_insurance_policy_key UNIQUE (insurance_policy);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: waitlist waitlist_code_key; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_code_key UNIQUE (code);


--
-- Name: waitlist waitlist_pkey; Type: CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_pkey PRIMARY KEY (id);


--
-- Name: idx_action_logs_dates; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_action_logs_dates ON public.action_logs USING btree (action_date, user_id);


--
-- Name: idx_action_logs_user_date; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_action_logs_user_date ON public.action_logs USING btree (user_id, action_date);


--
-- Name: idx_certification_courses_composite; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_certification_courses_composite ON public.certification_courses USING btree (certification, certifying_entity);


--
-- Name: idx_certification_courses_entity_type; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_certification_courses_entity_type ON public.certification_courses USING btree (certifying_entity, course_type);


--
-- Name: idx_country_code; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_country_code ON public.country_codes USING btree (country_code);


--
-- Name: idx_courses_course_date; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_courses_course_date ON public.courses USING btree (course_id, start_date);


--
-- Name: idx_courses_speciality_course_id; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_courses_speciality_course_id ON public.courses USING btree (speciality_course_id);


--
-- Name: idx_dive_sites_country; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dive_sites_country ON public.dive_sites USING btree (country);


--
-- Name: idx_dive_sites_geo_location; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dive_sites_geo_location ON public.dive_sites USING gist (geo_location);


--
-- Name: idx_diver_levels_entity; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_diver_levels_entity ON public.diver_levels USING btree (certifying_entity_id);


--
-- Name: idx_dives_date; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dives_date ON public.dives USING btree (date);


--
-- Name: idx_dives_date_status; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dives_date_status ON public.dives USING btree (date, status);


--
-- Name: idx_dives_day_light; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dives_day_light ON public.dives USING btree (day_light_id);


--
-- Name: idx_dives_site_status; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dives_site_status ON public.dives USING btree (id_site, status);


--
-- Name: idx_dives_weather; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_dives_weather ON public.dives USING btree (weather_conditions);


--
-- Name: idx_event_categories_category_value; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_event_categories_category_value ON public.event_categories USING btree (category_name, value_name);


--
-- Name: idx_instructor_levels_entity; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_instructor_levels_entity ON public.instructor_levels USING btree (certifying_entity_id);


--
-- Name: idx_phone_code; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_phone_code ON public.country_codes USING btree (phone_code);


--
-- Name: idx_registrations_composite; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_registrations_composite ON public.dive_registrations USING btree (dive_id, user_id);


--
-- Name: idx_reviews_dive_user; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_reviews_dive_user ON public.reviews USING btree (dive_id, user_id);


--
-- Name: idx_speciality_courses_speciality_id; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_speciality_courses_speciality_id ON public.speciality_courses USING btree (speciality_id);


--
-- Name: idx_users_active_role; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_users_active_role ON public.users USING btree (is_active, role);


--
-- Name: idx_users_activity; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_users_activity ON public.users USING btree (is_active, registration_date);


--
-- Name: idx_users_credentials; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_users_credentials ON public.users USING btree (lower((email)::text), lower((username)::text));


--
-- Name: idx_waitlist_dive_status; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_waitlist_dive_status ON public.waitlist USING btree (dive_id, status_id);


--
-- Name: idx_waitlist_priority; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE INDEX idx_waitlist_priority ON public.waitlist USING btree (dive_id, listed_date);


--
-- Name: users_insurance_policy_unique; Type: INDEX; Schema: public; Owner: indira_sierra
--

CREATE UNIQUE INDEX users_insurance_policy_unique ON public.users USING btree (insurance_policy) WHERE (insurance_policy IS NOT NULL);


--
-- Name: dives trg_dive_code; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_dive_code BEFORE INSERT ON public.dives FOR EACH ROW EXECUTE FUNCTION public.set_dive_code();


--
-- Name: users trg_exclusive_user_levels; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_exclusive_user_levels BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.trg_enforce_exclusive_levels();


--
-- Name: users trg_generate_user_code; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_generate_user_code BEFORE INSERT ON public.users FOR EACH ROW WHEN ((new.code IS NULL)) EXECUTE FUNCTION public.generate_user_code();


--
-- Name: waitlist trg_generate_waitlist_code; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_generate_waitlist_code BEFORE INSERT ON public.waitlist FOR EACH ROW EXECUTE FUNCTION public.set_waitlist_code();


--
-- Name: certification_courses trg_log_certification_courses_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_certification_courses_activity AFTER INSERT OR DELETE OR UPDATE ON public.certification_courses FOR EACH ROW EXECUTE FUNCTION public.trg_log_certification_courses_activity();


--
-- Name: certification_equivalences trg_log_certification_equivalences_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_certification_equivalences_activity AFTER INSERT OR DELETE OR UPDATE ON public.certification_equivalences FOR EACH ROW EXECUTE FUNCTION public.trg_log_certification_equivalences_activity();


--
-- Name: course_enrollments trg_log_course_enrollments_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_course_enrollments_activity AFTER INSERT OR DELETE OR UPDATE ON public.course_enrollments FOR EACH ROW EXECUTE FUNCTION public.trg_log_course_enrollments_activity();


--
-- Name: courses trg_log_courses_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_courses_activity AFTER INSERT OR DELETE OR UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.trg_log_courses_activity();


--
-- Name: deletions trg_log_deletions_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_deletions_activity AFTER INSERT ON public.deletions FOR EACH ROW EXECUTE FUNCTION public.trg_log_deletions_activity();


--
-- Name: dive_cancellations trg_log_dive_cancellations_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_dive_cancellations_activity AFTER INSERT OR DELETE OR UPDATE ON public.dive_cancellations FOR EACH ROW EXECUTE FUNCTION public.trg_log_dive_cancellations_activity();


--
-- Name: dive_registrations trg_log_dive_registrations_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_dive_registrations_activity AFTER INSERT OR DELETE ON public.dive_registrations FOR EACH ROW EXECUTE FUNCTION public.trg_log_dive_registrations_activity();


--
-- Name: dive_sites trg_log_dive_sites_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_dive_sites_activity AFTER INSERT OR DELETE OR UPDATE ON public.dive_sites FOR EACH ROW EXECUTE FUNCTION public.trg_log_dive_sites_activity();


--
-- Name: dives trg_log_on_dives; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_on_dives AFTER INSERT OR DELETE OR UPDATE ON public.dives FOR EACH ROW EXECUTE FUNCTION public.trg_log_dives_activity();


--
-- Name: reviews trg_log_reviews_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_reviews_activity AFTER INSERT OR DELETE OR UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.trg_log_reviews_activity();


--
-- Name: speciality_courses trg_log_speciality_courses_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_speciality_courses_activity AFTER INSERT OR DELETE OR UPDATE ON public.speciality_courses FOR EACH ROW EXECUTE FUNCTION public.trg_log_speciality_courses_activity();


--
-- Name: users trg_log_users_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_users_activity AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.trg_log_users_activity();


--
-- Name: waitlist trg_log_waitlist_activity; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_log_waitlist_activity AFTER INSERT OR DELETE OR UPDATE ON public.waitlist FOR EACH ROW EXECUTE FUNCTION public.trg_log_waitlist_activity();


--
-- Name: master_tables_list trg_master_table_defaults; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_master_table_defaults BEFORE INSERT ON public.master_tables_list FOR EACH ROW EXECUTE FUNCTION public.set_defaults_on_insert_master_table();


--
-- Name: master_tables_list trg_master_table_update_defaults; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_master_table_update_defaults BEFORE UPDATE ON public.master_tables_list FOR EACH ROW EXECUTE FUNCTION public.set_defaults_on_update_master_table();


--
-- Name: users trg_normalize_user_levels_by_type; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_normalize_user_levels_by_type BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.normalize_user_levels_by_type();


--
-- Name: dive_registrations trg_promote_from_waitlist; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_promote_from_waitlist AFTER DELETE ON public.dive_registrations FOR EACH ROW EXECUTE FUNCTION public.promote_waitlisted_user();


--
-- Name: reviews trg_review_code; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_review_code BEFORE INSERT ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.set_review_code();


--
-- Name: dive_sites trg_site_code; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_site_code BEFORE INSERT ON public.dive_sites FOR EACH ROW EXECUTE FUNCTION public.set_site_code();


--
-- Name: dive_sites trg_update_geo_location; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_update_geo_location BEFORE INSERT OR UPDATE ON public.dive_sites FOR EACH ROW EXECUTE FUNCTION public.auto_set_geo_location();


--
-- Name: dives trg_update_geo_location_dives; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_update_geo_location_dives BEFORE INSERT OR UPDATE ON public.dives FOR EACH ROW EXECUTE FUNCTION public.auto_set_geo_location();


--
-- Name: courses trg_update_status_on_courses; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_update_status_on_courses AFTER INSERT OR UPDATE ON public.courses FOR EACH STATEMENT EXECUTE FUNCTION public.trg_check_event_status();


--
-- Name: dives trg_update_status_on_dives; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_update_status_on_dives AFTER INSERT OR UPDATE ON public.dives FOR EACH STATEMENT EXECUTE FUNCTION public.trg_check_event_status();


--
-- Name: waitlist trg_update_waitlist_count; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_update_waitlist_count AFTER INSERT OR DELETE OR UPDATE ON public.waitlist FOR EACH ROW EXECUTE FUNCTION public.update_waitlist_count();


--
-- Name: users trg_validate_diver_type_levels; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_validate_diver_type_levels BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.validate_diver_type_levels();


--
-- Name: users trg_validate_user_uniqueness; Type: TRIGGER; Schema: public; Owner: indira_sierra
--

CREATE TRIGGER trg_validate_user_uniqueness BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.validate_user_uniqueness();


--
-- Name: certification_courses certification_courses_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT certification_courses_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: certification_equivalences certification_equivalences_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT certification_equivalences_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: certifying_entities certifying_entities_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certifying_entities
    ADD CONSTRAINT certifying_entities_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.country_codes(id);


--
-- Name: course_enrollments course_enrollments_enrollment_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_enrollment_status_fkey FOREIGN KEY (enrollment_status) REFERENCES public.status_events(id);


--
-- Name: courses courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.certification_courses(id);


--
-- Name: courses courses_speciality_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_speciality_course_id_fkey FOREIGN KEY (speciality_course_id) REFERENCES public.speciality_courses(id);


--
-- Name: courses courses_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_status_fkey FOREIGN KEY (status) REFERENCES public.status_events(id);


--
-- Name: deletions deletions_log_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_log_id_fkey FOREIGN KEY (log_id) REFERENCES public.action_logs(id);


--
-- Name: dive_cancellations dive_cancellations_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: dive_cancellations dive_cancellations_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: dive_registrations dive_registrations_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: dive_sites dive_sites_dive_access_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_dive_access_fkey FOREIGN KEY (dive_access) REFERENCES public.event_categories(id);


--
-- Name: dive_sites dive_sites_kind_of_dive_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_kind_of_dive_fkey FOREIGN KEY (kind_of_dive) REFERENCES public.event_categories(id);


--
-- Name: dive_sites dive_sites_water_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT dive_sites_water_fkey FOREIGN KEY (water) REFERENCES public.event_categories(id);


--
-- Name: diver_levels diver_levels_certifying_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_levels
    ADD CONSTRAINT diver_levels_certifying_entity_id_fkey FOREIGN KEY (certifying_entity_id) REFERENCES public.certifying_entities(id);


--
-- Name: diver_specialities diver_specialties_diver_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.diver_specialities
    ADD CONSTRAINT diver_specialties_diver_level_fkey FOREIGN KEY (diver_level) REFERENCES public.diver_levels(id);


--
-- Name: dives dives_id_site_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_id_site_fkey FOREIGN KEY (id_site) REFERENCES public.dive_sites(id);


--
-- Name: dives dives_min_level_required_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_min_level_required_fkey FOREIGN KEY (min_level_required) REFERENCES public.diver_levels(id);


--
-- Name: dives dives_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT dives_status_fkey FOREIGN KEY (status) REFERENCES public.status_events(id);


--
-- Name: action_logs fk_action_logs_user_id; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT fk_action_logs_user_id FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: certification_equivalences fk_certification_category; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_equivalences
    ADD CONSTRAINT fk_certification_category FOREIGN KEY (category_course_id) REFERENCES public.event_categories(id);


--
-- Name: certification_courses fk_certification_courses_type; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.certification_courses
    ADD CONSTRAINT fk_certification_courses_type FOREIGN KEY (course_type_id) REFERENCES public.event_categories(id);


--
-- Name: course_enrollments fk_course_enrollments_course; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT fk_course_enrollments_course FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE;


--
-- Name: course_enrollments fk_course_enrollments_student; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT fk_course_enrollments_student FOREIGN KEY (student_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dives fk_daylight; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT fk_daylight FOREIGN KEY (day_light_id) REFERENCES public.event_categories(id) ON DELETE SET NULL;


--
-- Name: deletions fk_deleted_by; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT fk_deleted_by FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: deletions fk_deleted_record; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT fk_deleted_record FOREIGN KEY (deleted_record) REFERENCES public.event_categories(id);


--
-- Name: dive_cancellations fk_dive_cancellations_canceled_by; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT fk_dive_cancellations_canceled_by FOREIGN KEY (canceled_by) REFERENCES public.users(id);


--
-- Name: dive_cancellations fk_dive_cancellations_reasons; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT fk_dive_cancellations_reasons FOREIGN KEY (reasons) REFERENCES public.event_categories(id);


--
-- Name: dive_registrations fk_dive_registrations_user; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT fk_dive_registrations_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: dive_sites fk_dive_sites_country; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT fk_dive_sites_country FOREIGN KEY (country) REFERENCES public.country_codes(id);


--
-- Name: dives fk_dives_weather; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT fk_dives_weather FOREIGN KEY (weather_conditions) REFERENCES public.event_categories(id);


--
-- Name: action_logs fk_log_action; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT fk_log_action FOREIGN KEY (action_type) REFERENCES public.event_categories(id);


--
-- Name: master_tables_list fk_master_table_status; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.master_tables_list
    ADD CONSTRAINT fk_master_table_status FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: courses fk_payment; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT fk_payment FOREIGN KEY (payment) REFERENCES public.event_categories(id);


--
-- Name: reviews fk_reviews_user_id; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_reviews_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reviews fk_visibility; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT fk_visibility FOREIGN KEY (visibility) REFERENCES public.event_categories(id);


--
-- Name: waitlist fk_waitlist_status; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT fk_waitlist_status FOREIGN KEY (status_id) REFERENCES public.status_events(id);


--
-- Name: waitlist fk_waitlist_user; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT fk_waitlist_user FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: instructor_levels instructor_levels_certifying_entity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.instructor_levels
    ADD CONSTRAINT instructor_levels_certifying_entity_id_fkey FOREIGN KEY (certifying_entity_id) REFERENCES public.certifying_entities(id);


--
-- Name: reviews reviews_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: speciality_courses speciality_courses_speciality_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.speciality_courses
    ADD CONSTRAINT speciality_courses_speciality_id_fkey FOREIGN KEY (speciality_id) REFERENCES public.diver_specialities(id);


--
-- Name: users users_certifying_entity_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_certifying_entity_fkey FOREIGN KEY (certifying_entity) REFERENCES public.certifying_entities(id);


--
-- Name: users users_country_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_country_fkey FOREIGN KEY (country) REFERENCES public.country_codes(id);


--
-- Name: users users_diver_type_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_diver_type_fkey FOREIGN KEY (diver_type) REFERENCES public.event_categories(id);


--
-- Name: users users_diving_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_diving_level_fkey FOREIGN KEY (diving_level) REFERENCES public.diver_levels(id);


--
-- Name: users users_gender_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_gender_fkey FOREIGN KEY (gender) REFERENCES public.event_categories(id);


--
-- Name: users users_instructor_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_instructor_level_fkey FOREIGN KEY (instructor_level) REFERENCES public.instructor_levels(id);


--
-- Name: users users_role_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_role_fkey FOREIGN KEY (role) REFERENCES public.event_categories(id);


--
-- Name: users users_size_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_size_fkey FOREIGN KEY (size) REFERENCES public.event_categories(id);


--
-- Name: waitlist waitlist_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: indira_sierra
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO indira_sierra;


--
-- Name: FUNCTION log_table_creation(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.log_table_creation() TO indira_sierra;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: indira_sierra
--

ALTER DEFAULT PRIVILEGES FOR ROLE indira_sierra IN SCHEMA public GRANT ALL ON SEQUENCES TO indira_sierra;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: indira_sierra
--

ALTER DEFAULT PRIVILEGES FOR ROLE indira_sierra IN SCHEMA public GRANT ALL ON FUNCTIONS TO indira_sierra;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: indira_sierra
--

ALTER DEFAULT PRIVILEGES FOR ROLE indira_sierra IN SCHEMA public GRANT ALL ON TABLES TO indira_sierra;


--
-- PostgreSQL database dump complete
--

