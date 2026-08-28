# REQ-002 — Monetary precision

Status: implemented.

## Objective

Increase the internal precision of monetary values used by the booking model so
nightly rates, discounts, services, reservation totals, and payments retain six
decimal places inside PostgreSQL.

The change prevents monetary information from being reduced to presentation
precision before all relevant database calculations have completed. Displaying
two decimal places in a UI, report, or API response remains a presentation
decision and does not define the database storage model.

## Precision policy

The implemented policy is:

- stored monetary values use six decimal places;
- presentation precision is handled separately from storage precision;
- PostgreSQL remains responsible for important monetary calculations;
- intermediate calculations must not introduce premature two-decimal rounding;
- monetary results are constrained to six decimals at their calculation or
  storage boundary.

No `ROUND(..., 2)` expression or equivalent two-decimal monetary cast remains in
the implemented calculation path.

## Monetary columns

The final schema contains these monetary definitions:

```text
properties.nightly_rate
  NUMERIC(12,2) → NUMERIC(16,6)

reservations.total_amount
  NUMERIC(12,2) → NUMERIC(16,6)

payments.payment_amount
  NUMERIC(12,2) → NUMERIC(16,6)

services.price
  NUMERIC(10,2) → NUMERIC(14,6)

reservation_services.unit_price
  NUMERIC(10,2) → NUMERIC(14,6)
```

Both precision and scale were increased by four digits. This preserves the
existing whole-number capacity while adding four fractional digits. For
example, `NUMERIC(12,2)` allows ten whole-number digits; `NUMERIC(16,6)` keeps
the same ten whole-number digits. Likewise, `NUMERIC(10,2)` and
`NUMERIC(14,6)` both allow eight whole-number digits.

All existing non-negative and positive-value constraints remain unchanged.

`discounts.discount_percent` remains `NUMERIC(5,2)`. It is a percentage rather
than a stored monetary value and is outside the six-decimal monetary storage
policy.

## Custom types

The monetary attributes in the project composite types match the corresponding
table columns:

```text
property_request.nightly_rate
  NUMERIC → NUMERIC(16,6)

reservation_summary.total_amount
  NUMERIC → NUMERIC(16,6)

service_summary.unit_price
  NUMERIC(10,2) → NUMERIC(14,6)
```

This alignment ensures that property creation, reservation summaries, and
service summaries do not reintroduce a lower-precision boundary.

## Functions and calculation boundaries

PostgreSQL discards parenthesized type modifiers such as precision and scale
from function argument and return signatures. The affected functions therefore
retain `NUMERIC` as their SQL signature type and enforce the six-decimal result
at the calculation boundary with explicit casts.

The final calculation flow is:

```text
calculate_stay_cost(...)
  → (nights × nightly_rate)::NUMERIC(16,6)

calculate_booking_discount(...)
  → undiscounted or discounted result::NUMERIC(16,6)

calculate_booking_total(...)
  → final result::NUMERIC(16,6)
```

Intermediate variables remain unconstrained `NUMERIC` where appropriate so
they do not reduce scale before the final result is produced. The reservation
creation flow stores the resulting value in
`reservations.total_amount NUMERIC(16,6)`.

`process_booking` accepts `p_payment_amount NUMERIC`, compares it with the
reservation total in PostgreSQL, and stores it in
`payments.payment_amount NUMERIC(16,6)`. Its existing `0.01` payment-match
tolerance remains unchanged to preserve established business behavior.

Service-assignment functions continue to read `services.price` and snapshot it
in `reservation_services.unit_price`. Their unconstrained `NUMERIC`
intermediate variables do not truncate the six-decimal stored value. These
functions do not currently calculate a service subtotal.

## Upgrade strategy

Existing databases apply
`schema/upgrades/007_increase_monetary_precision.sql` after
`006_add_application_users.sql`.

The upgrade executes in one transaction and follows this order:

