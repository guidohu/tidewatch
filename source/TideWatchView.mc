import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class TideWatchView extends WatchUi.WatchFace {

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        
        var tideColorIdx = Application.Properties.getValue("TideColor");
        var graphColorIdx = Application.Properties.getValue("GraphColor");

        var tideColor = getColorFromIndex(tideColorIdx);
        var graphColor = getColorFromIndex(graphColorIdx);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var scale = width / 416.0;

        // 1. Draw Time
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.24, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw Battery
        var stats = System.getSystemStats();
        drawBattery(dc, width / 2, (height * 0.08).toNumber(), stats.battery);

        // 2. Fetch and parse Tide info
        var tideData = Application.Storage.getValue("tideData");
        var waveData = Application.Storage.getValue("waveData");
        var tideError = Application.Storage.getValue("tideError");
        
        if (tideData == null || !(tideData instanceof Array) || tideData.size() == 0) {
            dc.setColor(tideError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            var msg = tideError != null ? "Tide Sync Error: " + tideError : "No Tide Data\nWaiting for sync...";
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Time.now().value() returns the Unix timestamp directly
        var now = Time.now().value();
        System.println("onUpdate: now=" + now + " tideData size=" + tideData.size());
        if (tideData.size() > 0) {
            System.println("First tide item ts: " + (tideData[0] as Dictionary).get("t"));
            System.println("Last tide item ts: " + (tideData[tideData.size()-1] as Dictionary).get("t"));
        }
        
        var currentTide = null;
        var nextTide = null;
        var nextExtrema = null;

        for (var i = 0; i < tideData.size() - 1; i++) {
            var t1 = tideData[i] as Dictionary;
            var t2 = tideData[i+1] as Dictionary;
            var ts1 = t1.get("t") as Number;
            var ts2 = t2.get("t") as Number;
            
            if (ts1 == null || ts2 == null) {
                // Handle old data or mismatch - clear it and exit to prevent crash
                Application.Storage.deleteValue("tideData");
                return;
            }

            if (now >= ts1 && now <= ts2) {
                currentTide = t1;
                nextTide = t2;
                // find next extrema starting from here
                for (var j = i; j < tideData.size(); j++) {
                    var tj = tideData[j] as Dictionary;
                    var type = tj.get("y") as String;
                    if (tj.get("t") as Number > now && (type.equals("HIGH") || type.equals("LOW"))) {
                        nextExtrema = tj;
                        break;
                    }
                }
                break;
            }
        }
        
        if (currentTide == null || nextTide == null) {
            System.println("Failed to find current/next tide for now=" + now);
        }

        if (currentTide != null && nextTide != null) {
            var h1Val = currentTide.get("v");
            var h2Val = nextTide.get("v");
            var h1 = (h1Val instanceof Number) ? h1Val.toFloat() : h1Val as Float;
            var h2 = (h2Val instanceof Number) ? h2Val.toFloat() : h2Val as Float;
            
            var ts1 = currentTide.get("t") as Number;
            var ts2 = nextTide.get("t") as Number;
            
            // Interpolate
            var progress = (now - ts1).toFloat() / (ts2 - ts1).toFloat();
            var currentHeight = h1 + (h2 - h1) * progress;
            var isRising = h2 > h1;

            var dispHeight = currentHeight;
            var dispUnit = "m";
            if (tideUnits == 1) {
                dispHeight = currentHeight * 3.28084;
                dispUnit = "ft";
            }

            var tideNumStr = dispHeight.format("%.2f");
            var numWidth = dc.getTextWidthInPixels(tideNumStr, Graphics.FONT_NUMBER_MEDIUM);
            var mWidth = dc.getTextWidthInPixels(dispUnit, Graphics.FONT_MEDIUM);
            var totalWidth = numWidth + mWidth;
            var startX = width / 2 - totalWidth / 2;

            // Center everything nicely
            // Tide Height
            dc.setColor(tideColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX, height * 0.44, Graphics.FONT_NUMBER_MEDIUM, tideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + numWidth, height * 0.44, Graphics.FONT_MEDIUM, dispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

            // Draw arrow next to tide
            var arrowX = startX + totalWidth + (15 * scale).toNumber();
            var arrowY = height * 0.44;
            dc.setColor(isRising ? Graphics.COLOR_GREEN : Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            drawArrow(dc, arrowX.toNumber(), arrowY.toNumber(), isRising);

            // Draw next extrema
            if (nextExtrema != null) {
                var extHVal = nextExtrema.get("v");
                var extH = (extHVal instanceof Number) ? extHVal.toFloat() : extHVal as Float;
                var extType = nextExtrema.get("y") as String;
                var extTs = nextExtrema.get("t") as Number;
                
                // Convert Unix timestamp back to Garmin Time.Moment
                var extTime = new Time.Moment(extTs.toNumber());
                var extInfo = Gregorian.info(extTime, Time.FORMAT_SHORT);
                var extTimeStr = Lang.format("$1$:$2$", [extInfo.hour.format("%02d"), extInfo.min.format("%02d")]);
                
                var dispExtH = extH;
                if (tideUnits == 1) {
                    dispExtH = extH * 3.28084;
                }
                var extStr = Lang.format("Next $1$: $2$$3$ $4$", [extType, dispExtH.format("%.2f"), dispUnit, extTimeStr]);
                
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, height * 0.70, Graphics.FONT_XTINY, extStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            // Draw Swell Data
            if (waveData != null && waveData instanceof Array) {
                if (waveData.size() > 1) {
                    var w1 = waveData[0] as Dictionary;
                    if (w1.get("t") == null) {
                        // Old data format - clear it
                        Application.Storage.deleteValue("waveData");
                        return;
                    }
                }
                var currentWave = null;
                for (var i = 0; i < waveData.size() - 1; i++) {
                    var w1 = waveData[i] as Dictionary;
                    var w2 = waveData[i+1] as Dictionary;
                    var waveTs1 = w1.get("t") as Number;
                    var waveTs2 = w2.get("t") as Number;
                    if (now >= waveTs1 && now < waveTs2) {
                        currentWave = w1;
                        break;
                    }
                }
                
                if (currentWave == null && waveData.size() > 0) {
                    var firstW = waveData[0] as Dictionary;
                    if (now < (firstW.get("t") as Number)) {
                        currentWave = firstW; // fallback to first if before
                    } else {
                        currentWave = waveData[waveData.size() - 1]; // fallback to last if beyond
                    }
                }
                
                if (currentWave != null) {
                    var cw = currentWave as Dictionary;
                    var waveH1 = cw.get("1h");
                    var waveP1 = cw.get("1p");
                    var waveH2 = cw.get("2h");
                    var waveP2 = cw.get("2p");
                    var waveH3 = cw.get("3h");
                    var waveP3 = cw.get("3p");
                        var waveD1 = cw.get("1d");
                        var waveD2 = cw.get("2d");
                        var waveD3 = cw.get("3d");
                        
                        var validSwells = new Array<Array<Lang.Numeric>>[3];
                        var count = 0;
                        if (waveH1 != null && waveP1 != null && waveD1 != null && (waveH1 as Lang.Numeric) > 0 && (waveP1 as Lang.Numeric) > 0) {
                            validSwells[count] = [waveH1 as Lang.Numeric, waveP1 as Lang.Numeric, waveD1 as Lang.Numeric];
                            count++;
                        }
                        if (waveH2 != null && waveP2 != null && waveD2 != null && (waveH2 as Lang.Numeric) > 0 && (waveP2 as Lang.Numeric) > 0) {
                            validSwells[count] = [waveH2 as Lang.Numeric, waveP2 as Lang.Numeric, waveD2 as Lang.Numeric];
                            count++;
                        }
                        if (waveH3 != null && waveP3 != null && waveD3 != null && (waveH3 as Lang.Numeric) > 0 && (waveP3 as Lang.Numeric) > 0) {
                            validSwells[count] = [waveH3 as Lang.Numeric, waveP3 as Lang.Numeric, waveD3 as Lang.Numeric];
                            count++;
                        }
                        
                        if (count > 0) {
                            var swellTotalWidth = 0;
                            var parts = new Array<String>[count];
                            var arrowWidth = (10 * scale).toNumber();
                            var arrowPad = (3 * scale).toNumber();
                            var sepStr = " | ";
                            var sepWidth = dc.getTextWidthInPixels(sepStr, Graphics.FONT_XTINY);
                            
                            for (var i = 0; i < count; i++) {
                                var swell = validSwells[i] as Array<Lang.Numeric>;
                                var hVal = swell[0]; var pVal = swell[1];
                                var hv = (hVal instanceof Number) ? hVal.toFloat() : hVal as Float;
                                var pv = (pVal instanceof Number) ? pVal.toNumber() : pVal as Number;
                                
                                var dispSwellH = hv;
                                var dispSwellUnit = "m";
                                if (swellUnits == 1) { // Feet requested
                                    dispSwellH = hv * 3.28084;
                                    dispSwellUnit = "ft";
                                }
                                
                                var str = dispSwellH.format("%.1f") + dispSwellUnit + "@" + pv;
                                parts[i] = str;
                                swellTotalWidth += arrowWidth + arrowPad + dc.getTextWidthInPixels(str, Graphics.FONT_XTINY);
                            }
                            swellTotalWidth += (count - 1) * sepWidth;
                            
                            var currentX = (width / 2.0 - swellTotalWidth / 2.0).toNumber();
                            var currentY = (height * 0.58).toNumber();
                            
                            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                            for (var i = 0; i < count; i++) {
                                var swell = validSwells[i] as Array<Lang.Numeric>;
                                var dVal = swell[2];
                                var dir = (dVal instanceof Number) ? dVal.toFloat() : dVal as Float;
                                
                                drawSwellArrow(dc, currentX + arrowWidth/2, currentY, dir);
                                currentX += arrowWidth + arrowPad;
                                
                                dc.drawText(currentX, currentY, Graphics.FONT_XTINY, parts[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                                currentX += dc.getTextWidthInPixels(parts[i], Graphics.FONT_XTINY);
                                
                                if (i < count - 1) {
                                    dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                                    dc.drawText(currentX, currentY, Graphics.FONT_XTINY, sepStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                                    dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                                    currentX += sepWidth;
                                }
                            }
                        } else {
                            // Show placeholder so we know if there is no valid swell array inside the wave spot
                            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                            dc.drawText(width / 2, height * 0.58, Graphics.FONT_XTINY, "No Swells Right Now", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                        }
                }
            } else {
                var waveError = Application.Storage.getValue("waveError");
                var msg = waveError != null ? "Swell Sync Error: " + waveError : "Waiting for swell data...";
                dc.setColor(waveError != null ? Graphics.COLOR_RED : Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, height * 0.58, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

            // Draw Tide Graph
            if (tideData.size() > 1) {
                var minH = 9999.0;
                var maxH = -9999.0;
                var minT = now;
                var maxT = now + 16 * 3600; // Next 16 hours

                for (var i = 0; i < tideData.size(); i++) {
                    var tj = tideData[i] as Dictionary;
                    var tTs = tj.get("t") as Number;
                    // Only consider points roughly within the next 16h to scale the height properly
                    if (tTs >= minT - 3600 && tTs <= maxT + 3600) {
                        var hVal = tj.get("v");
                        var h = (hVal instanceof Number) ? hVal.toFloat() : hVal as Float;
                        if (h < minH) { minH = h; }
                        if (h > maxH) { maxH = h; }
                    }
                }

                if (maxH > minH && maxT > minT) {
                    var graphY = height * 0.88; // Bottom of graph
                    var graphHeight = height * 0.18; // Top of graph is 0.70, slightly overlapping 0.70 text 
                    var graphMargin = width * 0.15; // 15% margin on sides so the current time is not clipped
                    var drawWidth = width - 2 * graphMargin;
                    
                    // Draw Swell Graph (quantitative, 0-4m scale)
                    if (waveData != null && waveData instanceof Array && waveData.size() > 1) {
                        var swellColors = [Graphics.COLOR_WHITE, Graphics.COLOR_LT_GRAY, Graphics.COLOR_LT_GRAY];
                        var swellKeys = ["1h", "2h", "3h"];
                        
                        for (var s = 0; s < 3; s++) {
                            var key = swellKeys[s];
                            var lastSX = -1;
                            var lastSY = -1;
                            
                            for (var i = 0; i < waveData.size(); i++) {
                                var wj = waveData[i] as Dictionary;
                                var wTsVal = wj.get("t");
                                if (wTsVal == null) { continue; }
                                
                                var wTs = 0L;
                                if (wTsVal has :toLong) { wTs = wTsVal.toLong(); }
                                else if (wTsVal instanceof Number) { wTs = wTsVal.toLong(); }
                                else { continue; }
                                
                                var hVal = wj.get(key);
                                if (hVal == null) { 
                                    lastSX = -1; // Gap in data
                                    continue; 
                                }
                                
                                var h = 0.0;
                                if (hVal has :toFloat) { h = hVal.toFloat(); }
                                else if (hVal instanceof Number) { h = hVal.toFloat(); }
                                else { h = hVal as Float; }
                                
                                var isMaxed = h > 4.0;
                                if (isMaxed) { h = 4.0; }
                                
                                // Calculate position relative to now (minT) and 16h window
                                var sx = graphMargin + drawWidth * (wTs - minT).toFloat() / (maxT - minT).toFloat();
                                var sy = graphY - graphHeight * (h / 4.0);
                                
                                var sxi = sx.toNumber();
                                var syi = sy.toNumber();
                                
                                // Draw trend line
                                if (lastSX >= 0 && (sx >= -50 && sx <= width + 50)) {
                                    dc.setColor(isMaxed ? Graphics.COLOR_RED : swellColors[s], Graphics.COLOR_TRANSPARENT);
                                    dc.drawLine(lastSX, lastSY, sxi, syi);
                                    if (s == 0) { // Thicker primary swell
                                        dc.drawLine(lastSX, lastSY + 1, sxi, syi + 1);
                                        dc.drawLine(lastSX, lastSY - 1, sxi, syi - 1);
                                    }
                                }
                                
                                // Debug: visible index for each point to confirm they exist
                                if (s == 0 && sx >= graphMargin && sx <= width - graphMargin) {
                                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
                                    dc.drawText(sxi, syi - 10, Graphics.FONT_XTINY, i.toString(), Graphics.TEXT_JUSTIFY_CENTER);
                                }
                                
                                lastSX = sxi;
                                lastSY = syi;
                            }
                        }
                    }

                    // Draw Tide Graph
                    dc.setColor(graphColor, Graphics.COLOR_TRANSPARENT);
                    var lastX = -1;
                    var lastY = -1;
                    
                    for (var i = 0; i < tideData.size(); i++) {
                        var tj = tideData[i] as Dictionary;
                        var tTs = tj.get("t") as Number;
                        var hVal = tj.get("v");
                        var h = (hVal instanceof Number) ? hVal.toFloat() : hVal as Float;
                        
                        var x = graphMargin + drawWidth * (tTs - minT).toFloat() / (maxT - minT).toFloat();
                        var y = graphY - graphHeight * (h - minH) / (maxH - minH);
                        
                        var xi = x.toNumber();
                        var yi = y.toNumber();
                        
                        if (lastX >= 0) {
                            dc.drawLine(lastX, lastY, xi, yi);
                            dc.drawLine(lastX, lastY+1, xi, yi+1); // thicker 
                        }
                        lastX = xi;
                        lastY = yi;
                    }
                    
                    // Draw current time marker on the graph
                    var nowX = graphMargin + drawWidth * (now - minT).toFloat() / (maxT - minT).toFloat();
                    if (nowX >= 0 && nowX <= width) {
                        dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                        dc.fillCircle(nowX.toNumber(), (graphY - graphHeight * (currentHeight - minH) / (maxH - minH)).toNumber(), 3);
                    }
                }
            }

            // Draw Spot Name at the bottom
            var spotNameStr = Application.Storage.getValue("spotName");
            if (spotNameStr != null && spotNameStr instanceof String) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(width / 2, height * 0.95, Graphics.FONT_XTINY, spotNameStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }

        } else {
            var msg = tideError != null ? "Tide Error: " + tideError : "Tide Data Old\nWaiting for sync...";
            dc.setColor(tideError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawArrow(dc as Dc, x as Number, y as Number, isRising as Boolean) as Void {
        var s = dc.getWidth() / 416.0;
        var sz = (8 * s).toNumber();
        var pts;
        if (isRising) {
            pts = [[x, y - sz], [x - sz, y + sz], [x + sz, y + sz]]; // Up Arrow
        } else {
            pts = [[x, y + sz], [x - sz, y - sz], [x + sz, y - sz]]; // Down Arrow
        }
        dc.fillPolygon(pts as Array<[Lang.Numeric, Lang.Numeric]>);
    }

    function drawSwellArrow(dc as Dc, x as Number, y as Number, direction as Float) as Void {
        var s = dc.getWidth() / 416.0;
        var rad = (direction + 180.0) * Math.PI / 180.0;
        var cos = Math.cos(rad);
        var sin = Math.sin(rad);
        
        var xf = x.toFloat();
        var yf = y.toFloat();
        
        var px = 0.0; var py = -5.0 * s;
        var p0x = xf + px*cos - py*sin; var p0y = yf + px*sin + py*cos;
        px = -3.5 * s; py = 3.5 * s;
        var p1x = xf + px*cos - py*sin; var p1y = yf + px*sin + py*cos;
        px = 3.5 * s; py = 3.5 * s;
        var p2x = xf + px*cos - py*sin; var p2y = yf + px*sin + py*cos;
        
        var pts = [
            [p0x, p0y],
            [p1x, p1y],
            [p2x, p2y]
        ];
        dc.fillPolygon(pts as Array<[Lang.Numeric, Lang.Numeric]>);
    }

    function drawBattery(dc as Dc, x as Number, y as Number, battery as Float) as Void {
        var s = dc.getWidth() / 416.0;
        var width = (24 * s).toNumber();
        var height = (12 * s).toNumber();
        var tipWidth = (2 * s).toNumber();
        var tipHeight = (6 * s).toNumber();
        var margin = (2 * s).toNumber();
        var fillWidth = ((width - margin * 2) * (battery / 100.0)).toNumber();
        if (fillWidth < 0) {
            fillWidth = 0;
        }

        var color = Graphics.COLOR_WHITE;
        if (battery < 10.0) {
            color = Graphics.COLOR_RED;
        } else if (battery < 20.0) {
            color = Graphics.COLOR_YELLOW;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        
        // Draw percentage text
        var percStr = battery.toNumber().toString() + "%";
        dc.drawText(x - (2 * s).toNumber(), y, Graphics.FONT_XTINY, percStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw battery outline
        var iconX = x + (2 * s).toNumber();
        var iconY = y - height / 2;
        
        dc.drawRectangle(iconX, iconY, width, height);
        dc.fillRectangle(iconX + width, iconY + (height - tipHeight) / 2, tipWidth, tipHeight);

        // Fill battery level
        if (fillWidth > 0) {
            dc.fillRectangle(iconX + margin, iconY + margin, fillWidth, height - margin * 2);
        }
    }

    function onHide() as Void {
    }

    function onExitSleep() as Void {
    }

    function onEnterSleep() as Void {
    }

    function getColorFromIndex(idx as Number) as Number {
        if (idx == 1) { return Graphics.COLOR_PINK; }
        if (idx == 2) { return Graphics.COLOR_RED; }
        if (idx == 3) { return Graphics.COLOR_GREEN; }
        if (idx == 4) { return Graphics.COLOR_WHITE; }
        if (idx == 5) { return Graphics.COLOR_YELLOW; }
        return Graphics.COLOR_BLUE; // Default/0
    }
}
