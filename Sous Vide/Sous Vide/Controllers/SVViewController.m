//
//  SVViewController.m
//  Sous Vide
//
//  Created by Matthew Lewis on 6/19/14.
//  Copyright (c) 2014 Kestrel Development. All rights reserved.
//

#define SOUS_VIDE_BEAN_NAME @"SousVide"

#define UPDATE_INTERVAL_SECS 5.0

#define ICON_CHECK @"checkmark.png"
#define ICON_X @"cancel.png"
#define ICON_QUESTION @"help.png"
#define ICON_QUESTION_LG @"help_lg.png"
#define ICON_HEATING_LG @"hot.png"
#define ICON_COOLING_LG @"cool.png"

#define BT_STATUS_TEXT @"Bluetooth: %@"
#define BEAN_STATUS_TEXT @"Bean: %@"

#define ALPHA_FADED 0.3
#define ALPHA_OPAQUE 1.0

#define CMD_STATUS 0x00
#define CMD_ENABLE 0x01
#define CMD_DISABLE 0x02
#define CMD_SETTARGET 0x03

// MSG_: Bytes indicating message types for Bean messages

#define MSG_STATUS 0x00
#define MSG_ENABLE 0x01
#define MSG_DISABLE 0x02
#define MSG_SET_TARGET_TEMP 0x03

// ST_: State machine states for parsing Bean messages

#define ST_READY 0x00 // Waiting for message type byte

#define ST_STATUS_CURRENT_TEMP 0x01 // Got message type STATUS (0x00); waiting for current temp
#define ST_STATUS_TARGET_TEMP 0x02 // Got current temp; waiting for target temp
#define ST_STATUS_ENABLED 0x03 // Got target temp; waiting for ENABLED byte

#define ST_SET_TARGET_TEMP 0x04 // Got message type SET_TARGET_TEMP (0x03); waiting for target temp

#define ST_DONE 0xFF // Got expected message bytes; waiting for terminator (0xFF)

#import "SVViewController.h"

@interface SVViewController () <PTDBeanManagerDelegate, PTDBeanDelegate>

@property PTDBeanManager *beanManager;
@property NSMutableDictionary *beans;
@property PTDBean *sousVideBean;
@property NSTimer *updateTimer;

// For parsing serial messages

@property unsigned char msgType;
@property unsigned char msgCurrentState;
@property unsigned char msgCurrentTemp;
@property unsigned char msgTargetTemp;
@property BOOL msgEnabled;

@end

@implementation SVViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up BeanManager
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];
    
    // Clear program state
    [self reset];
}

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
    }
}

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
            // Show the connectino status.
            [self setBeanStatusWithSpinner:@"Connecting..."];
        }
    }
}

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

- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    // When the Bean disconnects, clean up
    [self reset];
    
    // If Bluetooth is ready, start scanning again right away
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self startScanning];
    }
}

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
                               isHeating:NO];
        } else if (self.msgType == MSG_ENABLE) {
            [self showEnabled:YES];
        } else if (self.msgType == MSG_DISABLE) {
            [self showEnabled:NO];
        } else if (self.msgType == MSG_SET_TARGET_TEMP) {
            [self showTargetTemp:self.msgTargetTemp];
        }
        self.msgCurrentState = ST_READY;
    }
}

- (void)setBtStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.btStatusIcon setImage:[UIImage imageNamed:iconName]];
    [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, statusText]];
}

- (void)setBeanStatus:(NSString *)statusText withIcon:(NSString *)iconName
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:iconName]];
    self.beanStatusIcon.hidden = NO;
}

- (void)setBeanStatusWithSpinner:(NSString *)statusText
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, statusText]];
    [self.beanStatusSpinner startAnimating];
    self.beanStatusIcon.hidden = YES;
}

- (void)startScanning
{
    [self.beanManager startScanningForBeans_error:nil];
    [self setBeanStatusWithSpinner:@"Scanning..."];
}

- (void)stopScanning
{
    // Clear all found Beans and stop scanning.
    [self.beans removeAllObjects];
    [self.beanManager stopScanningForBeans_error:nil];
}

- (void)showTemp:(int)temp
{
    [self.tempLabel setText:[NSString stringWithFormat:@"%i° F", temp]];
}

- (void)showTargetTemp:(int)targetTemp
{
    [self.targetTempLabel setText:[NSString stringWithFormat:@"%i° F", targetTemp]];
}

- (void)showEnabled:(BOOL)enabled
{
    self.cookingSwitch.on = enabled;
}

- (void)showHeating:(BOOL)heating
{
    NSString *heatingImage = heating ? ICON_HEATING_LG : ICON_COOLING_LG;
    [self.heatingIcon setImage:[UIImage imageNamed:heatingImage]];
    [self.heatingLabel setText:heating ? @"Heating" : @"Cooling"];
}

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
    [self.targetTempButtons setEnabled:YES];
    self.targetTempButtons.alpha = ALPHA_OPAQUE;
    [self.cookingSwitch setEnabled:YES];
    
    [self showTemp:temp];
    [self showTargetTemp:targetTemp];
    [self showEnabled:enabled];
    [self showHeating:heating];
}

- (void)disableControls
{
    self.heatingIcon.alpha = ALPHA_FADED;
    self.tempLabel.alpha = ALPHA_FADED;
    self.heatingLabel.alpha = ALPHA_FADED;
    self.targetTempLabel.alpha = ALPHA_FADED;
    self.cookingLabel.alpha = ALPHA_FADED;
    [self.targetTempButtons setEnabled:NO];
    self.targetTempButtons.alpha = ALPHA_FADED;
    [self.cookingSwitch setEnabled:NO];
    
    [self.heatingIcon setImage:[UIImage imageNamed:ICON_QUESTION_LG]];
    [self.tempLabel setText:@"?° F"];
    [self.heatingLabel setText:@"Unknown"];
    [self.targetTempLabel setText:@"?° F"];
    [self.cookingLabel setText:@"?"];
}

- (void)reset
{
    // Run this when the Bean disconnects or Bluetooth chokes.
    
    // Disable controls
    [self disableControls];
    
    // Stop sending update requests
    [self stopUpdateRequests];
    
    // Throw away the connected Bean
    self.sousVideBean = nil;

    // Reset the state machine
    self.msgCurrentState = ST_READY;
}

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

- (void)requestUpdate
{
    [self sendData:(char[]){CMD_STATUS} length:1];
}

- (void)enableHeater
{
    [self sendData:(char[]){CMD_ENABLE} length:1];
}

- (void)disableHeater
{
    [self sendData:(char[]){CMD_DISABLE} length:1];
}

- (void)setTargetTemp:(unsigned char)targetTemp
{
    [self sendData:(char[]){CMD_SETTARGET, targetTemp} length:2];
}

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
