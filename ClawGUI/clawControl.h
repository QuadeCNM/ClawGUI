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


#define CLAW_MAX_PERIOD                     400
#define CLAW_MIN_PERIOD                     40

#define CLAW_ERROR_DOMAIN                   @"com.jon-wade.ClawGUI.SerialError"
#define CLAW_ERROR_INVALID_PORT_PATH        100
#define CLAW_ERROR_NO_DATA_TO_READ          101
#define CLAW_ERROR_STEPPER_NOT_CONNECTED    200
#define CLAW_ERROR_STEPPER_NOT_ENABLED      201
#define CLAW_ERROR_INCORRECT_RESPONSE       202

NS_ASSUME_NONNULL_BEGIN

@interface clawControl : NSObject
{
    dispatch_semaphore_t serialPortSemaphore;
}

@property BOOL connectionStatus;
@property BOOL clawStepperEnabled;
@property NSString* devicePath;

- (NSError*)setClawErrorWithCode:(NSInteger) errorCode
                  andDescription:(NSString*) errorDescription
                       andReason:(NSString*) errorReason
                   andSuggestion:(NSString*) errorSuggestion;

- (BOOL)setDevicePathWith:(NSString*)pathToSet withError:(NSError**)error;
- (BOOL)connectToSerialPortWithError:(NSError**)error;
- (BOOL)disconnectFromSerialPortWithError:(NSError**)error;
- (BOOL)enableClawStepperWithError:(NSError**)error;
- (BOOL)disableClawStepperWithError:(NSError**)error;
- (BOOL)setClawPosition:(NSInteger) clawPosition withError:(NSError**)error;
- (BOOL)stopClawMotionWithError:(NSError**)error;
- (NSDictionary*)readStatusToDictionaryWithError:(NSError**)error;
- (BOOL)setClawSpeed:(NSInteger)clawPeriod withError:(NSError**)error;
- (BOOL)setClawZeroWithError:(NSError**)error;
- (BOOL)bumpClawZeroDownWithError:(NSError**)error;

@end

NS_ASSUME_NONNULL_END
