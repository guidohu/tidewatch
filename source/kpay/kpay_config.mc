import Toybox.WatchUi;
import Toybox.Lang;

function getKPayConfig() as Dictionary {
    return {
        "APP_ID" => WatchUi.loadResource(Rez.Strings.KPayAppId).toNumber(),
        // TODO: CHANGEME
        "TEST_MODE" => true,
        "TRIAL_ENABLED" => true
    };
}
