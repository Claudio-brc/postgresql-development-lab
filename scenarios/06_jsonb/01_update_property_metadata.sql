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
	

