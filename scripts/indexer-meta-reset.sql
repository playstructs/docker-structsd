-- Reset the meta tables
-- Usually only needed when network ID changes
TRUNCATE TABLE structs.struct_type_meta;
TRUNCATE TABLE structs.planet_meta;
TRUNCATE TABLE structs.player_meta;
TRUNCATE TABLE structs.player_pending;
TRUNCATE TABLE structs.player_internal_pending;
TRUNCATE TABLE structs.player_address_meta;
TRUNCATE TABLE structs.player_address_activation_code;
TRUNCATE TABLE structs.player_external_pending;