#include <OneWire.h>
#include <DallasTemperature.h>

// Data wire is plugged into port 2 on the Arduino
#define ONE_WIRE_BUS 2

// State variables
bool enabled = false;
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
    if (!sensors.getAddress(thermometer, 0)) {
        Serial.println("Unable to find address for Device 0");
    }

    sensors.setResolution(thermometer, 9);
}

float temperature()
{
    return DallasTemperature::toFahrenheit(sensors.getTempC(thermometer));
}

void loop()
{
    // Sleep if there are no incoming commands
    if (!Serial.available()) {
        Bean.sleep(20000);
    }

    Bean.setLed(0, 0, 255);

    byte cmd = Serial.read();

    if (cmd == 0x00) {
        // 0: Get status
        // Send the command to get temperatures
        sensors.requestTemperatures();

        // Return 0x00, current temp, target temp, enabled, 0xFF
        Serial.write(0x00);
        Serial.write((int)temperature());
        Serial.write(targetTempF);
        Serial.write(enabled ? 0x01 : 0x00);
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