1. alter the five monetary table columns to their widened six-decimal types;
2. alter the three monetary composite-type attributes;
3. replace `calculate_stay_cost` with its explicit six-decimal result cast;
4. replace `calculate_booking_discount` with explicit casts for both discounted
   and undiscounted results;
5. replace `calculate_booking_total` with an explicit final result cast;
6. commit only after every schema and function change succeeds.

Changing from scale 2 to scale 6 preserves all representable existing values.
Widening total precision at the same time prevents any loss of the previous
whole-number range. No row transformation, deletion, identifier change, or
date change is required.

The clean installer creates the final six-decimal model directly. Existing
databases must use the ordered upgrade scripts rather than the destructive
consolidated installer.

## Source files

- `schema/00_custom_types.sql`.
- `schema/01_core_schema.sql`.
- `schema/02_seed_data.sql`.
- `schema/upgrades/006_add_application_users.sql`.
- `schema/upgrades/007_increase_monetary_precision.sql`.
- `scenarios/01_plpgsql_fundamentals/01_calculate_stay_cost.sql`.
- `scenarios/02_functions_business_rules/01_calculate_booking_discount.sql`.
- `scenarios/02_functions_business_rules/04_calculate_booking_total.sql`.
- `scenarios/02_functions_business_rules/05_create_reservation.sql`.
- `scenarios/02_functions_business_rules/06_process_booking.sql`.
- `scenarios/05_advanced_types/01_create_property.sql`.
- `scenarios/05_advanced_types/02_get_reservation_summary.sql`.
- `scenarios/05_advanced_types/03_add_services_to_reservation.sql`.
- `scenarios/06_jsonb/05_add_services_to_reservation_jsonb.sql`.
- `examples/01_plpgsql_fundamentals.sql`.
- `examples/02_functions_business_rules.sql`.
- `README.md`.

The generated files affected by the implementation are:

- `install/01_plpgsql_fundamentals.sql`;
- `install/02_functions_business_rules.sql`;
- `install/postgresql-development-lab.sql`.

Files under `install/` are regenerated only through `tools/build-all.ps1`.

## Validation

The final implementation was validated against PostgreSQL 17 in separate,
disposable databases for clean installation and upgrade scenarios.

Clean-install validation confirmed:

1. successful execution of the generated master installer;
2. precision 16 and scale 6 for nightly rates, reservation totals, and
   payments;
3. precision 14 and scale 6 for service prices and reservation service price
   snapshots;
4. matching six-decimal definitions in all affected composite types;
5. a stay cost of `369.370368` from a six-decimal nightly rate;
6. a discounted booking total of `775.677773` after the final six-decimal
   calculation boundary.

Upgrade validation confirmed:

1. successful execution of `007_increase_monetary_precision.sql` over the prior
   two-decimal definitions;
2. preservation of previous maximum-range sample values, including
   `9999999999.99 → 9999999999.990000` and
   `99999999.99 → 99999999.990000`;
3. correct final precision and scale for all five monetary columns;
4. correct six-decimal calculations after the upgrade;
5. successful execution of the final installer and upgrade together.

The project build completed successfully, `git diff --check` reported no
errors, and a repository-wide audit found no remaining monetary
`NUMERIC(12,2)`, monetary `NUMERIC(10,2)`, or `ROUND(..., 2)` calculation.

## Audit consistency findings

The audit also produced these small consistency decisions, retained separately
from the core precision requirement:

- `process_booking.p_payment_amount` now uses the accurate `NUMERIC` function
  signature notation instead of the misleading `NUMERIC(12,2)` notation,
  because PostgreSQL discards function-signature typemods;
- the same signature correction was applied to the historical application-user
  upgrade and its example documentation;
- the existing payment comparison tolerance of `0.01` was retained rather than
  silently changing payment acceptance behavior;
- seed values that naturally contain two decimal places were retained because
  they are exact inputs and are stored with scale 6 by the final column types;
- non-monetary numeric fields, including percentages, identifiers, quantities,
  counts, and dates, were not changed.
