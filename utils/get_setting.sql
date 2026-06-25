CREATE OR REPLACE FUNCTION get_setting(
    p_setting_key VARCHAR
)
RETURNS VARCHAR AS $$
DECLARE
    v_setting_value VARCHAR;
BEGIN

    SELECT setting_value
      INTO v_setting_value
      FROM app_settings
     WHERE setting_key = p_setting_key;

    IF v_setting_value IS NULL THEN
        RAISE EXCEPTION
            'Setting "%" not found.',
            p_setting_key;
    END IF;

    RETURN v_setting_value;

END;
$$ LANGUAGE plpgsql;