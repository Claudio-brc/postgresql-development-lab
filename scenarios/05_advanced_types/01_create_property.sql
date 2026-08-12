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
        is_active,
        property_type,
        property_code,
        metadata
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        COALESCE(p_property.is_active, TRUE),
        p_property.property_type,
        p_property.property_code,
        p_property.metadata
    )
    RETURNING property_id
    INTO v_property_id;

    RETURN v_property_id;
END;
$$;
