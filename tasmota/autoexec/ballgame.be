
import mqtt
import gpio

var SWITCH_PIN = 7

var RED_LED = 0
var GREEN_LED = 1

var PN532_RX = 3
var PN532_TX = 4
var PN532_BAUD = 115200

var NO_CARD_TIMEOUT = 1000
var PN532_RESPONSE_TIMEOUT = 300
var BLINK_INTERVAL = 250
var BALL_READ_TIMEOUT = 2000
var UID_SENSOR_RESET_MS = 1000

var uid_list1 = [
    '5372060D140001', '531F560F140001', '53B94D0F140001', '5318480F140001', '53633F0F140001', '5327450F140001', '53BF4D0F140001', '5357530F140001', '53BC5B0F140001', '535C610F140001', '53B5690F140001', '53336F0F140001', '5368770F140001', '53AC7C0F140001', '5351840F140001', '5350890F140001', '53BC900F140001', '5375950F140001', '533A9C0F140001', '539AA00F140001', '53389C0F140001', '53B2970F140001', '53C0900F140001', '53ED8B0F140001', '5345840F140001', '532D7F0F140001', '536C770F140001', '530D720F140001', '53A9690F140001',
    '53D8B206140001', '53F4B706140001', '53C8C006140001', '539FC506140001', '5359CB06140001', '53DBCF06140001', '531BD706140001', '53BCD906140001', '533ADE06140001', '53FBE106140001', '53AAE806140001', '53EAEB06140001', '5302EF06140001', '53ECEB06140001', '5393E506140001', '53FFE106140001', '539EDD06140001', '53C8D906140001', '5342D406140001', '53F7CE06140001', '535BCA06140001', '53DDC106140001', '53F8BC06140001', '53BEB606140001', '5394B106140001', '534AA806140001', '53DBA206140001', '53DF7006140001'
]

var uid_list2 = [
    "532346FF130001","533C3CFF130001","533F35FF130001","53292AFF130001","534723FF130001","539C19FF130001","53CB12FF130001","53F907FF130001","534001FF130001","53E7F7FE130001","53DAF2FE130001","5317EAFE130001","53A1E3FE130001","53C9DAFE130001","5387D4FE130001","53AECAFE130001","53DEC4FE130001","53B8BCFE130001","530FB7FE130001","5316AEFE130001","5372A8FE130001","538CA0FE130001","53FE9AFE130001","530892FE130001","53A18CFE130001","535785FE130001","538380FE130001","535C7AFE130001",
    '537B75FE130001', '53116FFE130001', '53816AFE130001', '533C63FE130001', '530C5FFE130001', '53A759FE130001', '53DA55FE130001', '53C34FFE130001', '53644CFE130001', '536048FE130001', '539445FE130001', '532741FE130001', '531A3FFE130001', '532941FE130001', '539543FE130001', '5338F70C140001', '532CF30C140001', '5325F00C140001', '5304EB0C140001', '53C2EA0C140001', '5358ED0C140001', '53ACF00C140001', '53D0F30C140001', '53F3F90C140001', '539EFD0C140001', '5363020D140001', '536E060D140001', '53A60A0D140001', '5341120D140001'
]

var uid_list3 = [
    "53CF160D140001","53EB1C0D140001","53CE210D140001","53801B0D140001","53D3160D140001","53030F0D140001","53A80A0D140001","5363010D140001","53A0FD0C140001","532BF70C140001","53D6F30C140001","5328F00C140001","535AED0C140001","53C8EA0C140001","5356ED0C140001","53A2F00C140001","53CAF30C140001","53F9F90C140001","539CFD0C140001","5365020D140001","536C060D140001","53A40A0D140001","5343120D140001","53CD160D140001","53ED1C0D140001","53C4210D140001","537E1B0D140001","53D9160D140001",
    '53010F0D140001', '539E0A0D140001', '5368060D140001', '536D010D140001', '53A2FD0C140001', '5329F70C140001', '53CCF30C140001', '535A610F140001', '53B7690F140001', '53316F0F140001', '536A770F140001', '53AA7C0F140001', '5353840F140001', '534E890F140001', '53BE900F140001', '5373950F140001', '533C9C0F140001', '5398A00F140001', '53369C0F140001', '53B4970F140001', '53BA900F140001', '53E38B0F140001', '534F840F140001', '53337F0F140001', '5366770F140001', '5303720F140001', '53B3690F140001', '531F640F140001', '53BA5B0F140001'
]

