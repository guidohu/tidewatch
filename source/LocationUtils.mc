import Toybox.Lang;

(:background)
module LocationUtilsBG {
    /**
     * Validates if the given object is a valid latitude coordinate (-90.0 to 90.0 degrees).
     * @param lat The latitude object to validate.
     * @return True if the value is a valid numeric latitude; false otherwise.
     */
    function isValidLatitude(lat as Float) as Boolean {
        return lat >= -90.0 && lat <= 90.0;
    }

    /**
     * Validates if the given object is a valid longitude coordinate (-180.0 to 180.0 degrees).
     * @param lon The longitude object to validate.
     * @return True if the value is a valid numeric longitude; false otherwise.
     */
    function isValidLongitude(lon as Float) as Boolean {
        return lon >= -180.0 && lon <= 180.0;
    }

    /**
     * Verifies if the location is set and valid (not 0.0, 0.0 and within valid bounds).
     * @param lat The latitude object to check.
     * @param lon The longitude object to check.
     * @return True if the coordinates are set, non-zero, and valid; false otherwise.
     */
    function isLocationSetAndValid(lat as Toybox.Application.Properties.ValueType, lon as Toybox.Application.Properties.ValueType) as Boolean {
        if (!(lat has :toFloat) || !(lon has :toFloat)) {
            return false;
        }
        if (!isValidLatitude(lat.toFloat()) || !isValidLongitude(lon.toFloat())) {
            return false;
        }
        return !(lat.toFloat() == 0.0 && lon.toFloat() == 0.0);
    }

    /**
     * Safely converts an object to a Float using :toFloat.
     */
    function getAsFloat(val as Toybox.Application.Properties.ValueType) as Float {
        if (val has :toFloat) {
            return val.toFloat() as Float;
        }
        return 0.0;
    }
}

module LocationUtils {
    function isValidLatitude(lat as Toybox.Application.Properties.ValueType) as Boolean {
        return LocationUtilsBG.isValidLatitude(lat);
    }

    function isValidLongitude(lon as Toybox.Application.Properties.ValueType) as Boolean {
        return LocationUtilsBG.isValidLongitude(lon);
    }

    function isLocationSetAndValid(lat as Toybox.Application.Properties.ValueType, lon as Toybox.Application.Properties.ValueType) as Boolean {
        return LocationUtilsBG.isLocationSetAndValid(lat, lon);
    }

    function getAsFloat(val as Toybox.Application.Properties.ValueType) as Float {
        return LocationUtilsBG.getAsFloat(val);
    }
}

