import Toybox.Application;
import Toybox.Background;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;
import Toybox.Time;
import Toybox.Time.Gregorian;

(:background)
class TideWatchBackground extends System.ServiceDelegate {

    var mApiKey as String? = null;
    var mTargetLat as Float? = null;
    var mTargetLon as Float? = null;
    var mStart as Number? = null;
    var mEnd as Number? = null;
    var mTideEnd as Number? = null;
    var mDatumStr as String = "MLLW";

    // Variables perfectly matched to Stormglass's separated queries
    var mParsedTideData as Array<Number>? = null;
    var mParsedTideTimes as Array<Number>? = null;

    function initialize() {
        ServiceDelegate.initialize();
        System.println("Tide Watch started successfully");
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    function onTemporalEvent() as Void {
        mApiKey = Application.Properties.getValue("StormglassApiKey");
        if (mApiKey == null || mApiKey.equals("")) {
            System.println("No Stormglass API Key. Exit.");
            Background.exit(false);
            return;
        }

        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        if (gpsLat != null && gpsLat instanceof String && !gpsLat.equals("") && gpsLon != null && gpsLon instanceof String && !gpsLon.equals("")) {
            mTargetLat = gpsLat.toFloat();
            mTargetLon = gpsLon.toFloat();
        } else {
            System.println("No Custom Coordinates. Exit.");
            Background.exit(false);
            return;
        }

        var datumProp = Application.Properties.getValue("TideDatum");
        if (datumProp == 1) {
            mDatumStr = "MSL";
        } else {
            mDatumStr = "MLLW";
        }

        // Aligning exactly to the "Align Graphs" logic from 6 hours ago to 16 hours forward
        var now = Time.now();
        var startTs = now.subtract(new Time.Duration(4 * 3600));
        var endTs = now.add(new Time.Duration(20 * 3600));
        var tideEndTs = now.add(new Time.Duration(30 * 3600));

        mStart = startTs.value();
        mEnd = endTs.value();
        mTideEnd = tideEndTs.value();

        System.println("Starting sync sequence. Target: " + mTargetLat + "/" + mTargetLon);
        makeBigDataCloudRequest();
    }

    function handleQuotaError(responseCode as Number) as Boolean {
        if (responseCode == 402 || responseCode == 429) {
            System.println("Stormglass API Quota Exceeded (402/429)!");
            saveSyncError(DataKeys.ERROR_QUOTA_EXCEEDED);
            Background.exit(false);
            return true;
        }
        return false;
    }

    function makeBigDataCloudRequest() as Void {
        var url = "https://api.bigdatacloud.net/data/reverse-geocode-client";
        var params = {
            "latitude" => mTargetLat,
            "longitude" => mTargetLon,
            "localityLanguage" => "en"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, params, options, method(:onReceiveBigDataCloud));
    }

    function onReceiveBigDataCloud(responseCode as Number, data as Dictionary?) as Void {
        System.println("BigDataCloud response: " + responseCode);
        if (responseCode != 200) { System.println("BigDataCloud data: " + data); }
        var spotName = "Unknown";
        if (responseCode == 200 && data != null) {
            var locality = data.get("locality");
            var city = data.get("city");
            if (locality != null && locality instanceof String && !locality.equals("")) {
                spotName = locality;
            } else if (city != null && city instanceof String && !city.equals("")) {
                spotName = city;
            }
        }
        Application.Storage.setValue("spotName", spotName);
        System.println("Resolved spotName: " + spotName);
        // Always proceed to the next request
        data = null;
        makeStormglassWeatherRequest();
    }

    function makeStormglassWeatherRequest() as Void {
        var url = "https://api.stormglass.io/v2/weather/point";
        var params = {
            "lat" => mTargetLat,
            "lng" => mTargetLon,
            "start" => mStart,
            "end" => mEnd,
            "params" => "swellHeight,swellPeriod,swellDirection,secondarySwellHeight,secondarySwellPeriod,secondarySwellDirection",
            "source" => "noaa"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Authorization" => mApiKey }
        };
        System.println("Requesting Stormglass Weather with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveWeather));
    }

    function onReceiveWeather(responseCode as Number, data as Dictionary?) as Void {
        System.println("Weather response: " + responseCode);
        if (responseCode != 200) { System.println("Weather data: " + data); }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) { return; }

        if (responseCode == 200 && data != null && data.hasKey("hours")) {
            var hours = data.get("hours") as Array;
            var waveResults = new Array<Array<Number?>>[hours.size()];
            var waveTimes = new Array<Number>[hours.size()];
            
            for (var i = 0; i < hours.size(); i++) {
                var hr = hours[i] as Dictionary;
                waveTimes[i] = parseIso8601ToUnix(hr.get("time") as String);
                
                var wPoint = new Array<Number?>[9];
                
                // Primary Swell
                var h = extractSourceValue(hr.get("swellHeight"));
                var p = extractSourceValue(hr.get("swellPeriod"));
                var d = extractSourceValue(hr.get("swellDirection"));
                if (h != null) { wPoint[0] = (h * 100.0).toNumber(); }
                if (p != null) { wPoint[1] = p.toNumber(); }
                if (d != null) { wPoint[2] = d.toNumber(); }

                // Secondary Swell
                var h2 = extractSourceValue(hr.get("secondarySwellHeight"));
                var p2 = extractSourceValue(hr.get("secondarySwellPeriod"));
                var d2 = extractSourceValue(hr.get("secondarySwellDirection"));
                if (h2 != null) { wPoint[3] = (h2 * 100.0).toNumber(); }
                if (p2 != null) { wPoint[4] = p2.toNumber(); }
                if (d2 != null) { wPoint[5] = d2.toNumber(); }

                waveResults[i] = wPoint;
            }
            
            Application.Storage.setValue("waveData", waveResults);
            Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_METER); // Stormglass default metric
            waveResults = null;
            waveTimes = null;
            data = null;
            makeStormglassTideRequest();
            return;
        }
        
        saveSyncError(responseCode);
        Background.exit(false);
    }

