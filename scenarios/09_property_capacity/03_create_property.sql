-- The two-argument form accepts capacity explicitly. The original composite
-- overload remains operational and creates a one-guest property.
CREATE OR REPLACE FUNCTION create_property(
    p_property property_request,
    p_max_guests INTEGER
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_property_id BIGINT;
BEGIN
    IF p_max_guests IS NULL OR p_max_guests <= 0 THEN
        RAISE EXCEPTION 'Maximum guest capacity must be greater than zero.';
    END IF;

    INSERT INTO properties (
        property_name,
        nightly_rate,
        max_guests,
        is_active,
        property_type,
        property_code,
        metadata
    )
    VALUES (
        p_property.property_name,
        p_property.nightly_rate,
        p_max_guests,
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

CREATE OR REPLACE FUNCTION create_property(
    p_property property_request
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_property(p_property, 1);
END;
$$;
