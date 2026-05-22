import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
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

    function initialize() {
        AppBase.initialize();
    }

    function onStop(state as Dictionary?) as Void {
        if (kpay != null) {
            kpay.onStop();
        }
    }

    function migrateSettings() as Void {
        var gpsLat = Application.Properties.getValue("GpsLat");
        if (gpsLat instanceof String) {
            var latFloat = 0.0;
            try {
                var f = gpsLat.toFloat();
                if (f != null && LocationUtils.isValidLatitude(f)) {
                    latFloat = f.toFloat();
                }
            } catch (e) {
                System.println("Failed to parse GpsLat: " + e.getErrorMessage());
            }
            Application.Properties.setValue("GpsLat", latFloat);
            System.println("Migrated GpsLat from String to Float.");
        }
        
        var gpsLon = Application.Properties.getValue("GpsLon");
        if (gpsLon instanceof String) {
            var lonFloat = 0.0;
            try {
                var f = gpsLon.toFloat();
                if (f != null && LocationUtils.isValidLongitude(f)) {
                    lonFloat = f.toFloat();
                }
            } catch (e) {
                System.println("Failed to parse GpsLon: " + e.getErrorMessage());
            }
            Application.Properties.setValue("GpsLon", lonFloat);
            System.println("Migrated GpsLon from String to Float.");
        }
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

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
        var kpayChanged = false;
        if (enableKPay) {
            var kpayInstance = kpay;
            if (kpayInstance == null) {
                kpayInstance = new KPay.Core(getKPayConfig());
                kpay = kpayInstance;
                kpayChanged = true;
            }
            System.println("KiezelPay settings changed - isLicensed: " + kpayInstance.isLicensed());
            if (!kpayInstance.isLicensed()) {
                kpayInstance.startPurchase();
            }
        } else {
            if (kpay != null) {
                kpay = null;
                kpayChanged = true;
            }
        }

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

    function getInitialView() {
        // Store AppId for background service since Rez isn't accessible there
        Application.Storage.setValue("AppId", WatchUi.loadResource(Rez.Strings.AppId));

        migrateSettings();

        mLastGpsLat = Application.Properties.getValue("GpsLat");
        mLastGpsLon = Application.Properties.getValue("GpsLon");
        mLastDatum = Application.Properties.getValue("TideDatum");
        mLastApiKey = Application.Properties.getValue("StormglassApiKey");

        var enableKPayVal = Application.Properties.getValue("EnableKPay");
        if (enableKPayVal != null && enableKPayVal as Boolean == true) {
            var kpayInstance = new KPay.Core(getKPayConfig());
            kpay = kpayInstance;
            System.println("KiezelPay startup - isLicensed: " + kpayInstance.isLicensed());
            if (!kpayInstance.isLicensed()) {
                kpayInstance.startPurchase();
            }
        }

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

    function getServiceDelegate() {
        System.println("TideWatch Background service: getServiceDelegate");
        var enableKPayVal = Application.Properties.getValue("EnableKPay");
        if (enableKPayVal != null && enableKPayVal as Boolean == true) {
            return [ new KPay.KPayBackgroundServiceDelegate(TideWatchBackground, 0) ] as [System.ServiceDelegate];
        } else {
            return [ new TideWatchBackground(null) ] as [System.ServiceDelegate];
        }
    }

    function getSettingsView() {
        return [ new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate() ] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

function getApp() as TideWatchApp {
    return Application.getApp() as TideWatchApp;
}

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
