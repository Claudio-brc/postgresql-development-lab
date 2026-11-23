# Property capacity

This final scenario adds maximum property occupancy and reservation guest
counts without changing accommodation pricing. The four-argument
`is_property_available` and guest-aware creation overloads are canonical.
Historical overloads delegate with one guest.

`properties.max_guests` is the current booking limit. A reservation stores the
declared occupancy in `reservations.guests_count`; changing property capacity
later does not rewrite that historical value. Direct writes are protected by
positive-value checks and a capacity trigger, while date overlap remains
protected by the existing exclusion constraint.
