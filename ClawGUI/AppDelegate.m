/**
    * @file AppDelegatel.m
    * @author Jon Wade
    * @date  23 Dec 2025
    * @copyright (c) 2025 Jon Wade. Standard MIT License applies. See LICENSE file.
    *
    * @brief implimentation of AppDelegate, the main GUI deligate
    *
    * This file contains the implimentation of the AppDelegate for the main GUI interface of ClawGUI
*/

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
    bool serialPortConnected;           //!< Member variable to keep track of serial port conection state
    bool calibrationModeEnabled;        //!< Member variable to keep track of calibration mode
}

@property clawControl *claw;                                        //!< Claw object, used to communicate with claw and issue commands to claw device
@property (strong) IBOutlet NSWindow *window;                       //!< Main GUI Window
@property (strong) IBOutlet NSComboBox *serialPortComboBox;         //!< Combo box with drop down list of available serial port devices ("/dev/cu.usbmodem*")
@property (strong) IBOutlet NSButton *connectButton;                //!< Button to connect or disconnect from claw device
@property (strong) IBOutlet NSButton *enableClawButton;             //!< Button to enable stepper motor on claw device
@property (strong) IBOutlet NSSlider *clawPositionSlider;           //!< Slider to set position of claw.  Also position is moved on a STOP ro READ STATUS
@property (strong) IBOutlet NSButton *stopClawButton;               //!< Button to stop claw motion immediately, somewhat liek an emergency stop, but in software
@property (strong) IBOutlet NSButton *readStatusButton;             //!< Button to read status of claw device.  Usefull to update position slider on external E-Stop
@property (strong) IBOutlet NSSlider *clawSpeedSlider;              //!< Slider to set claw speed, specifically stepper pulse rate, between 2.5kHz and 25kHz
@property (strong) IBOutlet NSButton *enableCalibrationButton;      //!< Enables calibration buttons, specifically "Set Origin" and "Bump Down" Buttons
@property (strong) IBOutlet NSButton *setOriginButton;              //!< Button to set claw origin to current location
@property (strong) IBOutlet NSButton *bumpOriginDownButton;         //!< Button to bump down calibrated zero by 1/4 turn to move zero point down a little bit

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
        if([fileName containsString:@"cu.usbmodem"])
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
    
    // Only select combo box if we have a serial port device found.
    if([serialDevices count] > 0)
    {
        [_serialPortComboBox selectItemAtIndex:0];
        [_serialPortComboBox setEnabled:TRUE];
        [_connectButton setTitle:@"Connect"];
        [_connectButton setEnabled:TRUE];
    }
    else
    {
        [_serialPortComboBox setEnabled:FALSE];
        [_connectButton setTitle:@"Connect"];
        [_connectButton setEnabled:FALSE];
        
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"No Serial Devices Found for Claw",
                                    NSLocalizedRecoverySuggestionErrorKey : @"Claw devices need to be serial ports in /dev/ that start with \"cu.usbmodem\".  Please quit application and connect Claw device.",
                                    NSLocalizedFailureReasonErrorKey : @"Claw devices need to be serial ports in /dev/ that start with \"cu.usbmodem\""};
        NSError *error = [NSError errorWithDomain:@"com.jon-wade.ClawGUI.SerialError"
                                             code:101
                                         userInfo:userInfo];
        [NSApp presentError:error];
        
    }
    
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
    
    [_enableCalibrationButton setEnabled:FALSE];
    [_setOriginButton setEnabled:FALSE];
    [_bumpOriginDownButton setEnabled:FALSE];
    calibrationModeEnabled = FALSE;
    
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
        if([_claw setDevicePathWith:[NSString stringWithFormat:@"/dev/%s", [[_serialPortComboBox stringValue] cStringUsingEncoding:NSUTF8StringEncoding]]
                       withError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
            return;
        }
        
        if([_claw connectToSerialPortWithError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
            return;
        }
        [_connectButton setTitle:@"Disconnect"];
        [_serialPortComboBox setEnabled:FALSE];
        serialPortConnected = TRUE;
        
        [_enableClawButton setEnabled:TRUE];
        [_stopClawButton setEnabled:TRUE];
        [_readStatusButton setEnabled:TRUE];
        
        NSDictionary* status = [_claw readStatusToDictionaryWithError:&error];
        
        if(status != nil)
        {
            [_clawSpeedSlider setDoubleValue:[self convertPeriodToSpeed:[[status valueForKey:@"Step Period"] integerValue]]];
            [_clawPositionSlider setFloatValue:(((double)[[status valueForKey:@"Current Position"] integerValue]/(double)MAX_STEPPER_POSITION) * 100.0)];
        }
    }
    else // we are disabling
    {
        // if claw is not disabled, then disable it.
        if([_claw clawStepperEnabled])
        {
            if([_claw disableClawStepperWithError:&error] == EXIT_SUCCESS)
            { // do GUI stuff
                [_enableClawButton setTitle:@"Enable Claw"];
                [_clawPositionSlider setEnabled:FALSE];
            }
            else
            {
                [NSApp presentError:error];
                return;
            }
        }
            
        // disconnect from serial port
        if([_claw disconnectFromSerialPortWithError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
            return;
        }
        [_connectButton setTitle:@"Connect"];
        [_serialPortComboBox setEnabled:TRUE];
        serialPortConnected = FALSE;
        
        [_enableClawButton setEnabled:FALSE];
        [_clawPositionSlider setEnabled:FALSE];
        [_stopClawButton setEnabled:FALSE];
        [_readStatusButton setEnabled:FALSE];
        [_clawSpeedSlider setEnabled:FALSE];
        [_setOriginButton setEnabled:FALSE];
        [_bumpOriginDownButton setEnabled:FALSE];
        calibrationModeEnabled = FALSE;
        [_enableCalibrationButton setTitle:@"Enable Cal"];
    }
    
}

- (IBAction)enableButtonPressed:(id)sender
{
    NSError *error = nil;
    
    if([_claw clawStepperEnabled] == FALSE)
    {
        // do serial stuff to enable claw stepper
        if([_claw enableClawStepperWithError:&error] == EXIT_SUCCESS)
        { // do GUI stuff
            [_enableClawButton setTitle:@"Disable Claw"];
            [_clawPositionSlider setEnabled:TRUE];
            [_clawSpeedSlider setEnabled:TRUE];
            [_enableCalibrationButton setEnabled:TRUE];
        }
        else
        {
            [NSApp presentError:error];
            return;
        }
    }
    else
    {
        if([_claw disableClawStepperWithError:&error] == EXIT_SUCCESS)
        { // do GUI stuff
            [_enableClawButton setTitle:@"Enable Claw"];
            [_clawPositionSlider setEnabled:FALSE];
            [_clawSpeedSlider setEnabled:FALSE];
            [_enableCalibrationButton setEnabled:FALSE];
            [_setOriginButton setEnabled:FALSE];
            [_bumpOriginDownButton setEnabled:FALSE];
            calibrationModeEnabled = FALSE;
            [_enableCalibrationButton setTitle:@"Enable Cal"];
        }
        else
        {
            [NSApp presentError:error];
            return;
        }
    }
}

- (IBAction)PositionSliderMoved:(id)sender
{
    NSError *error = nil;
    if(([_claw connectionStatus] == TRUE) && ([_claw clawStepperEnabled] == TRUE))
    {
        if([_claw setClawPosition:[_clawPositionSlider intValue] withError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
        }
    }
}

- (IBAction)stopClawButtonPressed:(id)sender
{
    NSError *error = nil;
    if([_claw connectionStatus] == TRUE)
    {
        if([_claw stopClawMotionWithError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
            return;
        }
        
        NSDictionary* status = [_claw readStatusToDictionaryWithError:&error];
        if(error != nil)
        {
            [NSApp presentError:error];
            return;
        }
        
        if(status != nil)
        {
            [_clawSpeedSlider setDoubleValue:[self convertPeriodToSpeed:[[status valueForKey:@"Step Period"] integerValue]]];
            [_clawPositionSlider setFloatValue:(((double)[[status valueForKey:@"Current Position"] integerValue]/(double)MAX_STEPPER_POSITION) * 100.0)];
        }
    }
}

- (IBAction)readStatusButtonPressed:(id)sender
{
    NSError *error = nil;
    
    NSDictionary* status = [_claw readStatusToDictionaryWithError:&error];
    if(error != nil)
    {
        [NSApp presentError:error];
        return;
    }
    
    if(status != nil)
    {
        [_clawSpeedSlider setDoubleValue:[self convertPeriodToSpeed:[[status valueForKey:@"Step Period"] integerValue]]];
        [_clawPositionSlider setFloatValue:(((double)[[status valueForKey:@"Current Position"] integerValue]/(double)MAX_STEPPER_POSITION) * 100.0)];
    }
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
        if([_claw setClawSpeed:[self convertSpeedToPeriod:[_clawSpeedSlider integerValue]] withError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
        }
    }
    
}

- (IBAction)enableCalibrationButtonPressed:(id)sender
{
    if(calibrationModeEnabled == FALSE)
    {
        [_setOriginButton setEnabled:TRUE];
        [_bumpOriginDownButton setEnabled:TRUE];
        calibrationModeEnabled = TRUE;
        [_enableCalibrationButton setTitle:@"Disable Cal"];
    }
    else
    {
        [_setOriginButton setEnabled:FALSE];
        [_bumpOriginDownButton setEnabled:FALSE];
        calibrationModeEnabled = FALSE;
        [_enableCalibrationButton setTitle:@"Enable Cal"];
    }
}

- (IBAction)setOriginButtonPressed:(id)sender
{
    NSError *error = nil;
    if(([_claw connectionStatus] == TRUE) && ([_claw clawStepperEnabled] == TRUE))
    {
        if([_claw setClawZeroWithError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
        }
    }
}

- (IBAction)BumpOriginDownButtonPressed:(id)sender
{
    NSError *error = nil;
    if(([_claw connectionStatus] == TRUE) && ([_claw clawStepperEnabled] == TRUE))
    {
        if([_claw bumpClawZeroDownWithError:&error] == EXIT_FAILURE)
        {
            [NSApp presentError:error];
        }
    }
}

@end
