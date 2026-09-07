# REQ-003 — Reservation economic lifecycle

Status: implemented; creation API refactored and validated on 2026-09-04.

## Objective

Evolve the model, after reservation services and JSONB have been introduced, so
that a reservation's current economic total includes its accommodation and its
service price snapshots. Payments remain immutable records of money actually
paid, while the amount paid and outstanding balance are calculated from the
authoritative reservation and payment data.

The target calculation is:

```text
reservation total
  = calculate_booking_total(property, dates)
  + SUM(reservation_services.quantity * reservation_services.unit_price)

amount paid
  = SUM(payments.payment_amount WHERE payments.status = 'PAID')

balance due
  = reservations.total_amount - amount paid
```

No `amount_paid` or `balance_due` columns will be added. Existing payment rows
will never be resized when the reservation total changes.

## Repository findings

The current progression is relevant to the design:

1. Scenario 02 introduces `calculate_booking_total`, `create_reservation`, and
   `process_booking` before services exist in the learning sequence.
2. Scenario 05 introduces the ARRAY overload of
   `add_services_to_reservation`. It replaces the service set and consolidates
   repeated identifiers into quantities.
3. Scenario 06 introduces the JSONB overload. It accepts explicit quantities
   and rejects repeated service identifiers.
4. Both overloads snapshot `services.price` into
   `reservation_services.unit_price`, but neither updates
   `reservations.total_amount`.
5. The ARRAY overload deletes existing rows before testing its argument, so
   both `NULL` and an empty array clear the service set. The JSONB overload
   returns before deletion for both `NULL` and `[]`, so both are no-ops.
6. `process_booking` always creates a reservation, requires one payment within
   the existing `0.01` tolerance of the full total, records it as `PAID`, and
   confirms the reservation.
7. Payment statuses are `PENDING`, `PAID`, and `REFUNDED`. Only `PAID`
   represents an effective payment in the present model. A `REFUNDED` row is
   excluded rather than subtracted because payment amounts cannot be negative
   and the model has no separate refund transaction.

## Implemented scenario placement

The new `07_reservation_economic_lifecycle` scenario runs after
advanced types and JSONB, allowing it to evolve earlier functions without
rewriting the files that teach their original form.

Scenario 02 will continue to show accommodation-only booking. Scenarios 05 and
06 will continue to show the historical introduction of service assignment.
Scenario 07 will redefine the affected functions into their final integrated
form and explain why the behavior evolves at that point.

## Implemented public contracts

### Economic calculations

The implementation adds these reusable functions:

```text
calculate_reservation_total(BIGINT)       -> NUMERIC
calculate_reservation_amount_paid(BIGINT) -> NUMERIC
calculate_reservation_balance(BIGINT)     -> NUMERIC
```

`calculate_reservation_total` loads the reservation, calls the existing
`calculate_booking_total(property_id, check_in_date, check_out_date)`, adds the
service subtotal from reservation snapshots, and returns a value explicitly
cast to `NUMERIC(16,6)`. It raises a not-found exception for an invalid
reservation identifier.

`calculate_reservation_amount_paid` sums only `PAID` payment rows and returns
six-decimal zero when none exist. `calculate_reservation_balance` subtracts
that value from the persisted `reservations.total_amount`. The balance is not
clamped at zero, so unexpected overpayment remains visible instead of being
hidden.

All reservation totals, paid amounts, balances, and payment values are
calculated and stored at six-decimal precision. The `0.01` constant is only a
settlement tolerance in `process_reservation_payment`; neither operand is
rounded to two decimal places before that comparison.

### Service replacement

The canonical domain operation is:

```text
replace_reservation_services(BIGINT, JSONB)
  -> TABLE (
       reservation_id BIGINT,
       reservation_total NUMERIC,
       amount_paid NUMERIC,
       balance_due NUMERIC
     )
```

The JSONB representation uses the same shape taught in scenario 06:

```json
[
  { "service_id": 1, "quantity": 2 },
  { "service_id": 3, "quantity": 1 }
]
```

The operation:

