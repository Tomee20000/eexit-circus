#include <Arduino.h>

#define BUTTON_HH_PIN 6
#define BUTTON_CC_PIN 7
#define RELAY_PIN     4

// Ha a reléd LOW-ra kapcsol be, cseréld meg ezt a kettőt.
#define RELAY_ON  HIGH
#define RELAY_OFF LOW

const unsigned long DEBOUNCE_MS = 30;

enum ActiveButton {
    NONE,
    HH,
    CC
};

ActiveButton activeButton = NONE;


// ----- HH debounce -----

bool hhRaw = HIGH;
bool hhStable = HIGH;
unsigned long hhLastChange = 0;


// ----- CC debounce -----

bool ccRaw = HIGH;
bool ccStable = HIGH;
unsigned long ccLastChange = 0;


void updateButtons()
{
    unsigned long now = millis();

    // HH
    bool newHH = digitalRead(BUTTON_HH_PIN);

    if (newHH != hhRaw) {
        hhRaw = newHH;
        hhLastChange = now;
    }

    if ((now - hhLastChange) >= DEBOUNCE_MS) {
        hhStable = hhRaw;
    }


    // CC
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
    Serial.flush();
}


void stopHH()
{
    Serial.println("HH_UP");
    Serial.flush();

    digitalWrite(RELAY_PIN, RELAY_OFF);

    activeButton = NONE;
}


void startCC()
{
    activeButton = CC;

    digitalWrite(RELAY_PIN, RELAY_ON);

    Serial.println("CC_DOWN");
    Serial.flush();
}


void stopCC()
{
    Serial.println("CC_UP");
    Serial.flush();

    digitalWrite(RELAY_PIN, RELAY_OFF);

    activeButton = NONE;
}


void setup()
{
    pinMode(BUTTON_HH_PIN, INPUT_PULLUP);
    pinMode(BUTTON_CC_PIN, INPUT_PULLUP);

    pinMode(RELAY_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, RELAY_OFF);

    Serial.begin(115200);

    delay(1000);

    Serial.println("READY");
}


void loop()
{
    updateButtons();

    switch (activeButton)
    {
        case NONE:

            // HH elsőbbséget kap, ha pontosan egyszerre nyomják meg őket
            if (hhStable == LOW) {
                startHH();
            }
            else if (ccStable == LOW) {
                startCC();
            }

            break;


        case HH:

            // HH gomb felengedve
            if (hhStable == HIGH) {
                stopHH();
            }

            break;


        case CC:

            // CC gomb felengedve
            if (ccStable == HIGH) {
                stopCC();
            }

            break;
    }

    delay(1);
}