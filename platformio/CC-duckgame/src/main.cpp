#include <string>
#include <Arduino.h>
#include "driver/gpio.h"
using namespace std;

// PIN definíciók
#define PIN_STEP 6
#define PIN_DIR 7
#define PIN_HOME 0
#define PIN_LASER 1
#define PIN_ONLINE_PING 10
#define PIN_TASMOTA_RX 20

// Sebességre optimalizált alap
#define DELAY_BASE 1

unsigned long lastOnlineToggle = 0;
const unsigned long ONLINE_INTERVAL = 10000;

// Mozgási paraméterek
long MOVE_STEPS = 800000;

// A lehető legnagyobb sebességre hangolva
int START_DELAY = 100;     // indulási késleltetés (fél periódus)
int MIN_DELAY = 2;        // végsebesség 
int ACCEL_STEPS = 8000;   // rövid, agresszív gyorsítás
int STEP_HIGH_US = 1;     // step HIGH pulse szélesség

string espID = string(ID);

int dir = 0;
bool onlineState = true;
bool moving = false;
string receivedMessage = "";
char incomingChar;

void performHoming();
void moveWithRamp(long steps);
void moveSimple(long steps, int delayUs = 20);
void readSerial();
void handleOnlinePing();
void(* resetFunc) (void) = 0;

HardwareSerial CommandSerial(1);

// Gyorsabb GPIO kezelés ESP32-n
inline void stepHigh() {
  gpio_set_level((gpio_num_t)PIN_STEP, 1);
}

inline void stepLow() {
  gpio_set_level((gpio_num_t)PIN_STEP, 0);
}

inline void dirWrite(int d) {
  gpio_set_level((gpio_num_t)PIN_DIR, d ? 1 : 0);
}

inline void onlineWrite(bool state) {
  gpio_set_level((gpio_num_t)PIN_ONLINE_PING, state ? 1 : 0);
}

inline void doStepFast(int delayMicros) {
  stepHigh();
  delayMicroseconds(STEP_HIGH_US);
  stepLow();
  if (delayMicros > 0) delayMicroseconds(delayMicros);
}

void setup() {
  CommandSerial.begin(9600, SERIAL_8N1, PIN_TASMOTA_RX, -1);
  Serial.begin(115200);
  delay(100);
  while (CommandSerial.available()) CommandSerial.read();

  lastOnlineToggle = millis();

  Serial.print("Stepper Ready. ID:");
  Serial.println(espID.c_str());
  Serial.println("Use 'home', 'move', 'stop', or 'speed 1-10'");

  pinMode(PIN_ONLINE_PING, OUTPUT);
  pinMode(PIN_STEP, OUTPUT);
  pinMode(PIN_DIR, OUTPUT);
  pinMode(PIN_HOME, INPUT_PULLUP);
  pinMode(PIN_LASER, INPUT_PULLUP);

  stepLow();
  dirWrite(dir);
  onlineWrite(LOW);

  performHoming();
}

void loop() {
  readSerial();

  if (moving) {
    dir = 0;
    dirWrite(dir);
    moveWithRamp(MOVE_STEPS);
    delay(50);

    dir = 1;
    dirWrite(dir);
    moveWithRamp(MOVE_STEPS);
    delay(50);
  }
}

void performHoming() {
  long stepCount = 0;

  if (!digitalRead(PIN_HOME)) {
    dir = 0;
    dirWrite(dir);
    moveSimple(3000, 10);
    delay(20);
  }

  dir = 1;
  dirWrite(dir);

  while (digitalRead(PIN_HOME)) {
    int delayMicros;

    if (stepCount < ACCEL_STEPS) {
      delayMicros = map(stepCount, 0, ACCEL_STEPS, START_DELAY, MIN_DELAY + 4);
    } else {
      delayMicros = MIN_DELAY + 4;
    }

    doStepFast(delayMicros);
    stepCount++;

    // Nem minden lépésnél olvasunk serialt, mert lassít
    if ((stepCount & 63) == 0) {
      readSerial();
    }
  }
}

