import Toybox.Lang;

(:background)
module DataKeys {
    enum {
        TIDE_DATA = 0,
        SPOT_NAME = 1,
        WAVE_DATA = 2,
        WAVE_ERROR = 3,
        TIDE_ERROR = 4,
        SWELL_1_HEIGHT = 0, SWELL_1_PERIOD = 1, SWELL_1_DIRECTION = 2,
        SWELL_2_HEIGHT = 3, SWELL_2_PERIOD = 4, SWELL_2_DIRECTION = 5,
        SWELL_3_HEIGHT = 6, SWELL_3_PERIOD = 7, SWELL_3_DIRECTION = 8,
        TIDE_TYPE_NORMAL = 9,
        TIDE_TYPE_HIGH = 10,
        TIDE_TYPE_LOW = 11,
        TIDE_START_TIME = 12,
        TIDE_INTERVAL = 13,
        TIDE_EXTREMA = 14,
        TIDE_TIMES = 15,
        TIDE_UNIT = 16,
        SWELL_UNIT = 17,
        UNIT_METER = 18,
        UNIT_FEET = 19,
        ERROR_NO_SPOTS_NEARBY = -500,
    }
}