var uid_list4 = [
    "53F6DC00140001","530EE400140001","53E1E800140001","5363F000140001","53E9F400140001","534BF900140001","5354FD00140001","53DA0001140001","539F0A01140001","534C1901140001","53A81701140001","53280F01140001","533E1201140001","53DF1601140001","53151501140001","53331101140001","53010E01140001","53660801140001","53B90401140001","534BFF00140001","5352FC00140001","5348F900140001","5335F200140001","53A1ED00140001","53EBE600140001","53FEE100140001","53FCD900140001","53DAD400140001","534CCD00140001",
    "53947303140001","533D6D03140001","53BE6303140001","53405D03140001","53245303140001","53844C03140001","539B4203140001","53DC3B03140001","53153503140001","53A52A03140001","53BE2303140001","537E1903140001","538B1203140001","53E70703140001","53DF0003140001","5316F902140001","530BF602140001","5312F602140001","5319F602140001","5320F602140001","5379F202140001","53F7E702140001","531EDD02140001","53FDD502140001","535ECB02140001","5333C402140001","5340B902140001","530CB202140001","5361A702140001"
]

var uid_list5 = [
    '53FE380D140001', '53D4320D140001', '53992D0D140001', '53982D0D140001', '53D5320D140001', '53FD380D140001', '53813E0D140001', '53CF480D140001', '53694E0D140001', '5307550D140001', '53B75A0D140001', '535B600D140001', '53B76A0D140001', '537A700D140001', '53BB770D140001', '53ED7D0D140001', '5359890D140001', '53C38F0D140001', '533D960D140001', '53BF8F0D140001', '533A840D140001', '5303A503140001', '53AF9C03140001', '530A9703140001', '538A8E03140001', '53D48803140001', '539A8103140001', '53317D03140001',
    '533A2E0D140001', '5304290D140001', '53382E0D140001', '5338380D140001', '53B63D0D140001', '5310440D140001', '53AF490D140001', '5313540D140001', '53AC590D140001', '534B5F0D140001', '5313660D140001', '53CA6B0D140001', '5392760D140001', '53C37C0D140001', '5333840D140001', '53C68F0D140001', '533A960D140001', '53C28F0D140001', '535A890D140001', '53EC7D0D140001', '53BC770D140001', '5385700D140001', '53BC6A0D140001', '535A600D140001', '53AC5A0D140001', '5308550D140001', '53684E0D140001', '53D0480D140001', '53803E0D140001'
]

var uid_list6 = [
    '532CA002140001', '53319502140001', '53FB8D02140001', '53508302140001', '531D7C02140001', '53297102140001', '53E57402140001', '538F7F02140001', '53C58602140001', '53C09102140001', '53F39802140001', '539FA302140001', '53D5AA02140001', '53CEB502140001', '53EE4606140001', '53804D06140001', '538A5806140001', '53C76006140001', '53056706140001', '53CE6F06140001', '53487406140001', '53BD7B06140001', '535E8106140001', '53048B06140001', '539F9006140001', '53C49706140001', '53589D06140001', '53E8A606140001', '534BAC06140001',
    '530B0701140001', '53E1C700140001', '531ABF00140001', '5388B900140001', '53E6B300140001', '53FFAB00140001', '5369A600140001', '534F9D00140001', '53939700140001', '53A29100140001', '53108C00140001', '53318200140001', '53CE7B00140001', '53847200140001', '53F26B00140001', '53986100140001', '53EF5A00140001', '533F5100140001', '53804A00140001', '53D33F00140001', '53FC3800140001', '535580FF130001', '537C7BFF130001', '53BD70FF130001', '539E69FF130001', '53895FFF130001', '537358FF130001', '532B4DFF130001'
]

