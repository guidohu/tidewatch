import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class TideWatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        if (System has :ServiceDelegate) {
            try {
                var tideData = Application.Storage.getValue("tideData");
                if (tideData == null) {
                    // Fastest possible scheduling allowed by Garmin OS for new installations
                    Background.registerForTemporalEvent(new Time.Duration(5 * 60));
                } else {
                    Background.registerForTemporalEvent(new Time.Duration(15 * 60));
                }
            } catch (e) {
                System.println("Background error: " + e.getErrorMessage());
            }
        }
        return [ new TideWatchView() ] as [Views];
    }

    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("onBackgroundData called with data: " + (data == null ? "null" : "valid"));
        logMemoryUsage();
        if (data != null && data instanceof Dictionary) {
            System.println("Saving synced data to storage");
            if (data.hasKey(DataKeys.TIDE_DATA)) { // TIDE_DATA = Tide data array
                Application.Storage.setValue("tideData", data.get(DataKeys.TIDE_DATA));
                Application.Storage.deleteValue("tideError");
            }
            if (data.hasKey(DataKeys.TIDE_START_TIME)) {
                Application.Storage.setValue("tideStartTime", data.get(DataKeys.TIDE_START_TIME));
            }
            if (data.hasKey(DataKeys.TIDE_INTERVAL)) {
                Application.Storage.setValue("tideInterval", data.get(DataKeys.TIDE_INTERVAL));
            }
            if (data.hasKey(DataKeys.TIDE_EXTREMA)) {
                Application.Storage.setValue("tideExtrema", data.get(DataKeys.TIDE_EXTREMA));
            }
            if (data.hasKey(DataKeys.TIDE_TIMES)) {
                Application.Storage.setValue("tideTimes", data.get(DataKeys.TIDE_TIMES));
            }
            if (data.hasKey(DataKeys.SPOT_NAME)) { // SPOT_NAME = Spot name
                Application.Storage.setValue("spotName", data.get(DataKeys.SPOT_NAME));
            }
            if (data.hasKey(DataKeys.WAVE_DATA)) { // WAVE_DATA = Wave/Swell data
                Application.Storage.setValue("waveData", data.get(DataKeys.WAVE_DATA));
                Application.Storage.deleteValue("waveError");
            }
            if (data.hasKey(DataKeys.WAVE_ERROR)) { // WAVE_ERROR = Wave error code
                Application.Storage.setValue("waveError", data.get(DataKeys.WAVE_ERROR));
            }
            if (data.hasKey(DataKeys.TIDE_ERROR)) { // TIDE_ERROR = Tide error code
                Application.Storage.setValue("tideError", data.get(DataKeys.TIDE_ERROR));
            }
            if (data.hasKey(DataKeys.TIDE_UNIT)) {
                Application.Storage.setValue("tideUnitApi", data.get(DataKeys.TIDE_UNIT));
            }
            if (data.hasKey(DataKeys.SWELL_UNIT)) {
                Application.Storage.setValue("swellUnitApi", data.get(DataKeys.SWELL_UNIT));
            }
            WatchUi.requestUpdate();
            logMemoryUsage();
        }
        
        // Switch to periodic 15-minute intervals after the first accelerated sync
        if (System has :ServiceDelegate) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(15 * 60));
            } catch (e) {
                System.println("Background registration error: " + e.getErrorMessage());
            }
        }
    }

    function getServiceDelegate() {
        return [ new TideWatchBackground() ] as [System.ServiceDelegate];
    }
}

function getApp() as TideWatchApp {
    return Application.getApp() as TideWatchApp;
}
