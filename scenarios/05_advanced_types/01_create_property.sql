CREATE OR REPLACE FUNCTION create_property(
    p_property property_request
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id BIGINT;
BEGIN
    INSERT INTO properties (
        property_name,
        nightly_rate,
        is_active
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        p_property.is_active
    )
    RETURNING property_id
    INTO v_property_id;

    RETURN v_property_id;
END;
$$;