var all_lists = [
    uid_list1,
    uid_list2,
    uid_list3,
    uid_list4,
    uid_list5,
    uid_list6
]

class BallGame

    var topic
    var switch_state

    var ser
    var rx_buffer
    var pn532_state
    var pn532_start_time

    var last_read_time
    var card_present
    var timeout_sent
    var current_ball
    var ball_published

    var uid_reported
    var uid_reset_since

    var read_window_active
    var read_window_start
    var read_window_sent

    var blink_active
    var blink_power
    var blink_step
    var blink_last_time
    var blink_max_step

    var last_status
    var enabled
    var sensor_bypass

    def build_status()
        var indicator = "off"

        if self.blink_active
            if self.blink_power == RED_LED
                indicator = "red"
            else
                indicator = "green"
            end
        end

        var switch_on = self.switch_state == 0

        return '{"tube":"' .. self.topic ..
               '","enabled":' .. (self.enabled ? "true" : "false") ..
               ',"sensor_bypass":' .. (self.sensor_bypass ? "true" : "false") ..
               ',"ball":"' .. self.current_ball ..
               '","present":' .. (self.card_present ? "true" : "false") ..
               ',"switch":' .. (switch_on ? "true" : "false") ..
               ',"indicator":"' .. indicator ..
               '","blink_active":' .. (self.blink_active ? "true" : "false") ..
               ',"blink_step":' .. self.blink_step ..
               ',"blink_total":' .. self.blink_max_step .. '}'
    end

    def publish_status()
        var msg = self.build_status()

        if msg == self.last_status
            return
        end

        self.last_status = msg
        mqtt.publish(self.topic .. "/STATUS", msg, true)
    end

    def publish_sensor_bypass()
        mqtt.publish(self.topic .. "/SENSOR_BYPASS", self.sensor_bypass ? "ON" : "OFF", true)
    end

    def set_sensor_bypass(value)
        if value && !self.enabled
            self.publish_sensor_bypass()
            tasmota.resp_cmnd_error()
            return
        end

        self.sensor_bypass = value
        self.read_window_active = false
        self.read_window_sent = false
        self.publish_sensor_bypass()
        self.last_status = ""
        self.publish_status()

        print(value ? "Sensor bypass enabled" : "Sensor bypass disabled")
        tasmota.resp_cmnd_done()
    end

    def sensor_bypass_command(cmd, idx, payload)
        if payload == "1" || payload == "ON" || payload == "on"
            self.set_sensor_bypass(true)
        elif payload == "0" || payload == "OFF" || payload == "off"
            self.set_sensor_bypass(false)
        elif payload == ""
            tasmota.resp_cmnd_str(self.sensor_bypass ? "ON" : "OFF")
        else
            tasmota.resp_cmnd_error()
        end
    end

    def sync_mqtt()
        self.publish_sensor_bypass()
        self.last_status = ""
        self.publish_status()
    end

    def find_ball(uid)
        var out = "NOT FOUND"
        var idx = 1

        for list : all_lists
            if list.find(uid) != nil
                out = str(idx)
                break
            end

            idx = idx + 1
        end

        return out
    end

    def start_read_window()
        if !self.enabled
            return
        end

        if self.ball_published || self.sensor_bypass
            return
        end

        self.read_window_active = true
        self.read_window_start = tasmota.millis()
        self.read_window_sent = false

        print("Ball detected, NFC window started")
    end

    def check_read_window()
        if !self.read_window_active
            return
        end

        if tasmota.millis() - self.read_window_start >= BALL_READ_TIMEOUT
            self.read_window_active = false

            if !self.read_window_sent
                print("NFC window expired without valid ball")
            else
                print("NFC window closed")
            end
        end
    end

    def log_uid(uid)
        if self.switch_state != 0
            return
        end

        if self.uid_reported
            return
        end

        self.uid_reported = true
        print("UID: " .. uid)
    end

    def handle_uid_sensor(state)
        if state == 0
            self.uid_reset_since = 0
            return
        end

        if !self.uid_reported
            self.uid_reset_since = 0
            return
        end

        var now = tasmota.millis()

        if self.uid_reset_since == 0
            self.uid_reset_since = now
            return
        end

        if now - self.uid_reset_since >= UID_SENSOR_RESET_MS
            self.uid_reported = false
            self.uid_reset_since = 0
        end
    end

    def card_read(uid)
        self.log_uid(uid)

        if !self.enabled
            return
        end

        var now = tasmota.millis()

        if self.ball_published
            self.last_read_time = now
            self.card_present = true
            self.timeout_sent = false
            return
        end

        if !self.sensor_bypass && !self.read_window_active
            return
        end

        var ball = self.find_ball(uid)

        if ball == "NOT FOUND"
            return
        end

        self.last_read_time = now
        self.card_present = true
        self.timeout_sent = false

        if ball != self.current_ball
            self.current_ball = ball
            self.last_status = ""
        end

        if self.sensor_bypass ||
           (!self.read_window_sent && now - self.read_window_start < BALL_READ_TIMEOUT)

            mqtt.publish(self.topic .. "/BALL", ball, true)

            self.read_window_sent = true
            self.read_window_active = false
            self.ball_published = true

            print("Ball published: " .. ball)
            print("NFC identification stopped, presence monitoring active")
        end
    end

    def clear_ball()
        if self.ball_published
            mqtt.publish(self.topic .. "/BALL", "-", true)
        end

        self.current_ball = "-"
        self.ball_published = false
        self.last_status = ""
        self.card_present = false
        self.timeout_sent = true
    end

    def check_card_timeout()
        if self.card_present &&
           !self.timeout_sent &&
           tasmota.millis() - self.last_read_time >= NO_CARD_TIMEOUT

            self.clear_ball()
            print("NFC removed")
        end
    end

    def start_blink(power, opposite_power, max_step)
        if !self.enabled
            tasmota.resp_cmnd("BallGame disabled")
            return false
        end

        tasmota.set_power(opposite_power, false)
        tasmota.set_power(power, false)

        self.blink_power = power
        self.blink_step = 0
        self.blink_max_step = max_step
        self.blink_last_time = tasmota.millis()
        self.blink_active = true

        tasmota.set_power(power, true)
    end

    def redblink()
        self.start_blink(RED_LED, GREEN_LED, 5)
        tasmota.resp_cmnd_done()
    end

    def greenblink()
        self.start_blink(GREEN_LED, RED_LED, 5)
        tasmota.resp_cmnd_done()
    end

    def solveblink()
        self.start_blink(GREEN_LED, RED_LED, 1)
        tasmota.resp_cmnd_done()
    end

    def handle_blink()
        if !self.blink_active
            return
        end

        if tasmota.millis() - self.blink_last_time < BLINK_INTERVAL
            return
        end

        self.blink_last_time = tasmota.millis()
        self.blink_step = self.blink_step + 1

        if self.blink_step == 1
            tasmota.set_power(self.blink_power, false)

        elif self.blink_step == 2
            tasmota.set_power(self.blink_power, true)

        elif self.blink_step == 3
            tasmota.set_power(self.blink_power, false)

        elif self.blink_step == 4
            tasmota.set_power(self.blink_power, true)

        elif self.blink_step == 5
            tasmota.set_power(self.blink_power, false)
        end

        if self.blink_step >= self.blink_max_step
            tasmota.set_power(self.blink_power, false)
            self.blink_active = false
        end
    end

    def reset_state(enabled_state)
        self.enabled = enabled_state
        self.sensor_bypass = false

        self.blink_active = false
        self.blink_power = RED_LED
        self.blink_step = 0
        self.blink_max_step = 5
        self.blink_last_time = tasmota.millis()

        tasmota.set_power(RED_LED, false)
        tasmota.set_power(GREEN_LED, false)

        self.current_ball = "-"
        self.ball_published = false
        self.card_present = false
        self.timeout_sent = true
        self.last_read_time = tasmota.millis()

        self.read_window_active = false
        self.read_window_start = 0
        self.read_window_sent = false

        mqtt.publish(self.topic .. "/BALL", "-", true)
        self.publish_sensor_bypass()

        self.switch_state = gpio.digital_read(SWITCH_PIN)
        self.publish_switch(self.switch_state)

        self.last_status = ""
        self.publish_status()
    end

    def enable_game()
        self.reset_state(true)
        tasmota.resp_cmnd("BallGame enabled and reset")
    end

    def disable_game()
        self.reset_state(false)
        tasmota.resp_cmnd("BallGame disabled and reset")
    end

    def publish_switch(state)
        var time_data = tasmota.cmd("Time")
        var current_time = time_data["Time"]
        var switch_value

        if state == 0
            switch_value = "ON"
        else
            switch_value = "OFF"
        end

        var payload = '{"Time":"' .. current_time ..
                      '","Switch1":"' .. switch_value .. '"}'

        mqtt.publish(
            "tele/" .. self.topic .. "/SENSOR",
            payload
        )
    end

    def clear_pn532_buffer()
        self.rx_buffer = []
    end

    def send_sam_config()
        self.clear_pn532_buffer()

        self.ser.write(
            bytes("0000FF05FBD4140114010200")
        )

        self.pn532_state = 1
        self.pn532_start_time = tasmota.millis()

        print("PN532 SAM configuration sent")
    end

    def send_rf_config()
        self.clear_pn532_buffer()

        self.ser.write(
            bytes("0000FF06FAD43205FF0100F500")
        )

        self.pn532_state = 3
        self.pn532_start_time = tasmota.millis()
    end

    def request_card()
        self.clear_pn532_buffer()

        self.ser.write(
            bytes("0000FF04FCD44A0100E100")
        )

        self.pn532_state = 2
        self.pn532_start_time = tasmota.millis()
    end

    def read_serial()
        var count = self.ser.available()

        if count <= 0
            return
        end

        var data = self.ser.read(count)

        if data == nil
            return
        end

        var i = 0

        while i < size(data)
            self.rx_buffer.push(data[i])
            i = i + 1
        end
    end

    def find_response(command)
        var count = size(self.rx_buffer)

        if count < 2
            return -1
        end

        var i = 0

        while i < count - 1
            if self.rx_buffer[i] == 0xD5 &&
               self.rx_buffer[i + 1] == command

                return i
            end

            i = i + 1
        end

        return -1
    end

    def parse_sam_response()
        var pos = self.find_response(0x15)

        if pos == -1
            return false
        end

        print("PN532 initialized")
        self.send_rf_config()

        return true
    end

    def parse_rf_config_response()
        if self.find_response(0x33) == -1
            return false
        end

        self.request_card()
        return true
    end

    def parse_card_response()
        var pos = self.find_response(0x4B)

        if pos == -1
            return false
        end

        if size(self.rx_buffer) <= pos + 2
            return false
        end

        var target_count = self.rx_buffer[pos + 2]

        if target_count == 0
            self.request_card()
            return true
        end

        if size(self.rx_buffer) <= pos + 7
            return false
        end

        var uid_length = self.rx_buffer[pos + 7]

        if size(self.rx_buffer) < pos + 8 + uid_length
            return false
        end

        var uid = ""
        var i = 0

        while i < uid_length
            uid = uid .. format(
                "%02X",
                self.rx_buffer[pos + 8 + i]
            )

            i = i + 1
        end

        self.card_read(uid)
        self.request_card()

        return true
    end

    def handle_pn532()
        self.read_serial()

        if self.pn532_state == 0

            if tasmota.millis() - self.pn532_start_time >= 200
                self.send_sam_config()
            end

        elif self.pn532_state == 1

            if !self.parse_sam_response()
                if tasmota.millis() - self.pn532_start_time > 1000
                    print("PN532 initialization retry")
                    self.send_sam_config()
                end
            end

        elif self.pn532_state == 2

            if !self.parse_card_response()
                if tasmota.millis() - self.pn532_start_time >
                   PN532_RESPONSE_TIMEOUT

                    self.request_card()
                end
            end

        elif self.pn532_state == 3

            if !self.parse_rf_config_response()
                if tasmota.millis() - self.pn532_start_time > 1000
                    print("PN532 RF configuration retry")
                    self.send_rf_config()
                end
            end
        end
    end

    def fast_loop()
        var state = gpio.digital_read(SWITCH_PIN)

        self.handle_uid_sensor(state)

        if state != self.switch_state
            self.switch_state = state

            self.publish_switch(state)

            if state == 0
                self.start_read_window()
            end
        end

        self.check_read_window()
        self.handle_pn532()
        self.check_card_timeout()
        self.handle_blink()
        self.publish_status()
    end

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]

        self.switch_state = gpio.digital_read(SWITCH_PIN)
        self.enabled = true
        self.sensor_bypass = false

        self.blink_active = false
        self.blink_power = RED_LED
        self.blink_step = 0
        self.blink_max_step = 5
        self.blink_last_time = tasmota.millis()

        tasmota.set_power(RED_LED, false)
        tasmota.set_power(GREEN_LED, false)

        self.rx_buffer = []
        self.pn532_state = 0
        self.pn532_start_time = tasmota.millis()

        self.last_read_time = tasmota.millis()
        self.card_present = false
        self.timeout_sent = true
        self.current_ball = "-"
        self.ball_published = false

        self.uid_reported = false
        self.uid_reset_since = 0

        self.read_window_active = false
        self.read_window_start = 0
        self.read_window_sent = false

        self.ser = serial(
            PN532_RX,
            PN532_TX,
            PN532_BAUD
        )

        self.ser.flush()

        self.ser.write(
            bytes("55550000000000000000000000000000")
        )

        mqtt.publish(self.topic .. "/BALL", "-", true)
        self.publish_sensor_bypass()

        self.publish_switch(self.switch_state)

        self.last_status = ""
        self.publish_status()

        tasmota.add_fast_loop(
            / -> self.fast_loop()
        )
    end
