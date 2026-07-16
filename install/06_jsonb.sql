------------------------------------------------------------
-- Source: 01_update_property_metadata.sql
------------------------------------------------------------

-- FUNCTION: public.update_property_metadata(bigint, jsonb)

-- DROP FUNCTION IF EXISTS public.update_property_metadata(bigint, jsonb);

CREATE OR REPLACE FUNCTION public.update_property_metadata(
	p_property_id bigint,
	p_metadata jsonb)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
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
$BODY$;

ALTER FUNCTION public.update_property_metadata(bigint, jsonb)
    OWNER TO postgres;

/*

SELECT update_property_metadata(
    1,
    '{
        "amenities": {
            "wifi": true,
            "parking": false,
            "air_conditioning": true,
            "smart_tv": true
        },
        "languages": [
            "English",
            "Spanish"
        ],
        "check_in": {
            "from": "15:00",
            "to": "22:00"
        },
        "house_rules": {
            "pets_allowed": false,
            "smoking": false
        }
    }'::jsonb
);


*/
	




------------------------------------------------------------
-- Source: 02_jsonb_queries.sql
------------------------------------------------------------

/*
==========================================
Retrieve the complete metadata document
==========================================
*/


/*
SELECT
    property_name,
    metadata
FROM properties
where metadata is not null;
*/


/*
==========================================
Access a top-level object
==========================================
*/


/*
SELECT
    property_name,
    metadata -> 'amenities' AS amenities
FROM properties
where metadata is not null;
*/


/*
==========================================
Extract a scalar value
==========================================
*/

/*

SELECT
    property_name,
    metadata ->> 'languages' AS languages
FROM properties
where metadata is not null;
*/



/*
==========================================
Access nested values
==========================================
*/


/*
SELECT
    property_name,
    metadata -> 'check_in' ->> 'from' AS check_in_from,
    metadata -> 'check_in' ->> 'to'   AS check_in_to
FROM properties
where metadata is not null;
*/


/*
==========================================
Filter: Properties that allow pets
==========================================
*/

/*
SELECT
    property_name
FROM properties
WHERE metadata -> 'house_rules' ->> 'pets_allowed' = 'false';
*/

------------------------------------------------------------
-- Source: 03_update_jsonb_fields.sql
------------------------------------------------------------

/*

SELECT jsonb_set(
    '{"amenities":{"wifi":true,"parking":false}}'::jsonb,
    '{amenities,parking}',
    'true'::jsonb
);

*/

/*

result:

{
  "amenities": {
    "wifi": true,
    "parking": true
  }
}


*/

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



------------------------------------------------------------
-- Source: 04_how_jsonb_set_works.sql
------------------------------------------------------------

/*
SELECT jsonb_set(
    '{"amenities":{"wifi":true,"parking":false}}'::jsonb,
    '{amenities,parking}',
    'true'::jsonb
);
*/

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

-- DROP FUNCTION IF EXISTS public.add_services_to_reservation(bigint, JSONB);

CREATE OR REPLACE FUNCTION public.add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services JSONB
)
    RETURNS void
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
	v_service_id BIGINT;
	v_service    JSONB;
	v_unit_price NUMERIC;
	v_quantity   INTEGER; 
BEGIN

  IF NOT EXISTS (
    SELECT 1
    FROM reservations
    WHERE reservation_id = p_reservation_id) THEN
    
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

  DELETE FROM reservation_services 
    WHERE reservation_id = p_reservation_id;



  FOR v_service IN
    SELECT *
    FROM jsonb_array_elements(p_services)
  LOOP

    v_service_id := (v_service ->> 'service_id')::BIGINT;
    v_quantity   := (v_service ->> 'quantity')::INTEGER;

    SELECT price
	  INTO v_unit_price
      FROM services   
	 WHERE service_id = v_service_id;

    IF v_unit_price IS NULL THEN
	  RAISE EXCEPTION 'Service % not found.', v_service_id;
	END IF;  

	INSERT INTO public.reservation_services(
	 reservation_id, service_id, quantity, unit_price)
	VALUES ( p_reservation_id,v_service_id, v_quantity , v_unit_price);

    
  END LOOP;  

END;
$BODY$;

ALTER FUNCTION public.add_services_to_reservation(bigint, JSONB)
    OWNER TO postgres;





