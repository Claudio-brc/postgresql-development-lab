CREATE OR REPLACE FUNCTION update_property_parking(
    p_property_id BIGINT,
    p_has_parking BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM properties
        WHERE property_id = p_property_id
    ) THEN
        RAISE EXCEPTION
            'Property % not found.',
            p_property_id;
    END IF;

    -- Replace the complete "amenities" object so a missing intermediate key can
    -- be created while preserving any existing amenity values.
    UPDATE properties
    SET metadata = jsonb_set(
        COALESCE(metadata, '{}'::jsonb),
        '{amenities}',
        COALESCE(metadata -> 'amenities', '{}'::jsonb)
            || jsonb_build_object('parking', p_has_parking)
    )
    WHERE property_id = p_property_id;
END;
$$;
