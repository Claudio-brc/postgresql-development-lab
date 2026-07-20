CREATE OR REPLACE FUNCTION public.confirm_reservation(
    p_reservation_id BIGINT
)
RETURNS VOID
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE 
v_status VARCHAR(20);

BEGIN

  SELECT status
    INTO v_status
    FROM reservations r
   WHERE reservation_id = p_reservation_id;

  IF v_status IS NULL THEN
    RAISE EXCEPTION 'Reservation % not found.', p_reservation_id;
  END IF;
   
  IF v_status <> 'PENDING' THEN
    RAISE EXCEPTION 'Reservation must be PENDING.';
  END IF;

  UPDATE reservations
     SET status = 'CONFIRMED'
   WHERE reservation_id = p_reservation_id;


END;
$BODY$;