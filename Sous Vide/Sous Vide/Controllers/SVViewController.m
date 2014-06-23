//
//  SVViewController.m
//  Sous Vide
//
//  Created by Matthew Lewis on 6/19/14.
//  Copyright (c) 2014 Kestrel Development. All rights reserved.
//

// Which Bean to connect to (BLE local name)
#define SOUS_VIDE_BEAN_NAME @"SousVide"

// How often the app should ask the Bean for updates
#define UPDATE_INTERVAL_SECS 5.0

// Image resource locations
#define ICON_CHECK @"checkmark.png"
#define ICON_X @"cancel.png"
#define ICON_QUESTION @"help.png"
#define ICON_QUESTION_LG @"help_lg.png"
#define ICON_HEATING_LG @"hot.png"
#define ICON_COOLING_LG @"cool.png"

// Text templates for the top two status lines
#define BT_STATUS_TEXT @"Bluetooth: %@"
#define BEAN_STATUS_TEXT @"Bean: %@"

// Alpha values for fading disabled interface elements
#define ALPHA_FADED 0.3
#define ALPHA_OPAQUE 1.0

// Command bytes for telling the Bean what to do
#define CMD_STATUS 0x00
#define CMD_ENABLE 0x01
#define CMD_DISABLE 0x02
#define CMD_SETTARGET 0x03

// Bytes indicating message types for Bean messages
#define MSG_STATUS 0x00
#define MSG_ENABLE 0x01
#define MSG_DISABLE 0x02
#define MSG_SET_TARGET_TEMP 0x03

// State machine states for parsing Bean messages
#define ST_READY 0x00               // Waiting for message type byte
#define ST_STATUS_CURRENT_TEMP 0x01 // Got message type STATUS (0x00); waiting for current temp
#define ST_STATUS_TARGET_TEMP 0x02  // Got current temp; waiting for target temp
#define ST_STATUS_ENABLED 0x03      // Got target temp; waiting for ENABLED byte
#define ST_STATUS_HEATING 0x05      // Got ENABLED byte; waiting for HEATING byte
#define ST_SET_TARGET_TEMP 0x04     // Got message type SET_TARGET_TEMP (0x03); waiting for target temp
#define ST_DONE 0xFF                // Got expected message bytes; waiting for terminator (0xFF)

#import "SVViewController.h"

@interface SVViewController () <PTDBeanManagerDelegate, PTDBeanDelegate>

@property PTDBeanManager *beanManager;  // Searches for Beans and manages Bluetooth connection
@property NSMutableDictionary *beans;   // A list of all found Beans, indexed by UUID
@property PTDBean *sousVideBean;        // The connected Bean, specified by SOUS_VIDE_BEAN_NAME
@property NSTimer *updateTimer;         // Used for asking the Bean for a status update every x seconds

@property BOOL targetTempSliding;       // Used to keep the Bean from getting updates until the
                                        // user's thumb is off the slider

// These variables are used to store parsed data from serial messages
@property unsigned char msgType;            // The last message type parsed (STATUS, ENABLE, DISABLE, SETTARGET)
@property unsigned char msgCurrentState;    // The current state of the parser state machine
@property unsigned char msgCurrentTemp;     // Storage for the "current cooker temperature" variable
@property unsigned char msgTargetTemp;      // Storage for the "target cooker temperature" variable
@property BOOL msgEnabled;                  // Storage for the "is the cooker enabled right now?" boolean
@property BOOL msgHeating;                  // Storage for the "is the cooker heating right now?" boolean

@end

@implementation SVViewController

// Called on load of the View.
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up BeanManager
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];
    
    // Clear program state
    [self reset];
}

// Called when something happens to Bluetooth (turns on, turns off, etc).
- (void)beanManagerDidUpdateState:(PTDBeanManager *)beanManager
{
    // Set Bluetooth status label and icon for the current Bluetooth state.
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self setBtStatus:@"Enabled" withIcon:ICON_CHECK];
    } else if (self.beanManager.state == BeanManagerState_PoweredOff) {
        [self setBtStatus:@"Disabled" withIcon:ICON_X];
    } else {
        [self setBtStatus:@"Unknown" withIcon:ICON_QUESTION];
    }
    
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        // If Bluetooth is on, start scanning for beans.
        [self startScanning];
    } else {
        // When we turn Bluetooth off, stop scanning.
        [self stopScanning];
        // When the Bean disconnects, clean up
        [self reset];
        // Show the Bean as disconnected
        [self setBeanStatus:@"Disconnected" withIcon:ICON_X];
    }
}

// Called on discovery of any Bean during scanning.
- (void)BeanManager:(PTDBeanManager *)beanManager didDiscoverBean:(PTDBean *)bean error:(NSError *)error
{
    NSUUID *key = bean.identifier;
    // Add newly-seen Beans to the dict.
    if (![self.beans objectForKey:key]) {
        [self.beans setObject:bean forKey:key];
        NSLog(@"New Bean discovered: %@ (%@)", bean.name, [key UUIDString]);
        if ([bean.name isEqualToString:SOUS_VIDE_BEAN_NAME]) {
            // Connect to the Sous Vide Bean.
            [self.beanManager connectToBean:bean error:nil];
            // Show the connection status.
            [self setBeanStatusWithSpinner:@"Connecting..."];
        }
    }
}

