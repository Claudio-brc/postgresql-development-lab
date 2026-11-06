-- Apply after 010_add_user_roles.sql.
-- Strengthens reservation confirmation and cancellation without rewriting data.

BEGIN;

-- Reuse the final economic-lifecycle definitions so upgrade and clean-install
-- behavior cannot drift. \ir resolves paths relative to this upgrade in psql.
\ir ../../scenarios/07_reservation_economic_lifecycle/09_confirm_reservation.sql
\ir ../../scenarios/07_reservation_economic_lifecycle/10_cancel_reservation.sql

COMMIT;
