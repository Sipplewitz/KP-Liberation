scriptName "KPLIB_uiManager";

disableSerialization;

private ["_sectorcontrols", "_resourcescontrols", "_active_sectors_hint", "_uiticks", "_attacked_string", "_active_sectors_string", "_color_readiness", "_nearest_active_sector", "_zone_size", "_colorzone", "_bar", "_barwidth", "_distfob", "_nearfob", "_fobdistance", "_showResources", "_notNearFOB", "_resource_area"];

_sectorcontrols = [
    201,    // BG Picture Sector
    202,    // Capture Frame
    203,    // Capture Frame OPFOR
    205,    // Label Point
    244     // Capture Frame BLUFOR
];

_active_sectors_hint = false;
_distfob = (GRLIB_fob_range * 0.8);
_notNearFOB = false;
_resource_area = "";
GRLIB_ui_notif = "";
KP_liberation_supplies = 0;
KP_liberation_ammo = 0;
KP_liberation_fuel = 0;
KP_liberation_air_vehicle_building_near = false;
KP_liberation_recycle_building_near = false;

_uiticks = 0;

waitUntil { !isNil "synchro_done" };
waitUntil { synchro_done };

if ( isNil "cinematic_camera_started" ) then { cinematic_camera_started = false };
if ( isNil "halojumping" ) then { halojumping = false };

private _overlay = displayNull;
private _overlayVisible = false;
private _showHud = false;
private _showResources = false;

