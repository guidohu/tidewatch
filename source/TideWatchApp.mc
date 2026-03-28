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
        if (data != null && data instanceof Dictionary) {
            System.println("Saving synced data to storage");
            if (data.hasKey("t")) { // "t" = Tide data
                Application.Storage.setValue("tideData", data.get("t"));
                Application.Storage.deleteValue("tideError");
            }
            if (data.hasKey("n")) { // "n" = Spot name
                Application.Storage.setValue("spotName", data.get("n"));
            }
            if (data.hasKey("w")) { // "w" = Wave/Swell data
                Application.Storage.setValue("waveData", data.get("w"));
                Application.Storage.deleteValue("waveError");
            }
            if (data.hasKey("we")) { // "we" = Wave error code
                Application.Storage.setValue("waveError", data.get("we"));
            }
            if (data.hasKey("te")) { // "te" = Tide error code
                Application.Storage.setValue("tideError", data.get("te"));
            }
            WatchUi.requestUpdate();
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
