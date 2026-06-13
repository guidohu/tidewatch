import Toybox.Lang;

(:background)
module LocationUtilsBG {
    /**
     * Validates if the given object is a valid latitude coordinate (-90.0 to 90.0 degrees).
     * @param lat The latitude object to validate.
     * @return True if the value is a valid numeric latitude; false otherwise.
     */
    function isValidLatitude(lat as Object?) as Boolean {
        if (lat != null && lat has :toFloat) {
            var f = lat.toFloat();
            return f >= -90.0 && f <= 90.0;
        }
        return false;
    }

    /**
     * Validates if the given object is a valid longitude coordinate (-180.0 to 180.0 degrees).
     * @param lon The longitude object to validate.
     * @return True if the value is a valid numeric longitude; false otherwise.
     */
    function isValidLongitude(lon as Object?) as Boolean {
        if (lon != null && lon has :toFloat) {
            var f = lon.toFloat();
            return f >= -180.0 && f <= 180.0;
        }
        return false;
    }

    /**
     * Verifies if the location is set and valid (not 0.0, 0.0 and within valid bounds).
     * @param lat The latitude object to check.
     * @param lon The longitude object to check.
     * @return True if the coordinates are set, non-zero, and valid; false otherwise.
     */
    function isLocationSetAndValid(lat as Object?, lon as Object?) as Boolean {
        if (!isValidLatitude(lat) || !isValidLongitude(lon)) {
            return false;
        }
        if (lat != null && lon != null && lat has :toFloat && lon has :toFloat) {
            return !(lat.toFloat() == 0.0 && lon.toFloat() == 0.0);
        }
        return false;
    }
}

module LocationUtils {
    function isValidLatitude(lat as Object?) as Boolean {
        return LocationUtilsBG.isValidLatitude(lat);
    }

    function isValidLongitude(lon as Object?) as Boolean {
        return LocationUtilsBG.isValidLongitude(lon);
    }

    function isLocationSetAndValid(lat as Object?, lon as Object?) as Boolean {
        return LocationUtilsBG.isLocationSetAndValid(lat, lon);
    }
}
