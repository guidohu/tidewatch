import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class TideWatchView extends WatchUi.WatchFace {

    var mLastLazyDataUpdate as Number = 0;
    var mLastSettingsHash as Number = 0;
    var mLastDataUpdatedAt as Number = 0;

    var mBattery as Float = 0.0;
    var mDateStr as String = "";
    var mDowStr as String = "";

    var mCurrentHeight as Float = 0.0;
    var mIsRising as Boolean = false;
    var mNextExtremaStr as String? = null;
    var mDispUnit as String = "";
    var mTideNumStr as String = "";

    var mValidSwells as Array = [];
    var mSwellTexts as Array = [];

    var mMinH as Float = 9999.0;
    var mMaxH as Float = -9999.0;
    var mMinSwellH as Float = 9999.0;
    var mMaxSwellH as Float = -9999.0;
    var mMinT as Number = 0;
    var mMaxT as Number = 0;

    var mcTideData as Array? = null;
    var mcTideTimes as Array? = null;
    var mcTideStartTime as Number? = null;
    var mcTideInterval as Number? = null;
    var mcTideExtrema as Array? = null;
    var mcWaveData as Array? = null;
    var mcTideUnitApi as Number? = null;
    var mcSwellUnitApi as Number? = null;
    var mcSpotName as String? = null;
    var mSyncError as Number? = null;
    var mErrorAt as Number? = null;

    function initialize() {
        WatchFace.initialize();
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function onUpdate(dc as Dc) as Void {
        var now = Time.now().value();
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        var targetTideUnit = (tideUnits == 1) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var targetSwellUnit = (swellUnits == 1) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var tideColorIdx = Application.Properties.getValue("TideColor");
        var graphColorIdx = Application.Properties.getValue("GraphColor");
        var baseColorIdx = Application.Properties.getValue("BaseColor");
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph");
        var showDate = Application.Properties.getValue("ShowDate");

        var currentHash = (tideUnits == null ? 0 : tideUnits as Number) +
            ((swellUnits == null ? 0 : swellUnits as Number) << 2) +
            ((tideColorIdx == null ? 0 : tideColorIdx as Number) << 4) +
            ((graphColorIdx == null ? 0 : graphColorIdx as Number) << 8) +
            ((baseColorIdx == null ? 0 : baseColorIdx as Number) << 12) +
            ((showSwellGraph ? 1 : 0) << 16) +
            ((showDate ? 1 : 0) << 17);

        var dataUpdatedAt = Application.Storage.getValue("dataUpdatedAt") as Number?;
        if (dataUpdatedAt == null) { dataUpdatedAt = 0; }

        if (now - mLastLazyDataUpdate >= 300 || currentHash != mLastSettingsHash || dataUpdatedAt != mLastDataUpdatedAt) {
            mLastLazyDataUpdate = now;
            mLastSettingsHash = currentHash;
            mLastDataUpdatedAt = dataUpdatedAt;

            var stats = System.getSystemStats();
            mBattery = stats.battery;

            var todayMed = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            var todayLong = Gregorian.info(Time.now(), Time.FORMAT_LONG);
            mDateStr = todayMed.day.format("%d") + " " + todayMed.month;
            mDowStr = todayLong.day_of_week;

            mcTideData = Application.Storage.getValue("tideData") as Array?;
            mcTideTimes = Application.Storage.getValue("tideTimes") as Array?;
            mcTideStartTime = Application.Storage.getValue("tideStartTime") as Number?;
            mcTideInterval = Application.Storage.getValue("tideInterval") as Number?;
            mcTideExtrema = Application.Storage.getValue("tideExtrema") as Array?;
            mcWaveData = Application.Storage.getValue("waveData") as Array?;
            mcTideUnitApi = Application.Storage.getValue("tideUnitApi") as Number?;
            mcSwellUnitApi = Application.Storage.getValue("swellUnitApi") as Number?;
            mcSpotName = Application.Storage.getValue("spotName") as String?;
            mSyncError = Application.Storage.getValue("syncError") as Number?;
            mErrorAt = Application.Storage.getValue("errorAt") as Number?;

            mCurrentHeight = 0.0;
            mIsRising = false;
            mNextExtremaStr = null;
            mValidSwells = [];
            mSwellTexts = [];
            mMinH = 9999.0;
            mMaxH = -9999.0;
            mMinSwellH = 9999.0;
            mMaxSwellH = -9999.0;
            mMinT = now - 2 * 3600;
            mMaxT = now + 16 * 3600;

            if (mcTideData != null && mcTideTimes != null && mcTideTimes.size() == mcTideData.size()) {
                var found = false;
                var currWaveIdx = -1;
                var tTimesArray = mcTideTimes as Array;
                var tDataArray = mcTideData as Array;
                for (var i = 0; i < tTimesArray.size() - 1; i++) {
                    var t1 = tTimesArray[i] as Number;
                    var t2 = tTimesArray[i + 1] as Number;
                    if (now >= t1 && now <= t2) {
                        var h1 = convertHeight(tDataArray[i] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        var h2 = convertHeight(tDataArray[i + 1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        var ratio = (now - t1).toFloat() / (t2 - t1).toFloat();
                        mCurrentHeight = h1 + (h2 - h1) * ratio;
                        mIsRising = h2 > h1;
                        currWaveIdx = i;
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    if (now < (tTimesArray[0] as Number)) {
                        mCurrentHeight = convertHeight(tDataArray[0] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        currWaveIdx = 0;
                    } else {
                        mCurrentHeight = convertHeight(tDataArray[tDataArray.size() - 1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        currWaveIdx = tDataArray.size() - 1;
                    }
                }

                var dispHeight = convertHeight((mCurrentHeight * 100).toNumber(), DataKeys.UNIT_METER, targetTideUnit);
                mDispUnit = (targetTideUnit == DataKeys.UNIT_FEET) ? "ft" : "m";
                mTideNumStr = dispHeight.format("%.2f");

                if (mcTideExtrema != null && mcTideExtrema instanceof Array) {
                    for (var i = 0; i < mcTideExtrema.size(); i++) {
                        var ext = mcTideExtrema[i] as Array;
                        if (ext[0] > now) {
                            var extTs = ext[0] as Number;
                            var rawExtH = ext[1] as Number;
                            var typeCode = ext[2];
                            var extType = (typeCode == DataKeys.TIDE_TYPE_HIGH) ? "High" : "Low";
                            var extInfo = Gregorian.info(new Time.Moment(extTs.toNumber()), Time.FORMAT_SHORT);
                            var extTimeStr = Lang.format("$1$:$2$", [extInfo.hour.format("%02d"), extInfo.min.format("%02d")]);
                            var dispExtH = convertHeight(rawExtH, mcTideUnitApi, targetTideUnit);
                            mNextExtremaStr = Lang.format("$1$: $2$$3$ $4$", [extType, dispExtH.format("%.2f"), mDispUnit, extTimeStr]);
                            break;
                        }
                    }
                }

                if (mcWaveData != null) {
                    var waveDataArray = mcWaveData as Array;
                    var currentWave = null;
                    if (currWaveIdx >= 0 && currWaveIdx < waveDataArray.size()) {
                        currentWave = waveDataArray[currWaveIdx] as Array;
                    } else if (waveDataArray.size() > 0) {
                        if (tTimesArray != null && tTimesArray.size() > 0 && now < (tTimesArray[0] as Number)) {
                            currentWave = waveDataArray[0] as Array;
                        } else {
                            currentWave = waveDataArray[waveDataArray.size() - 1] as Array;
                        }
                    }

                    if (currentWave != null) {
                        for (var s = 0; s < 3; s++) {
                            var h = (currentWave as Array)[s*3];
                            if (h != null) {
                                var hvRaw = h as Number;
                                if (hvRaw > 0) {
                                    var pVal = (currentWave as Array)[s*3+1];
                                    var pValNum = (pVal instanceof Number) ? pVal as Number : (pVal as Float).toNumber();
                                    var dVal = (currentWave as Array)[s*3+2];
                                    var dValFloat = (dVal instanceof Number) ? (dVal as Number).toFloat() : dVal as Float;
                                    mValidSwells.add([hvRaw, pValNum, dValFloat]);
                                    
                                    var dispH = convertHeight(hvRaw, mcSwellUnitApi, targetSwellUnit);
                                    var unit = (targetSwellUnit == DataKeys.UNIT_FEET) ? "ft" : "m";
                                    var sStr = dispH.format("%.1f") + unit + "@" + pValNum;
                                    mSwellTexts.add(sStr);
                                }
                            }
                        }
                    }
                }

                for (var i = 0; i < tDataArray.size(); i++) {
                    var tTs = tTimesArray[i] as Number;
                    if (tTs >= mMinT - 3600 && tTs <= mMaxT + 3600) {
                        var h = tDataArray[i];
                        if (h != null) {
                            var hFloat = convertHeight(h as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                            if (hFloat < mMinH) { mMinH = hFloat; }
                            if (hFloat > mMaxH) { mMaxH = hFloat; }
                        }
                    }
                }
                
                if (mcWaveData != null && mcWaveData instanceof Array) {
                    var wDataArray = mcWaveData as Array;
                    for (var i = 0; i < wDataArray.size(); i++) {
                        if (i < tTimesArray.size()) {
                            var tTs = tTimesArray[i] as Number;
                            if (tTs >= mMinT - 3600 && tTs <= mMaxT + 3600) {
                                var wPoint = wDataArray[i] as Array;
                                for (var s = 0; s < 3; s++) {
                                    var hVal = wPoint[s*3];
                                    if (hVal != null) {
                                        var h = convertHeight(hVal as Number, mcSwellUnitApi, DataKeys.UNIT_METER);
                                        if (h < mMinSwellH) { mMinSwellH = h; }
                                        if (h > mMaxSwellH) { mMaxSwellH = h; }
                                    }
                                }
                            }
                        }
                    }
                }
                if (mMinSwellH == 9999.0) { mMinSwellH = 0.0; mMaxSwellH = 1.0; }
                if (mMaxSwellH == mMinSwellH) { mMaxSwellH = mMinSwellH + 1.0; }
            }
        }

        var tideColor = getColorFromIndex(tideColorIdx);
        var graphColor = getColorFromIndex(graphColorIdx);
        var baseColor = getColorFromIndex(baseColorIdx);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var scale = width / 416.0;

        // 1. Draw Time/Battery (always rendered with current time)
        var clockTime = System.getClockTime();
        var timeStr = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width / 2, height * 0.24, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawBattery(dc, width / 2, (height * 0.08).toNumber(), mBattery, baseColor);

        // 2. Error Check
        var spotId = Application.Properties.getValue("SpotId");
        if (spotId == null || spotId.equals("")) {
             var msg = WatchUi.loadResource(Rez.Strings.NoSpotSelected) as String;
             msg += "\nLast sync: ";
             if (mLastDataUpdatedAt > 0) {
                 var info = Gregorian.info(new Time.Moment(mLastDataUpdatedAt), Time.FORMAT_SHORT);
                 msg += info.hour.format("%02d") + ":" + info.min.format("%02d");
             } else {
                 msg += "pending";
             }
             dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
             dc.drawText(width / 2, height / 2, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
             return;
        }

        if (mcTideData == null || mcTideTimes == null || mcTideStartTime == null || mcTideInterval == null) {
            var msg = "Waiting for sync...\nFirst sync can take\nup to 15 minutes.";
            if (mSyncError != null) {
                if (mSyncError == DataKeys.ERROR_NO_SPOTS_NEARBY) {
                    msg = WatchUi.loadResource(Rez.Strings.NoSpotsFound) as String;
                } else if (mSyncError == DataKeys.ERROR_NETWORK_RESPONSE_TOO_LARGE) {
                    msg = "no data sync";
                } else if (mSyncError <= DataKeys.ERROR_PHONE_CONN_MAX && mSyncError > DataKeys.ERROR_PHONE_CONN_MIN) {
                    msg = "no connection";
                } else {
                    msg = "sync error";
                }
            }
            dc.setColor(mSyncError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height / 2, Graphics.FONT_XTINY, msg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Draw Current Tide Height
        var numWidth = dc.getTextWidthInPixels(mTideNumStr, Graphics.FONT_NUMBER_MEDIUM);
        var mWidth = dc.getTextWidthInPixels(mDispUnit, Graphics.FONT_MEDIUM);
        var startX = (width - (numWidth + mWidth)) / 2;

        dc.setColor(tideColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, height * 0.44, Graphics.FONT_NUMBER_MEDIUM, mTideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth, height * 0.44, Graphics.FONT_MEDIUM, mDispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawArrow(dc, (startX + numWidth + mWidth + 15 * scale).toNumber(), (height * 0.44).toNumber(), mIsRising);

        if (showDate) {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX - 10 * scale, (height * 0.38) + 1, Graphics.FONT_XTINY, mDateStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + numWidth + mWidth + 30 * scale, (height * 0.38) + 1, Graphics.FONT_XTINY, mDowStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (mNextExtremaStr != null) {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.67, Graphics.FONT_XTINY, mNextExtremaStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Swell Section
        if (mValidSwells.size() > 0) {
            var totalSwellW = 0;
            var arrowW = (10 * scale).toNumber();
            var pad = (3 * scale).toNumber();
            var sepW = dc.getTextWidthInPixels(" | ", Graphics.FONT_XTINY);
            for (var i = 0; i < mValidSwells.size(); i++) {
                totalSwellW += arrowW + pad + dc.getTextWidthInPixels(mSwellTexts[i] as String, Graphics.FONT_XTINY);
            }
            totalSwellW += (mValidSwells.size() - 1) * sepW;

            var curX = (width - totalSwellW) / 2;
            var curY = (height * 0.57).toNumber();
            for (var i = 0; i < mValidSwells.size(); i++) {
                var sv = mValidSwells[i] as Array;
                drawSwellArrow(dc, (curX + arrowW/2).toNumber(), curY, sv[2] as Float);
                curX += arrowW + pad;
                dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(curX, curY, Graphics.FONT_XTINY, mSwellTexts[i] as String, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                curX += dc.getTextWidthInPixels(mSwellTexts[i] as String, Graphics.FONT_XTINY);
                if (i < mValidSwells.size() - 1) {
                    dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
                    dc.drawText(curX, curY, Graphics.FONT_XTINY, " | ", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
                    curX += sepW;
                }
            }
        } else {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.58, Graphics.FONT_XTINY, "No Swells", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Graph Section
        if (mMaxH > mMinH) {
            var graphY = height * 0.88;
            var graphHeight = height * 0.18;
            var graphMargin = width * 0.15;
            var drawWidth = width - 2 * graphMargin;

            // Swell Graph
            if (showSwellGraph && mcWaveData != null && mcWaveData instanceof Array) {
                var colors = [baseColor, baseColor, baseColor];
                var tTimesArray = mcTideTimes as Array?;
                for (var s = 0; s < 3; s++) {
                    var lastSX = -1, lastSY = -1;
                    var waveDataArray = mcWaveData as Array;
                    for (var i = 0; i < waveDataArray.size(); i++) {
                        var wPoint = waveDataArray[i] as Array;
                        var hVal = wPoint[s*3];
                        if (hVal == null || tTimesArray == null || i >= tTimesArray.size()) { lastSX = -1; continue; }
                        var h = convertHeight(hVal as Number, mcSwellUnitApi, DataKeys.UNIT_METER);
                        var wTs = tTimesArray[i] as Number;
                        var sx = graphMargin + drawWidth * (wTs - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
                        var sy = graphY - graphHeight * (h - mMinSwellH) / (mMaxSwellH - mMinSwellH);
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
            if (mcTideData != null && mcTideTimes != null) {
                var tTimesArray = mcTideTimes as Array;
                var tDataArray = mcTideData as Array;
                for (var i = 0; i < tDataArray.size(); i++) {
                    var tTs = tTimesArray[i] as Number;
                    var x = graphMargin + drawWidth * (tTs - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
                    var hVal = tDataArray[i];
                    if (hVal != null) {
                        var hFloat = convertHeight(hVal as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        var y = graphY - graphHeight * (hFloat - mMinH) / (mMaxH - mMinH);
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

            // Current Time Marker (using dynamic 'now' so marker moves!)
            var nowX = graphMargin + drawWidth * (now - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
            if (nowX >= 0 && nowX <= width) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                var markerY = graphY - graphHeight * (mCurrentHeight - mMinH) / (mMaxH - mMinH);
                dc.fillCircle(nowX.toNumber(), markerY.toNumber(), 3);
            }
        }

        // Spot Name or Error
        var isStale = (now - mLastDataUpdatedAt > 12 * 3600);
        var showSyncError = (mSyncError != null && mErrorAt != null && (now - mErrorAt < 300));

        if (showSyncError) {
            var errMsg = "sync error";
            if (mSyncError == DataKeys.ERROR_NETWORK_RESPONSE_TOO_LARGE) {
                errMsg = "no data sync";
            } else if (mSyncError <= DataKeys.ERROR_PHONE_CONN_MAX && mSyncError > DataKeys.ERROR_PHONE_CONN_MIN) {
                errMsg = "no connection";
            }
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.95, Graphics.FONT_XTINY, errMsg, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else if (mcSpotName != null) {
            var nameColor = baseColor;
            if (isStale || mSyncError != null) {
                nameColor = Graphics.COLOR_YELLOW;
            }
            dc.setColor(nameColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(width / 2, height * 0.95, Graphics.FONT_XTINY, mcSpotName as String, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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

    function convertHeight(rawValue as Number, apiUnit as Number?, targetUnit as Number) as Float {
        if (targetUnit != DataKeys.UNIT_METER && targetUnit != DataKeys.UNIT_FEET) {
            System.error("Invalid target unit: " + targetUnit);
        }
        var valFloat = rawValue.toFloat() / 100.0;
        if (apiUnit == null) { return valFloat; } // Assume already correct if unknown
        
        // API is Meters (18), Target is Feet (19)
        if (apiUnit == DataKeys.UNIT_METER && targetUnit == DataKeys.UNIT_FEET) {
            return valFloat * 3.28084;
        }
        // API is Feet (19), Target is Meters (18)
        if (apiUnit == DataKeys.UNIT_FEET && targetUnit == DataKeys.UNIT_METER) {
            return valFloat / 3.28084;
        }
        return valFloat;
    }
}
