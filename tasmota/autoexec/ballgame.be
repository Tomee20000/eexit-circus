import mqtt
import json

class BallGame
    var timeout_seconds, timeout_sent, topic

    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. self.topic .. "/SENSOR"
            var j = json.load(payload)
            var pn532 = j.find("PN532", nil)
            if pn532 == nil
                return nil
            end

            var data = pn532.find("Data", nil)
            if data == nil
                return nil
            end

            mqtt.publish(self.topic .. "/BALL", str(data))
            self.timeout_seconds = 0
            self.timeout_sent = false
        end
    end

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]
        self.timeout_seconds = 0
        self.timeout_sent = false
        mqtt.subscribe("tele/" .. self.topic .. "/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
        mqtt.publish(self.topic .. "/BALL", "-")
    end

    def every_second()
        self.timeout_seconds = self.timeout_seconds + 1
        if self.timeout_seconds > 5 && !self.timeout_sent
            mqtt.publish(self.topic .. "/BALL", "-")
            self.timeout_sent = true
        end
    end
end

var ball_game_driver = BallGame()
tasmota.add_driver(ball_game_driver)

print("BallGame driver loaded")