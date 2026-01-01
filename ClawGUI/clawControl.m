/**
    * @file clawControl.c
    * @author Jon Wade
    * @date  24 Dec 2025
    * @copyright (c) 2025 Jon Wade. Standard MIT License applies. See LICENSE file.
    *
    * @brief implimentation of claw class
    *
    * This file contains the implimentation of the class for controlling claw over the serial port including connecting and
    * disconnecting the serial port.
*/

#import "clawControl.h"
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/fcntl.h>

NS_ASSUME_NONNULL_BEGIN

@implementation clawControl

typedef struct UART
{
    int     uartFileHandle;
    char*   uartPath;
    int     uartBaud;
    int     uartParity;
    int     uartStopBits;
    int     uartByteSize;
    struct  termios uartOptions;
} UART_t;

UART_t myUART;

- (NSError*)setClawErrorWithCode:(NSInteger) errorCode
                  andDescription:(NSString*) errorDescription
                       andReason:(NSString*) errorReason
                   andSuggestion:(NSString*) errorSuggestion
{
    // create and allocate dictionary for error
    NSDictionary *errorInfo = [[NSMutableDictionary alloc] init];
    
    // Add keys to dictionary for NSError
    [errorInfo setValue:errorDescription forKey:NSLocalizedDescriptionKey];
    [errorInfo setValue:errorReason forKey:NSLocalizedFailureReasonErrorKey];
    [errorInfo setValue:errorSuggestion forKey:NSLocalizedRecoverySuggestionErrorKey];
    
    // Create NSError with appropriate domain, error code, and userInfo dictionary
    return [NSError errorWithDomain:CLAW_ERROR_DOMAIN
                               code:errorCode
                           userInfo:errorInfo];
}


- (BOOL)setDevicePathWith:(NSString*)pathToSet withError:(NSError**)error
{

    
    if(pathToSet == nil)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_INVALID_PORT_PATH
                             andDescription:@"Invalid Serial Port Path."
                                  andReason:@"Serial port path not defined."
                              andSuggestion:@"Serial Port Path not defined, please verify device name"];
        
        return NO;
    }
    
    myUART.uartPath = (char*)[pathToSet cStringUsingEncoding:NSUTF8StringEncoding];
    myUART.uartFileHandle = 0;
    
    _connectionStatus = FALSE;
    
    return YES;
    
}