void moveWithRamp(long steps) {
  long stepCount = 0;

  while (stepCount < steps && moving) {
    // Ezeket muszáj nézni minden lépésben
    if (!digitalRead(PIN_HOME) && dir == 1) {
      return;
    }

    if (!digitalRead(PIN_LASER)) {
      moving = false;
      delay(1000);
      performHoming();
      Serial.println("Duck shot down");
      return;
    }

    int delayMicros;

    // Csak gyorsítás, nincs lassítás: max sebességre optimalizálva
    if (stepCount < ACCEL_STEPS) {
      delayMicros = map(stepCount, 0, ACCEL_STEPS, START_DELAY, MIN_DELAY);
    } else {
      delayMicros = MIN_DELAY;
    }

    doStepFast(delayMicros);
    stepCount++;

    // Ritkábban ellenőrizzük a soros parancsokat
    if ((stepCount & 127) == 0) {
      readSerial();
    }
  }
}

void moveSimple(long steps, int delayUs) {
  for (long i = 0; i < steps; i++) {
    doStepFast(delayUs);
  }
}

void readSerial() {
  handleOnlinePing();

  while (CommandSerial.available()) {
    incomingChar = CommandSerial.read();

    if (incomingChar == '\n' && receivedMessage.find(espID) == 0) {
      if (receivedMessage == espID + " home") {
        Serial.println(">> Homing...");
        performHoming();
        Serial.println(">> Homing done");
      }
      else if (receivedMessage == espID + " move") {
        Serial.println(">> Start continuous motion");
        moving = true;
      }
      else if (receivedMessage == espID + " stop") {
        Serial.println(">> Stop motion");
        moving = false;
      }
      else if (receivedMessage.substr(0,11) == espID + " speed") {
        int speedVal = stoi(receivedMessage.substr(12,2));

        // Ugyanaz a parancs marad, de agresszívebb sebesség mappinggel
        switch (speedVal) {
          case 1:  MIN_DELAY = 20; break;
          case 2:  MIN_DELAY = 16; break;
          case 3:  MIN_DELAY = 12; break;
          case 4:  MIN_DELAY = 10; break;
          case 5:  MIN_DELAY = 8;  break;
          case 6:  MIN_DELAY = 6;  break;
          case 7:  MIN_DELAY = 5;  break;
          case 8:  MIN_DELAY = 4;  break;
          case 9:  MIN_DELAY = 3;  break;
          case 10: MIN_DELAY = 2;  break;
          default: MIN_DELAY = 2;  break;
        }

        Serial.print("Speed set to:");
        Serial.print(speedVal);
        Serial.print(" | Delay set to:");
        Serial.println(MIN_DELAY);
      }
      else if (receivedMessage == espID + " restart") {
        Serial.println("Restarting");
        resetFunc();
      }
      else {
        Serial.print("Unknown cmd: ");
        Serial.println(receivedMessage.c_str());
      }

      receivedMessage = "";
    }
    else if (incomingChar == '\n') {
      if (receivedMessage == "homeall") {
        Serial.println(">> Homing all...");
        performHoming();
        Serial.println(">> Homing done");
      }
      else if (receivedMessage == "moveall") {
        if (espID == "duck1" || espID == "duck3") {
          Serial.println(">> Start continuous motion");
          moving = true;
        }
        else {
          delay(5000);
          Serial.println(">> Start continuous motion");
          moving = true;
        }
      }
      else if (receivedMessage == "stopall") {
        Serial.println(">> Stop all motion");
        moving = false;
      }
      receivedMessage = "";
    }
    else {
      receivedMessage += incomingChar;
    }
  }
}

void handleOnlinePing() {
  unsigned long now = millis();
  if ((now - lastOnlineToggle) >= ONLINE_INTERVAL) {
    onlineState = !onlineState;
    onlineWrite(onlineState ? LOW : HIGH);
    lastOnlineToggle = now;
  }
}