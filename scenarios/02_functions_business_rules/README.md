# Business Rules

## Overview

This module contains the core business logic of the booking system.

The implemented functions are responsible for validating business rules, calculating booking costs, applying discounts, and executing the complete reservation workflow.

## Implemented Functions

### calculate_booking_discount()

Calculates the final booking amount by applying the highest active discount that matches the booking conditions.

Supported discount types include:

* Stay length discounts.
* Date range promotions.

### validate_booking_dates()

Validates the booking dates according to the business rules.

Validation includes:

* Non-null dates.
* Check-out date after check-in date.
* Minimum stay of one night.
* Maximum stay of thirty nights.

### can_guest_book()

Determines whether a guest is allowed to create a new reservation.

Currently, a guest cannot have three or more pending reservations.

### calculate_booking_total()

Calculates the total reservation amount by combining:

* Stay cost.
* Applicable discounts.

### create_reservation()

Creates a reservation after validating:

* Booking dates.
* Property availability.
* Guest eligibility.

The reservation is initially created with the `PENDING` status.

The function returns the generated reservation identifier.

### process_booking()

Executes the complete booking workflow.

The process performs the following operations:

1. Creates the reservation.
2. Validates the payment amount.
3. Registers the payment.
4. Updates the reservation status to `CONFIRMED`.

The function returns the created reservation identifier.

## Transaction Behavior

Business operations are implemented as PL/pgSQL functions.

When a function raises an exception, PostgreSQL automatically aborts the function execution and rolls back every data modification performed during that invocation.

Because of this behavior, explicit `COMMIT` and `ROLLBACK` statements are not required inside these business functions.

In a typical application architecture, transaction boundaries are managed by the application layer, while PL/pgSQL functions remain focused on implementing business logic.
