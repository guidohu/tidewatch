import Toybox.Application;
import Toybox.System;

class Benchmark {
    static function run() {
        var start = System.getTimer();
        var iters = 10000;

        for (var i = 0; i < iters; i++) {
            var tideUnits = Application.Properties.getValue("TideUnits");
        }
        var end = System.getTimer();
        System.println("10k Application.Properties.getValue: " + (end - start) + "ms");
    }
}
