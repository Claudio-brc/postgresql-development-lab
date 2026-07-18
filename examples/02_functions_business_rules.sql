--------------------------------------------------------------------------------
-- Function: calculate_booking_discount()
--
-- Description:
--   Calculates the final booking amount by applying the highest applicable
--   active discount based on the stay length or check-in date.
--
-- Parameters:
--   p_total_amount NUMERIC - Total booking amount before discounts.
--   p_nights INTEGER       - Number of nights in the reservation.
--   p_check_in DATE        - Reservation check-in date.
--
-- Returns:
--   The discounted booking amount as NUMERIC.
--   Returns the original amount if no applicable discount is found.
--   Raises an exception if the input values are invalid.
--------------------------------------------------------------------------------

SELECT calculate_booking_discount(
    1500.00,
    7,
    DATE '2026-08-10'
);

--------------------------------------------------------------------------------
-- Function: validate_booking_dates()
--
-- Description:
--   Validates the booking dates according to the business rules for minimum
--   and maximum stay length.
--
-- Parameters:
--   p_check_in_date DATE  - Reservation check-in date.
--   p_check_out_date DATE - Reservation check-out date.
--
-- Returns:
--   TRUE if the booking dates are valid.
--   Raises an exception if any validation rule is violated.
--------------------------------------------------------------------------------

SELECT validate_booking_dates(
    DATE '2026-08-10',
    DATE '2026-08-15'
);

--------------------------------------------------------------------------------
-- Function: can_guest_book()
--
-- Description:
--   Determines whether a guest is allowed to create a new reservation based
--   on the maximum number of pending reservations permitted.
--
-- Parameters:
--   p_guest_id BIGINT - Guest identifier.
--
-- Returns:
--   TRUE if the guest is eligible to make a new reservation.
--   Raises an exception if the guest does not exist or has reached the
--   maximum number of pending reservations.
--------------------------------------------------------------------------------

SELECT can_guest_book(
    1
);

--------------------------------------------------------------------------------
-- Function: calculate_booking_total()
--
-- Description:
--   Calculates the final booking amount by validating the booking dates,
--   computing the base stay cost, and applying any applicable discounts.
--
-- Parameters:
--   p_property_id BIGINT - Property identifier.
--   p_check_in DATE      - Reservation check-in date.
--   p_check_out DATE     - Reservation check-out date.
--
-- Returns:
--   The final booking amount as NUMERIC.
--   Raises an exception if the booking dates are invalid or the property
--   cannot be processed.
--------------------------------------------------------------------------------

SELECT calculate_booking_total(
    1,
    DATE '2026-08-18',
    DATE '2026-08-20'
);

--------------------------------------------------------------------------------
-- Function: create_reservation()
--
-- Description:
--   Creates a new reservation after validating the booking dates, verifying
--   property availability, confirming guest eligibility, and calculating the
--   total booking amount.
--
-- Parameters:
--   p_guest_id BIGINT      - Guest identifier.
--   p_property_id BIGINT   - Property identifier.
--   p_check_in DATE        - Reservation check-in date.
--   p_check_out DATE       - Reservation check-out date.
--
-- Returns:
--   The ID of the newly created reservation as BIGINT.
--   Raises an exception if any validation or business rule fails.
--------------------------------------------------------------------------------

SELECT create_reservation(
    1,
    1,
    DATE '2026-08-10',
    DATE '2026-08-17'
);


--------------------------------------------------------------------------------
-- Function: process_booking()
--
-- Description:
--   Processes a complete booking by creating the reservation, validating the
--   payment amount, recording the payment, and confirming the reservation.
--
-- Parameters:
--   p_guest_id BIGINT                 - Guest identifier.
--   p_property_id BIGINT              - Property identifier.
--   p_check_in DATE                   - Reservation check-in date.
--   p_check_out DATE                  - Reservation check-out date.
--   p_payment_amount NUMERIC(12,2)    - Payment amount for the reservation.
--   p_payment_method VARCHAR(30)      - Payment method.
--
-- Returns:
--   The ID of the confirmed reservation as BIGINT.
--   Raises an exception if the payment information is invalid or any booking
--   validation fails.
--------------------------------------------------------------------------------

SELECT process_booking(
    1,
    1,
    DATE '2026-08-18',
    DATE '2026-08-20',
    240.00,
    'CREDIT_CARD'
);

