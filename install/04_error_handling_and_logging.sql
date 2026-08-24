------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 04_error_handling_and_logging
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_try_create_reservation.sql
------------------------------------------------------------

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



------------------------------------------------------------
-- Source: 02_try_create_reservation_with_logging.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION try_create_reservation_with_logging(
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
    v_sqlstate      VARCHAR(10);
    v_error_message TEXT;
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate := RETURNED_SQLSTATE,
            v_error_message := MESSAGE_TEXT;

        INSERT INTO error_log (
            sql_state,
            error_message,
            function_name
        )
        VALUES (
            v_sqlstate,
            v_error_message,
            'try_create_reservation_with_logging'
        );

        -- This function returns NULL when reservation creation fails.
        -- The caller decides whether the failure should be raised again.
        RETURN NULL;
END;
$$;




