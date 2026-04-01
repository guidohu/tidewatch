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
        var baseColorIdx = Application.Properties.getValue("BaseColor");
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph");

        var tideColor = getColorFromIndex(tideColorIdx);
        var graphColor = getColorFromIndex(graphColorIdx);
        var baseColor = getColorFromIndex(baseColorIdx);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var scale = width / 416.0;

        // 1. Draw Time/Battery
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.24, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var stats = System.getSystemStats();
        drawBattery(dc, width / 2, (height * 0.08).toNumber(), stats.battery, baseColor);

        // 2. Fetch and parse Tide info
        var tideData = Application.Storage.getValue("tideData") as Array?;
        var tideTimes = Application.Storage.getValue("tideTimes") as Array?;
        var tideStartTime = Application.Storage.getValue("tideStartTime") as Number?;
        var tideInterval = Application.Storage.getValue("tideInterval") as Number?;
        var tideExtrema = Application.Storage.getValue("tideExtrema") as Array?;
        var waveData = Application.Storage.getValue("waveData") as Array?;
        var tideError = Application.Storage.getValue("tideError") as Number?;
        
        if (tideData == null || tideTimes == null || tideStartTime == null || tideInterval == null) {
            var msg = (tideError != null) ? "Tide Error: " + tideError : "No Tide Data\nWaiting for sync...";
            dc.setColor(tideError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_SMALL, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var now = Time.now().value();
        var currentHeight = 0.0;
        var isRising = false;
        var currWaveIdx = -1;
        
        if (tideData != null && tideTimes != null && tideTimes.size() == tideData.size()) {
            var found = false;
            var tTimesArray = tideTimes as Array;
            var tDataArray = tideData as Array;
            for (var i = 0; i < tTimesArray.size() - 1; i++) {
                var t1 = tTimesArray[i] as Number;
                var t2 = tTimesArray[i + 1] as Number;
                if (now >= t1 && now <= t2) {
                    var h1 = (tDataArray[i] as Number).toFloat() / 100.0;
                    var h2 = (tDataArray[i + 1] as Number).toFloat() / 100.0;
                    var ratio = (now - t1).toFloat() / (t2 - t1).toFloat();
                    currentHeight = h1 + (h2 - h1) * ratio;
                    isRising = h2 > h1;
                    currWaveIdx = i;
                    found = true;
                    break;
                }
            }
            if (!found) {
                if (now < (tTimesArray[0] as Number)) {
                    currentHeight = (tDataArray[0] as Number).toFloat() / 100.0;
                    currWaveIdx = 0;
                } else {
                    currentHeight = (tDataArray[tDataArray.size() - 1] as Number).toFloat() / 100.0;
                    currWaveIdx = tDataArray.size() - 1;
                }
            }
        }
        

        // Draw Current Tide Height
        var dispHeight = currentHeight;
        var dispUnit = "m";
        if (tideUnits == 1) {
            dispHeight = currentHeight * 3.28084;
            dispUnit = "ft";
        }
        var tideNumStr = dispHeight.format("%.2f");
        var numWidth = dc.getTextWidthInPixels(tideNumStr, Graphics.FONT_NUMBER_MEDIUM);
        var mWidth = dc.getTextWidthInPixels(dispUnit, Graphics.FONT_MEDIUM);
        var startX = (width - (numWidth + mWidth)) / 2;

        dc.setColor(tideColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, height * 0.44, Graphics.FONT_NUMBER_MEDIUM, tideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth, height * 0.44, Graphics.FONT_MEDIUM, dispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawArrow(dc, (startX + numWidth + mWidth + 15 * scale).toNumber(), (height * 0.44).toNumber(), isRising);

        var todayMed = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var todayLong = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        var dateStr = todayMed.day.format("%d") + " " + todayMed.month;
        var dowStr = todayLong.day_of_week;

        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX - 10 * scale, (height * 0.38) + 1, Graphics.FONT_XTINY, dateStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth + mWidth + 30 * scale, (height * 0.38) + 1, Graphics.FONT_XTINY, dowStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Next High/Low
        var nextExtrema = null;
        if (tideExtrema != null && tideExtrema instanceof Array) {
            for (var i = 0; i < tideExtrema.size(); i++) {
                var ext = tideExtrema[i] as Array;
                if (ext[0] > now) { nextExtrema = ext; break; }
            }
        }
        if (nextExtrema != null) {
            var extTs = nextExtrema[0] as Number;
            var extH = (nextExtrema[1] as Number).toFloat() / 100.0;
            var typeCode = nextExtrema[2];
            var extType = (typeCode == DataKeys.TIDE_TYPE_HIGH) ? "High" : "Low";
            var extInfo = Gregorian.info(new Time.Moment(extTs.toNumber()), Time.FORMAT_SHORT);
            var extTimeStr = Lang.format("$1$:$2$", [extInfo.hour.format("%02d"), extInfo.min.format("%02d")]);
            var dispExtH = (tideUnits == 1) ? extH * 3.28084 : extH;
            var extStr = Lang.format("$1$: $2$$3$ $4$", [extType, dispExtH.format("%.2f"), dispUnit, extTimeStr]);
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.67, Graphics.FONT_XTINY, extStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Swell Section
        if (waveData != null) {
            var waveDataArray = waveData as Array;
            var currentWave = null;
            if (currWaveIdx >= 0 && currWaveIdx < waveDataArray.size()) {
                currentWave = waveDataArray[currWaveIdx] as Array;
            } else if (waveDataArray.size() > 0) {
                var tTimesArray = tideTimes as Array?;
                if (tTimesArray != null && tTimesArray.size() > 0 && now < (tTimesArray[0] as Number)) {
                    currentWave = waveDataArray[0] as Array;
                } else {
                    currentWave = waveDataArray[waveDataArray.size() - 1] as Array;
                }
            }

            if (currentWave != null) {
                var validSwells = [];
                for (var s = 0; s < 3; s++) {
                    var h = (currentWave as Array)[s*3];
                    if (h != null) {
                        var hFloat = (h instanceof Number) ? (h as Number).toFloat() / 100.0 : h as Float;
                        if (hFloat > 0) {
                            var pVal = (currentWave as Array)[s*3+1];
                            var pValNum = (pVal instanceof Number) ? pVal as Number : (pVal as Float).toNumber();
                            var dVal = (currentWave as Array)[s*3+2];
                            var dValFloat = (dVal instanceof Number) ? (dVal as Number).toFloat() : dVal as Float;
                            validSwells.add([hFloat, pValNum, dValFloat]);
                        }
                    }
                }
                
                if (validSwells.size() > 0) {
                    var totalSwellW = 0;
                    var arrowW = (10 * scale).toNumber();
                    var pad = (3 * scale).toNumber();
                    var sepW = dc.getTextWidthInPixels(" | ", Graphics.FONT_XTINY);
                    var texts = [];
                    for (var i = 0; i < validSwells.size(); i++) {
                        var sv = validSwells[i] as Array;
                        var hv = sv[0] as Float;
                        var pv = sv[1] as Number;
                        var dispH = (swellUnits == 1) ? hv * 3.28084 : hv;
                        var unit = (swellUnits == 1) ? "ft" : "m";
                        var sStr = dispH.format("%.1f") + unit + "@" + pv;
                        texts.add(sStr);
                        totalSwellW += arrowW + pad + dc.getTextWidthInPixels(sStr, Graphics.FONT_XTINY);
                    }
                    totalSwellW += (validSwells.size() - 1) * sepW;
                    
                    var curX = (width - totalSwellW) / 2;
                    var curY = (height * 0.57).toNumber();
                    for (var i = 0; i < validSwells.size(); i++) {
                        var sv = validSwells[i] as Array;
                        drawSwellArrow(dc, (curX + arrowW/2).toNumber(), curY, sv[2] as Float);
                        curX += arrowW + pad;
                        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
                        dc.drawText(curX, curY, Graphics.FONT_XTINY, texts[i], Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                        curX += dc.getTextWidthInPixels(texts[i], Graphics.FONT_XTINY);
                        if (i < validSwells.size() - 1) {
                            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
                            dc.drawText(curX, curY, Graphics.FONT_XTINY, " | ", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                            curX += sepW;
                        }
                    }
                } else {
                    dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(width / 2, height * 0.58, Graphics.FONT_XTINY, "No Swells", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }
        }

        // Graph Section
        var minH = 9999.0;
        var maxH = -9999.0;
        var minT = now;
        var maxT = now + 16 * 3600;

        var minSwellH = 9999.0;
        var maxSwellH = -9999.0;

        if (tideData != null && tideTimes != null) {
            var tTimesArray = tideTimes as Array;
            var tDataArray = tideData as Array;
            for (var i = 0; i < tDataArray.size(); i++) {
                var tTs = tTimesArray[i] as Number;
                if (tTs >= minT - 3600 && tTs <= maxT + 3600) {
                    var h = tDataArray[i];
                    if (h != null) {
                        var hFloat = (h as Number).toFloat() / 100.0;
                        if (hFloat < minH) { minH = hFloat; }
                        if (hFloat > maxH) { maxH = hFloat; }
                    }
                }
            }
        }
        
        if (waveData != null && waveData instanceof Array && tideTimes != null) {
            var wDataArray = waveData as Array;
            var tTimesArray = tideTimes as Array;
            for (var i = 0; i < wDataArray.size(); i++) {
                if (i < tTimesArray.size()) {
                    var tTs = tTimesArray[i] as Number;
                    if (tTs >= minT - 3600 && tTs <= maxT + 3600) {
                        var wPoint = wDataArray[i] as Array;
                        for (var s = 0; s < 3; s++) {
                            var hVal = wPoint[s*3];
                            if (hVal != null) {
                                var h = (hVal instanceof Number) ? (hVal as Number).toFloat() / 100.0 : hVal as Float;
                                if (h < minSwellH) { minSwellH = h; }
                                if (h > maxSwellH) { maxSwellH = h; }
                            }
                        }
                    }
                }
            }
        }
        if (minSwellH == 9999.0) {
            minSwellH = 0.0;
            maxSwellH = 1.0;
        }
        if (maxSwellH == minSwellH) {
            maxSwellH = minSwellH + 1.0;
        }

        if (maxH > minH) {
            var graphY = height * 0.88;
            var graphHeight = height * 0.18;
            var graphMargin = width * 0.15;
            var drawWidth = width - 2 * graphMargin;

            // Swell Graph
            if (showSwellGraph && waveData != null && waveData instanceof Array) {
                var colors = [Graphics.COLOR_WHITE, Graphics.COLOR_LT_GRAY, Graphics.COLOR_LT_GRAY];
                var tTimesArray = tideTimes as Array?;
                for (var s = 0; s < 3; s++) {
                    var lastSX = -1, lastSY = -1;
                    var waveDataArray = waveData as Array;
                    for (var i = 0; i < waveDataArray.size(); i++) {
                        var wPoint = waveDataArray[i] as Array;
                        var hVal = wPoint[s*3];
                        if (hVal == null || tTimesArray == null || i >= tTimesArray.size()) { lastSX = -1; continue; }
                        var h = (hVal instanceof Number) ? (hVal as Number).toFloat() / 100.0 : hVal as Float;
                        var wTs = tTimesArray[i] as Number;
                        var sx = graphMargin + drawWidth * (wTs - minT).toFloat() / (maxT - minT).toFloat();
                        var sy = graphY - graphHeight * (h - minSwellH) / (maxSwellH - minSwellH);
                        if (lastSX >= 0 && (sx >= -50 && sx <= width + 50)) {
                            dc.setColor(colors[s], Graphics.COLOR_TRANSPARENT);
                            dc.drawLine(lastSX, lastSY, sx.toNumber(), sy.toNumber());
                            if (s == 0) { dc.drawLine(lastSX, lastSY+1, sx.toNumber(), sy.toNumber()+1); dc.drawLine(lastSX, lastSY-1, sx.toNumber(), sy.toNumber()-1); }
                        }
                        lastSX = sx.toNumber(); lastSY = sy.toNumber();
                    }
                }
            }

            // Tide Graph
            dc.setColor(graphColor, Graphics.COLOR_TRANSPARENT);
            var lastX = -1, lastY = -1;
            if (tideData != null && tideTimes != null) {
                var tTimesArray = tideTimes as Array;
                var tDataArray = tideData as Array;
                for (var i = 0; i < tDataArray.size(); i++) {
                    var tTs = tTimesArray[i] as Number;
                    var x = graphMargin + drawWidth * (tTs - minT).toFloat() / (maxT - minT).toFloat();
                    var hVal = tDataArray[i];
                    if (hVal != null) {
                        var hFloat = (hVal as Number).toFloat() / 100.0;
                        var y = graphY - graphHeight * (hFloat - minH) / (maxH - minH);
                        if (lastX >= 0 && (x >= -50 && x <= width + 50)) {
                            dc.drawLine(lastX, lastY, x.toNumber(), y.toNumber());
                            dc.drawLine(lastX, lastY+1, x.toNumber(), y.toNumber()+1);
                        }
                        lastX = x.toNumber(); lastY = y.toNumber();
                    } else {
                        lastX = -1; // Gap in data
                    }
                }
            }

            // Current Time Marker
            var nowX = graphMargin + drawWidth * (now - minT).toFloat() / (maxT - minT).toFloat();
            if (nowX >= 0 && nowX <= width) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                var markerY = graphY - graphHeight * (currentHeight - minH) / (maxH - minH);
                dc.fillCircle(nowX.toNumber(), markerY.toNumber(), 3);
            }
        }

        // Spot Name
        var spotName = Application.Storage.getValue("spotName");
        if (spotName != null) {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.95, Graphics.FONT_XTINY, spotName, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function drawArrow(dc as Dc, x as Number, y as Number, isRising as Boolean) as Void {
        var s = dc.getWidth() / 416.0;
        var sz = (8 * s).toNumber();
        var pts;
        
        if (isRising) {
            dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            pts = [[x, y - sz], [x - sz, y + sz], [x + sz, y + sz]]; // Up Arrow
        } else {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
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

    function drawBattery(dc as Dc, x as Number, y as Number, battery as Float, colorPrimary as Number) as Void {
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

        var color = colorPrimary;
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
        if (idx == 6) { return Graphics.COLOR_ORANGE; }
        if (idx == 7) { return Graphics.COLOR_PURPLE; }
        if (idx == 8) { return Graphics.COLOR_LT_GRAY; }
        if (idx == 9) { return Graphics.COLOR_DK_GRAY; }
        if (idx == 10) { return 0x55AAFF; } // Light Blue
        if (idx == 11) { return 0x005F6B; } // Petrol
        if (idx == 12) { return 0x00CCCC; } // Turquoise
        return Graphics.COLOR_BLUE; // Default/0
    }
}
