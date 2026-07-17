import Toybox.Lang;

(:background)
module LocationUtilsBG {
    /**
     * Validates if the given object is a valid latitude coordinate (-90.0 to 90.0 degrees).
     * @param lat The latitude object to validate.
     * @return True if the value is a valid numeric latitude; false otherwise.
     */
    function isValidLatitude(lat as Toybox.Application.Properties.ValueType) as Boolean {
        if (lat == null || !(lat has :toFloat)) {
            return false;
        }
        var f = lat.toFloat();
        return f != null && f >= -90.0 && f <= 90.0;
    }

    /**
     * Validates if the given object is a valid longitude coordinate (-180.0 to 180.0 degrees).
     * @param lon The longitude object to validate.
     * @return True if the value is a valid numeric longitude; false otherwise.
     */
    function isValidLongitude(lon as Toybox.Application.Properties.ValueType) as Boolean {
        if (lon == null || !(lon has :toFloat)) {
            return false;
        }
        var f = lon.toFloat();
        return f != null && f >= -180.0 && f <= 180.0;
    }

    /**
     * Verifies if the location is set and valid (not 0.0, 0.0 and within valid bounds).
     * @param lat The latitude object to check.
     * @param lon The longitude object to check.
     * @return True if the coordinates are set, non-zero, and valid; false otherwise.
     */
    function isLocationSetAndValid(lat as Toybox.Application.Properties.ValueType, lon as Toybox.Application.Properties.ValueType) as Boolean {
        if (lat == null || lon == null) {
            return false;
        }
        if (!(lat has :toFloat) || !(lon has :toFloat)) {
            return false;
        }
        var latFloat = lat.toFloat();
        var lonFloat = lon.toFloat();
        if (latFloat == null || lonFloat == null) {
            return false;
        }
        if (!isValidLatitude(latFloat) || !isValidLongitude(lonFloat)) {
            return false;
        }
        return !(latFloat == 0.0 && lonFloat == 0.0);
    }

    /**
     * Safely converts an object to a Float using :toFloat.
     */
    function getAsFloat(val as Toybox.Application.Properties.ValueType) as Float {
        if (val == null || !(val has :toFloat)) {
            return 0.0;
        }
        var f = val.toFloat();
        return f != null ? f : 0.0;
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

