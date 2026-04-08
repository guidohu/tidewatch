import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;

(:background)
class TideWatchBackground extends System.ServiceDelegate {
    /**
     * - DataKeys.TIDE_TIMES (15): Array<Number> (Precise timestamps matching TIDE_DATA entries)
     */
    var mSpotId = null;
    var mTargetLat = null;
    var mTargetLon = null;
    var mSpotLat = null;
    var mSpotLon = null;
    var mMapviewDistance = 0.0075;

    function initialize() {
        ServiceDelegate.initialize();
        System.println("Tide Watch started successfully");
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    function onTemporalEvent() as Void {
        mMapviewDistance = 0.0075;
        
        var gpsStr = Application.Properties.getValue("GpsCoordinates"); 
        System.println("Application.Properties.GpsCoordinates: " + gpsStr);
        if (gpsStr != null && gpsStr instanceof String && gpsStr.length() > 0) {
            System.println("Custom coordinates defined: " + gpsStr);
            var commaIdx = gpsStr.find(",");
            if (commaIdx != null) {
                var latStr = gpsStr.substring(0, commaIdx);
                var lonStr = gpsStr.substring(commaIdx+1, gpsStr.length());
                mTargetLat = latStr.toFloat();
                mTargetLon = lonStr.toFloat();
                System.println("Parsed Lat/Lon " + latStr + "/" + lonStr + " into: " + mTargetLat + "/" + mTargetLon);
            }
        } else {
            // Without Custom Coordinates we use the watch GPS. To find the closest
            // spots.
            var posInfo = Position.getInfo();
            if (posInfo != null && posInfo.position != null) {
                var latLon = posInfo.position.toDegrees();
                mTargetLat = latLon[0];
                mTargetLon = latLon[1];
            }
            System.println("Get position from watch Lat/Lon: " + mTargetLat + "/" + mTargetLon);
        }
        
        if (mTargetLat != null && mTargetLon != null) {
            logMemoryUsage();
            makeMapviewRequest();
            System.println("onTemporalEvent() done (mapview path).");
            return;
        }
        
        mSpotId = Application.Properties.getValue("SpotId");
        if (mSpotId == null || mSpotId.equals("")) {
            mSpotId = "6269dc2c491aa9ad66235f52"; // Canggu default
        }

        logMemoryUsage();
        makeTideRequest();
        System.println("onTemporalEvent() done.");
    }

    function makeMapviewRequest() as Void {
        var south = mTargetLat - mMapviewDistance;
        var north = mTargetLat + mMapviewDistance;
        var west = mTargetLon - mMapviewDistance;
        var east = mTargetLon + mMapviewDistance;
        
        var url = "https://services.surfline.com/kbyg/mapview?south=" + south + "&north=" + north + "&west=" + west + "&east=" + east;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        System.println("Requesting Mapview spots from: " + url);
        Communications.makeWebRequest(url, null, options, method(:onReceiveMapviewResponse));
    }

    function makeMapviewResolutionRequest(lat, lon) as Void {
        var dist = 0.0005; // Tight radius for specific resolution
        var south = lat - dist;
        var north = lat + dist;
        var west = lon - dist;
        var east = lon + dist;
        
        var url = "https://services.surfline.com/kbyg/mapview?south=" + south + "&north=" + north + "&west=" + west + "&east=" + east;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        System.println("Resolving name for " + mSpotId + " at " + lat + "/" + lon);
        Communications.makeWebRequest(url, null, options, method(:onReceiveMapviewResolutionResponse));
    }

    function makeTideRequest() as Void {
        var url = "https://services.surfline.com/kbyg/spots/forecasts/tides?units=m&spotId=" + mSpotId + "&days=2&intervalHours=" + Constants.SurflineTideInterval;
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
        };
        System.println("Requesting Tides from: " + url);
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
        System.println("Requesting Waves from: " + url);
        Communications.makeWebRequest(url, null, options, method(:onReceiveWaveResponse));
    }

    function onReceiveMapviewResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Mapview response code: " + responseCode);
        logMemoryUsage();
        
