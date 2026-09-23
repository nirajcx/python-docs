-- DESTRUCTIVE, OPT-IN: deletes ONLY the practice schema and all its objects/data.
-- Run manually ONLY when ready to lose your work in interview_lab.
-- No other schema is targeted. Re-run 01-schema.sql and 02-seed.sql afterward.
DROP SCHEMA IF EXISTS interview_lab CASCADE;
