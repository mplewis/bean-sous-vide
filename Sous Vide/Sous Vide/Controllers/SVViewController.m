//
//  SVViewController.m
//  Sous Vide
//
//  Created by Matthew Lewis on 6/19/14.
//  Copyright (c) 2014 Kestrel Development. All rights reserved.
//

#define ICON_CHECK @"checkmark.png"
#define ICON_X @"cancel.png"
#define ICON_QUESTION @"help.png"

#define BT_STATUS_TEXT @"Bluetooth: %@"
#define BEAN_STATUS_TEXT @"Bean: %@"

#define SOUS_VIDE_BEAN_NAME @"Sous Vide"

#import "SVViewController.h"

@interface SVViewController () <PTDBeanManagerDelegate, PTDBeanDelegate>

@property PTDBeanManager *beanManager;
@property NSMutableDictionary *beans;
@property PTDBean *sousVideBean;

@end

@implementation SVViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.beanManager = [[PTDBeanManager alloc] initWithDelegate:self];
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
        self.rescanButton.hidden = YES;
    } else {
        // When we turn Bluetooth off, clear the scanned Beans.
        [self.beans removeAllObjects];
        [self.beanManager stopScanningForBeans_error:nil];
        [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Disconnected"]];
        [self.beanStatusSpinner stopAnimating];
        [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_X]];
        self.beanStatusIcon.hidden = NO;
        self.rescanButton.hidden = YES;
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDiscoverBean:(PTDBean *)bean error:(NSError *)error
{
    NSUUID *key = bean.identifier;
    if (![self.beans objectForKey:key]) {
        [self.beans setObject:bean forKey:key];
        NSLog(@"New Bean discovered: %@", bean.name);
        if ([bean.name isEqualToString:SOUS_VIDE_BEAN_NAME]) {
            [self.beanManager connectToBean:bean error:nil];
            [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Connecting..."]];
        }
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didConnectToBean:(PTDBean *)bean error:(NSError *)error
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Connected"]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_CHECK]];
    self.beanStatusIcon.hidden = NO;
    self.rescanButton.hidden = YES;
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Disconnected"]];
    [self.beanStatusSpinner stopAnimating];
    [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_X]];
    self.beanStatusIcon.hidden = NO;
    self.rescanButton.hidden = NO;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
