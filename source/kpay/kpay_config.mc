import Toybox.WatchUi;
import Toybox.Lang;

function getKPayConfig() as Dictionary {
    return {
        "APP_ID" => WatchUi.loadResource(Rez.Strings.KPayAppId).toNumber(),
        // Generate free test purchase codes on your KPay developer dashboard to
        // simulate successful purchases without spending actual money.
        "TEST_MODE" => false,
        // It enables an automatic "try before you buy" grace period for new users.
        "TRIAL_ENABLED" => false
    };
}
