INSERT INTO guests (full_name, email)
SELECT
    'Guest ' || n,
    'guest' || n || '@example.com'
FROM generate_series(1,20) AS n;

INSERT INTO properties (property_name, nightly_rate)
VALUES
('Lake View Cabin', 120.00),
('Mountain Retreat', 150.00),
('Downtown Apartment', 90.00),
('Patagonia Loft', 110.00),
('Forest House', 180.00),
('Riverside Cottage', 140.00),
('City Studio', 75.00),
('Lakeside Bungalow', 200.00),
('Family Cabin', 160.00),
('Luxury Suite', 300.00);

INSERT INTO reservations (
    guest_id,
    property_id,
    check_in_date,
    check_out_date,
    status,
    total_amount
)
VALUES
(1,1,'2026-07-01','2026-07-05','CONFIRMED',480.00),
(2,2,'2026-07-10','2026-07-15','CONFIRMED',750.00),
(3,3,'2026-08-01','2026-08-04','PENDING',270.00),
(4,4,'2026-08-10','2026-08-15','CONFIRMED',550.00),
(5,5,'2026-09-01','2026-09-03','CANCELLED',360.00),
(6,1,'2026-09-10','2026-09-15','CONFIRMED',600.00),
(7,6,'2026-10-01','2026-10-04','PENDING',420.00),
(8,7,'2026-10-10','2026-10-12','CONFIRMED',150.00),
(9,8,'2026-11-01','2026-11-05','CONFIRMED',800.00),
(10,9,'2026-11-15','2026-11-18','PENDING',480.00);


INSERT INTO payments (
    reservation_id,
    payment_amount,
    payment_method,
    status
)
VALUES
(1,480.00,'CREDIT_CARD','PAID'),
(2,750.00,'BANK_TRANSFER','PAID'),
(4,550.00,'DEBIT_CARD','PAID'),
(6,600.00,'BANK_TRANSFER','PAID'),
(8,150.00,'CREDIT_CARD','PAID'),
(9,800.00,'BANK_TRANSFER','PAID');

INSERT INTO app_settings
(setting_key, setting_value, description)
VALUES
('weekly_discount_percent', '10', 'Discount applied to weekly stays'),

('weekly_discount_nights', '7', 'Minimum nights to apply weekly discount'),

('max_pending_reservations', '3', 'Maximum pending reservations per guest'),

('max_stay_nights', '30', 'Maximum allowed stay');

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    minimum_nights
)
VALUES
(
    'Weekly Discount',
    'STAY_LENGTH',
    10,
    7
);

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    minimum_nights
)
VALUES
(
    'Monthly Discount',
    'STAY_LENGTH',
    20,
    30
);

INSERT INTO discounts
(
    discount_name,
    discount_type,
    discount_percent,
    valid_from,
    valid_to
)
VALUES
(
    'Low Season',
    'DATE_RANGE',
    15,
    '2026-05-01',
    '2026-06-30'
);

INSERT INTO services
(
    service_name,
    description,
    price
)
VALUES
(
    'Breakfast',
    'Continental breakfast served every morning.',
    15.00
),
(
    'Airport Transfer',
    'Private transfer between the airport and the property.',
    40.00
),
(
    'Late Check-out',
    'Extended check-out after the standard departure time.',
    25.00
),
(
    'Pet Fee',
    'Additional charge for guests traveling with pets.',
    20.00
),
(
    'Extra Cleaning',
    'Additional cleaning service during the stay.',
    30.00
);