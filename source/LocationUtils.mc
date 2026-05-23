import Toybox.Lang;

(:background)
module LocationUtils {
    /**
     * Validates if the given object is a valid latitude coordinate (-90.0 to 90.0 degrees).
     * @param lat The latitude object to validate.
     * @return True if the value is a valid numeric latitude; false otherwise.
     */
    function isValidLatitude(lat as Object?) as Boolean {
        if (lat == null) {
            return false;
        }
        if (lat instanceof Float || lat instanceof Double || lat instanceof Number) {
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
        if (lon == null) {
            return false;
        }
        if (lon instanceof Float || lon instanceof Double || lon instanceof Number) {
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
        if ((lat instanceof Float || lat instanceof Double || lat instanceof Number) &&
            (lon instanceof Float || lon instanceof Double || lon instanceof Number)) {
            return !(lat.toFloat() == 0.0 && lon.toFloat() == 0.0);
        }
        return false;
    }
}
