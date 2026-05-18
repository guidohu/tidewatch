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
        }
        if (!LocationUtils.isValidLongitude(gpsLon)) {
            Application.Properties.setValue("GpsLon", 0.0);
        }

        TideWatchSettingsMenu.triggerImmediateSync(true);
        WatchUi.requestUpdate();
    }

    function getInitialView() {
        // Store AppId for background service since Rez isn't accessible there
        Application.Storage.setValue("AppId", WatchUi.loadResource(Rez.Strings.AppId));

        migrateSettings();

        kpay = new KPay.Core(getKPayConfig());

        if (System has :ServiceDelegate) {
            scheduleNextBackgroundEvent(null);
        }
        return [ new TideWatchView() ] as [WatchUi.Views];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("onBackgroundData called with data: " + (data == null ? "null" : data.toString()));
        logMemoryUsage();
        
        if (kpay != null && data instanceof Dictionary) {
            kpay.onBackgroundData(data);
            
            var response = (data as Dictionary)[(kpay as KPay.Core).extraResponseKey];
            if (response != null) {
                // Data is now saved directly to Storage by the background service.
                // We just need to trigger a UI refresh and handle follow-up registration.
                Application.Storage.setValue("dataUpdatedAt", Time.now().value());
                WatchUi.requestUpdate();
            }
        } else {
            System.println("TideWatch Background service: kpay is null or no data");
        }
        
        // Configure periodic intervals after the first accelerated sync
        if (System has :ServiceDelegate) {
            var earliest = Time.now().add(new Time.Duration(Constants.DATA_UPDATE_INTERVAL_SEC));
            scheduleNextBackgroundEvent(earliest);
        }
    }

    function getServiceDelegate() {
        System.println("TideWatch Background service: getServiceDelegate");
        return [ new KPay.KPayBackgroundServiceDelegate(TideWatchBackground, 0) ] as [System.ServiceDelegate];
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
