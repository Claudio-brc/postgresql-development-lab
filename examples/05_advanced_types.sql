--------------------------------------------------------------------------------
-- Function: create_property()
--
-- Description:
--   Creates a new property using the values provided in a property_request
--   composite type.
--
-- Parameters:
--   p_property PROPERTY_REQUEST - Composite value containing the property's
--                                 information.
--
-- Returns:
--   The ID of the newly created property as BIGINT.
--------------------------------------------------------------------------------

SELECT create_property(
    ROW(
        'Lake View Cabin',
        180.00,
        TRUE
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