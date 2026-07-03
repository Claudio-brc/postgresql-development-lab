CREATE TYPE property_request AS (
    property_name VARCHAR(150),
    nightly_rate NUMERIC,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ
);