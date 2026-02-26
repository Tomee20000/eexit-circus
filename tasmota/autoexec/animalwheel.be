import json

#analog ertekek 3908, 2780, 2030, 1300, 720, 370

var analog_value_map = {"low1": 270, "high1": 470,"low2": 620, "high2": 820,"low3": 1200, "high3": 1400,"low4": 1930, "high4": 2130,"low5": 2680, "high5": 2880,"low6": 3345, "high6": 4000}
var key_list = ["low1", "high1", "low2", "high2", "low3", "high3", "low4", "high4", "low5", "high5", "low6", "high6"]

class AnimalWheel
    var wheel_pos, analog, a, last_a1, last_a2, last_a3, last_a4, last_a5, changed, last_changed_time

    def init()
        self.wheel_pos = []
        self.analog = json.load(tasmota.read_sensors())["ANALOG"]
        self.changed = false
        self.a = [[6,0],[6,0],[6,0],[6,0],[6,0]]
        self.last_changed_time = 0

        self.last_a1 = self.a[0]
        self.last_a2 = self.a[1]
        self.last_a3 = self.a[2]
        self.last_a4 = self.a[3]
        self.last_a5 = self.a[4]
    end

    def every_50ms()
        self.read_analog()
        self.play_sound()
    end

    def read_analog()
        self.analog = json.load(tasmota.read_sensors())["ANALOG"]

        for i: 0..5
            var lowVal = number(analog_value_map[key_list[i * 2]])
            var highVal = number(analog_value_map[key_list[i * 2 + 1]])

            if number(self.analog["A1"]) > lowVal && number(self.analog["A1"]) < highVal && self.a[0][0] != i + 1
                self.a[0][0] = i + 1
                self.a[0][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A2"]) > lowVal && number(self.analog["A2"]) < highVal && self.a[1][0] != i + 1
                self.a[1][0] = i + 1
                self.a[1][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A3"]) > lowVal && number(self.analog["A3"]) < highVal && self.a[2][0] != i + 1
                self.a[2][0] = i + 1
                self.a[2][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A4"]) > lowVal && number(self.analog["A4"]) < highVal && self.a[3][0] != i + 1
                self.a[3][0] = i + 1
                self.a[3][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A5"]) > lowVal && number(self.analog["A5"]) < highVal && self.a[4][0] != i + 1
                self.a[4][0] = i + 1
                self.a[4][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end
        end
    end

    def play_sound()
        if self.changed && (tasmota.millis() - self.last_changed_time) > 1000 && (tasmota.millis() - self.last_changed_time) < 2000 
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

                self.a[i][1] = 0
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