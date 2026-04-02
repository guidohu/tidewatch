import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

(:background)
class TideWatchBackground extends System.ServiceDelegate {
    /**
     * mResult is the central data vessel passed to Background.exit() to share results with the main app.
     * 
     * Expected structure:
     * - DataKeys.TIDE_DATA (0): Array<Number> (Tide heights in centimeters)
     * - DataKeys.SPOT_NAME (1): String (The display name of the surf spot)
     * - DataKeys.WAVE_DATA (2): Array<Array<Number?>> (48 hourly snapshots, each index containing 9 elements:
     *                           [H1 (cm), P1 (s), D1 (deg), H2, P2, D2, H3, P3, D3] representing 3 swells)
     * - DataKeys.WAVE_ERROR (3): Number (HTTP status code if wave data request failed)
     * - DataKeys.TIDE_ERROR (4): Number (HTTP status code if tide data request failed)
     * - DataKeys.TIDE_UNIT (16): Number (Unit code for tide heights: METER or FEET)
     * - DataKeys.SWELL_UNIT (17): Number (Unit code for swell heights: METER or FEET)
     * - DataKeys.TIDE_START_TIME (12): Number (Unix timestamp for the start of the hourly grid)
     * - DataKeys.TIDE_INTERVAL (13): Number (Time interval between tide points in seconds)
     * - DataKeys.TIDE_EXTREMA (14): Array<Array> (Each inner array: [timestamp, height_cm, type_code])
     * - DataKeys.TIDE_TIMES (15): Array<Number> (Precise timestamps matching TIDE_DATA entries)
     */
    var mResult as Dictionary? = null;
    var mSpotId = null;
    var mTargetLat = null;
    var mTargetLon = null;

    function initialize() {
        ServiceDelegate.initialize();
        mResult = {};
        System.println("Tide Watch started successfully");
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    function onTemporalEvent() as Void {
        mResult = {};
        
        var mode = Application.Properties.getValue("LocationMode");
        if (mode != null && mode == DataKeys.LOCATION_MODE_GPS) {
            var gpsStr = Application.Properties.getValue("GpsCoordinates");
            if (gpsStr != null && gpsStr instanceof String) {
                var commaIdx = gpsStr.find(",");
                if (commaIdx != null) {
                    var latStr = gpsStr.substring(0, commaIdx);
                    var lonStr = gpsStr.substring(commaIdx + 1, gpsStr.length());
                    mTargetLat = latStr.toFloat();
                    mTargetLon = lonStr.toFloat();
                    
                    if (mTargetLat != null && mTargetLon != null) {
                        logMemoryUsage();
                        makeMapviewRequest();
                        System.println("onTemporalEvent() done (mapview path).");
                        return;
                    }
                }
            }
        }
        
        mSpotId = Application.Properties.getValue("SpotId");
        if (mSpotId == null || mSpotId.equals("")) {
            mSpotId = "6269dc2c491aa9ad66235f52"; // Canggu default
        }

        // Step 1: Start the sequential data fetch (Tides -> Waves)
        // Note: Requests are chained sequentially to stay within strict background memory limits.
        logMemoryUsage();
        makeTideRequest();
        System.println("onTemporalEvent() done.");
    }

    function makeMapviewRequest() as Void {
        var distance = 0.005; // +/- 0.005 degrees bounding box (~1km)
        var south = mTargetLat - distance;
        var north = mTargetLat + distance;
        var west = mTargetLon - distance;
        var east = mTargetLon + distance;
        
        var url = "https://services.surfline.com/kbyg/mapview?south=" + south + "&north=" + north + "&west=" + west + "&east=" + east;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        System.println("Background: Requesting Mapview spots from: " + url);
        Communications.makeWebRequest(url, null, options, method(:onReceiveMapviewResponse));
    }

    function onReceiveMapviewResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Background: Mapview response code: " + responseCode);
        logMemoryUsage();
        
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            var dataObj = data.get("data");
            if (dataObj != null && dataObj instanceof Dictionary) {
                var spots = dataObj.get("spots");
                if (spots != null && spots instanceof Array && spots.size() > 0) {
                    var closestSpotId = null;
                    var minDistanceSq = 999999.0;
                    
                    for (var i = 0; i < spots.size(); i++) {
                        var spot = spots[i] as Dictionary;
                        var sLat = spot.get("lat");
                        var sLon = spot.get("lon");
                        if (sLat != null && sLon != null) {
                            var sLatF = 0.0;
                            if (sLat instanceof Float) { sLatF = sLat; }
                            else if (sLat instanceof Double) { sLatF = sLat.toFloat(); }
                            else if (sLat instanceof Number) { sLatF = sLat.toFloat(); }
                            
                            var sLonF = 0.0;
                            if (sLon instanceof Float) { sLonF = sLon; }
                            else if (sLon instanceof Double) { sLonF = sLon.toFloat(); }
                            else if (sLon instanceof Number) { sLonF = sLon.toFloat(); }
                            
                            var dLat = sLatF - mTargetLat;
                            var dLon = sLonF - mTargetLon;
                            var distSq = dLat * dLat + dLon * dLon;
                            
                            if (distSq < minDistanceSq) {
                                minDistanceSq = distSq;
                                closestSpotId = spot.get("_id");
                            }
                        }
                    }
                    
                    if (closestSpotId != null && closestSpotId instanceof String) {
                        mSpotId = closestSpotId;
                        System.println("Found closest spot: " + mSpotId);
                        data = null; // Free memory
                        makeTideRequest();
                        return;
                    }
                }
            }
        }
        
