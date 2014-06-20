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

// ST_: State machine states for parsing Bean messages

// Waiting for message type byte
#define ST_READY 0x00

// Got message type STATUS (0x00); waiting for current temp
#define ST_STATUS_CURRENT_TEMP 0x01
// Got current temp; waiting for target temp
#define ST_STATUS_TARGET_TEMP 0x02
// Got target temp; waiting for ENABLED byte
#define ST_STATUS_ENABLED 0x03

// Got message type TARGET_TEMP (0x03); waiting for target temp
#define ST_TARGET_TEMP 0x04

// Got expected message bytes; waiting for terminator (0xFF)
#define ST_DONE 0xFF

#import "SVViewController.h"

@interface SVViewController () <PTDBeanManagerDelegate, PTDBeanDelegate>

@property PTDBeanManager *beanManager;
@property NSMutableDictionary *beans;
@property PTDBean *sousVideBean;
@property NSTimer *updateTimer;

@end

@implementation SVViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set up BeanManager
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];

    // Make sure controls start faded
    [self disableControls];
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
        [self connectionLost];
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
    [self connectionLost];
    
    // If Bluetooth is ready, start scanning again right away
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self startScanning];
    }
}

- (void)bean:(PTDBean *)bean serialDataReceived:(NSData *)data
{
    NSLog(@"Data received: %@", data);
    [self enableControlsWithTemp:77 targetTemp:100 isEnabled:YES isHeating:YES];
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

- (void)connectionLost
{
    // Run this when the Bean disconnects or Bluetooth chokes.
    
    // Disable controls
    [self disableControls];
    
    // Stop sending update requests
    [self stopUpdateRequests];
    
    // Throw away the connected Bean
    self.sousVideBean = nil;
}

- (void)requestUpdate
{
    // If the connected Bean is nil or not connected, stop updating
    if (!self.sousVideBean || [self.sousVideBean state] != BeanState_ConnectedAndValidated) {
        NSLog(@"Tried to request update while Bean was disconnected. Stopping updates.");
        [self stopUpdateRequests];
    } else {
        NSMutableData *data = [[NSMutableData alloc] init];
        [data appendBytes:(char[]){CMD_STATUS} length:1];
        [self.sousVideBean sendSerialData:data];
    }
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
    [self.updateTimer invalidate];
    self.updateTimer = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
