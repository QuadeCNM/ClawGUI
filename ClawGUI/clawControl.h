/**
    * @file clawControl.c
    * @author Jon Wade
    * @date  24 Dec 2025
    * @copyright (c) 2025 Jon Wade. Standard MIT License applies. See LICENSE file.
    *
    * @brief definition of claw class
    *
    * This file contains the definition of the class for controlling claw over the serial port including connecting and
    * disconnecting the serial port.
*/
#import <Foundation/Foundation.h>


#define CLAW_MAX_PERIOD                     400                                     // Maximum claw step period Freq = 1 / period = 2.5kHz
#define CLAW_MIN_PERIOD                     40                                      // Minimum claw step period Freq = 1 / period = 25kHz

#define CLAW_ERROR_DOMAIN                   @"com.jon-wade.ClawGUI.SerialError"     // NSError domain for errors created in clawControl.c
#define CLAW_ERROR_INVALID_PORT_PATH        100                                     // Error code for invalid serial port path
#define CLAW_ERROR_NO_DATA_TO_READ          101                                     // Error code for no date in receive queue of serial port
#define CLAW_ERROR_STEPPER_NOT_CONNECTED    200                                     // Error code for claw controller not connected to serial port
#define CLAW_ERROR_STEPPER_NOT_ENABLED      201                                     // Error code for claw controller stepper motor not connected
#define CLAW_ERROR_INCORRECT_RESPONSE       202                                     // Error code for incorrect response to command, specifically status command

NS_ASSUME_NONNULL_BEGIN

@interface clawControl : NSObject
{
    dispatch_semaphore_t serialPortSemaphore; //!< Semaphore for serial port access -- NOT IMPLEMENTED, Need to implement for threaded operation.
}

/**
    * @brief The status of the serial connection to the Claw controller
 */
@property BOOL connectionStatus;

/**
    * @brief The state of the stepper in the claw, Enabled = TRUE, Disabled = False
 */
@property BOOL clawStepperEnabled;

/**
    * @brief The path to the device descriptor in the /dev tree for the serial connection to the Claw controller
 */
@property (strong) NSString* devicePath;

/**
    * @brief Creates and NSerror with appropriate keys for Claw objects
    *
    * @param errorCode NSInteger error code for error
    * @param errorDescription NSString pointer to description of error
    * @param errorReason NSString pointer to the reason the error occured
    * @param errorSuggestion NSString pointer to a suggestion for the user to rectify the error
    * @return: returns NSError created or nil if failed to create error
 */
- (NSError*)setClawErrorWithCode:(NSInteger) errorCode
                  andDescription:(NSString*) errorDescription
                       andReason:(NSString*) errorReason
                   andSuggestion:(NSString*) errorSuggestion;

/**
    * @brief Sets device descriptior path to serial port
    *
    * @param pathToSet NSString pointer to device path of serial port
    * @param error pointer to NSError* on failure to set device path, nil otherwise
    * @return NSError if pathToSet parameter is nil
 */
- (BOOL)setDevicePathWith:(NSString*)pathToSet withError:(NSError**)error;

/**
    * @brief Connects the claw device to the serial port specified with setDevicePathWith:
    * 
    * Connects to device set with setDevicePathWith: method.  This also turns off echo on 
    * the firmware interface and clears the serial RX buffer.  This makes the claw device
    * firmware and connection ready to execute commands
    * 
    * @param error pointer to NSError* on failure to connect to the Device, nil otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)connectToSerialPortWithError:(NSError**)error;

/**
    * @brief Disconnects the claw device from the serial port if already connected
    * 
    * Disconnects from the claw serial port and frees the file handle
    *
    * @param error pointer to NSError* on failure to disconnect to the serial port of the claw device
    * @return returns NSError on failure to disconnect and free file handle
 */
- (BOOL)disconnectFromSerialPortWithError:(NSError**)error;

/**
    * @brief Sets claw device to enabled
    * 
    * Sets claw stepper motor to enabled and ready to move claw device
    * 
    * @param error pointer to NSError* on failure to enable the claw, nil otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)enableClawStepperWithError:(NSError**)error;

/**
    * @brief sets claw device to disabled
    * 
    * Sets claw stepper motor to disabled.  Disabling stepper will allow it to spin freely
    * 
    * @param error pointer to NSError* on failure to disable the claw, nil otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)disableClawStepperWithError:(NSError**)error;

/**
    * @brief sets claw position to parameter clawPosition (0 to 100)
    * 
    * Sets claw position based on clawPosition parameter to a value between 0 and 100
    * 
    * @param clawPosition NSInteger position 
    * @param error pointer to NSError* on failure set the claw position, nil otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)setClawPosition:(NSInteger) clawPosition withError:(NSError**)error;

/**
    * @brief stopps claw motion immediately, regardless of current position
    *
    * @param error pointer to NSError* on failure to send stop command, nill otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)stopClawMotionWithError:(NSError**)error;

/**
    * @brief reads status from claw device and returns dictionary of status
 
    * Status of claw device
    * key Current Position : current claw position in number of steps
    * key Target Position : target position of claw device in number of steps
    * key Step Period : microseconds per step pulse of claw stepper motor
    * key Moving : TRUE if claw is currently moving, FALSE otherwise
    * key Enabled : TRUE if claw is currently enabled, FALSE otherwise
    * key Estop : TRUE if claw E-Stop is currently pressed, FALSE otherwise
    *
    * @param error pointer to NSError* on failure to get status
    * @return NSDictionary pointer to dictionary of current status
    *
 */
- (NSDictionary*)readStatusToDictionaryWithError:(NSError**)error;

/**
    * @brief Set claw speed expressed as stepper period
    *
    * @note Claw speed is espressed as a period in microseconds
    *
    * Sets claw speed in microseconds per step.  Reasonable speeds are between 40µs and 400µs (25kHz to 2.5kHz)
    *
    * @param clawPeriod  microsecond period to set claw stepper motor pulse rate
    * @param error pointer to NSError* on failure to get status
    * @return NSDictionary pointer to dictionary of current status
 */
- (BOOL)setClawSpeed:(NSInteger)clawPeriod withError:(NSError**)error;

/**
    * @brief sets claw zero position to current position.  Used to calibrate zero on claw
    *
    * @param error pointer to NSError* on failure to send set zero command, nill otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)setClawZeroWithError:(NSError**)error;

/**
    * @brief bumps zero and moves stepper 1/4 turn below current zero to bump down zero set point
    *
    * @param error pointer to NSError* on failure to send bump down command, nill otherwise
    * @return EXIT_FAILURE on fail, EXIT_SUCCESS on success
 */
- (BOOL)bumpClawZeroDownWithError:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
