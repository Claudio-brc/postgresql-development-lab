# PostgreSQL Development Lab

> A practical PostgreSQL laboratory focused on writing production-style database code using PL/pgSQL, JSONB, triggers, business rules, and advanced PostgreSQL features.

This project follows the development of a realistic booking platform, implementing business logic directly inside PostgreSQL through practical development scenarios.

---

## Database Schema

![Entity Relationship Diagram](assets/erd-1.png)

---

## Project Goals:

- Demonstrate advanced PostgreSQL development techniques.
- Implement business logic directly inside PostgreSQL.
- Explore production-oriented PL/pgSQL patterns.
- Showcase practical use of JSONB, triggers, and advanced database features.
- Serve as a reference for PostgreSQL application development.
- The project is intentionally organized as progressive scenarios, where each topic builds upon previous concepts.

---

## Installation

### Requirements

- Git
- PowerShell 7+
- PostgreSQL 17 (or compatible)
- pgAdmin, `psql`, or another PostgreSQL client

### Option 1: Run PostgreSQL with Docker

Start a PostgreSQL instance using the provided Docker Compose file:

```bash
docker compose up -d
```

The container will be created with the following default configuration:

- **Database:** `postgresql_development_lab`
- **Username:** `postgres`
- **Password:** `postgres`
- **Port:** `5432`

### Build the Project

Run the build script to generate the consolidated installation file:

```powershell
./tools/build-all.ps1
```

This generates:

```text
install/
└── postgresql-development-lab.sql
```

### Install the project

Open the generated script in pgAdmin (or your preferred PostgreSQL client) and execute:

```text
install/postgresql-development-lab.sql
```

### Upgrade an existing database

To preserve existing data, do not run the destructive consolidated installer.
Apply the upgrades in order instead:

```text
schema/upgrades/001_add_property_type.sql
schema/upgrades/002_add_property_code.sql
schema/upgrades/003_update_property_creation.sql
schema/upgrades/004_add_guest_is_active.sql
schema/upgrades/005_add_guest_documents.sql
schema/upgrades/006_add_application_users.sql
```

Because historical rows have no reliable type information, the upgrade assigns
`ROOM` as a transitional value. Review and correct those rows after applying it.

The guest upgrade keeps every existing guest active. Guests can then be soft
deleted with `UPDATE guests SET is_active = FALSE`; it does not remove rows or
their reservation history. Existing queries are not filtered by activity.

### Explore the examples

After the installation completes, execute the scripts located in the `examples` directory to see the implemented functions and procedures in action.

```text
examples/
├── 01_plpgsql_fundamentals.sql
├── 02_functions_business_rules.sql
├── 03_triggers_and_auditing.sql
├── 04_error_handling_and_logging.sql
├── 05_advanced_types.sql
├── 06_jsonb.sql
├── 07_property_codes.sql
├── 08_guest_soft_delete.sql
├── 09_guest_documents.sql
└── 10_application_users.sql
```

Guest soft-delete behavior and reservation-history preservation are verified by
`examples/08_guest_soft_delete.sql`.

Guest document normalization, consistency, and uniqueness are verified by
`examples/09_guest_documents.sql`.

Application users and reservation creator ownership are verified by
`examples/10_application_users.sql`. Every reservation must reference the
application user that created it; `guest_id` continues to identify the person
staying or holding the reservation.

The initial development user is `CALVAREZ`. Its seeded `password_hash` is an
explicit non-credential placeholder. Booking API/Auth is responsible for
generating and managing real password hashes; PostgreSQL only stores them.

### Example Workflow

The example scripts simulate a typical booking lifecycle, including:

- booking validation;
- availability checking;
- stay cost calculation;
- discount application;
- reservation management;
- service management;
- payment processing;
- automatic auditing.


---

# Topics Covered

## Core Database Design

- Relational schema design
- Constraints
- Foreign keys
- Custom types
- Seed data

## PL/pgSQL

- Functions
- Procedures
- Variables
- Control structures
- Loops
- Exception handling
- Composite types

## Business Rules

Examples include:

- Booking validation
- Availability checking
- Stay cost calculation
- Weekly discounts
- Guest booking limits
- Reservation management

## JSONB

Examples of:

- JSONB updates
- Nested JSON manipulation
- JSON arrays
- Metadata storage

## Advanced Types

- Composite types
- Arrays
- FOREACH loops
- Record variables

## Triggers & Auditing

- Automatic auditing
- Change history
- Trigger-based business logic

## Error Handling

- Custom exceptions
- Validation rules
- Defensive programming

---

# Project Structure

```
.
├── assets
│ └── erd-1.png
│
├── docs
│ ├── REQ-001-application-users.md
│ └── repository-audit-2026-08-25.md
│
├── examples
│ ├── 01_plpgsql_fundamentals.sql
│ ├── 02_functions_business_rules.sql
│ ├── 03_triggers_and_auditing.sql
│ ├── 04_error_handling_and_logging.sql
│ ├── 05_advanced_types.sql
│ ├── 06_jsonb.sql
│ ├── 07_property_codes.sql
│ ├── 08_guest_soft_delete.sql
│ ├── 09_guest_documents.sql
│ └── 10_application_users.sql
│
├── install
│ ├── 01_plpgsql_fundamentals.sql
│ ├── 02_functions_business_rules.sql
│ ├── 03_triggers_and_auditing.sql
│ ├── 04_error_handling_and_logging.sql
│ ├── 05_advanced_types.sql
│ ├── 06_jsonb.sql
│ └── postgresql-development-lab.sql
│
├── schema
│ ├── 00_custom_types.sql
│ ├── 01_core_schema.sql
│ ├── 02_seed_data.sql
│ └── upgrades
│     ├── 001_add_property_type.sql
│     ├── 002_add_property_code.sql
│     ├── 003_update_property_creation.sql
│     ├── 004_add_guest_is_active.sql
│     ├── 005_add_guest_documents.sql
│     └── 006_add_application_users.sql
│
├── scenarios
│ ├── 01_plpgsql_fundamentals
│ ├── 02_functions_business_rules
│ ├── 03_triggers_and_auditing
│ ├── 04_error_handling_and_logging
│ ├── 05_advanced_types
│ └── 06_jsonb
│
├── tools
│ ├── build-all.ps1
│ └── build-scenarios.ps1
│
├── utils
│ ├── get_setting.sql
│ └── get_table_columns.sql
│
├── docker-compose.yml
└── README.md
```

---

# Current Scenarios

| Scenario | Status |
|-----------|--------|
| PL/pgSQL Fundamentals | ✅ |
| Business Rules | ✅ |
| Triggers & Auditing | ✅ |
| Error Handling | ✅ |
| Advanced Types | ✅ |
| JSONB | ✅ |


---

# Technologies

- PostgreSQL
- PL/pgSQL
- JSONB
- Docker
- PowerShell (build scripts)

---

# Future Topics

Additional scenarios may be added over time as the laboratory evolves.

---

# License

MIT
