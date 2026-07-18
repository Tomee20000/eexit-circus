#-
GPIO32: Relay 1
GPIO23: None
-#

import gpio

# ---------------- CONFIG ----------------

var RELAY = 0
var HOME_SENSOR = 23
var HOME_ACTIVE = 0

var MAINTENANCE_MS = 20000
var MAINTENANCE_TIMER = "carousel_maintenance"

# ---------------- CAROUSEL ----------------

class Carousel

    var state
    var position
    var last_relay

    def init()
        self.state = "idle"

        gpio.pin_mode(HOME_SENSOR, gpio.INPUT_PULLUP)

        self.set_relay(false)

        if self.at_home()
            self.position = "home"
        else
            self.position = "unknown"
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

    def fast_loop()
        var relay_state = tasmota.get_power(RELAY)

        if relay_state != self.last_relay
            self.last_relay = relay_state

            if self.state == "idle"
                self.position = "unknown"
                print("Manual relay control detected, position unknown")
            end
        end

        if self.state == "homing" && self.at_home()
            self.set_relay(false)
            self.position = "home"
            self.state = "idle"

            print("Home position reached")

        elif self.state == "maintenance_homing" &&
             self.at_home()
            self.start_maintenance_move()
        end
    end

end

# ---------------- START ----------------

var carousel = Carousel()

tasmota.add_cmd("Home", / -> carousel.home())
tasmota.add_cmd("Maintenance", / -> carousel.maintenance())

print("Carousel driver loaded")
print("------------------------------------------------")
print("Commands:")
print("Home        - Move to home position")
print("Maintenance - Move to maintenance position")
print("------------------------------------------------")