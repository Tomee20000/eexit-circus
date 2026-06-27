var SAW_PIN = 33

var OUT1 = 0

class SawBox
    var counter, saw_in, strip, led_count
    var red_color, green_color, count_per_led
    var started, finished

    def init()
        self.counter = 0
        self.saw_in = false
        self.led_count = 30
        self.count_per_led = 20
        self.started = false
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
        self.started = false
        self.finished = false

        self.strip.clear()
        self.strip.show()

        tasmota.resp_cmnd("Initialized")
    end

    def start_led()
        if self.started
            tasmota.resp_cmnd("Already started")
            return
        end

        self.counter = self.count_per_led
        self.saw_in = false
        self.started = true
        self.finished = false

        self.draw_leds()

        tasmota.resp_cmnd("First LED turned on")
    end

    def fast_loop()
        if !self.started || self.finished
            return
        end

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

    def draw_leds()
        var completed_leds =
            1 +
            int(
                (
                    self.counter
                ) / self.count_per_led
            )

        if completed_leds > self.led_count
            completed_leds = self.led_count
        end

        if completed_leds < 1
            return
        end

        for i: 0..(completed_leds - 1)
            var led_index =
                self.led_count - 1 - i

            self.strip.set_pixel_color(
                led_index,
                self.red_color,
                255
            )
        end

        self.strip.show()
    end

    def every_50ms()
        if !self.started || self.finished
            return
        end

        var target =
            (self.led_count - 1) * self.count_per_led

        self.draw_leds()

        if self.counter >= target
            self.finished = true

            for i: 0..(self.led_count - 1)
                self.strip.set_pixel_color(
                    i,
                    self.green_color,
                    255
                )
            end

            self.strip.show()

            tasmota.set_power(OUT1, false)

            print(
                "SawBox finished, OUT1 turned off"
            )
        end
    end
end

var saw_box_driver = SawBox()

tasmota.add_driver(saw_box_driver)

tasmota.add_cmd(
    "init",
    /cmd, idx -> saw_box_driver.init_game()
)

tasmota.add_cmd(
    "startled",
    /cmd, idx -> saw_box_driver.start_led()
)

print("SawBox driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("init - Initialize the game")
print("startled - Turn on the first LED and start counting")
print("--------------------------------------------------------------")