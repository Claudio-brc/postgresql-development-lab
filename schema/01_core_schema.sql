DROP TABLE IF EXISTS guests CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS reservations CASCADE;
DROP TABLE IF EXISTS payments CASCADE;


CREATE TABLE guests (
    guest_id      BIGSERIAL PRIMARY KEY,
    full_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE properties (
    property_id     BIGSERIAL PRIMARY KEY,
    property_name   VARCHAR(150) NOT NULL,

    nightly_rate    NUMERIC(12,2)
                     NOT NULL
                     CHECK (nightly_rate >= 0),

    is_active       BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE reservations (
    reservation_id      BIGSERIAL PRIMARY KEY,

    guest_id            BIGINT NOT NULL,

    property_id         BIGINT NOT NULL,

    check_in_date       DATE NOT NULL,

    check_out_date      DATE NOT NULL,

    status              VARCHAR(20)
                        NOT NULL
                        DEFAULT 'PENDING'
                        CHECK (
                            status IN (
                                'PENDING',
                                'CONFIRMED',
                                'CANCELLED'
                            )
                        ),

    total_amount        NUMERIC(12,2)
                        NOT NULL
                        DEFAULT 0
                        CHECK (total_amount >= 0),

    created_at          TIMESTAMP
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_reservations_guests
        FOREIGN KEY (guest_id)
        REFERENCES guests(guest_id),

    CONSTRAINT fk_reservations_properties
        FOREIGN KEY (property_id)
        REFERENCES properties(property_id),

    CONSTRAINT chk_reservation_dates
        CHECK (check_out_date > check_in_date)
);

CREATE TABLE payments (
    payment_id          BIGSERIAL PRIMARY KEY,

    reservation_id      BIGINT NOT NULL,

    payment_amount      NUMERIC(12,2)
                        NOT NULL
                        CHECK (payment_amount > 0),

    payment_method      VARCHAR(30) NOT NULL,

    status              VARCHAR(20)
                        NOT NULL
                        DEFAULT 'PENDING'
                        CHECK (
                            status IN (
                                'PENDING',
                                'PAID',
                                'REFUNDED'
                            )
                        ),

    payment_date        TIMESTAMP
                        NOT NULL
                        DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_payments_reservations
        FOREIGN KEY (reservation_id)
        REFERENCES reservations(reservation_id)
);

CREATE TABLE app_settings (

    setting_key     VARCHAR(100) PRIMARY KEY,

    setting_value   VARCHAR(255) NOT NULL,

    description     VARCHAR(255)

);