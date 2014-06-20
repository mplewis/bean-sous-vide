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
    Serial.begin(9600);
    
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
    // Wait for serial data
    while (!Serial.available());
    byte cmd = Serial.read();
    if (cmd == '0') {
        // 0: Get status
        // Send the command to get temperatures
        sensors.requestTemperatures();
        // Print the received temperature
        Serial.print("Enabled: ");
        Serial.print(enabled);
        Serial.print(", temp F: ");
        Serial.print(temperature());
        Serial.print(", target F: ");
        Serial.println(targetTempF);
    } else if (cmd == '1') {
        // 1: Turn on heater
        enabled = true;
        Serial.println("Heater on");
    } else if (cmd == '2') {
        // 2: Turn off heater
        enabled = false;
        Serial.println("Heater off");
    } else if (cmd == '3') {
        // 3: Set target temperature
        while (!Serial.available());
        targetTempF = Serial.read();
        Serial.print("Set temp to ");
        Serial.println(targetTempF);
    } else {
        while (Serial.available()) {
            Serial.read();
        }
    }
}
