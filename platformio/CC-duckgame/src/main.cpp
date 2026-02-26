#include <string>
#include <Arduino.h>
using namespace std;

// PIN definíciók
#define PIN_STEP 6
#define PIN_DIR 7
#define PIN_HOME 0
#define PIN_LASER 1
#define PIN_ONLINE_PING 10
#define PIN_TASMOTA_RX 20

#define DELAY_BASE 3


unsigned long lastOnlineToggle = 0;
const unsigned long ONLINE_INTERVAL = 10000; // 10 s
// Mozgási paraméterek
long MOVE_STEPS = 160000;
int START_DELAY = 50;
int MIN_DELAY = DELAY_BASE;
int ACCEL_STEPS = 5000;

string espID = string(ID);

bool onlineState = true;
bool moving = false;
string receivedMessage = "";
char incomingChar;

void performHoming(); 
void moveWithRamp(long steps);
void moveSimple(int steps);
void readSerial();
void handleOnlinePing();
void(* resetFunc) (void) = 0;

HardwareSerial CommandSerial(1);

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

  digitalWrite(PIN_STEP, LOW);
  digitalWrite(PIN_DIR, LOW);
  digitalWrite(PIN_ONLINE_PING, LOW);
  
  performHoming();
}

void loop() {
  readSerial();

  if (moving) {
    digitalWrite(PIN_DIR, LOW);
    moveWithRamp(MOVE_STEPS);

    digitalWrite(PIN_DIR, HIGH);
    moveWithRamp(MOVE_STEPS);
  }
}

void performHoming() {
  long stepCount = 0;

  if (digitalRead(PIN_HOME)) {
    digitalWrite(PIN_DIR, LOW);
    moveSimple(10000);
  }

  digitalWrite(PIN_DIR, HIGH);

  while (!digitalRead(PIN_HOME)) {
    int delayMicros;
    if (stepCount < ACCEL_STEPS) {
      delayMicros = map(stepCount, 0, ACCEL_STEPS, START_DELAY, DELAY_BASE);
    } else {
      delayMicros = DELAY_BASE;
    }

    digitalWrite(PIN_STEP, HIGH);
    delayMicroseconds(delayMicros * 2);
    digitalWrite(PIN_STEP, LOW);
    delayMicroseconds(delayMicros * 2);

    stepCount++;
    readSerial();
  }
}

void moveWithRamp(long steps) {
  long stepCount = 0;
  
  while (stepCount < steps && moving) {
    readSerial();

    if (digitalRead(PIN_HOME) && digitalRead(PIN_DIR)) {
      return;
    }

    if (!digitalRead(PIN_LASER)) {
      moving = false;
      delay(500);
      performHoming();
      Serial.println("Duck shot down");
      return;
    }

    int delayMicros;
    if (stepCount < ACCEL_STEPS) {
      delayMicros = map(stepCount, 0, ACCEL_STEPS, START_DELAY, MIN_DELAY);
    } 
    else if (stepCount < (steps - ACCEL_STEPS)) {
      delayMicros = MIN_DELAY;
    } 
    else {
      long decelStep = stepCount - (steps - ACCEL_STEPS);
      delayMicros = map(decelStep, 0, ACCEL_STEPS, MIN_DELAY, START_DELAY);
    }

    digitalWrite(PIN_STEP, HIGH);
    delayMicroseconds(delayMicros);
    digitalWrite(PIN_STEP, LOW);
    delayMicroseconds(delayMicros);

    stepCount++;
  }
}

void moveSimple(int steps) {
  for (int i = 0; i < steps; i++) {
    digitalWrite(PIN_STEP, HIGH);
    delayMicroseconds(START_DELAY);
    digitalWrite(PIN_STEP, LOW);
    delayMicroseconds(START_DELAY);
  }
}

void readSerial(){
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
        MIN_DELAY = DELAY_BASE * (11 - stoi(receivedMessage.substr(12,2)));
        Serial.print("Speed set to:");
        Serial.print(stoi(receivedMessage.substr(12,2)));
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
    digitalWrite(PIN_ONLINE_PING, onlineState ? LOW : HIGH);
    lastOnlineToggle = now;
  }
}