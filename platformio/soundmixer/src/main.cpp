#include <Arduino.h>

#define BUTTON_HH_PIN 6
#define BUTTON_CC_PIN 7
#define RELAY_PIN     4

#define RELAY_ON  HIGH
#define RELAY_OFF LOW

const unsigned long DEBOUNCE_MS = 30;
const unsigned long STATE_INTERVAL_MS = 1000;

enum ActiveButton {
    NONE,
    HH,
    CC
};

ActiveButton activeButton = NONE;

bool hhRaw;
bool hhStable;
bool hhPrevious;
unsigned long hhLastChange = 0;

bool ccRaw;
bool ccStable;
bool ccPrevious;
unsigned long ccLastChange = 0;

bool controlsArmed = false;
unsigned long lastStateSend = 0;


void sendState()
{
    switch (activeButton)
    {
        case HH:
            Serial.println("STATE:HH");
            break;

        case CC:
            Serial.println("STATE:CC");
            break;

        default:
            Serial.println("STATE:NONE");
            break;
    }

    lastStateSend = millis();
}


void updateButtons()
{
    unsigned long now = millis();

    bool newHH = digitalRead(BUTTON_HH_PIN);

    if (newHH != hhRaw) {
        hhRaw = newHH;
        hhLastChange = now;
    }

    if ((now - hhLastChange) >= DEBOUNCE_MS) {
        hhStable = hhRaw;
    }

    bool newCC = digitalRead(BUTTON_CC_PIN);

    if (newCC != ccRaw) {
        ccRaw = newCC;
        ccLastChange = now;
    }

    if ((now - ccLastChange) >= DEBOUNCE_MS) {
        ccStable = ccRaw;
    }
}


void startHH()
{
    activeButton = HH;

    digitalWrite(RELAY_PIN, RELAY_ON);

    Serial.println("HH_DOWN");
    sendState();
}


void stopHH()
{
    digitalWrite(RELAY_PIN, RELAY_OFF);

    activeButton = NONE;

    Serial.println("HH_UP");
    sendState();
}


void startCC()
{
    activeButton = CC;

    digitalWrite(RELAY_PIN, RELAY_ON);

    Serial.println("CC_DOWN");
    sendState();
}


void stopCC()
{
    digitalWrite(RELAY_PIN, RELAY_OFF);

    activeButton = NONE;

    Serial.println("CC_UP");
    sendState();
}


void processSerial()
{
    while (Serial.available())
    {
        String command = Serial.readStringUntil('\n');
        command.trim();

        if (command == "GET_STATE") {
            sendState();
        }
    }
}


void setup()
{
    pinMode(BUTTON_HH_PIN, INPUT_PULLUP);
    pinMode(BUTTON_CC_PIN, INPUT_PULLUP);

    digitalWrite(RELAY_PIN, RELAY_OFF);
    pinMode(RELAY_PIN, OUTPUT);

    hhRaw = digitalRead(BUTTON_HH_PIN);
    hhStable = hhRaw;
    hhPrevious = hhStable;
    hhLastChange = millis();

    ccRaw = digitalRead(BUTTON_CC_PIN);
    ccStable = ccRaw;
    ccPrevious = ccStable;
    ccLastChange = millis();

    Serial.begin(115200);

    delay(1000);

    Serial.println("READY");
    sendState();
}


void loop()
{
    updateButtons();
    processSerial();

    bool hhPressed =
        (hhStable == LOW && hhPrevious == HIGH);

    bool hhReleased =
        (hhStable == HIGH && hhPrevious == LOW);

    bool ccPressed =
        (ccStable == LOW && ccPrevious == HIGH);

    bool ccReleased =
        (ccStable == HIGH && ccPrevious == LOW);

    if (!controlsArmed)
    {
        if (hhStable == HIGH && ccStable == HIGH)
        {
            controlsArmed = true;
            Serial.println("BUTTONS_READY");
        }
    }
    else
    {
        switch (activeButton)
        {
            case NONE:

                if (hhPressed) {
                    startHH();
                }
                else if (ccPressed) {
                    startCC();
                }

                break;

            case HH:

                if (hhReleased) {
                    stopHH();
                }

                break;

            case CC:

                if (ccReleased) {
                    stopCC();
                }

                break;
        }
    }

    hhPrevious = hhStable;
    ccPrevious = ccStable;

    if ((millis() - lastStateSend) >= STATE_INTERVAL_MS) {
        sendState();
    }

    delay(1);
}