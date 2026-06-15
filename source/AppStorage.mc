import Toybox.Application;
import Toybox.Lang;
import Toybox.Math;

(:background)
module AppStorageBG {
    public function getAppId() as String? {
        return Application.Storage.getValue("AppId") as String?;
    }
    public function getForecastStartOffsetSec() as Number? {
        return Application.Storage.getValue("forecastStartOffsetSec") as Number?;
    }

    public function getForecastWindowSec() as Number? {
        return Application.Storage.getValue("forecastWindowSec") as Number?;
    }

    public function getSpotName() as String? {
        return Application.Storage.getValue("spotName") as String?;
    }
    public function setSpotName(val as String?) as Void {
        Application.Storage.setValue("spotName", val);
    }

    public function getAnonymousUserId() as String? {
        return Application.Storage.getValue("anonymous_user_id") as String?;
    }
    public function setAnonymousUserId(val as String) as Void {
        Application.Storage.setValue("anonymous_user_id", val);
    }
    public function getOrCreateAnonymousUserId() as String {
        var userId = getAnonymousUserId();
        if (userId == null) {
            var chars = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];
            var uuid = "";
            for (var i = 0; i < 32; i++) {
                if (i == 8 || i == 12 || i == 16 || i == 20) {
                    uuid += "-";
                }
                var idx = Math.rand() % 16;
                uuid += chars[idx];
            }
            userId = uuid;
            setAnonymousUserId(userId);
        }
        return userId;
    }

    public function getDataUpdatedAt() as Number {
        var val = Application.Storage.getValue("dataUpdatedAt");
        return (val instanceof Lang.Number) ? val : 0;
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

    public function getWeatherUpdatedAt() as Number? {
        return Application.Storage.getValue("weatherUpdatedAt") as Number?;
    }
    public function setWeatherUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("weatherUpdatedAt", val);
    }

    public function getTideTimelineUpdatedAt() as Number? {
        return Application.Storage.getValue("tideTimelineUpdatedAt") as Number?;
    }
    public function setTideTimelineUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("tideTimelineUpdatedAt", val);
    }

    public function getTideExtremesUpdatedAt() as Number? {
        return Application.Storage.getValue("tideExtremesUpdatedAt") as Number?;
    }
    public function setTideExtremesUpdatedAt(val as Number) as Void {
        Application.Storage.setValue("tideExtremesUpdatedAt", val);
    }

    public function setWaveData(val as Array<Array<Number?> >?) as Void {
        Application.Storage.setValue("waveData", val);
    }
    public function setSwellUnitApi(val as Number) as Void {
        Application.Storage.setValue("swellUnitApi", val);
    }

    public function setTideData(val as Array<Array<Number> >?) as Void {
        Application.Storage.setValue("tideData", val);
    }
    public function setTideUnitApi(val as Number) as Void {
        Application.Storage.setValue("tideUnitApi", val);
    }

    public function setTideExtrema(val as Array<Array<Number> >?) as Void {
        Application.Storage.setValue("tideExtrema", val);
    }

    public function setWeatherError(val as Number) as Void {
        Application.Storage.setValue("weatherError", val);
    }
    public function clearWeatherError() as Void {
        Application.Storage.deleteValue("weatherError");
    }

    public function setSyncError(val as Number) as Void {
        Application.Storage.setValue("syncError", val);
    }
    public function clearSyncError() as Void {
        Application.Storage.deleteValue("syncError");
    }

    public function setErrorAt(val as Number) as Void {
        Application.Storage.setValue("errorAt", val);
    }
    public function clearErrorAt() as Void {
        Application.Storage.deleteValue("errorAt");
    }
}

module AppStorage {
    // Delegated functions
    public function getAppId() as String? {
        return AppStorageBG.getAppId();
    }
    public function setAppId(val as String) as Void {
        Application.Storage.setValue("AppId", val);
    }

    public function getForecastStartOffsetSec() as Number? {
        return AppStorageBG.getForecastStartOffsetSec();
    }
    public function setForecastStartOffsetSec(val as Number) as Void {
        Application.Storage.setValue("forecastStartOffsetSec", val);
    }

    public function getForecastWindowSec() as Number? {
        return AppStorageBG.getForecastWindowSec();
    }
    public function setForecastWindowSec(val as Number) as Void {
        Application.Storage.setValue("forecastWindowSec", val);
    }

    public function getSpotName() as String? {
        return AppStorageBG.getSpotName();
    }
    public function setSpotName(val as String?) as Void {
        AppStorageBG.setSpotName(val);
    }

    public function getAnonymousUserId() as String? {
        return AppStorageBG.getAnonymousUserId();
    }
    public function setAnonymousUserId(val as String) as Void {
        AppStorageBG.setAnonymousUserId(val);
    }
    public function getOrCreateAnonymousUserId() as String {
        return AppStorageBG.getOrCreateAnonymousUserId();
    }

    public function getDataUpdatedAt() as Number {
        return AppStorageBG.getDataUpdatedAt();
    }
    public function setDataUpdatedAt(val as Number) as Void {
        AppStorageBG.setDataUpdatedAt(val);
    }

