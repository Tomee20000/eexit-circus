import mqtt
import gpio

var SWITCH_PIN = 7

var PN532_RX = 3
var PN532_TX = 4
var PN532_BAUD = 115200

var NO_CARD_TIMEOUT = 1000
var PN532_RESPONSE_TIMEOUT = 300

var uid_list1 = ["04175341BE2A81","0446D14FBD2A81","0479F94FBD2A81","04DDE34FBD2A81","04BC1240BE2A81","04EF2340BE2A81","0454EB4FBD2A81","04C9F44FBD2A81","04153840BE2A81","0465EE4FBD2A81","04C15541BE2A81","0473EE4FBD2A81","04A53340BE2A81","0429DE4FBD2A81","044F2940BE2A81","044DD44FBD2A81","0427DE4FBD2A81","04661C40BE2A81","047DDA4FBD2A81","04E1E34FBD2A81","0413E84FBD2A81","046ACD4FBD2A81"]
var uid_list2 = ["04CF6440BE2A81","04114B40BE2A81","04434540BE2A81","04155640BE2A81","04EF5B40BE2A81","04B73C40BE2A81","046B2240BE2A81","04741C40BE2A81","0499F34FBD2A81","04C12E40BE2A81","046B2240BE0704","04D81340BE2A81","042BFE4FBD2A81","04FEE74FBD2A81","0449F84FBD2A81","04F4CF4FBD2A81","04AE2740BE2A81","0433EC4FBD2A81","0412D74FBD2A81","04DCD34FBD2A81","042ADB4FBD2A81","04FBE24FBD2A81","043A3540BE2A81"]
var uid_list3 = ["042F7640BE2A81","0471F740BE2A81","047B7B40BE2A81","04B25941BE2A81","04559440BE2A81","04D68240BE2A81","04EA8840BE2A81","0495BC40BE2A81","0496B640BE2A81","04699A40BE2A81","0467A340BE2A81","04ACAD40BE2A81","045ACB40BE2A81","04B7C240BE2A81","04ADD940BE2A81","0466E440BE2A81","042ED240BE2A81","041EF240BE2A81","04F2E940BE2A81","04481141BE2A81"]
var uid_list4 = ["04B5B440BE2A81","043EC740BE2A81","0419CD40BE2A81","04B6BA40BE2A81","04C3C240BE2A81","047EA940BE2A81","04CE5E41BE2A81","04F2F540BE2A81","0449D44FBD2A81","04DE1841BE2A81","046A1241BE2A81","04ABDD40BE2A81","04A11D41BE2A81","04A52441BE2A81","049CEB40BE2A81","04B5FC40BE2A81","044CD14FBD2A81","04E8D740BE2A81","04493741BE2A81","04442941BE2A81","04243241BE2A81","0464CD4FBD2A81"]
var uid_list5 = ["043316AE7E2681","04972FAE7E2681","04E435AE7E2681","04AA22AE7E2681","04C128AE7E2681","04B93CAE7E2681","04C643AE7E2681","04C143AE7E2681","04E93BAE7E2681","04811BAE7E2681","047123AE7E2681","04D22EAE7E2681","04DF35AE7E2681","0438F9AD7E2681","046C15AE7E2681","04A822AE7E2681","048D1BAE7E2681","0418FFAD7E2681","048F29AE7E2681","049B2FAE7E2681","04FD48AE7E2681","041343AE7E2681","04F73BAE7E2681","04FE42AE7E2681"]
var uid_list6 = ["04821BAE7E2681","04471CAE7E2681","042C16AE7E2681","045DFEAD7E2681","04AC36AE7E2681","047723AE7E2681","04D42EAE7E2681","04CB28AE7E2681","04629A40BE2A81","04DD8240BE2A81","041F7640BE2A81","04747B40BE2A81","04F48840BE2A81","044B9440BE2A81","046EA340BE2A81","04146F40BE2A81","041B4F40BE2A81","04F65540BE2A81","04D55D40BE2A81","04D96440BE2A81","043E4540BE2A81","04813E40BE2A81"]

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

    var last_uid
    var last_read_time
    var card_present
    var timeout_sent

    def process_uid(uid)
        var out = "NOT FOUND"
        var idx = 1

        for list : all_lists
            if list.find(uid) != nil
                out = str(idx)
                break
            end

            idx = idx + 1
        end

        print("UID: " .. uid .. " -> " .. out)
        mqtt.publish(self.topic .. "/BALL", out)
    end

    def card_read(uid)
        self.last_read_time = tasmota.millis()
        self.timeout_sent = false

        if !self.card_present || uid != self.last_uid
            self.card_present = true
            self.last_uid = uid
            self.process_uid(uid)
        end
    end

    def check_card_timeout()
        if self.card_present &&
           !self.timeout_sent &&
           tasmota.millis() - self.last_read_time >= NO_CARD_TIMEOUT

            self.card_present = false
            self.last_uid = ""
            self.timeout_sent = true

            mqtt.publish(self.topic .. "/BALL", "-")
            print("NFC removed")
        end
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
        end
    end

    def fast_loop()
        var state = gpio.digital_read(SWITCH_PIN)

        if state != self.switch_state
            self.switch_state = state
            self.publish_switch(state)
        end

        self.handle_pn532()
        self.check_card_timeout()
    end

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]
        self.switch_state = gpio.digital_read(SWITCH_PIN)

        self.rx_buffer = []
        self.pn532_state = 0
        self.pn532_start_time = tasmota.millis()

        self.last_uid = ""
        self.last_read_time = tasmota.millis()
        self.card_present = false
        self.timeout_sent = true

        self.ser = serial(
            PN532_RX,
            PN532_TX,
            PN532_BAUD
        )

        self.ser.flush()

        self.ser.write(
            bytes("55550000000000000000000000000000")
        )

        mqtt.publish(self.topic .. "/BALL", "-")

        tasmota.add_fast_loop(
            / -> self.fast_loop()
        )

        print("BallGame driver loaded")
    end
end

tasmota.add_driver(BallGame())