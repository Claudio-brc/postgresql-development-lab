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
--   Raises an exception if the reservation is not found.
--------------------------------------------------------------------------------

SELECT get_reservation_summary(
    1
);

--------------------------------------------------------------------------------
-- Function: replace_reservation_services()
--
-- Description:
--   Replaces the services associated with a reservation using the canonical
--   JSONB service collection.
--
-- Parameters:
--   p_reservation_id BIGINT   - Reservation identifier.
--   p_services JSONB          - Service identifiers and explicit quantities.
--
-- Returns:
--   The reservation's total, paid amount, and balance.
--   Raises an exception if the reservation or any specified service does not
--   exist.
--------------------------------------------------------------------------------

SELECT * FROM replace_reservation_services(
    1,
    '[{"service_id": 1, "quantity": 2},
      {"service_id": 2, "quantity": 1},
      {"service_id": 3, "quantity": 1}]'::JSONB
);






