The trigger functions in this scenario are executed automatically during
reservation updates.

To observe their behavior:

- Run the examples from 02_functions_business_rules.
- Verify that:
  - updated_at is automatically refreshed.
  - Reservation status changes are recorded in reservation_status_audit.
  - Invalid status transitions raise exceptions.