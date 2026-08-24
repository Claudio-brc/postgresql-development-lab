-- Apply after 005_add_guest_documents.sql.
-- Booking API/Auth will generate and manage real password hashes. The value
-- inserted here is an explicit development-only placeholder, not a credential.

BEGIN;

CREATE TABLE public.users (
    user_id       BIGSERIAL PRIMARY KEY,
    user_code     VARCHAR(30) NOT NULL,
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name     VARCHAR(100) NOT NULL,
    is_active     BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMPTZ,

    CONSTRAINT uq_users_user_code
        UNIQUE (user_code),

    CONSTRAINT uq_users_email
        UNIQUE (email),

    CONSTRAINT chk_users_user_code_format
        CHECK (user_code ~ '^[A-Z0-9]+(-[A-Z0-9]+)*$')
);

INSERT INTO public.users (
    user_code,
    email,
    password_hash,
    full_name,
    is_active
)
VALUES (
    'CALVAREZ',
    'calvarez.brc@gmail.com',
    '$development-only$not-a-real-password-hash',
    'Claudio Alvarez',
    TRUE
);

ALTER TABLE public.reservations
    ADD COLUMN created_by_user_id BIGINT;

UPDATE public.reservations
SET created_by_user_id = (
    SELECT user_id
    FROM public.users
    WHERE user_code = 'CALVAREZ'
)
WHERE created_by_user_id IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.users
        WHERE user_code = 'CALVAREZ'
    ) THEN
        RAISE EXCEPTION 'Application user CALVAREZ was not created';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.reservations
        WHERE created_by_user_id IS NULL
    ) THEN
        RAISE EXCEPTION
            'Cannot enforce reservations.created_by_user_id: NULL values remain';
    END IF;
END;
$$;

ALTER TABLE public.reservations
    ALTER COLUMN created_by_user_id SET NOT NULL;

ALTER TABLE public.reservations
    ADD CONSTRAINT fk_reservations_created_by_user
    FOREIGN KEY (created_by_user_id)
    REFERENCES public.users(user_id);

CREATE INDEX idx_reservations_created_by_user_id
    ON public.reservations(created_by_user_id);

CREATE OR REPLACE FUNCTION create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_amount   NUMERIC;
    v_reservation_id BIGINT;
    v_is_available   BOOLEAN;
BEGIN
    PERFORM validate_booking_dates(p_check_in, p_check_out);

    v_is_available := is_property_available(
        p_property_id,
        p_check_in,
        p_check_out
    );

    IF NOT v_is_available THEN
        RAISE EXCEPTION 'Property is not available for the selected dates.';
    END IF;

    PERFORM can_guest_book(p_guest_id);

    v_total_amount := calculate_booking_total(
        p_property_id,
        p_check_in,
        p_check_out
    );

    INSERT INTO reservations (
        guest_id,
        property_id,
        check_in_date,
        check_out_date,
        total_amount,
        status,
        created_by_user_id
    )
    VALUES (
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        v_total_amount,
        'PENDING',
        p_created_by_user_id
    )
    RETURNING reservation_id INTO v_reservation_id;

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION process_booking(
    p_guest_id       BIGINT,
    p_property_id    BIGINT,
    p_check_in       DATE,
    p_check_out      DATE,
    p_payment_amount NUMERIC(12,2),
    p_payment_method VARCHAR(30),
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_reservation_id BIGINT;
    v_total_amount   NUMERIC;
BEGIN
    IF COALESCE(p_payment_amount, 0) <= 0 THEN
        RAISE EXCEPTION 'Payment amount must be greater than zero.';
    END IF;

    IF p_payment_method IS NULL THEN
        RAISE EXCEPTION 'Payment method cannot be NULL.';
    END IF;

    v_reservation_id := create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id
    );

    SELECT total_amount
    INTO v_total_amount
    FROM reservations
    WHERE reservation_id = v_reservation_id;

    IF ABS(v_total_amount - p_payment_amount) >= 0.01 THEN
        RAISE EXCEPTION
            'Payment amount does not match the reservation total.';
    END IF;

    INSERT INTO payments (
        reservation_id,
        payment_amount,
        payment_method,
        status,
        payment_date
    )
    VALUES (
        v_reservation_id,
        p_payment_amount,
        p_payment_method,
        'PAID',
        CURRENT_DATE
    );

    PERFORM confirm_reservation(v_reservation_id);

    RETURN v_reservation_id;
END;
$$;

CREATE OR REPLACE FUNCTION try_create_reservation(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE EXCEPTION 'Invalid guest, property, or user identifier.';

    WHEN check_violation THEN
        RAISE EXCEPTION
            'Reservation data violates database constraints.';
END;
$$;

CREATE OR REPLACE FUNCTION try_create_reservation_with_logging(
    p_guest_id    BIGINT,
    p_property_id BIGINT,
    p_check_in    DATE,
    p_check_out   DATE,
    p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_sqlstate      VARCHAR(10);
    v_error_message TEXT;
BEGIN
    RETURN create_reservation(
        p_guest_id,
        p_property_id,
        p_check_in,
        p_check_out,
        p_created_by_user_id
    );

EXCEPTION
    WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS
            v_sqlstate := RETURNED_SQLSTATE,
            v_error_message := MESSAGE_TEXT;

        INSERT INTO error_log (
            sql_state,
            error_message,
            function_name
        )
        VALUES (
            v_sqlstate,
            v_error_message,
            'try_create_reservation_with_logging'
        );

        RETURN NULL;
END;
$$;

-- Consumers now use the new signatures. Remove the obsolete entry points
-- without CASCADE so an unexpected stored dependency fails this upgrade.
DROP FUNCTION IF EXISTS try_create_reservation_with_logging(
    BIGINT, BIGINT, DATE, DATE
);
DROP FUNCTION IF EXISTS try_create_reservation(BIGINT, BIGINT, DATE, DATE);
DROP FUNCTION IF EXISTS process_booking(
    BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR
);
DROP FUNCTION IF EXISTS create_reservation(BIGINT, BIGINT, DATE, DATE);

CREATE OR REPLACE TRIGGER trg_users_update_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at();

COMMIT;