1. lock and validate the reservation;
2. reject `CANCELLED` reservations;
3. reject reservations for which `check_out_date < CURRENT_DATE`;
4. validate the entire JSONB collection before deleting current services;
5. reject non-array documents, malformed objects, missing identifiers,
   non-positive/non-integer quantities, repeated services, services that do not
   exist, and inactive catalog services;
6. replace the service rows and snapshot the current catalog price;
7. recalculate and persist the complete reservation total;
8. return the resulting total, paid amount, and balance.

The implemented collection semantics are:

- `NULL`: do not change the service set; still return the current economic
  state;
- `[]`: explicitly replace the service set with no services and recalculate the
  accommodation-only total;
- non-empty array: replace the complete service set.

This distinction makes omitted optional input safe and gives callers an
explicit way to clear services. It intentionally normalizes the inconsistent
legacy overload behavior at the later evolution point.

The earlier `add_services_to_reservation` overloads remain in scenarios 05 and
06 as progressive teaching history. Scenario 07 removes them from the final
API: `replace_reservation_services` is the single supported service write path,
with explicit JSONB quantities and a returned economic-state projection.

### Reservation creation

Scenario 07 renames the lower-level operation to:

```text
initialize_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)        -> BIGINT
initialize_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT, JSONB) -> BIGINT
```

It validates dates, property availability, guest eligibility, and creator
ownership; inserts the `PENDING` reservation; invokes canonical service
replacement when services are supplied; and persists the complete discounted
accommodation-plus-snapshot total. PostgreSQL function execution provides
atomicity: any validation, insert, or service failure rolls back the statement.

The public operation is now `create_reservation`, with four unambiguous forms:

```text
create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)
create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT, JSONB)
create_reservation(BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT)
create_reservation(BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT, JSONB)
```

The five- and six-argument forms initialize without payment and return a
`PENDING` reservation. The seven- and eight-argument forms preserve the former
`process_booking` parameter order and optionally settle the initialized
reservation. Both payment fields must be absent or supplied together.

The error-handling wrappers from scenario 04 did not need new signatures for
this requirement. Their existing five-argument calls continue through the
public unpaid `create_reservation` form. Service-aware error translation can be
added in a future error-handling evolution if required.

### Payment processing

The implementation adds:

```text
process_reservation_payment(BIGINT, NUMERIC, VARCHAR) -> BIGINT
```

The return value is the new `payment_id`. The function locks and
validates the reservation, rejects `CANCELLED` reservations, requires a positive
amount and nonblank method, calculates the current balance, and requires the
payment to match the complete positive outstanding balance using the existing
`0.01` settlement tolerance. It then inserts a new `PAID` payment. It confirms a
`PENDING` reservation and leaves a `CONFIRMED` reservation confirmed.

Requiring settlement of the complete balance preserves the approved booking
behavior and supports the required follow-up payment without
expanding this change into partial-payment allocation or accounting. The
checkout-date restriction applies to changing services, not to settling an
already established balance.

Paid `create_reservation` delegates payment creation and confirmation to
`process_reservation_payment`. The obsolete `process_booking` overloads are
removed from the final API, but their scenario 02 definition remains as
progressive history.

No existing payment is updated when services change. A fully paid,
`CONFIRMED` reservation may therefore remain `CONFIRMED` with a positive
derived balance until the new payment operation settles it.

## Status and temporal rules

- `PENDING`: service replacement is allowed until checkout has passed.
- `CONFIRMED`: service replacement is allowed until checkout has passed,
  including when a previously zero balance becomes positive. Status remains
  `CONFIRMED`.
- `CANCELLED`: service replacement and new payment processing are rejected.
  Cancellation is terminal in the current model, and changing its economics
  without refund or adjustment concepts would create misleading history.
- In progress (`check_in_date <= CURRENT_DATE` and
  `check_out_date >= CURRENT_DATE`): service replacement is allowed.
- Finished (`check_out_date < CURRENT_DATE`): service replacement is rejected.
  A checkout occurring today has not yet passed under the specified rule.

## Concurrency and source-of-truth rules

