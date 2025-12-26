//
//  clawControl.h
//  ClawGUI
//
//  Created by Jon Wade on 12/24/25.
//

#import <Foundation/Foundation.h>

#define CLAW_CONTROL_INVALID_PORT_PATH      100

#define CLAW_MAX_PERIOD                     400
#define CLAW_MIN_PERIOD                     40

NS_ASSUME_NONNULL_BEGIN

@interface clawControl : NSObject
{
    dispatch_semaphore_t serialPortSemaphore;
}

@property BOOL connectionStatus;
@property BOOL clawStepperEnabled;
@property NSString* devicePath;

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
