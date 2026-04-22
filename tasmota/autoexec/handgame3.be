import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}

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

var handgamereaderdriver = Handgamereader()
tasmota.add_driver(handgamereaderdriver)

print("Handgamereader driver loaded")