import math

var IN1 = 14
var IN2 = 13
var IN3 = 23
var IN4 = 22

var LALOCK = 0 #lock
var LAUNLOCK = 1 #unlock

var homing_steps = 25
var speed = 50

#absolute positions
var pos0 = 0
var pos1 = 1850
var pos2 = 3800
var pos3 = 5550
var pos4 = 7550

class CylinderDriver
    var actual_position, homing_state

    def init()
        self.actual_position = 0
        self.homing_state = 0
    end

    def lock(cmd,idx)
        tasmota.set_power(LAUNLOCK, false)
        tasmota.set_power(LALOCK, true)

        tasmota.set_timer(5000, / ->
            tasmota.set_power(LALOCK, false)
        )
        tasmota.resp_cmnd("Cylinder locked")
    end

    def unlock(cmd,idx) #blokkolni kell hogy teljes nyitásig ne mozogjon el
        tasmota.set_power(LALOCK, false)
        tasmota.set_power(LAUNLOCK, true)
        tasmota.delay(5000) 
        tasmota.set_power(LAUNLOCK, false)
        tasmota.resp_cmnd("Cylinder unlocked")
    end

    def home(cmd, idx)
        self.unlock()
        self.homing_state = 1
        tasmota.set_timer(10, / -> self._home_step())
    end

    def _home_step()
        if self.homing_state == 1
            # FAST SEEK
            if !gpio.digital_read(IN4)
                tasmota.cmd("motormove " .. (homing_steps * 10))
                tasmota.set_timer(200, / -> self._home_step())
                print("seeking...")
            else
                self.homing_state = 2
                tasmota.set_timer(100, / -> self._home_step())
                print("seeking over")
            end

        elif self.homing_state == 2
            # BACKOFF
            print("going back")
            tasmota.cmd("motormove -" .. (homing_steps * 20))
            self.homing_state = 3
            tasmota.set_timer(500, / -> self._home_step())

        elif self.homing_state == 3
            # SLOW APPROACH
            if !gpio.digital_read(IN4)
                tasmota.cmd("motormove " .. homing_steps)
                tasmota.set_timer(250, / -> self._home_step())
            else
                self.homing_state = 0
                self.actual_position = 0

                tasmota.set_timer(1000, / -> self.lock(nil, nil))
                tasmota.resp_cmnd("Homing done")
            end
        end
    end

    def set_pos(cmd, i, position)
        if position == 0
            self.unlock()
            tasmota.cmd("motorMove " .. (pos0 - self.actual_position));
            tasmota.set_timer(1000,/ -> self.lock(nil, nil))   
            self.actual_position = pos0
        elif position == 1
            self.unlock()
            tasmota.cmd("motorMove " .. (pos1 - self.actual_position));
            tasmota.set_timer(1000,/ -> self.lock(nil, nil))   
            self.actual_position = pos1
        elif position == 2
            self.unlock()
            tasmota.cmd("motorMove " .. (pos2 - self.actual_position));
            tasmota.set_timer(1000,/ -> self.lock(nil, nil))   
            self.actual_position = pos2

        elif position == 3
            self.unlock()
            tasmota.cmd("motorMove " .. (pos3 - self.actual_position));
            tasmota.set_timer(1000,/ -> self.lock(nil, nil))   
            self.actual_position = pos3

        elif position == 4
            self.unlock()
            tasmota.cmd("motorMove " .. (pos4 - self.actual_position));
            tasmota.set_timer(1000,/ -> self.lock(nil, nil))   
            self.actual_position = pos4
        else
            tasmota.resp_cmnd("Bad argument: " .. position)
            return
        end

        tasmota.resp_cmnd("Cylinder set to pos" .. position .. ", actual position:" .. self.actual_position)
    end
end
  
var cylinderdriver = CylinderDriver()

tasmota.add_driver(cylinderdriver)

tasmota.add_cmd("lock", /cmd, idx-> cylinderdriver.lock(cmd, idx))
tasmota.add_cmd("unlock", /cmd, idx-> cylinderdriver.unlock(cmd, idx))
tasmota.add_cmd("home", /cmd, idx-> cylinderdriver.home(cmd, idx))
tasmota.add_cmd("pos", /cmd, i, position -> cylinderdriver.set_pos(cmd, i, number(position)))

tasmota.cmd("MotorRPM " .. speed);

print("Cylinder driver loaded")
print("--------------------------------------------------------------")
print("Commands:")
print("lock - locks the cylinder in place")
print("unlock - unlocks the cylinder")
print("home - start homing")
print("pos <n> - goes to the given position")
print("--------------------------------------------------------------")