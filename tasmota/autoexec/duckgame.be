# gpio_rx:16 gpio_tx:17
var ser = serial(16, 17, 9600, serial.SERIAL_8E1)

var LDR1 = 32
var LDR2 = 33
var LDR3 = 25
var LDR4 = 26

def duck_command(cmd, idx, payload, payload_json)
    payload += "\n"
    ser.write(bytes().fromstring(payload))
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('duck', /cmd, idx, payload, payload_json->duck_command(cmd, idx, payload, payload_json))

class DuckGameDriver
    def every_100ms()
        if !gpio.digital_read(LDR1)
            ser.write(bytes().fromstring("shoot1\n"))
        elif !gpio.digital_read(LDR2)
            ser.write(bytes().fromstring("shoot2\n"))
        elif !gpio.digital_read(LDR3)
            ser.write(bytes().fromstring("shoot3\n"))
        elif !gpio.digital_read(LDR4)
            ser.write(bytes().fromstring("shoot4\n"))
        end
    end
end
  
d1 = DuckGameDriver()

tasmota.add_driver(d1)

print ("DuckGame driver loaded")