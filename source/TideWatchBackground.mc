import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

(:background)
class TideWatchBackground extends System.ServiceDelegate {

    var mPendingTides = null;
    var mPendingSpotName = null;
    var mSpotId = null;

    function initialize() {
        ServiceDelegate.initialize();
        System.println("Tide Watch started successfully");
    }

    function onTemporalEvent() as Void {
        mSpotId = Application.Properties.getValue("SpotId");
        if (mSpotId == null || mSpotId.equals("")) {
            mSpotId = "6269dc2c491aa9ad66235f52"; // Canggu default
        }

        // Step 1: Start the sequential data fetch (Tides -> Waves)
        // Note: Requests are chained sequentially to stay within strict background memory limits.
        makeTideRequest();
    }

    function makeTideRequest() as Void {
        var url = "https://services.surfline.com/kbyg/spots/forecasts/tides?spotId=" + mSpotId + "&days=2&intervalHours=1";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        System.println("Background: Requesting Tides from: " + url);
        // onReceiveTideResponse will call makeWaveRequest. This way the request is sequential.
        Communications.makeWebRequest(url, null, options, method(:onReceiveTideResponse));
    }

    function makeWaveRequest() as Void {
        var url = "https://services.surfline.com/kbyg/spots/forecasts/wave?spotId=" + mSpotId + "&days=2&intervalHours=1";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        System.println("Background: Requesting Waves from: " + url);
        Communications.makeWebRequest(url, null, options, method(:onReceiveWaveResponse));
    }

    function onReceiveTideResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Background: Tides response code: " + responseCode);
        
