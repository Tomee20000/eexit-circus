import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}

class Handgamereader
    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. tasmota.cmd("Topic")["Topic"] .. "/SENSOR"
            mqtt.publish(tasmota.cmd("Topic")["Topic"] .. "/CARD", str(uid_map[json.load(payload)["PN532"]["UID"]]))
        end
    end

    def init()
        mqtt.subscribe("tele/" .. tasmota.cmd("Topic")["Topic"] .. "/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
    end
end

var handgamereaderdriver = Handgamereader()
tasmota.add_driver(handgamereaderdriver)

print("Handgamereader driver loaded")