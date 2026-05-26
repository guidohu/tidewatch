import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
using KPayClock.KPay as KPay;

var kpay as KPay.Core?;

(:background)
class TideWatchApp extends Application.AppBase {

    var mLastGpsLat;
    var mLastGpsLon;
    var mLastDatum;
    var mLastApiKey;

    /**
     * Constructor. Initializes the parent AppBase.
     */
    function initialize() {
        AppBase.initialize();
    }

    /**
     * Lifecycle callback when the app stops.
     * Stops the KiezelPay task/timers if active.
     */
    function onStop(state as Dictionary?) as Void {
        if (kpay != null) {
            kpay.onStop();
        }
    }

    /**
     * Parses a generic coordinate value from an Object (e.g. String) to a Float.
     * Validates that the parsed value falls between min and max bounds.
     * @param val The coordinate value object to parse.
     * @param min The minimum acceptable coordinate.
     * @param max The maximum acceptable coordinate.
     * @return The parsed coordinate float, or 0.0 if parsing or bounds check fails.
     */
    function parseCoordinate(val as Object?, min as Float, max as Float) as Float {
        if (val instanceof String) {
            try {
                var f = val.toFloat();
                if (f != null && f >= min && f <= max) {
                    return f;
                }
            } catch (e) {
                System.println("Failed to parse coordinate: " + e.getErrorMessage());
            }
        }
        return 0.0;
    }

    /**
     * Parses a latitude coordinate from an Object to a Float, validating range [-90, 90].
     * @param val The latitude object to parse.
     * @return The parsed latitude float, or 0.0 on failure.
     */
    function parseLatitude(val as Object?) as Float {
        return parseCoordinate(val, -90.0, 90.0);
    }

    /**
     * Parses a longitude coordinate from an Object to a Float, validating range [-180, 180].
     * @param val The longitude object to parse.
     * @return The parsed longitude float, or 0.0 on failure.
     */
    function parseLongitude(val as Object?) as Float {
        return parseCoordinate(val, -180.0, 180.0);
    }

    /**
     * Migrates settings stored as legacy Strings (e.g. from old Garmin settings)
     * into proper Floats for latitude and longitude.
     */
    function migrateSettings() as Void {
        // Migrate potential string gps lat/lon from settings to float.
        var gpsLat = Application.Properties.getValue("GpsLat");
        if (gpsLat instanceof String) {
            Application.Properties.setValue("GpsLat", parseLatitude(gpsLat));
            System.println("Migrated GpsLat from String to Float.");
        }
        
        var gpsLon = Application.Properties.getValue("GpsLon");
        if (gpsLon instanceof String) {
            Application.Properties.setValue("GpsLon", parseLongitude(gpsLon));
            System.println("Migrated GpsLon from String to Float.");
        }

        // Version-based data migrations
        var currentVersion = Version.STRING;
        var lastVersion = Application.Storage.getValue("AppVersion") as String?;

        if (lastVersion == null || Version.isLowerThan(lastVersion, currentVersion)) {
            System.println("Upgrading app from " + (lastVersion == null ? "unknown" : lastVersion) + " to " + currentVersion);
            
            // Invalidate legacy formats from prior versions
            Application.Storage.deleteValue("tideTimes");
            Application.Storage.deleteValue("tideData");
            Application.Storage.deleteValue("waveData");
            Application.Storage.setValue("dataUpdatedAt", 0);

            // Reset sync thresholds to trigger immediate background download
            Application.Storage.deleteValue("geocodeUpdatedAt");
            Application.Storage.deleteValue("weatherUpdatedAt");
            Application.Storage.deleteValue("tideTimelineUpdatedAt");
            Application.Storage.deleteValue("tideExtremesUpdatedAt");

            // Save the new version string to storage
            Application.Storage.setValue("AppVersion", currentVersion);
        }
    }

    /**
     * Retrieves or generates a pseudo-random anonymous user identifier.
     */
    function getOrCreateAnonymousIdentifier() {
        var userId = Storage.getValue("anonymous_user_id");
        
        if (userId == null) {
            var chars = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
            var uuid = "";
            
            // Generate a 32-character hex string (UUIDv4 style: 8-4-4-4-12)
            for (var i = 0; i < 32; i++) {
                if (i == 8 || i == 12 || i == 16 || i == 20) {
                    uuid += "-";
                }
                // Math.rand() is fine for generating a single index 0-15
                var idx = Math.rand() % 16;
                uuid += chars[idx];
            }
            
            userId = uuid;
            Storage.setValue("anonymous_user_id", userId);
        }
        return userId;
    }

