-- Run only in a disposable, empty database. This fixture models the users
-- table immediately before upgrade 010 and verifies data preservation and
-- upgrade repeatability.

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

INSERT INTO public.users (
    user_code,
    email,
    password_hash,
    full_name,
    is_active
)
VALUES
    (
        'LEGACY-ACTIVE',
        'legacy-active@example.test',
        '$development-only$legacy-active',
        'Legacy Active User',
        TRUE
    ),
    (
        'LEGACY-INACTIVE',
        'legacy-inactive@example.test',
        '$development-only$legacy-inactive',
        'Legacy Inactive User',
        FALSE
    );

CREATE TEMP TABLE users_before_upgrade AS
SELECT
    user_id,
    user_code,
    email,
    password_hash,
    full_name,
    is_active,
    created_at,
    updated_at
FROM public.users;

\ir ../../schema/upgrades/010_add_user_roles.sql
\ir ../../schema/upgrades/010_add_user_roles.sql

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM public.users) <> 2 THEN
        RAISE EXCEPTION 'Upgrade 010 did not preserve every existing user';
    END IF;

    IF EXISTS (
        (
            SELECT * FROM users_before_upgrade
            EXCEPT
            SELECT
                user_id,
                user_code,
                email,
                password_hash,
                full_name,
                is_active,
                created_at,
                updated_at
            FROM public.users
        )
        UNION ALL
        (
            SELECT
                user_id,
                user_code,
                email,
                password_hash,
                full_name,
                is_active,
                created_at,
                updated_at
            FROM public.users
            EXCEPT
            SELECT * FROM users_before_upgrade
        )
    ) THEN
        RAISE EXCEPTION 'Upgrade 010 changed existing user data';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.users
        WHERE user_code = 'LEGACY-ACTIVE'
          AND email = 'legacy-active@example.test'
          AND password_hash = '$development-only$legacy-active'
          AND full_name = 'Legacy Active User'
          AND is_active = TRUE
          AND role = 'OPERATOR'
    ) OR NOT EXISTS (
        SELECT 1
        FROM public.users
        WHERE user_code = 'LEGACY-INACTIVE'
          AND email = 'legacy-inactive@example.test'
          AND password_hash = '$development-only$legacy-inactive'
          AND full_name = 'Legacy Inactive User'
          AND is_active = FALSE
          AND role = 'OPERATOR'
    ) THEN
        RAISE EXCEPTION 'Upgrade 010 did not backfill existing users';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.users'::REGCLASS
          AND conname = 'chk_users_role'
    ) THEN
        RAISE EXCEPTION 'Upgrade 010 did not create chk_users_role';
    END IF;
END;
$$;
