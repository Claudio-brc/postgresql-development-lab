# Triggers and Auditing

## Overview

This module introduces PostgreSQL triggers and demonstrates how they can be used to automate common database tasks, enforce business rules, and maintain audit information.

The examples illustrate both `BEFORE` and `AFTER` row-level triggers.

## Implemented Triggers

### update_updated_at()

Automatically updates the `updated_at` column before a row is modified.

The same trigger function is reused by multiple tables, avoiding duplicated logic.

Concepts covered:

- `BEFORE UPDATE`
- `NEW`
- `FOR EACH ROW`
- Reusable trigger functions

---

### validate_reservation_status()

Prevents invalid reservation status transitions.

The trigger enforces business rules directly in the database by validating the previous and new values of the reservation status.

Examples of blocked transitions include:

- `CONFIRMED → PENDING`
- `CANCELLED → PENDING`
- `CANCELLED → CONFIRMED`

Concepts covered:

- `OLD`
- `NEW`
- Business rule enforcement
- `RAISE EXCEPTION`

---

### log_reservation_status_change()

Records every reservation status change in a dedicated audit table.

Whenever the reservation status changes, the trigger stores:

- Reservation identifier
- Previous status
- New status
- Timestamp of the change

The audit record is created only when the status actually changes.

Concepts covered:

- `AFTER UPDATE`
- Audit tables
- Change history
- `IS DISTINCT FROM`

## Summary

This module demonstrates three common trigger use cases:

- Automatic maintenance of metadata (`updated_at`)
- Enforcement of business rules
- Audit logging

These patterns are frequently used in production PostgreSQL databases to keep business logic close to the data while maintaining consistency and traceability.