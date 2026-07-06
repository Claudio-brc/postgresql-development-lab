CREATE TYPE property_request AS (
    property_name VARCHAR(150),
    nightly_rate NUMERIC,
    is_active BOOLEAN,
    created_at TIMESTAMPTZ
);

CREATE TYPE reservation_summary AS
(
    reservation_id BIGINT,
    guest_name VARCHAR(150),
    property_name VARCHAR(150),
    total_amount NUMERIC,
    status VARCHAR(20)
);

CREATE TYPE service_summary AS
(
    service_id BIGINT,
    service_name VARCHAR(100),
    quantity INTEGER,
    unit_price NUMERIC(10,2)
);