        // Fallback to configured Spot ID if Mapview fails or finds no spots
        mSpotId = Application.Properties.getValue("SpotId");
        if (mSpotId == null || mSpotId.equals("")) {
            mSpotId = "6269dc2c491aa9ad66235f52"; // Canggu default
        }
        data = null;
        makeTideRequest();
    }

    function makeTideRequest() as Void {
        var url = "https://services.surfline.com/kbyg/spots/forecasts/tides?units=m&spotId=" + mSpotId + "&days=2&intervalHours=" + Constants.SurflineTideInterval;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        System.println("Background: Requesting Tides from: " + url);
        // onReceiveTideResponse will call makeWaveRequest. This way the request is sequential.
        // This is done for memory reasons.
        Communications.makeWebRequest(url, null, options, method(:onReceiveTideResponse));
    }

    function makeWaveRequest() as Void {
        var url = "https://services.surfline.com/kbyg/spots/forecasts/wave?spotId=" + mSpotId + "&days=2&intervalHours=" + Constants.SurflineWaveInterval;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        System.println("Background: Requesting Waves from: " + url);
        Communications.makeWebRequest(url, null, options, method(:onReceiveWaveResponse));
    }

    function onReceiveTideResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Background: Tides response code: " + responseCode);
        System.println("Background: Response data:" + data);
        logMemoryUsage();
        
        // Extract the data structure under:
        // "associated" : { "spot" : { "name" : "Canggu" } }
        // "data" : {
        //    "tides" : [
        //       { "timestamp" : 1234567890, "type" : "HIGH", "value" : 1.23 },
        //       { "timestamp" : 1234567890, "type" : "LOW", "value" : 1.23 },
        //       ...
        //    }
        // }
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            // Parse Tides and Spot information and store results in mResult.
            parseTideFromTideData(data);
            parseTideUnitFromTideData(data);
            parseSpotNameFromTideData(data);
                
            // Step 2: Clear memory and fetch Wave Data
            logMemoryUsage();
            data = null;
            makeWaveRequest();
            return;
        }
        Background.exit({DataKeys.TIDE_ERROR => responseCode});
    }
    
    function onReceiveWaveResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Background: Waves response code: " + responseCode);
        logMemoryUsage();
        
        if (responseCode == 200 && data != null) {
            parseSwellUnitFromWaveData(data);
            var waveResults = parseWaveFromWaveData(data);
            if (waveResults != null) {
                mResult.put(DataKeys.WAVE_DATA, waveResults);
            }
        } else {
            mResult.put(DataKeys.WAVE_ERROR, responseCode);
        }

        Background.exit(mResult);
        return;
    }

    /**
     * Extracts the spot name from the Surfline API response.
     * 
     * The response data structure looks like this:
     * {
     *   "associated": {
     *     "tideLocation": {
     *       "name": "Canggu, West Bali",
     *       ...
     *     },
     *     ...
     *   },
     *   "data": { "tides": [...] }
     * }
     * 
     * We parse the "name" field (e.g., "Canggu, West Bali") and return the
     * part before the comma (e.g., "Canggu").
     */
    function parseSpotNameFromTideData(data as Dictionary) {
        var spotName = "Unknown";
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
        mResult.put(DataKeys.SPOT_NAME, spotName);
        return;
    }

    /**
     * Parses the tide data from the Surfline API response.
     * 
     * The response data structure looks like this:
     * "data" : {
     *    "tides" : [
     *       { "timestamp" : 1234567890, "type" : "HIGH", "value" : 1.23 },
     *       { "timestamp" : 1234567890, "type" : "LOW", "value" : 1.23 },
     *       ...
     *    }
     * }
     */
    function parseTideFromTideData(data as Dictionary) {
        var dataObj = data.get("data");
        if (dataObj != null && dataObj instanceof Dictionary) {
            var tides = dataObj.get("tides");
            if (tides != null && tides instanceof Array && tides.size() > 0) {
                // 1. Extract Extrema (HIGH/LOW) with precise timing
                var extrema = [];
                for (var i = 0; i < tides.size(); i++) {
                    var tide = tides[i] as Dictionary;
                    var typeStr = tide.get("type");
                    if (typeStr != null && (typeStr.equals("HIGH") || typeStr.equals("LOW"))) {
                        var typeCode = typeStr.equals("HIGH") ? DataKeys.TIDE_TYPE_HIGH : DataKeys.TIDE_TYPE_LOW;
                        var height = (tide.get("height") as Float * 100.0).toNumber();
                        extrema.add([tide.get("timestamp"), height, typeCode]);
                    }
                }
                mResult.put(DataKeys.TIDE_EXTREMA, extrema);
                
                // 2. Collect Grid Points and their Timestamps.
                var gridHeights = new Array<Number>[tides.size()];
                var gridTimes = new Array<Number>[tides.size()];
                var startTime = (tides[0] as Dictionary).get("timestamp") as Number;
                for (var i = 0; i < tides.size(); i++) {
                    var tidePoint = (tides[i] as Dictionary);
                    var ts = tidePoint.get("timestamp") as Number;
                    var height = (tidePoint.get("height") as Float * 100.0).toNumber();
                    gridHeights[i] = height;
                    gridTimes[i] = ts;
                }
                mResult.put(DataKeys.TIDE_TIMES, gridTimes);
                mResult.put(DataKeys.TIDE_DATA, gridHeights);
                mResult.put(DataKeys.TIDE_START_TIME, startTime);
                mResult.put(DataKeys.TIDE_INTERVAL, Constants.SurflineTideInterval * 3600);
                System.println("Prepared grid tide data: " + gridHeights.size() + " hourly heights (+ extrema), " + extrema.size() + " extrema");
            }
        }
        return null;
    }

    /**
     * Parses the tide unit from the Surfline API response.
     * 
     * Data structure:
     * "associated" : {
     *   "units" : {
     *     "tideHeight": "M",
     *     "swellHeight": "M"
     *   }
     * }
     */
    function parseTideUnitFromTideData(data as Dictionary) as Void {
        var associated = data.get("associated");
        if (associated != null && associated instanceof Dictionary) {
            var units = associated.get("units");
            if (units != null && units instanceof Dictionary) {
                var tideUnitStr = units.get("tideHeight");
                if (tideUnitStr != null && tideUnitStr.equals("M")) {
                    mResult.put(DataKeys.TIDE_UNIT, DataKeys.UNIT_METER);
                } else {
                    mResult.put(DataKeys.TIDE_UNIT, DataKeys.UNIT_FEET);
                }
            }
        }
    }

    /**
     * Parses the swell unit from the Surfline API response.
     * 
     * Data structure:
     * "associated" : {
     *   "units" : {
     *     "swellHeight": "M"
     *   }
     * }
     */
    function parseSwellUnitFromWaveData(data as Dictionary) as Void {
        var associated = data.get("associated");
        if (associated != null && associated instanceof Dictionary) {
            var units = associated.get("units");
            if (units != null && units instanceof Dictionary) {
                var swellUnitStr = units.get("swellHeight");
                if (swellUnitStr != null && swellUnitStr.equals("M")) {
                    mResult.put(DataKeys.SWELL_UNIT, DataKeys.UNIT_METER);
                } else {
                    mResult.put(DataKeys.SWELL_UNIT, DataKeys.UNIT_FEET);
                }
            }
        }
    }

    /**
     * Parses wave and swell data from the Surfline API response.
     * 
     * The response structure looks like this:
     * {
     *   "associated" : { },
     *   "data": {
     *     "wave": [
     *       {
     *         "timestamp": 1774713600,
     *         "swells": [
     *           { "height": 1.83, "period": 12, "direction": 195.7, "power": 694.2, "impact": 0.7146 },
     *           ...
     *         ]
     *       },
     *       ...
     *     ]
     *   },
     *   "permissions" : { }
     * }
     * 
     * We extract up to 24 future-looking points and pick the top 3 swells 
     * (sorted by power) for each timestamp.
     */
    function parseWaveFromWaveData(data as Dictionary) as Array<Array<Number?>>? {
        var dataObj = data.get("data");
        if (dataObj == null || !(dataObj instanceof Dictionary)) {
            return null;
        }

        // Remove stuff we do not need right from the beginning
        data.remove("associated");
        data.remove("permissions");
        
        var waveArray = dataObj.get("wave");
        if (waveArray == null || !(waveArray instanceof Array) || waveArray.size() == 0) {
            return null;
        }

        // 1. Pre-process raw data: extract top 3 swells by impact and only keep those
        // going forward.
        for (var i = 0; i < waveArray.size(); i++) {
            var wavePoint = waveArray[i] as Dictionary;
            // Remove keys we do not need right from the beginning
            wavePoint.remove("probability");
            wavePoint.remove("utcOffset");
            wavePoint.remove("surf");
            wavePoint.remove("power");
            extractTop3Swells(wavePoint);
        }

        // 2. Get target timestamps from TIDE_TIMES
        var targetTimes = mResult.get(DataKeys.TIDE_TIMES) as Array<Number>?;
        if (targetTimes == null || targetTimes.size() == 0) {
            return null;
        }

        // 3. Generate interpolated points matching TIDE_TIMES
        var totalPoints = targetTimes.size();
        var itemsToKeep = new Array<Array<Number?>>[totalPoints];
        
        for (var h = 0; h < totalPoints; h++) {
            var targetTs = targetTimes[h];
            
            // Find flanking points in waveArray
            var idx1 = -1;
            var idx2 = -1;
            for (var i = 0; i < waveArray.size() - 1; i++) {
                var ts1 = (waveArray[i] as Dictionary).get("timestamp") as Number;
                var ts2 = (waveArray[i+1] as Dictionary).get("timestamp") as Number;
                if (targetTs >= ts1 && targetTs <= ts2) {
                    idx1 = i;
                    idx2 = i + 1;
                    break;
                }
            }
            
            var resultPoint = new Array<Number?>[9];
            
            if (idx1 != -1 && idx2 != -1) {
                var w1 = waveArray[idx1] as Dictionary;
                var w2 = waveArray[idx2] as Dictionary;
                var ts1 = w1.get("timestamp") as Number;
                var ts2 = w2.get("timestamp") as Number;
                var ratio = (targetTs - ts1).toFloat() / (ts2 - ts1).toFloat();
                
                interpolateSwells(resultPoint, w1.get("swells") as Array?, w2.get("swells") as Array?, ratio);
            } else if (targetTs < (waveArray[0] as Dictionary).get("timestamp") as Number) {
                // Clamping to first
                extractSwells(resultPoint, (waveArray[0] as Dictionary).get("swells") as Array?);
            } else {
                // Clamping to last
                extractSwells(resultPoint, (waveArray[waveArray.size()-1] as Dictionary).get("swells") as Array?);
            }
            
            itemsToKeep[h] = resultPoint;
        }

        System.println("Prepared " + totalPoints + " interpolated items for waves");
        logMemoryUsage();
        return itemsToKeep;
    }

    function interpolateSwells(target as Array, s1Array as Array?, s2Array as Array?, ratio as Float) as Void {
        for (var i = 1; i <= 3; i++) {
            var s1 = (s1Array != null && s1Array.size() >= i) ? s1Array[i-1] as Dictionary : null;
            var s2 = (s2Array != null && s2Array.size() >= i) ? s2Array[i-1] as Dictionary : null;
            
            if (s1 == null && s2 == null) { continue; }
            
            var hKey, pKey, dKey;
            if (i == 1) { 
                hKey = DataKeys.SWELL_1_HEIGHT; pKey = DataKeys.SWELL_1_PERIOD; dKey = DataKeys.SWELL_1_DIRECTION; 
            } else if (i == 2) { 
                hKey = DataKeys.SWELL_2_HEIGHT; pKey = DataKeys.SWELL_2_PERIOD; dKey = DataKeys.SWELL_2_DIRECTION; 
            } else { 
                hKey = DataKeys.SWELL_3_HEIGHT; pKey = DataKeys.SWELL_3_PERIOD; dKey = DataKeys.SWELL_3_DIRECTION; 
            }

            var hF = interpolateValue(s1, s2, "height", ratio, true) as Float;
            target[hKey] = (hF * 100.0).toNumber();
            target[pKey] = interpolateValue(s1, s2, "period", ratio, false) as Number;
            target[dKey] = interpolateDirection(s1, s2, ratio).toNumber();
        }
    }

    function extractSwells(target as Array, sArray as Array?) as Void {
        for (var i = 1; i <= 3; i++) {
            var s = (sArray != null && sArray.size() >= i) ? sArray[i-1] as Dictionary : null;
            if (s == null) { continue; }
            
            var hKey, pKey, dKey;
            if (i == 1) { 
                hKey = DataKeys.SWELL_1_HEIGHT; pKey = DataKeys.SWELL_1_PERIOD; dKey = DataKeys.SWELL_1_DIRECTION; 
            } else if (i == 2) { 
                hKey = DataKeys.SWELL_2_HEIGHT; pKey = DataKeys.SWELL_2_PERIOD; dKey = DataKeys.SWELL_2_DIRECTION; 
            } else { 
                hKey = DataKeys.SWELL_3_HEIGHT; pKey = DataKeys.SWELL_3_PERIOD; dKey = DataKeys.SWELL_3_DIRECTION; 
            }

            var hVal = s.get("height");
            if (hVal != null) {
                var hF = (hVal instanceof Number) ? hVal.toFloat() : hVal as Float;
                target[hKey] = (hF * 100.0).toNumber();
            }
            var pVal = s.get("period");
            if (pVal != null) {
                target[pKey] = (pVal instanceof Float) ? pVal.toNumber() : (pVal instanceof Double ? (pVal as Double).toNumber() : pVal as Number);
            }
            var dVal = s.get("direction");
            if (dVal != null) {
                target[dKey] = (dVal instanceof Float) ? dVal.toNumber() : (dVal instanceof Double ? (dVal as Double).toNumber() : dVal as Number);
            }
        }
    }

    function interpolateValue(s1 as Dictionary?, s2 as Dictionary?, key as String, ratio as Float, isFloat as Boolean) as Numeric {
        var v1 = 0.0;
        var v2 = 0.0;
        if (s1 != null) { 
            var val = s1.get(key);
            v1 = (val instanceof Number) ? val.toFloat() : val as Float;
        }
        if (s2 != null) { 
            var val = s2.get(key);
            v2 = (val instanceof Number) ? val.toFloat() : val as Float;
        }
        
        if (s1 == null) { v1 = v2; }
        if (s2 == null) { v2 = v1; }
        
        var res = v1 + (v2 - v1) * ratio;
        return isFloat ? res : res.toNumber();
    }

    function interpolateDirection(s1 as Dictionary?, s2 as Dictionary?, ratio as Float) as Float {
        var d1 = 0.0;
        var d2 = 0.0;
        if (s1 != null) { 
            var val = s1.get("direction");
            d1 = (val instanceof Number) ? val.toFloat() : val as Float;
        }
        if (s2 != null) { 
            var val = s2.get("direction");
            d2 = (val instanceof Number) ? val.toFloat() : val as Float;
        }
        
        if (s1 == null) { d1 = d2; }
        if (s2 == null) { d2 = d1; }

        var diff = d2 - d1;
        while (diff > 180) { diff -= 360; }
        while (diff < -180) { diff += 360; }
        
        var res = d1 + diff * ratio;
        while (res < 0) { res += 360; }
        while (res >= 360) { res -= 360; }
        return res;
    }

    /**
     * Evaluates all swells and takes only the 3 with the highest impact.
     * Stores the result back into the waveItem dictionary.
     */
    function extractTop3Swells(waveItem as Dictionary) as Void {
        var swells = waveItem.get("swells") as Array?;
        if (swells == null || swells.size() <= 3) {
            if (swells == null) { waveItem.put("swells", []); }
            return;
        }

        var top3 = new Array<Dictionary>[3];
        var topImpacts = [-1.0, -1.0, -1.0] as Array<Float>;

        for (var i = 0; i < swells.size(); i++) {
            var s = swells[i] as Dictionary;
            var impact = s.get("impact");
            var v = 0.0;
            if (impact instanceof Number) { v = impact.toFloat(); } 
            else if (impact instanceof Float) { v = impact; } 
            else if (impact instanceof Double) { v = impact.toFloat(); }

            if (v > topImpacts[0]) {
                topImpacts[2] = topImpacts[1]; top3[2] = top3[1];
                topImpacts[1] = topImpacts[0]; top3[1] = top3[0];
                topImpacts[0] = v; top3[0] = s;
            } else if (v > topImpacts[1]) {
                topImpacts[2] = topImpacts[1]; top3[2] = top3[1];
                topImpacts[1] = v; top3[1] = s;
            } else if (v > topImpacts[2]) {
                topImpacts[2] = v; top3[2] = s;
            }
        }
        waveItem.put("swells", top3);
    }
}
