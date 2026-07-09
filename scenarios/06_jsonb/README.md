# JSONB

## Overview

This module demonstrates how PostgreSQL JSONB can be used to store, query, update, and process semi-structured data directly inside the database.

Unlike composite types, JSONB provides a flexible schema that is ideal for metadata, configuration, and API payloads whose structure may evolve over time.

## Implemented Examples

### Store JSON Metadata

Stores property metadata inside a JSONB column.

The example demonstrates how a complete JSON document can be assigned to an existing property.

Concepts covered:

- JSONB
- JSON document storage
- Database validation of JSON syntax

---

### Query JSON Documents

Shows how to retrieve information from JSON documents using PostgreSQL JSON operators.

The examples demonstrate reading complete objects, nested attributes, scalar values, and filtering rows based on JSON content.

Concepts covered:

- `->`
- `->>`
- Nested objects
- JSON filtering

---

### Partial JSON Updates

Updates individual values inside an existing JSON document without replacing the entire document.

The example uses `jsonb_set()` to modify nested properties while preserving the remaining document structure.

Concepts covered:

- `jsonb_set()`
- Nested updates
- Partial document modifications

---

### Process JSON Arrays

Receives a JSON array as a function parameter and processes each object individually.

Each JSON object represents a reservation service containing the service identifier and quantity.

Concepts covered:

- `jsonb_array_elements()`
- `jsonb_array_length()`
- `jsonb_typeof()`
- JSON parsing
- Processing API payloads

## JSONB vs Composite Types

This module complements the **Advanced Types** scenario.

Composite types are recommended when the data structure is known and strongly typed.

JSONB is better suited for flexible documents, metadata, and payloads received from external applications where the structure may change over time.

## Summary

This module demonstrates how PostgreSQL can combine relational data with document-oriented storage.

JSONB allows applications to work with flexible data structures while still taking advantage of PostgreSQL's transactional capabilities and SQL features.