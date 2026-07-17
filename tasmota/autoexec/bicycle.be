import mqtt

var BICYCLE_PIN = 1

class Bicycle
    var topic, counter, counted, last_count_time
    var enabled, last_status

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]
        self.counter = 0
        self.counted = false
        self.last_count_time = 0
        self.enabled = true
        self.last_status = ""

        tasmota.add_fast_loop(/ -> self.fast_loop())
        self.publish_status()
    end

    def build_status()
        return '{"enabled":' .. (self.enabled ? "true" : "false") .. ',"counter":' .. self.counter .. ',"target":5}'
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish(self.topic .. "/STATUS", msg, true)
    end

    def reset_state(enabled_state)
        self.enabled = enabled_state
        self.counter = 0
        self.counted = false
        self.last_count_time = 0
        self.last_status = ""
        self.publish_status()
    end

    def init_game()
        self.reset_state(true)
        tasmota.resp_cmnd("Bicycle enabled and reset")
    end

    def disable_game()
        self.reset_state(false)
        tasmota.resp_cmnd("Bicycle disabled and reset")
    end

    def fast_loop()
        if !self.enabled
            self.publish_status()
            return
        end

        var now = tasmota.millis()

        if self.counter > 0 && self.last_count_time > 0 && now - self.last_count_time > 5000
            self.counter = 0
            self.counted = false
            self.last_count_time = 0
            self.publish_status()
        end

        if !gpio.digital_read(BICYCLE_PIN) && !self.counted
            self.counter = self.counter + 1
            self.counted = true
            self.last_count_time = now
            self.publish_status()

            if self.counter >= 5
                mqtt.publish("CLASERGUN/BCOUNTER", "5")
                self.counter = 0
                self.last_count_time = 0
                self.publish_status()
            end
        end

        if gpio.digital_read(BICYCLE_PIN) && self.counted
            self.counted = false
        end
    end
end

var bicycle_driver = Bicycle()
tasmota.add_driver(bicycle_driver)

tasmota.add_cmd("init", /cmd, idx -> bicycle_driver.init_game())
tasmota.add_cmd("enable", / -> bicycle_driver.init_game())
tasmota.add_cmd("disable", / -> bicycle_driver.disable_game())

print("Bicycle driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("init / enable - enable and reset the counter")
print("disable - disable and reset the counter")
print("--------------------------------------------------------------")
