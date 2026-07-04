import json
import mqtt

var MQTT_TOPIC = "CANIMALWHEEL/"
var STABLE_MS = 200

var ANALOG_VALUE_MAP = {
    "low1": 270, "high1": 470,
    "low2": 620, "high2": 820,
    "low3": 1200, "high3": 1400,
    "low4": 1930, "high4": 2130,
    "low5": 2680, "high5": 2880,
    "low6": 3345, "high6": 4000
}

var ANALOG_KEY_LIST = [
    "low1", "high1",
    "low2", "high2",
    "low3", "high3",
    "low4", "high4",
    "low5", "high5",
    "low6", "high6"
]

var SOUND_MAP = [
    [
        "/mp3/monkey.mp3",
        "/mp3/horse.mp3",
        "/mp3/snake.mp3",
        "/mp3/elephant.mp3",
        "/mp3/lion.mp3"
    ],
    [
        "/mp3/horse.mp3",
        "/mp3/snake.mp3",
        "/mp3/elephant.mp3",
        "/mp3/lion.mp3",
        "/mp3/monkey.mp3"
    ],
    [
        "/mp3/snake.mp3",
        "/mp3/elephant.mp3",
        "/mp3/lion.mp3",
        "/mp3/monkey.mp3",
        "/mp3/horse.mp3"
    ],
    [
        "/mp3/elephant.mp3",
        "/mp3/lion.mp3",
        "/mp3/monkey.mp3",
        "/mp3/horse.mp3",
        "/mp3/snake.mp3"
    ],
    [
        "/mp3/lion.mp3",
        "/mp3/monkey.mp3",
        "/mp3/horse.mp3",
        "/mp3/snake.mp3",
        "/mp3/elephant.mp3"
    ]
]

var ANIMAL_MAP = [
    ["MONKEY", "HORSE", "SNAKE", "ELEPHANT", "LION"],
    ["HORSE", "SNAKE", "ELEPHANT", "LION", "MONKEY"],
    ["SNAKE", "ELEPHANT", "LION", "MONKEY", "HORSE"],
    ["ELEPHANT", "LION", "MONKEY", "HORSE", "SNAKE"],
    ["LION", "MONKEY", "HORSE", "SNAKE", "ELEPHANT"]
]