end

var ball_game_driver = BallGame()

tasmota.add_rule(
    "Mqtt#Connected",
    / -> ball_game_driver.sync_mqtt(),
    "ballgame_bypass_sync"
)

tasmota.add_cmd(
    "sensorbypass",
    / cmd, idx, payload -> ball_game_driver.sensor_bypass_command(cmd, idx, payload)
)

tasmota.add_cmd(
    "sensoroff",
    / -> ball_game_driver.set_sensor_bypass(true)
)

tasmota.add_cmd(
    "sensoron",
    / -> ball_game_driver.set_sensor_bypass(false)
)

tasmota.add_cmd(
    "enable",
    / -> ball_game_driver.enable_game()
)

tasmota.add_cmd(
    "disable",
    / -> ball_game_driver.disable_game()
)

tasmota.add_cmd(
    "redblink",
    / -> ball_game_driver.redblink()
)

tasmota.add_cmd(
    "greenblink",
    / -> ball_game_driver.greenblink()
)

tasmota.add_cmd(
    "solveblink",
    / -> ball_game_driver.solveblink()
)

print("BallGame driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("enable - enable and reset this tube")
print("disable - disable, clear ball and LEDs")
print("sensorbypass 1/0 - enable/disable sensor bypass")
print("sensoroff - read balls without the proximity sensor")
print("sensoron - require proximity sensor to read balls")
print("redblink - red led blink 3 times")
print("greenblink - green led blink 3 times")
print("solveblink - green led blink 1 time")
print("--------------------------------------------------------------")