- (BOOL)connectToSerialPortWithError:(NSError**)error;
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    // check to make sure file handle is initialized
    if(myUART.uartFileHandle != 0)
        return EXIT_FAILURE;
    
    // Open serial port device descriptor
    myUART.uartFileHandle = open(myUART.uartPath, O_RDWR | O_NOCTTY | O_SYNC);
    if (myUART.uartFileHandle == -1 )
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error opening Serial Port: %s", strerror(errno)]
                                  andReason:@"open() failed"
                              andSuggestion:@"Check permisions to serial port and if application can open serial ports"];
        
        NSLog(@"Error opening: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    
    // Apply IO Control to file handle
    if (ioctl(myUART.uartFileHandle, TIOCEXCL) == -1)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error setting control bits to serial port: %s", strerror(errno)]
                                  andReason:@"ioctl() failed"
                              andSuggestion:@"Check permisions to serial port and if application can control serial ports"];
        NSLog(@"Error ioctl(): %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    
    // Ensure Nonblocking operation
    /*if (fcntl(myUART.uartFileHandle, F_SETFL, FNDELAY) == -1)
    {
        printf("Error fcntl(): %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }*/
    
    // get UART attributes
    if(tcgetattr(myUART.uartFileHandle, &(myUART.uartOptions)) != 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading control bits of serial port: %s", strerror(errno)]
                                  andReason:@"tcgetattr() failed"
                              andSuggestion:@"Check permisions to serial port and if application can control serial ports"];
        NSLog(@"Error %i from tcgetattr: %s\n", errno, strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
        
    }
    
    cfsetospeed(&(myUART.uartOptions), B115200);
    cfsetispeed(&(myUART.uartOptions), B115200);
    
    myUART.uartOptions.c_cflag |= (CLOCAL | CREAD);
    myUART.uartOptions.c_cflag &= ~PARENB; // No parity bit
    myUART.uartOptions.c_cflag &= ~CSTOPB; // 1 stop bit
    myUART.uartOptions.c_cflag &= ~CSIZE;
    myUART.uartOptions.c_cflag |= CS8; // 8 bits per byte
    //myUART.uartOptions.c_cflag &= ~CRTSCTS; // Disable hardware flow control

    //myUART.uartOptions.c_cflag &= ~(IXON | IXOFF | IXANY); // Disable software flow control
    //myUART.uartOptions.c_cflag &= ~IGNBRK; // Disable break processing

    //myUART.uartOptions.c_cflag &= ~ICANON; // Disable canonical mode (line-by-line input)
    myUART.uartOptions.c_cflag &= ~ECHO; // Disable echo
    myUART.uartOptions.c_cflag &= ~ECHOE;
    myUART.uartOptions.c_cflag &= ~ECHONL;
    myUART.uartOptions.c_cflag &= ~ISIG; // Disable interpretation of signal characters

    // Set minimum number of characters for a read and the timeout
    myUART.uartOptions.c_cc[VMIN] = 0; // Read at least 1 character
    myUART.uartOptions.c_cc[VTIME] = 2; // Wait up to 0.2 seconds (2 * 0.1s)

    // Apply the settings
    if (tcsetattr(myUART.uartFileHandle, TCSANOW, &(myUART.uartOptions)) != 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing control bits of serial port: %s", strerror(errno)]
                                  andReason:@"tcsetattr() failed"
                              andSuggestion:@"Check permisions to serial port and if application can control serial ports"];
        close(myUART.uartFileHandle);
        NSLog(@"Error %i from tcsetattr: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    
    // Wait for one second after applying settings to continue
    sleep(1);

    // Flush Serial Port before write
    // Don't check for errors since flush may or may not succeed depending
    // on the fact that there may or may not be bytes in the buffer
    ioctl(myUART.uartFileHandle, TCIFLUSH);
    
    // Read from the serial port
    // This should be a blocking read
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        NSLog(@"Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    
    // set UART options to read at least 1 character
    myUART.uartOptions.c_cc[VMIN] = 1; // Read at least 1 character
    
    // Apply the settings
    if (tcsetattr(myUART.uartFileHandle, TCSANOW, &(myUART.uartOptions)) != 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing control bits of serial port: %s", strerror(errno)]
                                  andReason:@"tcsetattr() failed"
                              andSuggestion:@"Check permisions to serial port and if application can control serial ports"];
        close(myUART.uartFileHandle);
        NSLog(@"Error %i from tcsetattr: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    
    // Turn echo off, this makes it easier to do UART stuff if echo is off in firmware
    NSLog(@"\n**Do echo off:\n");
    
    // Write to the serial port
    strcpy(sendBuffer, "echo off\n");
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        close(myUART.uartFileHandle);
        NSLog(@"Error %i from write: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    
    // wait for 5ms for firmware to respond
    usleep(5000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        close(myUART.uartFileHandle);
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    
    _connectionStatus = TRUE;
    
    return YES;
}

- (BOOL)disconnectFromSerialPortWithError:(NSError**)error;
{
    
    // flush UART before close
    ioctl(myUART.uartFileHandle, TCIFLUSH);
    
    close(myUART.uartFileHandle);
    
    _connectionStatus = FALSE;
    
    myUART.uartFileHandle = 0;
    
    // At present there are no errors to throw.  Assume ioctl() and close()
    // succeed.  Flushing file handle may or may not throw error, but it has
    // no real effect.  Throwing an error on close has no real recourse.
    *error = nil;
    
    return YES;
}

- (BOOL)enableClawStepperWithError:(NSError**)error
{
    
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_connectionStatus == TRUE)
    {
        NSLog(@"\n**Do enable_stepper:\n");
        
        // Write to the serial port
        strcpy(sendBuffer, "enable_stepper\n");
        num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
        tcdrain(myUART.uartFileHandle);
        if (num_bytes < 0)
        {
            *error = [self setClawErrorWithCode:errno
                                 andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                      andReason:@"write() failed"
                                  andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
            NSLog(@"Error %i from write: %s\n", errno, strerror(errno));
            return EXIT_FAILURE;
        }
        usleep(100000);
        
        // Read from the serial port
        num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
        if (num_bytes < 0)
        {
            *error = [self setClawErrorWithCode:errno
                                 andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                      andReason:@"read() failed"
                                  andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
            NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
            return EXIT_FAILURE;
        }
        else
        {
            // Process the data in read_buf
            recieveBuffer[num_bytes] = 0; // make sure we are null terminated
            NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
        }
        
        _clawStepperEnabled = TRUE;
        
        *error = nil;
        return EXIT_SUCCESS;
    }
    else
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Enabling Claw"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return EXIT_FAILURE;
    }
}

- (BOOL)disableClawStepperWithError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_connectionStatus == TRUE)
    {
        NSLog(@"\n**Do disable_stepper:\n");
        
        // Write to the serial port
        strcpy(sendBuffer, "disable_stepper\n");
        num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
        tcdrain(myUART.uartFileHandle);
        if (num_bytes < 0)
        {
            *error = [self setClawErrorWithCode:errno
                                 andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                      andReason:@"write() failed"
                                  andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
            NSLog(@"Error writing: %s\n", strerror(errno));
            return EXIT_FAILURE;
        }
        
        usleep(100000);
        
        // Read from the serial port
        num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
        if (num_bytes < 0)
        {
            *error = [self setClawErrorWithCode:errno
                                 andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                      andReason:@"read() failed"
                                  andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
            NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
            return EXIT_FAILURE;
        }
        else
        {
            // Process the data in read_buf
            recieveBuffer[num_bytes] = 0; // make sure we are null terminated
            NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
        }
        
        _clawStepperEnabled = FALSE;
        // do serial stuff to disable
        
        return EXIT_SUCCESS;
    }
    else
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Disabling Claw"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return EXIT_FAILURE;
    }
}

- (BOOL)setClawPosition:(NSInteger) clawPosition withError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_ENABLED
                             andDescription:@"Claw Stepper Not Enabled"
                                  andReason:@"Claw Stepper Not Enabled"
                              andSuggestion:@"Please Enable Claw Stepper"];
        
        NSLog(@"Claw Not Enabled, Please enable claw before trying to set claw position\n");
        return EXIT_FAILURE;
    }
    
    NSLog(@"\n**Do claw_set %d:\n", (int)clawPosition);

    // Write to the serial port
    strcpy(sendBuffer, [[NSString stringWithFormat:@"claw_set %ld\n", (long)clawPosition] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
}

- (BOOL)stopClawMotionWithError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_ENABLED
                             andDescription:@"Claw Stepper Not Enabled"
                                  andReason:@"Claw Stepper Not Enabled"
                              andSuggestion:@"Please Enable Claw Stepper"];
        
        NSLog(@"Claw Not Enabled, Please enable claw before trying to stop claw\n");
        return EXIT_FAILURE;
    }
    
    NSLog(@"\n**Do stop_stepper\n");

    // Write to the serial port
    strcpy(sendBuffer, "stop_stepper\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
    
}

- (NSDictionary*)readStatusToDictionaryWithError:(NSError**)error;
{
    NSMutableDictionary* tempStatus;
    char* statusString;
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_connectionStatus == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Enabling Claw"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return nil;
    }
    
    NSLog(@"\n**Do stop_stepper\n");

    // Write to the serial port
    strcpy(sendBuffer, "get_stepper_status\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        
        // return nil to indicate failure
        return nil;
    }
    // wait 100us for return value... probably a bit long but...
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        
        // return nil to indicate failure
        return nil;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    
    // Check to see if we have the correct command response
    if(!(strncmp(recieveBuffer, "Stepper Status", strlen("Stepper Status")) == 0))
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_INCORRECT_RESPONSE
                             andDescription:@"Claw did not respond properly to command"
                                  andReason:@"Claw did not respond properly to command"
                              andSuggestion:@"is Claw FW up to date?"];
        
        // return nil to indicate failure
        return nil;
    }
    
    // build the dictionary
    tempStatus = [[NSMutableDictionary alloc] init];
    
    // Search for current position
    statusString = strnstr(recieveBuffer, "Current Position:", num_bytes);
    if(statusString != nil)
    {
        NSNumber* value = [NSNumber numberWithInt:(atoi(&statusString[strlen("Current Position: ")]))];
        [tempStatus setValue:value
                      forKey:@"Current Position"];
    }
    
    // Search for target position
    statusString = strnstr(recieveBuffer, "Target Position:", num_bytes);
    if(statusString != nil)
    {
        NSNumber* value = [NSNumber numberWithInt:(atoi(&statusString[strlen("Target Position: ")]))];
        [tempStatus setValue:value
                      forKey:@"Target Position"];
    }
    
    // Search for Step Period
    statusString = strnstr(recieveBuffer, "Step Period (us):", num_bytes);
    if(statusString != nil)
    {
        NSNumber* value = [NSNumber numberWithInt:(atoi(&statusString[strlen("Step Period (us): ")]))];
        [tempStatus setValue:value
                      forKey:@"Step Period"];
    }
    // Search for Moving
    statusString = strnstr(recieveBuffer, "Moving:", num_bytes);
    if(statusString != nil)
    {
        // create BOOL value
        NSNumber* value;
        if(strncmp(&statusString[strlen("Moving: ")], "Yes", strlen("Yes")) == 0)
            value = [NSNumber numberWithBool:TRUE];
        else
            value = [NSNumber numberWithBool:FALSE];
            
        [tempStatus setValue:value
                      forKey:@"Moving"];
    }
    // Search for Enabled
    statusString = strnstr(recieveBuffer, "Enabled:", num_bytes);
    if(statusString != nil)
    {
        // create BOOL value
        NSNumber* value;
        if(strncmp(&statusString[strlen("Enabled: ")], "Yes", strlen("Yes")) == 0)
            value = [NSNumber numberWithBool:TRUE];
        else
            value = [NSNumber numberWithBool:FALSE];
            
        [tempStatus setValue:value
                      forKey:@"Enabled"];
    }
    // Search for Enabled
    statusString = strnstr(recieveBuffer, "Estop:", num_bytes);
    if(statusString != nil)
    {
        // create BOOL value
        NSNumber* value;
        if(strncmp(&statusString[strlen("Estop: ")], "Active", strlen("Active")) == 0)
            value = [NSNumber numberWithBool:TRUE];
        else
            value = [NSNumber numberWithBool:FALSE];
            
        [tempStatus setValue:value
                      forKey:@"EStop"];
    }
    
    // copy the temp dictionary to a non-mutable dictionary
    return [tempStatus copy];
}

