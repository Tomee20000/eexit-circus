var BICYCLE = 1

class Bicycle
    var counter, counted

    def init()
        self.counter = 0
        self.counted = false
        tasmota.add_fast_loop(/-> self.fast_loop())
    end

    def initGame() #for command
        self.counter = 0
        self.counted = false
        tasmota.resp_cmnd("Initialized")
    end

    def fast_loop()
        if !gpio.digital_read(BICYCLE) && !self.counted
            self.counter = self.counter + 1 
            self.counted = true

            mqtt.publish("CLASERGUN/BCOUNTER",self.counter)
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