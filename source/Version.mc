import Toybox.Lang;

(:background)
module Version {
    const STRING = "1.10.0";

    /**
     * Compares two semantic version strings (e.g. "1.1.0" and "1.0.0").
     * @param x The first version string.
     * @param y The second version string.
     * @return True if version x is higher than version y; false otherwise.
     */
    function isHigherThan(x as String, y as String) as Boolean {
        var xParts = parseVersionString(x);
        var yParts = parseVersionString(y);
        
        if (xParts[0] > yParts[0]) {
            return true;
        } else if (xParts[0] < yParts[0]) {
            return false;
        }
        
        if (xParts[1] > yParts[1]) {
            return true;
        } else if (xParts[1] < yParts[1]) {
            return false;
        }
        
        if (xParts[2] > yParts[2]) {
            return true;
        }
        
        return false;
    }

    /**
     * Compares two semantic version strings (e.g. "1.0.0" and "1.1.0").
     * @param x The first version string.
     * @param y The second version string.
     * @return True if version x is lower than version y; false otherwise.
     */
    function isLowerThan(x as String, y as String) as Boolean {
        return isHigherThan(y, x);
    }

    /**
     * Parses a version string into an array of [major, minor, patch] integers.
     * @param str The version string to parse.
     * @return Array containing [major, minor, patch] integers.
     */
    function parseVersionString(str as String) as Array<Number> {
        var parts = [0, 0, 0] as Array<Number>;
        var s = str;
        
        var dot1 = s.find(".");
        if (dot1 != null) {
            var majorStr = s.substring(0, dot1);
            if (majorStr != null) {
                var val = majorStr.toNumber();
                if (val != null) { parts[0] = val; }
            }
            s = s.substring(dot1 + 1, s.length());
            if (s != null) {
                var dot2 = s.find(".");
                if (dot2 != null) {
                    var minorStr = s.substring(0, dot2);
                    if (minorStr != null) {
                        var val = minorStr.toNumber();
                        if (val != null) { parts[1] = val; }
                    }
                    var patchStr = s.substring(dot2 + 1, s.length());
                    if (patchStr != null) {
                        var val = patchStr.toNumber();
                        if (val != null) { parts[2] = val; }
                    }
                } else {
                    var val = s.toNumber();
                    if (val != null) { parts[1] = val; }
                }
            }
        } else {
            var val = s.toNumber();
            if (val != null) { parts[0] = val; }
        }
        
        return parts;
    }
}
