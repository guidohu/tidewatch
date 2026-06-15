import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
using KPayClock.KPay as KPay;

var kpay as KPay.Core?;

class TideWatchView extends WatchUi.WatchFace {

    var mLastGpsLat;
    var mLastGpsLon;
    var mLastDatum;
    var mLastApiKey;

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

    var mCachedGraphBitmap as Graphics.BufferedBitmap? = null;
    var mLastGraphUpdateMinute as Number = -1;
    var mLastPowerMode as Boolean = false;
    var mLastGraphHash as Number = 0;

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

    var mcTideData as Array<Array<Number>>? = null;

    var mcTideExtrema as Array<Array<Number>>? = null;
    var mcWaveData as Array<Array<Number?>>? = null;
    var mcTideUnitApi as Number? = null;
    var mcSwellUnitApi as Number? = null;
    var mcSpotName as String? = null;
    var mSyncError as Number? = null;
    var mErrorAt as Number? = null;
    var mWeatherError as Number? = null;

    var mScreenWidth as Number = 0;
    var mScreenHeight as Number = 0;
    var mScale as Float = 1.0;
    var mFontAssistantSmall as Graphics.FontDefinition? = null;
    var mInLowPowerMode as Boolean = false;
    var mTimeFont = null;

    /**
     * Constructor. Calls parent WatchFace constructor.
     */
    function initialize() {
        WatchFace.initialize();

        foregroundAppDelegate = self;

        getOrCreateAnonymousIdentifier();
        migrateSettings();

        var forecastWindow = Application.loadResource(Rez.Strings.ForecastWindow) as String;
        var forecastWindowSec = 48 * 3600;
        var forecastStartOffsetSec = 4 * 3600;
        if (forecastWindow.equals("short") || forecastWindow.equals("small")) {
            forecastWindowSec = 12 * 3600;
            forecastStartOffsetSec = 4 * 3600;
        }
        AppStorage.setForecastWindowSec(forecastWindowSec);
        AppStorage.setForecastStartOffsetSec(forecastStartOffsetSec);

        mLastGpsLat = Application.Properties.getValue("GpsLat");
        mLastGpsLon = Application.Properties.getValue("GpsLon");
        mLastDatum = Application.Properties.getValue("TideDatum");
        mLastApiKey = Application.Properties.getValue("StormglassApiKey");

        initializeKPay(true);
    }

    /**
     * Terminate hourly/periodic updates when entering low power sleep mode.
     */
    function onEnterSleep() as Void {
        mInLowPowerMode = true;
        WatchUi.requestUpdate();
    }

