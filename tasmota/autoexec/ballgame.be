import string
import mqtt

var uid_list1 = ["041EF240BE2A81","042ED240BE2A81","042F7640BE2A81","04481141BE2A81","04559440BE2A81","045ACB40BE2A81","0466E440BE2A81","0467A340BE2A81","04699A40BE2A81","0471F740BE2A81","047B7B40BE2A81","0495BC40BE2A81","0496B640BE2A81","04ACAD40BE2A81","04ADD940BE2A81","04B25941BE2A81","04B7C240BE2A81","04D68240BE2A81","04EA8840BE2A81","04F2E940BE2A81"]
var uid_list2 = ["04114B40BE2A81","04155640BE2A81","042ADB4FBD2A81","0433EC4FBD2A81","043A3540BE2A81","04434540BE2A81","0449F84FBD2A81","046B2240BE2A81","04741C40BE2A81","0499F34FBD2A81","04ACAE40BE2A81","04AE2740BE2A81","04B73C40BE2A81","04C12E40BE2A81","04CF6440BE2A81","04D81340BE2A81","04DCD34FBD2A81","04EF5B40BE2A81","04F2E940BE2A81","04F4CF4FBD2A81","04FBE24FBD2A81","04FEE74FBD2A81"]
var uid_list3 = ["0413E84FBD2A81","04153840BE2A81","04175341BE2A81","0427DE4FBD2A81","0429DE4FBD2A81","0446D14FBD2A81","044DD44FBD2A81","044F2940BE2A81","0454EB4FBD2A81","04661C40BE2A81","0465EE4FBD2A81","046ACD4FBD2A81","0479F94FBD2A81","047DDA4FBD2A81","04811BAE7E2681","04972FAE7E2681","04A822AE7E2681","049B2FAE7E2681","04BC1240BE2A81","04C128AE7E2681"]
var uid_list4 = ["0419CD40BE2A81","04243241BE2A81","043EC740BE2A81","04442941BE2A81","0449D44FBD2A81","044CD14FBD2A81","046A1241BE2A81","047EA940BE2A81","049CEB40BE2A81","04A11D41BE2A81","04A52441BE2A81","04ABDD40BE2A81","04B5B440BE2A81","04B5FC40BE2A81","04B6BA40BE2A81","04CE5E41BE2A81","04DE1841BE2A81","04E8D740BE2A81","04F2F540BE2A81","04C3C240BE2A81","04493741BE2A81"]
var uid_list5 = ["04146F40BE2A81","041B4F40BE2A81","041F7640BE2A81","042C16AE7E2681","043E4540BE2A81","04471CAE7E2681","044B9440BE2A81","04629A40BE2A81","046EA340BE2A81","04813E40BE2A81","04821BAE7E2681","04AC36AE7E2681","04D42EAE7E2681","04D55D40BE2A81","04D96440BE2A81","04DD8240BE2A81","045DFEAD7E2681","04747B40BE2A81","047723AE7E2681","04CB28AE7E2681","04F48840BE2A81","04F65540BE2A81"]
var uid_list6 = ["041343AE7E2681","0418FFAD7E2681","043316AE7E2681","0438F9AD7E2681","046C15AE7E2681","047123AE7E2681","04811BAE7E2681","048D1BAE7E2681","048F29AE7E2681","04972FAE7E2681","049B2FAE7E2681","04A822AE7E2681","04AA22AE7E2681","04B93CAE7E2681","04C128AE7E2681","04C143AE7E2681","04C643AE7E2681","04D22EAE7E2681","04DF35AE7E2681","04E435AE7E2681","04E93BAE7E2681","04F73BAE7E2681","04FD48AE7E2681","04FE42AE7E2681"]

var all_lists = [uid_list1, uid_list2, uid_list3, uid_list4, uid_list5, uid_list6]
var TIMEOUT = 2000

class BallGame
    var topic
    var last_time
    var timeout_sent

    def extract_uid(payload_str)
        var key = '"UID":"'
        var pos = string.find(payload_str, key)
        if pos == -1
            return nil
        end
        var start = pos + string.size(key)
        var uid_str = payload_str[start..(string.size(payload_str) - 1)]
        var endpos = string.find(uid_str, '"')
        if endpos == -1
            return nil
        end
        return uid_str[0..(endpos - 1)]
    end

    def on_mqtt_message(topic_str, payload)
        var payload_str = str(payload)
        var uid = self.extract_uid(payload_str)
        if uid == nil
            return nil
        end
        self.last_time = tasmota.millis()
        self.timeout_sent = false
        var out = "NOT FOUND"
        var idx = 1
        for list : all_lists
            if list.find(uid) != nil
                out = str(idx)
                break
            end
            idx = idx + 1
        end
        mqtt.publish(self.topic .. "/BALL", out)
    end

    def every_second()
        if (tasmota.millis() - self.last_time) > TIMEOUT && !self.timeout_sent
            mqtt.publish(self.topic .. "/BALL", "-")
            self.timeout_sent = true
        end
    end

    def init()
        self.topic = tasmota.cmd("Topic")["Topic"]
        self.last_time = tasmota.millis()
        self.timeout_sent = true
        mqtt.subscribe("tele/" .. self.topic .. "/SENSOR", /t, idx, data, b -> self.on_mqtt_message(t, data))
    end
end

tasmota.add_driver(BallGame())
print("BallGame driver loaded")