    /**
     * Prints current system memory stats to debug logs.
     */
    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    /**
     * Instantiates or destroys the KiezelPay Core controller based on settings.
     * @param enableKPay If true, initializes and starts KiezelPay; otherwise, disables it.
     * @return True if the KPay activation state changed.
     */
    function initializeKPay(enableKPay as Boolean) as Boolean {
        var kpayChanged = false;
        if (enableKPay) {
            var kpayInstance = kpay;
            if (kpayInstance == null) {
                kpayInstance = new KPay.Core(getKPayConfig());
                kpay = kpayInstance;
                kpayChanged = true;
            }
            System.println("KiezelPay isLicensed: " + kpayInstance.isLicensed());
            if (!kpayInstance.isLicensed()) {
                kpayInstance.startPurchase();
            }
        } else {
            if (kpay != null) {
                kpay = null;
                kpayChanged = true;
            }
        }
        return kpayChanged;
    }

    /**
     * Lifecycle callback triggered when user settings are changed in Connect IQ.
     * Validates GPS location bounds, resets/initializes KPay, and checks if a background sync is needed.
     */
    function onSettingsChanged() {
        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        if (!LocationUtils.isValidLatitude(gpsLat)) {
            Application.Properties.setValue("GpsLat", 0.0);
            gpsLat = 0.0;
        }
        if (!LocationUtils.isValidLongitude(gpsLon)) {
            Application.Properties.setValue("GpsLon", 0.0);
            gpsLon = 0.0;
        }

        var enableKPayVal = Application.Properties.getValue("EnableKPay");
        var enableKPay = (enableKPayVal != null) ? enableKPayVal as Boolean : false;
        var kpayChanged = initializeKPay(enableKPay);

        var curDatum = Application.Properties.getValue("TideDatum");
        var curApiKey = Application.Properties.getValue("StormglassApiKey");

        var needsSync = false;
        if (gpsLat != mLastGpsLat || gpsLon != mLastGpsLon || curDatum != mLastDatum || 
           (curApiKey != null && !curApiKey.equals(mLastApiKey)) || (mLastApiKey != null && !mLastApiKey.equals(curApiKey)) || kpayChanged) {
            needsSync = true;
        }

        mLastGpsLat = gpsLat;
        mLastGpsLon = gpsLon;
        mLastDatum = curDatum;
        mLastApiKey = curApiKey;

        if (needsSync) {
            TideWatchSettingsMenu.triggerImmediateSync(true);
        }
        
        WatchUi.requestUpdate();
    }

    /**
     * Initializer for the first view of the application.
     * @return Array containing the main watch face view.
     */
    function getInitialView() {
        // Store AppId for background service since Rez isn't accessible there
        Application.Storage.setValue("AppId", WatchUi.loadResource(Rez.Strings.AppId));

        getOrCreateAnonymousIdentifier();
        migrateSettings();

        mLastGpsLat = Application.Properties.getValue("GpsLat");
        mLastGpsLon = Application.Properties.getValue("GpsLon");
        mLastDatum = Application.Properties.getValue("TideDatum");
        mLastApiKey = Application.Properties.getValue("StormglassApiKey");

        var enableKPayVal = Application.Properties.getValue("EnableKPay");
        var enableKPay = (enableKPayVal != null) ? enableKPayVal as Boolean : false;
        initializeKPay(enableKPay);

        if (System has :ServiceDelegate) {
           scheduleNextBackgroundEvent(null);
        }
        return [ new TideWatchView() ] as [WatchUi.Views];
    }

    /**
     * Handles data returned by the background service delegate.
     * 
     * Expected data formats:
     * - KPay Enabled: We expect a Dictionary returned by KPay containing licensing info 
     *   and the sync success status (Boolean) nested under its extraResponseKey.
     * - KPay Disabled: We expect a direct Boolean value representing the sync success status.
     * - Everything else is unexpected and ignored.
     * 
     * Note: Our custom background service (TideWatchBackground) writes all retrieved tide and
     * weather data directly to Application.Storage. The return value passed here is only used to
     * indicate sync success, update the timestamp, and trigger a UI refresh.
     * 
     * @param data The persistable type returned by the background service delegate.
     */
    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("onBackgroundData called with data: " + (data == null ? "null" : data.toString()));
        logMemoryUsage();
        