- (BOOL)setClawSpeed:(NSInteger)clawPeriod withError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Setting Claw Speed"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return EXIT_FAILURE;
    }
    
    NSLog(@"\n**Do set_stepper_period %d:\n", (int)clawPeriod);

    // Write to the serial port
    strcpy(sendBuffer, [[NSString stringWithFormat:@"set_stepper_period %ld\n", (long)clawPeriod] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
}

- (BOOL)setClawZeroWithError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Setting Claw Zero"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return EXIT_FAILURE;
    }
    
    NSLog(@"\n**Do set_stepper_zero:\n");

    // Write to the serial port
    strcpy(sendBuffer, "set_stepper_zero\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
}

- (BOOL)bumpClawZeroDownWithError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        *error = [self setClawErrorWithCode:CLAW_ERROR_STEPPER_NOT_CONNECTED
                             andDescription:@"Claw Serial Interface Not Connected"
                                  andReason:@"Claw Serial Interface Not Connected"
                              andSuggestion:@"Please Connect Claw Serial Interface Before Bumping Claw Down"];
        
        NSLog(@"Claw Serial Interface Not Connected, please connect serial interface first\n");
        return EXIT_FAILURE;
    }
    
    NSLog(@"\n**Do move_stepper_bump_down:\n");

    // Write to the serial port
    strcpy(sendBuffer, "move_stepper_bump_down\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error writing to serial port: %s", strerror(errno)]
                                  andReason:@"write() failed"
                              andSuggestion:@"Check permisions to serial port and if application can write to serial ports"];
        NSLog(@"Error writing: %s\n", strerror(errno));
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        *error = [self setClawErrorWithCode:errno
                             andDescription:[NSString stringWithFormat:@"Error reading from serial port: %s", strerror(errno)]
                                  andReason:@"read() failed"
                              andSuggestion:@"Check permisions to serial port and if application can read from serial ports"];
        NSLog(@"Error %i from read: %s\n", errno, strerror(errno));
        return EXIT_FAILURE;
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        NSLog(@"Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
}

@end

NS_ASSUME_NONNULL_END
