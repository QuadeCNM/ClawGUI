//
//  AppDelegate.h
//  ClawGUI
//
//  Created by Jon Wade on 12/23/25.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

{
    dispatch_semaphore_t serialSem;
}


- (IBAction)connectButtonPressed:(id)sender;

- (IBAction)enableButtonPressed:(id)sender;

- (IBAction)PositionSliderMoved:(id)sender;

- (IBAction)stopClawButtonPressed:(id)sender;

- (IBAction)readStatusButtonPressed:(id)sender;

- (IBAction)speedSliderMoved:(id)sender;

- (IBAction)enableCalibrationButtonPressed:(id)sender;

- (IBAction)setOriginButtonPressed:(id)sender;

- (IBAction)BumpOriginDownButtonPressed:(id)sender;

@end

