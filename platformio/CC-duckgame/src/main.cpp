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

// Mozgási paraméterek (most már változó)
long MOVE_STEPS = 160000;
int START_DELAY = 50;
int MIN_DELAY = 5;
int ACCEL_STEPS = 2000;

bool moving = false;

string receivedMessage = "";
char incomingChar;

void performHoming(); 
void moveWithRamp(long steps);
void moveSimple(int steps);
void readSerial();
void(* resetFunc) (void) = 0;

HardwareSerial CommandSerial(1);

void setup() {
  CommandSerial.begin(9600, SERIAL_8N1, PIN_TASMOTA_RX, -1);
	Serial.begin(115200);
  Serial.println("Stepper Ready.");
  Serial.println("Use 'home', 'move', 'stop', or 'set <param> <value>'");

  pinMode(PIN_STEP, OUTPUT);
  pinMode(PIN_DIR, OUTPUT);
  pinMode(PIN_HOME, INPUT_PULLUP);
  pinMode(PIN_LASER, INPUT_PULLUP);

  digitalWrite(PIN_STEP, LOW);
  digitalWrite(PIN_DIR, LOW);
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
  if (digitalRead(PIN_HOME) == HIGH) {
    digitalWrite(PIN_DIR, LOW);
    moveSimple(10000);
  }

  digitalWrite(PIN_DIR, HIGH);

  while (digitalRead(PIN_HOME) == LOW) {
    digitalWrite(PIN_STEP, HIGH);
    delayMicroseconds(START_DELAY);
    digitalWrite(PIN_STEP, LOW);
    delayMicroseconds(START_DELAY);
  }
}

void moveWithRamp(long steps) {
  long stepCount = 0;
  while (stepCount < steps && moving) {
    if (digitalRead(PIN_HOME) == HIGH && digitalRead(PIN_DIR)) {
      return;
    }
    readSerial();

    int delayMicros;
    if (stepCount < ACCEL_STEPS) {
      delayMicros = map(stepCount, 0, ACCEL_STEPS, START_DELAY, MIN_DELAY);
    } else if (stepCount < (steps - ACCEL_STEPS)) {
      delayMicros = MIN_DELAY;
    } else {
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
	while (CommandSerial.available()) {
		incomingChar = CommandSerial.read();  // Read each character from the buffer	
		
		if (incomingChar == '\n') {  // Check if the user pressed Enter (new line character)
			if (receivedMessage == "home"){
        Serial.println(">> Homing...");
        performHoming();
        Serial.println(">> Homing done");
			}
			else if (receivedMessage == "move"){
        Serial.println(">> Start continuous motion");
        moving = true;
			}
			else if (receivedMessage == "stop"){
        Serial.println(">> Stop motion");
        moving = false;
			}
			else if (receivedMessage.substr(0,5) == "speed"){
        MIN_DELAY = 5 * (11 - stoi(receivedMessage.substr(6,2)));
        Serial.print("Speed set to:");
        Serial.println(MIN_DELAY);
			}
      else if (receivedMessage == "restart"){
				Serial.println("Restarting");
				resetFunc();
			}
			else{
        Serial.print("Unknown cmd: ");
        Serial.println(receivedMessage.c_str());
      }

			receivedMessage = "";

			return;
		}
		else {
			receivedMessage += incomingChar; // Append the character to the message string
		}
	}
}