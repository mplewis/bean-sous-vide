#include <OneWire.h>
#include <DallasTemperature.h>

// Thermometer is connected to pin 2
#define ONE_WIRE_BUS 2

// Powerswitch Tail is connected to pin 3
#define HEATER_PIN 3

// State variables
bool enabled = false;
bool heating = false;
byte targetTempF = 0;

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
    // Get current temperature
    sensors.requestTemperatures();
    int currentTempF = (int) sensors.getTempFByIndex(0);
    
    // Turn heater on or off based on current temperature
    if (currentTempF <= targetTempF + 1) {
        // Turn on heater when currentTempF is less than 2 degrees above targetTempF
        heating = 1;
        
    } else {
        // Turn off heater when currentTempF is 2+ degrees above targetTempF
        heating = 0;
    }
    digitalWrite(HEATER_PIN, heating);

    // Sleep if there are no incoming commands
    if (!Serial.available()) {
        Bean.sleep(10000);
    }

    // Process incoming commands
    Bean.setLed(0, 0, 255);

    byte cmd = Serial.read();

    if (cmd == 0x00) {
        // 0: Get status
        // Send the command to get temperatures
        sensors.requestTemperatures();

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

    Bean.setLed(0, 0, 0);
}
