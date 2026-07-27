CREATE OR REPLACE FUNCTION update_property_metadata(
    p_property_id BIGINT,
    p_metadata    JSONB
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

    UPDATE properties
    SET metadata = p_metadata
    WHERE property_id = p_property_id;
END;
$$;