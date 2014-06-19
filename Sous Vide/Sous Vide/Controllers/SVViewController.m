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
    
    // If Bluetooth is on, start scanning for beans.
    if (self.beanManager.state == BeanManagerState_PoweredOn) {
        [self.beanManager startScanningForBeans_error:nil];
        [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Scanning..."]];
        [self.beanStatusSpinner startAnimating];
        self.beanStatusIcon.hidden = YES;
    } else {
        [self.beanManager stopScanningForBeans_error:nil];
        [self.beanStatusLabel setText:[NSString stringWithFormat:BEAN_STATUS_TEXT, @"Disconnected"]];
        [self.beanStatusSpinner stopAnimating];
        [self.beanStatusIcon setImage:[UIImage imageNamed:ICON_X]];
        self.beanStatusIcon.hidden = NO;
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDiscoverBean:(PTDBean *)bean error:(NSError *)error
{
    NSUUID *key = bean.identifier;
    if (![self.beans objectForKey:key]) {
        NSLog(@"New Bean discovered: %@", bean.name);
        [self.beans setObject:bean forKey:key];
    }
}

- (void)BeanManager:(PTDBeanManager *)beanManager didConnectToBean:(PTDBean *)bean error:(NSError *)error
{
    
}

- (void)BeanManager:(PTDBeanManager *)beanManager didDisconnectBean:(PTDBean *)bean error:(NSError *)error
{
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
