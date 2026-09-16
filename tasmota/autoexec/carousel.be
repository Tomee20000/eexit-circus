#-
GPIO32: Relay 1
GPIO23: None
xsns_22_sr04.ino-ben a FUNC_EVERY_SECOND lett FUNC_EVERY_250_MSECOND-ra cserélve és a max távolság 350-re
-#

import gpio
import json

# ---------------- CONFIG ----------------

var RELAY = 0
var HOME_SENSOR = 23
var HOME_ACTIVE = 0

var MAINTENANCE_MS = 20250
var MAINTENANCE_TIMER = "carousel_maintenance"

var SAFETY_DISTANCE_CM = 70
var SAFETY_ZONE_START_MS = 33000
var SAFETY_ZONE_END_MS = 37000

# ---------------- CAROUSEL ----------------

class Carousel

    var state
    var position
    var last_relay
    var last_home

    var home_known
    var travel_ms
    var last_tick

    def init()
        self.state = "idle"

        gpio.pin_mode(HOME_SENSOR, gpio.INPUT_PULLUP)

        self.set_relay(false)

        self.last_home = self.at_home()
        self.last_tick = tasmota.millis()
        self.travel_ms = 0

        if self.at_home()
            self.position = "home"
            self.home_known = true
        else
            self.position = "unknown"
            self.home_known = false
        end

        tasmota.add_fast_loop(/ -> self.fast_loop())
    end

    def set_relay(value)
        tasmota.set_power(RELAY, value)
        self.last_relay = value
    end

    def at_home()
        return gpio.digital_read(HOME_SENSOR) == HOME_ACTIVE
    end

    def home()
        tasmota.remove_timer(MAINTENANCE_TIMER)

        if self.state == "homing"
            tasmota.resp_cmnd_str("Homing already in progress")
            return
        end

        if self.position == "home" && self.at_home()
            self.state = "idle"
            self.set_relay(false)

            tasmota.resp_cmnd_str("Already in home position")
            return
        end

        self.state = "homing"
        self.position = "unknown"
        self.set_relay(true)

        tasmota.resp_cmnd_str("Homing started")
    end

    def maintenance()
        if self.state == "maintenance_homing" ||
           self.state == "maintenance_move"
            tasmota.resp_cmnd_str(
                "Maintenance positioning already in progress"
            )
            return
        end

        if self.position == "maintenance"
            self.state = "idle"
            self.set_relay(false)

            tasmota.resp_cmnd_str(
                "Already in maintenance position"
            )
            return
        end

        tasmota.remove_timer(MAINTENANCE_TIMER)
        self.position = "unknown"

        if self.at_home()
            self.travel_ms = 0
            self.home_known = true
            self.start_maintenance_move()
        else
            self.state = "maintenance_homing"
            self.set_relay(true)
        end

        tasmota.resp_cmnd_str(
            "Maintenance positioning started"
        )
    end

    def start_maintenance_move()
        self.state = "maintenance_move"
        self.position = "unknown"
        self.set_relay(true)

        tasmota.set_timer(
            MAINTENANCE_MS,
            / -> self.finish_maintenance(),
            MAINTENANCE_TIMER
        )
    end

    def finish_maintenance()
        if self.state != "maintenance_move"
            return
        end

        self.set_relay(false)
        self.position = "maintenance"
        self.state = "idle"

        print("Maintenance position reached")
    end

    def in_safety_zone()
        if SAFETY_ZONE_START_MS < 0 ||
           SAFETY_ZONE_END_MS < 0
            return false
        end

        if !self.home_known
            return false
        end

        return self.travel_ms >= SAFETY_ZONE_START_MS &&
               self.travel_ms <= SAFETY_ZONE_END_MS
    end

    def safety_stop(distance)
        if !tasmota.get_power(RELAY)
            return
        end

        tasmota.remove_timer(MAINTENANCE_TIMER)

        self.set_relay(false)
        self.position = "unknown"
        self.state = "idle"

        print(
            "Safety stop: object detected at",
            distance,
            "cm"
        )
    end

    def every_100ms()
        if !tasmota.get_power(RELAY)
            return
        end

        if !self.in_safety_zone()
            return
        end

        try
            var sensors = json.load(tasmota.read_sensors())

            if sensors == nil
                return
            end

            var sr04 = sensors.find("SR04")

            if sr04 == nil
                return
            end

            var distance = sr04.find("Distance")

            if distance == nil
                return
            end

            if distance > 0 &&
               distance < SAFETY_DISTANCE_CM
                self.safety_stop(distance)
            end

        except ..
            return
        end
    end

    def fast_loop()
        var now = tasmota.millis()
        var delta = now - self.last_tick

        self.last_tick = now

        if delta < 0 || delta > 1000
            delta = 0
        end

        var relay_state = tasmota.get_power(RELAY)
        var home_now = self.at_home()

        if relay_state && self.home_known
            self.travel_ms += delta
        end

        if home_now && !self.last_home
            self.travel_ms = 0
            self.home_known = true
        end

        self.last_home = home_now

        if relay_state != self.last_relay
            self.last_relay = relay_state

            if self.state == "idle"
                self.position = "unknown"

                if relay_state && home_now
                    self.travel_ms = 0
                    self.home_known = true
                end

                print(
                    "Manual relay control detected, position unknown"
                )
            end
        end

        if self.state == "homing" && home_now
            self.set_relay(false)
            self.travel_ms = 0
            self.home_known = true
            self.position = "home"
            self.state = "idle"

            print("Home position reached")

        elif self.state == "maintenance_homing" &&
             home_now
            self.travel_ms = 0
            self.home_known = true
            self.start_maintenance_move()
        end
    end

end

# ---------------- START ----------------

var carousel = Carousel()

tasmota.add_driver(carousel)

tasmota.add_cmd("Home", / -> carousel.home())
tasmota.add_cmd("Maintenance", / -> carousel.maintenance())

print("Carousel driver loaded")
print("------------------------------------------------")
print("Commands:")
print("Home        - Move to home position")
print("Maintenance - Move to maintenance position")
print("------------------------------------------------")