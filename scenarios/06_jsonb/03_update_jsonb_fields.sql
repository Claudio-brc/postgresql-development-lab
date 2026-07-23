-- This example assumes the metadata document has already been initialized.

CREATE OR REPLACE FUNCTION update_property_parking(
    p_property_id BIGINT,
    p_has_parking BOOLEAN
)
RETURNS VOID AS $$
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
       SET metadata = jsonb_set(
            COALESCE(metadata, '{}'::jsonb),
            '{amenities,parking}',
            to_jsonb(p_has_parking)
       )
     WHERE property_id = p_property_id;

END;
$$ LANGUAGE plpgsql;
