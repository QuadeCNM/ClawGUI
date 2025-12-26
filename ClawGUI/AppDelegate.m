//
//  AppDelegate.m
//  ClawGUI
//
//  Created by Jon Wade on 12/23/25.
//

#import "AppDelegate.h"
#import "clawControl.h"

#define STEPPER_STEPS_PER_REV           3200    // Number of steps per revolution for the stepper motor
                                                // 16 microsteps / 1.8 degree step angle * 360 degrees = 3200 steps
#define STEPPER_MAX_REVOLUTIONS         12      // Maximum number of revolutions the stepper can move
                                                // 20 TPI lead screw with 3/4 inch travel = 15 revolutions
#define MAX_STEPPER_POSITION            (STEPPER_STEPS_PER_REV * STEPPER_MAX_REVOLUTIONS)
#define MIN_STEPPER_POSITION            0

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
@property (strong) IBOutlet NSSlider *clawSpeedSlider;

@end

@implementation AppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    serialPortConnected = FALSE;
    
    NSError* error;
    NSArray* devFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"/dev/" error:&error];
    NSMutableArray* serialDevices = [[NSMutableArray alloc] init];
    
    for(id fileName in devFiles)
    {
        if([fileName containsString:@"cu."])
        {
            [serialDevices addObject:[fileName copy]];
        }
    }
    
    // Set GUI defaults
    [_serialPortComboBox removeAllItems];
    
    for(id filename in serialDevices)
    {
        [_serialPortComboBox addItemWithObjectValue:filename];
    }
    
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
    
    [_clawSpeedSlider setMinValue:0.0];
    [_clawSpeedSlider setMaxValue:100.0];
    [_clawSpeedSlider setDoubleValue:0.0];
    [_clawSpeedSlider setEnabled:FALSE];
    
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
        [_clawSpeedSlider setEnabled:TRUE];
        
        NSDictionary* status = [_claw readStatusToDictionaryWithError:&error];
        
        if(status != nil)
        {
            [_clawSpeedSlider setDoubleValue:[self convertPeriodToSpeed:[[status valueForKey:@"Step Period"] integerValue]]];
        }
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
        [_clawSpeedSlider setEnabled:FALSE];
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
        
        NSDictionary* status = [_claw readStatusToDictionaryWithError:&error];
        
        if(status != nil)
        {
            NSInteger stepPosition = [[status valueForKey:@"Current Position"] integerValue];
            double clawPositionSliderValue = (((double)stepPosition/(double)MAX_STEPPER_POSITION) * 100.0);
            [_clawPositionSlider setFloatValue:clawPositionSliderValue];
        }
    }
}

- (IBAction)readStatusButtonPressed:(id)sender
{
    NSDictionary* status;
    NSError *error = nil;
    
    status = [_claw readStatusToDictionaryWithError:&error];
}

- (NSInteger)convertSpeedToPeriod:(NSInteger)speed
{
    double period = 400.0 - (3.6 * (double)speed);
    
    return round(period);
}

- (double)convertPeriodToSpeed:(NSInteger)period
{
    double speed = ((double)period -400.0)/-3.6;
    
    return speed;
}

- (IBAction)speedSliderMoved:(id)sender
{
    NSError *error = nil;
    if(([_claw connectionStatus] == TRUE) && ([_claw clawStepperEnabled] == TRUE))
    {
        [_claw setClawSpeed:[self convertSpeedToPeriod:[_clawSpeedSlider integerValue]] withError:&error];
    }
    
}

@end
