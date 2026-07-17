import Toybox.Lang;

(:background)
module VersionBG {
    const STRING = "2.6.0";
}

module Version {
    const STRING = VersionBG.STRING;

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
        
        for (var i = 0; i < 3; i++) {
            if (s == null || s.length() == 0) {
                break;
            }
            var dot = s.find(".");
            var numStr = (dot != null) ? s.substring(0, dot) : s;
            if (numStr != null) {
                var val = numStr.toNumber();
                if (val != null) {
                    parts[i] = val;
                }
            }
            if (dot != null) {
                s = s.substring(dot + 1, s.length());
            } else {
                s = "";
            }
        }
        
        return parts;
    }
}
