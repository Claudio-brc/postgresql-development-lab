# Currencies and partial payments

This final scenario adds explicit ISO 4217-style currency codes, independent
reservation/payment exchange-rate snapshots, base-currency reporting, and
partial payments. Rates always use `1 source currency = rate base currency`
and are stored as `NUMERIC(20,10)`; money remains `NUMERIC(16,6)`.

The explicit-currency APIs are:

```text
initialize_reservation(..., services, currency_code, exchange_rate)
process_reservation_payment(reservation_id, amount, method, exchange_rate)
create_reservation(..., services, currency_code,
                   reservation_exchange_rate, payment_exchange_rate)
```

Convenience overloads omit services. Existing creation signatures continue to
mean base currency at rate 1. The legacy three-argument payment overload is
valid only for base-currency reservations, because a new foreign-currency
payment needs its own supplied snapshot.

Each successful payment is a separate `PAID` row. A positive balance at or
above the `0.01` settlement tolerance remains `PENDING`; a balance within the
tolerance becomes `CONFIRMED`. Overpayments at or beyond the tolerance are
rejected. Derived reporting is exposed through:

```text
calculate_reservation_potential_value_in_base_currency(BIGINT)
calculate_reservation_collected_value_in_base_currency(BIGINT)
```
