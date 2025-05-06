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
    country character varying(50) NOT NULL,
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
    gender_id integer
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
-- Data for Name: action_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: certification_courses; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (1, 'CU-D-FE34-01', '1 Star Diver (B1E) Course', 'D-FE34-01', 1, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (2, 'CU-D-FE34-02', '2 Star Diver (B2E) Course', 'D-FE34-02', 1, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (3, 'CU-D-FE34-03', '3 Star Diver (B3E) Course', 'D-FE34-03', 1, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (4, 'CU-D-FE34-GG', 'Group Guide Course', 'D-FE34-GG', 1, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (5, 'CU-D-CM33-01', 'CMAS 1 Star Diver Course', 'D-CM33-01', 2, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (6, 'CU-D-CM33-02', 'CMAS 2 Star Diver Course', 'D-CM33-02', 2, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (7, 'CU-D-CM33-03', 'CMAS 3 Star Diver Course', 'D-CM33-03', 2, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (8, 'CU-D-PA01-01', 'Open Water Diver Course', 'D-PA01-01', 3, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (9, 'CU-D-PA01-02', 'Rescue Diver Course', 'D-PA01-02', 3, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (10, 'CU-D-PA01-03', 'Divemaster - Master Scuba Diver Course', 'D-PA01-03', 3, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (11, 'CU-D-MA33-02', '2nd Class Diver Course', 'D-MA34-02', 4, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (12, 'CU-D-MA33-03', '1st Class Diver Course', 'D-MA34-03', 4, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (13, 'CU-D-BS44-01', 'Ocean Diver - Club Diver - Sport Diver Course', 'D-BS44-01', 5, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (14, 'CU-D-BS44-02', 'Dive Leader Course', 'D-BS44-02', 5, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (15, 'CU-D-BS44-03', 'Advanced Diver Course', 'D-BS44-03', 5, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (16, 'CU-D-BS44-GG', '1st Class Diver Course', 'D-BS44-GG', 5, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (17, 'CU-D-SS01-01', 'Open Water Diver Course', 'D-SS01-01', 6, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (18, 'CU-D-SS01-02', 'Advanced Open Water Diver Course', 'D-SS01-02', 6, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (19, 'CU-D-SS01-03', 'Divemaster - Master Diver - Diver Con. Course', 'D-SS01-03', 6, 'diver level 3', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (20, 'CU-D-AC01-01', 'Open Water Diver Course', 'D-AC01-01', 7, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (21, 'CU-D-AC01-02', 'Advanced Diver Course', 'D-AC01-02', 7, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (22, 'CU-D-AC01-03', 'Divemaster - Master Diver Course', 'D-AC01-03', 7, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (23, 'CU-D-NA01-01', 'Scuba Diver Course', 'D-NA01-01', 8, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (24, 'CU-D-NA01-02', 'Rescue Diver Course', 'D-NA01-02', 8, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (25, 'CU-D-NA01-03', 'Master Scuba Diver Course', 'D-NA01-03', 8, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (26, 'CU-D-PD01-01', 'Starter Course', 'D-PD01-01', 9, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (27, 'CU-D-PD01-02', '2nd Restricted Course', 'D-PD01-02', 9, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (28, 'CU-D-PD01-03', '2nd Professional Course', 'D-PD01-03', 9, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (29, 'CU-D-GC34-03', 'Guardia Civil Diver Course', 'D-GC34-03', 10, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (30, 'CU-D-FA34-01', 'Scientific Diver Course', 'D-FA34-01', 11, 'diver level 0', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (31, 'CU-D-FA34-02', 'Support Diver Course', 'D-FA34-02', 11, 'diver level 1', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (32, 'CU-D-FA34-03', 'Elementary Diver Course', 'D-FA34-03', 11, 'diver level 2', 'Diver');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (33, 'CU-D-FA34-GG1', 'Combat Diver Course', 'D-FA34-GG1', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (34, 'CU-D-FA34-GG2', 'Mine Diver Course', 'D-FA34-GG2', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (35, 'CU-D-FA34-GG3', 'Fitness GP Diver Course', 'D-FA34-GG3', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (36, 'CU-D-FA34-GG4', 'Assault Diver Course', 'D-FA34-GG4', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (37, 'CU-D-FA34-GG5', 'Amphibious Sapper Course', 'D-FA34-GG5', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (38, 'CU-D-FA34-GG6', 'Dive Technology Course', 'D-FA34-GG6', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (39, 'CU-D-FA34-GG7', 'Dive Speciality Course', 'D-FA34-GG7', 11, 'diver level 3', 'Guide');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (40, 'CU-I-FE34-01', '1 Star Intructor Course', 'I-FE34-01', 1, 'diver level 3', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (41, 'CU-I_FE34-02', '2 Star Instructor Course', 'I-FE34-02', 1, 'instructor level 1', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (42, 'CU-I_FE34-03', '3 Star Instructor Course', 'I-FE34-03', 1, 'instructor level 2', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (43, 'CU-I-BS44-02', 'Open Water Instructor Course', 'I-BS44-00', 5, 'diver level 3', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (44, 'CU-I-PA01-02', 'Open Water Instructor Course', 'I-PA01-02', 3, 'diver level 3', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (45, 'CU-I-SS01-02', 'Open Water Instructor Course', 'I-SS01-02', 6, 'diver level 3', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (46, 'CU-I-AC01-02', 'Open Water Instructor Course', 'I-AC01-02', 7, 'diver level 3', 'Instructor');
INSERT INTO public.certification_courses (id, code, name, certification, certifying_entity, requirements, course_type) VALUES (47, 'CU-I-NA01-02', 'Scuba Instructor Course', 'I-NA01-02', 8, 'diver level 3', 'Instructor');


--
-- Data for Name: certification_equivalences; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (1, 1, 'diver', 'Level 1', '1 Star Diver (B1E)', 'D-FE34-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (2, 1, 'diver', 'Level 2', '2 Star Diver (B2E)', 'D-FE34-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (3, 1, 'diver', 'Level 3', '3 Star Diver (B3E)', 'D-FE34-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (4, 1, 'diver', 'Guide', 'Group Guide', 'D-FE34-GG');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (5, 1, 'instructor', 'Level 1', '1 Star Instructor', 'I-FE34-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (6, 1, 'instructor', 'Level 2', '2 Star Instructor', 'I-FE34-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (7, 1, 'instructor', 'Level 3', '3 Star Instructor', 'I-FE34-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (8, 2, 'diver', 'Level 1', 'CMAS 1 Star Diver', 'D-CM33-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (9, 2, 'diver', 'Level 2', 'CMAS 2 Star Diver', 'D-CM33-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (10, 2, 'diver', 'Level 3', 'CMAS 3 Star Diver', 'D-CM33-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (11, 2, 'instructor', 'Level 1', '1 Star Instructor', 'I-CM33-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (12, 2, 'instructor', 'Level 2', '2 Star Instructor', 'I-CM33-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (13, 2, 'instructor', 'Level 3', '3 Star Instructor', 'I-CM33-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (14, 3, 'diver', 'Level 1', 'Open Water Diver', 'D-PA01-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (15, 3, 'diver', 'Level 2', 'Rescue Diver', 'D-PA01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (16, 3, 'diver', 'Level 3', 'Divemaster - Master Scuba Diver', 'D-PA01-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (17, 3, 'instructor', 'Level 2', 'Open Water Instructor', 'I-PA01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (18, 4, 'diver', 'Level 2', '2nd Class Diver', 'D-MA34-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (19, 4, 'diver', 'Level 3', '1st Class Diver', 'D-MA34-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (20, 5, 'diver', 'Level 1', 'Ocean Diver - Club Diver - Sport Diver', 'D-BS44-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (21, 5, 'diver', 'Level 2', 'Dive Leader', 'D-BS44-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (22, 5, 'diver', 'Level 3', 'Advanced Diver', 'D-BS44-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (23, 5, 'diver', 'Guide', '1st Class Diver', 'D-BS44-GG');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (24, 5, 'instructor', 'Level 2', 'Open Water Instructor', 'I-BS44-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (25, 6, 'diver', 'Level 1', 'Open Water Diver', 'D-SS01-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (26, 6, 'diver', 'Level 2', 'Advanced Open Water Diver', 'D-SS01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (27, 6, 'diver', 'Level 3', 'Divemaster - Master Diver - Diver Con.', 'D-SS01-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (28, 6, 'instructor', 'Level 2', 'Open Water Instructor', 'I-SS01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (29, 7, 'diver', 'Level 1', 'Open Water Diver', 'D-AC01-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (30, 7, 'diver', 'Level 2', 'Advanced Diver', 'D-AC01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (31, 7, 'diver', 'Level 3', 'Divemaster - Master Diver', 'D-AC01-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (32, 7, 'instructor', 'Level 2', 'Open Water Instructor', 'I-AC01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (33, 8, 'diver', 'Level 1', 'Scuba Diver', 'D-NA01-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (34, 8, 'diver', 'Level 2', 'Rescue Diver', 'D-NA01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (35, 8, 'diver', 'Level 3', 'Master Scuba Diver', 'D-NA01-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (36, 8, 'instructor', 'Level 2', 'Scuba Instructor', 'I-NA01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (37, 9, 'diver', 'Level 1', 'Starter', 'D-PD01-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (38, 9, 'diver', 'Level 2', '2nd Restricted', 'D-PD01-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (39, 9, 'diver', 'Level 3', '2nd Professional', 'D-PD01-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (40, 10, 'diver', 'Level 3', 'Guardia Civil Diver', 'D-GC34-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (41, 11, 'diver', 'Level 1', 'Scientific Diver', 'D-FA34-01');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (42, 11, 'diver', 'Level 2', 'Support Diver', 'D-FA34-02');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (43, 11, 'diver', 'Level 3', 'Elementary Diver', 'D-FA34-03');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (44, 11, 'diver', 'Guide', 'Combat Diver', 'D-FA34-GG1');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (45, 11, 'diver', 'Guide', 'Mine Diver', 'D-FA34-GG2');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (46, 11, 'diver', 'Guide', 'Fitness GP Diver', 'D-FA34-GG3');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (47, 11, 'diver', 'Guide', 'Assault Diver', 'D-FA34-GG4');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (48, 11, 'diver', 'Guide', 'Amphibious Sapper', 'D-FA34-GG5');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (49, 11, 'diver', 'Guide', 'Dive Technology', 'D-FA34-GG6');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (50, 11, 'diver', 'Guide', 'Dive Speciality', 'D-FA34-GG7');
INSERT INTO public.certification_equivalences (id, certifying_entity, category, level, name, level_code) VALUES (51, 0, 'diver', 'level 0', 'No Certification / Entry Level', 'D-NONE-00');


--
-- Data for Name: certifying_entities; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (1, 'Federación Española de Actividades Subacuáticas', 'FEDAS', 'FE34');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (2, 'Confédération Mondiale des Activités Subaquatiques', 'CMAS', 'CM33');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (3, 'Professional Association of Diving Instructors', 'PADI', 'PA01');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (4, 'Mediterranean Aquatic Professions Association', 'MAPA', 'MA34');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (5, 'British Sub-Aqua Club', 'BSAC', 'BS44');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (6, 'Scuba Schools International', 'SSI', 'SS01');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (7, 'American and Canadian Underwater Certifications', 'ACUC', 'AC01');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (8, 'National Association of Underwater Instructors', 'NAUI', 'NA01');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (11, 'EMB Fuerzas Armadas Ejército Español', 'ARMADA', 'FA34');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (0, 'System', 'SYS', 'SYS00');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (9, 'Professional Dive', 'PROFESSIONAL DIVE', 'PD01');
INSERT INTO public.certifying_entities (id, full_name, acronym, code) VALUES (10, 'GEAS Guardia Civil', 'GUARDIA CIVIL', 'GC34');


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
INSERT INTO public.diver_levels (id, certifying_entity_id, level, certification, code) VALUES (0, 0, 'level 0', 'No Certification / Entry Level', 'D-NONE-00');


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
INSERT INTO public.event_categories (id, category_name, value_name, description) VALUES (19, 'Kind of Dive', 'Explore Unknown', NULL);
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
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (0, 0, 'level 0', 'Max Diving Level', 'I-NONE-00');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (4, 2, 'Level 1', 'CMAS 1 Star Instructor', 'I-CM33-01');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (5, 2, 'Level 2', 'CMAS 2 Star Instructor', 'I-CM33-02');
INSERT INTO public.instructor_levels (id, certifying_entity_id, level, certification, code) VALUES (6, 2, 'Level 3', 'CMAS 3 Star Instructor', 'I-CM33-03');


--
-- Data for Name: master_tables_list; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (1, 'public', 'action_logs', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (2, 'public', 'certification_courses', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (3, 'public', 'certification_equivalences', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (4, 'public', 'certifying_entities', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (5, 'public', 'course_enrollments', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (6, 'public', 'courses', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (7, 'public', 'deletions', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (8, 'public', 'dive_cancellations', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (9, 'public', 'dive_registrations', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (10, 'public', 'dive_sites', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (11, 'public', 'diver_levels', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (13, 'public', 'dives', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (14, 'public', 'event_categories', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (15, 'public', 'instructor_levels', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (16, 'public', 'reviews', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (17, 'public', 'spatial_ref_sys', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (18, 'public', 'status_events', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (19, 'public', 'users', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (20, 'public', 'waitlist', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (12, 'public', 'diver_specialities', '2025-04-27 16:55:01.727141');
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (21, 'public', 'public.speciality_courses', '2025-04-28 02:56:30.819801');


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


--
-- Data for Name: status_events; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.status_events (id, status, code) VALUES (1, 'Next', 'ST01');
INSERT INTO public.status_events (id, status, code) VALUES (2, 'Active', 'ST02');
INSERT INTO public.status_events (id, status, code) VALUES (3, 'Full', 'ST03');
INSERT INTO public.status_events (id, status, code) VALUES (4, 'Ongoing', 'ST04');
INSERT INTO public.status_events (id, status, code) VALUES (5, 'Canceled', 'ST05');
INSERT INTO public.status_events (id, status, code) VALUES (6, 'Finished', 'ST06');


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: waitlist; Type: TABLE DATA; Schema: public; Owner: -
--



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

SELECT pg_catalog.setval('public.dive_sites_id_seq', 1, false);


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

SELECT pg_catalog.setval('public.event_categories_id_seq', 64, true);


--
-- Name: instructor_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.instructor_levels_id_seq', 1, false);


--
-- Name: master_tables_list_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.master_tables_list_id_seq', 21, true);


--
-- Name: reviews_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.reviews_id_seq', 1, false);


--
-- Name: speciality_courses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.speciality_courses_id_seq', 16, true);


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
-- Name: idx_courses_course_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courses_course_date ON public.courses USING btree (course_id, start_date);


--
-- Name: idx_dives_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_dives_date ON public.dives USING btree (date);


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

