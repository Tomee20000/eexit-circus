var LED0 = 23
var LED1 = 22
var LED2 = 21
var LED3 = 19
var LED4 = 18
var LED5 = 17
var LASER = 25

var MOTOR1 = 32
var MOTOR2 = 33

var CONNECTED = 36
var TRIGGER = 39

class Lasergun
    var enable, bicycle_counter

    def on_mqtt_message(topic, payload)
        if topic == "CLASERGUN/BCOUNTER"
            self.bicycle_counter = number(payload)
        end
    end

    def init()
        mqtt.subscribe("CLASERGUN/BCOUNTER", /t, idx, data, b -> self.on_mqtt_message(t, data))
        self.enable = false
        self.bicycle_counter = 0
    end

    def enable_game()
        self.enable = true
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        tasmota.resp_cmnd("Game disabled")
    endy

    def every_50ms()
        if self.enable

        end
    end
end

var lasergundriver = Lasergun()
tasmota.add_driver(lasergundriver)

tasmota.add_cmd("enable", /-> lasergundriver.enable_game())
tasmota.add_cmd("disable", /-> lasergundriver.disable_game())

print("Lasergun driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")