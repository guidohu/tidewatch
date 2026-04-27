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
    var mDatumStr as String? = null;



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

        var datumProp = Application.Properties.getValue("TideDatum") as Number;
        if (datumProp == DataKeys.DATUM_MSL) {
            mDatumStr = "MSL";
        } else if (datumProp == DataKeys.DATUM_MLLW) {
            mDatumStr = "MLLW";
        } else if (datumProp == DataKeys.DATUM_LAT) {
            mDatumStr = "LAT";
        } else {
            mDatumStr = null;
        }

        // Aligning exactly to the "Align Graphs" logic from 6 hours ago to 16 hours forward
        var now = Time.now();
        var startTs = now.subtract(new Time.Duration(4 * 3600));
        var endTs = now.add(new Time.Duration(48 * 3600));
        var tideEndTs = now.add(new Time.Duration(48 * 3600));

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
        var url = "https://forecast.wakeandsurf.ch/data/reverse-geocode-client";
        var params = {
            "latitude" => mTargetLat,
            "longitude" => mTargetLon,
            "localityLanguage" => "en"
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { 
                "Authorization" => mApiKey,
                "X-App-Id" => "app-Z9xbg5GQW8p7I6nDtRA" 
            }
        };
        System.println("Requesting BigDataCloud Reverse-Geocode with: " + url + " parameters: " + params);
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
        if (mApiKey != null && !mApiKey.equals("")) {
            makeStormglassWeatherRequest();
        } else {
            makeTideTimelineRequest();
        }
    }

    function makeStormglassWeatherRequest() as Void {
        var url = "https://forecast.wakeandsurf.ch/v2/weather/point";
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
            :headers => { 
                "Authorization" => mApiKey,
                "X-App-Id" => "app-Z9xbg5GQW8p7I6nDtRA"
            }
        };
        System.println("Requesting Stormglass Weather with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveWeather));
    }

    function onReceiveWeather(responseCode as Number, data as Dictionary?) as Void {
        System.println("Weather response: " + responseCode);
        if (responseCode != 200) { System.println("Weather data: " + data); }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) { return; }

        if (responseCode == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var waveResults = new Array<Array<Number?>>[pts.size()];
            
            for (var i = 0; i < pts.size(); i++) {
                var pt = pts[i] as Dictionary;

                
                var wPoint = new Array<Number?>[9];
                
                // Primary Swell
                var h = pt.get("h1");
                var p = pt.get("p1");
                var d = pt.get("d1");
                if (h != null) {
                    var hFloat = (h instanceof Number) ? (h as Number).toFloat() : h as Float;
                    wPoint[0] = (hFloat * 100.0).toNumber();
                }
                if (p != null) {
                    wPoint[1] = (p instanceof Number) ? p as Number : (p as Float).toNumber();
                }
                if (d != null) {
                    wPoint[2] = (d instanceof Number) ? d as Number : (d as Float).toNumber();
                }

                // Secondary Swell
                var h2 = pt.get("h2");
                var p2 = pt.get("p2");
                var d2 = pt.get("d2");
                if (h2 != null) {
                    var h2Float = (h2 instanceof Number) ? (h2 as Number).toFloat() : h2 as Float;
                    wPoint[3] = (h2Float * 100.0).toNumber();
                }
                if (p2 != null) {
                    wPoint[4] = (p2 instanceof Number) ? p2 as Number : (p2 as Float).toNumber();
                }
                if (d2 != null) {
                    wPoint[5] = (d2 instanceof Number) ? d2 as Number : (d2 as Float).toNumber();
                }

                waveResults[i] = wPoint;
            }
            
            Application.Storage.setValue("waveData", waveResults);
            Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_METER); // Stormglass default metric
            waveResults = null;
            data = null;
            makeTideTimelineRequest();
            return;
        }
        
        saveSyncError(responseCode);
        Background.exit(false);
    }

    function makeTideTimelineRequest() as Void {
        var url = "https://forecast.wakeandsurf.ch/tides/timeline";
        var params = {
            "latitude" => mTargetLat,
            "longitude" => mTargetLon,
            "start" => mStart,
            "end" => mTideEnd
        };
        if (mDatumStr != null) {
            params.put("datum", mDatumStr);
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { 
                "X-App-Id" => "app-Z9xbg5GQW8p7I6nDtRA"
            }
        };
        System.println("Requesting Tide Timeline: " + url + " parameters: " + params);
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
                gridTimes[i] = point.get("ts") as Number;
                var h = point.get("h");
                if (h != null) {
                    var hFloat = (h instanceof Number) ? (h as Number).toFloat() : h as Float;
                    gridHeights[i] = (hFloat * 100.0).toNumber();
                } else {
                    gridHeights[i] = 0;
                }
            }

            if (gridTimes.size() > 0) {
                Application.Storage.setValue("tideTimes", gridTimes);
                Application.Storage.setValue("tideData", gridHeights);
                Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_METER);
            }
            
            gridTimes = null;
            gridHeights = null;
            data = null;
            makeTideExtremesRequest();
            return;
        }
        
        saveSyncError(responseCode);
        Background.exit(false);
    }

    function makeTideExtremesRequest() as Void {
        var url = "https://forecast.wakeandsurf.ch/tides/extremes";
        var params = {
            "latitude" => mTargetLat,
            "longitude" => mTargetLon,
            "start" => mStart,
            "end" => mTideEnd
        };
        if (mDatumStr != null) {
            params.put("datum", mDatumStr);
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => { 
                "X-App-Id" => "app-Z9xbg5GQW8p7I6nDtRA"
            }
        };
        System.println("Requesting Tide Extremes with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveExtremes));
    }

    function onReceiveExtremes(responseCode as Number, data as Dictionary?) as Void {
        System.println("Extremes response: " + responseCode);
        if (responseCode != 200) { 
            System.println("Extremes data: " + data);
        }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) {
            System.println("Quota error");
            return;
        }

        if (responseCode == 200 && data != null && data.hasKey("data")) {
            var pts = data.get("data") as Array;
            var extrema = [];
            
            for (var i = 0; i < pts.size(); i++) {
                var point = pts[i] as Dictionary;
                var typeStr = point.get("t");
                if (typeStr != null && (typeStr.equals("high") || typeStr.equals("low"))) {
                    var typeCode = typeStr.equals("high") ? DataKeys.TIDE_TYPE_HIGH : DataKeys.TIDE_TYPE_LOW;
                    var ts = point.get("ts");
                    var hVal = point.get("h");
                    if (ts != null && hVal != null) {
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

    // Utility functions parseIso8601ToUnix, formatIso8601, and extractSourceValue removed as proxy returns compacted format

    function saveSyncError(code as Number) as Void {
        Application.Storage.setValue("syncError", code);
        Application.Storage.setValue("errorAt", Time.now().value());
    }

    function clearSyncError() as Void {
        Application.Storage.deleteValue("syncError");
        Application.Storage.deleteValue("errorAt");
    }
}
