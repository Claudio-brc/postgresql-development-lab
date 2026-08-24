CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC;
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
BEGIN
    PERFORM validate_booking_dates(
        p_check_in,
        p_check_out
    );

    v_is_available := is_property_available(
        p_property_id,
        p_check_in,
        p_check_out
    );

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'Property is not available for the selected dates.';
    END IF;

    PERFORM can_guest_book(
        p_guest_id
    );

    v_total_amount := calculate_booking_total(
        p_property_id,
        p_check_in,
        p_check_out
    );

    INSERT INTO reservations (
        guest_id,
        property_id,
        check_in_date,
        check_out_date,
        total_amount,
        status,
        created_by_user_id
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING',
        p_created_by_user_id
    )
    RETURNING reservation_id
    INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$;