    public function getGeocodeUpdatedAt() as Number? {
        return AppStorageBG.getGeocodeUpdatedAt();
    }
    public function setGeocodeUpdatedAt(val as Number) as Void {
        AppStorageBG.setGeocodeUpdatedAt(val);
    }

    public function getWeatherUpdatedAt() as Number? {
        return AppStorageBG.getWeatherUpdatedAt();
    }
    public function setWeatherUpdatedAt(val as Number) as Void {
        AppStorageBG.setWeatherUpdatedAt(val);
    }

    public function getTideTimelineUpdatedAt() as Number? {
        return AppStorageBG.getTideTimelineUpdatedAt();
    }
    public function setTideTimelineUpdatedAt(val as Number) as Void {
        AppStorageBG.setTideTimelineUpdatedAt(val);
    }

    public function getTideExtremesUpdatedAt() as Number? {
        return AppStorageBG.getTideExtremesUpdatedAt();
    }
    public function setTideExtremesUpdatedAt(val as Number) as Void {
        AppStorageBG.setTideExtremesUpdatedAt(val);
    }

    public function setWaveData(val as Array<Array<Number?> >?) as Void {
        AppStorageBG.setWaveData(val);
    }
    public function setSwellUnitApi(val as Number) as Void {
        AppStorageBG.setSwellUnitApi(val);
    }

    public function setTideData(val as Array<Array<Number> >?) as Void {
        AppStorageBG.setTideData(val);
    }
    public function setTideUnitApi(val as Number) as Void {
        AppStorageBG.setTideUnitApi(val);
    }

    public function setTideExtrema(val as Array<Array<Number> >?) as Void {
        AppStorageBG.setTideExtrema(val);
    }

    public function setWeatherError(val as Number) as Void {
        AppStorageBG.setWeatherError(val);
    }
    public function clearWeatherError() as Void {
        AppStorageBG.clearWeatherError();
    }

    public function setSyncError(val as Number) as Void {
        AppStorageBG.setSyncError(val);
    }
    public function clearSyncError() as Void {
        AppStorageBG.clearSyncError();
    }

    public function setErrorAt(val as Number) as Void {
        AppStorageBG.setErrorAt(val);
    }
    public function clearErrorAt() as Void {
        AppStorageBG.clearErrorAt();
    }

    // Foreground-only functions
    public function getAppVersion() as String? {
        return Application.Storage.getValue("AppVersion") as String?;
    }
    public function setAppVersion(val as String?) as Void {
        Application.Storage.setValue("AppVersion", val);
    }

    public function clearSpotName() as Void {
        Application.Storage.deleteValue("spotName");
    }

    public function clearGeocodeUpdatedAt() as Void {
        Application.Storage.deleteValue("geocodeUpdatedAt");
    }

    public function clearWeatherUpdatedAt() as Void {
        Application.Storage.deleteValue("weatherUpdatedAt");
    }

    public function clearTideTimelineUpdatedAt() as Void {
        Application.Storage.deleteValue("tideTimelineUpdatedAt");
    }

    public function clearTideExtremesUpdatedAt() as Void {
        Application.Storage.deleteValue("tideExtremesUpdatedAt");
    }

    public function getWeatherError() as Number? {
        return Application.Storage.getValue("weatherError") as Number?;
    }

    public function getSyncError() as Number? {
        return Application.Storage.getValue("syncError") as Number?;
    }

    public function getErrorAt() as Number? {
        return Application.Storage.getValue("errorAt") as Number?;
    }

    public function getWaveData() as Array<Array<Number?> >? {
        return Application.Storage.getValue("waveData") as Array<Array<Number?> >?;
    }

    public function getSwellUnitApi() as Number? {
        return Application.Storage.getValue("swellUnitApi") as Number?;
    }

    public function getTideData() as Array<Array<Number> >? {
        return Application.Storage.getValue("tideData") as Array<Array<Number> >?;
    }

    public function getTideUnitApi() as Number? {
        return Application.Storage.getValue("tideUnitApi") as Number?;
    }

    public function getTideExtrema() as Array<Array<Number> >? {
        return Application.Storage.getValue("tideExtrema") as Array<Array<Number> >?;
    }

    public function getNextSyncTime() as Number {
        var val = Application.Storage.getValue("nextSyncTime");
        return (val instanceof Lang.Number) ? val : 0;
    }
    public function setNextSyncTime(val as Number) as Void {
        Application.Storage.setValue("nextSyncTime", val);
    }
    public function clearNextSyncTime() as Void {
        Application.Storage.deleteValue("nextSyncTime");
    }

    public function clearCache() as Void {
        clearTideData();
        clearTideExtrema();
        clearWaveData();
        clearSyncError();
        clearErrorAt();
        clearSpotName();
        clearGeocodeUpdatedAt();
        clearWeatherUpdatedAt();
        clearTideTimelineUpdatedAt();
        clearTideExtremesUpdatedAt();
        clearNextSyncTime();
        setDataUpdatedAt(0);
    }

    public function clearTideData() as Void {
        Application.Storage.setValue("tideData", null);
    }
    public function clearTideExtrema() as Void {
        Application.Storage.setValue("tideExtrema", null);
    }
    public function clearWaveData() as Void {
        Application.Storage.setValue("waveData", null);
    }
}
