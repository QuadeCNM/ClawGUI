/**
    * @file AppDelegatel.h
    * @author Jon Wade
    * @date  23 Dec 2025
    * @copyright (c) 2025 Jon Wade. Standard MIT License applies. See LICENSE file.
    *
    * @brief definition of claw class
    *
    * This file contains the definition of the class for controlling claw over the serial port including connecting and
    * disconnecting the serial port.
*/

#import <Cocoa/Cocoa.h>

/**
    * Define AppDelegate for GUI.  This deligate handles all GUI actions from main window
 */
@interface AppDelegate : NSObject <NSApplicationDelegate>

/**
    * Handle connect button pressed action.  Connects to claw device over UART.  Also enables Enable button.  Changes
    * button label to "Disconnect" on connect.  When in DIsconnect state, it will disconnect from claw device.
    * @brief Handle connect button pressd action
    * @param sender Sender object of action
 */
- (IBAction)connectButtonPressed:(id)sender;

/**
    * Handle enable button pressed action.  Enables stepper motor of claw.  Changes label to "Disable" on success.
    * Also enables controls such as position slider, speed slider, stop button and enable cal button
    * @brief Handle enable button pressd action
    * @param sender Sender object of action
 */
- (IBAction)enableButtonPressed:(id)sender;

/**
    * Handle claw position slider movement.  Issues command to claw device to move claw to mirror slider position
    * @brief Handle claw position slider moved action
    * @param sender Sender object of action
 */
- (IBAction)PositionSliderMoved:(id)sender;

/**
    * Handle stops button press.  Issues command to claw device to stop motion.  Updates position
    * slider based on read status.
    * @brief Handle read status button press
    * @param sender Sender object of action
 */
- (IBAction)stopClawButtonPressed:(id)sender;

/**
    * Handle read status button press.  Issues command to claw device to return status.  Updates sliders based on read status.
    * Usefull if an external E-Stop occures to update slider positions.
    * @brief Handle read status button press
    * @param sender Sender object of action
 */
- (IBAction)readStatusButtonPressed:(id)sender;

/**
    * Handle claw speed slider movement.  Issues command to claw device to move claw to mirror slider position.
    * @brief Handle claw speed slider moved action
    * @note speed is sent as the pulse period between 40µs and 400µs.  Slider converts range linearly into pulse period scale
    * @param sender Sender object of action
 */
- (IBAction)speedSliderMoved:(id)sender;

/**
    * Handle enable calibration button press.  Enables "Set Origin" and "Bump Down" buttons.  Calibration can be a somewhat
    * dangerous operation so we want to protect from acccidental engagement of calibration buttons
    * @brief Handle enable calibration button press.
    * @param sender Sender object of action
 */
- (IBAction)enableCalibrationButtonPressed:(id)sender;

/**
    * Handle Set Origin button press.  Issues command to reset origin of claw to current position
    * @brief Handle Set Origin button press
    * @param sender Sender object of action
 */
- (IBAction)setOriginButtonPressed:(id)sender;

/**
    * Handle Bump Down button press.  Issues command to bump origin down a quarter turn and reset
    * origin to new origin location ( -1/4 turn).  Used to set calibrated zero point of claw device
    * @brief Handle Set Origin button press
    * @param sender Sender object of action
 */
- (IBAction)BumpOriginDownButtonPressed:(id)sender;

@end

