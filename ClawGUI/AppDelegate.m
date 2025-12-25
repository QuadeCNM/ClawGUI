//
//  AppDelegate.m
//  ClawGUI
//
//  Created by Jon Wade on 12/23/25.
//

#import "AppDelegate.h"
#import "clawControl.h"

@interface AppDelegate ()
{
    bool serialPortConnected;
}

@property clawControl *claw;
@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSComboBox *serialPortComboBox;
@property (strong) IBOutlet NSButton *connectButton;
@property (strong) IBOutlet NSButton *enableClawButton;
@property (strong) IBOutlet NSSlider *clawPositionSlider;
@property (strong) IBOutlet NSButton *stopClawButton;
@property (strong) IBOutlet NSButton *readStatusButton;

@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    serialPortConnected = FALSE;
    
    // Set GUI defaults
    [_serialPortComboBox removeAllItems];
    [_serialPortComboBox addItemWithObjectValue:@"cu.usbmodem1101"];
    [_serialPortComboBox selectItemAtIndex:0];
    [_serialPortComboBox setEnabled:TRUE];
    
    [_connectButton setTitle:@"Connect"];
    [_connectButton setEnabled:TRUE];
    
    [_enableClawButton setTitle:@"Enable Claw"];
    [_enableClawButton setEnabled:FALSE];
      
    [_clawPositionSlider setMinValue:0.0];
    [_clawPositionSlider setMaxValue:100.0];
    [_clawPositionSlider setDoubleValue:0.0];
    [_clawPositionSlider setEnabled:FALSE];
    
    [_stopClawButton setEnabled:FALSE];
    
    [_readStatusButton setEnabled:FALSE];
    
    _claw = [[clawControl alloc] init];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (IBAction)connectButtonPressed:(id)sender
{
    NSError *error = nil;
    
    // we are connecting since previous status was disabled
    if(serialPortConnected == FALSE)
    {
        [_claw setDevicePathWith:[NSString stringWithFormat:@"/dev/%s", [[_serialPortComboBox stringValue] cStringUsingEncoding:NSUTF8StringEncoding]]
                       withError:&error];
        [_claw connectToSerialPortWithError:&error];
        [_connectButton setTitle:@"Disconnect"];
        [_serialPortComboBox setEnabled:FALSE];
        serialPortConnected = TRUE;
        
        [_enableClawButton setEnabled:TRUE];
        [_stopClawButton setEnabled:TRUE];
        [_readStatusButton setEnabled:TRUE];
    }
    else // we are disabling
    {
        // if claw is not disabled, then disable it.
        if([_claw clawStepperEnabled])
        {
            if([_claw disableClawStepperWithError:&error])
            { // do GUI stuff
                [_enableClawButton setTitle:@"Enable Claw"];
                [_clawPositionSlider setEnabled:FALSE];
            }
        }
            
        [_claw disconnectFromSerialPortWithError:&error];
        [_connectButton setTitle:@"Connect"];
        [_serialPortComboBox setEnabled:TRUE];
        serialPortConnected = FALSE;
        
        [_enableClawButton setEnabled:FALSE];
        [_clawPositionSlider setEnabled:FALSE];
        [_stopClawButton setEnabled:FALSE];
        [_readStatusButton setEnabled:FALSE];
    }
    
}

- (IBAction)enableButtonPressed:(id)sender
{
    NSError *error = nil;
    
    if([_claw clawStepperEnabled] == FALSE)
    {
        // do serial stuff to enable claw stepper
        if([_claw enableClawStepperWithError:&error])
        { // do GUI stuff
            [_enableClawButton setTitle:@"Disable Claw"];
            [_clawPositionSlider setEnabled:TRUE];
        }
    }
    else
    {
        if([_claw disableClawStepperWithError:&error])
        { // do GUI stuff
            [_enableClawButton setTitle:@"Enable Claw"];
            [_clawPositionSlider setEnabled:FALSE];
        }
    }
}

- (IBAction)PositionSliderMoved:(id)sender
{
    NSError *error = nil;
    if(([_claw connectionStatus] == TRUE) && ([_claw clawStepperEnabled] == TRUE))
    {
        [_claw setClawPosition:[_clawPositionSlider intValue] withError:&error];
    }
}

- (IBAction)stopClawButtonPressed:(id)sender
{
    NSError *error = nil;
    if([_claw connectionStatus] == TRUE)
    {
        [_claw stopClawMotionWithError:&error];
    }
}

- (IBAction)readStatusButtonPressed:(id)sender
{
    NSDictionary* status;
    NSError *error = nil;
    
    [_claw readStatusToDictionary:status withError:&error];
}

@end
