import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;
import Toybox.Time;
import Toybox.Background;
import Toybox.Application.Storage;
import Toybox.Application.Properties;

class TideWatchSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Settings"});
        
        var spotName = Application.Storage.getValue("spotName");
        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        var subLabel = "";
        if (spotName != null && spotName instanceof String && !spotName.equals("")) {
            subLabel = spotName as String;
        } else if (gpsLat != null && gpsLon != null && gpsLat instanceof String && gpsLon instanceof String && !gpsLat.equals("") && !gpsLon.equals("")) {
            subLabel = gpsLat + ", " + gpsLon;
        }

        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.UpdateLocationTitle), subLabel, "UpdateLocation", {}));

        var tideDatum = Application.Properties.getValue("TideDatum") as Number;
        var datumStr = (tideDatum == 1) ? loadStr(Rez.Strings.DatumMSL) : loadStr(Rez.Strings.DatumMLLW);
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TideDatumTitle), datumStr, "TideDatum", {}));

        var tideUnit = Application.Properties.getValue("TideUnits") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.TideUnitsTitle), getUnitName(tideUnit), "TideUnits", {}));

        var swellUnit = Application.Properties.getValue("SwellUnits") as Number;
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.SwellUnitsTitle), getUnitName(swellUnit), "SwellUnits", {}));

        var showSwell = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(loadStr(Rez.Strings.ShowSwellGraphTitle), null, "ShowSwellGraph", showSwell, {}));

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
        if (apiKey != null && apiKey instanceof String && (apiKey as String).length() > 0) {
            apiKeyStr = "Set";
        }
        addItem(new WatchUi.MenuItem(loadStr(Rez.Strings.StormglassApiKeyTitle), apiKeyStr, "StormglassApiKey", {}));
    }

    static function loadStr(id as ResourceId) as String {
        return WatchUi.loadResource(id) as String;
    }

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

    static function triggerImmediateSync(fullInvalidate as Boolean) as Void {
        if (fullInvalidate) {
            Storage.setValue("tideData", null);
            Storage.setValue("tideTimes", null);
            Storage.setValue("tideStartTime", null);
            Storage.setValue("tideInterval", null);
            Storage.setValue("tideExtrema", null);
            Storage.setValue("waveData", null);
            Storage.deleteValue("syncError");
            Storage.deleteValue("errorAt");
        }
        
        Storage.setValue("dataUpdatedAt", 0);
        
        if (Toybox has :Background) {
            try { 
                Background.registerForTemporalEvent(new Time.Duration(1));
            } catch (e) {
                // Ignore.
            }
        }
    }

    function getColorName(index as Number) as String {
        var colorStrings = getSettingsColorResources();
        if (index >= 0 && index < colorStrings.size()) {
            return loadStr(colorStrings[index]);
        }
        return "Unknown";
    }

    function getUnitName(index as Number) as String {
        if (index == DataKeys.SETTING_UNIT_METERS) {
            return loadStr(Rez.Strings.UnitsMeters);
        } else if (index == DataKeys.SETTING_UNIT_FEET) {
            return loadStr(Rez.Strings.UnitsFeet);
        }
        return "Unknown";
    }

    function getTimeFormatName(index as Number) as String {
        if (index == DataKeys.TIME_FORMAT_24_H) { return loadStr(Rez.Strings.Format24Hour); }
        if (index == DataKeys.TIME_FORMAT_12_H) { return loadStr(Rez.Strings.Format12Hour); }
        return "Unknown";
    }
}

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

class TideWatchSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("UpdateLocation")) {
            WatchUi.pushView(new LocationOptionMenu(item), new LocationOptionMenuDelegate(item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideDatum")) {
            WatchUi.pushView(new DatumMenu(id, item), new PropertyMenuDelegate(id, item, true), WatchUi.SLIDE_LEFT);
        } else if (id.equals("BaseColor") || id.equals("TideColor") || id.equals("GraphColor")) {
            WatchUi.pushView(new ColorMenu(id, item), new PropertyMenuDelegate(id, item, false), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideUnits") || id.equals("SwellUnits")) {
            WatchUi.pushView(new UnitMenu(id, item), new PropertyMenuDelegate(id, item, true), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TimeFormat")) {
            WatchUi.pushView(new TimeFormatMenu(id, item), new PropertyMenuDelegate(id, item, false), WatchUi.SLIDE_LEFT);
        } else if (id.equals("StormglassApiKey")) {
            item.setSubLabel(TideWatchSettingsMenu.loadStr(Rez.Strings.SetInConnectIQ));
            WatchUi.requestUpdate();
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
}

class LocationOptionMenu extends WatchUi.Menu2 {
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>TideWatchSettingsMenu.loadStr(Rez.Strings.UpdateLocationTitle)});
        
        var manualLat = Application.Properties.getValue("GpsLat");
        var manualLon = Application.Properties.getValue("GpsLon");
        var manualSub = "Not Set";
        if (manualLat != null && manualLon != null && (manualLat as String).length() > 0 && (manualLon as String).length() > 0) {
            manualSub = (manualLat as String) + ", " + (manualLon as String);
        }
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UseManualCoordinates), manualSub, "Manual", {}));
        
        var gpsSub = "No signal";
        var info = Position.getInfo();
        if (info != null && info.position != null) {
            var latLon = info.position.toDegrees();
            gpsSub = latLon[0].format("%.4f") + ", " + latLon[1].format("%.4f");
        }
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.UseWatchLocation), gpsSub, "Watch", {}));
    }
}

class LocationOptionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _parentItem as WatchUi.MenuItem;
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }
    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId().equals("Manual")) {
            item.setSubLabel(WatchUi.loadResource(Rez.Strings.SetInConnectIQ) as String);
            WatchUi.requestUpdate();
        } else if (item.getId().equals("Watch")) {
            var info = Position.getInfo();
            if (info != null && info.position != null) {
                var latLon = info.position.toDegrees();
                var lat = latLon[0].format("%.4f");
                var lon = latLon[1].format("%.4f");
                Application.Properties.setValue("GpsLat", lat);
                Application.Properties.setValue("GpsLon", lon);
                Application.Storage.deleteValue("spotName");
                _parentItem.setSubLabel(lat + ", " + lon);
                
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
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumMLLW), null, 0, {}));
        addItem(new WatchUi.MenuItem(TideWatchSettingsMenu.loadStr(Rez.Strings.DatumMSL), null, 1, {}));
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
