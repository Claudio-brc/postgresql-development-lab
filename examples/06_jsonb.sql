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
            "Spanish",
            "English"
        ],
        "house_rules": {
            "smoking": false,
            "pets_allowed": false
        },
        "arrival_departure": {
            "check_in_from": "15:00",
            "check_in_to": "22:00",
            "check_out_until": "11:00"
        }
    }'::jsonb
);

--------------------------------------------------------------------------------
-- Function: update_property_parking()
--
-- Description:
-- Updates the parking amenity flag within the metadata JSONB document of a
-- specific property. Missing metadata or amenities objects are initialized.
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
-- - Uses jsonb_set() to replace the amenities object while preserving its
--   existing values and changing only parking.
-- - COALESCE ensures the operation works if metadata or amenities is missing.
-- - The function returns VOID; use SELECT to execute it.
--------------------------------------------------------------------------------

SELECT update_property_parking(1, FALSE);

--------------------------------------------------------------------------------
-- Function: replace_reservation_services()
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
--   The reservation's total, paid amount, and balance.
--   Raises an exception if the reservation does not exist, the JSON document
--   is invalid, any specified service does not exist, or a service is repeated.
--------------------------------------------------------------------------------

SELECT * FROM replace_reservation_services(
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