        if (responseCode == -403 || responseCode == -402) {
            System.println("Background: Mapview payload too large. Retrying with smaller radius (current=" + mMapviewDistance + ").");
            if (mMapviewDistance > 0.0045) {
                mMapviewDistance -= 0.0025;
                makeMapviewRequest();
                return;
            }
        }
        
        // Extract the data structure under:
        // "data" : {
        //    "spots" : [
        //       { "_id" : "6269dc2c441aa9ad66235f52", "name" : "Canggu", "lat" : -8.65, "lon" : 115.13 },
        //       ...
        //    ]
        // }
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            var dataObj = data.get("data");
            if (dataObj != null && dataObj instanceof Dictionary) {
                var spots = dataObj.get("spots");
                if (spots != null && spots instanceof Array && spots.size() > 0) {
                    var top10 = [] as Array<Array>; // Stores [spotName, spotId, distSq]
                    
                    for (var i = 0; i < spots.size(); i++) {
                        var spot = spots[i] as Dictionary;
                        var sLat = spot.get("lat");
                        var sLon = spot.get("lon");
                        var spotId = spot.get("_id");
                        var spotName = spot.get("name");
                        // Early cleanup
                        spot.remove("lat");
                        spot.remove("lon");
                        spot.remove("_id");
                        spot.remove("name");
                        
                        if (sLat != null && sLon != null && spotId != null && spotName != null) {
                            var sLatF = (sLat as Numeric).toFloat();
                            var sLonF = (sLon as Numeric).toFloat();
                            
                            var dLat = sLatF - mTargetLat;
                            var dLon = sLonF - mTargetLon;
                            var distSq = dLat * dLat + dLon * dLon;
                            
                            // Insert into sorted top10 (insertion sort variant)
                            var inserted = false;
                            for (var j = 0; j < top10.size(); j++) {
                                if (distSq < (top10[j] as Array)[2]) {
                                    top10.add([] as Array); // Grow the array
                                    for (var k = top10.size() - 1; k > j; k--) {
                                        top10[k] = top10[k - 1];
                                    }
                                    top10[j] = [spotName as String, spotId as String, distSq] as Array;
                                    inserted = true;
                                    break;
                                }
                            }
                            if (!inserted && top10.size() < 10) {
                                top10.add([spotName as String, spotId as String, distSq]);
                            }
                            if (top10.size() > 10) {
                                top10 = top10.slice(0, 10);
                            }
                        }
                    }
                    if (top10.size() > 10) { top10 = top10.slice(0, 10); }

                    Application.Storage.setValue("NearbySpots", top10);
                    System.println("NearbySpots stored");
                    
                    mSpotId = Application.Properties.getValue("SpotId");
                    if (mSpotId == null || mSpotId.equals("")) {
                        if (top10.size() > 0) {
                            var firstEntry = top10[0] as Array;
                            mSpotId = firstEntry[1] as String;
                            System.println("Set SpotID to closest spot " + firstEntry[0] as String + " / " + mSpotId);
                        } else {
                            mSpotId = "6269dc2c491aa9ad66235f52"; // Pererenan, Bali
                            System.println("Set SpotID to Pererenan " + mSpotId + " [DEFAULT]");
                        }
                    }
                    
                    // Search for the name of the active mSpotId in our discovered top10 spots.
                    for (var i = 0; i < top10.size(); i++) {
                        var entry = top10[i] as Array;
                        if (entry[1].equals(mSpotId)) {
                            var name = entry[0] as String;
                            System.println("Found spot name in top10: " + name);
                            Application.Storage.setValue("spotName", name);
                            break;
                        }
                    }
                    
                    data = null; // Free memory
                    top10 = null;
                    makeTideRequest();
                    return;
                } else if (mMapviewDistance < 0.02) {
                    mMapviewDistance += 0.0025;
                    System.println("Mapview: No spots found. Retrying with larger radius (current=" + mMapviewDistance + ").");
                    data = null;
                    makeMapviewRequest();
                    return;
                }
            }
        }
        
        mSpotId = Application.Properties.getValue("SpotId");
        if (mSpotId == null || mSpotId.equals("")) {
            mSpotId = "6269dc2c491aa9ad66235f52"; // Canggu default
        }
        data = null;
        makeTideRequest();
    }

    function onReceiveTideResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Tides response code: " + responseCode);
        logMemoryUsage();
        
        // Extract the data structure under:
        // "associated" : { "units" : { "tideHeight" : "M" } }
        // "data" : {
        //    "tides" : [
        //       { "timestamp" : 1234567890, "type" : "HIGH", "height" : 1.23 },
        //       { "timestamp" : 1234567890, "type" : "LOW", "height" : 1.23 },
        //       ...
        //    ]
        // }
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            // Parse Tides and store results.
            parseTideFromTideData(data);
            parseTideUnitFromTideData(data);
                
            // Step 2: Clear memory and fetch Wave Data
            logMemoryUsage();
            data = null;
            makeWaveRequest();
            return;
        }
        Application.Storage.setValue("tideError", responseCode);
        Background.exit(false);
    }
    
    function onReceiveWaveResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Waves response code: " + responseCode);
        logMemoryUsage();
        
        if (responseCode == 200 && data != null) {
            parseSwellUnitFromWaveData(data);
            var waveResults = parseWaveFromWaveData(data);
            if (waveResults != null) {
                Application.Storage.setValue("waveData", waveResults);
                waveResults = null; // Reclaim memory
            }
        } else {
            Application.Storage.setValue("waveError", responseCode);
        }

        // If we don't have a name yet, try to resolve it using coordinates from Wave API
        var existingName = Application.Storage.getValue("spotName");
        if (existingName == null && mSpotLat != null && mSpotLon != null) {
            data = null;
            makeMapviewResolutionRequest(mSpotLat, mSpotLon);
            return;
        }

        Background.exit(true);
        return;
    }

    function onReceiveMapviewResolutionResponse(responseCode as Number, data as Dictionary?) as Void {
        System.println("Mapview resolution response: " + responseCode);
        logMemoryUsage();
        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            var dataObj = data.get("data");
            if (dataObj != null && dataObj instanceof Dictionary) {
                var spots = dataObj.get("spots");
                if (spots != null && spots instanceof Array) {
                    for (var i = 0; i < spots.size(); i++) {
                        var spot = spots[i] as Dictionary;
                        if (spot.get("_id").equals(mSpotId)) {
                            var name = spot.get("name") as String;
                            System.println("Successfully resolved spot name: " + name);
                            Application.Storage.setValue("spotName", name);
                            break;
                        }
                        spots[i] = null;
                    }
                }
            }
        }
        Background.exit(true);
    }

    /**
     * Parses the tide data from the Surfline API response.
     * 
     * The response data structure looks like this:
     * "data" : {
     *    "tides" : [
     *       { "timestamp" : 1234567890, "type" : "HIGH", "height" : 1.23 },
     *       { "timestamp" : 1234567890, "type" : "LOW", "height" : 1.23 },
     *       ...
     *    ]
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
                Application.Storage.setValue("tideExtrema", extrema);
                extrema = null;
                
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
                Application.Storage.setValue("tideTimes", gridTimes);
                Application.Storage.setValue("tideData", gridHeights);
                Application.Storage.setValue("tideStartTime", startTime);
                Application.Storage.setValue("tideInterval", Constants.SurflineTideInterval * 3600);
                
                gridHeights = null;
                gridTimes = null;
                
                System.println("Saved grid tide data to storage");
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
                    Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_METER);
                } else {
                    Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_FEET);
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
                    Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_METER);
                } else {
                    Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_FEET);
                }
            }
        }
    }

    /**
     * Parses wave and swell data from the Surfline API response.
     * 
     * The response structure looks like this:
     * {
     *   "associated" : {
     *     "units": { "swellHeight": "M" },
     *     "location": { "lat": -8.65, "lon": 115.13 }
     *   },
     *   "data": {
     *     "wave": [
     *       {
     *         "timestamp": 1774713600,
     *         "swells": [
     *           { "height": 1.83, "period": 12, "direction": 195.7, "impact": 0.7146 },
     *           ...
     *         ]
     *       },
     *       ...
     *     ]
     *   }
     * }
     * 
     * We extract the data matching our tide timestamps and pick the top 3 swells 
     * (sorted by impact) for each timestamp.
     */
    function parseWaveFromWaveData(data as Dictionary) as Array<Array<Number?>>? {
        var dataObj = data.get("data");
        if (dataObj == null || !(dataObj instanceof Dictionary)) {
            return null;
        }

        var associated = data.get("associated");
        if (associated != null && associated instanceof Dictionary) {
            var location = associated.get("location");
            if (location != null && location instanceof Dictionary) {
                mSpotLat = location.get("lat");
                mSpotLon = location.get("lon");
                System.println("Extracted spot coordinates: " + mSpotLat + "/" + mSpotLon);
            }
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
        var targetTimes = Application.Storage.getValue("tideTimes") as Array<Number>?;
        if (targetTimes == null || targetTimes.size() == 0) {
            return null;
        }

        // 3. Generate interpolated points matching TIDE_TIMES (Single-pass tracker)
        var totalPoints = targetTimes.size();
        var itemsToKeep = new Array<Array<Number?>>[totalPoints];
        var currentIndex = 0;
        
        for (var h = 0; h < totalPoints; h++) {
            var targetTs = targetTimes[h];
            
            // Reclaim memory: Null out swells of points we've definitely passed
            if (currentIndex > 0) {
                var prevPoint = waveArray[currentIndex - 1] as Dictionary;
                if (prevPoint.hasKey("swells")) {
                    prevPoint.put("swells", null);
                }
            }

            // Find flanking points in waveArray using single-pass approach
            while (currentIndex < waveArray.size() - 1) {
                var ts2 = (waveArray[currentIndex + 1] as Dictionary).get("timestamp") as Number;
                if (ts2 >= targetTs) {
                    break;
                }
                // Memory Reclaim: As we advance, null out the swells we won't need again
                (waveArray[currentIndex] as Dictionary).put("swells", null);
                currentIndex++;
            }
            
            var resultPoint = new Array<Number?>[9];
            var w1 = waveArray[currentIndex] as Dictionary;
            var ts1 = w1.get("timestamp") as Number;

            if (currentIndex < waveArray.size() - 1) {
                var w2 = waveArray[currentIndex + 1] as Dictionary;
                var ts2 = w2.get("timestamp") as Number;
                
                if (targetTs >= ts1 && targetTs <= ts2) {
                    var ratio = (ts2 == ts1) ? 0.0 : (targetTs - ts1).toFloat() / (ts2 - ts1).toFloat();
                    interpolateSwells(resultPoint, w1.get("swells") as Array?, w2.get("swells") as Array?, ratio);
                } else if (targetTs < ts1) { // Clamping to first (shouldn't happen with correct while loop)
                    extractSwells(resultPoint, w1.get("swells") as Array?);
                } else { // targetTs > ts2 (shouldn't happen with correct while loop)
                    extractSwells(resultPoint, w2.get("swells") as Array?);
                }
            } else {
                // Clamping to last
                extractSwells(resultPoint, w1.get("swells") as Array?);
            }
            
            itemsToKeep[h] = resultPoint;
        }

        System.println("Prepared " + totalPoints + " interpolated items for waves");
        targetTimes = null; // Free reference
        waveArray = null;
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
            var impactVal = s.get("impact");
            var v = 0.0;
            if (impactVal instanceof Number) { v = (impactVal as Number).toFloat(); } 
            else if (impactVal instanceof Float) { v = impactVal as Float; } 
            else if (impactVal instanceof Double) { v = (impactVal as Double).toFloat(); }
            
            // Aggressive cleaning: Remove keys we won't need for interpolation
            s.remove("impact");
            s.remove("power");

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
        top3 = null;
        topImpacts = null;
    }
}