while { true } do {
    _showHud = alive player && {!dialog && {isNull curatorCamera && {!cinematic_camera_started && !halojumping}}};

    if (_showHud && {!_overlayVisible}) then {
        "KPLIB_ui" cutRsc ["KPLIB_overlay", "PLAIN", 1];
        _uiticks = 0;
    };
    if (!_showHud && {_overlayVisible}) then {
        "KPLIB_ui" cutText ["", "PLAIN"];
    };

    _overlay = uiNamespace getVariable ['KPLIB_overlay', displayNull];
    _overlayVisible = !isNull _overlay;

    _nearfob = [] call KPLIB_fnc_getNearestFob;
    _fobdistance = 9999;
    if ( count _nearfob == 3 ) then {
        _fobdistance = player distance _nearfob;
    };

    if (_fobdistance < _distfob) then {
        _showResources = true;
        ([_nearfob] call KPLIB_fnc_getFobResources) params ["", "_supplies", "_ammo", "_fuel", "_hasAir", "_hasRecycling"];

        if (KP_liberation_resources_global) then {
            _resource_area = localize "STR_RESOURCE_GLOBAL";
            KP_liberation_supplies = KP_liberation_supplies_global;
            KP_liberation_ammo = KP_liberation_ammo_global;
            KP_liberation_fuel = KP_liberation_fuel_global;
        } else {
            _resource_area = toUpper ([_nearfob] call KPLIB_fnc_getFobName);

            KP_liberation_supplies = _supplies;
            KP_liberation_ammo = _ammo;
            KP_liberation_fuel = _fuel;
        };
        KP_liberation_air_vehicle_building_near = _hasAir;
        KP_liberation_recycle_building_near = _hasRecycling;

        // Fix for small script error that variables will be "any" for a second after an FOB has been build
        // TODO get rid off this
        // probably will not happen anymore if we will use "playerNamespace"
        if (isNil "KP_liberation_supplies") then {KP_liberation_supplies = 0;};
        if (isNil "KP_liberation_ammo") then {KP_liberation_ammo = 0;};
        if (isNil "KP_liberation_fuel") then {KP_liberation_fuel = 0;};
    } else {
        _showResources = false;
        KP_liberation_supplies = 0;
        KP_liberation_ammo = 0;
        KP_liberation_fuel = 0;
        KP_liberation_air_vehicle_building_near = false;
        KP_liberation_recycle_building_near = false;
    };

    if ( _overlayVisible) then {

        (_overlay displayCtrl (266)) ctrlSetText format [ "%1", GRLIB_ui_notif ];
        (_overlay displayCtrl (267)) ctrlSetText format [ "%1", GRLIB_ui_notif ];

        if ((markerPos "opfor_capture_marker") distance markers_reset > 100 ) then {

            private [ "_attacked_string" ];
            _attacked_string = [markerpos "opfor_capture_marker"] call KPLIB_fnc_getLocationName;

            (_overlay displayCtrl (401)) ctrlShow true;
            (_overlay displayCtrl (402)) ctrlSetText _attacked_string;
            (_overlay displayCtrl (403)) ctrlSetText (markerText "opfor_capture_marker");
        } else {
            (_overlay displayCtrl (401)) ctrlShow false;
            (_overlay displayCtrl (402)) ctrlSetText "";
            (_overlay displayCtrl (403)) ctrlSetText "";
        };

        // Update resources overlay
        [
            _overlay,
            _showResources,
            _uiticks % 5 == 0 // update values
        ] call KPLIB_fnc_overlayUpdateResources;

        if ( _uiticks % 25 == 0 ) then {

            if (!isNil "active_sectors" && ( [] call KPLIB_fnc_getOpforCap >= GRLIB_sector_cap)) then {

                (_overlay displayCtrl (517)) ctrlShow true;

                if ( !_active_sectors_hint ) then {
                    hint localize "STR_OVERLOAD_HINT";
                    _active_sectors_hint = true;
                };

                _active_sectors_string = "<t align='right' color='#e0e000'>" + (localize "STR_ACTIVE_SECTORS") + "<br/>";
                {
                    _active_sectors_string = _active_sectors_string + (markertext _x) + "<br/>";
                } foreach active_sectors;
                _active_sectors_string = _active_sectors_string + "</t>";
                (_overlay displayCtrl (516)) ctrlSetStructuredText parseText _active_sectors_string;

            } else {
                (_overlay displayCtrl (516)) ctrlSetStructuredText parseText " ";
                (_overlay displayCtrl (517)) ctrlShow false;
            };

            _nearest_active_sector = [ GRLIB_sector_size ] call KPLIB_fnc_getNearestSector;
            if ( _nearest_active_sector != "" ) then {
                _zone_size = GRLIB_capture_size;
                if ( _nearest_active_sector in sectors_bigtown ) then {
                    _zone_size = GRLIB_capture_size * 1.4;
                };

                "zone_capture" setmarkerposlocal (markerpos _nearest_active_sector);
                _colorzone = "ColorGrey";
                if ( [ markerpos _nearest_active_sector, _zone_size ] call KPLIB_fnc_getSectorOwnership == GRLIB_side_friendly ) then { _colorzone = GRLIB_color_friendly };
                if ( [ markerpos _nearest_active_sector, _zone_size ] call KPLIB_fnc_getSectorOwnership == GRLIB_side_enemy ) then { _colorzone = GRLIB_color_enemy };
                if ( [ markerpos _nearest_active_sector, _zone_size ] call KPLIB_fnc_getSectorOwnership == GRLIB_side_resistance ) then { _colorzone = "ColorCivilian" };
                "zone_capture" setmarkercolorlocal _colorzone;

                _ratio = [_nearest_active_sector] call KPLIB_fnc_getBluforRatio;
                _barwidth = 0.084 * safezoneW * _ratio;
                _bar = _overlay displayCtrl (244);
                _bar ctrlSetPosition [(ctrlPosition _bar) select 0,(ctrlPosition _bar) select 1,_barwidth,(ctrlPosition _bar) select 3];
                _bar ctrlCommit ([0, 2] select ctrlShown _bar);

                (_overlay displayCtrl (205)) ctrlSetText (markerText _nearest_active_sector);
                { (_overlay displayCtrl (_x)) ctrlShow true; } foreach  _sectorcontrols;
                if ( _nearest_active_sector in blufor_sectors ) then {
                    (_overlay displayCtrl (205)) ctrlSetTextColor [0,0.3,1.0,1];
                } else {
                    (_overlay displayCtrl (205)) ctrlSetTextColor [0.85,0,0,1];
                };

                "zone_capture" setMarkerSizeLocal [ _zone_size,_zone_size ];
            } else {
                { (_overlay displayCtrl (_x)) ctrlShow false; } foreach  _sectorcontrols;
                "zone_capture" setmarkerposlocal markers_reset;
            };
        };
    };
    _uiticks = _uiticks + 1;
    if ( _uiticks > 1000 ) then { _uiticks = 0 };
    uiSleep 0.25;
};