class AnimalWheel
    var analog
    var positions
    var pending_positions
    var pending_since
    var enabled
    var initialized
    var startup_published
    var sound_playing
    var sound_wheel
    var sound_position

    def init()
        tasmota.cmd("I2SGain 70")

        self.analog = {}

        self.positions = [0, 0, 0, 0, 0]
        self.pending_positions = [0, 0, 0, 0, 0]
        self.pending_since = [0, 0, 0, 0, 0]

        self.enabled = false
        self.initialized = false
        self.startup_published = false

        self.sound_playing = false
        self.sound_wheel = -1
        self.sound_position = 0
    end

    def valid_animal_position(position)
        return position >= 1 && position <= 5
    end

    def animal_name(wheel, position)
        if self.valid_animal_position(position)
            return ANIMAL_MAP[wheel][position - 1]
        end

        return "-"
    end

    def stop_sound()
        if self.sound_playing
            tasmota.cmd("I2SStop")

            self.sound_playing = false
            self.sound_wheel = -1
            self.sound_position = 0

            print("Sound stopped")
        end
    end

    def play_sound(wheel, position)
        if !self.enabled
            return
        end

        if !self.valid_animal_position(position)
            return
        end

        var sound = SOUND_MAP[wheel][position - 1]

        self.sound_playing = true
        self.sound_wheel = wheel
        self.sound_position = position

        print("Wheel: " .. str(wheel + 1))
        print(
            "Animal: " ..
            self.animal_name(wheel, position)
        )
        print("Playing: " .. sound)

        tasmota.cmd("I2SPlay " .. sound)
    end

    def publish_wheel(wheel)
        if !mqtt.connected()
            return
        end

        var topic = MQTT_TOPIC .. str(wheel + 1)
        var animal = self.animal_name(
            wheel,
            self.positions[wheel]
        )

        var payload = "{\"data\":\"" .. animal .. "\"}"

        mqtt.publish(topic, payload, true)

        print("MQTT: " .. topic .. " = " .. payload)
    end

    def publish_all()
        for i: 0..4
            self.publish_wheel(i)
        end
    end

    def enable()
        self.enabled = true
        tasmota.resp_cmnd("AnimalWheel enabled")
    end

    def disable()
        self.enabled = false
        self.stop_sound()
        tasmota.resp_cmnd("AnimalWheel disabled")
    end

    def get_position(analog_name)
        var value = number(self.analog[analog_name])

        for i: 0..5
            var low_value = number(
                ANALOG_VALUE_MAP[ANALOG_KEY_LIST[i * 2]]
            )

            var high_value = number(
                ANALOG_VALUE_MAP[ANALOG_KEY_LIST[i * 2 + 1]]
            )

            if value > low_value && value < high_value
                return i + 1
            end
        end

        return 0
    end

    def read_initial_positions()
        self.analog = json.load(
            tasmota.read_sensors()
        )["ANALOG"]

        self.positions[0] = self.get_position("A1")
        self.positions[1] = self.get_position("A2")
        self.positions[2] = self.get_position("A3")
        self.positions[3] = self.get_position("A4")
        self.positions[4] = self.get_position("A5")

        for i: 0..4
            self.pending_positions[i] = self.positions[i]
            self.pending_since[i] = 0
        end
    end

    def update_position(wheel, analog_name)
        var new_position = self.get_position(analog_name)
        var now = tasmota.millis()

        if self.sound_playing &&
           self.sound_wheel == wheel &&
           new_position != self.sound_position

            self.stop_sound()
        end

        if !self.valid_animal_position(new_position)
            self.pending_positions[wheel] = new_position
            self.pending_since[wheel] = 0

            if new_position != self.positions[wheel]
                self.positions[wheel] = new_position
                return true
            end

            return false
        end

        if new_position != self.pending_positions[wheel]
            self.pending_positions[wheel] = new_position
            self.pending_since[wheel] = now
            return false
        end

        if new_position == self.positions[wheel]
            self.pending_since[wheel] = 0
            return false
        end

        if self.pending_since[wheel] == 0
            self.pending_since[wheel] = now
            return false
        end

        if now - self.pending_since[wheel] < STABLE_MS
            return false
        end

        self.positions[wheel] = new_position
        self.pending_since[wheel] = 0

        return true
    end

    def read_analog()
        self.analog = json.load(
            tasmota.read_sensors()
        )["ANALOG"]

        var changed = false
        var latest_wheel = -1
        var latest_position = 0

        if self.update_position(0, "A1")
            changed = true
            latest_wheel = 0
            latest_position = self.positions[0]
        end

        if self.update_position(1, "A2")
            changed = true
            latest_wheel = 1
            latest_position = self.positions[1]
        end

        if self.update_position(2, "A3")
            changed = true
            latest_wheel = 2
            latest_position = self.positions[2]
        end

        if self.update_position(3, "A4")
            changed = true
            latest_wheel = 3
            latest_position = self.positions[3]
        end

        if self.update_position(4, "A5")
            changed = true
            latest_wheel = 4
            latest_position = self.positions[4]
        end

        if !changed
            return
        end

        self.publish_all()

        if latest_wheel >= 0
            self.play_sound(
                latest_wheel,
                latest_position
            )
        end
    end

    def every_50ms()
        if !self.initialized
            self.read_initial_positions()
            self.initialized = true
            return
        end

        self.read_analog()

        if !self.startup_published &&
           mqtt.connected()

            self.startup_published = true
            self.publish_all()
        end
    end
end

var animal_wheel_driver = AnimalWheel()
tasmota.add_driver(animal_wheel_driver)

tasmota.add_cmd(
    "enable",
    / -> animal_wheel_driver.enable()
)

tasmota.add_cmd(
    "disable",
    / -> animal_wheel_driver.disable()
)

print("AnimalWheel driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - enable AnimalWheel sound")
print("disable - disable AnimalWheel sound")
print("--------------------------------------------------------------")