// Called when the sous vide Bean is connected.
- (void)BeanManager:(PTDBeanManager *)beanManager didConnectToBean:(PTDBean *)bean error:(NSError *)error
{
    // Set Bean delegate to self
    [bean setDelegate:self];
    
    // Show connected status
    [self setBeanStatus:@"Connected" withIcon:ICON_CHECK];
    
    // Stop scanning
    [self stopScanning];
    
    // Keep track of the connected Bean
    self.sousVideBean = bean;
    
    // Start sending update packets
    [self startUpdateRequests];
}

// Called when the sous vide Bean disconnects.
- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    // When the Bean disconnects, clean up
    [self reset];
}

// Called when serial data is received from the connected Bean.
// This is the state machine that parses incoming serial messages.
- (void)bean:(PTDBean *)bean serialDataReceived:(NSData *)data
{
    const char *dataBytes = (const char *)[data bytes];
    unsigned char dataByte = dataBytes[0];

    if (self.msgCurrentState == ST_READY) {
        // Read message type and set next state accordingly
        self.msgType = dataByte;

        if (self.msgType == MSG_STATUS) {
            self.msgCurrentState = ST_STATUS_CURRENT_TEMP;
            
        } else if (self.msgType == MSG_ENABLE) {
            self.msgCurrentState = ST_DONE;
        
        } else if (self.msgType == MSG_DISABLE) {
            self.msgCurrentState = ST_DONE;
        
        } else if (self.msgType == MSG_SET_TARGET_TEMP) {
            self.msgCurrentState = ST_SET_TARGET_TEMP;
        
        } // Ignore all other messages

    } else if (self.msgCurrentState == ST_STATUS_CURRENT_TEMP) {
        self.msgCurrentTemp = dataByte;
        self.msgCurrentState = ST_STATUS_TARGET_TEMP;
        
    } else if (self.msgCurrentState == ST_STATUS_TARGET_TEMP) {
        self.msgTargetTemp = dataByte;
        self.msgCurrentState = ST_STATUS_ENABLED;
        
    } else if (self.msgCurrentState == ST_STATUS_ENABLED) {
        self.msgEnabled = dataByte;
        self.msgCurrentState = ST_STATUS_HEATING;
        
    } else if (self.msgCurrentState == ST_STATUS_HEATING) {
        self.msgHeating = dataByte;
        self.msgCurrentState = ST_DONE;
        
    } else if (self.msgCurrentState == ST_SET_TARGET_TEMP) {
        self.msgTargetTemp = dataByte;
        self.msgCurrentState = ST_DONE;
        
    } else if (self.msgCurrentState == ST_DONE && dataByte == 0xFF) {
        // State machine was waiting for terminator and received it.
        if (self.msgType == MSG_STATUS) {
            [self enableControlsWithTemp:self.msgCurrentTemp
                              targetTemp:self.msgTargetTemp
                               isEnabled:self.msgEnabled
                               isHeating:self.msgHeating];
        }
        self.msgCurrentState = ST_READY;
    }
}

// Set the Bluetooth status text/icon.
- (void)setBtStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.btStatusIcon setImage:[UIImage imageNamed:iconName]];
    [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, statusText]];
}

// Set the Bean status text/icon.
- (void)setBeanStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:iconName]];
    self.beanStatusIcon.hidden = NO;
}

// Set the Bean status text and set the icon to an activity spinner.
- (void)setBeanStatusWithSpinner:(NSString *)statusText
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner startAnimating];
    self.beanStatusIcon.hidden = YES;
}

// Start scanning for Beans.
- (void)startScanning
{
    [self.beanManager startScanningForBeans_error:nil];
    [self setBeanStatusWithSpinner:@"Scanning..."];
}

// Stop scanning for Beans.
- (void)stopScanning
{
    // Clear all found Beans and stop scanning.
    [self.beans removeAllObjects];
    [self.beanManager stopScanningForBeans_error:nil];
}

// Display the current temperature of the cooker.
- (void)showTemp:(int)temp
{
    [self.tempLabel setText:[NSString stringWithFormat:@"%i° F", temp]];
}

// Display the target temperature.
- (void)showTargetTemp:(int)targetTemp
{
    [self.targetTempLabel setText:[NSString stringWithFormat:@"%i° F", targetTemp]];
    [self.targetTempSlider setValue:targetTemp];
}

// Display the current cooker enable status.
- (void)showEnabled:(BOOL)enabled
{
    self.cookingSwitch.on = enabled;
    [self.cookingLabel setText:enabled ? @"Yes" : @"No"];
}

// Display the current cooker heating/cooling status.
- (void)showHeating:(BOOL)heating
{
    NSString *heatingImage = heating ? ICON_HEATING_LG : ICON_COOLING_LG;
    [self.heatingIcon setImage:[UIImage imageNamed:heatingImage]];
    [self.heatingLabel setText:heating ? @"Heating" : @"Cooling"];
}

