import mqtt

class Handgame
    var enable

    def on_mqtt_message(topic, payload)
        if topic == "CELEPHANT" && self.enable
            light.set({"power": true, "rgb": payload})
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

var handgamedriver = Handgame()
tasmota.add_driver(handgamedriver)

tasmota.add_cmd("enable", / -> handgamedriver.enable_game())
tasmota.add_cmd("disable", / -> handgamedriver.disable_game())

print("Handgame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - game disabled")
print("--------------------------------------------------------------")