    function makeStormglassTideRequest() as Void {
        var url = "https://api.stormglass.io/v2/tide/sea-level/point";
        var params = {
            "lat" => mTargetLat,
            "lng" => mTargetLon,
            "start" => mStart,
            "end" => mTideEnd,
            "datum" => mDatumStr
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Authorization" => mApiKey }
        };
        System.println("Requesting Stormglass Tide Sea-Level: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveTide));
    }

    function onReceiveTide(responseCode as Number, data as Dictionary?) as Void {
        System.println("Tide response: " + responseCode);
        if (responseCode != 200) { System.println("Tide data: " + data); }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) { return; }

        if (responseCode == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var gridHeights = new Array<Number>[pts.size()];
            var gridTimes = new Array<Number>[pts.size()];
            
            for (var i = 0; i < pts.size(); i++) {
                var point = pts[i] as Dictionary;
                gridTimes[i] = parseIso8601ToUnix(point.get("time") as String);
                var h = point.get("sg");
                if (h == null) { h = point.get("height"); }
                if (h != null) {
                    var hFloat = (h instanceof Number) ? (h as Number).toFloat() : h as Float;
                    gridHeights[i] = (hFloat * 100.0).toNumber();
                } else {
                    gridHeights[i] = 0;
                }
            }

            if (gridTimes.size() > 0) {
                Application.Storage.setValue("tideStartTime", gridTimes[0]);
                Application.Storage.setValue("tideTimes", gridTimes);
                Application.Storage.setValue("tideData", gridHeights);
                Application.Storage.setValue("tideInterval", 3600); // 1 hour interval matches Stormglass exactly
                Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_METER);
            }
            
            gridTimes = null;
            gridHeights = null;
            data = null;
            makeStormglassExtremesRequest();
            return;
        }
        
