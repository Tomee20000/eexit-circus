import mqtt
import string

class Handgamereader
    var timer, sent_timeout, topic
    var uid_map

    def extract_uid(payload_str)
        var key = '"UID":"'
        var pos = string.find(payload_str, key)

        if pos == -1
            return nil
        end

        var start = pos + size(key)
        var uid_str = payload_str[start..(size(payload_str) - 1)]
        var endpos = string.find(uid_str, '"')

        if endpos == -1
            return nil
        end

        return uid_str[0..(endpos - 1)]
    end

    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. self.topic .. "/SENSOR"
            var payload_str = str(payload)
            var data = self.extract_uid(payload_str)

            if data == nil
                return nil
            end

            mqtt.publish(self.topic .. "/CARD", str(self.uid_map[data]))
            self.timer = 0
            self.sent_timeout = false
        end
    end

    def init()
        self.uid_map = {
            "F42A6E05": 1,
            "B357B303": 2,
            "3FF4F829": 3,
            "0D807606": 4,
            "97A37606": 5,
            "26567306": 6,
            "8CAD7306": 7
        }

        self.topic = tasmota.cmd("Topic")["Topic"]
        self.timer = 0
        self.sent_timeout = false

        mqtt.subscribe(
            "tele/" .. self.topic .. "/SENSOR",
            /t, idx, data, b -> self.on_mqtt_message(t, data)
        )

        mqtt.publish(self.topic .. "/CARD", "-")

        print("Handgamereader driver loaded")
    end

    def every_second()
        self.timer = self.timer + 1

        if self.timer >= 3 && !self.sent_timeout
            mqtt.publish(self.topic .. "/CARD", "-")
            self.sent_timeout = true
        end
    end
end