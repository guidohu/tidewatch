import Toybox.Test;

(:test)
module LocationUtilsTest {

    (:test)
    function testIsValidLatitude(logger as Test.Logger) as Boolean {
        // Valid bounds
        Test.assertEqual(LocationUtilsBG.isValidLatitude(0.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(90.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(-90.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(45.5), true);

        // Out of bounds
        Test.assertEqual(LocationUtilsBG.isValidLatitude(90.1), false);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(-90.1), false);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(100.0), false);
        Test.assertEqual(LocationUtilsBG.isValidLatitude(-100.0), false);

        return true;
    }

    (:test)
    function testIsValidLongitude(logger as Test.Logger) as Boolean {
        // Valid bounds
        Test.assertEqual(LocationUtilsBG.isValidLongitude(0.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(180.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(-180.0), true);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(45.5), true);

        // Out of bounds
        Test.assertEqual(LocationUtilsBG.isValidLongitude(180.1), false);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(-180.1), false);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(200.0), false);
        Test.assertEqual(LocationUtilsBG.isValidLongitude(-200.0), false);

        return true;
    }
}