        saveSyncError(responseCode);
        Background.exit(false);
    }

    function makeStormglassExtremesRequest() as Void {
        var url = "https://api.stormglass.io/v2/tide/extremes/point";
        var params = {
            "lat" => mTargetLat,
            "lng" => mTargetLon,
            "start" => mStart,
            "end" => mTideEnd,
            "datum" => mDatumStr
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { "Authorization" => mApiKey }
        };
        System.println("Requesting Stormglass Tide Extremes");
        Communications.makeWebRequest(url, params, options, method(:onReceiveExtremes));
    }

    function onReceiveExtremes(responseCode as Number, data as Dictionary?) as Void {
        System.println("Extremes response: " + responseCode);
        if (responseCode != 200) { System.println("Extremes data: " + data); }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) { return; }

        if (responseCode == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var extrema = [];
            
            for (var i = 0; i < pts.size(); i++) {
                var point = pts[i] as Dictionary;
                var typeStr = point.get("type");
                if (typeStr != null && (typeStr.equals("high") || typeStr.equals("low"))) {
                    var typeCode = typeStr.equals("high") ? DataKeys.TIDE_TYPE_HIGH : DataKeys.TIDE_TYPE_LOW;
                    var ts = parseIso8601ToUnix(point.get("time") as String);
                    var hVal = point.get("height");
                    if (hVal != null) {
                        var hFloat = (hVal instanceof Number) ? (hVal as Number).toFloat() : hVal as Float;
                        extrema.add([ts, (hFloat * 100.0).toNumber(), typeCode]);
                    }
                }
            }

            Application.Storage.setValue("tideExtrema", extrema);
            
            // Clean exit, successful sync pipeline
            clearSyncError();
            Application.Storage.setValue("dataUpdatedAt", Time.now().value());
            Background.exit(true);
            return;
        }
        
        saveSyncError(responseCode);
        Background.exit(false);
    }

    function extractSourceValue(paramNode) as Float? {
        if (paramNode == null) { return null; }
        // Attempt dictionary extraction for stormglass format: [ {"source": "noaa", "value": 1.4}, ... ]
        if (paramNode instanceof Array && paramNode.size() > 0) {
            // First pass: look for noaa
            for (var i=0; i<paramNode.size(); i++) {
                var entry = paramNode[i] as Dictionary;
                if (entry.hasKey("source") && (entry.get("source") as String).equals("noaa")) {
                    var v = entry.get("value");
                    return (v instanceof Number) ? (v as Number).toFloat() : v as Float;
                }
            }
            // Second pass: look for sg fallback
            for (var i=0; i<paramNode.size(); i++) {
                var entry = paramNode[i] as Dictionary;
                if (entry.hasKey("source") && (entry.get("source") as String).equals("sg")) {
                    var v = entry.get("value");
                    return (v instanceof Number) ? (v as Number).toFloat() : v as Float;
                }
            }
            // Third pass: fallback to first available
            var fallback = (paramNode[0] as Dictionary).get("value");
            return (fallback instanceof Number) ? (fallback as Number).toFloat() : fallback as Float;
        } else if (paramNode instanceof Dictionary) {
             var v = paramNode.get("noaa");
             if (v == null) { v = paramNode.get("sg"); }
             if (v != null) {
                return (v instanceof Number) ? (v as Number).toFloat() : v as Float;
             }
        }
        return null;
    }

    function formatIso8601(moment as Time.Moment) as String {
        var info = Gregorian.utcInfo(moment, Time.FORMAT_SHORT);
        return Lang.format("$1$-$2$-$3$T$4$:$5$:00+00:00", [
            info.year,
            info.month.format("%02d"),
            info.day.format("%02d"),
            info.hour.format("%02d"),
            info.min.format("%02d")
        ]);
    }

    function parseIso8601ToUnix(iso as String) as Number {
        // format "YYYY-MM-DDTHH:MM:SS+00:00"
        var year = iso.substring(0, 4).toNumber();
        var month = iso.substring(5, 7).toNumber();
        var day = iso.substring(8, 10).toNumber();
        var hour = iso.substring(11, 13).toNumber();
        var min = iso.substring(14, 16).toNumber();
        var sec = iso.substring(17, 19).toNumber();

        // Days from 1970 to beginning of year
        var yForLeap = year - 1;
        var leapDays = (yForLeap / 4) - (yForLeap / 100) + (yForLeap / 400) - ((1970 - 1) / 4) + ((1970 - 1) / 100) - ((1970 - 1) / 400);
        var days = (year - 1970) * 365 + leapDays;

        var daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
            daysInMonth[1] = 29;
        }

        for (var i = 0; i < month - 1; i++) {
            days += daysInMonth[i];
        }

        days += day - 1;

        return days * 86400 + hour * 3600 + min * 60 + sec;
    }

    function saveSyncError(code as Number) as Void {
        Application.Storage.setValue("syncError", code);
        Application.Storage.setValue("errorAt", Time.now().value());
    }

    function clearSyncError() as Void {
        Application.Storage.deleteValue("syncError");
        Application.Storage.deleteValue("errorAt");
    }
}
