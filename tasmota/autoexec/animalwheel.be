import json

var analog_value_map = {"low1": 1, "high1": 545,"low2": 546, "high2": 1010,"low3": 1011, "high3": 1665,"low4": 1666, "high4": 2405,"low5": 2406, "high5": 3344,"low6": 3345, "high6": 4000}
var key_list = ["low1", "high1", "low2", "high2", "low3", "high3", "low4", "high4", "low5", "high5", "low6", "high6"]

class AnimalWheel
    var wheel_pos, analog, a, last_a1, last_a2, last_a3, last_a4, last_a5, changed

    def init()
        self.wheel_pos = []
        self.analog = json.load(tasmota.read_sensors())["ANALOG"]
        self.changed = false
        self.a = [[6,0],[6,0],[6,0],[6,0],[6,0]]

        self.last_a1 = self.a[0]
        self.last_a2 = self.a[1]
        self.last_a3 = self.a[2]
        self.last_a4 = self.a[3]
        self.last_a5 = self.a[4]
    end

    def every_50ms()
        self.read_analog()
    end

    def every_second()

    end

    def read_analog()
        self.analog = json.load(tasmota.read_sensors())["ANALOG"]

        for i: 0..4
            var lowVal = number(analog_value_map[key_list[i * 2]])
            var highVal = number(analog_value_map[key_list[i * 2 + 1]])

            if number(self.analog["A1"]) > lowVal && number(self.analog["A1"]) < highVal && self.a[0] != i + 1
                self.a[0][0] = i + 1
                self.a[0][1] = tasmota.millis()
                self.changed = true
            end

            if number(self.analog["A2"]) > lowVal && number(self.analog["A2"]) < highVal && self.a[1] != i + 1
                self.a[1][0] = i + 1
                self.a[1][1] = tasmota.millis()
                self.changed = true
            end

            if number(self.analog["A3"]) > lowVal && number(self.analog["A3"]) < highVal && self.a[2] != i + 1
                self.a[2][0] = i + 1
                self.a[2][1] = tasmota.millis()
                self.changed = true
            end

            if number(self.analog["A4"]) > lowVal && number(self.analog["A4"]) < highVal && self.a[3] != i + 1
                self.a[3][0] = i + 1
                self.a[3][1] = tasmota.millis()
                self.changed = true
            end

            if number(self.analog["A5"]) > lowVal && number(self.analog["A5"]) < highVal && self.a[4] != i + 1
                self.a[4][0] = i + 1
                self.a[4][1] = tasmota.millis()
                self.changed = true
            end
        end
    end

    def play_sound()
        if self.changed
            self.changed = false
            var latest_pos = 6
            var latest_time = 0
            var latest_wheel = 0

            for i: 0..4
                if self.a[i][0] != 6 && self.a[i][1] > latest_time 
                    latest_pos = self.a[i][0]
                    latest_time = self.a[i][1]
                    latest_wheel = i + 1
                end
            end
            
            print("Latest wheel: " .. latest_wheel)
            print("Latest pos: " .. latest_pos)

            if latest_pos == 1
                tasmota.cmd("i2ssay one")
            elif latest_pos == 2
                tasmota.cmd("i2ssay two")
            elif latest_pos == 3
                tasmota.cmd("i2ssay three")
            elif latest_pos == 4
                tasmota.cmd("i2ssay four")
            elif latest_pos == 5
                tasmota.cmd("i2ssay five")
            end
        
        end
    end
end

var animalwheel = AnimalWheel()
tasmota.add_driver(animalwheel)

print ("AnimalWheel driver loaded")