#-
#FFFFFF   (fehér)
#0D00FF   (kék)
#FF5F15   (sárga)
#FF0000   (piros)
#004D1A   (sötétzöld)
#B10061   (lila / magenta)
#000000   (fekete - szünet)
-#

import mqtt
import json

var UID_MAP = {
    "F42A6E05": 1,
    "B357B303": 2,
    "3FF4F829": 3,
    "0D807606": 4
}

var COLOR_MAP = [
    "FFFFFF",
    "0D00FF",
    "FF5F15",
    "FF0000",
    "004D1A",
    "B10061"
]

class Handgame1
    var enable
    var elephant_color
    var next_color
    var blink_current
    var solving_started
    var first_correct
    var paused

    def game_solved_blink()
        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":false, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":true, "rgb":"008000"})
        tasmota.delay(250)

        light.set({"power":false, "rgb":"008000"})
        tasmota.cmd("State")

        mqtt.publish("CHANDGAME", "SOLVED")
    end

    def pause_for_video()
        self.paused = true

        light.set({
            "power":false,
            "rgb":"000000"
        })

        tasmota.cmd("State")

        mqtt.publish(
            "CC/videocontrol",
            '{"data":"VIDEO4START"}'
        )

        print("VIDEO4START sent, game paused")
    end

    def continue_after_video()
        if !self.paused
            return
        end

        self.paused = false

        if self.enable && self.solving_started && self.elephant_color != nil
            light.set({
                "power":true,
                "rgb":self.elephant_color
            })

            tasmota.cmd("State")
        end

        print("VIDEO4END received, game continued")
    end

    def on_mqtt_message(topic, payload)
        if topic == "CC/videocontrol"
            var video_json = json.load(payload)
            var video_data = video_json.find("data", nil)

            if video_data == "VIDEO4END"
                self.continue_after_video()
            end

            return
        end

        if topic == "CELEPHANT"
            self.elephant_color = payload

            if self.solving_started && !self.paused
                light.set({
                    "power":true,
                    "rgb":self.elephant_color
                })

                tasmota.cmd("State")
            end

            return
        end

        if topic == "tele/CHANDGAME2/SENSOR"
            if !self.enable || self.paused
                return
            end

            var sensor_data = json.load(payload)

            if sensor_data.find("Switch1", nil) == nil
                return
            end

            if self.next_color >= 6
                return
            end

            if self.elephant_color == COLOR_MAP[self.next_color]
                self.solving_started = true
                self.next_color += 1

                if !self.first_correct
                    self.first_correct = true
                    self.pause_for_video()
                    return
                end

                light.set({
                    "power":false,
                    "rgb":self.elephant_color
                })

                tasmota.delay(250)

                light.set({
                    "power":true,
                    "rgb":self.elephant_color
                })

                tasmota.delay(250)

                light.set({
                    "power":false,
                    "rgb":self.elephant_color
                })

                tasmota.delay(250)

                light.set({
                    "power":true,
                    "rgb":self.elephant_color
                })

                tasmota.delay(250)

                light.set({
                    "power":false,
                    "rgb":self.elephant_color
                })

                tasmota.delay(250)

                light.set({
                    "power":true,
                    "rgb":self.elephant_color
                })

                tasmota.cmd("State")

            elif self.elephant_color != COLOR_MAP[self.next_color]
                if self.solving_started
                    light.set({
                        "power":false,
                        "rgb":"FFFFFF"
                    })

                    tasmota.cmd("State")

                    self.elephant_color = nil
                    self.next_color = 0
                    self.blink_current = 0
                    self.solving_started = false
                end
            end

            if self.next_color == 6
                print("Game solved")

                self.enable = false
                self.paused = false
                self.solving_started = false

                tasmota.set_timer(
                    1000,
                    / -> self.game_solved_blink()
                )
            end
        end
    end

    def init()
        mqtt.subscribe(
            "tele/CHANDGAME2/SENSOR",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            "CELEPHANT",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            "CC/videocontrol",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        light.set({
            "power":false,
            "rgb":"FFFFFF"
        })

        tasmota.cmd("State")

        self.enable = false
        self.elephant_color = nil
        self.next_color = 0
        self.blink_current = 0
        self.solving_started = false
        self.first_correct = false
        self.paused = false
    end

    def enable_game()
        self.enable = true
        self.paused = false
        self.solving_started = false
        self.first_correct = false
        self.elephant_color = nil
        self.next_color = 0
        self.blink_current = 0

        light.set({
            "power":false,
            "rgb":"FFFFFF"
        })

        tasmota.cmd("State")
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        self.paused = false
        self.solving_started = false

        light.set({
            "power":false,
            "rgb":"FFFFFF"
        })

        tasmota.cmd("State")
        tasmota.resp_cmnd("Game disabled")
    end

    def every_second()
        if self.paused
            return
        end

        if !self.solving_started && self.enable
            if self.blink_current < 6
                var current_color = COLOR_MAP[self.blink_current]

                mqtt.publish(
                    tasmota.cmd("Topic")["Topic"],
                    current_color
                )

                light.set({
                    "power":true,
                    "rgb":current_color
                })

                self.blink_current += 1

            elif self.blink_current <= 7
                mqtt.publish(
                    tasmota.cmd("Topic")["Topic"],
                    "000000"
                )

                light.set({
                    "power":false,
                    "rgb":"FFFFFF"
                })

                self.blink_current += 1

            else
                self.blink_current = 0
            end

            tasmota.cmd("State")
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