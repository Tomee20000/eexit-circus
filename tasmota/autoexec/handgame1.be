import mqtt
import json

var HAND_TOPIC = "CHANDGAME1"
var HAND_STATUS_TOPIC = "CHANDGAME1/STATUS"
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
    var video_started
    var solved_state
    var run_id
    var last_status

    def set_light(power, color)
        light.set({
            "power": power,
            "rgb": color
        })

        tasmota.cmd("State")
    end

    def build_status()
        var selected = self.selected_color
        if selected == nil
            selected = "000000"
        end

        var text = "Inaktív"
        if self.solved_state
            text = "Megoldva"
        elif self.enable
            text = "Aktív - következő szín: " .. str(self.next_color + 1) .. " / " .. str(size(SOLUTION))
        end

        return '{"enabled":' .. (self.enable ? "true" : "false") ..
               ',"solved":' .. (self.solved_state ? "true" : "false") ..
               ',"progress":' .. self.next_color ..
               ',"total":' .. size(SOLUTION) ..
               ',"selected_color":"' .. selected ..
               '","video_started":' .. (self.video_started ? "true" : "false") ..
               ',"text":"' .. text .. '"}'
    end

    def publish_status()
        var msg = self.build_status()
        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish(HAND_STATUS_TOPIC, msg, true)
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

        self.set_light(true, color)
    end

    def finish_solved(id)
        if id != self.run_id || !self.enable
            return
        end

        self.enable = false
        self.solved_state = true
        self.next_color = size(SOLUTION)

        mqtt.publish(
            HAND_TOPIC,
            "SOLVED_BLINK"
        )

        self.publish_status()
        self.green_blink()

        mqtt.publish(
            GAME_TOPIC,
            '{"data":"SOLVED"}'
        )

        self.publish_status()
    end

    def wrong()
        mqtt.publish(
            GAME_TOPIC,
            '{"data":"WRONG"}'
        )

        self.next_color = 0

        if self.selected_color != nil
            self.set_light(true, self.selected_color)
        else
            self.set_light(false, "FFFFFF")
        end

        self.publish_status()
    end

    def on_mqtt_message(topic, payload)
        if topic == ELEPHANT_TOPIC
            if !self.enable
                return
            end

            if payload == "000000"
                self.selected_color = nil
                self.set_light(false, "FFFFFF")
                self.publish_status()
                return
            end

            self.selected_color = payload
            self.set_light(true, self.selected_color)
            self.publish_status()

            return
        end

        if topic == HAND_SENSOR_TOPIC
            if !self.enable
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
                if !self.video_started
                    self.video_started = true

                    mqtt.publish(
                        VIDEO_TOPIC,
                        '{"data":"VIDEO4START"}'
                    )
                end

                self.next_color += 1
                self.publish_status()

                if self.next_color >= size(SOLUTION)
                    var id = self.run_id

                    tasmota.set_timer(
                        1000,
                        / -> self.finish_solved(id)
                    )

                    return
                end

                self.blink_color(self.selected_color)

            else
                self.wrong()
            end
        end
    end

    def reset_game(enabled_state, stop_video)
        self.run_id += 1

        if stop_video && self.video_started
            mqtt.publish(
                VIDEO_TOPIC,
                '{"data":"VIDEO4STOP"}'
            )
        end

        self.enable = enabled_state
        self.selected_color = nil
        self.next_color = 0
        self.video_started = false
        self.solved_state = false

        self.set_light(false, "FFFFFF")

        self.last_status = ""
        self.publish_status()
    end

    def init()
        self.enable = false
        self.selected_color = nil
        self.next_color = 0
        self.video_started = false
        self.solved_state = false
        self.run_id = 0
        self.last_status = ""

        self.set_light(false, "FFFFFF")

        mqtt.subscribe(
            HAND_SENSOR_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.subscribe(
            ELEPHANT_TOPIC,
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        self.publish_status()
    end

    def enable_game()
        self.reset_game(true, true)
        tasmota.resp_cmnd("Game enabled and reset")
    end

    def force_complete()
        self.run_id += 1
        self.enable = true
        self.solved_state = false
        var id = self.run_id
        self.finish_solved(id)
        tasmota.resp_cmnd("Handgame force completed")
    end

    def disable_game()
        self.reset_game(false, true)
        tasmota.resp_cmnd("Game disabled and reset")
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

tasmota.add_cmd(
    "forcecomplete",
    / -> handgame_driver.force_complete()
)

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled from clean state")
print("disable - game disabled and fully reset")
print("forcecomplete - normal solved blink and SOLVED event")
print("--------------------------------------------------------------")
