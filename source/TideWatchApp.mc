import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
using KPayClock.KPay as KPay;

(:background)
var foregroundAppDelegate = null;

(:background)
class TideWatchApp extends Application.AppBase {

    /**
     * Constructor. Initializes the parent AppBase.
     */
    (:background)
    function initialize() {
        AppBase.initialize();
    }

    /**
     * Lifecycle callback when the app stops.
     */
    function onStop(state as Dictionary?) as Void {
        if (foregroundAppDelegate != null && foregroundAppDelegate has :onStop) {
            foregroundAppDelegate.onStop(state);
        }
    }

    /**
     * Lifecycle callback triggered when user settings are changed in Connect IQ.
     */
    function onSettingsChanged() {
        if (foregroundAppDelegate != null && foregroundAppDelegate has :onSettingsChanged) {
            foregroundAppDelegate.onSettingsChanged();
        }
    }

    /**
     * Initializer for the first view of the application.
     */
    function getInitialView() {
        // Store AppId for background service since Rez isn't accessible there
        AppStorage.setAppId(WatchUi.loadResource(Rez.Strings.AppId) as String);

        if (System has :ServiceDelegate) {
           scheduleNextBackgroundEvent(null);
        }
        return [ new TideWatchView() ] as [WatchUi.Views];
    }

    /**
     * Handles data returned by the background service delegate.
     */
    function onBackgroundData(data as Application.PersistableType) as Void {
        if (foregroundAppDelegate != null && foregroundAppDelegate has :onBackgroundData) {
            foregroundAppDelegate.onBackgroundData(data);
        }
    }

    /**
     * Gets the background service delegate instance to execute scheduled events.
     */
    (:background)
    function getServiceDelegate() {
        var enableKPay = true;
        if (enableKPay) {
            return [ new KPay.KPayBackgroundServiceDelegate(TideWatchBackground, 0) ] as [System.ServiceDelegate];
        } else {
            return [ new TideWatchBackground(null) ] as [System.ServiceDelegate];
        }
    }

    /**
     * Retrieves the settings menu views and delegates.
     */
    function getSettingsView() {
        if (foregroundAppDelegate != null && foregroundAppDelegate has :getSettingsView) {
            return foregroundAppDelegate.getSettingsView();
        }
        return null;
    }
}

/**
 * Registers/schedules the next background temporal event.
 */
(:background)
function scheduleNextBackgroundEvent(earliestTime as Time.Moment?) as Void {
    if (Toybox has :Background) {
        try { 
            var lastTime = Background.getLastTemporalEventTime();
            var nextTime = Time.now();

            if (earliestTime != null && earliestTime.value() > nextTime.value()) {
                nextTime = earliestTime;
            }

            if (lastTime != null) {
                var lastPlus5 = lastTime.add(new Time.Duration(5 * 60));
                if (lastPlus5.value() > nextTime.value()) {
                    nextTime = lastPlus5;
                }
            }
            
            // var info = Gregorian.info(nextTime, Time.FORMAT_SHORT);
            // System.println(Lang.format("Scheduling background event for: $1$-$2$-$3$ $4$:$5$:$6$", [
            //     info.year,
            //     info.month.format("%02d"),
            //     info.day.format("%02d"),
            //     info.hour.format("%02d"),
            //     info.min.format("%02d"),
            //     info.sec.format("%02d")
            // ]));
            
            Background.registerForTemporalEvent(nextTime);
            Application.Storage.setValue("nextSyncTime", nextTime.value());
        } catch (e) {
            System.println("ERROR: Background registration failed: " + e.getErrorMessage()); 
        }
    } else {
        System.println("ERROR: Background not available"); 
    }
}

