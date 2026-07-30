# PostgreSQL Development Lab

> A practical PostgreSQL laboratory focused on writing production-style database code using PL/pgSQL, JSONB, triggers, business rules, and advanced PostgreSQL features.

Unlike SQL tutorial repositories, this project follows the development of a realistic booking platform, implementing business logic directly inside PostgreSQL while exploring advanced database features.

---

## Project Goals

This laboratory was created to:

- Learn PostgreSQL through practical scenarios.
- Write clean and maintainable PL/pgSQL code.
- Model real business rules at the database level.
- Explore PostgreSQL features beyond basic CRUD.
- Build a portfolio demonstrating backend database development skills.

The project is intentionally organized as progressive scenarios, where each topic builds upon previous concepts.

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
├── examples
│   ├── 01_plpgsql_fundamentals.sql
│   ├── 02_business_rules.sql
│   ├── 03_triggers_and_auditing.sql
│   ├── 04_error_handling_and_logging.sql
│   ├── 05_advanced_types.sql
│   └── 06_jsonb.sql
│
├── install
│   ├── 01_schema.sql
│   ├── 02_plpgsql_fundamentals.sql
│   ├── 03_business_rules.sql
│   ├── ...
│   └── postgresql-development-lab.sql
│
├── scenarios
│   ├── 01_schema
│   │   ├── 00_custom_types.sql
│   │   ├── 01_core_schema.sql
│   │   └── 02_core_seed.sql
│   │
│   ├── 02_plpgsql_fundamentals
│   │   ├── 01_validate_booking_dates.sql
│   │   ├── 02_calculate_stay_cost.sql
│   │   └── ...
│   │
│   ├── 03_business_rules
│   ├── 04_triggers_and_auditing
│   ├── 05_advanced_types
│   └── 06_jsonb
│
├── schema
│
├── tools
│   └── build-all.ps1
│
└── README.md
```

---

# Current Scenarios

| Scenario | Status |
|-----------|--------|
| Database Schema | ✅ |
| PL/pgSQL Fundamentals | ✅ |
| Business Rules | ✅ |
| Triggers & Auditing | ✅ |
| Advanced Types | ✅ |
| JSONB | 🚧 |
| Error Handling | Planned |
| Concurrency | Planned |

---

# Why This Project?

Many SQL repositories demonstrate isolated queries.

This project focuses on something different:

- designing a complete database;
- implementing business logic inside PostgreSQL;
- writing production-style PL/pgSQL;
- organizing SQL code as a maintainable project;
- using PostgreSQL as an application platform rather than only a storage engine.

---

# Technologies

- PostgreSQL
- PL/pgSQL
- JSONB
- Git
- PowerShell (build scripts)

---

# Future Topics

Planned additions include:

- Transactions
- Concurrency
- Locking
- Advisory Locks
- Dynamic SQL
- Performance considerations
- Testing strategies
- Extensions
- Security
- Roles & permissions

---

# License

MIT