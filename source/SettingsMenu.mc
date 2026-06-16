import Toybox.Activity;
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Background;
import Toybox.Application.Storage;
import Toybox.Application.Properties;

class TideWatchSettingsMenu extends WatchUi.Menu2 {
    /**
     * Initializes the settings menu with all available options.
     * Loads labels and current values from properties and storage.
     */
    function initialize() {
        Menu2.initialize({:title=>"Settings"});
        
        var spotName = AppStorage.getSpotName();
        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        var subLabel = "";
        if (spotName != null && !spotName.equals("")) {
            subLabel = spotName;
        } else if ((gpsLat instanceof Float || gpsLat instanceof Double) && (gpsLon instanceof Float || gpsLon instanceof Double)) {
            subLabel = gpsLat.format("%.4f") + ", " + gpsLon.format("%.4f");
        }

        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.UpdateLocationTitle), subLabel, "UpdateLocation", {}));

        var tideDatum = Application.Properties.getValue("TideDatum") as Number;
        var datumStr = "";
        if (tideDatum == DataKeys.DATUM_MSL) { datumStr = loadStr(Rez.Strings.DatumMSL); }
        else if (tideDatum == DataKeys.DATUM_MLLW) { datumStr = loadStr(Rez.Strings.DatumMLLW); }
        else if (tideDatum == DataKeys.DATUM_LAT) { datumStr = loadStr(Rez.Strings.DatumLAT); }
        else { datumStr = loadStr(Rez.Strings.DatumStationDefault); }
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TideDatumTitle), datumStr, "TideDatum", {}));

        var tideUnit = Application.Properties.getValue("TideUnits") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TideUnitsTitle), getUnitName(tideUnit), "TideUnits", {}));

        var swellUnit = Application.Properties.getValue("SwellUnits") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.SwellUnitsTitle), getUnitName(swellUnit), "SwellUnits", {}));

        var showSwell = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(loadStr(Rez.Strings.ShowSwellGraphTitle), null, "ShowSwellGraph", showSwell, {}));

        var showSummary = Application.Properties.getValue("ShowSwellSummary") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(loadStr(Rez.Strings.ShowSwellSummaryTitle), null, "ShowSwellSummary", showSummary, {}));

        var showDate = Application.Properties.getValue("ShowDate") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(loadStr(Rez.Strings.ShowDateTitle), null, "ShowDate", showDate, {}));

        var timeFormat = Application.Properties.getValue("TimeFormat") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TimeFormatTitle), getTimeFormatName(timeFormat), "TimeFormat", {}));

        var baseColor = Application.Properties.getValue("BaseColor") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.BaseColorTitle), getColorName(baseColor), "BaseColor", {}));

        var tideColor = Application.Properties.getValue("TideColor") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TideColorTitle), getColorName(tideColor), "TideColor", {}));

        var graphColor = Application.Properties.getValue("GraphColor") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.GraphColorTitle), getColorName(graphColor), "GraphColor", {}));

        var apiKeyStr = "Not Set";
        var apiKey = Application.Properties.getValue("StormglassApiKey");
        if (apiKey instanceof String && (apiKey as String).length() > 0) {
            apiKeyStr = "Set";
        }
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.StormglassApiKeyTitle), apiKeyStr, "StormglassApiKey", {}));
        
        // addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.ExperimentsTitle), "", "Experiments", {}));
        
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.SyncTitle), "", "ForceSync", {}));
        
        addItem(new WatchUi.MenuItem("About", "", "About", {}));
    }

    /**
     * Helper to load a string resource.
     * @param id The ResourceId of the string to load.
     * @return The loaded string.
     */
    static function loadStr(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

    /**
     * Returns an array of ResourceIds for the color setting names.
     * Used to populate the color selection menu.
     */
    static function getSettingsColorResources() as Array<ResourceId> {
        return [
            Rez.Strings.ColorBlue,
            Rez.Strings.ColorPink,
            Rez.Strings.ColorRed,
            Rez.Strings.ColorGreen,
            Rez.Strings.ColorWhite,
            Rez.Strings.ColorYellow,
            Rez.Strings.ColorOrange,
            Rez.Strings.ColorPurple,
            Rez.Strings.ColorLtGray,
            Rez.Strings.ColorDkGray,
            Rez.Strings.ColorLightBlue,
            Rez.Strings.ColorPetrol,
            Rez.Strings.ColorTurquoise
        ];
    }

    /**
     * Triggers an immediate background sync by registering a temporal event.
     * @param fullInvalidate If true, clears cached tide and wave data before syncing.
     */
    static function triggerImmediateSync(fullInvalidate as Boolean) as Void {
        if (fullInvalidate) {
            AppStorage.clearCache();
        } else {
            // Always delete these to force the background task to perform a fresh network sync
            AppStorage.clearGeocodeUpdatedAt();
            AppStorage.clearWeatherUpdatedAt();
            AppStorage.clearTideTimelineUpdatedAt();
            AppStorage.clearTideExtremesUpdatedAt();
            AppStorage.setDataUpdatedAt(0);
        }
        
        scheduleNextBackgroundEvent(null);
    }

    /**
     * Gets the display name for a color at a given index.
     * @param index The color index.
     * @return The localized name of the color.
     */
    function getColorName(index as Number) as String {
        var colorStrings = getSettingsColorResources();
        if (index >= 0 && index < colorStrings.size()) {
            return loadStr(colorStrings[index]);
        }
        return "Unknown";
    }

    /**
     * Gets the display name for a unit setting (Metric vs Imperial).
     * @param index The unit setting index.
     * @return The localized unit name.
     */
    function getUnitName(index as Number) as String {
        if (index == DataKeys.SETTING_UNIT_METERS) {
            return loadStr(Rez.Strings.UnitsMeters);
        } else if (index == DataKeys.SETTING_UNIT_FEET) {
            return loadStr(Rez.Strings.UnitsFeet);
        }
        return "Unknown";
    }

    /**
     * Gets the display name for a time format setting (24h vs 12h).
     * @param index The time format index.
     * @return The localized format name.
     */
    function getTimeFormatName(index as Number) as String {
        if (index == DataKeys.TIME_FORMAT_24_H) { return loadStr(Rez.Strings.Format24Hour); }
        if (index == DataKeys.TIME_FORMAT_12_H) { return loadStr(Rez.Strings.Format12Hour); }
        return "Unknown";
    }
}

