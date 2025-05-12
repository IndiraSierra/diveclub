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
-- Name: cancel_reason_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.cancel_reason_enum AS ENUM (
    'Bad Weather',
    'Close Access Road',
    'Slack of Responsible Instructor',
    'Not Enough Attendants',
    'Unexpected Surge',
    'Rain',
    'Personal Reasons'
);


--
-- Name: daylight_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.daylight_enum AS ENUM (
    'Day Dive',
    'Night Dive'
);


--
-- Name: dive_access_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.dive_access_enum AS ENUM (
    'Shore',
    'boat',
    'Pier',
    'Cave'
);


--
-- Name: diver_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.diver_type_enum AS ENUM (
    'diver',
    'Instructor'
);


--
-- Name: gender_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.gender_enum AS ENUM (
    'Fem',
    'Masc'
);


--
-- Name: kind_of_dive_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.kind_of_dive_enum AS ENUM (
    'Reef',
    'Wreck',
    'Cave',
    'Under Ice',
    'Explore Unknown'
);


--
-- Name: log_action_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.log_action_enum AS ENUM (
    'CREATE',
    'UPDATE',
    'DELETE',
    'LOGIN',
    'LOGOUT',
    'VIEW',
    'FAILED_LOGIN',
    'ENROLLMENT',
    'PASSWORD_CHANGE',
    'ATTEND',
    'REVIEW'
);


--
-- Name: payment_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_enum AS ENUM (
    'Currency',
    'Credits'
);


--
-- Name: role_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.role_enum AS ENUM (
    'user',
    'admin'
);


--
-- Name: size_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.size_enum AS ENUM (
    'XS',
    'S',
    'M',
    'L',
    'XL',
    'XXL'
);


--
-- Name: visibility_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.visibility_enum AS ENUM (
    'Bad (-3m)',
    'Regular (3~5m)',
    'Good (+5m)',
    'Very Good (+10m)',
    'Night Dive'
);


--
-- Name: water_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.water_enum AS ENUM (
    'Salt',
    'Fresh'
);


--
-- Name: weather_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.weather_enum AS ENUM (
    'Cloudy',
    'Sunny',
    'Rainny',
    'Surge',
    'Windy'
);


--
-- Name: delete_from_master_tables_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_from_master_tables_list() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
BEGIN
    -- Recorremos todos los objetos de tipo tabla en el evento
    FOR obj IN
        SELECT tg_event, tg_table, tg_schema
        FROM pg_event_trigger_dropped_objects()
    LOOP
        -- Eliminamos el nombre de la tabla de la tabla maestra
        DELETE FROM master_tables_list
        WHERE schema_name = obj.tg_schema
        AND table_name = obj.tg_table;
    END LOOP;
END;
$$;


