import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Position;

class TideWatchSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>"Settings"});
        
        var spotId = Application.Properties.getValue("SpotId");
        var subLabel = spotId != null ? spotId as String : "Unknown";
        var cachedSpots = Application.Storage.getValue("NearbySpots");
        if (cachedSpots != null && cachedSpots instanceof Array) {
            for (var i = 0; i < cachedSpots.size(); i++) {
                var item = cachedSpots[i];
                if (item instanceof Array && item.size() >= 2) {
                    if (item[1].equals(spotId)) {
                        subLabel = item[0] as String;
                        break;
                    }
                }
            }
        }
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SurfSpotTitle) as String, subLabel, "SurfSpot", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideUnitsTitle) as String, null, "TideUnits", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SwellUnitsTitle) as String, null, "SwellUnits", {}));

        var showSwell = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowSwellGraphTitle) as String, null, "ShowSwellGraph", showSwell, {}));

        var showDate = Application.Properties.getValue("ShowDate") as Boolean;
        addItem(new WatchUi.ToggleMenuItem(WatchUi.loadResource(Rez.Strings.ShowDateTitle) as String, null, "ShowDate", showDate, {}));

        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.BaseColorTitle) as String, null, "BaseColor", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.TideColorTitle) as String, null, "TideColor", {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.GraphColorTitle) as String, null, "GraphColor", {}));
    }
}

class TideWatchSettingsMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("SurfSpot")) {
            WatchUi.pushView(new SpotOptionMenu(), new SpotOptionMenuDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("BaseColor") || id.equals("TideColor") || id.equals("GraphColor")) {
            WatchUi.pushView(new ColorMenu(id), new ColorMenuDelegate(id), WatchUi.SLIDE_LEFT);
        } else if (id.equals("TideUnits") || id.equals("SwellUnits")) {
            WatchUi.pushView(new UnitMenu(id), new UnitMenuDelegate(id), WatchUi.SLIDE_LEFT);
        } else if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(id, (item as WatchUi.ToggleMenuItem).isEnabled());
        }
    }
}

class ColorMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String) {
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
    
    function initialize(propertyId as String) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var colorIndex = item.getId() as Number;
        Application.Properties.setValue(_propertyId, colorIndex);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class UnitMenu extends WatchUi.Menu2 {
    function initialize(propertyId as String) {
        var titleStr = "";
        if (propertyId.equals("TideUnits")) {
            titleStr = WatchUi.loadResource(Rez.Strings.TideUnitsTitle) as String;
        } else if (propertyId.equals("SwellUnits")) {
            titleStr = WatchUi.loadResource(Rez.Strings.SwellUnitsTitle) as String;
        }
        Menu2.initialize({:title=>titleStr});
        
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UnitsMeters) as String, null, 0, {}));
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UnitsFeet) as String, null, 1, {}));
    }
}

class UnitMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _propertyId as String;
    
    function initialize(propertyId as String) {
        Menu2InputDelegate.initialize();
        _propertyId = propertyId;
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var unitIndex = item.getId() as Number;
        Application.Properties.setValue(_propertyId, unitIndex);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class SpotOptionMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.SurfSpotTitle) as String});
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.SelectFromList) as String, null, "SelectFromList", {}));
        
        var spotId = Application.Properties.getValue("SpotId");
        var spotIdStr = spotId != null ? spotId as String : "";
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.EnterSpotIdMenuItem) as String, spotIdStr, "EnterSpotId", {}));
        
        var gpsStr = Application.Properties.getValue("GpsCoordinates");
        var gpsLabel = gpsStr != null ? gpsStr as String : "";
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.EnterCoordinatesMenuItem) as String, gpsLabel, "EnterCoordinates", {}));
    }
}

class SpotOptionMenuDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("SelectFromList")) {
            WatchUi.pushView(new NearbySpotMenu(), new NearbySpotDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id.equals("EnterSpotId")) {
            item.setSubLabel("Use Phone App");
            WatchUi.requestUpdate();
        } else if (id.equals("EnterCoordinates")) {
            WatchUi.pushView(new GpsOptionMenu(), new GpsOptionDelegate(), WatchUi.SLIDE_LEFT);
        }
    }
}

class NearbySpotMenu extends WatchUi.Menu2 {
    function initialize() {
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
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var selectedId = item.getId() as String;
        if (selectedId.equals("None")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }
        
        Application.Properties.setValue("SpotId", selectedId);
        Application.Properties.setValue("LocationMode", 0); // Spot ID Mode
        
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }
}

class GpsOptionMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title=>WatchUi.loadResource(Rez.Strings.EnterCoordinatesMenuItem) as String});
        addItem(new WatchUi.MenuItem(WatchUi.loadResource(Rez.Strings.UseWatchGps) as String, null, "UseWatchGps", {}));
        addItem(new WatchUi.MenuItem("Set via Phone App", null, "UsePhone", {}));
    }
}

class GpsOptionDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as String;
        if (id.equals("UseWatchGps")) {
            var posInfo = Position.getInfo();
            if (posInfo != null && posInfo.position != null) {
                var latLon = posInfo.position.toDegrees();
                var coordsStr = latLon[0].format("%.4f") + "," + latLon[1].format("%.4f");
                Application.Properties.setValue("GpsCoordinates", coordsStr);
                Application.Properties.setValue("LocationMode", 1); // GPS Mode
                item.setSubLabel("Saved: " + coordsStr);
            } else {
                item.setSubLabel("No GPS Fix");
            }
            WatchUi.requestUpdate();
        } else if (id.equals("UsePhone")) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
}
