# REQ-001 — Usuarios de la aplicación

Estado: implementado.

## Objetivo

Incorporar `public.users` y garantizar que toda reserva identifique al usuario de Booking API que la creó, manteniendo separados estos conceptos:

```text
reservations.guest_id
  → persona alojada o titular de la reserva

reservations.created_by_user_id
  → usuario de Booking API que creó la reserva
```

No se incorporan autenticación, login, JWT, hashing en PostgreSQL, roles, permisos, sesiones, refresh tokens ni una relación User ↔ Guest. Booking API no forma parte del cambio.

## Modelo de `public.users`

```sql
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
```

`password_hash` usa `VARCHAR(255)` para admitir representaciones codificadas de distintos algoritmos sin acoplar el esquema a uno de ellos. PostgreSQL sólo almacena el valor previamente procesado.

## Usuario inicial

La instalación y el upgrade crean el usuario de aplicación:

- `user_code = 'CALVAREZ'`;
- `full_name = 'Claudio Alvarez'`;
- `email = 'calvarez.brc@gmail.com'`;
- `is_active = TRUE`.

El seed almacena un placeholder explícitamente ficticio en `password_hash`. No es una contraseña ni una credencial válida. La generación y gestión del hash real corresponde a Booking API/Auth.

El `user_id` nunca se asume igual a `1`; toda relación de seed o migración lo resuelve mediante `user_code = 'CALVAREZ'`.

## Relación obligatoria con reservas

El estado final es:

```sql
created_by_user_id BIGINT NOT NULL
```

con:

- FK `fk_reservations_created_by_user` hacia `users(user_id)`;
- índice `idx_reservations_created_by_user_id`;
- sin `ON DELETE CASCADE`.

## Estrategia de migración

El upgrade se ejecuta dentro de una transacción y sigue este orden:

1. crear `public.users`;
2. insertar `CALVAREZ`;
3. agregar `created_by_user_id` temporalmente nullable;
4. resolver el `user_id` de `CALVAREZ` por `user_code`;
5. asignarlo a reservas existentes sin creador;
6. abortar si queda algún `NULL`;
7. aplicar `NOT NULL`;
8. crear la FK y el índice;
9. instalar las nuevas firmas de funciones;
10. retirar las firmas antiguas sin usar `CASCADE`.

La instalación limpia crea directamente el modelo final y sus seeds ya incluyen el creador obligatorio.

## Funciones

El estado final contiene una única firma de cada función afectada:

```text
create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)
process_booking(BIGINT, BIGINT, DATE, DATE, NUMERIC, VARCHAR, BIGINT)
try_create_reservation(BIGINT, BIGINT, DATE, DATE, BIGINT)
try_create_reservation_with_logging(BIGINT, BIGINT, DATE, DATE, BIGINT)
```

`p_created_by_user_id` es obligatorio, no tiene default y se propaga usando la identidad técnica `users.user_id`. No se mantienen wrappers ni overloads históricos.

`try_create_reservation` traduce una violación de FK como un identificador inválido de guest, property o user.

## Archivos fuente

- `schema/01_core_schema.sql`.
- `schema/02_seed_data.sql`.
- `schema/upgrades/006_add_application_users.sql`.
- `scenarios/02_functions_business_rules/05_create_reservation.sql`.
- `scenarios/02_functions_business_rules/06_process_booking.sql`.
- `scenarios/03_triggers_and_auditing/01_update_updated_at_trigger.sql`.
- `scenarios/04_error_handling_and_logging/01_try_create_reservation.sql`.
- `scenarios/04_error_handling_and_logging/02_try_create_reservation_with_logging.sql`.
- `examples/02_functions_business_rules.sql`.
- `examples/08_guest_soft_delete.sql`.
- `examples/10_application_users.sql`.
- `README.md`.

Los archivos de `install/` se regeneran únicamente mediante `tools/build-all.ps1`.

## Verificaciones

La validación debe comprobar:

1. existencia y estado activo de `CALVAREZ`;
2. generación automática de `user_id`;
3. obligatoriedad, formato y unicidad de `user_code`;
4. unicidad de email;
5. conservación del `password_hash` suministrado;
6. independencia de Guest y User;
7. relación User → Reservation;
8. cero reservas con `created_by_user_id IS NULL`;
9. FK válida hacia `users`;
10. rechazo de reservas sin creador o con un `user_id` inexistente;
11. una sola firma vigente por función afectada;
12. ausencia de wrappers de compatibilidad.

La instalación limpia y el upgrade desde el esquema anterior deben validarse por separado en bases descartables.
