--------------------------------------------------------------------------------
-- Function: calculate_stay_cost()
--
-- Description:
--   Calculates the total accommodation cost based on the property's nightly
--   rate and the number of nights between the check-in and check-out dates.
--
-- Returns:
--   The total stay cost as NUMERIC(16,6).
--   Raises an exception if the dates are invalid or the property does not exist.
--------------------------------------------------------------------------------

SELECT calculate_stay_cost(
    1,
    DATE '2026-08-10',
    DATE '2026-08-15'
);

--------------------------------------------------------------------------------
-- Function: is_property_available()
--
-- Description:
--   Checks whether a property is available for the specified date range by
--   verifying that no overlapping reservations exist.
--
-- Returns:
--   TRUE if the property is available for booking.
--   FALSE if an overlapping reservation exists.
--   Raises an exception if the dates are invalid or the property does not exist.
--------------------------------------------------------------------------------

SELECT is_property_available(
    1,
    DATE '2026-08-10',
    DATE '2026-08-15'
);

--------------------------------------------------------------------------------
-- Function: show_guest_reservations()
--
-- Description:
--   Returns all reservations associated with the specified guest, including
--   property information, stay dates, and reservation status.
--
-- Returns:
--   A table containing the reservation ID, property name, check-in date,
--   check-out date, and reservation status.
--   Raises an exception if the guest does not exist.
--------------------------------------------------------------------------------

SELECT *
FROM show_guest_reservations(
    1
);
