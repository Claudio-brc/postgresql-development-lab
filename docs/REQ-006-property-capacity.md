# REQ-006 — Property capacity and reservation guest count

Status: implemented on 2026-11-19.

## Objective

Add a positive maximum occupancy to each property and persist the positive
guest count declared for each reservation. Availability must require an active
property, sufficient capacity, and no overlapping `PENDING` or `CONFIRMED`
reservation. Pricing remains property-based and is not multiplied by guests.

## Data model

`properties.max_guests INTEGER NOT NULL DEFAULT 1` is the current maximum
number of guests accepted for a new reservation. `reservations.guests_count
INTEGER NOT NULL DEFAULT 1` is the occupancy declared when that reservation was
created. Named check constraints require both values to be greater than zero.

The default `1` exists for migration and API compatibility. For rows created
before REQ-006, it is a conservative placeholder, not verified historical
occupancy. After upgrading, operators should configure each property's actual
`max_guests`. Existing reservation guest counts must not be presented as known
historical facts unless they are independently corrected.

Changing `properties.max_guests` does not rewrite stored reservation occupancy.
The reservation value is part of the booking snapshot. The
`trg_reservations_enforce_capacity` trigger protects direct inserts and changes
to `property_id` or `guests_count`; it rejects values above the property's
current limit. The existing exclusion constraint continues to protect direct
writes from overlapping active reservations.

## Availability

The canonical contract is:

```text
is_property_available(BIGINT, DATE, DATE, INTEGER) -> BOOLEAN
```

It raises `Guest count must be greater than zero.` for `NULL`, zero, or negative
occupancy. It retains the established invalid-date and missing-property
exceptions, returns false for inactive or insufficient-capacity properties,
and returns false when the half-open requested date range overlaps a `PENDING`
or `CONFIRMED` reservation. A reservation checking out on another's check-in
date does not overlap. `CANCELLED` rows do not block availability.

The original three-argument function delegates to the canonical implementation
with one guest. There is one copy of the overlap query.

## Creation contracts

The canonical `initialize_reservation` adds `p_guests_count INTEGER` between
the dates and creator identifier. It validates availability with that value and
persists it. The canonical public `create_reservation` adds the same argument
at the same position before the existing optional payment, service, currency,
and exchange-rate inputs.

Guest-aware convenience overloads cover unpaid and paid base-currency calls,
services, and explicit currency snapshots. All pre-REQ-006 overloads remain in
place and delegate with one guest. `INTEGER` is used for occupancy while entity
identifiers remain `BIGINT`, avoiding conflicts with the established overload
set. The legacy one-argument `create_property(property_request)` also remains;
the new two-argument form accepts an explicit `max_guests`, while the legacy
form delegates with one.

`calculate_booking_total` is unchanged. Guest count does not change nightly
rates, discounts, service snapshots, currency handling, exchange-rate
snapshots, partial payments, confirmation, or cancellation.

## Migration

Apply `schema/upgrades/013_property_capacity.sql` after upgrade 012. It adds the
columns when absent, backfills null historical values to one, applies defaults,
not-null and positive-value constraints, installs the direct-write trigger, and
replaces the final availability/property/reservation functions. Reapplying it
is safe where practical: schema objects are guarded or replaced, and the
backfill only touches null values.

Upgrade 013 contains `psql` `\ir` meta-commands so its canonical function
sources cannot drift from clean installation. `\ir` is not SQL and pgAdmin
Query Tool does not interpret it. Run the upgrade from the repository root with
`psql -X -v ON_ERROR_STOP=1 -d <database> -f
schema/upgrades/013_property_capacity.sql`. A pgAdmin-only workflow must replace
each `\ir` line with the complete contents of the referenced source file before
executing the combined script; do not submit the literal `\ir` lines to Query
Tool.

The consolidated installer is destructive and is only for a fresh lab
database. It must not be used as an upgrade.

## Validation coverage

`examples/14_property_capacity.sql` runs transactionally and rolls back all
fixture rows. It covers capacity below/equal/above the limit, invalid guest
counts, inactive and occupied properties, back-to-back dates, cancelled rows,
guest-aware unpaid and paid creation, persisted occupancy, unchanged pricing
and payment behavior, the legacy one-guest overload, direct-write protection,
and positive-value constraints.

### Verification evidence

Validation was run on PostgreSQL 17 on 2026-11-19 in disposable databases.
The generated clean installer completed with `ON_ERROR_STOP=1`, followed by
examples 10 through 14. Upgrade 013 then completed twice on the clean database
and example 14 still passed. The isolated pre-013 fixture also applied the real
upgrade twice and verified preserved row counts and identifiers, historical
backfill to one, new constraints, and guest-aware function installation. The
disposable databases were removed afterward.

The CI workflow installs the generated master script, runs all existing final
lifecycle regressions, runs example 14, reapplies upgrade 013 twice, and reruns
the capacity regression.

## Files

- `scenarios/09_property_capacity/` contains the canonical final definitions.
- `schema/upgrades/013_property_capacity.sql` is the incremental upgrade.
- `examples/14_property_capacity.sql` is the transactional behavior regression.
- `install/09_property_capacity.sql` and
  `install/postgresql-development-lab.sql` are generated by
  `tools/build-all.ps1`; they are not edited manually.

## Out of scope

This requirement does not introduce guest-based prices, extra-person fees,
included-guest thresholds, discounts, quotation APIs, Booking API changes, or
currency-model changes.
