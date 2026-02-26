# gpio_rx:16 gpio_tx:17
var ser = serial(16, 17, 9600, serial.SERIAL_8E1)

def duck_command(cmd, idx, payload, payload_json)
    payload += "\n"
    ser.write(bytes().fromstring(payload))
    tasmota.resp_cmnd_done()
end

tasmota.add_cmd('duck', /cmd, idx, payload, payload_json->duck_command(cmd, idx, payload, payload_json))

class DuckGameDriver
    def home(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " home\n"))
        tasmota.resp_cmnd("duck" .. idx .. " homing")
    end

    def move(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " move\n"))
        tasmota.resp_cmnd("duck" .. idx .. " moving")
    end

    def stop(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " stop\n"))
        tasmota.resp_cmnd("duck" .. idx .. " stopped")
    end

    def restart(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " restart\n"))
        tasmota.resp_cmnd("duck" .. idx .. " restarting")
    end

    def setspeed(cmd, idx, speed)
        if speed == "" || number(speed) > 10 || number(speed) < 1
            return
        end
        ser.write(bytes().fromstring("duck" .. idx .. " speed " .. speed .. "\n"))
        tasmota.resp_cmnd("duck" .. idx .. " speed set to " .. speed)
    end
end
  
var duckgamedriver = DuckGameDriver()

tasmota.add_driver(duckgamedriver)

tasmota.add_cmd("home", /cmd, idx-> duckgamedriver.home(cmd, idx))
tasmota.add_cmd("move", /cmd, idx-> duckgamedriver.move(cmd, idx))
tasmota.add_cmd("stop", /cmd, idx-> duckgamedriver.stop(cmd, idx))
tasmota.add_cmd("duckrestart", /cmd, idx-> duckgamedriver.restart(cmd, idx))
tasmota.add_cmd("speed", /cmd, idx, speed-> duckgamedriver.setspeed(cmd, idx, speed))

print ("DuckGame driver loaded")
print ("Command example: duck1 home - duck1 is unique id of the first duck")
print ("home - homing")
print ("move - starts moving up and down")
print ("stop - stops the moving")
print ("duckrestart - restarts the esp32-c3 supermini")
print ("speed - sets the speed of moving up and down 1-10")
