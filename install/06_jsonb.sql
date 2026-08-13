------------------------------------------------------------
-- PostgreSQL Development Lab
-- Scenario: 06_jsonb
--
-- AUTO-GENERATED FILE
-- DO NOT EDIT MANUALLY
------------------------------------------------------------

------------------------------------------------------------
-- Source: 01_update_property_metadata.sql
------------------------------------------------------------

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


------------------------------------------------------------
-- Source: 02_jsonb_queries.sql
------------------------------------------------------------

/*
==========================================
Retrieve the complete metadata document
==========================================
*/

SELECT
    property_name,
    metadata
FROM properties
where metadata is not null;

/*
==========================================
Access a top-level object
==========================================
*/

SELECT
    property_name,
    metadata -> 'amenities' AS amenities
FROM properties
where metadata is not null;

/*
==========================================
Access a top-level array
==========================================
*/

SELECT
    property_name,
    metadata -> 'languages' AS languages
FROM properties
where metadata is not null;

/*
==========================================
Access nested values
==========================================
*/

SELECT
    property_name,
    metadata -> 'arrival_departure' ->> 'check_in_from'    AS check_in_from,
    metadata -> 'arrival_departure' ->> 'check_in_to'      AS check_in_to,
    metadata -> 'arrival_departure' ->> 'check_out_until'  AS check_out_until
FROM properties
where metadata is not null;

/*
==========================================
Filter: Properties that do not allow pets
==========================================
*/

SELECT
    property_name
FROM properties
WHERE metadata -> 'house_rules' ->> 'pets_allowed' = 'false';



------------------------------------------------------------
-- Source: 03_update_jsonb_fields.sql
------------------------------------------------------------

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



------------------------------------------------------------
-- Source: 04_how_jsonb_set_works.sql
------------------------------------------------------------

SELECT jsonb_set(
    '{"amenities":{"wifi":true,"parking":false}}'::jsonb,
    '{amenities,parking}',
    'true'::jsonb
);


/*

result:

{
  "amenities": {
    "wifi": true,
    "parking": true
  }
}


*/


------------------------------------------------------------
-- Source: 05_add_services_to_reservation_jsonb.sql
------------------------------------------------------------

CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services       JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_service_id BIGINT;
    v_service    JSONB;
    v_unit_price NUMERIC;
    v_quantity   INTEGER;
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM reservations
        WHERE reservation_id = p_reservation_id
    ) THEN
        RAISE EXCEPTION
            'Reservation % not found.',
            p_reservation_id;
    END IF;

    IF p_services IS NULL THEN
        RETURN;
    END IF;

    IF jsonb_typeof(p_services) <> 'array' THEN
        RAISE EXCEPTION
            'Expected a JSON array.';
    END IF;

    IF jsonb_array_length(p_services) = 0 THEN
        RETURN;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM jsonb_array_elements(p_services) AS item(service_data)
        GROUP BY (service_data ->> 'service_id')::BIGINT
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'The service list contains repeated services.';
    END IF;

    DELETE FROM reservation_services
    WHERE reservation_id = p_reservation_id;

    FOR v_service IN
        SELECT *
        FROM jsonb_array_elements(p_services)
    LOOP
        v_service_id := (v_service ->> 'service_id')::BIGINT;
        v_quantity := (v_service ->> 'quantity')::INTEGER;

        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            RAISE EXCEPTION
                'Service quantity must be greater than zero.';
        END IF;

        SELECT price
        INTO v_unit_price
        FROM services
        WHERE service_id = v_service_id;

        IF v_unit_price IS NULL THEN
            RAISE EXCEPTION 'Service % not found.', v_service_id;
        END IF;

        INSERT INTO reservation_services (
            reservation_id,
            service_id,
            quantity,
            unit_price
        )
        VALUES (
            p_reservation_id,
            v_service_id,
            v_quantity,
            v_unit_price
        );
    END LOOP;
END;
$$;




