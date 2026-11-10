-- Apply after 011_reservation_cancellation.sql.
-- Prevents cancellation of confirmed reservations after checkout.

BEGIN;

-- Reuse the final economic-lifecycle definition so upgrade and clean-install
-- behavior cannot drift. \ir resolves paths relative to this upgrade in psql.
\ir ../../scenarios/07_reservation_economic_lifecycle/10_cancel_reservation.sql

COMMIT;
