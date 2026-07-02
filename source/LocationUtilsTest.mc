import Toybox.Test;
import Toybox.Application.Properties;
import Toybox.Lang;

(:test)
function testGetAsFloatWithFloat(logger as Logger) as Boolean {
    var val = 3.14f;
    var result = LocationUtilsBG.getAsFloat(val);
    Test.assertEqual(result, 3.14f);
    return true;
}

(:test)
function testGetAsFloatWithNumber(logger as Logger) as Boolean {
    var val = 42;
    var result = LocationUtilsBG.getAsFloat(val);
    Test.assertEqual(result, 42.0f);
    return true;
}

(:test)
function testGetAsFloatWithString(logger as Logger) as Boolean {
    var val = "1.23";
    var result = LocationUtilsBG.getAsFloat(val);
    Test.assertEqual(result, 1.23f);
    return true;
}

(:test)
function testGetAsFloatWithBoolean(logger as Logger) as Boolean {
    var val = true;
    var result = LocationUtilsBG.getAsFloat(val);
    Test.assertEqual(result, 0.0f);
    return true;
}

(:test)
function testGetAsFloatWithNull(logger as Logger) as Boolean {
    var val = null;
    var result = LocationUtilsBG.getAsFloat(val);
    Test.assertEqual(result, 0.0f);
    return true;
}
