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
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--



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


--
-- Data for Name: course_enrollments; Type: TABLE DATA; Schema: public; Owner: -
--



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
-- Data for Name: courses; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: deletions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_sites; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dives; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_cancellations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: dive_registrations; Type: TABLE DATA; Schema: public; Owner: -
--



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
INSERT INTO public.master_tables_list (id, schema_name, table_name, created_at) VALUES (22, 'public', 'public.country_codes', '2025-05-07 12:59:51.05719');


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

SELECT pg_catalog.setval('public.master_tables_list_id_seq', 22, true);


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
-- PostgreSQL database dump complete
--

