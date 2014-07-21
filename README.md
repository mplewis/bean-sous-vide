# DIY Sous-Vide with Bean

Build a sous-vide cooker with your Bean! Make delicious food and leverage the power of Bluetooth Low Energy to control your cooking experience.

[![Sous-vide components, all together](http://punchthrough.com/files/external-images/sous-vide/teaser.jpg)](http://punchthrough.com/files/external-images/sous-vide/teaser.jpg)

*Above: The finished sous-vide machine and app, ready to cook delicious salmon!*

# What is sous-vide?

Short version:

> Sous-vide is hot-water immersion cooking. You seal your food in plastic bags and put it into hot water. This keeps the moisture locked in and makes sure meat cooks fully all the way through.

Long version from Wikipedia:

> Sous-vide (French for "under vacuum") is a method of cooking food sealed in airtight plastic bags in a water bath or in a temperature-controlled steam environment for longer than normal cooking times at an accurately regulated temperature much lower than normally used for cooking. The intention is to cook the item evenly, ensuring that the inside is properly cooked without overcooking the outside, and retain moisture.

Once you start cooking your food sous-vide, you'll never go back—everything comes out moist and delicious and falls apart on your fork. It's great for cooking everything from salmon to steak to squash.

# What do I need?

A [LightBlue Bean](http://punchthrough.com/bean/), of course! This is the bit that regulates the temperature and talks to your phone.

[![LightBlue Bean in box](http://punchthrough.com/images/press/bean/original/open-bean-box.jpg)](http://punchthrough.com/bean/)

Commercial sous-vide solutions for home chefs (such as the [Sansaire](http://sansaire.com/)) usually include the following:

* Temperature sensor
* Heating coil
* Water circulator

Instead of a heating coil, this DIY sous-vide machine uses a slow cooker (crock pot) to heat the water and cook the food. Since the stoneware in the slow cooker distributes heat evenly to the contents of the cooker, we won't need to include a water circulator.

We picked a [Hamilton Beach 8-quart slow cooker from Amazon](http://www.amazon.com/Hamilton-Beach-33182A-Cooker-8-Quart/dp/B00EZI26C8/ref=sr_1_1?s=kitchen&ie=UTF8&qid=1403562458&sr=1-1&keywords=8+quart+slow+cooker). Whatever cooker you use, make sure it's an **analog control mechanism**—no fancy digital temperature regulators or timers. The Bean is only able to turn the cooker on and off with a relay, and power-cycling a digital cooker will most likely cause it to stop cooking until it's set up again.

[![Hamilton Beach 8-quart slow cooker from Amazon](http://punchthrough.com/files/external-images/sous-vide/slow-cooker.jpg)](http://www.amazon.com/Hamilton-Beach-33182A-Cooker-8-Quart/dp/B00EZI26C8/)

*Above: Hamilton Beach 8-quart slow cooker*

To turn the slow cooker on and off and keep the water at the desired temperature, we bought an AC relay device called the [PowerSwitch Tail II](https://www.sparkfun.com/products/10747) from Sparkfun. We selected the PowerSwitch Tail II because it let us use the Bean to control AC power in a safe way. This relay is fully isolated and allows us to use low-voltage, low-current signals to turn the slow cooker on and off.

[![PowerSwitch Tail II from Sparkfun](http://punchthrough.com/files/external-images/sous-vide/powerswitch-tail-ii.jpg)](https://www.sparkfun.com/products/10747)

*Above: PowerSwitch Tail II photo by Sparkfun, licensed under [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/)*

To measure the temperature of the water, we ordered a [DS18B20 temperature sensor with waterproof enclosure](https://www.sparkfun.com/products/11050) from Sparkfun. You could use any waterproof temperature sensor you want, but the Arduino code included with this project uses the DS18B20 because it's an accurate, reliable, and inexpensive temperature sensor.

This sensor relies on a pullup resistor to enable communication via the 1-Wire protocol. We used a 10k resistor, but most large resistors (>1kΩ) will work.

[![DS18B20 from Sparkfun](http://punchthrough.com/files/external-images/sous-vide/ds18b20.jpg)](https://www.sparkfun.com/products/11050)

*Above: DS18B20 photo by Sparkfun, licensed under [CC BY-NC-SA 3.0](http://creativecommons.org/licenses/by-nc-sa/3.0/)*

Finally, we hooked our Bean up to one of the 2xAA battery packs included in the Maker Kit and attached it with a bit of double-sided sticky foam. We connected this because polling a temperature sensor and talking to an iOS device every 5 seconds will quickly drain a coin cell battery.

We'll use an iOS device that supports Bluetooth Low Energy with an app that talks to the Bean and sets the target temperature for the cooker.

# How do I get started?

If you'd like to get up and running right away, here are the steps you'll need to follow:

## Rename your Bean to `SousVide`

You'll need to rename your Bean using the OS X Loader App. The iOS app finds the Sous Vide bean by looking for a nearby Bean with the name `SousVide`—if your Bean isn't named exactly the same, the iOS app won't try to connect.

Alternately, you can change the name that the app searches for inside `Sous Vide/Controllers/SVViewController.m` to match your Bean instead:

```
// Which Bean to connect to (BLE local name)
#define SOUS_VIDE_BEAN_NAME @"SousVide"
```

## Program your Bean

Open the sketch at `sous_vide_arduino/sous_vide_arduino.ino` in the Arduino software, Verify it, and program your Bean with the sketch.

This sketch relies on the OneWire library by PJRC and the Dallas Temperature library by Miles Burton. You need to install those libraries into your Arduino software before Verifying the sketch.

Useful links:

* [OneWire library](https://www.pjrc.com/teensy/td_libs_OneWire.html)
* [Dallas Temperature library](http://www.milesburton.com/?title=Dallas_Temperature_Control_Library)
* [How to install new Arduino libraries](http://arduino.cc/en/Guide/Libraries)

## Run the iOS app on your iDevice

Clone this repository and open `Sous Vide.xcworkspace` in Xcode. Once that's complete, build and run the app on your iPhone or iPod Touch.

The iOS simulator doesn't support Bluetooth Low Energy, so you'll need to have actual hardware to use the app properly. You'll also need an [iOS Developer Program](https://developer.apple.com/programs/ios/) account to be able to run the app on your device.

## Wire the Bean up

The Bean should be wired as follows:

* Bean `VCC/GND`: Drawing power from the 2xAA battery pack (`VCC`: red, `GND`: black)
* Bean `BAT/GND`: Powering the DS18B20 temperature sensor (`BAT`: red, `GND`: black)
* Bean IO pin `2`: Connected to the DS18B20 temperature sensor's data line (the white wire)
* Bean IO pin `3`: Connected to the PowerSwitch Tail II `+in` (pin 1)
* Bean `GND`: Connected to the PowerSwitch Tail II `-in` (pin 2)
* 4.7k resistor: Connected between Bean `BAT` and Bean IO pin `2` (pullup on the DS18B20 data line)

## Power on and sanity check

You can verify the Bean is working properly by running the iOS app and connecting to the Bean. You should connect the temperature sensor and relay to the Bean, but you don't have to plug the slow cooker or the relay into the wall—the relay has an LED that indicates its powered/unpowered status.

Once the iOS app connects to the Bean, you should be able to read the current temperature of the sensor. If you turn on the "Cooking" switch and set the target temperature higher than the current temperature with the slider, you should see the Bean turn on the relay (the red LED on the relay should come on) in an attempt to heat the water in the slow cooker to the target temperature.

## You're good to go!

It's worth taking a little bit of time to verify the Bean is able to moderate the temperature of the slow cooker within reasonable bounds—in our experience, the temperature has stayed within ±2°F, but your results will vary based on the cooker you use.

Don't forget basic safety—slow cookers generate heat, so make sure to monitor your setup while you're cooking to avoid any risk of fire!

# Known Issues

## UI glitches

Sometimes the app will disconnect from the Bean but show that it's still connected, or disconnect from the Bean but fail to scan for nearby Beans to reconnect. The current workarounds are to cycle Bluetooth power on your iOS device or to force quit the app and reopen it.

## Periodic disconnects

The iOS app frequently loses connection to the Bean. This won't affect your cooking—the Bean holds the last-set values in memory and continues to use them to regulate the temperature of the water in the cooker.

# Questions?

If you have any questions about this project, the best place to ask is the [Beantalk community forum](http://beantalk.punchthrough.com/).

All aspects of this project are covered under [the MIT License](http://opensource.org/licenses/MIT).