# Reservation Economic Lifecycle

## Overview

This scenario integrates accommodation, reservation-service snapshots, and
payments into one economic lifecycle. It evolves earlier teaching functions
without changing their original scenario source files.

All stored and calculated money values use six-decimal precision. The `0.01`
tolerance is used only when deciding whether one payment settles the complete
outstanding balance; totals and balances are not rounded to cents first.

## Economic values

- `calculate_reservation_total(BIGINT)` recalculates accommodation plus service
  snapshots and returns `NUMERIC(16,6)`.
- `calculate_reservation_amount_paid(BIGINT)` sums only `PAID` payment rows and
  returns `NUMERIC(16,6)`.
- `calculate_reservation_balance(BIGINT)` subtracts paid money from the stored
  reservation total and returns `NUMERIC(16,6)`. Negative balances remain
  visible.

`amount_paid` and `balance_due` are derived values, not table columns.

## Supported write path

Use `replace_reservation_services(BIGINT, JSONB)` for service replacement. It
locks the reservation, validates the complete request before changing rows,
snapshots active service prices, persists the recalculated total, and returns:

```text
reservation_id BIGINT
reservation_total NUMERIC(16,6)
amount_paid NUMERIC(16,6)
balance_due NUMERIC(16,6)
```

The JSONB shape is:

```json
[
  { "service_id": 1, "quantity": 2 },
  { "service_id": 3, "quantity": 1 }
]
```

`NULL` leaves services and the persisted total unchanged. `[]` explicitly
clears services and recalculates the accommodation-only total. The earlier
`add_services_to_reservation` teaching overloads are removed from the final
API; callers use this canonical JSONB operation directly.

Service changes are allowed for `PENDING` and `CONFIRMED` reservations through
checkout day. They are rejected for `CANCELLED` reservations and after
checkout. Existing snapshots do not follow later catalog price changes.

## Creation and payment

`initialize_reservation` owns validation and `PENDING` creation. Its five-
argument form creates an accommodation-only reservation; its six-argument
form accepts the optional JSONB services collection and persists the complete
accommodation-plus-snapshot total.

`process_reservation_payment(BIGINT, NUMERIC, VARCHAR)` locks an existing
reservation, requires the complete positive balance within the settlement
tolerance, stores a six-decimal `PAID` payment, and confirms a `PENDING`
reservation. It returns the new payment ID. It does not change old payments.

`create_reservation` is the public creation operation. Its five- and six-
argument forms initialize without payment and return a `PENDING` reservation.
Its seven- and eight-argument forms retain the former `process_booking`
parameter order, optionally include services, settle the complete balance, and
return a `CONFIRMED` reservation. Payment amount and method must either both be
`NULL` or both be supplied. The obsolete `process_booking` name is removed in
this final scenario.

Payments may settle an existing balance after checkout, but cancelled
reservations reject payments. Domain functions are the supported write path;
direct table writes do not automatically recalculate totals.
