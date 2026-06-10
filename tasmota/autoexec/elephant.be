#-
#FFFFFF   (fehér)
#0D00FF   (kék)
#FF5F15   (sárga)
#FF0000   (piros)
#004D1A   (sötétzöld)
#B10061   (lila / magenta)
-#

import mqtt
import json

var INPUT1 = 26
var INPUT2 = 27
var INPUT3 = 14
var INPUT4 = 13
var INPUT5 = 23
var INPUT6 = 22

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
    var blink_current
    var solving_started
    var blink_round
    var video_paused
    var wanted_power
    var wanted_color

    def set_light(power, color)
        self.wanted_power = power
        self.wanted_color = color

        if !self.video_paused
            light.set({
                "power": power,
                "rgb": color
            })
            tasmota.cmd("State")
        end
    end

    def pause_video()
        self.video_paused = true

        light.set({
            "power": false,
            "rgb": self.wanted_color
        })

        tasmota.cmd("State")
        print("VIDEO4START received, light paused")
    end

    def continue_video()
        if !self.video_paused
            return
        end

        self.video_paused = false

        light.set({
            "power": self.wanted_power,
            "rgb": self.wanted_color
        })

        tasmota.cmd("State")
        print("VIDEO4END received, light continued")
    end

    def on_mqtt_message(topic, payload)
        if topic == "CC/videocontrol"
            var video_json = json.load(payload)
            var video_data = video_json.find("data", nil)

            if video_data == "VIDEO4START"
                self.pause_video()
            elif video_data == "VIDEO4END"
                self.continue_video()
            end

            return
        end

        if topic == "CHANDGAME1" && self.enable
            if !self.solving_started && payload == "000000"
                self.set_light(false, "FFFFFF")
                self.blink_round += 1

            elif !self.solving_started
                self.set_light(true, payload)
            end
        end
    end

    def init()
        self.current_color = 0
        self.last_input = nil
        self.enable = false
        self.blink_current = 0
        self.solving_started = false
        self.blink_round = 0
        self.video_paused = false
        self.wanted_power = false
        self.wanted_color = "FFFFFF"

        light.set({
            "power": false,
            "rgb": "FFFFFF"
        })

        tasmota.cmd("State")

        mqtt.subscribe(
            "CHANDGAME1",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            "CC/videocontrol",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )
    end

    def enable_game()
        self.enable = true
        self.blink_current = 0
        self.solving_started = false
        self.blink_round = 0
        self.video_paused = false
        self.wanted_power = false
        self.wanted_color = "FFFFFF"

        light.set({
            "power": false,
            "rgb": "FFFFFF"
        })

        tasmota.cmd("State")
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.video_paused = false
        self.wanted_power = false
        self.wanted_color = "FFFFFF"

        light.set({
            "power": false,
            "rgb": "FFFFFF"
        })

        tasmota.cmd("State")
        tasmota.resp_cmnd("Game disabled")
    end

    def change_color()
        var color = COLOR_MAP[self.current_color]

        self.set_light(true, color)

        mqtt.publish(
            tasmota.cmd("Topic")["Topic"],
            color
        )
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
             self.blink_round >= 1

            self.last_input = self.current_color
            self.change_color()
            self.solving_started = true
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