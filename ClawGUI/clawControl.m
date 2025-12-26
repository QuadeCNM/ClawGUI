//
//  clawControl.m
//  ClawGUI
//
//  Created by Jon Wade on 12/24/25.
//

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

- (BOOL)setDevicePathWith:(NSString*)pathToSet withError:(NSError**)error
{

    
    if(pathToSet == nil)
    {
        NSDictionary *errorInfo = @{
            NSLocalizedDescriptionKey: NSLocalizedString(@"Invalid Serial Port Path.", nil),
            NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Serial port path not valid.", nil)
        };
        
        *error = [NSError errorWithDomain:@"clawControlDomain"
                                     code:CLAW_CONTROL_INVALID_PORT_PATH
                                 userInfo:errorInfo];
        
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
    
    if(myUART.uartFileHandle != 0)
        return NO;
    
    myUART.uartFileHandle = open(myUART.uartPath, O_RDWR | O_NOCTTY | O_SYNC);
    if (myUART.uartFileHandle == -1 )
    {
        printf("Error opening: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    
    if (ioctl(myUART.uartFileHandle, TIOCEXCL) == -1)
    {
        printf("Error ioctl(): %s\n", strerror(errno));
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
    
    if(tcgetattr(myUART.uartFileHandle, &(myUART.uartOptions)) != 0)
    {
        printf("Error %i from tcgetattr: %s\n", errno, strerror(errno));
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
    myUART.uartOptions.c_cc[VTIME] = 2; // Wait up to 0.5 seconds (5 * 0.1s)

    // Apply the settings
    if (tcsetattr(myUART.uartFileHandle, TCSANOW, &(myUART.uartOptions)) != 0) {
        printf("Error %i from tcsetattr: %s\n", errno, strerror(errno));
        // Handle error
    }
    
    sleep(1);

    // Flush Serial Port before write
    ioctl(myUART.uartFileHandle, TCIFLUSH);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    
    // set UART options to read at least 1 character
    myUART.uartOptions.c_cc[VMIN] = 1; // Read at least 1 character
    
    // Apply the settings
    if (tcsetattr(myUART.uartFileHandle, TCSANOW, &(myUART.uartOptions)) != 0) {
        printf("Error %i from tcsetattr: %s\n", errno, strerror(errno));
        // Handle error
    }
    
    
    printf("\n**Do echo off:\n");
    
    // Write to the serial port
    strcpy(sendBuffer, "echo off\n");
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        printf("Error writing: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    
    usleep(2000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
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
    
    return YES;
}

- (BOOL)enableClawStepperWithError:(NSError**)error
{
    
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_connectionStatus == TRUE)
    {
        printf("\n**Do enable_stepper:\n");
        
        // Write to the serial port
        strcpy(sendBuffer, "enable_stepper\n");
        num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
        tcdrain(myUART.uartFileHandle);
        if (num_bytes < 0)
        {
            printf("Error writing: %s\n", strerror(errno));
            close(myUART.uartFileHandle);
            return EXIT_FAILURE;
        }
        usleep(100000);
        
        // Read from the serial port
        num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
        if (num_bytes < 0)
        {
            printf("Error reading: %s\n", strerror(errno));
        }
        else
        {
            // Process the data in read_buf
            recieveBuffer[num_bytes] = 0; // make sure we are null terminated
            printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
        }
        
        _clawStepperEnabled = TRUE;
        
        return TRUE;
    }
    else
        return FALSE;
}

- (BOOL)disableClawStepperWithError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_connectionStatus == TRUE)
    {
        printf("\n**Do disable_stepper:\n");
        
        // Write to the serial port
        strcpy(sendBuffer, "disable_stepper\n");
        num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
        tcdrain(myUART.uartFileHandle);
        if (num_bytes < 0)
        {
            printf("Error writing: %s\n", strerror(errno));
            close(myUART.uartFileHandle);
            return EXIT_FAILURE;
        }
        
        usleep(100000);
        
        // Read from the serial port
        num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
        if (num_bytes < 0)
        {
            printf("Error reading: %s\n", strerror(errno));
        }
        else
        {
            // Process the data in read_buf
            recieveBuffer[num_bytes] = 0; // make sure we are null terminated
            printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
        }
        
        _clawStepperEnabled = FALSE;
        // do serial stuff to disable
        
        return TRUE;
    }
    else
        return FALSE;
}

- (BOOL)setClawPosition:(NSInteger) clawPosition withError:(NSError**)error
{
    char sendBuffer[100];
    char recieveBuffer[3000];
    int num_bytes;
    
    if(_clawStepperEnabled == FALSE)
    {
        return FALSE;
    }
    
    printf("\n**Do claw_set %d:\n", (int)clawPosition);

    // Write to the serial port
    strcpy(sendBuffer, [[NSString stringWithFormat:@"claw_set %ld\n", (long)clawPosition] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        printf("Error writing: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
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
        return FALSE;
    }
    
    printf("\n**Do stop_stepper\n");

    // Write to the serial port
    strcpy(sendBuffer, "stop_stepper\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        printf("Error writing: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
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
        return FALSE;
    }
    
    printf("\n**Do stop_stepper\n");

    // Write to the serial port
    strcpy(sendBuffer, "get_stepper_status\n");
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        printf("Error writing: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return FALSE;
    }
    // wait 100us for return value... probably a bit long but...
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    
    // Check to see if we have the correct command response
    if(!(strncmp(recieveBuffer, "Stepper Status", strlen("Stepper Status")) == 0))
    {
        // We didn't get the correct response so return error
        return FALSE;
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
        return FALSE;
    }
    
    printf("\n**Do set_stepper_period %d:\n", (int)clawPeriod);

    // Write to the serial port
    strcpy(sendBuffer, [[NSString stringWithFormat:@"set_stepper_period %ld\n", (long)clawPeriod] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    num_bytes = (int)write(myUART.uartFileHandle, sendBuffer, strlen(sendBuffer)); // Returns the number of bytes written
    tcdrain(myUART.uartFileHandle);
    if (num_bytes < 0)
    {
        printf("Error writing: %s\n", strerror(errno));
        close(myUART.uartFileHandle);
        return EXIT_FAILURE;
    }
    usleep(100000);
    
    // Read from the serial port
    num_bytes = (int)read(myUART.uartFileHandle, recieveBuffer, sizeof(recieveBuffer));
    if (num_bytes < 0)
    {
        printf("Error reading: %s\n", strerror(errno));
    }
    else
    {
        // Process the data in read_buf
        recieveBuffer[num_bytes] = 0; // make sure we are null terminated
        printf("Read %i bytes. Received data: \n%s\n", num_bytes, recieveBuffer);
    }
    return TRUE;
}

@end

NS_ASSUME_NONNULL_END
