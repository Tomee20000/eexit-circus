def init()
    # gpio_rx:16 gpio_tx:17
    ser = serial(16, 17, 9600, serial.SERIAL_8E1)

    ser.write(bytes().fromstring("start\n"))   # send string "Hello"
    
    tasmota.resp_cmnd_done("Serial  initialized")
end

def init_game()
    ser.write(bytes().fromstring("init\n"))
    tasmota.resp_cmnd_done("Game initialized")
end

def restart()
    ser.write(bytes().fromstring("restart\n"))
    tasmota.resp_cmnd_done("Esp32 restarted")
end

def start_game()
    ser.write(bytes().fromstring("start\n"))
    tasmota.resp_cmnd_done("Game started")
end

def stop_game()
    ser.write(bytes().fromstring("stop\n"))
    tasmota.resp_cmnd_done("Game stopped")
end

def shoot1()
    ser.write(bytes().fromstring("shoot1\n"))
    tasmota.resp_cmnd_done("Duck 1 shot down")
end

def shoot2()
    ser.write(bytes().fromstring("shoot2\n"))
    tasmota.resp_cmnd_done("Duck 2 shot down")
end

def shoot3()
    ser.write(bytes().fromstring("shoot3\n"))
    tasmota.resp_cmnd_done("Duck 3 shot down")
end

def shoot4()
    ser.write(bytes().fromstring("shoot4\n"))
    tasmota.resp_cmnd_done("Duck 4 shot down")
end

tasmota.add_cmd("DUCKSTART", start_game)
tasmota.add_cmd("DUCKSTOP", stop_game)
tasmota.add_cmd("DUCKINIT", init_game)
tasmota.add_cmd("RESTART", restart)
tasmota.add_cmd("INIT", init)
tasmota.add_cmd("DUCKSHOOT1", shoot1)
tasmota.add_cmd("DUCKSHOOT2", shoot2)
tasmota.add_cmd("DUCKSHOOT3", shoot3)
tasmota.add_cmd("DUCKSHOOT4", shoot4)

init()
print ("DuckGame driver loaded")