//
//  BCOad.h
//  Created by Richie on 2014-6-8.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Cordova/NSDictionary+Extensions.h>
#import <Cordova/NSArray+Comparisons.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/NSData+Base64.h>
#import <Cordova/CDVJSON.h>

#import "oad.h"
#define HI_UINT16(a) (((a) >> 8) & 0xff)
#define LO_UINT16(a) ((a) & 0xff)

@interface BCOad : CDVPlugin
{
    BOOL isVariableInit;
}

- (void)validateImage:(CDVInvokedUrlCommand*)command;
- (void)uploadImage:(CDVInvokedUrlCommand*)command;
- (void)getFWFiles:(CDVInvokedUrlCommand*)command;
- (void)setImageType:(CDVInvokedUrlCommand*)command;

@property (strong,nonatomic) NSData *imageFile;

@property int nBlocks;
@property int nBytes;
@property int iBlocks;
@property int iBytes;
@property BOOL canceled;
@property BOOL inProgramming;
@property BOOL start;
@property (nonatomic,retain) NSTimer *imageDetectTimer;
@property uint16_t imgVersion;

-(void) makeConfigurationForProfile;
-(void) configureProfile;
-(void) deconfigureProfile;

-(void) programmingTimerTick:(NSTimer *)timer;
-(void) imageDetectTimerTick:(NSTimer *)timer;

-(NSMutableArray *) findFWFiles;

-(BOOL) isCorrectImage;

@end

