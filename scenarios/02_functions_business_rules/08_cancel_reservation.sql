CREATE OR REPLACE FUNCTION public.cancel_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_status VARCHAR(20);
BEGIN

    SELECT status
      INTO v_status
      FROM reservations
     WHERE reservation_id = p_reservation_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
    END IF;

    IF v_status = 'CANCELLED' THEN
        RAISE EXCEPTION 'Reservation is already cancelled.';
    END IF;

    UPDATE reservations
       SET status = 'CANCELLED'
     WHERE reservation_id = p_reservation_id;

END;
$$;