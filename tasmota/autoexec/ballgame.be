import mqtt
import json

class BallGame
    var timer, sent_timeout

    def on_mqtt_message(topic, payload)
        if topic == "tele/" .. tasmota.cmd("Topic")["Topic"] .. "/SENSOR"
            mqtt.publish(tasmota.cmd("Topic")["Topic"] .. "/BALL", str(json.load(payload)["PN532"]["Data"]))
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
            mqtt.publish(tasmota.cmd("Topic")["Topic"] .. "/BALL", "-")
            self.sent_timeout = true
        end
    end
end

var ballgamedriver = BallGame()
tasmota.add_driver(ballgamedriver)

print("Ballgame driver loaded")