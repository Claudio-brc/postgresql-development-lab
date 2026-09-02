CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_service_ids    BIGINT[]
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_services JSONB;
BEGIN
    IF p_service_ids IS NULL THEN
        PERFORM replace_reservation_services(p_reservation_id, NULL);
        RETURN;
    END IF;

    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'service_id', grouped.service_id,
                'quantity', grouped.quantity
            )
            ORDER BY grouped.service_id
        ),
        '[]'::JSONB
    )
    INTO v_services
    FROM (
        SELECT item.service_id, COUNT(*)::INTEGER AS quantity
        FROM unnest(p_service_ids) AS item(service_id)
        GROUP BY item.service_id
    ) AS grouped;

    PERFORM replace_reservation_services(p_reservation_id, v_services);
END;
$$;

CREATE OR REPLACE FUNCTION add_services_to_reservation(
    p_reservation_id BIGINT,
    p_services       JSONB
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM replace_reservation_services(p_reservation_id, p_services);
END;
$$;
