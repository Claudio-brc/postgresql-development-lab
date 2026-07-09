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
Extract a scalar value
==========================================
*/

SELECT
    property_name,
    metadata ->> 'languages' AS languages
FROM properties
where metadata is not null;

/*
==========================================
Access nested values
==========================================
*/

SELECT
    property_name,
    metadata -> 'check_in' ->> 'from' AS check_in_from,
    metadata -> 'check_in' ->> 'to'   AS check_in_to
FROM properties
where metadata is not null;

/*
==========================================
Filter: Properties that allow pets
==========================================
*/

SELECT
    property_name
FROM properties
WHERE metadata -> 'house_rules' ->> 'pets_allowed' = 'false';