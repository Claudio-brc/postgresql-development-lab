CREATE OR REPLACE FUNCTION try_create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE,
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
        p_created_by_user_id
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION
            'Invalid guest, property, or user identifier.';

    WHEN check_violation THEN
        RAISE EXCEPTION
            'Reservation data violates database constraints.';
END;
$$;
