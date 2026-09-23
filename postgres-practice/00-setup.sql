-- psql-only convenience runner; relative includes resolve beside this file.
\set ON_ERROR_STOP on
\ir 01-schema.sql
\ir 02-seed.sql
\ir 07-verify.sql
