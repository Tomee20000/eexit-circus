#-
#FFFFFF   fehér
#0D00FF   kék
#FF5F15   sárga
#FF0000   piros
#004D1A   sötétzöld
#B10061   lila / magenta
-#

import mqtt
import json

var INPUT1 = 26
var INPUT2 = 27
var INPUT3 = 14
var INPUT4 = 13
var INPUT5 = 23
var INPUT6 = 22

var HAND_TOPIC = "CHANDGAME1"
var ELEPHANT_TOPIC = "CELEPHANT"
var GAME_TOPIC = "CHANDGAME"

var COLOR_MAP = [
    "FF0000",
    "FFFFFF",
    "B10061",
    "0D00FF",
    "004D1A",
    "FF5F15"
]

class Elephant
    var current_color
    var last_input
    var enable
    var demo_round
    var sensor_started
    var last_demo_black

    def set_light(power, color)
        light.set({
            "power": power,
            "rgb": color
        })

        tasmota.cmd("State")
    end

    def green_blink()
        for i: 1..3
            self.set_light(false, "008000")
            tasmota.delay(250)

            self.set_light(true, "008000")
            tasmota.delay(250)
        end

        self.set_light(false, "008000")
    end

    def reset_after_wrong()
        self.demo_round = 0
        self.sensor_started = false
        self.last_demo_black = false
        self.last_input = nil

        self.set_light(false, "FFFFFF")
    end

    def on_mqtt_message(topic, payload)
        if topic == HAND_TOPIC
            if payload == "SOLVED_BLINK"
                self.enable = false
                self.sensor_started = false
                self.green_blink()
                return
            end

            if !self.enable || self.sensor_started
                return
            end

            if payload == "000000"
                self.set_light(false, "FFFFFF")

                if !self.last_demo_black
                    self.demo_round += 1
                    self.last_demo_black = true
                end

            else
                self.set_light(true, payload)
                self.last_demo_black = false
            end

            return
        end

        if topic == GAME_TOPIC
            var game_json = json.load(payload)
            var game_data = game_json.find("data", nil)

            if game_data == "WRONG"
                self.reset_after_wrong()
            end

            return
        end
    end

    def init()
        self.current_color = 0
        self.last_input = nil
        self.enable = false
        self.demo_round = 0
        self.sensor_started = false
        self.last_demo_black = false

        self.set_light(false, "FFFFFF")

        mqtt.subscribe(
            HAND_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            GAME_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )
    end

    def enable_game()
        self.enable = true
        self.current_color = 0
        self.last_input = nil
        self.demo_round = 0
        self.sensor_started = false
        self.last_demo_black = false

        self.set_light(false, "FFFFFF")

        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.current_color = 0
        self.last_input = nil
        self.demo_round = 0
        self.sensor_started = false
        self.last_demo_black = false

        self.set_light(false, "FFFFFF")

        mqtt.publish(
            ELEPHANT_TOPIC,
            "000000"
        )

        tasmota.resp_cmnd("Game disabled")
    end

    def publish_color()
        var color = COLOR_MAP[self.current_color]

        mqtt.publish(
            ELEPHANT_TOPIC,
            color
        )

        self.set_light(false, "FFFFFF")
    end

    def every_50ms()
        if gpio.digital_read(INPUT1)
            self.current_color = 0
        elif gpio.digital_read(INPUT2)
            self.current_color = 1
        elif gpio.digital_read(INPUT3)
            self.current_color = 2
        elif gpio.digital_read(INPUT4)
            self.current_color = 3
        elif gpio.digital_read(INPUT5)
            self.current_color = 4
        elif gpio.digital_read(INPUT6)
            self.current_color = 5
        end

        if self.last_input == nil
            self.last_input = self.current_color

        elif self.last_input != self.current_color &&
             self.enable &&
             self.demo_round >= 1

            self.last_input = self.current_color
            self.sensor_started = true

            self.publish_color()
        end
    end
end

var elephant_driver = Elephant()

tasmota.add_driver(elephant_driver)

tasmota.add_cmd(
    "enable",
    / -> elephant_driver.enable_game()
)

tasmota.add_cmd(
    "disable",
    / -> elephant_driver.disable_game()
)

print("Elephant driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")