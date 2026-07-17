import mqtt

var INPUT1 = 26
var INPUT2 = 27
var INPUT3 = 14
var INPUT4 = 13
var INPUT5 = 23
var INPUT6 = 22

var ELEPHANT_TOPIC = "CELEPHANT"

var SOLUTION_SEQUENCE = [
    "FFFFFF",
    "0D00FF",
    "FF5F15",
    "FF0000",
    "004D1A",
    "B10061"
]

var COLOR_MAP = [
    "FF0000",
    "FFFFFF",
    "B10061",
    "0D00FF",
    "004D1A",
    "FF5F15"
]

class Elephant
    var current_color
    var last_input
    var selector_inited
    var enable
    var demo_index
    var last_status

    def set_light(power, color)
        light.set({
            "power": power,
            "rgb": color
        })

        tasmota.cmd("State")
    end

    def read_selector()
        if gpio.digital_read(INPUT1)
            return 0
        elif gpio.digital_read(INPUT2)
            return 1
        elif gpio.digital_read(INPUT3)
            return 2
        elif gpio.digital_read(INPUT4)
            return 3
        elif gpio.digital_read(INPUT5)
            return 4
        elif gpio.digital_read(INPUT6)
            return 5
        end

        return nil
    end

    def init()
        self.current_color = nil
        self.last_input = nil
        self.selector_inited = false
        self.enable = false
        self.demo_index = 0
        self.last_status = ""

        self.set_light(false, "FFFFFF")
        mqtt.publish(ELEPHANT_TOPIC, "000000", true)
        self.publish_status()
    end

    def build_status()
        var color = "000000"
        if self.current_color != nil
            color = COLOR_MAP[self.current_color]
        end

        return '{"enabled":' .. (self.enable ? "true" : "false") .. ',"color":"' .. color .. '","demo_index":' .. self.demo_index .. '}'
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish("CELEPHANT/STATUS", msg, true)
    end

    def enable_game()
        self.enable = true
        self.current_color = nil
        self.last_input = nil
        self.selector_inited = false
        self.demo_index = 0

        self.set_light(false, "FFFFFF")
        mqtt.publish(ELEPHANT_TOPIC, "000000", true)
        self.last_status = ""
        self.publish_status()

        tasmota.resp_cmnd("Game enabled and reset")
    end

    def disable_game()
        self.enable = false
        self.current_color = nil
        self.last_input = nil
        self.selector_inited = false
        self.demo_index = 0

        self.set_light(false, "FFFFFF")

        mqtt.publish(
            ELEPHANT_TOPIC,
            "000000",
            true
        )

        self.last_status = ""
        self.publish_status()
        tasmota.resp_cmnd("Game disabled and reset")
    end

    def publish_color()
        if self.current_color == nil
            return
        end

        mqtt.publish(
            ELEPHANT_TOPIC,
            COLOR_MAP[self.current_color],
            true
        )

        self.publish_status()
    end

    def every_second()
        self.publish_status()

        if !self.enable
            return
        end

        if self.demo_index < 6
            self.set_light(
                true,
                SOLUTION_SEQUENCE[self.demo_index]
            )

            self.demo_index += 1

        elif self.demo_index <= 7
            self.set_light(false, "FFFFFF")

            self.demo_index += 1

        else
            self.demo_index = 0
        end
    end

    def every_50ms()
        if !self.enable
            return
        end

        var new_color = self.read_selector()

        if !self.selector_inited
            self.current_color = new_color
            self.last_input = new_color
            self.selector_inited = true
            return
        end

        if new_color == self.last_input
            return
        end

        self.last_input = new_color

        if new_color == nil
            return
        end

        self.current_color = new_color
        self.publish_color()
    end
end

var elephant_driver = Elephant()

tasmota.add_driver(elephant_driver)

tasmota.add_cmd(
    "enable",
    / -> elephant_driver.enable_game()
)

tasmota.add_cmd(
    "disable",
    / -> elephant_driver.disable_game()
)

print("Elephant driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - game enabled")
print("disable - clear selection, lamp OFF and retained MQTT reset")
print("--------------------------------------------------------------")
