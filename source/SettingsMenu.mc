import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;
import Toybox.Time;
import Toybox.Background;

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

        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UpdateLocationTitle) as String, subLabel, "UpdateLocation", {}));

        var tideDatum = Application.Properties.getValue("TideDatum") as Number;
        var datumStr = (tideDatum == 1) ? WatchUi.loadResource(Rez.Strings.DatumMSL) as String : WatchUi.loadResource(Rez.Strings.DatumMLLW) as String;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideDatumTitle) as String, datumStr, "TideDatum", {}));

        var tideUnit = Application.Properties.getValue("TideUnits") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideUnitsTitle) as String, getUnitName(tideUnit), "TideUnits", {}));

        var swellUnit = Application.Properties.getValue("SwellUnits") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SwellUnitsTitle) as String, getUnitName(swellUnit), "SwellUnits", {}));

        var showSwell = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSwellGraphTitle) as String, null, "ShowSwellGraph", showSwell, {}));

        var showDate = Application.Properties.getValue("ShowDate") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowDateTitle) as String, null, "ShowDate", showDate, {}));

        var timeFormat = Application.Properties.getValue("TimeFormat") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TimeFormatTitle) as String, getTimeFormatName(timeFormat), "TimeFormat", {}));

        var baseColor = Application.Properties.getValue("BaseColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.BaseColorTitle) as String, getColorName(baseColor), "BaseColor", {}));

        var tideColor = Application.Properties.getValue("TideColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideColorTitle) as String, getColorName(tideColor), "TideColor", {}));

        var graphColor = Application.Properties.getValue("GraphColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphColorTitle) as String, getColorName(graphColor), "GraphColor", {}));

        var apiKeyStr = "Not Set";
        var apiKey = Application.Properties.getValue("StormglassApiKey");
        if (apiKey != null && apiKey instanceof String && apiKey.length() > 0) {
            apiKeyStr = "Set";
        }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.StormglassApiKeyTitle) as String, apiKeyStr, "StormglassApiKey", {}));
    }

    function getColorName(index as Number) as String {
        var colorStrings = [
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
        if (index >= 0 && index < colorStrings.size()) {
            return WatchUi.loadResource(colorStrings[index]) as String;
        }
        return "Unknown";
    }

    function getUnitName(index as Number) as String {
        if (index == DataKeys.SETTING_UNIT_METERS) {
            return WatchUi.loadResource(Rez.Strings.UnitsMeters) as String;
        } else if (index == DataKeys.SETTING_UNIT_FEET) {
            return WatchUi.loadResource(Rez.Strings.UnitsFeet) as String;
        }
        return "Unknown";
    }

    function getTimeFormatName(index as Number) as String {
        if (index == DataKeys.TIME_FORMAT_24_H) { return WatchUi.loadResource(Rez.Strings.Format24Hour) as String; }
        if (index == DataKeys.TIME_FORMAT_12_H) { return WatchUi.loadResource(Rez.Strings.Format12Hour) as String; }
        return "Unknown";
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
            WatchUi.pushView(new DatumMenu(id, item), new DatumMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("BaseColor") || id.equals("TideColor") || id.equals("GraphColor")) {
            WatchUi.pushView(new ColorMenu(id, item), new ColorMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideUnits") || id.equals("SwellUnits")) {
            WatchUi.pushView(new UnitMenu(id, item), new UnitMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TimeFormat")) {
            WatchUi.pushView(new TimeFormatMenu(id, item), new UnitMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("StormglassApiKey")) {
            item.setSubLabel(WatchUi.loadResource(Rez.Strings.SetInConnectIQ) as String);
            WatchUi.requestUpdate();
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
}

class LocationOptionMenu extends WatchUi.Menu2 {
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.UpdateLocationTitle) as String});
        
        var manualLat = Application.Properties.getValue("GpsLat");
        var manualLon = Application.Properties.getValue("GpsLon");
        var manualSub = "Not Set";
        if (manualLat != null && manualLon != null && !manualLat.equals("") && !manualLon.equals("")) {
            manualSub = (manualLat as String) + ", " + (manualLon as String);
        }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UseManualCoordinates) as String, manualSub, "Manual", {}));
        
        var gpsSub = "No signal";
        var info = Position.getInfo();
        if (info != null && info.position != null) {
            var latLon = info.position.toDegrees();
            gpsSub = latLon[0].format("%.4f") + ", " + latLon[1].format("%.4f");
        }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UseWatchLocation) as String, gpsSub, "Watch", {}));
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
                
                // Invalidate data and refresh
                Application.Storage.setValue("tideData", null);
                Application.Storage.setValue("tideTimes", null);
                Application.Storage.setValue("tideStartTime", null);
                Application.Storage.setValue("tideInterval", null);
                Application.Storage.setValue("tideExtrema", null);
                Application.Storage.setValue("waveData", null);
                Application.Storage.deleteValue("syncError");
                Application.Storage.deleteValue("errorAt");
                Application.Storage.setValue("dataUpdatedAt", 0);

                if (Toybox has :Background) {
                    try { 
                        Background.registerForTemporalEvent(new Time.Duration(1));
                    } catch (e) {
                        // TODO: Handle error.
                    }
                }
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
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.TideDatumTitle) as String});
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.DatumMLLW) as String, null, 0, {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.DatumMSL) as String, null, 1, {}));
    }
}

class DatumMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _propertyId as String;
    private var _parentItem as WatchUi.MenuItem;
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
        _parentItem = parentItem;
    }
    function onSelect(item as WatchUi.MenuItem) as Void {
        Application.Properties.setValue(_propertyId, item.getId() as Number);
        _parentItem.setSubLabel(item.getLabel());
        
        Application.Storage.setValue("dataUpdatedAt", 0); // Invalidate data so it re-syncs
        if (Toybox has :Background) {
            try { Background.registerForTemporalEvent(new Time.Duration(1)); } catch (e) {}
        }
        
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class ColorMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        var titleStr = "";
        if (propertyId.equals("BaseColor")) {
            titleStr = WatchUi.loadResource(Rez.Strings.BaseColorTitle) as String;
        } else if (propertyId.equals("TideColor")) {
            titleStr = WatchUi.loadResource(Rez.Strings.TideColorTitle) as String;
        } else if (propertyId.equals("GraphColor")) {
            titleStr = WatchUi.loadResource(Rez.Strings.GraphColorTitle) as String;
        }
        Menu2.initialize({:title=>titleStr});
        
        var colorStrings = [
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
        
        for (var i = 0; i < colorStrings.size(); i++) {
            var labelStr = WatchUi.loadResource(colorStrings[i]) as String;
            addItem(new WatchUi.MenuItem(labelStr, null, i, {}));
        }
    }
}

class ColorMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _propertyId as String;
    private var _parentItem as WatchUi.MenuItem;
    
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
        _parentItem = parentItem;
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var colorIndex = item.getId() as Number;
        Application.Properties.setValue(_propertyId, colorIndex);
        _parentItem.setSubLabel(item.getLabel());
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class UnitMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        var titleStr = "";
        if (propertyId.equals("TideUnits")) {
            titleStr = WatchUi.loadResource(Rez.Strings.TideUnitsTitle) as String;
        } else if (propertyId.equals("SwellUnits")) {
            titleStr = WatchUi.loadResource(Rez.Strings.SwellUnitsTitle) as String;
        }
        Menu2.initialize({:title=>titleStr});
        
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UnitsMeters) as String, null, DataKeys.SETTING_UNIT_METERS, {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UnitsFeet) as String, null, DataKeys.SETTING_UNIT_FEET, {}));
    }
}

class UnitMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _propertyId as String;
    private var _parentItem as WatchUi.MenuItem;
    
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
        _parentItem = parentItem;
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var unitIndex = item.getId() as Number;
        Application.Properties.setValue(_propertyId, unitIndex);
        _parentItem.setSubLabel(item.getLabel());
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class TimeFormatMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String, parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.TimeFormatTitle) as String});
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Format24Hour) as String, null, DataKeys.TIME_FORMAT_24_H, {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.Format12Hour) as String, null, DataKeys.TIME_FORMAT_12_H, {}));
    }
}