Service replacement and payment processing lock the reservation row with
`SELECT ... FOR UPDATE`. This serializes economic changes for one reservation
and prevents two concurrent calls from calculating a final total or balance
from stale state.

Service totals will always use `reservation_services.unit_price`; later changes
to `services.price` will not change an existing snapshot. Replacing a service
set creates new snapshots at the catalog prices effective at replacement time.
Changing a catalog price alone will not trigger or imply reservation
recalculation.

Direct table writes can bypass domain functions in the current lab. This plan
does not add triggers that recalculate totals, because the requirement is an
evolution of the PostgreSQL domain API and trigger-based enforcement would add
a separate teaching concern. Examples and documentation will identify the
domain functions as the supported write path.

## Implemented files

### Added source files

- `scenarios/07_reservation_economic_lifecycle/README.md` — scenario purpose,
  progression, contracts, and rules.
- `scenarios/07_reservation_economic_lifecycle/01_calculate_reservation_total.sql`.
- `scenarios/07_reservation_economic_lifecycle/02_calculate_reservation_amount_paid.sql`.
- `scenarios/07_reservation_economic_lifecycle/03_calculate_reservation_balance.sql`.
- `scenarios/07_reservation_economic_lifecycle/04_replace_reservation_services.sql`.
- `scenarios/07_reservation_economic_lifecycle/05_remove_obsolete_service_wrappers.sql`.
- `scenarios/07_reservation_economic_lifecycle/06_initialize_reservation.sql`.
- `scenarios/07_reservation_economic_lifecycle/07_process_reservation_payment.sql`.
- `scenarios/07_reservation_economic_lifecycle/08_create_reservation.sql`.
- `schema/upgrades/008_reservation_economic_lifecycle.sql` — transactional,
  idempotence-aware upgrade of functions for an existing database.
- `examples/11_reservation_economic_lifecycle.sql` — executable assertions and
  lifecycle examples.

### Updated existing files

- `README.md` — list scenario 07, example 11, upgrade 008, and the evolved
  lifecycle behavior.
- This document records the final contracts, decisions, source files, and
  verification evidence.

No schema table or monetary column change was needed. The early scenario files
were not edited. The build scripts also needed no change because they discover
numbered scenario directories and SQL files automatically.

### Generated files

`tools/build-all.ps1` generated or updated:

- `install/07_reservation_economic_lifecycle.sql`;
- `install/postgresql-development-lab.sql`.

Generated files were not edited manually.

## Completed implementation sequence

1. Add the calculation functions and verify six-decimal result boundaries.
2. Add the canonical JSONB replacement function with reservation locking,
   whole-document validation, snapshot insertion, total update, and economic
   state return.
3. Remove the superseded ARRAY and JSONB service wrapper names from the final API.
4. Rename the validated `PENDING` creation operation to `initialize_reservation`.
5. Extract existing-reservation payment processing.
6. Evolve `process_booking` into public `create_reservation`, with paid and
   unpaid service-aware forms, and remove the obsolete name.
7. Add upgrade 008 with the same final function definitions and safe signature
   handling without `CASCADE`.
8. Add transactional examples and assertions.
9. Update the README and this requirement document.
10. Regenerate install scripts and validate clean installation and ordered
    upgrade paths in separate disposable PostgreSQL 17 databases.

## Implemented validation coverage

`examples/11_reservation_economic_lifecycle.sql` uses generated test rows,
relative dates around `CURRENT_DATE`, a transaction, and PL/pgSQL assertions so
it remains reproducible and rolls back its data. It covers:

1. unpaid creation without services (`PENDING`, accommodation total);
2. unpaid creation with JSONB services (`PENDING`, complete total);
3. paid creation with services (`CONFIRMED`, complete total, paid amount, and
   zero balance);
4. replacement, addition, and explicit clearing with `[]`;
5. the documented canonical `NULL` no-op behavior;
6. JSONB duplicate rejection;
7. paid amount derived only from `PAID` rows, with `PENDING` and `REFUNDED`
   excluded;
