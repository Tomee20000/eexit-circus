import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}

class Handgame1
    var enable

    def on_mqtt_message(topic, payload)
        if topic == "CELEPHANT" && self.enable
            light.set({"power": true, "rgb": payload})
            tasmota.cmd("State")
        end
    end

    def init()
        mqtt.subscribe("CELEPHANT", /t, idx, data, b -> self.on_mqtt_message(t, data))
        light.set({"power":false, "rgb":"FFFFFF"})
        self.enable = false
    end

    def enable_game()
        self.enable = true
        tasmota.resp_cmnd("Game enabled")
    end

    def disable_game()
        self.enable = false
        light.set({"power":false, "rgb":"FFFFFF"})
        tasmota.resp_cmnd("Game disabled")
    end
end

class Handgamereader
    var timer, sent_timeout

    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. tasmota.cmd("Topic")["Topic"] .. "/SENSOR"
            mqtt.publish(tasmota.cmd("Topic")["Topic"] .. "/CARD", str(uid_map[json.load(payload)["PN532"]["UID"]]))
            self.timer = 0
            self.sent_timeout = false
        end
    end

    def init()
        self.timer = 0
        self.sent_timeout = false
        mqtt.subscribe("tele/" .. tasmota.cmd("Topic")["Topic"] .. "/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
    end

    def every_second()
        self.timer = self.timer + 1
        if self.timer > 5 && !self.sent_timeout
            mqtt.publish(tasmota.cmd("Topic")["Topic"] .. "/CARD", "-")
            self.sent_timeout = true
        end
    end
end

var handgamedriver = Handgame1()
tasmota.add_driver(handgamedriver)

tasmota.add_cmd("enable", / -> handgamedriver.enable_game())
tasmota.add_cmd("disable", / -> handgamedriver.disable_game())

print("Handgame1 driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")

var handgamereaderdriver = Handgamereader()
tasmota.add_driver(handgamereaderdriver)

print("Handgamereader driver loaded")