        if (kpay != null && data instanceof Dictionary) {
            // Let KPay process its own data and update its internal state.
            kpay.onBackgroundData(data);

            var event = data.get("kpay_event");
            if (event instanceof Dictionary) {
                var kpayStatus = event.get("status");
                System.println("KiezelPay background event status: " + kpayStatus);
            }
            System.println("KiezelPay isLicensed after sync: " + kpay.isLicensed());

            // Extract the actual response from our background task.
            var response = (data as Dictionary)[(kpay as KPay.Core).extraResponseKey];
            if (response instanceof Boolean && response as Boolean) {
                // Data is now saved directly to Storage by the background service.
                // We just need to trigger a UI refresh and handle follow-up registration.
                Application.Storage.setValue("dataUpdatedAt", Time.now().value());
                WatchUi.requestUpdate();
            } else {
                System.println("TideWatch Background service: kpay pass-through sync failed");
            }
        } else if (kpay == null && data instanceof Boolean) {
            if (data as Boolean) {
                Application.Storage.setValue("dataUpdatedAt", Time.now().value());
                WatchUi.requestUpdate();
            } else {
                System.println("TideWatch Background service: sync failed");
            }
        } else {
            System.println("TideWatch Background service: unknown data format or failed sync");
        }
        
        // Configure periodic intervals after the first accelerated sync
        if (System has :ServiceDelegate) {
            var earliest = Time.now().add(new Time.Duration(Constants.DATA_UPDATE_INTERVAL_SEC));
            scheduleNextBackgroundEvent(earliest);
        }
    }

    /**
     * Gets the background service delegate instance to execute scheduled events.
     * If KiezelPay is enabled, returns KPay's background service delegate wrapper.
     * @return Array containing the ServiceDelegate.
     */
    function getServiceDelegate() {
        System.println("TideWatch Background service: getServiceDelegate");
        var enableKPayVal = Application.Properties.getValue("EnableKPay");
        if (enableKPayVal != null && enableKPayVal as Boolean == true) {
            return [ new KPay.KPayBackgroundServiceDelegate(TideWatchBackground, 0) ] as [System.ServiceDelegate];
        } else {
            return [ new TideWatchBackground(null) ] as [System.ServiceDelegate];
        }
    }

    /**
     * Retrieves the settings menu views and delegates.
     * @return Array containing the menu view and its input delegate.
     */
    function getSettingsView() {
        return [ new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate() ] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

/**
 * Helper to get the active TideWatchApp instance.
 * @return The active TideWatchApp application instance.
 */
function getApp() as TideWatchApp {
    return Application.getApp() as TideWatchApp;
}

/**
 * Registers/schedules the next background temporal event.
 * Ensures the event complies with Garmin's minimum 5-minute event duration rules.
 * @param earliestTime The earliest Moment to run the event, or null to schedule immediately.
 */
function scheduleNextBackgroundEvent(earliestTime as Time.Moment?) as Void {
    if (Toybox has :Background) {
        try { 
            var lastTime = Background.getLastTemporalEventTime();
            var nextTime = Time.now();

            if (earliestTime != null && earliestTime.value() > nextTime.value()) {
                nextTime = earliestTime;
            }

            // Garmin only allows events that are at least 5 minutes after the last event for
            // watch faces and background apps.
            if (lastTime != null) {
                var lastPlus5 = lastTime.add(new Time.Duration(5 * 60));
                if (lastPlus5.value() > nextTime.value()) {
                    nextTime = lastPlus5;
                }
            }
            
            var info = Gregorian.info(nextTime, Time.FORMAT_SHORT);
            System.println(Lang.format("Scheduling background event for: $1$-$2$-$3$ $4$:$5$:$6$", [
                info.year,
                info.month.format("%02d"),
                info.day.format("%02d"),
                info.hour.format("%02d"),
                info.min.format("%02d"),
                info.sec.format("%02d")
            ]));
            
            Background.registerForTemporalEvent(nextTime);
        } catch (e) {
            System.println("Background registration failed: " + e.getErrorMessage()); 
        }
    } else {
        System.println("Background not available"); 
    }
}
