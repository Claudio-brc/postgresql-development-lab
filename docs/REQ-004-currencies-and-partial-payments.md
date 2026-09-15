# REQ-004 — Currencies, exchange-rate snapshots, and partial payments

Status: implemented on 2026-09-12.

## Objective

Extend the reservation economic lifecycle with explicit currencies, reference
exchange-rate snapshots, consolidated base-currency reporting, and multiple
partial payments while preserving the direct `Reservation 1:N Payments`
relationship and REQ-002 monetary precision.

## Economic model

`app_settings.base_currency_code` identifies the reporting currency. The seed
and legacy-data migration use `ARS`. Currency values use normalized three-letter
ISO 4217 syntax. No currency catalog or external rate provider is introduced.

Every reservation stores `currency_code VARCHAR(3)` and
`exchange_rate NUMERIC(20,10)`. Its monetary components and `total_amount` are
all understood to be in that currency. Every payment inherits that reservation
currency and stores its own `exchange_rate NUMERIC(20,10)` snapshot.

The single rate convention is:

```text
1 unit of source currency = exchange_rate units of base currency
```

Rates must be positive. A base-currency reservation or payment must use rate
1. Rate snapshots are not rounded to monetary precision before multiplication;
only the resulting reporting value is cast to `NUMERIC(16,6)`.

The derived reporting calculations are:

```text
potential value in base = reservations.total_amount
                        * reservations.exchange_rate

collected value in base = SUM(PAID payments.payment_amount
                            * payments.exchange_rate)
```

They are implemented by
`calculate_reservation_potential_value_in_base_currency` and
`calculate_reservation_collected_value_in_base_currency`. Neither value is
persisted.

## Partial-payment rules

`process_reservation_payment(BIGINT, NUMERIC, VARCHAR, NUMERIC)` is the
canonical operation. It locks the reservation, validates a positive amount,
method, and payment-time rate, then reads the current derived balance. A
payment below the balance is accepted and the reservation remains `PENDING`.
When the new balance is within the existing `0.01` settlement tolerance, a
`PENDING` reservation becomes `CONFIRMED`. An amount exceeding the current
balance by `0.01` or more is rejected atomically. Each successful call inserts
one independent `PAID` row; old payments and rates are never changed.

The three-argument compatibility overload delegates with rate 1 only for a
base-currency reservation. It rejects foreign-currency reservations because a
new payment-time rate cannot safely be inferred.

## Creation API

The canonical `initialize_reservation` adds `currency_code` and
`exchange_rate` after the existing arguments. The canonical
`create_reservation` adds reservation currency, reservation exchange rate, and
payment exchange rate after its existing eight arguments. Convenience forms
omit services and/or payment. Existing five-, six-, seven-, and eight-argument
creation shapes remain supported as base-currency/rate-1 operations and all
delegate to the canonical functions; business logic is not duplicated.

## Schema and direct-write safeguards

The schema retains all REQ-002 money types. Only exchange rates use
`NUMERIC(20,10)`. Check constraints enforce uppercase three-letter syntax and
positive rates. Validation triggers additionally enforce the base-currency
rate-1 invariant. Legacy direct inserts that omit both reservation currency
fields inherit the configured base currency and rate 1; payment inserts may
omit the rate only for base-currency reservations.

## Upgrade and data preservation

`schema/upgrades/009_currencies_and_partial_payments.sql` is applied after 008.
It inserts the missing `base_currency_code` setting without overwriting an
existing value, adds nullable columns, backfills every historical reservation
with the configured base currency/rate 1 and every historical payment with
rate 1, and only then makes the columns mandatory. Amounts, statuses, service
snapshots, payment rows, and timestamps are not rewritten. The upgrade uses
the canonical scenario sources for function definitions and is repeatable.

## Traceability

| Requirement | Implementation | Validation |
| --- | --- | --- |
| Base currency setting and ISO syntax | `schema/01_core_schema.sql`, seed data, validation function/trigger | Example 12 setting and invalid base-rate checks |
| Reservation currency/rate snapshot | reservation columns; `initialize_reservation` overloads | Example 12 USD reservation and precision assertions |
| Payment rate snapshot and inherited currency | payment column; four-argument payment function and trigger | Three payments with independent rates; legacy-overload rejection |
| Potential/collected base reporting | scenario 08 reporting functions | 450000 potential and 451500 collected assertions |
| Partial payments and settlement | canonical payment function | 100 + 150 + 50 flow and status/balance assertions |
| Overpayment rejection | canonical payment function | atomic 50.01 rejection at balance 50 |
| Existing data preserved | upgrade 009 backfill | upgrade validation from version 008 |
| Generated distribution | scenario installer and master installer | build plus clean-install validation |

## Out of scope

There is no rate-history table, automatic lookup, external FX integration,
mixed-currency payment, payment header/detail split, or historical rate
reconstruction. Three-letter syntax is enforced locally; maintaining a full
ISO 4217 code registry is intentionally outside this requirement.

## Verification evidence

Validation was performed on PostgreSQL 17 in disposable databases. The clean
generated installer completed with `ON_ERROR_STOP=1`, then examples 11 and 12
completed transactionally. A second database loaded from the pre-change
version-008 installer retained 10 reservations totaling 4860.000000 and 6
payments totaling 3330.000000 after upgrade 009; every legacy snapshot was
backfilled to ARS/rate 1. Example 12 passed after upgrade, and applying upgrade
009 a second time also completed successfully.
