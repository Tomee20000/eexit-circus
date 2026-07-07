#-
#FFFFFF   fehér
#0D00FF   kék
#FF5F15   sárga
#FF0000   piros
#004D1A   sötétzöld
#B10061   lila / magenta
#000000   fekete / szünet
-#

import mqtt
import json

var HAND_TOPIC = "CHANDGAME1"
var ELEPHANT_TOPIC = "CELEPHANT"
var GAME_TOPIC = "CHANDGAME"
var VIDEO_TOPIC = "CC/videocontrol"
var HAND_SENSOR_TOPIC = "tele/CHANDGAME2/SENSOR"

var UID_MAP = {
    "F42A6E05": 1,
    "B357B303": 2,
    "3FF4F829": 3,
    "0D807606": 4
}

var SOLUTION = [
    "FFFFFF",
    "0D00FF",
    "FF5F15",
    "FF0000",
    "004D1A",
    "B10061"
]

class Handgame1
    var enable
    var selected_color
    var next_color
    var demo_index
    var demo_active
    var selector_started
    var first_correct

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

    def blink_color(color)
        for i: 1..3
            self.set_light(false, color)
            tasmota.delay(250)

            self.set_light(true, color)
            tasmota.delay(250)
        end
    end

    def solved()
        self.enable = false
        self.demo_active = false
        self.selector_started = false

        mqtt.publish(
            HAND_TOPIC,
            "SOLVED_BLINK"
        )

        self.green_blink()

        mqtt.publish(
            GAME_TOPIC,
            '{"data":"SOLVED"}'
        )
    end

    def wrong()
        mqtt.publish(
            GAME_TOPIC,
            '{"data":"WRONG"}'
        )

        self.selected_color = nil
        self.next_color = 0
        self.demo_index = 0
        self.demo_active = true
        self.selector_started = false
        self.first_correct = false

        self.set_light(false, "FFFFFF")
    end

    def on_mqtt_message(topic, payload)
        if topic == ELEPHANT_TOPIC
            if !self.enable
                return
            end

            if payload == "000000"
                self.set_light(false, "FFFFFF")
                return
            end

            self.selected_color = payload
            self.selector_started = true
            self.demo_active = false

            self.set_light(true, self.selected_color)
            return
        end

        if topic == HAND_SENSOR_TOPIC
            if !self.enable
                return
            end

            if !self.selector_started
                return
            end

            if self.selected_color == nil
                return
            end

            var sensor_data = json.load(payload)

            if sensor_data.find("Switch1", nil) == nil
                return
            end

            if self.next_color >= size(SOLUTION)
                return
            end

            if self.selected_color == SOLUTION[self.next_color]
                if !self.first_correct
                    self.first_correct = true

                    mqtt.publish(
                        VIDEO_TOPIC,
                        '{"data":"VIDEO4START"}'
                    )
                end

                self.next_color += 1

                if self.next_color >= size(SOLUTION)
                    tasmota.set_timer(
                        1000,
                        / -> self.solved()
                    )

                    return
                end

                self.blink_color(self.selected_color)

            else
                self.wrong()
            end
        end
    end

    def init()
        self.enable = false
        self.selected_color = nil
        self.next_color = 0
        self.demo_index = 0
        self.demo_active = false
        self.selector_started = false
        self.first_correct = false

        self.set_light(false, "FFFFFF")

        mqtt.subscribe(
            HAND_SENSOR_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            ELEPHANT_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )
    end

    def enable_game()
        self.enable = true
        self.selected_color = nil
        self.next_color = 0
        self.demo_index = 0
        self.demo_active = true
        self.selector_started = false
        self.first_correct = false

        self.set_light(false, "FFFFFF")

        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.selected_color = nil
        self.next_color = 0
        self.demo_index = 0
        self.demo_active = false
        self.selector_started = false
        self.first_correct = false

        self.set_light(false, "FFFFFF")

        tasmota.resp_cmnd("Game disabled")
    end

    def every_second()
        if !self.enable || !self.demo_active
            return
        end

        if self.demo_index < 6
            self.set_light(
                true,
                SOLUTION[self.demo_index]
            )

            self.demo_index += 1

        elif self.demo_index <= 7
            self.set_light(false, "FFFFFF")

            self.demo_index += 1

        else
            self.demo_index = 0
        end
    end
end

var handgame_driver = Handgame1()
var handgamereaderdriver = Handgamereader()

tasmota.add_driver(handgamereaderdriver)
tasmota.add_driver(handgame_driver)

tasmota.add_cmd(
    "enable",
    / -> handgame_driver.enable_game()
)

tasmota.add_cmd(
    "disable",
    / -> handgame_driver.disable_game()
)

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")