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
    var mDataUpdatedThisRun as Boolean = false;

    var mKpayCallback;

    function initialize(cb) {
        ServiceDelegate.initialize();
        mKpayCallback = cb;
        System.println("Tide Watch background task started successfully");
    }

    /**
     * Exits the background task, returning the sync success status.
     * Invokes the KPay callback if running under KiezelPay temporal delegate; otherwise exits directly.
     * @param success Boolean indicating whether background operations completed successfully.
     */
    function exitBackground(success as Boolean) as Void {
        if (mKpayCallback != null) {
            mKpayCallback.invoke(success);
        } else {
            Background.exit(success);
        }
    }

    /**
     * Logs current memory stats to console logs.
     */
    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    /**
     * Retrieves the stored App ID.
     * @return Stored App ID string, or null if not found.
     */
    function getAppId() as String? {
        return Application.Storage.getValue("AppId") as String?;
    }

    /**
     * Main background execution callback triggered by temporal events.
     * Sets target location, calculates start/end moments, and triggers the sync chain.
     */
    function onTemporalEvent() as Void {
        var appId = getAppId();
        if (appId == null) {
            System.println("AppId missing from storage. Background sync aborted.");
            exitBackground(false);
            return;
        }

        mApiKey = Application.Properties.getValue("StormglassApiKey");

        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        if (LocationUtils.isLocationSetAndValid(gpsLat, gpsLon)) {
            mTargetLat = gpsLat.toFloat();
            mTargetLon = gpsLon.toFloat();
        } else {
            System.println("No Location Set or invalid range/type. Exit.");
            exitBackground(false);
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

    /**
     * Checks if the response code indicates API limit / quota issues.
     * Logs the error and exits the background task on match.
     * @param responseCode The HTTP status code of a web request.
     * @return True if quota was exceeded; false otherwise.
     */
    function handleQuotaError(responseCode as Number) as Boolean {
        if (responseCode == 402 || responseCode == 429) {
            System.println("API Quota Exceeded (402/429)!");
            saveSyncError(DataKeys.ERROR_QUOTA_EXCEEDED);
            exitBackground(false);
            return true;
        }
        return false;
    }

    /**
     * Helper to verify if cached data corresponding to a key is still within freshness bounds.
     * @param key Storage lookup key.
     * @param freshnessSec Permissible age limit in seconds.
     * @return True if data exists and is younger than freshnessSec; false otherwise.
     */
    function isFresh(key as String, freshnessSec as Number) as Boolean {
        var updatedAt = Application.Storage.getValue(key);
        if (updatedAt != null && updatedAt instanceof Number) {
            return (Time.now().value() - (updatedAt as Number)) < freshnessSec;
        }
        return false;
    }

    /**
     * Builds HTTP header dictionaries and parameters for Garmin makeWebRequest.
     * @param includeAuth True to attach the Stormglass API key authorization header.
     * @return Request option configuration dictionary.
     */
    function getRequestOptions(includeAuth as Boolean) as Dictionary {
        var headers = { "X-App-Id" => getAppId() };
        if (includeAuth && mApiKey != null && !mApiKey.equals("")) {
            headers.put("Authorization", mApiKey);
        }
        return {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => headers
        };
    }

    /**
     * Safely parses any numeric object to a Float.
     * @param val The numeric object.
     * @return Float representation of val.
     */
    function parseFloatSafe(val as Object) as Float {
        return (val instanceof Number) ? (val as Number).toFloat() : val as Float;
    }

    /**
     * Safely parses any numeric object to a Number.
     * @param val The numeric object.
     * @return Number representation of val.
     */
    function parseNumberSafe(val as Object) as Number {
        return (val instanceof Float) ? (val as Float).toNumber() : val as Number;
    }

    /**
     * Triggers completion of background synchronization.
     * Updates timestamps, clears sync errors, and notifies the watch face via exitBackground.
     */
    function finalizeSync() as Void {
        if (mDataUpdatedThisRun) {
            Application.Storage.setValue("dataUpdatedAt", Time.now().value());
        }
        clearSyncError();
        exitBackground(true);
    }

    /**
     * Executes the BigDataCloud reverse geocode request to fetch localized spot/locality names.
     */
    function makeBigDataCloudRequest() as Void {
        var hasSpotName = (Application.Storage.getValue("spotName") != null);
        var threshold = hasSpotName ? (24 * 3600) : Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC;

        if (isFresh("geocodeUpdatedAt", threshold)) {
            System.println("Geocoding data is fresh, skipping.");
            if (mApiKey != null && !mApiKey.equals("")) {
                makeStormglassWeatherRequest();
            } else {
                makeTideTimelineRequest();
            }
            return;
        }

        var url = "https://forecast.wakeandsurf.ch/data/reverse-geocode";
        var params = {
            "latitude" => mTargetLat,
            "longitude" => mTargetLon,
            "localityLanguage" => "en"
        };
        var options = getRequestOptions(true);
        System.println("Requesting BigDataCloud Reverse-Geocode with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveBigDataCloud));
    }

    /**
     * Callback for the reverse geocoding web request.
     * Stores the resolved spot name or coordinates fallback, then proceeds to weather/tide fetching.
     * @param responseCode HTTP status response code.
     * @param data Parsed JSON response dictionary.
     */
    function onReceiveBigDataCloud(responseCode as Number, data as Dictionary?) as Void {
        System.println("BigDataCloud response: " + responseCode);
        if (responseCode != 200) { System.println("BigDataCloud data: " + data); }
        var spotName = null;
        var success = false;

        if (responseCode == 200 && data != null && data instanceof Dictionary) {
            var locality = data.get("locality");
            var city = data.get("city");
            if (locality != null && locality instanceof String && !locality.equals("")) {
                spotName = locality;
                success = true;
            } else if (city != null && city instanceof String && !city.equals("")) {
                spotName = city;
                success = true;
            }
        }

        if (!success) {
            var cachedSpotName = Application.Storage.getValue("spotName") as String?;
            if (cachedSpotName == null) {
                spotName = Lang.format("$1$, $2$", [mTargetLat.format("%.2f"), mTargetLon.format("%.2f")]);
                Application.Storage.setValue("spotName", spotName);
                mDataUpdatedThisRun = true;
            }
            System.println("Geocoding failed, fallback to coordinates (or keep cached): " + spotName);
        } else {
            Application.Storage.setValue("geocodeUpdatedAt", Time.now().value());
            Application.Storage.setValue("spotName", spotName);
            mDataUpdatedThisRun = true;
            System.println("Resolved spotName: " + spotName);
        }

        // Always proceed to the next request
        data = null;
        if (mApiKey != null && !mApiKey.equals("")) {
            makeStormglassWeatherRequest();
        } else {
            makeTideTimelineRequest();
        }
    }

    /**
     * Executes the Stormglass Weather web request to fetch swell sizes, periods, and direction parameters.
     */
    function makeStormglassWeatherRequest() as Void {
        if (isFresh("weatherUpdatedAt", Constants.SLOW_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            System.println("Weather data is fresh, skipping.");
            makeTideTimelineRequest();
            return;
        }

        var url = "https://forecast.wakeandsurf.ch/v2/weather/point";
        var params = {
            "lat" => mTargetLat,
            "lng" => mTargetLon,
            "start" => mStart,
            "end" => mEnd,
            "params" => "swellHeight,swellPeriod,swellDirection,secondarySwellHeight,secondarySwellPeriod,secondarySwellDirection",
            "source" => "noaa"
        };
        var options = getRequestOptions(true);
        System.println("Requesting Stormglass Weather with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveWeather));
    }

    /**
     * Callback for the Stormglass Weather web request.
     * Decodes and stores primary/secondary swell heights and directions to storage.
     * @param responseCode HTTP status response code.
     * @param data Parsed JSON response dictionary.
     */
    function onReceiveWeather(responseCode as Number, data as Dictionary?) as Void {
        System.println("Weather response: " + responseCode);
        if (responseCode != 200) { 
            System.println("Weather data: " + data);
            var errCode = DataKeys.ERROR_OTHER;
            if (responseCode == 402 || responseCode == 429) {
                errCode = DataKeys.ERROR_QUOTA_EXCEEDED;
            } else if (data != null && data instanceof Dictionary && data.hasKey("errors")) {
                var errors = data.get("errors") as Dictionary;
                if (errors.hasKey("key")) {
                    var keyErr = errors.get("key") as String;
                    if (keyErr.equals("API key is invalid")) {
                        errCode = DataKeys.ERROR_INVALID_KEY;
                    }
                }
            }
            Application.Storage.setValue("weatherError", errCode);
        } else {
            Application.Storage.deleteValue("weatherError");
        }

        logMemoryUsage();
        // Do not call handleQuotaError here, since we want tide data to continue syncing
        // even if the user's weather API key has exceeded its quota limits.

        if (responseCode == 200 && data != null && data instanceof Dictionary && data.hasKey("data")) {
            var pts = data.get("data");
            if (pts instanceof Array) {
                var waveResults = new Array<Array<Number?>>[pts.size()];
                
                for (var i = 0; i < pts.size(); i++) {
                    var pt = pts[i];
                    if (pt instanceof Dictionary) {
                        var wPoint = new Array<Number?>[9];
                        
                        // Primary Swell
                        var h = pt.get("h1");
                        var p = pt.get("p1");
                        var d = pt.get("d1");
                        if (h != null) { wPoint[0] = (parseFloatSafe(h) * 100.0).toNumber(); }
                        if (p != null) { wPoint[1] = parseNumberSafe(p); }
                        if (d != null) { wPoint[2] = parseNumberSafe(d); }

                        // Secondary Swell
                        var h2 = pt.get("h2");
                        var p2 = pt.get("p2");
                        var d2 = pt.get("d2");
                        if (h2 != null) { wPoint[3] = (parseFloatSafe(h2) * 100.0).toNumber(); }
                        if (p2 != null) { wPoint[4] = parseNumberSafe(p2); }
                        if (d2 != null) { wPoint[5] = parseNumberSafe(d2); }

                        waveResults[i] = wPoint;
                    }
                }
                
                Application.Storage.setValue("waveData", waveResults);
                Application.Storage.setValue("swellUnitApi", DataKeys.UNIT_METER); // Stormglass default metric
                Application.Storage.setValue("weatherUpdatedAt", Time.now().value());
                mDataUpdatedThisRun = true;
                waveResults = null;
                data = null;
            }
        }
        
        // If we failed weather (but not quota), still try tides
        makeTideTimelineRequest();
    }

    /**
     * Executes the Tide Timeline web request to fetch absolute tide level elevations.
     */
    function makeTideTimelineRequest() as Void {
        if (isFresh("tideTimelineUpdatedAt", Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            System.println("Tide timeline data is fresh, skipping.");
            makeTideExtremesRequest();
            return;
        }

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
        var options = getRequestOptions(false);
        System.println("Requesting Tide Timeline: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveTide));
    }

    /**
     * Callback for the Tide Timeline web request.
     * Parses and registers grid elevation array data to application storage, then triggers extremes sync.
     * @param responseCode HTTP status response code.
     * @param data Parsed JSON response dictionary.
     */
    function onReceiveTide(responseCode as Number, data as Dictionary?) as Void {
        System.println("Tide response: " + responseCode);
        if (responseCode != 200) { System.println("Tide data: " + data); }
        logMemoryUsage();
        if (handleQuotaError(responseCode)) { return; }

        if (responseCode == 200 && data != null && data instanceof Dictionary && data.hasKey("data")) {
            var pts = data.get("data");
            if (pts instanceof Array) {
                var gridHeights = [];
                var gridTimes = [];
                
                for (var i = 0; i < pts.size(); i++) {
                    var point = pts[i];
                    if (point instanceof Dictionary) {
                        var ts = point.get("ts");
                        if (ts != null) {
                            gridTimes.add(parseNumberSafe(ts));
                            var h = point.get("h");
                            if (h != null) {
                                gridHeights.add((parseFloatSafe(h) * 100.0).toNumber());
                            } else {
                                gridHeights.add(0);
                            }
                        }
                    }
                }

                if (gridTimes.size() > 0) {
                    Application.Storage.setValue("tideTimes", gridTimes);
                    Application.Storage.setValue("tideData", gridHeights);
                    Application.Storage.setValue("tideUnitApi", DataKeys.UNIT_METER);
                    Application.Storage.setValue("tideTimelineUpdatedAt", Time.now().value());
                    mDataUpdatedThisRun = true;
                    
                    gridTimes = null;
                    gridHeights = null;
                    data = null;
                    makeTideExtremesRequest();
                    return;
                } else {
                    gridTimes = null;
                    gridHeights = null;
                    data = null;
                    saveSyncError(DataKeys.ERROR_NO_DATA);
                    exitBackground(false);
                    return;
                }
            }
        }
        
        saveSyncError(responseCode);
        exitBackground(false);
    }

    /**
     * Executes the Tide Extremes web request to retrieve times/heights of upcoming high/low peaks.
     */
    function makeTideExtremesRequest() as Void {
        if (isFresh("tideExtremesUpdatedAt", Constants.FAST_SYNC_FRESHNESS_THRESHOLD_SEC)) {
            System.println("Tide extremes data is fresh, skipping.");
            finalizeSync();
            return;
        }

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
        var options = getRequestOptions(false);
        System.println("Requesting Tide Extremes with: " + url + " parameters: " + params);
        Communications.makeWebRequest(url, params, options, method(:onReceiveExtremes));
    }

    /**
     * Callback for the Tide Extremes web request.
     * Decodes high/low metadata, updates storage, and completes the sync sequence.
     * @param responseCode HTTP status response code.
     * @param data Parsed JSON response dictionary.
     */
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

        if (responseCode == 200 && data != null && data instanceof Dictionary && data.hasKey("data")) {
            var pts = data.get("data");
            if (pts instanceof Array) {
                var extrema = [];
                
                for (var i = 0; i < pts.size(); i++) {
                    var point = pts[i];
                    if (point instanceof Dictionary) {
                        var typeStr = point.get("t");
                        if (typeStr != null && typeStr instanceof String && (typeStr.equals("high") || typeStr.equals("low"))) {
                            var typeCode = typeStr.equals("high") ? DataKeys.TIDE_TYPE_HIGH : DataKeys.TIDE_TYPE_LOW;
                            var ts = point.get("ts");
                            var hVal = point.get("h");
                            if (ts != null && hVal != null) {
                                extrema.add([parseNumberSafe(ts), (parseFloatSafe(hVal) * 100.0).toNumber(), typeCode]);
                            }
                        }
                    }
                }

                Application.Storage.setValue("tideExtrema", extrema);
                Application.Storage.setValue("tideExtremesUpdatedAt", Time.now().value());
                mDataUpdatedThisRun = true;
                
                // Clean exit, successful sync pipeline
                finalizeSync();
                return;
            }
        }
        
        saveSyncError(responseCode);
        exitBackground(false);
    }

    /**
     * Saves the sync failure error code and timestamp to storage.
     * @param code The numeric error code.
     */
    function saveSyncError(code as Number) as Void {
        Application.Storage.setValue("syncError", code);
        Application.Storage.setValue("errorAt", Time.now().value());
    }

    /**
     * Removes saved sync failure codes and timestamps from storage.
     */
    function clearSyncError() as Void {
        Application.Storage.deleteValue("syncError");
        Application.Storage.deleteValue("errorAt");
    }
}
