#include <OneWire.h>
#include <DallasTemperature.h>

// Thermometer is connected to pin 2
#define ONE_WIRE_BUS 2

// Powerswitch Tail is connected to pin 3
#define HEATER_PIN 3

// Wait 5 seconds between checking temperature
#define CONTROL_INTERVAL 10000

// Default to starting at 120 F
#define DEFAULT_TARGET_TEMP 120

// State variables
bool enabled = false;
bool heating = false;
byte currentTempF = 0;
byte targetTempF = DEFAULT_TARGET_TEMP;

// Setup a oneWire instance to communicate with OneWire devices
OneWire oneWire(ONE_WIRE_BUS);

// Pass our oneWire reference to the Dallas Temperature library
DallasTemperature sensors(&oneWire);
DeviceAddress thermometer;

void setup()
{
    Serial.begin(57600);
    sensors.begin();
    pinMode(HEATER_PIN, OUTPUT);
    digitalWrite(HEATER_PIN, 0);
}

void loop()
{   
    // Blink red while grabbing temperature
    Bean.setLed(255, 0, 0);
    
    // Get current temperature
    sensors.requestTemperatures();
    currentTempF = (byte) sensors.getTempFByIndex(0);

    // Process control loop if there are no incoming commands
    if (!Serial.available()) {
        
        // Blink green
        Bean.setLed(0, 255, 0);
        
        // Turn heater on or off based on current temperature
        if (currentTempF < targetTempF) {
            // Turn on heater when currentTempF is less than targetTempF
            heating = 1;    
        } else {
            // Turn off heater when currentTempF is equal to or greater than targetTempF
            heating = 0;
        }

        // If heater is disabled, turn off heating no matter what
        if (!enabled) {
            heating = 0;
        }

        digitalWrite(HEATER_PIN, heating);

        Bean.setLed(0, 0, 0);
        Bean.sleep(CONTROL_INTERVAL);

    } else {

        // Process incoming commands and blink blue
        Bean.setLed(0, 0, 255);

        byte cmd = Serial.read();

        if (cmd == 0x00) {
            // 0: Get status
            // Return 0x00, current temp, target temp, enabled, heating, 0xFF
            Serial.write(0x00);
            Serial.write(currentTempF);
            Serial.write(targetTempF);
            Serial.write(enabled ? 0x01 : 0x00);
            Serial.write(heating ? 0x01 : 0x00);
            Serial.write(0xFF);

        } else if (cmd == 0x01) {
            // 1: Enable heater
            enabled = true;

            // Return 0x01, 0xFF
            Serial.write(0x01);
            Serial.write(0xFF);

        } else if (cmd == 0x02) {
            // 2: Disable heater
            enabled = false;

            // Return 0x02, 0xFF
            Serial.write(0x02);
            Serial.write(0xFF);

        } else if (cmd == 0x03) {
            // 3: Set target temperature
            while (!Serial.available());
            targetTempF = Serial.read();

            // Return 0x03, target temp, 0xFF
            Serial.write(0x03);
            Serial.write(targetTempF);
            Serial.write(0xFF);

        } else {
            // Flush incoming buffer
            while (Serial.available()) {
                Serial.read();
            }
        }

    }

    Bean.setLed(0, 0, 0);
}
