-- FUNCTION: public.get_table_columns(text)

-- DROP FUNCTION IF EXISTS public.get_table_columns(text);

CREATE OR REPLACE FUNCTION public.get_table_columns(
	p_table_name text)
    RETURNS TABLE(column_name text, data_type text, max_length integer, is_nullable text) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
BEGIN

    RETURN QUERY
    SELECT
        c.column_name::TEXT,
        c.data_type::TEXT,
        c.character_maximum_length::INTEGER,
        c.is_nullable::TEXT
    FROM information_schema.columns c
    WHERE c.table_schema = 'public'
      AND c.table_name = LOWER(p_table_name)
    ORDER BY c.ordinal_position;

END;
$BODY$;

ALTER FUNCTION public.get_table_columns(text)
    OWNER TO postgres;