8. balance derivation without persisted redundant columns;
9. a fully paid `CONFIRMED` reservation receiving services, remaining
   `CONFIRMED`, acquiring a balance, and settling it with a new payment row;
10. proof that an old payment amount is unchanged after service replacement;
11. proof that changing `services.price` after assignment does not change the
    reservation total until a deliberate replacement takes a new snapshot;
12. service replacement for an in-progress reservation;
13. rejection after `check_out_date < CURRENT_DATE` and allowance when checkout
    is today;
14. rejection for `CANCELLED` reservations;
15. atomic rollback when any service item is invalid;
16. full-balance and payment-method validation, including atomic rejection of
    partial payment and overpayment during creation;
17. final function signatures and absence of obsolete wrappers;
18. clean installation and upgrade from schema version 007.

Expected-failure assertions catch `raise_exception` and verify the exact domain
message. They do not use unrestricted `WHEN OTHERS`, so an unrelated failure
cannot satisfy the test accidentally.

### Verification evidence

Validation was rerun on PostgreSQL 17 on 2026-09-04 in two uniquely named
disposable databases:

- Clean install: the regenerated
  `install/postgresql-development-lab.sql` completed with
  `ON_ERROR_STOP=1`, followed by `examples/11_reservation_economic_lifecycle.sql`
  (`BEGIN`, `DO`, `ROLLBACK`).
- Upgrade: a database containing the schema and scenarios through 06 (the
  version-007 state) accepted
  `schema/upgrades/008_reservation_economic_lifecycle.sql` with
  `ON_ERROR_STOP=1`, then passed the same transactional assertions.
- Upgrade repeatability: upgrade 008 was applied a second time successfully.
- Historical preservation: a pre-upgrade reservation-service snapshot was
  inserted while its stored total remained accommodation-only; applying
  upgrade 008 left both the stored total and snapshot rows unchanged.
- Final-scenario repeatability: scenario 07 was reapplied over the clean final
  state and the transactional lifecycle assertions passed again.
- Precision: the assertions exercise non-cent totals, payment storage, paid
  amount, and balance values at six decimals, including a payment differing
  from its balance by `0.000001`. The residual `0.000001` remains visible,
  proving that the settlement tolerance does not round calculations to cents.

## Compatibility and progressive history

- Earlier learning-stage source files remain unchanged.
- Existing five- and six-argument `create_reservation` call shapes remain valid
  as public unpaid creation paths, but delegate to `initialize_reservation`.
- Existing seven- and eight-argument paid call shapes retain their argument
  order under the clearer `create_reservation` name.
- `process_booking` and both `add_services_to_reservation` overloads are absent
  from the final installed API. Their earlier scenario files are unchanged.
- Canonical service input retains `NULL` as no change and `[]` as explicit clear.
- Existing reservation-service snapshots and payment rows are not rewritten by
  the upgrade. Existing reservation totals will be recalculated only when the
  new domain operations modify that reservation; the upgrade will not perform
  an unrequested bulk economic rewrite.

## Out of scope

This implementation does not add invoicing, credit notes, automatic refunds,
reconciliation, negative payments, partial-payment allocation, service
delivery statuses, service cancellation history, post-stay economic
adjustments, or triggers for direct table writes. It also does not infer a new
reservation status from the derived balance.

## Approved policy decisions

The implementation follows these approved policy points:

1. `NULL` means no change and an empty collection means clear for both legacy
   overloads, despite each differing from one part of current behavior.
2. `CANCELLED` reservations reject both service changes and new payments.
3. Only `PAID` contributes to amount paid; `REFUNDED` is excluded, not
   represented as a negative amount.
4. `process_reservation_payment` settles the full positive balance rather than
   accepting partial payments, and retains `0.01` only as the settlement
   tolerance without cent-rounding either operand.
5. Payments may settle an established balance after checkout; only service
   changes are date-restricted.
6. Inactive catalog services should be rejected for new snapshots. Existing
   snapshots remain valid if a service is later deactivated.
7. The upgrade does not bulk-recalculate historical reservation totals. Such a
   migration could change historical economics without knowing whether all
   existing service rows were intended to be billable.
