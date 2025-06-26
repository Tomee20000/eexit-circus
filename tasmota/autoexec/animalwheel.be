#tasmota.cmd("SetOption")

#led mux

var PIN_MUX_ADDR_0 = 15
var PIN_MUX_ADDR_1 = 14
var PIN_MUX_ADDR_2 = 12
var PIN_MUX_ADDR_3 = 13
var PIN_MUX_COM = 33

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