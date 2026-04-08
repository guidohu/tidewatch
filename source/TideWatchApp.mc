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
        System.println("onBackgroundData called with data: " + (data == null ? "null" : data.toString()));
        logMemoryUsage();
        
        // Data is now saved directly to Storage by the background service.
        // We just need to trigger a UI refresh and handle follow-up registration.
        
        var spotId = Application.Properties.getValue("SpotId");
        var lastSpotId = Application.Storage.getValue("lastSpotId");
        if (spotId != null && !spotId.equals(lastSpotId)) {
            Application.Storage.setValue("lastSpotId", spotId);
        }

        Application.Storage.setValue("dataUpdatedAt", Time.now().value());
        WatchUi.requestUpdate();
        logMemoryUsage();
        
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

    function getSettingsView() {
        return [ new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate() ] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

function getApp() as TideWatchApp {
    return Application.getApp() as TideWatchApp;
}
