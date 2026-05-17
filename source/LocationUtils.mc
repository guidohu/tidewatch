import Toybox.Lang;

(:background)
module LocationUtils {
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
}
