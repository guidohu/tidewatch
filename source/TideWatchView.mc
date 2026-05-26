import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class TideWatchView extends WatchUi.WatchFace {

    const METERS_TO_FEET = 3.28084;
    const STALE_DATA_THRESHOLD_SEC = 43200; // 12 hours
    const ERROR_DISPLAY_WINDOW_SEC = 300;   // 5 minutes
    const GRAPH_PAST_HOURS = 2;
    const GRAPH_FUTURE_HOURS = 16;
    const SCREEN_WIDTH_REFERENCE = 416.0;

    var mLastLazyDataUpdate as Number = 0;
    var mLastSettingsHash as Number = 0;
    var mLastDataUpdatedAt as Number = 0;
    var mLastSyncAttemptAt as Number = 0;

    var mBattery as Float = 0.0;

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

    var mcTideExtrema as Array? = null;
    var mcWaveData as Array? = null;
    var mcTideUnitApi as Number? = null;
    var mcSwellUnitApi as Number? = null;
    var mcSpotName as String? = null;
    var mSyncError as Number? = null;
    var mErrorAt as Number? = null;
    var mWeatherError as Number? = null;

    var mScreenWidth as Number = 0;
    var mScreenHeight as Number = 0;
    var mScale as Float = 1.0;

    /**
     * Constructor. Calls parent WatchFace constructor.
     */
    function initialize() {
        WatchFace.initialize();
    }

    /**
     * Lifecycle method called when the layout of the watch face needs to be loaded.
     * Pre-calculates and caches device screen boundaries and dynamic scaling ratios.
     * @param dc The device context representing the watch screen.
     */
    function onLayout(dc as Dc) as Void {
        mScreenWidth = dc.getWidth();
        mScreenHeight = dc.getHeight();
        mScale = mScreenWidth.toFloat() / SCREEN_WIDTH_REFERENCE;
    }

    /**
     * Main rendering hook called on watch face update cycles.
     * Manages KiezelPay dialog displays, triggers data state updates, and routes rendering commands
     * to modular drawing sub-routines (clock, battery, tide, swell, graphs, footer).
     * @param dc The device context.
     */
    function onUpdate(dc as Dc) as Void {
        // Payment Dialog / Licensing Check
        if (kpay != null) {
            var kpayInstance = kpay as KPayClock.KPay.Core;
            if (!kpayInstance.isLicensed()) {
                if (kpayInstance.shouldShowDialog()) {
                    kpayInstance.drawDialog(dc);
                } else {
                    dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
                    dc.clear();
                    var midY = dc.getHeight() / 2;
                    drawCenteredText(dc, midY - 12, Graphics.FONT_XTINY, "KiezelPay", Graphics.COLOR_WHITE);
                    drawCenteredText(dc, midY + 12, Graphics.FONT_XTINY, "Fetching code...", Graphics.COLOR_WHITE);
                }
                return;
            }
        }
        dc.setPenWidth(1);

        // Actual App
        var now = Time.now().value();
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        var targetTideUnit = (tideUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var targetSwellUnit = (swellUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var tideColorIdx = Application.Properties.getValue("TideColor");
        var graphColorIdx = Application.Properties.getValue("GraphColor");
        var baseColorIdx = Application.Properties.getValue("BaseColor");
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph");
        var showSwellSummary = Application.Properties.getValue("ShowSwellSummary");
        var showDate = Application.Properties.getValue("ShowDate");
        var timeFormatVal = Application.Properties.getValue("TimeFormat");
        var use24Hour = (timeFormatVal == null || timeFormatVal == DataKeys.TIME_FORMAT_24_H);

        // Fallback size setup in case onLayout wasn't triggered
        if (mScreenWidth == 0) {
            onLayout(dc);
        }

        updateCacheAndCalculations(now, targetTideUnit, targetSwellUnit, use24Hour);

        var tideColor = getColorFromIndex(tideColorIdx != null ? tideColorIdx as Number : 0);
        var graphColor = getColorFromIndex(graphColorIdx != null ? graphColorIdx as Number : 0);
        var baseColor = getColorFromIndex(baseColorIdx != null ? baseColorIdx as Number : 4);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1. Draw Time/Battery (always rendered with current time)
        drawClock(dc, baseColor, use24Hour);
        drawBattery(dc, baseColor);

        // 2. Error Check
        var apiKey = Application.Properties.getValue("StormglassApiKey");
        var hasApiKey = (apiKey != null && apiKey instanceof String && !apiKey.equals(""));

        var gpsLat = Application.Properties.getValue("GpsLat");
        var gpsLon = Application.Properties.getValue("GpsLon");

        if (!LocationUtils.isLocationSetAndValid(gpsLat, gpsLon)) {
             if (showDate) {
                 drawDateCentered(dc, baseColor);
             }

             var msg = WatchUi.loadResource(Rez.Strings.NoSpotSelected) as String;
             if (mLastDataUpdatedAt > 0) {
                 msg += "\nLast sync: ";
                 var info = Gregorian.info(new Time.Moment(mLastDataUpdatedAt), Time.FORMAT_SHORT);
                 var hourAmPm = formatHourAmPm(info.hour, use24Hour, false);
                 msg += hourAmPm[0].format(use24Hour ? "%02d" : "%d") + ":" + info.min.format("%02d") + hourAmPm[1];
             }
             drawCenteredText(dc, mScreenHeight * 0.55, Graphics.FONT_XTINY, msg, baseColor);
             return;
        }

        if (mcTideData == null) {
            var msg = "Waiting for sync...\nFirst sync can take\nup to 15 minutes.";
            if (mSyncError != null) {
                if (mSyncError == DataKeys.ERROR_QUOTA_EXCEEDED) {
                    msg = "API Limit Reached";
                } else if (mSyncError == DataKeys.ERROR_NO_DATA) {
                    msg = "no tide data available";
                } else if (mSyncError <= DataKeys.ERROR_PHONE_CONN_MAX && mSyncError > DataKeys.ERROR_PHONE_CONN_MIN) {
                    msg = "no connection";
                } else {
                    msg = "sync error";
                }
            }
            var errColor = mSyncError != null ? Graphics.COLOR_RED : Graphics.COLOR_LT_GRAY;
            drawCenteredText(dc, mScreenHeight / 2, Graphics.FONT_XTINY, msg, errColor);
            return;
        }

        // Draw Current Tide Height and Date horizontally relative to each other
        drawTideAndDate(dc, tideColor, baseColor, showDate);

        if (mNextExtremaStr != null) {
            drawCenteredText(dc, mScreenHeight * 0.67, Graphics.FONT_XTINY, mNextExtremaStr, baseColor);
        }

        // Swell Section
        if (showSwellSummary) {
            drawSwellData(dc, baseColor, hasApiKey);
        }

        // Graph Section
        drawGraphs(dc, graphColor, baseColor, showSwellGraph, now);

        // Spot Name or Error
        var isStale = (now - mLastDataUpdatedAt > STALE_DATA_THRESHOLD_SEC);
        if (isStale && System.getDeviceSettings().phoneConnected && mSyncError != DataKeys.ERROR_QUOTA_EXCEEDED) {
            if (now - mLastSyncAttemptAt > 300) {
                mLastSyncAttemptAt = now;
                scheduleNextBackgroundEvent(null);
            }
        }

        drawFooter(dc, baseColor, now);
    }

    /**
     * Lazy updates storage values, extracts wave/tide data array limits, and processes extrema heights.
     * Calculates graphs min/max bounds and current tide levels.
     * @param now Current epoch timestamp.
     * @param targetTideUnit Unit system for tides (feet vs meters).
     * @param targetSwellUnit Unit system for swells (feet vs meters).
     * @param use24Hour Boolean indicating whether to format hours in 24h style.
     */
    function updateCacheAndCalculations(now as Number, targetTideUnit as Number, targetSwellUnit as Number, use24Hour as Boolean) as Void {
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        var tideColorIdx = Application.Properties.getValue("TideColor");
        var graphColorIdx = Application.Properties.getValue("GraphColor");
        var baseColorIdx = Application.Properties.getValue("BaseColor");
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph");
        var showSwellSummary = Application.Properties.getValue("ShowSwellSummary");
        var showDate = Application.Properties.getValue("ShowDate");

        var currentHash = (tideUnits == null ? 0 : tideUnits as Number) +
            ((swellUnits == null ? 0 : swellUnits as Number) << 2) +
            ((tideColorIdx == null ? 0 : tideColorIdx as Number) << 4) +
            ((graphColorIdx == null ? 0 : graphColorIdx as Number) << 8) +
            ((baseColorIdx == null ? 0 : baseColorIdx as Number) << 12) +
            ((showSwellGraph == true ? 1 : 0) << 16) +
            ((showSwellSummary == true ? 1 : 0) << 17) +
            ((showDate == true ? 1 : 0) << 18) +
            ((use24Hour ? 1 : 0) << 19);

        var dataUpdatedAt = Application.Storage.getValue("dataUpdatedAt") as Number?;
        if (dataUpdatedAt == null) { dataUpdatedAt = 0; }

        if (now - mLastLazyDataUpdate >= Constants.DATA_UPDATE_INTERVAL_SEC || currentHash != mLastSettingsHash || dataUpdatedAt != mLastDataUpdatedAt) {
            mLastLazyDataUpdate = now;
            mLastSettingsHash = currentHash;
            mLastDataUpdatedAt = dataUpdatedAt;

            mcTideData = Application.Storage.getValue("tideData") as Array?;

            mcTideExtrema = Application.Storage.getValue("tideExtrema") as Array?;
            mcWaveData = Application.Storage.getValue("waveData") as Array?;
            mcTideUnitApi = Application.Storage.getValue("tideUnitApi") as Number?;
            mcSwellUnitApi = Application.Storage.getValue("swellUnitApi") as Number?;
            mcSpotName = Application.Storage.getValue("spotName") as String?;
            mSyncError = Application.Storage.getValue("syncError") as Number?;
            mErrorAt = Application.Storage.getValue("errorAt") as Number?;
            mWeatherError = Application.Storage.getValue("weatherError") as Number?;
        }

        var stats = System.getSystemStats();
        mBattery = stats.battery;

        mCurrentHeight = 0.0;
        mIsRising = false;
        mNextExtremaStr = null;
        mValidSwells = [];
        mSwellTexts = [];
        mMinH = 9999.0;
        mMaxH = -9999.0;
        mMinSwellH = 9999.0;
        mMaxSwellH = -9999.0;
        mMinT = now - GRAPH_PAST_HOURS * Constants.SECONDS_IN_HOUR;
        mMaxT = now + GRAPH_FUTURE_HOURS * Constants.SECONDS_IN_HOUR;

        if (mcTideData != null && mcTideData.size() > 0) {
            var found = false;
            var currWaveIdx = -1;
            var tDataArray = mcTideData as Array;
            for (var i = 0; i < tDataArray.size() - 1; i++) {
                var p1 = tDataArray[i] as Array;
                var p2 = tDataArray[i + 1] as Array;
                var t1 = p1[0] as Number;
                var t2 = p2[0] as Number;
                if (now >= t1 && now <= t2) {
                    var h1 = convertHeight(p1[1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                    var h2 = convertHeight(p2[1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                    var ratio = (now - t1).toFloat() / (t2 - t1).toFloat();
                    mCurrentHeight = h1 + (h2 - h1) * ratio;
                    mIsRising = h2 > h1;
                    currWaveIdx = i;
                    found = true;
                    break;
                }
            }
            if (!found) {
                var pFirst = tDataArray[0] as Array;
                var pLast = tDataArray[tDataArray.size() - 1] as Array;
                if (now < (pFirst[0] as Number)) {
                    mCurrentHeight = convertHeight(pFirst[1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                    currWaveIdx = 0;
                } else {
                    mCurrentHeight = convertHeight(pLast[1] as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                    currWaveIdx = tDataArray.size() - 1;
                }
            }

            var dispHeight = convertHeight((mCurrentHeight * 100).toNumber(), DataKeys.UNIT_METER, targetTideUnit);
            mDispUnit = (targetTideUnit == DataKeys.UNIT_FEET) ? "ft" : "m";
            mTideNumStr = dispHeight.format("%.2f");

            if (mcTideExtrema != null && mcTideExtrema instanceof Array) {
                for (var i = 0; i < mcTideExtrema.size(); i++) {
                    var ext = mcTideExtrema[i] as Array?;
                    if (ext == null) {
                        System.println("invalid data for tide extrema");
                        break;
                    }
                    if (ext[0] > now) {
                        var extTs = ext[0] as Number;
                        var rawExtH = ext[1] as Number;
                        var typeCode = ext[2];
                        var extType = (typeCode == DataKeys.TIDE_TYPE_HIGH) ? "High" : "Low";
                        var extInfo = Gregorian.info(new Time.Moment(extTs.toNumber()), Time.FORMAT_SHORT);
                        var hourAmPm = formatHourAmPm(extInfo.hour, use24Hour, false);
                        var extTimeStr = Lang.format("$1$:$2$$3$", [hourAmPm[0].format(use24Hour ? "%02d" : "%d"), extInfo.min.format("%02d"), hourAmPm[1]]);
                        var dispExtH = convertHeight(rawExtH, mcTideUnitApi, targetTideUnit);
                        mNextExtremaStr = Lang.format("$1$: $2$$3$ $4$", [extType, dispExtH.format("%.2f"), mDispUnit, extTimeStr]);
                        break;
                    }
                }
            }

            if (mcWaveData != null) {
                var waveDataArray = mcWaveData as Array;
                var currentWave = null;
                
                // Find the swell data point closest in time to 'now'
                var minDiff = 9999999;
                for (var i = 0; i < waveDataArray.size(); i++) {
                    var wPoint = waveDataArray[i];
                    if (wPoint != null && wPoint instanceof Array && wPoint.size() > 6 && wPoint[6] != null) {
                        var wTs = wPoint[6] as Number;
                        var diff = now - wTs;
                        if (diff < 0) {
                            diff = -diff;
                        }
                        if (diff < minDiff) {
                            minDiff = diff;
                            currentWave = wPoint;
                        }
                    }
                }
                
                // Fallback to index-based matching if no timestamps are available in the data
                if (currentWave == null && waveDataArray.size() > 0) {
                    if (currWaveIdx >= 0 && currWaveIdx < waveDataArray.size()) {
                        currentWave = waveDataArray[currWaveIdx];
                    } else {
                        var firstTide = tDataArray[0] as Array;
                        if (firstTide != null && firstTide.size() > 0 && now < (firstTide[0] as Number)) {
                            currentWave = waveDataArray[0];
                        } else {
                            currentWave = waveDataArray[waveDataArray.size() - 1];
                        }
                    }
                }

                if (currentWave != null && currentWave instanceof Array && currentWave.size() >= 6) {
                    for (var s = 0; s < 2; s++) {
                        var h = currentWave[s*3];
                        var hvRaw = 0;
                        if (h != null) {
                            hvRaw = (h instanceof Number) ? h as Number : (h as Float).toNumber();
                        }
                        
                        var pVal = currentWave[s*3+1];
                        var pValNum = 0;
                        if (pVal != null) {
                            pValNum = (pVal instanceof Number) ? pVal as Number : (pVal as Float).toNumber();
                        }
                        
                        var dVal = currentWave[s*3+2];
                        var dValFloat = 0.0;
                        if (dVal != null) {
                            dValFloat = (dVal instanceof Number) ? (dVal as Number).toFloat() : dVal as Float;
                        }
                        
                        if (hvRaw > 0 && pValNum > 0) {
                            mValidSwells.add([hvRaw, pValNum, dValFloat]);
                            
                            var dispH = convertHeight(hvRaw, mcSwellUnitApi, targetSwellUnit);
                            var unit = (targetSwellUnit == DataKeys.UNIT_FEET) ? "ft" : "m";
                            var sStr = dispH.format("%.1f") + unit + "@" + pValNum.toString();
                            mSwellTexts.add(sStr);
                        }
                    }
                }
            }

            for (var i = 0; i < tDataArray.size(); i++) {
                var p = tDataArray[i] as Array;
                var tTs = p[0] as Number;
                if (tTs >= mMinT - Constants.SECONDS_IN_HOUR && tTs <= mMaxT + Constants.SECONDS_IN_HOUR) {
                    var h = p[1];
                    if (h != null) {
                        var hFloat = convertHeight(h as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        if (hFloat < mMinH) { mMinH = hFloat; }
                        if (hFloat > mMaxH) { mMaxH = hFloat; }
                    }
                }
            }
            
            if (mMinH == 9999.0) { mMinH = 0.0; mMaxH = 1.0; }
            if (mMaxH == mMinH) { mMaxH = mMinH + 1.0; }
            
            if (mcWaveData != null && mcWaveData instanceof Array) {
                var wDataArray = mcWaveData as Array;
                for (var i = 0; i < wDataArray.size(); i++) {
                    var wPoint = wDataArray[i];
                    if (wPoint != null && wPoint instanceof Array && wPoint.size() >= 6) {
                        var wTs = (wPoint.size() > 6 && wPoint[6] != null) ? wPoint[6] as Number : null;
                        if (wTs != null && wTs >= mMinT - Constants.SECONDS_IN_HOUR && wTs <= mMaxT + Constants.SECONDS_IN_HOUR) {
                            for (var s = 0; s < 2; s++) {
                                var hVal = wPoint[s*3];
                                var pVal = wPoint[s*3+1];
                                var hv = 0;
                                if (hVal != null) {
                                    hv = (hVal instanceof Number) ? hVal as Number : (hVal as Float).toNumber();
                                }
                                var pv = 0;
                                if (pVal != null) {
                                    pv = (pVal instanceof Number) ? pVal as Number : (pVal as Float).toNumber();
                                }
                                if (hv > 0 && pv > 0) {
                                    var h = convertHeight(hv, mcSwellUnitApi, DataKeys.UNIT_METER);
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

    /**
     * Renders battery percentage number and status layout outline.
     * @param dc The device context.
     * @param baseColor Numeric color code for regular drawing.
     */
    function drawBattery(dc as Dc, baseColor as Number) as Void {
        var x = mScreenWidth / 2;
        var y = (mScreenHeight * 0.08).toNumber();
        var width = (24 * mScale).toNumber();
        var height = (12 * mScale).toNumber();
        var tipWidth = (2 * mScale).toNumber();
        var tipHeight = (6 * mScale).toNumber();
        var margin = (2 * mScale).toNumber();
        var fillWidth = ((width - margin * 2) * (mBattery / 100.0)).toNumber();
        if (fillWidth < 0) {
            fillWidth = 0;
        }

        var color = baseColor;
        if (mBattery < 10.0) {
            color = Graphics.COLOR_RED;
        } else if (mBattery < 20.0) {
            color = Graphics.COLOR_YELLOW;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        
        // Draw percentage text
        var percStr = mBattery.toNumber().toString() + "%";
        dc.drawText(x - (2 * mScale).toNumber(), y, Graphics.FONT_XTINY, percStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // Draw battery outline
        var iconX = x + (2 * mScale).toNumber();
        var iconY = y - height / 2;
        
        dc.drawRectangle(iconX, iconY, width, height);
        dc.fillRectangle(iconX + width, iconY + (height - tipHeight) / 2, tipWidth, tipHeight);

        // Fill battery level
        if (fillWidth > 0) {
            dc.fillRectangle(iconX + margin, iconY + margin, fillWidth, height - margin * 2);
        }
    }

    /**
     * Renders current digital clock format and AM/PM labels relative to center.
     * @param dc The device context.
     * @param baseColor Color of base text.
     * @param use24Hour True for 24-hour style format.
     */
    function drawClock(dc as Dc, baseColor as Number, use24Hour as Boolean) as Void {
        var clockTime = System.getClockTime();
        var hourAmPmVal = formatHourAmPm(clockTime.hour, use24Hour, true);
        var clockHour = hourAmPmVal[0];
        var clockAmPm = hourAmPmVal[1] as String;
        var timeStr = Lang.format("$1$:$2$", [clockHour.format(use24Hour ? "%02d" : "%d"), clockTime.min.format("%02d")]);
        dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        
        var timeY = mScreenHeight * 0.24;
        if (clockAmPm.length() > 0) {
            var timeWidth = dc.getTextWidthInPixels(timeStr, Graphics.FONT_NUMBER_HOT);
            var amPmWidth = dc.getTextWidthInPixels(clockAmPm, Graphics.FONT_XTINY);
            var gap = (2 * mScale).toNumber();
            var totalW = timeWidth + gap + amPmWidth;
            var startX = (mScreenWidth - totalW) / 2;
            
            dc.drawText(startX, timeY, Graphics.FONT_NUMBER_HOT, timeStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + timeWidth + gap, timeY - (8 * mScale), Graphics.FONT_XTINY, clockAmPm, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            drawCenteredText(dc, timeY, Graphics.FONT_NUMBER_HOT, timeStr, baseColor);
        }
    }

    /**
     * Renders a centered date and day string. Used as fallback when GPS is not active.
     * @param dc The device context.
     * @param baseColor Numeric color code.
     */
    function drawDateCentered(dc as Dc, baseColor as Number) as Void {
        var dateStr = getDay() + ", " + getDate();
        drawCenteredText(dc, mScreenHeight * 0.38, Graphics.FONT_XTINY, dateStr, baseColor);
    }

    /**
     * Renders current tide elevation value and rising/falling indicator arrow horizontally
     * aligned alongside day and date text.
     * @param dc The device context.
     * @param tideColor Color for drawing tide numeric indicators.
     * @param baseColor Color of base text.
     * @param showDate True to render the adjacent date and day strings.
     */
    function drawTideAndDate(dc as Dc, tideColor as Number, baseColor as Number, showDate as Boolean) as Void {
        var numWidth = dc.getTextWidthInPixels(mTideNumStr, Graphics.FONT_NUMBER_MEDIUM);
        var mWidth = dc.getTextWidthInPixels(mDispUnit, Graphics.FONT_MEDIUM);
        var startX = (mScreenWidth - (numWidth + mWidth)) / 2;

        dc.setColor(tideColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, mScreenHeight * 0.44, Graphics.FONT_NUMBER_MEDIUM, mTideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth, mScreenHeight * 0.44, Graphics.FONT_MEDIUM, mDispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawArrow(dc, (startX + numWidth + mWidth + 15 * mScale).toNumber(), (mScreenHeight * 0.44).toNumber(), mIsRising);

        if (showDate) {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(startX - 4 * mScale, (mScreenHeight * 0.38) + 1, Graphics.FONT_XTINY, getDate(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + numWidth + mWidth + 30 * mScale, (mScreenHeight * 0.38) + 1, Graphics.FONT_XTINY, getDay(), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    /**
     * Renders current swell data summaries (primary & secondary height, periods, directions).
     * @param dc The device context.
     * @param baseColor Default color of text.
     * @param hasApiKey True if a Stormglass API key is supplied.
     */
    function drawSwellData(dc as Dc, baseColor as Number, hasApiKey as Boolean) as Void {
        if (!hasApiKey) {
            drawCenteredText(dc, mScreenHeight * 0.58, Graphics.FONT_XTINY, "no stormglass.io key", baseColor);
        } else if (mWeatherError == DataKeys.ERROR_INVALID_KEY) {
            drawCenteredText(dc, mScreenHeight * 0.58, Graphics.FONT_XTINY, "stormglass key invalid", Graphics.COLOR_RED);
        } else if (mWeatherError == DataKeys.ERROR_QUOTA_EXCEEDED) {
            drawCenteredText(dc, mScreenHeight * 0.58, Graphics.FONT_XTINY, "swell API limit reached", Graphics.COLOR_RED);
        } else if (mWeatherError == DataKeys.ERROR_OTHER) {
            drawCenteredText(dc, mScreenHeight * 0.58, Graphics.FONT_XTINY, "swell sync error", Graphics.COLOR_RED);
        } else if (mValidSwells.size() > 0) {
            var totalSwellW = 0;
            var arrowW = (10 * mScale).toNumber();
            var pad = (3 * mScale).toNumber();
            var sepW = dc.getTextWidthInPixels(" | ", Graphics.FONT_XTINY);
            for (var i = 0; i < mValidSwells.size(); i++) {
                totalSwellW += arrowW + pad + dc.getTextWidthInPixels(mSwellTexts[i] as String, Graphics.FONT_XTINY);
            }
            totalSwellW += (mValidSwells.size() - 1) * sepW;

            var curX = (mScreenWidth - totalSwellW) / 2;
            var curY = (mScreenHeight * 0.57).toNumber();
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
            drawCenteredText(dc, mScreenHeight * 0.58, Graphics.FONT_XTINY, "no swell data available", baseColor);
        }
    }

    /**
     * Draws the main tide elevation curve and optionally overlays swell metrics.
     * Places a red dot representing current time on the timeline grid.
     * @param dc The device context.
     * @param graphColor Color of tide line graph.
     * @param baseColor Color of swell layers and helper layouts.
     * @param showSwellGraph True if the swell graph layer is active.
     * @param now Current epoch timestamp.
     */
    function drawGraphs(dc as Dc, graphColor as Number, baseColor as Number, showSwellGraph as Boolean, now as Number) as Void {
        if (mMaxH > mMinH) {
            var graphY = mScreenHeight * 0.88;
            var graphHeight = mScreenHeight * 0.18;
            var graphMargin = mScreenWidth * 0.15;
            var drawWidth = mScreenWidth - 2 * graphMargin;

            // Swell Graph
            if (showSwellGraph && mcWaveData != null && mcWaveData instanceof Array) {
                var colors = [baseColor, baseColor, baseColor];
                for (var s = 0; s < 2; s++) {
                    var lastSX = -1, lastSY = -1;
                    var waveDataArray = mcWaveData as Array;
                    for (var i = 0; i < waveDataArray.size(); i++) {
                        var wPoint = waveDataArray[i];
                        if (wPoint == null || !(wPoint instanceof Array) || wPoint.size() < 6) { 
                            lastSX = -1; 
                            continue; 
                        }
                        var hVal = wPoint[s*3];
                        var pVal = wPoint[s*3+1];
                        var hv = 0;
                        if (hVal != null) {
                            hv = (hVal instanceof Number) ? hVal as Number : (hVal as Float).toNumber();
                        }
                        var pv = 0;
                        if (pVal != null) {
                            pv = (pVal instanceof Number) ? pVal as Number : (pVal as Float).toNumber();
                        }
                        
                        if (hv <= 0 || pv <= 0) { 
                            lastSX = -1; 
                            continue; 
                        }
                        
                        var wTs = (wPoint.size() > 6 && wPoint[6] != null) ? wPoint[6] as Number : null;
                        if (wTs != null) {
                            var h = convertHeight(hv, mcSwellUnitApi, DataKeys.UNIT_METER);
                            var sx = graphMargin + drawWidth * (wTs - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
                            var sy = graphY - graphHeight * (h - mMinSwellH) / (mMaxSwellH - mMinSwellH);
                            if (lastSX >= 0 && (sx >= -50 && sx <= mScreenWidth + 50)) {
                                dc.setColor(colors[s], Graphics.COLOR_TRANSPARENT);
                                dc.drawLine(lastSX, lastSY, sx.toNumber(), sy.toNumber());
                                if (s == 0) { dc.drawLine(lastSX, lastSY+1, sx.toNumber(), sy.toNumber()+1); dc.drawLine(lastSX, lastSY-1, sx.toNumber(), sy.toNumber()-1); }
                            }
                            lastSX = sx.toNumber(); lastSY = sy.toNumber();
                        } else {
                            lastSX = -1;
                        }
                    }
                }
            }

            // Tide Graph
            dc.setColor(graphColor, Graphics.COLOR_TRANSPARENT);
            var lastX = -1, lastY = -1;
            if (mcTideData != null) {
                var tDataArray = mcTideData as Array;
                for (var i = 0; i < tDataArray.size(); i++) {
                    var p = tDataArray[i] as Array;
                    var tTs = p[0] as Number;
                    var x = graphMargin + drawWidth * (tTs - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
                    var hVal = p[1];
                    if (hVal != null) {
                        var hFloat = convertHeight(hVal as Number, mcTideUnitApi, DataKeys.UNIT_METER);
                        var y = graphY - graphHeight * (hFloat - mMinH) / (mMaxH - mMinH);
                        if (lastX >= 0 && (x >= -50 && x <= mScreenWidth + 50)) {
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
            if (nowX >= 0 && nowX <= mScreenWidth) {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
                var markerY = graphY - graphHeight * (mCurrentHeight - mMinH) / (mMaxH - mMinH);
                dc.fillCircle(nowX.toNumber(), markerY.toNumber(), (6 * mScale).toNumber());
            }
        }
    }

    /**
     * Renders the spot name or sync errors at the bottom footer of the display.
     * @param dc The device context.
     * @param baseColor Numeric color code for standard drawing.
     * @param now Current timestamp.
     */
    function drawFooter(dc as Dc, baseColor as Number, now as Number) as Void {
        var isStale = (now - mLastDataUpdatedAt > STALE_DATA_THRESHOLD_SEC);
        var showSyncError = (mSyncError != null && mErrorAt != null && (now - mErrorAt < ERROR_DISPLAY_WINDOW_SEC));

        if (showSyncError) {
            var errMsg = "sync error";
            var errColor = Graphics.COLOR_RED;
            if (mSyncError != null && mSyncError == DataKeys.ERROR_QUOTA_EXCEEDED) {
                errMsg = "API Limit Reached";
            } else if (mSyncError != null && mSyncError <= DataKeys.ERROR_PHONE_CONN_MAX && mSyncError > DataKeys.ERROR_PHONE_CONN_MIN) {
                errMsg = "no connection";
            }
            drawCenteredText(dc, mScreenHeight * 0.95, Graphics.FONT_XTINY, errMsg, errColor);
        } else if (mcSpotName != null) {
            var nameColor = baseColor;
            if (isStale || mSyncError != null) {
                nameColor = Graphics.COLOR_YELLOW;
            }
            drawCenteredText(dc, mScreenHeight * 0.95, Graphics.FONT_XTINY, mcSpotName as String, nameColor);
        }
    }

    /**
     * Draws a simple up or down arrow representing rising or falling tide heights.
     * @param dc The device context.
     * @param x Centered horizontal coordinate.
     * @param y Vertical center coordinate.
     * @param isRising True for up (rising); false for down (falling).
     */
    function drawArrow(dc as Dc, x as Number, y as Number, isRising as Boolean) as Void {
        var sz = (8 * mScale).toNumber();
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

    /**
     * Draws an arrow polygon pointing in the direction the swell is moving.
     * @param dc The device context.
     * @param x Center coordinate.
     * @param y Center coordinate.
     * @param direction Degree angle representing swell heading direction.
     */
    function drawSwellArrow(dc as Dc, x as Number, y as Number, direction as Float) as Void {
        var rad = (direction + 180.0) * Math.PI / 180.0;
        var cos = Math.cos(rad);
        var sin = Math.sin(rad);
        
        var xf = x.toFloat();
        var yf = y.toFloat();
        
        var px = 0.0; var py = -5.0 * mScale;
        var p0x = xf + px*cos - py*sin; var p0y = yf + px*sin + py*cos;
        px = -3.5 * mScale; py = 3.5 * mScale;
        var p1x = xf + px*cos - py*sin; var p1y = yf + px*sin + py*cos;
        px = 3.5 * mScale; py = 3.5 * mScale;
        var p2x = xf + px*cos - py*sin; var p2y = yf + px*sin + py*cos;
        
        var pts = [
            [p0x, p0y],
            [p1x, p1y],
            [p2x, p2y]
        ];
        dc.fillPolygon(pts as Array<[Lang.Numeric, Lang.Numeric]>);
    }

    /**
     * Converts a setting index to a Garmin Graphics COLOR_* constant or custom hex value.
     * @param idx The color property setting index.
     * @return Color hex integer.
     */
    function getColorFromIndex(idx as Number) as Number {
        if (idx == DataKeys.SETTING_COLOR_PINK) { return Graphics.COLOR_PINK; }
        if (idx == DataKeys.SETTING_COLOR_RED) { return Graphics.COLOR_RED; }
        if (idx == DataKeys.SETTING_COLOR_GREEN) { return Graphics.COLOR_GREEN; }
        if (idx == DataKeys.SETTING_COLOR_WHITE) { return Graphics.COLOR_WHITE; }
        if (idx == DataKeys.SETTING_COLOR_YELLOW) { return Graphics.COLOR_YELLOW; }
        if (idx == DataKeys.SETTING_COLOR_ORANGE) { return Graphics.COLOR_ORANGE; }
        if (idx == DataKeys.SETTING_COLOR_PURPLE) { return Graphics.COLOR_PURPLE; }
        if (idx == DataKeys.SETTING_COLOR_LT_GRAY) { return Graphics.COLOR_LT_GRAY; }
        if (idx == DataKeys.SETTING_COLOR_DK_GRAY) { return Graphics.COLOR_DK_GRAY; }
        if (idx == DataKeys.SETTING_COLOR_LIGHT_BLUE) { return 0x55AAFF; } // Light Blue
        if (idx == DataKeys.SETTING_COLOR_PETROL) { return 0x005F6B; } // Petrol
        if (idx == DataKeys.SETTING_COLOR_TURQUOISE) { return 0x00CCCC; } // Turquoise
        return Graphics.COLOR_BLUE; // Default/0
    }

    /**
     * Formats hours for AM/PM layout or 24-hour style format.
     * @param hour The hour value (0-23).
     * @param use24Hour True for 24h format; false for 12h format.
     * @param upperCase True to capitalize AM/PM suffix labels.
     * @return Array containing [hour_number, am_pm_suffix_string].
     */
    function formatHourAmPm(hour as Number, use24Hour as Boolean, upperCase as Boolean) as Array {
        var amPm = "";
        if (!use24Hour) {
            if (hour >= 12) {
                amPm = upperCase ? "PM" : "pm";
                if (hour > 12) { hour -= 12; }
            } else {
                amPm = upperCase ? "AM" : "am";
                if (hour == 0) { hour = 12; }
            }
        }
        return [hour, amPm];
    }

    /**
     * Resolves the current formatted date string (e.g. "23 May").
     * @return Formatted date string.
     */
    function getDate() as String {
        var todayMed = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return todayMed.day.format("%d") + " " + todayMed.month;
    }

    /**
     * Resolves the current formatted weekday string (e.g. "Saturday").
     * @return Active day-of-week string.
     */
    function getDay() as String {
        var todayLong = Gregorian.info(Time.now(), Time.FORMAT_LONG);
        return todayLong.day_of_week;
    }

    /**
     * Utility method to draw centered text layouts using custom fonts and colors.
     * @param dc The device context.
     * @param y Vertical center offset.
     * @param font The active Garmin font face.
     * @param text String label to draw.
     * @param color Graphics color to apply.
     */
    function drawCenteredText(dc as Dc, y as Lang.Numeric, font, text as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(mScreenWidth / 2, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    /**
     * Converts a raw rawValue elevation between meter/feet metrics using calibration ratios.
     * @param rawValue The raw elevation value (multiplied by 100).
     * @param apiUnit Source API unit code.
     * @param targetUnit Output target unit code.
     * @return Correctly calibrated float value.
     */
    function convertHeight(rawValue as Number, apiUnit as Number?, targetUnit as Number) as Float {
        if (targetUnit != DataKeys.UNIT_METER && targetUnit != DataKeys.UNIT_FEET) {
            System.println("Invalid target unit: " + targetUnit);
        }
        var valFloat = rawValue.toFloat() / 100.0;
        if (apiUnit == null) { return valFloat; } // Assume already correct if unknown
        
        // API is Meters (18), Target is Feet (19)
        if (apiUnit == DataKeys.UNIT_METER && targetUnit == DataKeys.UNIT_FEET) {
            return valFloat * METERS_TO_FEET;
        }
        // API is Feet (19), Target is Meters (18)
        if (apiUnit == DataKeys.UNIT_FEET && targetUnit == DataKeys.UNIT_METER) {
            return valFloat / METERS_TO_FEET;
        }
        return valFloat;
    }
}
