import json

#analog ertekek 3908, 2780, 2030, 1300, 720, 370

var ANALOG_VALUE_MAP = {"low1": 270, "high1": 470, "low2": 620, "high2": 820, "low3": 1200, "high3": 1400, "low4": 1930, "high4": 2130, "low5": 2680, "high5": 2880, "low6": 3345, "high6": 4000}
var ANALOG_KEY_LIST = ["low1", "high1", "low2", "high2", "low3", "high3", "low4", "high4", "low5", "high5", "low6", "high6"]

class AnimalWheel
    var analog, positions, changed, last_changed_time

    def init()
        tasmota.cmd("I2SGain 70")

        self.analog = json.load(tasmota.read_sensors())["ANALOG"]
        self.changed = false
        self.positions = [[6, 0], [6, 0], [6, 0], [6, 0], [6, 0]]
        self.last_changed_time = 0
    end

    def every_50ms()
        self.read_analog()
        self.play_sound()
    end

    def read_analog()
        self.analog = json.load(tasmota.read_sensors())["ANALOG"]

        for i: 0..5
            var low_value = number(ANALOG_VALUE_MAP[ANALOG_KEY_LIST[i * 2]])
            var high_value = number(ANALOG_VALUE_MAP[ANALOG_KEY_LIST[i * 2 + 1]])

            if number(self.analog["A1"]) > low_value && number(self.analog["A1"]) < high_value && self.positions[0][0] != i + 1
                self.positions[0][0] = i + 1
                self.positions[0][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A2"]) > low_value && number(self.analog["A2"]) < high_value && self.positions[1][0] != i + 1
                self.positions[1][0] = i + 1
                self.positions[1][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A3"]) > low_value && number(self.analog["A3"]) < high_value && self.positions[2][0] != i + 1
                self.positions[2][0] = i + 1
                self.positions[2][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A4"]) > low_value && number(self.analog["A4"]) < high_value && self.positions[3][0] != i + 1
                self.positions[3][0] = i + 1
                self.positions[3][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end

            if number(self.analog["A5"]) > low_value && number(self.analog["A5"]) < high_value && self.positions[4][0] != i + 1
                self.positions[4][0] = i + 1
                self.positions[4][1] = tasmota.millis()
                self.changed = true
                self.last_changed_time = tasmota.millis()
            end
        end
    end

    def play_sound()
        if self.changed && (tasmota.millis() - self.last_changed_time) > 500 && (tasmota.millis() - self.last_changed_time) < 1000 
            self.changed = false
            var latest_pos = 6
            var latest_time = 0
            var latest_wheel = 0

            for i: 0..4
                if self.positions[i][0] != 6 && self.positions[i][1] > latest_time 
                    latest_pos = self.positions[i][0]
                    latest_time = self.positions[i][1]
                    latest_wheel = i + 1
                end

                self.positions[i][1] = 0
            end
            
            print("Latest wheel: " .. latest_wheel)
            print("Latest pos: " .. latest_pos)

            if latest_pos == 1
                tasmota.cmd("I2SPlay /mp3/monkey.mp3")
            elif latest_pos == 2
                tasmota.cmd("I2SPlay /mp3/horse.mp3")
            elif latest_pos == 3
                tasmota.cmd("I2SPlay /mp3/snake.mp3")
            elif latest_pos == 4
                tasmota.cmd("I2SPlay /mp3/elephant.mp3")
            elif latest_pos == 5
                tasmota.cmd("I2SPlay /mp3/tiger.mp3")
            end
        
        end
    end
end

var animal_wheel_driver = AnimalWheel()
tasmota.add_driver(animal_wheel_driver)

print("AnimalWheel driver loaded")