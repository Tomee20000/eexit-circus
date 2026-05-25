import mqtt
import json

var uid_map = {"F42A6E05": 1,"B357B303": 2, "3FF4F829": 3,"0D807606": 4}

class Handgamereader
    var timer, sent_timeout, topic

    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. self.topic .. "/SENSOR"
            var j = json.load(payload)
            var pn532 = j.find("PN532", nil)
            if pn532 == nil
                return nil
            end

            var data = pn532.find("UID", nil)
            if data == nil
                return nil
            end

            mqtt.publish(self.topic .. "/CARD", str(data))
            self.timer = 0
            self.sent_timeout = false
        end
    end

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]
        self.timer = 0
        self.sent_timeout = false
        mqtt.subscribe("tele/" .. self.topic .. "/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
        mqtt.publish(self.topic .. "/CARD", "-")    
    end

    def every_second()
        self.timer = self.timer + 1
        if self.timer > 5 && !self.sent_timeout
            mqtt.publish(self.topic .. "/CARD", "-")
            self.sent_timeout = true
        end
    end
end

var handgamereaderdriver = Handgamereader()
tasmota.add_driver(handgamereaderdriver)

print("Handgamereader driver loaded")