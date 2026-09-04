CREATE OR REPLACE FUNCTION process_booking(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_payment_amount    NUMERIC,
    p_payment_method    VARCHAR(30),
    p_created_by_user_id BIGINT,
    p_services          JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
BEGIN
    v_reservation_id := create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        p_services
    );

    PERFORM process_reservation_payment(
        v_reservation_id,
        p_payment_amount,
        p_payment_method
    );

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION process_booking(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_payment_amount    NUMERIC,
    p_payment_method    VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN process_booking(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_payment_amount,
        p_payment_method,
        p_created_by_user_id,
        NULL::JSONB
    );
END;
$$;