--
-- Name: insert_into_master_tables_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.insert_into_master_tables_list() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj RECORD;
BEGIN
    -- Recorremos todos los objetos de tipo tabla en el evento
    FOR obj IN
        SELECT tg_event, tg_table, tg_schema
        FROM pg_event_trigger_dropped_objects()
    LOOP
        -- Insertamos el nombre de la tabla en nuestra tabla maestra
        INSERT INTO master_tables_list (schema_name, table_name)
        VALUES (obj.tg_schema, obj.tg_table);
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
BEGIN
    FOR obj IN
        SELECT *
        FROM pg_event_trigger_ddl_commands()
        WHERE command_tag = 'CREATE TABLE'
    LOOP
        INSERT INTO master_tables_list (table_name, schema_name, created_at)
        VALUES (obj.object_identity, obj.schema_name, NOW());
    END LOOP;
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
-- Name: remove_table_from_master_list(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.remove_table_from_master_list() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  DELETE FROM master_tables_list
  WHERE table_name = tg_table;
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_logs (
    id integer NOT NULL,
    user_id integer,
    action_type public.log_action_enum NOT NULL,
    target_table character varying(100) NOT NULL,
    target_id integer,
    action_date timestamp without time zone NOT NULL,
    description text,
    ip_address character varying(45),
    code character varying(30) NOT NULL
);


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
    course_type character varying(30) NOT NULL
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
    level_code character varying(30) NOT NULL
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
    code character varying(30) NOT NULL
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
    active boolean DEFAULT true
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
    course_id integer,
    student_id integer,
    enrollment_date timestamp without time zone NOT NULL,
    code character varying(30) NOT NULL
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
    payment public.payment_enum NOT NULL,
    status integer NOT NULL,
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
    log_id integer,
    deleted_record character varying(30) NOT NULL,
    deleted_id integer NOT NULL,
    deleted_by integer,
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
    dive_id integer,
    status_id integer,
    canceled_by integer,
    reasons public.cancel_reason_enum DEFAULT 'Not Enough Attendants'::public.cancel_reason_enum NOT NULL,
    date timestamp without time zone NOT NULL,
    information text,
    code character varying(30) NOT NULL
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
    user_id integer,
    dive_id integer,
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
    water public.water_enum DEFAULT 'Salt'::public.water_enum NOT NULL,
    kind_of_dive public.kind_of_dive_enum DEFAULT 'Wreck'::public.kind_of_dive_enum NOT NULL,
    dive_access public.dive_access_enum DEFAULT 'boat'::public.dive_access_enum NOT NULL,
    region character varying(50) NOT NULL,
    country integer NOT NULL,
    code character varying(30) NOT NULL
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
    certifying_entity_id integer,
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
    weather_conditions public.weather_enum DEFAULT 'Cloudy'::public.weather_enum NOT NULL,
    status integer NOT NULL,
    credits integer NOT NULL,
    description text NOT NULL,
    code character varying(30) NOT NULL,
    day_light_id integer
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
    certifying_entity_id integer,
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
    created_at timestamp without time zone DEFAULT now()
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
    dive_id integer,
    user_id integer,
    review_date timestamp without time zone NOT NULL,
    visibility public.visibility_enum NOT NULL,
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
    name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(150) NOT NULL,
    birth_date date NOT NULL,
    phone character varying(20) NOT NULL,
    weight integer NOT NULL,
    height integer NOT NULL,
    size public.size_enum NOT NULL,
    role public.role_enum DEFAULT 'user'::public.role_enum NOT NULL,
    username character varying(50) NOT NULL,
    password character varying(255) NOT NULL,
    diver_type public.diver_type_enum DEFAULT 'diver'::public.diver_type_enum NOT NULL,
    certifying_entity integer NOT NULL,
    diving_level integer NOT NULL,
    instructor_level integer,
    federation_license character varying(20) NOT NULL,
    insurance boolean DEFAULT false,
    insurance_policy character varying(50) NOT NULL,
    registration_date timestamp without time zone NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    credits integer DEFAULT 0 NOT NULL,
    code character varying(30) NOT NULL,
    total_dives integer DEFAULT 0 NOT NULL,
    gender_id integer NOT NULL,
    country character varying(2)
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
    "position" integer NOT NULL,
    user_id integer,
    dive_id integer,
    code character varying(30) NOT NULL
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
-- Name: waitlist waitlist_dive_id_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_dive_id_position_key UNIQUE (dive_id, "position");


--
-- Name: waitlist waitlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_pkey PRIMARY KEY (id);


--
-- Name: idx_certification_courses_composite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_certification_courses_composite ON public.certification_courses USING btree (certification, certifying_entity);


--
-- Name: idx_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_country_code ON public.country_codes USING btree (country_code);


--
-- Name: idx_courses_course_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_course_date ON public.courses USING btree (course_id, start_date);


--
-- Name: idx_dive_sites_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dive_sites_country ON public.dive_sites USING btree (country);


--
-- Name: idx_dive_sites_geo_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dive_sites_geo_location ON public.dive_sites USING gist (geo_location);


--
-- Name: idx_dives_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dives_date ON public.dives USING btree (date);


--
-- Name: idx_phone_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_phone_code ON public.country_codes USING btree (phone_code);


--
-- Name: idx_speciality_courses_speciality_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_speciality_courses_speciality_id ON public.speciality_courses USING btree (speciality_id);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_federation_license; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_federation_license ON public.users USING btree (federation_license);


--
-- Name: action_logs action_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_logs
    ADD CONSTRAINT action_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: course_enrollments course_enrollments_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.course_enrollments
    ADD CONSTRAINT course_enrollments_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(id);


--
-- Name: courses courses_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.certification_courses(id);


--
-- Name: courses courses_instructor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_instructor_id_fkey FOREIGN KEY (instructor_id) REFERENCES public.users(id);


--
-- Name: courses courses_status_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courses
    ADD CONSTRAINT courses_status_fkey FOREIGN KEY (status) REFERENCES public.status_events(id);


--
-- Name: deletions deletions_deleted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.users(id);


--
-- Name: deletions deletions_log_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deletions
    ADD CONSTRAINT deletions_log_id_fkey FOREIGN KEY (log_id) REFERENCES public.action_logs(id);


--
-- Name: dive_cancellations dive_cancellations_canceled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_cancellations
    ADD CONSTRAINT dive_cancellations_canceled_by_fkey FOREIGN KEY (canceled_by) REFERENCES public.users(id);


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
-- Name: dive_registrations dive_registrations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_registrations
    ADD CONSTRAINT dive_registrations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: dives fk_daylight; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dives
    ADD CONSTRAINT fk_daylight FOREIGN KEY (day_light_id) REFERENCES public.event_categories(id) ON DELETE SET NULL;


--
-- Name: dive_sites fk_dive_sites_country; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dive_sites
    ADD CONSTRAINT fk_dive_sites_country FOREIGN KEY (country) REFERENCES public.country_codes(id);


--
-- Name: users fk_gender; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_gender FOREIGN KEY (gender_id) REFERENCES public.event_categories(id) ON DELETE SET NULL;


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
-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: users users_diving_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_diving_level_fkey FOREIGN KEY (diving_level) REFERENCES public.diver_levels(id);


--
-- Name: users users_instructor_level_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_instructor_level_fkey FOREIGN KEY (instructor_level) REFERENCES public.instructor_levels(id);


--
-- Name: waitlist waitlist_dive_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_dive_id_fkey FOREIGN KEY (dive_id) REFERENCES public.dives(id);


--
-- Name: waitlist waitlist_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.waitlist
    ADD CONSTRAINT waitlist_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: track_table_creation; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER track_table_creation ON ddl_command_end
         WHEN TAG IN ('CREATE TABLE')
   EXECUTE FUNCTION public.log_table_creation();


--
-- Name: track_table_deletion; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER track_table_deletion ON ddl_command_end
         WHEN TAG IN ('DROP TABLE')
   EXECUTE FUNCTION public.log_table_deletion();


--
-- PostgreSQL database dump complete
--