/**
 * A generic delegate for sub-menus that simply set a property value.
 */
class PropertyMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _propertyId as String;
    private var _parentItem as WatchUi.MenuItem;
    private var _needsSync as Boolean;
    
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem, needsSync as Boolean) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
        _parentItem = parentItem;
        _needsSync = needsSync;
    }
    
    /**
     * Handles item selection in a property sub-menu.
     * Sets the property, updates the parent menu label, and optionally triggers sync.
     */
    function onSelect(item as WatchUi.MenuItem) as Void {
        var value = item.getId();
        if (value instanceof Number) {
            Application.Properties.setValue(_propertyId, value);
        } else if (value instanceof String) {
            Application.Properties.setValue(_propertyId, value);
        }
        
        _parentItem.setSubLabel(item.getLabel());
        
        if (_needsSync) {
            TideWatchSettingsMenu.triggerImmediateSync(false);
        }
        
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

/**
 * Main input delegate for the settings menu.
 * Handles navigation to sub-menus or toggling simple boolean settings.
 */
class TideWatchSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    /**
     * Handles selection of a menu item in the main settings menu.
     */
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("UpdateLocation")) {
            WatchUi.pushView(new LocationOptionMenu(item), new LocationOptionMenuDelegate(item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideDatum")) {
            WatchUi.pushView(new DatumMenu(id, item), new PropertyMenuDelegate(id, item, true), WatchUi.SLIDE_LEFT);
        } else if (id.equals("BaseColor") || id.equals("TideColor") || id.equals("GraphColor")) {
            WatchUi.pushView(new ColorMenu(id, item), new PropertyMenuDelegate(id, item, false), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideUnits") || id.equals("SwellUnits")) {
            WatchUi.pushView(new UnitMenu(id, item), new PropertyMenuDelegate(id, item, false), WatchUi.SLIDE_LEFT);
        } else if (id.equals("ShowSwellSummary")) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
            TideWatchSettingsMenu.triggerImmediateSync(false);
        } else if (id.equals("TimeFormat")) {
            WatchUi.pushView(new TimeFormatMenu(id, item), new PropertyMenuDelegate(id, item, false), WatchUi.SLIDE_LEFT);
        } else if (id.equals("StormglassApiKey")) {
            item.setSubLabel(TideWatchSettingsMenu.loadStr(Rez.Strings.SetInConnectIQ));
            WatchUi.requestUpdate();
        } else if (id.equals("ForceSync")) {
            item.setSubLabel(TideWatchSettingsMenu.loadStr(Rez.Strings.SyncExecuting));
            TideWatchSettingsMenu.triggerImmediateSync(false);
            WatchUi.requestUpdate();
        // } else if (id.equals("Experiments")) {
        //     WatchUi.pushView(new ExperimentsMenu(), new ExperimentsMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("About")) {
            WatchUi.pushView(new AboutMenu(), new AboutMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
}

/**
 * Sub-menu for choosing location update method.
 */
class LocationOptionMenu extends WatchUi.Menu2 {
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>TideWatchSettingsMenu.loadStr(Rez.Strings.UpdateLocationTitle)});
        
        var manualLat = Application.Properties.getValue("GpsLat");
        var manualLon = Application.Properties.getValue("GpsLon");
        var manualSub = "Not Set";
        if ((manualLat instanceof Float || manualLat instanceof Double) && (manualLon instanceof Float || manualLon instanceof Double)) {
            manualSub = manualLat.format("%.4f") + ", " + manualLon.format("%.4f");
        }
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UseManualCoordinates), manualSub, "Manual", {}));
        
        var gpsSub = "No signal";
        var info = Activity.getActivityInfo();
        if (info != null && info.currentLocation != null) {
            var latLon = info.currentLocation.toDegrees();
            gpsSub = latLon[0].format("%.4f") + ", " + latLon[1].format("%.4f");
        }
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UseWatchLocation), gpsSub, "Watch", {}));
    }
}

