--------------------------------------------------------------------------------
-- Function: create_property()
--
-- Description:
--   Creates a new property using the values provided in a property_request
--   composite type.
--
-- Parameters:
--   p_property PROPERTY_REQUEST - Composite value containing the property's
--                                 name, rate, active status, type, optional
--                                 code, and optional JSONB metadata.
--
-- Returns:
--   The ID of the newly created property as BIGINT.
--------------------------------------------------------------------------------

-- NULL property_code delegates code generation to trg_properties_set_property_code.
SELECT create_property(
    ROW(
        'Advanced Types Cabin',
        180.00,
        TRUE,
        'CABIN',
        NULL,
        '{
            "amenities": {
                "wifi": true,
                "parking": true,
                "air_conditioning": false,
                "smart_tv": true
            },
            "languages": ["Spanish", "English"],
            "house_rules": {
                "smoking": false,
                "pets_allowed": true
            },
            "arrival_departure": {
                "check_in_from": "15:00",
                "check_in_to": "22:00",
                "check_out_until": "11:00"
            }
        }'::JSONB
    )::property_request
);

-- Manual codes are accepted and normalized by the same trigger.
SELECT create_property(
    ROW(
        'Advanced Types Apartment',
        135.00,
        TRUE,
        'APARTMENT',
        'adv-9000',
        '{
            "amenities": {
                "wifi": true,
                "parking": false,
                "air_conditioning": true,
                "smart_tv": true
            },
            "languages": ["Spanish", "English"],
            "house_rules": {
                "smoking": false,
                "pets_allowed": false
            },
            "arrival_departure": {
                "check_in_from": "14:00",
                "check_in_to": "21:00",
                "check_out_until": "10:00"
            }
        }'::JSONB
    )::property_request
);

--------------------------------------------------------------------------------
-- Function: get_reservation_summary()
--
-- Description:
--   Retrieves a reservation summary as a reservation_summary composite type,
--   including guest, property, amount, and status information.
--
-- Parameters:
--   p_reservation_id BIGINT - Reservation identifier.
--
-- Returns:
--   A RESERVATION_SUMMARY composite value containing the reservation details.
--   Returns NULL if the reservation is not found.
--------------------------------------------------------------------------------

SELECT get_reservation_summary(
    1
);

--------------------------------------------------------------------------------
-- Function: add_services_to_reservation()
--
-- Description:
--   Replaces the services associated with a reservation using the provided
--   array of service IDs. Repeated IDs are consolidated and their number of
--   occurrences is stored as the service quantity.
--
-- Parameters:
--   p_reservation_id BIGINT   - Reservation identifier.
--   p_service_ids BIGINT[]    - Array of service identifiers to associate with
--                               the reservation.
--
-- Returns:
--   No value.
--   Raises an exception if the reservation or any specified service does not
--   exist.
--------------------------------------------------------------------------------

SELECT add_services_to_reservation(
    1,
    ARRAY[1, 1, 2, 3]
);






