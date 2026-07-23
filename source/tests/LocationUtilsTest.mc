import Toybox.Test;
import Toybox.Lang;

(:test)
function testIsValidLongitude(logger as Test.Logger) as Boolean {
    // Valid cases
    Test.assertMessage(LocationUtils.isValidLongitude(0.0), "0.0 should be valid");
    Test.assertMessage(LocationUtils.isValidLongitude(180.0), "180.0 should be valid");
    Test.assertMessage(LocationUtils.isValidLongitude(-180.0), "-180.0 should be valid");
    Test.assertMessage(LocationUtils.isValidLongitude(90.0), "90.0 should be valid");
    Test.assertMessage(LocationUtils.isValidLongitude(-90.0), "-90.0 should be valid");

    // Invalid cases
    Test.assertMessage(!LocationUtils.isValidLongitude(180.1), "180.1 should be invalid");
    Test.assertMessage(!LocationUtils.isValidLongitude(-180.1), "-180.1 should be invalid");
    Test.assertMessage(!LocationUtils.isValidLongitude(360.0), "360.0 should be invalid");
    Test.assertMessage(!LocationUtils.isValidLongitude(-360.0), "-360.0 should be invalid");

    return true;
}