        if (responseCode == 200 && data != null) {
            var dataObj = data.get("data");
            if (dataObj != null && dataObj instanceof Dictionary) {
                var tides = dataObj.get("tides");
                if (tides != null && tides instanceof Array) {
                    var keepCount = 0;
                    for (var i = 0; i < tides.size(); i++) {
                        keepCount++;
                        if (keepCount >= 60) { break; }
                    }
                    var itemsToKeep = new Array<Dictionary>[keepCount];
                    for (var i = 0; i < keepCount; i++) {
                        var tide = tides[i] as Dictionary;
                        itemsToKeep[i] = {
                            "t" => tide.get("timestamp"),
                            "y" => tide.get("type"),
                            "v" => tide.get("height")
                        };
                    }
                    var spotName = "Unknown Spot";
                    var associated = data.get("associated");
                    if (associated != null && associated instanceof Dictionary) {
                        var tideLocation = associated.get("tideLocation");
                        if (tideLocation != null && tideLocation instanceof Dictionary) {
                            var fullName = tideLocation.get("name");
                            if (fullName != null && fullName instanceof String) {
                                var commaIdx = fullName.find(",");
                                if (commaIdx != null) {
                                    spotName = fullName.substring(0, commaIdx);
                                } else {
                                    spotName = fullName;
                                }
                            }
                        }
                    }

                    System.println("Prepared " + keepCount + " items for tides, spot=" + spotName);
                    mPendingTides = itemsToKeep;
                    mPendingSpotName = spotName;
                    
                    // Step 2: Clear memory and fetch Wave Data
                    data = null; 
                    makeWaveRequest();
                    return;
                }
            }
        }
        Background.exit({"te" => responseCode});
    }
    
    function onReceiveWaveResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Background: Waves response code: " + responseCode);
        
        if (responseCode == 200 && data != null) {
            var dataObj = data.get("data");
            if (dataObj != null && dataObj instanceof Dictionary) {
                var waveArray = dataObj.get("wave");
                if (waveArray != null && waveArray instanceof Array) {
                    var now = Time.now().value();
                    var keepCount = 0;
                    for (var i = 0; i < waveArray.size(); i++) {
                        var waveItem = waveArray[i] as Dictionary;
                        var ts = waveItem.get("timestamp");
                        if (ts != null && (ts as Number) < now - 4 * 3600) { continue; }
                        keepCount++;
                        if (keepCount >= 24) { break; } 
                    }
                    
                    var itemsToKeep = new Array<Dictionary>[keepCount];
                    var idx = 0;
                    for (var i = 0; i < waveArray.size() && idx < keepCount; i++) {
                        var waveItem = waveArray[i] as Dictionary;
                        var ts = waveItem.get("timestamp");
                        if (ts == null || (ts as Number) < now - 4 * 3600) { continue; }
                        
                        var swells = waveItem.get("swells");
                        
                        var h1Final = null;
                        var p1Final = null;
                        var d1Final = null;
                        var h2Final = null;
                        var p2Final = null;
                        var d2Final = null;
                        var h3Final = null;
                        var p3Final = null;
                        var d3Final = null;
                        
                        if (swells != null && swells instanceof Array) {
                            swells = sortSwells(swells);
                            for (var j = 0; j < swells.size() && j < 3; j++) {
                                var s = swells[j] as Dictionary;
                                var hVal = s.get("height");
                                var pVal = s.get("period");
                                var dVal = s.get("direction");
                                
                                var h = 0.0;
                                if (hVal instanceof Number) { h = hVal.toFloat(); } else if (hVal instanceof Float) { h = hVal; } else if (hVal instanceof Double) { h = hVal.toFloat(); }
                                var p = 0;
                                if (pVal instanceof Number) { p = pVal; } else if (pVal instanceof Float) { p = pVal.toNumber(); } else if (pVal instanceof Double) { p = pVal.toNumber(); }
                                var d = 0;
                                if (dVal instanceof Number) { d = dVal; } else if (dVal instanceof Float) { d = dVal.toNumber(); } else if (dVal instanceof Double) { d = dVal.toNumber(); }
                                
                                if (j == 0) { h1Final = h; p1Final = p; d1Final = d; }
                                else if (j == 1) { h2Final = h; p2Final = p; d2Final = d; }
                                else if (j == 2) { h3Final = h; p3Final = p; d3Final = d; }
                            }
                        }
                        
                        itemsToKeep[idx] = {
                            "t" => ts,
                            "1h" => h1Final, "1p" => p1Final, "1d" => d1Final,
                            "2h" => h2Final, "2p" => p2Final, "2d" => d2Final,
                            "3h" => h3Final, "3p" => p3Final, "3d" => d3Final
                        };
                        idx++;
                    }
                    
                    System.println("Prepared " + keepCount + " items for waves");
                    
                    var result = {
                        "t" => mPendingTides,
                        "n" => mPendingSpotName,
                        "w" => itemsToKeep
                    };
                    Background.exit(result);
                    return;
                }
            }
        }
        
        // If waves failed, fallback to returning just tides
        if (mPendingTides != null) {
            var result = {
                "t" => mPendingTides,
                "n" => mPendingSpotName,
                "we" => responseCode
            };
            Background.exit(result);
            return;
        }
        
        Background.exit({"we" => responseCode});
    }

    function sortSwells(swells as Array) as Array {
        var size = swells.size();
        if (size <= 1) { return swells; }
        
        // Simple bubble sort by "power" descending
        // Power is the best indicator of swell energy/importance on Surfline
        for (var i = 0; i < size; i++) {
            for (var j = 0; j < size - i - 1; j++) {
                var s1 = swells[j] as Dictionary;
                var s2 = swells[j+1] as Dictionary;
                var p1 = s1.get("power");
                var p2 = s2.get("power");
                
                var v1 = 0.0;
                if (p1 instanceof Number) { v1 = p1.toFloat(); } else if (p1 instanceof Float) { v1 = p1; } else if (p1 instanceof Double) { v1 = p1.toFloat(); }
                var v2 = 0.0;
                if (p2 instanceof Number) { v2 = p2.toFloat(); } else if (p2 instanceof Float) { v2 = p2; } else if (p2 instanceof Double) { v2 = p2.toFloat(); }
                
                if (v2 > v1) {
                    var temp = swells[j];
                    swells[j] = swells[j+1];
                    swells[j+1] = temp;
                }
            }
        }
        return swells;
    }
}
