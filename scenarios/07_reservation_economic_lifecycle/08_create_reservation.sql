-- The eight-argument form is the canonical implementation. Payment is absent
-- only when both payment fields are NULL; incomplete payment input is rejected.
CREATE OR REPLACE FUNCTION create_reservation(
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
    v_reservation_id := initialize_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        p_services
    );

    IF p_payment_amount IS NULL AND p_payment_method IS NULL THEN
        RETURN v_reservation_id;
    END IF;

    IF p_payment_amount IS NULL OR p_payment_method IS NULL THEN
        RAISE EXCEPTION 'Payment amount and payment method must be supplied together.';
    END IF;

    PERFORM process_reservation_payment(
        v_reservation_id,
        p_payment_amount,
        p_payment_method
    );

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
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
    RETURN create_reservation(
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

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT,
    p_services          JSONB
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        NULL::NUMERIC,
        NULL::VARCHAR(30),
        p_created_by_user_id,
        p_services
    );
END;
$$;

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id          BIGINT,
    p_property_id       BIGINT,
    p_check_in          DATE,
    p_check_out         DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id,
        NULL::JSONB
    );
END;
$$;

-- The former name described workflow rather than domain intent. Scenario 02
-- remains unchanged as history; only the final installed API removes it.
DROP FUNCTION IF EXISTS process_booking(
    BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT, JSONB
);
DROP FUNCTION IF EXISTS process_booking(
    BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT
);
