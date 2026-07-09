SELECT jsonb_set(
    '{"amenities":{"wifi":true,"parking":false}}'::jsonb,
    '{amenities,parking}',
    'true'::jsonb
);


/*

result:

{
  "amenities": {
    "wifi": true,
    "parking": true
  }
}


*/