import Toybox.Lang;

(:background)
module DataKeys {
    enum {
        TIDE_TYPE_HIGH = 10,
        TIDE_TYPE_LOW = 11,
        UNIT_METER = 18,
        UNIT_FEET = 19,
        ERROR_QUOTA_EXCEEDED = -429,
        ERROR_PHONE_CONN_MIN = -200,
        ERROR_PHONE_CONN_MAX = -100,
        
        SETTING_UNIT_METERS = 0,
        SETTING_UNIT_FEET = 1,

        SETTING_COLOR_PINK = 1,
        SETTING_COLOR_RED = 2,
        SETTING_COLOR_GREEN = 3,
        SETTING_COLOR_WHITE = 4,
        SETTING_COLOR_YELLOW = 5,
        SETTING_COLOR_ORANGE = 6,
        SETTING_COLOR_PURPLE = 7,
        SETTING_COLOR_LT_GRAY = 8,
        SETTING_COLOR_DK_GRAY = 9,
        SETTING_COLOR_LIGHT_BLUE = 10,
        SETTING_COLOR_PETROL = 11,
        SETTING_COLOR_TURQUOISE = 12,

        TIME_FORMAT_24_H = 0,
        TIME_FORMAT_12_H = 1,
    }
}
