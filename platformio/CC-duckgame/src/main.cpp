#include <ESP32Servo.h>
#include <string>
using namespace std;

#define servoPin1 32
#define servoPin2 33
#define servoPin3 25
#define servoPin4 26
#define startPos 180 //down
#define endPos 60 //up
#define servoStop 200 //stop at peak

// create servo object to control a servo
Servo servo1;
Servo servo2;
Servo servo3;
Servo servo4;  
 
// variable to store the servo position
int servo1Pos = 0;
int servo2Pos = 0;
int servo3Pos = 0;
int servo4Pos = 0;  
int directionChanger = 1;

bool initNeeded = true;
bool animationStarted = false;
bool servo1Shotdown = false;
bool servo2Shotdown = false;
bool servo3Shotdown = false;
bool servo4Shotdown = false;

//delay time between steps
int servoSpeed = 7;

void servoAnimation();
void servoAnimationInit();
void servoInit();
void readSerial();
void servoPos(int servoNumber, double pos);
void shootDown(int servoNumber);
 
void setup() {
	Serial.begin(115200);
	Serial.println("ESP32 is ready. Please enter a message:");

	// Allow allocation of all timers
	ESP32PWM::allocateTimer(0);
	ESP32PWM::allocateTimer(1);
	ESP32PWM::allocateTimer(2);
	ESP32PWM::allocateTimer(3);

	servo1.setPeriodHertz(50);
	servo2.setPeriodHertz(50);
	servo3.setPeriodHertz(50);
	servo4.setPeriodHertz(50);

	servo1.attach(servoPin1, 544, 2500);
	servo2.attach(servoPin2, 544, 2500);
	servo3.attach(servoPin3, 544, 2500);
	servo4.attach(servoPin4, 544, 2500);
}
 
void loop() {
	readSerial();
	if (animationStarted){
		servoAnimation();
	}
}

void servoAnimationInit(){
	if (initNeeded){
		for (int i = 0; i <= 100; i += 1) { 
			servoPos(2,i);
			servoPos(4,i);
			
			delay(servoSpeed);
		}

		initNeeded = false;
		directionChanger = 1;
	}
}

void servoInit(){
	animationStarted = false;
	servo1Shotdown = false;
	servo2Shotdown = false;
	servo3Shotdown = false;
	servo4Shotdown = false;

	servoPos(1,0);
	servoPos(2,0);
	servoPos(3,0);
	servoPos(4,0);

	initNeeded = true;
}

void servoAnimation(){
	servoAnimationInit();
	
	for (int i = 0; i <= 100 && animationStarted; i += 1) { 
		readSerial();

		if (!servo1Shotdown){
			servoPos(1, servo1Pos + 1 * directionChanger);
		}
		else{
			servoPos(1,0);
		}

		if (!servo2Shotdown){
			servoPos(2,servo2Pos - 1 * directionChanger);
		}
		else{
			servoPos(2,0);
		}

		if (!servo3Shotdown){
			servoPos(3,servo3Pos + 1 * directionChanger);
		}
		else{
			servoPos(3,0);
		}

		if (!servo4Shotdown){
			servoPos(4,servo4Pos - 1 * directionChanger);
		}
		else{
			servoPos(4,0);
		}

		if(servo1Shotdown && servo2Shotdown && servo3Shotdown && servo4Shotdown){
			animationStarted = false;
		}

		delay(servoSpeed);
	}
	directionChanger *= -1;
	delay(servoStop);
}

void readSerial(){
	string receivedMessage = "";

	while (Serial.available()) {
		char incomingChar = Serial.read();  // Read each character from the buffer
		
		if (incomingChar == '\n') {  // Check if the user pressed Enter (new line character)
			if (receivedMessage == "start"){
				servoInit();
				delay(servoStop * 5);
				animationStarted = true;
			}
			else if (receivedMessage == "init"){
				animationStarted = false;
				servoInit();
			}
			else if (receivedMessage == "stop"){
				animationStarted = false;
			}
			else if (receivedMessage.substr(0,3) == "pos"){
				servoPos(stoi(receivedMessage.substr(3,1)),stod(receivedMessage.substr(5,3)));	
			}
			else if (receivedMessage.substr(0,5) == "shoot"){
				shootDown(stoi(receivedMessage.substr(5,1)));
			}

			return;
		} 
		else {
			receivedMessage += incomingChar; // Append the character to the message string
		}
	}
}

void servoPos(int servoNumber, double pos){
	if (servoNumber == 1){
		servo1Pos = pos;
		servo1.write(startPos - ((startPos - endPos) / 100.0 * pos));
	}
	else if (servoNumber == 2){
		servo2Pos = pos;
		servo2.write(startPos - ((startPos - endPos) / 100.0 * pos));
	}
	else if (servoNumber == 3){
		servo3Pos = pos;
		servo3.write(startPos - ((startPos - endPos) / 100.0 * pos));
	}
	else if (servoNumber == 4){
		servo4Pos = pos;
		servo4.write(startPos - ((startPos - endPos) / 100.0 * pos));
	}
	
}

void shootDown(int servoNumber){
	if (servoNumber == 1){
		servo1Shotdown = true;
	}
	else if (servoNumber == 2){
		servo2Shotdown = true;
	}
	else if (servoNumber == 3){
		servo3Shotdown = true;
	}
	else if (servoNumber == 4){
		servo4Shotdown = true;
	}
	
}