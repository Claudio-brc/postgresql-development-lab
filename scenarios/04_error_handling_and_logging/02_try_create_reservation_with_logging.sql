CREATE OR REPLACE FUNCTION try_create_reservation_with_logging(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE
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
        p_check_out
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

        RAISE;
END;
$$;