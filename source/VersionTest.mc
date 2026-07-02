import Toybox.Lang;
import Toybox.Test;

(:test)
function testParseVersionString(logger as Logger) as Boolean {
    // 1. Happy path
    var res1 = Version.parseVersionString("1.2.3");
    if (res1[0] != 1 || res1[1] != 2 || res1[2] != 3) {
        logger.debug("Failed happy path: 1.2.3");
        return false;
    }

    // 2. Partial versions
    var res2 = Version.parseVersionString("1.2");
    if (res2[0] != 1 || res2[1] != 2 || res2[2] != 0) {
        logger.debug("Failed partial version: 1.2");
        return false;
    }

    var res3 = Version.parseVersionString("1");
    if (res3[0] != 1 || res3[1] != 0 || res3[2] != 0) {
        logger.debug("Failed partial version: 1");
        return false;
    }

    // 3. Empty string
    var res4 = Version.parseVersionString("");
    if (res4[0] != 0 || res4[1] != 0 || res4[2] != 0) {
        logger.debug("Failed empty string");
        return false;
    }

    // 4. Non-numeric parts
    var res5 = Version.parseVersionString("1.a.3");
    if (res5[0] != 1 || res5[1] != 0 || res5[2] != 3) {
        logger.debug("Failed non-numeric: 1.a.3");
        return false;
    }

    // 5. Too many parts
    var res6 = Version.parseVersionString("1.2.3.4");
    if (res6[0] != 1 || res6[1] != 2 || res6[2] != 3) {
        logger.debug("Failed too many parts: 1.2.3.4");
        return false;
    }

    return true;
}
