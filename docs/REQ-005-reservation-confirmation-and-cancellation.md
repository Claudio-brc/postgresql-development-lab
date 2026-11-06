# REQ-005 — Reservation confirmation and cancellation

Status: implemented on 2026-11-05.

## Objective

Strengthen the final `confirm_reservation(BIGINT)` and
`cancel_reservation(BIGINT)` domain operations without changing their public
signatures, existing reservation/payment data, or the established currency and
partial-payment model.

## Confirmation

Confirmation locks the reservation row with `SELECT ... FOR UPDATE`, accepts
only `PENDING`, and calculates the current balance through
`calculate_reservation_balance`. A reservation is settled only when its
six-decimal reservation-currency balance satisfies `ABS(balance) < 0.01`.
Neither the total nor the balance is rounded to cents, and exchange rates are
not involved in settlement.

This check is intentionally the same strict tolerance used by
`process_reservation_payment`. The payment operation already owns the same row
lock, inserts the visible `PAID` row, and then safely calls confirmation in the
same transaction.

## Cancellation

Cancellation locks the reservation row before checking status. It accepts
`PENDING` and `CONFIRMED`, rejects an already `CANCELLED` reservation, and only
changes the reservation status. Existing payments and exchange-rate snapshots
are preserved. Refunds, penalties, and payment mutations are out of scope.

The existing update and audit triggers continue to maintain
`reservations.updated_at` and `reservation_status_audit`; the domain functions
do not duplicate that work.

## Concurrency

Confirmation, cancellation, payment processing, and service replacement all
lock the reservation row first. Supported domain operations for one reservation
therefore serialize before reading status or derived economic state. Direct
table writes remain outside this domain-API guarantee.

The transactional regression script verifies state, economic history,
timestamps, and auditing. CI currently runs SQL scripts through sequential
`psql` invocations and has no reliable cross-session synchronization fixture,
so a timing-based multi-session test is intentionally not included. Adding one
without explicit session barriers would be flaky; the row-lock statements and
common lock order remain subject to code review.

## Upgrade

`schema/upgrades/011_reservation_cancellation.sql` replaces only the two
function definitions by including their canonical scenario sources. It performs
no table alteration or data modification and is safe to apply repeatedly after
upgrade 010.

Automatic reservation expiration is explicitly outside this requirement.
