var BICYCLE = 1

class Bicycle
    var counter, counted, last_count_time

    def init()
        self.counter = 0
        self.counted = false
        self.last_count_time = 0
        tasmota.add_fast_loop(/-> self.fast_loop())
    end

    def initGame() #for command
        self.counter = 0
        self.counted = false
        self.last_count_time = 0
        tasmota.resp_cmnd("Initialized")
    end

    def fast_loop()
        var now = tasmota.millis()

        if self.counter > 0 && self.last_count_time > 0 && now - self.last_count_time > 5000
            self.counter = 0
            self.counted = false
            self.last_count_time = 0
        end

        if !gpio.digital_read(BICYCLE) && !self.counted
            self.counter = self.counter + 1
            self.counted = true
            self.last_count_time = now

            if self.counter >= 5
                mqtt.publish("CLASERGUN/BCOUNTER", "5")
                self.counter = 0
                self.last_count_time = 0
            end
        end

        if gpio.digital_read(BICYCLE) && self.counted
            self.counted = false
        end
    end
end

var bicycledriver = Bicycle()
tasmota.add_driver(bicycledriver)

tasmota.add_cmd("init", /cmd, idx -> bicycledriver.initGame())

print("Bicycle driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("init - Initialize the counter")
print("--------------------------------------------------------------")