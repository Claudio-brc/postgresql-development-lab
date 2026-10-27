-- Apply after 009_currencies_and_partial_payments.sql.
-- Existing application users receive the OPERATOR role.

BEGIN;

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS role VARCHAR(20);

UPDATE public.users
SET role = 'OPERATOR'
WHERE role IS NULL;

ALTER TABLE public.users
    ALTER COLUMN role SET DEFAULT 'OPERATOR',
    ALTER COLUMN role SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.users'::REGCLASS
          AND conname = 'chk_users_role'
    ) THEN
        ALTER TABLE public.users
            ADD CONSTRAINT chk_users_role
            CHECK (role IN ('ADMIN', 'OPERATOR'));
    END IF;
END;
$$;

COMMIT;
