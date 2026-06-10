var SAW_PIN = 33

var OUT1 = 0

class SawBox
    var counter, saw_in, strip, led_count
    var red_color, green_color, count_per_led
    var finished

    def init()
        self.counter = 0
        self.saw_in = false
        self.led_count = 30
        self.count_per_led = 25
        self.finished = false

        self.red_color = self.rgb(255, 0, 0)
        self.green_color = self.rgb(0, 255, 0)

        self.strip = Leds(
            self.led_count,
            gpio.pin(gpio.WS2812, 3)
        )

        self.strip.clear()
        self.strip.show()

        tasmota.add_fast_loop(/ -> self.fast_loop())
    end

    def init_game()
        self.counter = 0
        self.saw_in = false
        self.finished = false

        self.strip.clear()
        self.strip.show()

        tasmota.resp_cmnd("Initialized")
    end

    def fast_loop()
        if !gpio.digital_read(SAW_PIN) && !self.saw_in
            self.counter += 1
            self.saw_in = true
        end

        if gpio.digital_read(SAW_PIN) && self.saw_in
            self.saw_in = false
        end
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def every_50ms()
        var target = self.count_per_led * self.led_count

        if self.counter > 0 && self.counter < target
            var led_index = 29 - (
                self.counter / self.count_per_led - 1
            )

            if led_index >= 0 && led_index < self.led_count
                self.strip.set_pixel_color(
                    led_index,
                    self.red_color,
                    255
                )
            end
        end

        if self.counter >= target && !self.finished
            self.finished = true

            for i: 0..(self.led_count - 1)
                self.strip.set_pixel_color(
                    i,
                    self.green_color,
                    255
                )
            end

            tasmota.set_power(OUT1, false)
            print("SawBox finished, OUT1 turned off")
        end

        self.strip.show()
    end
end

var saw_box_driver = SawBox()
tasmota.add_driver(saw_box_driver)

tasmota.add_cmd(
    "init",
    /cmd, idx -> saw_box_driver.init_game()
)

print("SawBox driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("init - Initialize the game")
print("--------------------------------------------------------------")