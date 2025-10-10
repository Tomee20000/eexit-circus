var pos1 = 100
var pos2 = 100
var pos3 = 100
var pos4 = 100
var started = false
var down1 = false
var down2 = false
var down3 = false
var down4 = false
var secondcounter = 0

var up_position = 60
var down_position = 100

def init()
    tasmota.cmd("ShutterPosition1 " .. down_position)
    tasmota.cmd("ShutterPosition2 " .. down_position)
    tasmota.cmd("ShutterPosition3 " .. down_position)
    tasmota.cmd("ShutterPosition4 " .. down_position)
    pos1 = down_position
    pos2 = down_position
    pos3 = down_position
    pos4 = down_position
    tasmota.resp_cmnd("Game initialized")
end

def switch_1()
    if pos1 == down_position
        tasmota.cmd("ShutterPosition1 " .. up_position)
        pos1 = up_position
    else
        tasmota.cmd("ShutterPosition1 " .. down_position)
        pos1 = down_position
    end
    tasmota.resp_cmnd("Switch1")
end

def switch_2()
    if pos2 == down_position
        tasmota.cmd("ShutterPosition2 " .. up_position)
        pos2 = up_position
    else
        tasmota.cmd("ShutterPosition2 " .. down_position)
        pos2 = down_position
    end
    tasmota.resp_cmnd("Switch2")
end

def switch_3()
    if pos3 == down_position
        tasmota.cmd("ShutterPosition3 " .. up_position)
        pos3 = up_position
    else
        tasmota.cmd("ShutterPosition3 " .. down_position)
        pos3 = down_position
    end
    tasmota.resp_cmnd("Switch3")
end

def switch_4()
    if pos4 == down_position
        tasmota.cmd("ShutterPosition4 " .. up_position)
        pos4 = up_position
    else
        tasmota.cmd("ShutterPosition4 " .. down_position)
        pos4 = down_position
    end
    tasmota.resp_cmnd("Switch4")
end

class DuckGameAnimation
    def every_250ms()
        secondcounter += 1
        if started && secondcounter == 6
            switch_1()
            switch_2()
            switch_3()
            switch_4()
            secondcounter = 0;
        end
    end
end

d1 = DuckGameAnimation()
tasmota.add_driver(d1)

def start_game()
    started = true
    down1 = false
    down2 = false
    down3 = false
    down4 = false

    tasmota.resp_cmnd("Game started")
end

def stop_game()
    started = false
    secondcounter = 0;
    tasmota.resp_cmnd("Game stopped")
end

tasmota.add_cmd("DUCKSTART", start_game)
tasmota.add_cmd("DUCKSTOP", stop_game)
tasmota.add_cmd("DUCKINIT", init)
tasmota.add_cmd("SWITCH", switch_1)
tasmota.add_cmd("SWITCH", switch_2)
tasmota.add_cmd("SWITCH", switch_3)
tasmota.add_cmd("SWITCH", switch_4)
tasmota.cmd("ShutterCloseDuration1 1.5")
tasmota.cmd("ShutterOpenDuration1 1.5")
tasmota.cmd("ShutterCloseDuration2 1.5")
tasmota.cmd("ShutterOpenDuration2 1.5")
tasmota.cmd("ShutterCloseDuration3 1.5")
tasmota.cmd("ShutterOpenDuration3 1.5")
tasmota.cmd("ShutterCloseDuration4 1.5")
tasmota.cmd("ShutterOpenDuration4 1.5")



print ("DuckGame driver loaded")