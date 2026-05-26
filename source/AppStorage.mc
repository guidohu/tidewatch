import Toybox.Application;
import Toybox.Lang;

(:background)
module AppStorage {
    // Legacy / Deleted keys
    public function clearTideTimes() as Void {
        Application.Storage.deleteValue("tideTimes");
    }
    public function clearTideStartTime() as Void {
        Application.Storage.setValue("tideStartTime", null);
    }
    public function clearTideInterval() as Void {
        Application.Storage.setValue("tideInterval", null);
    }

    // App Version
    public function getAppVersion() as String? {
        return Application.Storage.getValue("AppVersion") as String?;
    }
    public function setAppVersion(val as String?) as Void {
        Application.Storage.setValue("AppVersion", val);
    }

    // App ID
    public function getAppId() as String? {
        return Application.Storage.getValue("AppId") as String?;
    }
    public function setAppId(val as String) as Void {
        Application.Storage.setValue("AppId", val);
    }

    // Spot Name
    public function getSpotName() as String? {
        return Application.Storage.getValue("spotName") as String?;
    }
    public function setSpotName(val as String?) as Void {
        Application.Storage.setValue("spotName", val);
    }
    public function clearSpotName() as Void {
        Application.Storage.deleteValue("spotName");
    }

    // Anonymous User ID
    public function getAnonymousUserId() as String? {
        return Application.Storage.getValue("anonymous_user_id") as String?;
    }
    public function setAnonymousUserId(val as String) as Void {
        Application.Storage.setValue("anonymous_user_id", val);
    }

    // Data Update Timestamps
    public function getDataUpdatedAt() as Number {
        var val = Application.Storage.getValue("dataUpdatedAt");
        return (val instanceof Number) ? val : 0;
    }
    public function setDataUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("dataUpdatedAt", val);
    }

    public function getGeocodeUpdatedAt() as Number? {
        return Application.Storage.getValue("geocodeUpdatedAt") as Number?;
    }
    public function setGeocodeUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("geocodeUpdatedAt", val);
    }
    public function clearGeocodeUpdatedAt() as Void {
        Application.Storage.deleteValue("geocodeUpdatedAt");
    }

    public function getWeatherUpdatedAt() as Number? {
        return Application.Storage.getValue("weatherUpdatedAt") as Number?;
    }
    public function setWeatherUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("weatherUpdatedAt", val);
    }
    public function clearWeatherUpdatedAt() as Void {
        Application.Storage.deleteValue("weatherUpdatedAt");
    }

    public function getTideTimelineUpdatedAt() as Number? {
        return Application.Storage.getValue("tideTimelineUpdatedAt") as Number?;
    }
    public function setTideTimelineUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("tideTimelineUpdatedAt", val);
    }
    public function clearTideTimelineUpdatedAt() as Void {
        Application.Storage.deleteValue("tideTimelineUpdatedAt");
    }

    public function getTideExtremesUpdatedAt() as Number? {
        return Application.Storage.getValue("tideExtremesUpdatedAt") as Number?;
    }
    public function setTideExtremesUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("tideExtremesUpdatedAt", val);
    }
    public function clearTideExtremesUpdatedAt() as Void {
        Application.Storage.deleteValue("tideExtremesUpdatedAt");
    }

    // Error Codes
    public function getWeatherError() as Number? {
        return Application.Storage.getValue("weatherError") as Number?;
    }
    public function setWeatherError(val as Number) as Void {
        Application.Storage.setValue("weatherError", val);
    }
    public function clearWeatherError() as Void {
        Application.Storage.deleteValue("weatherError");
    }

    public function getSyncError() as Number? {
        return Application.Storage.getValue("syncError") as Number?;
    }
    public function setSyncError(val as Number) as Void {
        Application.Storage.setValue("syncError", val);
    }
    public function clearSyncError() as Void {
        Application.Storage.deleteValue("syncError");
    }

    public function getErrorAt() as Number? {
        return Application.Storage.getValue("errorAt") as Number?;
    }
    public function setErrorAt(val as Number) as Void {
        Application.Storage.setValue("errorAt", val);
    }
    public function clearErrorAt() as Void {
        Application.Storage.deleteValue("errorAt");
    }

    // Main Swell/Tide Data Arrays
    public function getWaveData() as Array<Array<Number?> >? {
        return Application.Storage.getValue("waveData") as Array<Array<Number?> >?;
    }
    public function setWaveData(val as Array<Array<Number?> >?) as Void {
        Application.Storage.setValue("waveData", val);
    }
    public function clearWaveData() as Void {
        Application.Storage.setValue("waveData", null);
    }

    public function getSwellUnitApi() as Number? {
        return Application.Storage.getValue("swellUnitApi") as Number?;
    }
    public function setSwellUnitApi(val as Number) as Void {
        Application.Storage.setValue("swellUnitApi", val);
    }

    public function getTideData() as Array<Array<Number> >? {
        return Application.Storage.getValue("tideData") as Array<Array<Number> >?;
    }
    public function setTideData(val as Array<Array<Number> >?) as Void {
        Application.Storage.setValue("tideData", val);
    }
    public function clearTideData() as Void {
        Application.Storage.setValue("tideData", null);
    }

    public function getTideUnitApi() as Number? {
        return Application.Storage.getValue("tideUnitApi") as Number?;
    }
    public function setTideUnitApi(val as Number) as Void {
        Application.Storage.setValue("tideUnitApi", val);
    }

    public function getTideExtrema() as Array<Array<Number> >? {
        return Application.Storage.getValue("tideExtrema") as Array<Array<Number> >?;
    }
    public function setTideExtrema(val as Array<Array<Number> >?) as Void {
        Application.Storage.setValue("tideExtrema", val);
    }
    public function clearTideExtrema() as Void {
        Application.Storage.setValue("tideExtrema", null);
    }

    // Bulk actions
    public function clearCache() as Void {
        clearTideData();
        clearTideStartTime();
        clearTideInterval();
        clearTideExtrema();
        clearWaveData();
        clearSyncError();
        clearErrorAt();
        clearSpotName();
        clearGeocodeUpdatedAt();
        clearWeatherUpdatedAt();
        clearTideTimelineUpdatedAt();
        clearTideExtremesUpdatedAt();
        setDataUpdatedAt(0);
    }
}
