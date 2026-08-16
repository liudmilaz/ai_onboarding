-- Metabase keeps its own application state (dashboards, cards, users) in Postgres
-- rather than the default embedded H2, so the stack survives a container restart.
CREATE DATABASE metabase;