// Enable controls with latest status data. We don't want to enable the controls
// and un-dim the display with stale data, so we have to pass in fresh data
// (temp, enabled, etc.) when we call this method.
- (void)enableControlsWithTemp:(int)temp
                    targetTemp:(int)targetTemp
                     isEnabled:(BOOL)enabled
                     isHeating:(BOOL)heating
{
    self.heatingIcon.alpha = ALPHA_OPAQUE;
    self.tempLabel.alpha = ALPHA_OPAQUE;
    self.heatingLabel.alpha = ALPHA_OPAQUE;
    self.targetTempLabel.alpha = ALPHA_OPAQUE;
    self.cookingLabel.alpha = ALPHA_OPAQUE;
    [self.targetTempSlider setEnabled:YES];
    self.targetTempSlider.alpha = ALPHA_OPAQUE;
    [self.cookingSwitch setEnabled:YES];
    
    [self showTemp:temp];
    [self showEnabled:enabled];
    [self showHeating:heating];
    if (!self.targetTempSliding) {
        [self showTargetTemp:targetTemp];
    }
}

// Disable controls and dim the display.
- (void)disableControls
{
    self.heatingIcon.alpha = ALPHA_FADED;
    self.tempLabel.alpha = ALPHA_FADED;
    self.heatingLabel.alpha = ALPHA_FADED;
    self.targetTempLabel.alpha = ALPHA_FADED;
    self.cookingLabel.alpha = ALPHA_FADED;
    [self.targetTempSlider setEnabled:NO];
    self.targetTempSlider.alpha = ALPHA_FADED;
    [self.cookingSwitch setEnabled:NO];
    
    [self.heatingIcon setImage:[UIImage imageNamed:ICON_QUESTION_LG]];
    [self.tempLabel setText:@"?° F"];
    [self.heatingLabel setText:@"Unknown"];
    [self.targetTempLabel setText:@"?° F"];
    [self.cookingLabel setText:@"?"];
}

// targetTempDown, targetTempChanged, targetTempUp keep the slider from
// spamming the Bean with serial data. Sending lots of packets very quickly
// can cause the Bean to lose connection with the iOS device, so we send
// packets only when the user releases the slider.

// On slider touch
- (IBAction)targetTempDown:(UISlider *)sender
{
    self.targetTempSliding = true;
}

// On slider slide
- (IBAction)targetTempChanged:(UISlider *)sender
{
    [self showTargetTemp:[sender value]];
}

// On slider release
- (IBAction)targetTempUp:(UISlider *)sender
{
    self.targetTempSliding = false;
    [self setTargetTemp:[sender value]];
}

// Handle changes in the Cooking Enable switch.
- (IBAction)enableSwitchChanged:(UISwitch *)sender
{
    if (sender.on) {
        [self enableHeater];
    } else {
        [self disableHeater];
    }
}

// Run this when the Bean disconnects or Bluetooth chokes.
- (void)reset
{
    // Disable controls
    [self disableControls];
    
    // Stop sending update requests
    [self stopUpdateRequests];
    
    // Throw away the connected Bean
    self.sousVideBean = nil;

    // Reset the state machine
    self.msgCurrentState = ST_READY;
    
    // If Bluetooth is ready, start scanning again right away
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self startScanning];
    }
}

// Helper function. Send a char array of bytes with specified length to the Bean.
- (void)sendData:(char[])cmdBytes length:(int)length
{
    // If the connected Bean is nil or not connected, stop updating
    if (!self.sousVideBean || [self.sousVideBean state] != BeanState_ConnectedAndValidated) {
        NSLog(@"Tried to send data while Bean was disconnected. Ignoring.");
    } else {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:cmdBytes length:length];
        [self.sousVideBean sendSerialData:data];
    }
}

// Ask the Bean for a status update. This happens asynchronously, so the iOS
// device will get results and handle them in the bean:serialDataReceived method.
- (void)requestUpdate
{
    [self sendData:(char[]){CMD_STATUS} length:1];
}

// Enable heating.
- (void)enableHeater
{
    [self sendData:(char[]){CMD_ENABLE} length:1];
}

// Disable heating. The Bean will not turn on the heater pin even if the temperature is low.
- (void)disableHeater
{
    [self sendData:(char[]){CMD_DISABLE} length:1];
}

// Set the Bean target temperature.
- (void)setTargetTemp:(unsigned char)targetTemp
{
    [self sendData:(char[]){CMD_SETTARGET, targetTemp} length:2];
}

// Start asking the Bean for status updates every 5 seconds.
- (void)startUpdateRequests
{
    // Disable any prior timers
    [self stopUpdateRequests];
    
    // Schedule update requests to run every 5 seconds
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:UPDATE_INTERVAL_SECS
                                                        target:self
                                                      selector:@selector(requestUpdate)
                                                      userInfo:nil
                                                       repeats:YES];

    // Send an update request immediately
    [self requestUpdate];
}

// Cancel the update timer and stop asking the Bean for updates.
- (void)stopUpdateRequests
{
    if (self.updateTimer) {
        [self.updateTimer invalidate];
    }
    self.updateTimer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
