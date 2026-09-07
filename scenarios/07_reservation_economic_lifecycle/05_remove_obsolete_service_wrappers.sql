-- Scenarios 05 and 06 retain these names to show the evolution from ARRAY to
-- JSONB input. In the final API, service replacement has one canonical entry
-- point with explicit collection semantics and an economic-state result.
DROP FUNCTION IF EXISTS add_services_to_reservation(BIGINT, BIGINT[]);
DROP FUNCTION IF EXISTS add_services_to_reservation(BIGINT, JSONB);
