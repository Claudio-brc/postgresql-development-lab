/*
==========================================
Retrieve the complete metadata document
==========================================
*/

SELECT
    property_name,
    metadata
FROM properties
where metadata is not null;

/*
==========================================
Access a top-level object
==========================================
*/

SELECT
    property_name,
    metadata -> 'amenities' AS amenities
FROM properties
where metadata is not null;

/*
==========================================
Access a top-level array
==========================================
*/

SELECT
    property_name,
    metadata -> 'languages' AS languages
FROM properties
where metadata is not null;

/*
==========================================
Access nested values
==========================================
*/

SELECT
    property_name,
    metadata -> 'arrival_departure' ->> 'check_in_from'    AS check_in_from,
    metadata -> 'arrival_departure' ->> 'check_in_to'      AS check_in_to,
    metadata -> 'arrival_departure' ->> 'check_out_until'  AS check_out_until
FROM properties
where metadata is not null;

/*
==========================================
Filter: Properties that do not allow pets
==========================================
*/

SELECT
    property_name
FROM properties
WHERE metadata -> 'house_rules' ->> 'pets_allowed' = 'false';
