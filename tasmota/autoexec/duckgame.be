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

    def homeall(cmd, idx)
        ser.write(bytes().fromstring("homeall\n"))
        tasmota.resp_cmnd("homing all")
    end

    def move(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " move\n"))
        tasmota.resp_cmnd("duck" .. idx .. " moving")
    end

    def moveall(cmd, idx)
        ser.write(bytes().fromstring("moveall\n"))
        tasmota.resp_cmnd("moving all")
    end

    def stop(cmd, idx)
        ser.write(bytes().fromstring("duck" .. idx .. " stop\n"))
        tasmota.resp_cmnd("duck" .. idx .. " stopped")
    end

    def stopall(cmd, idx)
        ser.write(bytes().fromstring("stopall\n"))
        tasmota.resp_cmnd("all stopped")
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
tasmota.add_cmd("homeall", /cmd, idx-> duckgamedriver.homeall(cmd, idx))
tasmota.add_cmd("move", /cmd, idx-> duckgamedriver.move(cmd, idx))
tasmota.add_cmd("moveall", /cmd, idx-> duckgamedriver.moveall(cmd, idx))
tasmota.add_cmd("stop", /cmd, idx-> duckgamedriver.stop(cmd, idx))
tasmota.add_cmd("stopall", /cmd, idx-> duckgamedriver.stopall(cmd, idx))
tasmota.add_cmd("duckrestart", /cmd, idx-> duckgamedriver.restart(cmd, idx))
tasmota.add_cmd("speed", /cmd, idx, speed-> duckgamedriver.setspeed(cmd, idx, speed))

print("DuckGame driver loaded")
print("Command example: home1 - duck1 start homing")
print("home - start homing")
print("homeall - start homing for all ducks")
print("move - start moving up and down")
print("moveall - start moving all ducks up and down")
print("stop - stop moving")
print("stopall - stop all ducks")
print("duckrestart - restart the ESP32-C3 SuperMini")
print("speed - set the speed of moving up and down (1–10)")
