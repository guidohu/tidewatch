import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;

class TideWatchSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Settings"});
        
        var spotId = Application.Properties.getValue("SpotId");
        if (spotId == null || spotId.equals("")) {
            spotId = Application.Storage.getValue("spotId");
        }
        
        var subLabel = Application.Properties.getValue("SpotName");
        if (subLabel == null || subLabel.equals("")) {
            subLabel = Application.Storage.getValue("spotName");
        }
        
        if (subLabel == null || subLabel.equals("")) {
            subLabel = (spotId != null && !spotId.equals("")) ? spotId as String : "None Selected";
        }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SurfSpotTitle) as String, subLabel as String, "SurfSpot", {}));

        var tideUnit = Application.Properties.getValue("TideUnits") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideUnitsTitle) as String, getUnitName(tideUnit), "TideUnits", {}));

        var swellUnit = Application.Properties.getValue("SwellUnits") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SwellUnitsTitle) as String, getUnitName(swellUnit), "SwellUnits", {}));

        var showSwell = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSwellGraphTitle) as String, null, "ShowSwellGraph", showSwell, {}));

        var showDate = Application.Properties.getValue("ShowDate") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowDateTitle) as String, null, "ShowDate", showDate, {}));

        var timeFormat = Application.Properties.getValue("TimeFormat");
        if (timeFormat == null) { timeFormat = 0; }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TimeFormatTitle) as String, getTimeFormatName(timeFormat as Number), "TimeFormat", {}));

        var baseColor = Application.Properties.getValue("BaseColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.BaseColorTitle) as String, getColorName(baseColor), "BaseColor", {}));

        var tideColor = Application.Properties.getValue("TideColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideColorTitle) as String, getColorName(tideColor), "TideColor", {}));

        var graphColor = Application.Properties.getValue("GraphColor") as Number;
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphColorTitle) as String, getColorName(graphColor), "GraphColor", {}));
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
        if (id.equals("SurfSpot")) {
            WatchUi.pushView(new SpotOptionMenu(item), new SpotOptionMenuDelegate(item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("BaseColor") || id.equals("TideColor") || id.equals("GraphColor")) {
            WatchUi.pushView(new ColorMenu(id, item), new ColorMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideUnits") || id.equals("SwellUnits")) {
            WatchUi.pushView(new UnitMenu(id, item), new UnitMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TimeFormat")) {
            WatchUi.pushView(new TimeFormatMenu(id, item), new UnitMenuDelegate(id, item), WatchUi.SLIDE_LEFT);
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
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

class SpotOptionMenu extends WatchUi.Menu2 {
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.SurfSpotTitle) as String});
        
        var gpsStr = Application.Properties.getValue("GpsCoordinates");
        var hasCoords = (gpsStr != null && gpsStr instanceof String && gpsStr.length() > 0);
        
        if (hasCoords) {
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SearchCustomCoordinates) as String, gpsStr as String, "SearchSpots", {}));
        } else {
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SearchWatchGps) as String, null, "SearchSpots", {}));
        }
        
        var spotId = Application.Properties.getValue("SpotId");
        if (spotId == null || spotId.equals("")) {
            spotId = Application.Storage.getValue("spotId");
        }
        var spotIdStr = spotId != null ? spotId as String : "";
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.EnterSpotIdMenuItem) as String, spotIdStr, "EnterSpotId", {}));
    }
}

class SpotOptionMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _parentItem as WatchUi.MenuItem;
    
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("SearchSpots")) {
            WatchUi.pushView(new NearbySpotMenu(_parentItem), new NearbySpotDelegate(_parentItem), WatchUi.SLIDE_LEFT);
        } else if (id.equals("EnterSpotId")) {
            item.setSubLabel("Use Phone App");
            WatchUi.requestUpdate();
        }
    }
}

class NearbySpotMenu extends WatchUi.Menu2 {
    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.SelectFromList) as String});
        var spots = Application.Storage.getValue("NearbySpots");
        
        if (spots != null && spots instanceof Array && spots.size() > 0) {
            for (var i = 0; i < spots.size(); i++) {
                var sp = spots[i];
                if (sp instanceof Array && sp.size() >= 2) {
                    var name = sp[0] as String;
                    var spotId = sp[1] as String;
                    addItem(new WatchUi.MenuItem(name, null, spotId, {}));
                }
            }
        } else {
            addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.NoSpotsFound) as String, null, "None", {}));
        }
    }
}

class NearbySpotDelegate extends WatchUi.Menu2InputDelegate {
    private var _parentItem as WatchUi.MenuItem;

    function initialize(parentItem as WatchUi.MenuItem) {
        Menu2InputDelegate.initialize();
        _parentItem = parentItem;
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var selectedId = item.getId() as String;
        var selectedName = item.getLabel(); // Get the name from the menu item

        if (selectedId.equals("None")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        
        System.println("Set SpotId to " + selectedId + " (" + selectedName + ")");
        Application.Properties.setValue("SpotId", selectedId);
        Application.Properties.setValue("SpotName", selectedName);
        Application.Storage.setValue("lastSpotId", selectedId);

        // Update spotName immediately so main view knows what to show.
        Application.Storage.setValue("spotName", selectedName);
        Application.Storage.setValue("spotId", selectedId);
        _parentItem.setSubLabel(selectedName);

        // Invalidate current data. This will trigger "Waiting for sync..." on main view.
        Application.Storage.setValue("tideData", null);
        Application.Storage.setValue("tideTimes", null);
        Application.Storage.setValue("tideStartTime", null);
        Application.Storage.setValue("tideInterval", null);
        Application.Storage.setValue("tideExtrema", null);
        Application.Storage.setValue("waveData", null);
        Application.Storage.deleteValue("syncError");
        Application.Storage.deleteValue("errorAt");
        Application.Storage.setValue("dataUpdatedAt", 0);

        // Trigger an immediate background sync for the new spot.
        if (Toybox has :Background) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(1));
            } catch (e) {
                System.println("Background error: " + e.getErrorMessage());
            }
        }
        
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }
}