/**
 * Delegate for the location option menu.
 */
class LocationOptionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _parentItem as WatchUi.MenuItem;
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }
    
    /**
     * Handles location selection. 
     * If 'Watch' is chosen, it attempts to get current GPS coordinates.
     */
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId().equals("Manual")) {
            item.setSubLabel(WatchUi.loadResource(Rez.Strings.SetInConnectIQ) as String);
            WatchUi.requestUpdate();
        } else if (item.getId().equals("Watch")) {
            var info = Activity.getActivityInfo();
            if (info != null && info.currentLocation != null) {
                var latLon = info.currentLocation.toDegrees();
                var lat = latLon[0].toFloat();
                var lon = latLon[1].toFloat();
                Application.Properties.setValue("GpsLat", lat);
                Application.Properties.setValue("GpsLon", lon);
                AppStorage.clearSpotName();
                _parentItem.setSubLabel(lat.format("%.4f") + ", " + lon.format("%.4f"));
                
                TideWatchSettingsMenu.triggerImmediateSync(true);
                WatchUi.popView(WatchUi.SLIDE_RIGHT);
            } else {
                item.setSubLabel("No signal");
                WatchUi.requestUpdate();
            }
        }
    }
}

class DatumMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>TideWatchSettingsMenu.loadStr(Rez.Strings.TideDatumTitle)});
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumStationDefault), null, DataKeys.DATUM_STATION_DEFAULT, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumMSL), null, DataKeys.DATUM_MSL, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumMLLW), null, DataKeys.DATUM_MLLW, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumLAT), null, DataKeys.DATUM_LAT, {}));
    }
}

class ColorMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        var titleStr = "";
        if (propertyId.equals("BaseColor")) {
            titleStr = TideWatchSettingsMenu.loadStr(Rez.Strings.BaseColorTitle);
        } else if (propertyId.equals("TideColor")) {
            titleStr = TideWatchSettingsMenu.loadStr(Rez.Strings.TideColorTitle);
        } else if (propertyId.equals("GraphColor")) {
            titleStr = TideWatchSettingsMenu.loadStr(Rez.Strings.GraphColorTitle);
        }
        Menu2.initialize({:title=>titleStr});
        
        var colorStrings = TideWatchSettingsMenu.getSettingsColorResources();
        
        for (var i = 0; i < colorStrings.size(); i++) {
            var labelStr = TideWatchSettingsMenu.loadStr(colorStrings[i]);
            addItem(new WatchUi.MenuItem(labelStr, null, i, {}));
        }
    }
}

class UnitMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        var titleStr = "";
        if (propertyId.equals("TideUnits")) {
            titleStr = TideWatchSettingsMenu.loadStr(Rez.Strings.TideUnitsTitle);
        } else if (propertyId.equals("SwellUnits")) {
            titleStr = TideWatchSettingsMenu.loadStr(Rez.Strings.SwellUnitsTitle);
        }
        Menu2.initialize({:title=>titleStr});
        
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UnitsMeters), null, DataKeys.SETTING_UNIT_METERS, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UnitsFeet), null, DataKeys.SETTING_UNIT_FEET, {}));
    }
}

class TimeFormatMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>TideWatchSettingsMenu.loadStr(Rez.Strings.TimeFormatTitle)});
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.Format24Hour), null, DataKeys.TIME_FORMAT_24_H, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.Format12Hour), null, DataKeys.TIME_FORMAT_12_H, {}));
    }
}

/*
class ExperimentsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>TideWatchSettingsMenu.loadStr(Rez.Strings.ExperimentsTitle)});
        var enableKPay = Application.Properties.getValue("EnableKPay") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.EnableKPayTitle), null, "EnableKPay", enableKPay, {}));
    }
}

class ExperimentsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("EnableKPay")) {
            var val = (item as WatchUi.ToggleMenuItem).isEnabled();
            Application.Properties.setValue(id, val);
            (Application.getApp() as TideWatchApp).onSettingsChanged();
        }
    }
}
*/

class AboutMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"About"});
        
        var lastSyncStr = formatTime(AppStorage.getDataUpdatedAt(), "Never");
        var nextSyncStr = formatTime(AppStorage.getNextSyncTime(), "None");
        
        var stationName = AppStorage.getTideStationName();
        var stationCountry = AppStorage.getTideStationCountry();
        var stationStr = "Unknown";
        if (stationName != null && !stationName.equals("")) {
            if (stationCountry != null && !stationCountry.equals("")) {
                stationStr = stationName + ", " + stationCountry;
            } else {
                stationStr = stationName;
            }
        }
        
        addItem(new WatchUi.MenuItem("Version", Version.STRING, "version", {}));
        addItem(new WatchUi.MenuItem("Last Sync", lastSyncStr, "sync", {}));
        addItem(new WatchUi.MenuItem("Next Sync", nextSyncStr, "next_sync", {}));
        addItem(new WatchUi.MenuItem("Station", stationStr, "station", {}));
        addItem(new WatchUi.MenuItem("openwaters.io", "used for tide data", "ow", {}));
        addItem(new WatchUi.MenuItem("stormglass.io", "used for weather data", "stormglass", {}));
        addItem(new WatchUi.MenuItem("bigdatacloud.com", "used for geo data", "bigdatacloud", {}));
    }

    function formatTime(timestamp as Number, defaultStr as String) as String {
        if (timestamp <= 0) {
            return defaultStr;
        }
        var info = Gregorian.info(new Time.Moment(timestamp), Time.FORMAT_SHORT);
        var use24Hour = System.getDeviceSettings().is24Hour;
        var hour = info.hour;
        var amPm = "";
        if (!use24Hour) {
            if (hour >= 12) {
                amPm = " PM";
                if (hour > 12) {
                    hour -= 12;
                }
            } else {
                amPm = " AM";
                if (hour == 0) {
                    hour = 12;
                }
            }
        }
        return Lang.format("$1$-$2$-$3$ $4$:$5$$6$", [
            info.year,
            info.month.format("%02d"),
            info.day.format("%02d"),
            hour.format(use24Hour ? "%02d" : "%d"),
            info.min.format("%02d"),
            amPm
        ]);
    }
}

class AboutMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        // Read-only menu, do nothing on selection
    }
}
