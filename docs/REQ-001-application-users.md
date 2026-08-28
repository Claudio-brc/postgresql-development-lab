# REQ-001 — Application users

Status: implemented.

## Objective

Introduce `public.users` and ensure that every reservation identifies
the Booking API user who created it, while keeping the following
concepts separate:

```text
reservations.guest_id
  → person staying at the property or reservation holder

reservations.created_by_user_id
  → Booking API user who created the reservation
```

Authentication, login, JWT, PostgreSQL-side password hashing, roles,
permissions, sessions, refresh tokens, and a User ↔ Guest relationship
are not included in this requirement. Booking API itself is also outside
the scope of this change.

## `public.users` model

```sql
CREATE TABLE public.users (
    user_id       BIGSERIAL PRIMARY KEY,
    user_code     VARCHAR(30) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ,

    CONSTRAINT uq_users_user_code UNIQUE (user_code),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_user_code_format
        CHECK (user_code ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$')
);
```

`password_hash` uses `VARCHAR(255)` to support encoded representations
produced by different hashing algorithms without coupling the schema to
a specific one. PostgreSQL only stores the value after it has been
processed by the application.

## Initial user

The clean installation and upgrade create the following application
user:

- `user_code = 'CALVAREZ'`;
- `full_name = 'Claudio Alvarez'`;
- `email = 'calvarez.brc@gmail.com'`;
- `is_active = TRUE`.

The seed stores an explicitly fictitious placeholder in `password_hash`.
It is neither a password nor a valid credential. Generating and managing
the actual password hash is the responsibility of Booking API/Auth.

The `user_id` is never assumed to be `1`; every seed or migration
relationship resolves it through `user_code = 'CALVAREZ'`.

## Mandatory reservation relationship

The final state is:

```sql
created_by_user_id BIGINT NOT NULL
```

with:

- FK `fk_reservations_created_by_user` referencing `users(user_id)`;
- index `idx_reservations_created_by_user_id`;
- no `ON DELETE CASCADE`.

## Migration strategy

The upgrade runs inside a transaction and follows this order:

1. create `public.users`;
2. insert `CALVAREZ`;
3. add `created_by_user_id` as temporarily nullable;
4. resolve the `user_id` of `CALVAREZ` through `user_code`;
5. assign it to existing reservations without a creator;
6. abort if any `NULL` values remain;
7. apply `NOT NULL`;
8. create the FK and index;
9. install the new function signatures;
10. remove the old signatures without using `CASCADE`.

A clean installation creates the final model directly, and its seeds
already include the mandatory creator.

## Functions

The final state contains a single signature for each affected function:

```text
create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)
process_booking(BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT)
try_create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)
try_create_reservation_with_logging(BIGINT, BIGINT, DATE, DATE, BIGINT)
```

`p_created_by_user_id` is mandatory, has no default value, and is
propagated using the technical identifier `users.user_id`. No historical
wrappers or overloads are retained.

`try_create_reservation` translates a foreign key violation into an
invalid guest, property, or user identifier error.

## Source files

- `schema/01_core_schema.sql`.
- `schema/02_seed_data.sql`.
- `schema/upgrades/006_add_application_users.sql`.
- `scenarios/02_functions_business_rules/05_create_reservation.sql`.
- `scenarios/02_functions_business_rules/06_process_booking.sql`.
- `scenarios/03_triggers_and_auditing/01_update_updated_at_trigger.sql`.
- `scenarios/04_error_handling_and_logging/01_try_create_reservation.sql`.
- `scenarios/04_error_handling_and_logging/02_try_create_reservation_with_logging.sql`.
- `examples/02_functions_business_rules.sql`.
- `examples/08_guest_soft_delete.sql`.
- `examples/10_application_users.sql`.
- `README.md`.

Files under `install/` are regenerated exclusively through
`tools/build-all.ps1`.

## Verification

Validation must verify:

1. existence and active status of `CALVAREZ`;
2. automatic `user_id` generation;
3. mandatory, formatted, and unique `user_code`;
4. email uniqueness;
5. preservation of the supplied `password_hash`;
6. independence between Guest and User;
7. User → Reservation relationship;
8. zero reservations with `created_by_user_id IS NULL`;
9. valid FK referencing `users`;
10. rejection of reservations without a creator or with a nonexistent
    `user_id`;
11. exactly one active signature for each affected function;
12. absence of compatibility wrappers.

Clean installation and upgrade from the previous schema must be
validated separately using disposable databases.
