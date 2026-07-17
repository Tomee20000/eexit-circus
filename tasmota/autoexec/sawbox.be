import mqtt

var SAW_PIN = 33
var OUT1 = 0

var SAW_SOUND_TOPIC = "CSAWBOX/SOUND"
var SAW_STATUS_TOPIC = "CSAWBOX/STATUS"

var SAW_GAIN = 100
var SAW_RESTART_MS = 83000

var SAWING_TIMEOUT_MS = 300

class SawBox
    var counter, saw_in, strip, led_count
    var red_color, green_color, count_per_led
    var started, finished
    var sound_started, sound_loud, sound_start
    var last_sound_state
    var last_pin_state, last_move_time
    var last_progress

    def init()
        self.counter = 0
        self.saw_in = false
        self.led_count = 30
        self.count_per_led = 10
        self.started = false
        self.finished = false

        self.sound_started = false
        self.sound_loud = false
        self.sound_start = 0
        self.last_sound_state = ""

        self.last_pin_state = gpio.digital_read(SAW_PIN)
        self.last_move_time = 0
        self.last_progress = ""

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

    def completed_leds()
        if !self.started && !self.finished
            return 0
        end

        var c = 1 + int(self.counter / self.count_per_led)
        if c > self.led_count
            c = self.led_count
        end
        if c < 0
            c = 0
        end
        return c
    end

    def publish_progress()
        var leds = self.completed_leds()
        var text = str(leds) .. " / " .. str(self.led_count) .. " LED"
        if self.finished
            text = text .. " - kész"
        end
        if !self.started && !self.finished
            text = "Inaktív - " .. text
        end

        var msg = '{"text":"' .. text ..
                  '","leds":' .. leds ..
                  ',"total":' .. self.led_count ..
                  ',"started":' .. (self.started ? "true" : "false") ..
                  ',"finished":' .. (self.finished ? "true" : "false") .. '}'
        if msg == self.last_progress
            return
        end
        self.last_progress = msg
        mqtt.publish(SAW_STATUS_TOPIC, msg, true)
    end

    def force_complete()
        self.started = true
        self.finished = true
        self.counter = (self.led_count - 1) * self.count_per_led
        for i: 0..(self.led_count - 1)
            self.strip.set_pixel_color(i, self.green_color, 255)
        end
        self.strip.show()
        tasmota.set_power(OUT1, false)
        self.stop_sound()
        self.publish_progress()
        tasmota.resp_cmnd("SawBox force completed")
    end

    def publish_sound_state(state)
        if self.last_sound_state == state
            return
        end

        self.last_sound_state = state

        mqtt.publish(
            SAW_SOUND_TOPIC,
            '{"data":"' .. state .. '"}'
        )
    end

    def reset_game(response_text)
        self.counter = 0
        self.saw_in = false
        self.started = false
        self.finished = false

        self.sound_started = false
        self.sound_loud = false
        self.sound_start = 0
        self.last_sound_state = ""

        self.last_pin_state = gpio.digital_read(SAW_PIN)
        self.last_move_time = 0

        tasmota.cmd("i2sstop")
        tasmota.cmd("i2sgain 0")

        self.publish_sound_state("STOP")

        self.strip.clear()
        self.strip.show()

        self.last_progress = ""
        self.publish_progress()

        tasmota.resp_cmnd(response_text)
    end

    def init_game()
        self.reset_game("Initialized")
    end

    def disable_game()
        self.reset_game("SawBox disabled and fully reset")
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

        self.sound_started = false
        self.sound_loud = false
        self.sound_start = 0
        self.last_sound_state = ""

        self.last_pin_state = gpio.digital_read(SAW_PIN)
        self.last_move_time = 0

        tasmota.cmd("i2sstop")
        tasmota.cmd("i2sgain 0")

        self.publish_sound_state("STOP")

        self.strip.clear()
        self.strip.show()
        self.draw_leds()

        self.last_progress = ""
        self.publish_progress()

        tasmota.resp_cmnd("First LED turned on")
    end

    def start_saw_sound()
        self.sound_started = true
        self.sound_start = tasmota.millis()

        tasmota.cmd("i2sgain " .. str(SAW_GAIN))
        tasmota.cmd("i2splay mp3/saw.mp3")
    end

    def set_sound_loud()
        var now = tasmota.millis()

        if !self.sound_started ||
           now - self.sound_start >= SAW_RESTART_MS

            self.start_saw_sound()
        end

        if !self.sound_loud
            self.sound_loud = true
            tasmota.cmd("i2sgain " .. str(SAW_GAIN))
            self.publish_sound_state("LOUD")
        end
    end

    def set_sound_quiet()
        if self.sound_loud
            self.sound_loud = false
            tasmota.cmd("i2sgain 0")
            self.publish_sound_state("QUIET")
        end
    end

    def stop_sound()
        self.sound_started = false
        self.sound_loud = false
        self.sound_start = 0
        self.last_move_time = 0

        tasmota.cmd("i2sstop")
        tasmota.cmd("i2sgain 0")

        self.publish_sound_state("STOP")
    end

    def fast_loop()
        if !self.started || self.finished
            return
        end

        var state = gpio.digital_read(SAW_PIN)
        var now = tasmota.millis()

        if state != self.last_pin_state
            self.last_pin_state = state
            self.last_move_time = now

            self.set_sound_loud()

            if state == 0
                self.counter += 1
            end
        end
    end

    def rgb(r, g, b)
        return (r << 16) | (g << 8) | b
    end

    def draw_leds()
        var completed_leds = self.completed_leds()

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
        self.publish_progress()

        if !self.started || self.finished
            return
        end

        var now = tasmota.millis()

        if self.sound_loud &&
           self.last_move_time > 0 &&
           now - self.last_move_time >= SAWING_TIMEOUT_MS

            self.set_sound_quiet()
        end

        if self.sound_loud &&
           self.sound_started &&
           now - self.sound_start >= SAW_RESTART_MS

            self.start_saw_sound()
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
            self.stop_sound()
            self.publish_progress()

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

tasmota.add_cmd(
    "disable",
    / -> saw_box_driver.disable_game()
)

tasmota.add_cmd(
    "forcecomplete",
    / -> saw_box_driver.force_complete()
)

print("SawBox driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("init - Initialize the game")
print("startled - Turn on the first LED and start counting")
print("disable - stop sound, clear leds and reset progress")
print("forcecomplete - set 30/30 green and stop")
print("--------------------------------------------------------------")
