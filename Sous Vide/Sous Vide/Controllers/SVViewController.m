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

#define BT_STATUS_TEXT @"Bluetooth: %@"
#define BEAN_STATUS_TEXT @"Bean: %@"

#define ALPHA_FADED 0.3
#define ALPHA_OPAQUE 1.0

#define CMD_STATUS 0x00
#define CMD_ENABLE 0x01
#define CMD_DISABLE 0x02
#define CMD_SETTARGET 0x03

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
        [self.btStatusIcon setImage:[UIImage imageNamed:ICON_CHECK]];
        [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, @"Enabled"]];
    } else if (self.beanManager.state == BeanManagerState_PoweredOff) {
        [self.btStatusIcon setImage:[UIImage imageNamed:ICON_X]];
        [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, @"Disabled"]];
    } else {
        [self.btStatusIcon setImage:[UIImage imageNamed:ICON_QUESTION]];
        [self.btStatusLabel setText:[NSString stringWithFormat:BT_STATUS_TEXT, @"Unknown"]];
    }
    
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        // If Bluetooth is on, start scanning for beans.
        [self.beanManager startScanningForBeans_error:nil];
        [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Scanning..."]];
        [self.beanStatusSpinner startAnimating];
        self.beanStatusIcon.hidden = YES;
    } else {
        // When we turn Bluetooth off, clear the scanned Beans.
        [self.beans removeAllObjects];
        [self.beanManager stopScanningForBeans_error:nil];
        [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Disconnected"]];
        [self.beanStatusSpinner stopAnimating];
        [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_X]];
        self.beanStatusIcon.hidden = NO;

        // Dim the on-screen controls
        [self disableControls];
        
        // Stop sending update requests
        [self stopUpdateRequests];
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDiscoverBean:(PTDBean *)bean error:(NSError *)error
{
    NSUUID *key = bean.identifier;
    if (![self.beans objectForKey:key]) {
        [self.beans setObject:bean forKey:key];
        NSLog(@"New Bean discovered: %@ (%@)", bean.name, [key UUIDString]);
        if ([bean.name isEqualToString:SOUS_VIDE_BEAN_NAME]) {
            [self.beanManager connectToBean:bean error:nil];
            [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Connecting..."]];
            [self.beanStatusSpinner startAnimating];
            self.beanStatusIcon.hidden = YES;
        }
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didConnectToBean:(PTDBean *)bean error:(NSError *)error
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Connected"]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_CHECK]];
    self.beanStatusIcon.hidden = NO;

    // Enable controls
    [self enableControls];
    
    // Keep track of the connected Bean
    self.sousVideBean = bean;
    
    // Start sending update packets
    [self startUpdateRequests];
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    // Disable controls
    [self disableControls];
    
    // Stop sending update requests
    [self stopUpdateRequests];
    
    // Throw away the connected Bean
    self.sousVideBean = nil;
    
    // If Bluetooth is ready, start scanning again right away
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self startScanning];
    }
}

- (void)bean:(PTDBean *)bean serialDataReceived:(NSData *)data
{
    NSLog(@"Data received: %@", data);
}

- (void)startScanning
{
    [self.beanManager startScanningForBeans_error:nil];
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Scanning..."]];
    [self.beanStatusSpinner startAnimating];
    self.beanStatusIcon.hidden = YES;
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

- (void)enableControls
{
    self.heatingIcon.alpha = ALPHA_OPAQUE;
    self.tempLabel.alpha = ALPHA_OPAQUE;
    self.heatingLabel.alpha = ALPHA_OPAQUE;
    self.targetTempLabel.alpha = ALPHA_OPAQUE;
    self.cookingLabel.alpha = ALPHA_OPAQUE;
    [self.targetTempButtons setEnabled:YES];
    self.targetTempButtons.alpha = ALPHA_OPAQUE;
    [self.cookingSwitch setEnabled:YES];
}

- (void)requestUpdate
{
    NSMutableData *data = [[NSMutableData alloc] init];
    [data appendBytes:(char[]){CMD_STATUS} length:1];
    [self.sousVideBean sendSerialData:data];
}

- (void)startUpdateRequests
{
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
