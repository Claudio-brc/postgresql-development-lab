--------------------------------------------------------------------------------
-- Function: update_property_metadata()
--
-- Description:
--   Updates the metadata associated with a property using a JSONB document.
--
-- Parameters:
--   p_property_id BIGINT - Property identifier.
--   p_metadata JSONB     - JSON document containing the property metadata.
--
-- Returns:
--   No value.
--   Raises an exception if the property does not exist.
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Procedure: update_property_parking()
--
-- Description:
-- Updates the parking amenity flag within the metadata JSONB document of a
-- specific property. The procedure assumes the metadata document has already
-- been initialized (or will be created with COALESCE).
-- If the property does not exist, an exception is raised.
--
-- Parameters:
-- p_property_id BIGINT - Identifier of the property to update.
-- p_has_parking BOOLEAN - New parking availability value to set
-- (true = available, false = not available).
--
-- Returns:
-- VOID - No return value. The update is applied directly to the properties table.
--
-- Notes:
-- - Uses jsonb_set() to navigate the nested path '{amenities,parking}'.
-- - COALESCE(metadata, '{}'::jsonb) ensures the operation works even if the metadata column is NULL.
-- - The procedure does not return any value; use SELECT or CALL to execute it.
--------------------------------------------------------------------------------

SELECT update_property_parking(1, FALSE);

--------------------------------------------------------------------------------
-- Function: add_services_to_reservation()
--
-- Description:
--   Replaces the services associated with a reservation using a JSONB array
--   containing service identifiers and quantities.
--
-- Parameters:
--   p_reservation_id BIGINT - Reservation identifier.
--   p_services JSONB        - JSON array of service objects. Each object must
--                             contain a service_id and quantity.
--
-- Returns:
--   No value.
--   Raises an exception if the reservation does not exist, the JSON document
--   is invalid, or any specified service does not exist.
--------------------------------------------------------------------------------

SELECT add_services_to_reservation(
    1,
    '[
        {
            "service_id": 1,
            "quantity": 2
        },
        {
            "service_id": 3,
            "quantity": 1
        }
    ]'::jsonb
);


