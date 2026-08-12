-- Apply after 002_add_property_code.sql.

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'property_request'::REGCLASS
          AND attname = 'property_code'
          AND NOT attisdropped
    ) THEN
        ALTER TYPE property_request
            ADD ATTRIBUTE property_code VARCHAR(10);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_attribute
        WHERE attrelid = 'property_request'::REGCLASS
          AND attname = 'metadata'
          AND NOT attisdropped
    ) THEN
        ALTER TYPE property_request
            ADD ATTRIBUTE metadata JSONB;
    END IF;
END;
$$;

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