    /**
     * Restore standard rendering updates when leaving low power sleep mode.
     */
    function onExitSleep() as Void {
        mInLowPowerMode = false;
        WatchUi.requestUpdate();
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
        mFontAssistantSmall = WatchUi.loadResource(Rez.Fonts.AssistantSmall) as Graphics.FontDefinition;
        mTimeFont = WatchUi.loadResource(Rez.Strings.time_font);
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
                    return;
                }
            }
        }
        dc.setPenWidth(1);

        // Actual App
        var now = Time.now().value();
        var tideUnits = Application.Properties.getValue("TideUnits");
        var swellUnits = Application.Properties.getValue("SwellUnits");
        var targetTideUnit = (tideUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var targetSwellUnit = (swellUnits == DataKeys.SETTING_UNIT_FEET) ? DataKeys.UNIT_FEET : DataKeys.UNIT_METER;
        var tideColorIdx = Application.Properties.getValue("TideColor") as Lang.Number;
        var graphColorIdx = Application.Properties.getValue("GraphColor") as Lang.Number;
        var baseColorIdx = Application.Properties.getValue("BaseColor") as Lang.Number;
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        var showSwellSummary = Application.Properties.getValue("ShowSwellSummary");
        var showDate = Application.Properties.getValue("ShowDate");
        var timeFormatVal = Application.Properties.getValue("TimeFormat");
        var use24Hour = timeFormatVal == DataKeys.TIME_FORMAT_24_H;

        // Fallback size setup in case onLayout wasn't triggered
        if (mScreenWidth == 0) {
            onLayout(dc);
        }

        updateCacheAndCalculations(now, targetTideUnit, targetSwellUnit, use24Hour);

        var tideColor = getColorFromIndex(tideColorIdx);
        var graphColor = getColorFromIndex(graphColorIdx);
        var baseColor = getColorFromIndex(baseColorIdx);

        if (mInLowPowerMode) {
            tideColor = blendWithBlack(tideColor, 0.95);
            graphColor = blendWithBlack(graphColor, 0.95);
            baseColor = blendWithBlack(baseColor, 0.85);
        }

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 1. Draw Time/Battery (always rendered with current time)
        drawClock(dc, baseColor, use24Hour);
        if (!mInLowPowerMode) {
            drawBattery(dc, baseColor);
        }

        // 2. Error Check
        var apiKey = Application.Properties.getValue("StormglassApiKey") as String;
        var hasApiKey = (!apiKey.equals(""));

        var gpsLat = Application.Properties.getValue("GpsLat") as Numeric or String or Null;
        var gpsLon = Application.Properties.getValue("GpsLon") as Numeric or String or Null;

        if (!LocationUtils.isLocationSetAndValid(gpsLat, gpsLon)) {
             if (showDate || mInLowPowerMode) {
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
            if (mInLowPowerMode) {
                errColor = blendWithBlack(errColor, 0.95);
            }
            drawCenteredText(dc, mScreenHeight / 2, Graphics.FONT_XTINY, msg, errColor);
            return;
        }

        // Draw Date/Day centered just below time
        if (showDate || mInLowPowerMode) {
            drawDateCentered(dc, baseColor);
        }

        // Swell Section
        if (showSwellSummary && !mInLowPowerMode) {
            drawSwellData(dc, baseColor, hasApiKey);
        }

        // Graph Section
        drawGraphs(dc, graphColor, baseColor, showSwellGraph, now);

        // Tide Change Text (drawn on top of the graph with a cutout background)
        drawTideChangeText(dc, tideColor, baseColor, mScreenHeight * 0.64 + 58 * mScale);

        // Next Extrema (drawn below the graph)
        if (mNextExtremaStr != null && !mInLowPowerMode) {
            var nextExtrema = mNextExtremaStr as String;
            var font = Graphics.FONT_XTINY;
            drawCenteredText(dc, mScreenHeight * 0.81 + 30 * mScale, font, nextExtrema, baseColor);
        }

        // Spot Name or Error
        var isStale = (now - mLastDataUpdatedAt > STALE_DATA_THRESHOLD_SEC);
        if (isStale && System.getDeviceSettings().phoneConnected && mSyncError != DataKeys.ERROR_QUOTA_EXCEEDED) {
            if (now - mLastSyncAttemptAt > 300) {
                mLastSyncAttemptAt = now;
                scheduleNextBackgroundEvent(null);
            }
        }

        if (!mInLowPowerMode) {
            drawFooter(dc, baseColor, now);
        }
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
        var tideUnits = Application.Properties.getValue("TideUnits") as Number;
        var swellUnits = Application.Properties.getValue("SwellUnits") as Number;
        var tideColorIdx = Application.Properties.getValue("TideColor") as Number;
        var graphColorIdx = Application.Properties.getValue("GraphColor") as Number;
        var baseColorIdx = Application.Properties.getValue("BaseColor") as Number;
        var showSwellGraph = Application.Properties.getValue("ShowSwellGraph") as Boolean;
        var showSwellSummary = Application.Properties.getValue("ShowSwellSummary") as Boolean;
        var showDate = Application.Properties.getValue("ShowDate") as Boolean;

        var currentHash = tideUnits +
            (swellUnits << 2) +
            (tideColorIdx << 4) +
            (graphColorIdx << 8) +
            (baseColorIdx << 12) +
            ((showSwellGraph == true ? 1 : 0) << 16) +
            ((showSwellSummary == true ? 1 : 0) << 17) +
            ((showDate == true ? 1 : 0) << 18) +
            ((use24Hour == true ? 1 : 0) << 19);

        var dataUpdatedAt = AppStorage.getDataUpdatedAt();

        if (now - mLastLazyDataUpdate >= Constants.DATA_UPDATE_INTERVAL_SEC || currentHash != mLastSettingsHash || dataUpdatedAt != mLastDataUpdatedAt) {
            mLastLazyDataUpdate = now;
            mLastSettingsHash = currentHash;
            mLastDataUpdatedAt = dataUpdatedAt;

            mcTideData = AppStorage.getTideData();

            mcTideExtrema = AppStorage.getTideExtrema();
            mcWaveData = AppStorage.getWaveData();
            mcTideUnitApi = AppStorage.getTideUnitApi();
            mcSwellUnitApi = AppStorage.getSwellUnitApi();
            mcSpotName = AppStorage.getSpotName();
            mSyncError = AppStorage.getSyncError();
            mErrorAt = AppStorage.getErrorAt();
            mWeatherError = AppStorage.getWeatherError();
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
            var currWaveIdx = findCurrentTideState(now, targetTideUnit);
            findNextExtrema(now, targetTideUnit, use24Hour);
            findCurrentSwell(now, targetSwellUnit, currWaveIdx);
            calculateGraphBounds();
        }
    }

    function findCurrentTideState(now as Number, targetTideUnit as Number) as Number {
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
        mTideNumStr = (targetTideUnit == DataKeys.UNIT_FEET) ? dispHeight.format("%.1f") : dispHeight.format("%.2f");
        
        return currWaveIdx;
    }

    function findNextExtrema(now as Number, targetTideUnit as Number, use24Hour as Boolean) as Void {
        if (mcTideExtrema != null) {
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
                    var formatStr = (targetTideUnit == DataKeys.UNIT_FEET) ? "%.1f" : "%.2f";
                    mNextExtremaStr = Lang.format("$1$: $2$$3$ $4$", [extType, dispExtH.format(formatStr), mDispUnit, extTimeStr]);
                    break;
                }
            }
        }
    }

    function findCurrentSwell(now as Number, targetSwellUnit as Number, currWaveIdx as Number) as Void {
        if (mcWaveData != null) {
            var waveDataArray = mcWaveData as Array;
            var currentWave = null;
            
            var minDiff = 9999999;
            for (var i = 0; i < waveDataArray.size(); i++) {
                var wPoint = waveDataArray[i];
                if (wPoint != null && wPoint instanceof Array && wPoint.size() > 6 && wPoint[6] != null) {
                    var wTs = wPoint[6] as Number;
                    var diff = now - wTs;
                    if (diff < 0) { diff = -diff; }
                    if (diff < minDiff) {
                        minDiff = diff;
                        currentWave = wPoint;
                    }
                }
            }
            
            if (currentWave == null && waveDataArray.size() > 0) {
                if (currWaveIdx >= 0 && currWaveIdx < waveDataArray.size()) {
                    currentWave = waveDataArray[currWaveIdx];
                } else {
                    var tDataArray = mcTideData as Array;
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
    }

    function calculateGraphBounds() as Void {
        var tDataArray = mcTideData as Array;
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
        
        if (mcWaveData != null) {
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
        var font = (mFontAssistantSmall != null) ? mFontAssistantSmall : Graphics.FONT_XTINY;
        dc.drawText(x - (2 * mScale).toNumber(), y, font, percStr, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

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
        
        var font = Graphics.FONT_NUMBER_HOT;
        if (mTimeFont != null && mTimeFont.equals("medium")) {
            font = Graphics.FONT_NUMBER_MEDIUM;
        }
        var timeY = mScreenHeight * 0.24 - 5 * mScale;
        if (clockAmPm.length() > 0) {
            var timeWidth = dc.getTextWidthInPixels(timeStr, font);
            var amPmWidth = dc.getTextWidthInPixels(clockAmPm, Graphics.FONT_XTINY);
            var gap = (2 * mScale).toNumber();
            var totalW = timeWidth + gap + amPmWidth;
            var startX = (mScreenWidth - totalW) / 2;
            
            dc.drawText(startX, timeY, font, timeStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + timeWidth + gap, timeY - (8 * mScale), Graphics.FONT_XTINY, clockAmPm, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            drawCenteredText(dc, timeY, font, timeStr, baseColor);
        }
    }

    /**
     * Renders a centered date and day string. Used as fallback when GPS is not active.
     * @param dc The device context.
     * @param baseColor Numeric color code.
     */
    function drawDateCentered(dc as Dc, baseColor as Number) as Void {
        var dateStr = getDay() + ", " + getDate();
        drawCenteredText(dc, mScreenHeight * 0.38 - 5 * mScale, Graphics.FONT_XTINY, dateStr, baseColor);
    }

    /**
     * Renders current tide elevation value and rising/falling indicator arrow.
     * @param dc The device context.
     * @param tideColor Color for drawing tide numeric indicators.
     */
    function drawTideChangeText(dc as Dc, tideColor as Number, baseColor as Number, yVal as Float) as Void {
        var numWidth = dc.getTextWidthInPixels(mTideNumStr, Graphics.FONT_NUMBER_MILD);
        var mWidth = dc.getTextWidthInPixels(mDispUnit, Graphics.FONT_SMALL);
        
        var arrowOffset = (15 * mScale).toNumber();
        var sz = (8 * mScale).toNumber();
        var totalW = numWidth + mWidth + arrowOffset + sz;
        var startX = (mScreenWidth - totalW) / 2;

        var fontHeight = dc.getFontHeight(Graphics.FONT_NUMBER_MILD);
        var padX = (5 * mScale).toNumber();
        var rectW = totalW + 2 * padX;
        var rectH = (fontHeight * 0.68).toNumber() + (10 * mScale).toNumber();
        var rectX = startX - padX;
        var rectY = (yVal - 5 * mScale) - rectH / 2;

        // Use a BufferedBitmap to isolate the setFill state and prevent breaking subsequent primitives (like drawArrow)
        if (dc has :setBlendMode && Graphics has :createBufferedBitmap) {
            dc.setBlendMode(Graphics.BLEND_MODE_SOURCE_OVER);
            
            var options = {
                :width => rectW,
                :height => rectH
            };
            
            var bitmapRef = Graphics.createBufferedBitmap(options);
            if (bitmapRef != null) {
                var bufferedBitmap = bitmapRef.get();
                if (bufferedBitmap != null) {
                    var bDc = bufferedBitmap.getDc();
                    if (bDc != null) {
                        bDc.setBlendMode(Graphics.BLEND_MODE_NO_BLEND);
                        bDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
                        bDc.clear();
                        
                        bDc.setBlendMode(Graphics.BLEND_MODE_SOURCE_OVER);
                        
                        if (bDc has :setFill) {
                            var rgb = getRgbFromColor(Graphics.COLOR_BLACK);
                            var baseRgb = (rgb[0] << 16) | (rgb[1] << 8) | rgb[2];
                            // Create the 32-bit ARGB value (102 out of 255 is ~40% opacity)
                            var alphaColor = (102 << 24) | baseRgb; 
                            
                            // setColor strips alpha, so setFill MUST be used
                            bDc.setFill(alphaColor);
                        } else {
                            var blendedColor = blendWithBlack(Graphics.COLOR_BLACK, 0.40);
                            bDc.setColor(blendedColor, Graphics.COLOR_TRANSPARENT);
                        }
                        
                        bDc.fillRectangle(0, 0, rectW, rectH);
                        dc.drawBitmap(rectX, rectY, bufferedBitmap);
                    }
                }
            }
            dc.setBlendMode(Graphics.BLEND_MODE_NO_BLEND);
        } else {
            // Legacy hardware fallback path
            var blendedColor = blendWithBlack(Graphics.COLOR_BLACK, 0.40);
            dc.setColor(blendedColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(rectX, rectY, rectW, rectH);
        }

        var textY = yVal - 5 * mScale;
        var textClr = mInLowPowerMode ? baseColor : tideColor;
        dc.setColor(textClr, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, textY, Graphics.FONT_NUMBER_MILD, mTideNumStr, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + numWidth, textY, Graphics.FONT_SMALL, mDispUnit, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        drawArrow(dc, (startX + numWidth + mWidth + arrowOffset).toNumber(), textY.toNumber(), mIsRising, baseColor);
    }

    /**
     * Renders current swell data summaries (primary & secondary height, periods, directions).
     * @param dc The device context.
     * @param baseColor Default color of text.
     * @param hasApiKey True if a Stormglass API key is supplied.
     */
    function drawSwellData(dc as Dc, baseColor as Number, hasApiKey as Boolean) as Void {
        var swellY = mScreenHeight * 0.45 + 5 * mScale;
        if (!hasApiKey) {
            drawCenteredText(dc, swellY, Graphics.FONT_XTINY, "no stormglass.io key", baseColor);
        } else if (mWeatherError == DataKeys.ERROR_INVALID_KEY) {
            drawCenteredText(dc, swellY, Graphics.FONT_XTINY, "stormglass key invalid", Graphics.COLOR_RED);
        } else if (mWeatherError == DataKeys.ERROR_QUOTA_EXCEEDED) {
            drawCenteredText(dc, swellY, Graphics.FONT_XTINY, "swell API limit reached", Graphics.COLOR_RED);
        } else if (mWeatherError == DataKeys.ERROR_OTHER) {
            drawCenteredText(dc, swellY, Graphics.FONT_XTINY, "swell sync error", Graphics.COLOR_RED);
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
            var curY = swellY.toNumber();
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
            drawCenteredText(dc, swellY, Graphics.FONT_XTINY, "no swell data available", baseColor);
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
            var graphY = mScreenHeight * 0.73 - 20 * mScale;
            var graphHeight = mScreenHeight * 0.18;
            var graphMargin = 0.0;
            var drawWidth = mScreenWidth;
            
            var currentMinute = (now / 60) / 10;
            var currentHash = mLastSettingsHash + mLastDataUpdatedAt;
            var needsRedraw = false;
            
            if (mCachedGraphBitmap == null) {
                needsRedraw = true;
            } else if (currentMinute != mLastGraphUpdateMinute) {
                needsRedraw = true;
            } else if (mInLowPowerMode != mLastPowerMode) {
                needsRedraw = true;
            } else if (currentHash != mLastGraphHash) {
                needsRedraw = true;
            }

            var bitmapY = (graphY - graphHeight - 30 * mScale).toNumber();
            if (bitmapY < 0) { bitmapY = 0; }
            var bitmapHeight = (graphHeight + 60 * mScale).toNumber();
            if (bitmapY + bitmapHeight > mScreenHeight) {
                bitmapHeight = mScreenHeight - bitmapY;
            }

            if (needsRedraw) {
                mLastGraphUpdateMinute = currentMinute;
                mLastPowerMode = mInLowPowerMode;
                mLastGraphHash = currentHash;

                if (mCachedGraphBitmap == null && Graphics has :createBufferedBitmap) {
                    try {
                        var bitmapRef = Graphics.createBufferedBitmap({
                            :width => mScreenWidth,
                            :height => bitmapHeight
                        });
                        if (bitmapRef != null) {
                            mCachedGraphBitmap = bitmapRef.get() as Graphics.BufferedBitmap;
                        }
                    } catch (e) {
                        mCachedGraphBitmap = null;
                    }
                }

                var targetDc = dc;
                var drawYOffset = 0;
                if (mCachedGraphBitmap != null) {
                    targetDc = mCachedGraphBitmap.getDc();
                    targetDc.setColor(Graphics.COLOR_TRANSPARENT, Graphics.COLOR_TRANSPARENT);
                    targetDc.clear();
                    drawYOffset = bitmapY;
                }
                
                // Shift graphY by drawYOffset so all dependent drawing coordinates are shifted appropriately into the bitmap space
                graphY = graphY - drawYOffset;

            // Tide Graph
            targetDc.setColor(graphColor, Graphics.COLOR_TRANSPARENT);
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
                            // Draw shade under the line (fades from solid to transparent towards the bottom)
                            if (!mInLowPowerMode) {
                                var N = 12;
                                for (var j = 0; j < N; j++) {
                                    var fraction = j.toFloat() / (N - 1).toFloat();
                                    var ratio = 0.05 + 0.60 * (1.0 - fraction * fraction);
                                    var shadeColor = blendWithBlack(graphColor, ratio);
                                    
                                    var ly1 = lastY + (graphY - lastY) * j.toFloat() / N.toFloat();
                                    var ly2 = lastY + (graphY - lastY) * (j + 1).toFloat() / N.toFloat();
                                    var ry1 = y + (graphY - y) * j.toFloat() / N.toFloat();
                                    var ry2 = y + (graphY - y) * (j + 1).toFloat() / N.toFloat();
                                    
                                    targetDc.setColor(shadeColor, Graphics.COLOR_TRANSPARENT);
                                    targetDc.fillPolygon([
                                        [lastX, ly1.toNumber()],
                                        [x.toNumber(), ry1.toNumber()],
                                        [x.toNumber(), ry2.toNumber()],
                                        [lastX, ly2.toNumber()]
                                    ] as Array<[Lang.Numeric, Lang.Numeric]>);
                                }
                            }

                            // Draw the actual line on top
                            targetDc.setColor(graphColor, Graphics.COLOR_TRANSPARENT);
                            targetDc.drawLine(lastX, lastY, x.toNumber(), y.toNumber());
                            targetDc.drawLine(lastX, lastY+1, x.toNumber(), y.toNumber()+1);
                        }
                        lastX = x.toNumber(); lastY = y.toNumber();
                    } else {
                        lastX = -1; // Gap in data
                    }
                }
            }

            // Swell Graph
            if (!mInLowPowerMode && showSwellGraph && mcWaveData != null) {
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
                                targetDc.setColor(colors[s], Graphics.COLOR_TRANSPARENT);
                                targetDc.drawLine(lastSX, lastSY, sx.toNumber(), sy.toNumber());
                                if (s == 0) { targetDc.drawLine(lastSX, lastSY+1, sx.toNumber(), sy.toNumber()+1); targetDc.drawLine(lastSX, lastSY-1, sx.toNumber(), sy.toNumber()-1); }
                            }
                            lastSX = sx.toNumber(); lastSY = sy.toNumber();
                        } else {
                            lastSX = -1;
                        }
                    }
                }
            }

            if (!mInLowPowerMode) {
                // Grid Lines (either meters or feet depending on settings)
                var tideUnits = Application.Properties.getValue("TideUnits");
                var isFeet = (tideUnits == DataKeys.SETTING_UNIT_FEET);
                var factor = isFeet ? METERS_TO_FEET : 1.0;
                var minDisp = mMinH * factor;
                var maxDisp = mMaxH * factor;
                
                var gridStep = isFeet ? 1.0 : 0.5;
                var candidates;
                if (isFeet) {
                    candidates = [1.0, 2.0, 3.0, 4.0, 5.0, 8.0, 10.0, 15.0, 20.0, 25.0, 50.0] as Array<Float>;
                } else {
                    candidates = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 10.0, 20.0] as Array<Float>;
                }
                
                for (var idx = 0; idx < candidates.size(); idx++) {
                    var stepVal = candidates[idx];
                    var startGrid = (Math.ceil(minDisp / stepVal) * stepVal).toFloat();
                    var labelCount = 0;
                    for (var val = startGrid; val < maxDisp; val += stepVal) {
                        labelCount++;
                    }
                    if (labelCount <= 3) {
                        gridStep = stepVal;
                        break;
                    }
                }
                
                var startGrid = (Math.ceil(minDisp / gridStep) * gridStep).toFloat();
                var unitStr = isFeet ? "ft" : "m";
                var gridLabels = [];
                
                for (var val = startGrid; val < maxDisp; val += gridStep) {
                    var hMeter = val / factor;
                    var gy = graphY - graphHeight * (hMeter - mMinH) / (mMaxH - mMinH);
                    
                    targetDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    var dashLen = (4 * mScale).toNumber();
                    var gapLen = (4 * mScale).toNumber();
                    if (dashLen < 2) { dashLen = 2; }
                    if (gapLen < 2) { gapLen = 2; }
                    for (var gx = 0; gx < mScreenWidth; gx += dashLen + gapLen) {
                        var endX = gx + dashLen;
                        if (endX > mScreenWidth) { endX = mScreenWidth; }
                        targetDc.drawLine(gx, gy.toNumber(), endX, gy.toNumber());
                    }
                    
                    var formatStr = (gridStep.toFloat() - gridStep.toNumber().toFloat()) > 0.01 ? "%.1f" : "%.0f";
                    var labelText = val.format(formatStr) + unitStr;
                    gridLabels.add([gy.toNumber(), labelText]);
                }

                // Draw vertical line where the date is changing (midnight)
                var info = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT);
                var todayMidnight = Gregorian.moment({
                    :year => info.year,
                    :month => info.month,
                    :day => info.day,
                    :hour => 0,
                    :minute => 0,
                    :second => 0
                }).value();
                
                var dateChangeTs = null;
                if (todayMidnight >= mMinT && todayMidnight <= mMaxT) {
                    dateChangeTs = todayMidnight;
                } else if (todayMidnight + 86400 >= mMinT && todayMidnight + 86400 <= mMaxT) {
                    dateChangeTs = todayMidnight + 86400;
                } else if (todayMidnight - 86400 >= mMinT && todayMidnight - 86400 <= mMaxT) {
                    dateChangeTs = todayMidnight - 86400;
                }
                
                if (dateChangeTs != null) {
                    var cx = graphMargin + drawWidth * (dateChangeTs - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
                    targetDc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                    var dashLen = (4 * mScale).toNumber();
                    var gapLen = (4 * mScale).toNumber();
                    if (dashLen < 2) { dashLen = 2; }
                    if (gapLen < 2) { gapLen = 2; }
                    var startY = graphY - graphHeight;
                    for (var gy = startY; gy < graphY; gy += dashLen + gapLen) {
                        var endY = gy + dashLen;
                        if (endY > graphY) { endY = graphY; }
                        targetDc.drawLine(cx.toNumber(), gy.toNumber(), cx.toNumber(), endY.toNumber());
                    }
                }

                // Draw grid labels on the right side of the watch face on top of everything
                targetDc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                var font = (mFontAssistantSmall != null) ? mFontAssistantSmall : Graphics.FONT_XTINY;
                for (var i = 0; i < gridLabels.size(); i++) {
                    var item = gridLabels[i] as Array;
                    var gy = item[0] as Number;
                    var labelText = item[1] as String;
                    targetDc.drawText(mScreenWidth - (10 * mScale).toNumber(), gy, font, labelText, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
                }
            }

            // Current Time Marker (using dynamic 'now' so marker moves!)
            var nowX = graphMargin + drawWidth * (now - mMinT).toFloat() / (mMaxT - mMinT).toFloat();
            if (nowX >= 0 && nowX <= mScreenWidth) {
                var markerColor = mInLowPowerMode ? blendWithBlack(Graphics.COLOR_RED, 0.95) : Graphics.COLOR_RED;
                targetDc.setColor(markerColor, Graphics.COLOR_TRANSPARENT);
                var markerY = graphY - graphHeight * (mCurrentHeight - mMinH) / (mMaxH - mMinH);
                targetDc.fillCircle(nowX.toNumber(), markerY.toNumber(), (6 * mScale).toNumber());
            }
            
            } // End of needsRedraw block

            // Finally, if we have a cached bitmap, draw it to the main dc
            if (mCachedGraphBitmap != null) {
                dc.drawBitmap(0, bitmapY, mCachedGraphBitmap);
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

        var font = (mFontAssistantSmall != null) ? mFontAssistantSmall : Graphics.FONT_XTINY;
        if (showSyncError) {
            var errMsg = "sync error";
            var errColor = Graphics.COLOR_RED;
            if (mSyncError != null && mSyncError == DataKeys.ERROR_QUOTA_EXCEEDED) {
                errMsg = "API Limit Reached";
            } else if (mSyncError != null && mSyncError <= DataKeys.ERROR_PHONE_CONN_MAX && mSyncError > DataKeys.ERROR_PHONE_CONN_MIN) {
                errMsg = "no connection";
            }
            drawCenteredText(dc, mScreenHeight * 0.95, font, errMsg, errColor);
        } else if (mcSpotName != null) {
            var nameColor = baseColor;
            if (isStale || mSyncError != null) {
                nameColor = Graphics.COLOR_YELLOW;
            }
            drawCenteredText(dc, mScreenHeight * 0.95, font, mcSpotName as String, nameColor);
        }
    }

    /**
     * Draws a simple up or down arrow representing rising or falling tide heights.
     * @param dc The device context.
     * @param x Centered horizontal coordinate.
     * @param y Vertical center coordinate.
     * @param isRising True for up (rising); false for down (falling).
     */
    function drawArrow(dc as Dc, x as Number, y as Number, isRising as Boolean, baseColor as Number) as Void {
        var sz = (8 * mScale).toNumber();
        var pts;
        
        if (mInLowPowerMode) {
            dc.setColor(baseColor, Graphics.COLOR_TRANSPARENT);
        } else {
            if (isRising) {
                dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            }
        }

        if (isRising) {
            pts = [[x, y - sz], [x - sz, y + sz], [x + sz, y + sz]]; // Up Arrow
        } else {
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

    /**
     * Blends a color with black to simulate opacity/transparency.
     * @param color The original 24-bit RGB color.
     * @param ratio The blending ratio (0.0 = completely black/transparent, 1.0 = original color).
     * @return The blended color integer.
     */
    function blendWithBlack(color as Number, ratio as Float) as Number {
        if (ratio <= 0.0) { return 0x000000; }
        if (ratio >= 1.0) { return color; }
        
        var rgb = getRgbFromColor(color);
        var r = (rgb[0] * ratio).toNumber();
        var g = (rgb[1] * ratio).toNumber();
        var b = (rgb[2] * ratio).toNumber();
        
        return (r << 16) | (g << 8) | b;
    }

    /**
     * Resolves standard Garmin system colors and custom hex colors to RGB components.
     */
    function getRgbFromColor(color as Number) as Array<Number> {
        if (color == Graphics.COLOR_WHITE) { return [255, 255, 255]; }
        if (color == Graphics.COLOR_LT_GRAY) { return [170, 170, 170]; }
        if (color == Graphics.COLOR_DK_GRAY) { return [85, 85, 85]; }
        if (color == Graphics.COLOR_BLACK) { return [0, 0, 0]; }
        if (color == Graphics.COLOR_RED) { return [255, 0, 0]; }
        if (color == Graphics.COLOR_DK_RED) { return [170, 0, 0]; }
        if (color == Graphics.COLOR_ORANGE) { return [255, 85, 0]; }
        if (color == Graphics.COLOR_YELLOW) { return [255, 255, 0]; }
        if (color == Graphics.COLOR_GREEN) { return [0, 255, 0]; }
        if (color == Graphics.COLOR_DK_GREEN) { return [0, 170, 0]; }
        if (color == Graphics.COLOR_BLUE) { return [0, 0, 255]; }
        if (color == Graphics.COLOR_DK_BLUE) { return [0, 0, 170]; }
        if (color == Graphics.COLOR_PURPLE) { return [170, 0, 255]; }
        if (color == Graphics.COLOR_PINK) { return [255, 0, 170]; }
        
        var r = (color >> 16) & 0xFF;
        var g = (color >> 8) & 0xFF;
        var b = color & 0xFF;
        return [r, g, b];
    }

    /**
     * Lifecycle callback when the app stops.
     */
    function onStop(state as Dictionary?) as Void {
        if (kpay != null) {
            kpay.onStop();
        }
    }

    /**
     * Parses a generic coordinate value from an Object (e.g. String) to a Float.
     */
    function parseCoordinate(val as Object?, min as Float, max as Float) as Float {
        if (val instanceof String) {
            try {
                var f = val.toFloat();
                if (f != null && f >= min && f <= max) {
                    return f;
                }
            } catch (e) {
                System.println("Failed to parse coordinate: " + e.getErrorMessage());
            }
        }
        return 0.0;
    }

    function parseLatitude(val as Object?) as Float {
        return parseCoordinate(val, -90.0, 90.0);
    }

    function parseLongitude(val as Object?) as Float {
        return parseCoordinate(val, -180.0, 180.0);
    }

    /**
     * Migrates settings stored as legacy Strings.
     */
    function migrateSettings() as Void {
        var gpsLat = Application.Properties.getValue("GpsLat");
        if (gpsLat instanceof String) {
            Application.Properties.setValue("GpsLat", parseLatitude(gpsLat));
            System.println("Migrated GpsLat from String to Float.");
        }
        
        var gpsLon = Application.Properties.getValue("GpsLon");
        if (gpsLon instanceof String) {
            Application.Properties.setValue("GpsLon", parseLongitude(gpsLon));
            System.println("Migrated GpsLon from String to Float.");
        }

        var currentVersion = Version.STRING;
        var lastVersion = AppStorage.getAppVersion();

        if (lastVersion == null || Version.isLowerThan(lastVersion, "2.2.0")) {
            System.println("Upgrading app from " + (lastVersion == null ? "unknown" : lastVersion) + " to " + currentVersion);
            
            Application.Storage.deleteValue("tideTimes");
            Application.Storage.deleteValue("tideStartTime");
            Application.Storage.deleteValue("tideInterval");
            AppStorage.clearTideData();
            AppStorage.clearWaveData();
            AppStorage.setDataUpdatedAt(0);

            AppStorage.clearGeocodeUpdatedAt();
            AppStorage.clearWeatherUpdatedAt();
            AppStorage.clearTideTimelineUpdatedAt();
            AppStorage.clearTideExtremesUpdatedAt();

            AppStorage.setAppVersion(currentVersion);
        }
    }

    function getOrCreateAnonymousIdentifier() {
        return AppStorage.getOrCreateAnonymousUserId();
    }

    function logMemoryUsage() {
        var stats = System.getSystemStats();
        System.println("Memory: " + stats.usedMemory + " / " + stats.totalMemory);
    }

    /**
     * Instantiates or destroys the KiezelPay Core controller based on settings.
     */
    function initializeKPay(enableKPay as Boolean) as Boolean {
        var kpayChanged = false;
        if (enableKPay) {
            var kpayInstance = kpay;
            if (kpayInstance == null) {
                kpayInstance = new KPay.Core(getKPayConfig());
                kpay = kpayInstance;
                kpayChanged = true;
            }
            System.println("KiezelPay isLicensed: " + kpayInstance.isLicensed());
            if (!kpayInstance.isLicensed()) {
                kpayInstance.startPurchase();
            }
        } else {
            if (kpay != null) {
                kpay = null;
                kpayChanged = true;
            }
        }
        return kpayChanged;
    }

    /**
     * Handles user settings changes in the view.
     */
    function onSettingsChanged() {
        var gpsLat = Application.Properties.getValue("GpsLat") as Numeric or String or Null;
        var gpsLon = Application.Properties.getValue("GpsLon") as Numeric or String or Null;

        if (!LocationUtils.isValidLatitude(gpsLat)) {
            Application.Properties.setValue("GpsLat", 0.0);
            gpsLat = 0.0;
        }
        if (!LocationUtils.isValidLongitude(gpsLon)) {
            Application.Properties.setValue("GpsLon", 0.0);
            gpsLon = 0.0;
        }

        var kpayChanged = initializeKPay(true);

        var curDatum = Application.Properties.getValue("TideDatum");
        var curApiKey = Application.Properties.getValue("StormglassApiKey");

        var needsSync = false;
        if (gpsLat != mLastGpsLat || gpsLon != mLastGpsLon || curDatum != mLastDatum || 
           (curApiKey != null && !curApiKey.equals(mLastApiKey)) || (mLastApiKey != null && !mLastApiKey.equals(curApiKey)) || kpayChanged) {
            needsSync = true;
        }

        mLastGpsLat = gpsLat;
        mLastGpsLon = gpsLon;
        mLastDatum = curDatum;
        mLastApiKey = curApiKey;

        if (needsSync) {
            TideWatchSettingsMenu.triggerImmediateSync(true);
        }
        
        WatchUi.requestUpdate();
    }

    /**
     * Handles background data in the view.
     */
    function onBackgroundData(data as Application.PersistableType) as Void {
        System.println("onBackgroundData called on View with data: " + (data == null ? "null" : data.toString()));
        logMemoryUsage();
        
        if (kpay != null && data instanceof Dictionary) {
            kpay.onBackgroundData(data);

            var event = data.get("kpay_event");
            if (event instanceof Dictionary) {
                var kpayStatus = event.get("status");
                System.println("KiezelPay background event status: " + kpayStatus);
            }
            System.println("KiezelPay isLicensed after sync: " + kpay.isLicensed());

            var response = (data as Dictionary)[(kpay as KPay.Core).extraResponseKey];
            if (response instanceof Boolean && response as Boolean) {
                AppStorage.setDataUpdatedAt(Time.now().value());
                WatchUi.requestUpdate();
            } else {
                // System.println("TideWatch Background service: kpay pass-through sync failed");
                logSyncError("kpay pass-through sync failed", AppStorage.getSyncError());
            }
        } else if (kpay == null && data instanceof Boolean) {
            if (data as Boolean) {
                AppStorage.setDataUpdatedAt(Time.now().value());
                WatchUi.requestUpdate();
            } else {
                // System.println("TideWatch Background service: sync failed");
                logSyncError("sync failed", AppStorage.getSyncError());
            }
        } else {
            // System.println("TideWatch Background service: unknown data format or failed sync");
            logSyncError("unknown data format or failed sync", AppStorage.getSyncError());
        }
        
        if (System has :ServiceDelegate) {
            var earliest = Time.now().add(new Time.Duration(Constants.DATA_UPDATE_INTERVAL_SEC));
            scheduleNextBackgroundEvent(earliest);
        }
    }

    /**
     * Translates a numeric background error code to a human-readable string and prints it.
     */
    function logSyncError(context as String, errorCode as Number?) as Void {
        var msg = "";
        if (errorCode == null) {
            msg = "unknown error";
        } else if (errorCode == DataKeys.ERROR_APP_ID_MISSING) {
            msg = "AppId missing from storage. Background sync aborted.";
        } else if (errorCode == DataKeys.ERROR_LOCATION_MISSING) {
            msg = "No Location Set or invalid range/type. Exit.";
        } else if (errorCode == DataKeys.ERROR_QUOTA_EXCEEDED) {
            msg = "API Quota Exceeded (402/429)!";
        } else if (errorCode == DataKeys.ERROR_NO_DATA) {
            msg = "no tide data available";
        } else if (errorCode == DataKeys.ERROR_INVALID_KEY) {
            msg = "API key is invalid";
        } else {
            msg = "error code " + errorCode;
        }
        System.println("TideWatch Background service: " + context + " (" + msg + ")");
    }

    /**
     * Retrieves the settings menu views and delegates.
     */
    function getSettingsView() {
        return [ new TideWatchSettingsMenu(), new TideWatchSettingsMenuDelegate() ] as [WatchUi.Views, WatchUi.InputDelegates];
    }
}

class AlphaDrawable {
    function setAlpha(alpha as Number) as Void {}
    function setFill(color as Number) as Void {}
}
