#tasmota.cmd("SetOption")

#led mux

var PIN_MUX_ADDR_0 = 
var PIN_MUX_ADDR_1 = 
var PIN_MUX_ADDR_2 = 
var PIN_MUX_ADDR_3 = 
var PIN_MUX_COM = 

var topic = tasmota.cmd("Topic")["Topic"]

var mux = Multiplexer()

var character_maps = {
    "ANIMALWHEEL": ["_", "Animal1", "Animal2", "Animal3", "Animal4", "Animal5", "Stop", "#", "#", "#", "#", "#", "#", "#", "#", "#"],
}

mux.set_address_pins(PIN_MUX_ADDR_0,PIN_MUX_ADDR_1,PIN_MUX_ADDR_2,PIN_MUX_ADDR_3)
mux.set_common_analog_input_pin(PIN_MUX_COM)
mux.set_topic(topic)
mux.set_character_map(character_maps[topic])
mux.set_tolerance(15)
tasmota.add_driver(mux)