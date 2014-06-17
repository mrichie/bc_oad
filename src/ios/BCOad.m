//
//  BCOad.m
//  Created by Richie on 2014-6-8.
//

#import "BCOad.h"

#define EVENT_NAME @"eventName"

@implementation BCOad

- (void)pluginInitialize{
    [super pluginInitialize];
    if (!isVariableInit) {
        [self variableInit];
    }
}

- (void)variableInit{
    isVariableInit = TRUE;
    self.canceled = FALSE;
    self.inProgramming = FALSE;
    self.start = YES;
}

- (void)addEventListener:(CDVInvokedUrlCommand *)command{
    if ([self existCommandArguments:command.arguments]) {
        NSString *eventName = [self parseStringFromJS:command.arguments keyFromJS:EVENT_NAME];
        [[NSUserDefaults standardUserDefaults] setValue:command.callbackId forKey:eventName];
    }else{
        CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void) uploadImage:(CDVInvokedUrlCommand *)command{
    CDVPluginResult* pluginResult = nil;

    NSString* filename = [[command.arguments objectAtIndex:0] valueForKey:@"filename"];

    NSString *fullPath = [self getFWImageFullPath:filename];

    self.imageFile = [NSData dataWithContentsOfFile:fullPath];

    self.inProgramming = YES;
    self.canceled = NO;

    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];
    uint8_t requestData[OAD_IMG_HDR_SIZE + 2 + 2]; // 12Bytes

    for(int ii = 0; ii < 20; ii++) {
        NSLog(@"%02hhx", imageFileData[ii]);
    }

    img_hdr_t imgHeader;
    memcpy(&imgHeader, &imageFileData[0 + OAD_IMG_HDR_OSET], sizeof(img_hdr_t));

    requestData[0] = LO_UINT16(imgHeader.ver);
    requestData[1] = HI_UINT16(imgHeader.ver);

    requestData[2] = LO_UINT16(imgHeader.len);
    requestData[3] = HI_UINT16(imgHeader.len);

    NSLog(@"Image version = %04hx, len = %04hx",imgHeader.ver,imgHeader.len);

    memcpy(requestData + 4, &imgHeader.uid, sizeof(imgHeader.uid));

    requestData[OAD_IMG_HDR_SIZE + 0] = LO_UINT16(12);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(12);

    requestData[OAD_IMG_HDR_SIZE + 2] = LO_UINT16(15);
    requestData[OAD_IMG_HDR_SIZE + 1] = HI_UINT16(15);

    NSData* jsdata = [NSData dataWithBytes:(const void *)requestData length:12];

    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:jsdata];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

    self.nBlocks = imgHeader.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE);
    self.nBytes = imgHeader.len * HAL_FLASH_WORD_SIZE;
    self.iBlocks = 0;
    self.iBytes = 0;

    NSMutableDictionary *myDictionary = [[NSMutableDictionary alloc] init];
    [myDictionary setObject:command forKey:@"command"];
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(programmingTimerTick:) userInfo:myDictionary repeats:NO];

}

-(void) programmingTimerTick:(NSTimer *)timer {
    if (self.canceled) {
        self.canceled = FALSE;
        return;
    }

    CDVPluginResult* pluginResult = nil;
    CDVInvokedUrlCommand *command = [[timer userInfo] objectForKey:@"command"];

    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];

    //Prepare Block
    uint8_t requestData[2 + OAD_BLOCK_SIZE];

    // This block is run 4 times, this is needed to get CoreBluetooth to send consequetive packets in the same connection interval.
    for (int ii = 0; ii < 4; ii++) {

        requestData[0] = LO_UINT16(self.iBlocks);
        requestData[1] = HI_UINT16(self.iBlocks);

        memcpy(&requestData[2] , &imageFileData[self.iBytes], OAD_BLOCK_SIZE);

        NSData* jsdata = [NSData dataWithBytes:(const void *)requestData length:18];

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArrayBuffer:jsdata];
        [pluginResult setKeepCallbackAsBool:TRUE];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

        self.iBlocks++;
        self.iBytes += OAD_BLOCK_SIZE;

        if(self.iBlocks == self.nBlocks) {
            self.inProgramming = NO;
        }
        else {
            NSMutableDictionary *myDictionary = [[NSMutableDictionary alloc] init];
            [myDictionary setObject:command forKey:@"command"];
            if (ii == 3)[NSTimer scheduledTimerWithTimeInterval:0.09 target:self selector:@selector(programmingTimerTick:) userInfo:myDictionary repeats:NO];
        }
    }

    float secondsPerBlock = 0.09 / 4;
    float secondsLeft = (float)(self.nBlocks - self.iBlocks) * secondsPerBlock;

    NSLog(@"secondsPerBlock : %f", secondsPerBlock);
    NSLog(@"secondsLeft: %f", secondsLeft);
    NSLog(@"inProgramming %hhd", self.inProgramming);

    NSString *progress = [NSString stringWithFormat:@"%0.1f%%",(float)((float)self.iBlocks / (float)self.nBlocks) * 100.0f];
    NSString *remaining = [NSString stringWithFormat:@"Time remaining : %d:%02d",(int)(secondsLeft / 60),(int)secondsLeft - (int)(secondsLeft / 60) * (int)60];
    NSLog(@"progress : %@", progress);
    NSLog(@"remaining: %@", remaining);

    NSMutableDictionary *jsDict = [[NSMutableDictionary alloc] init];
    [jsDict setValue:[NSNumber numberWithFloat:secondsLeft] forKey:@"secondsLeft"];
    [jsDict setValue:[NSNumber numberWithFloat:self.inProgramming] forKey:@"inProgramming"];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:jsDict];
    [pluginResult setKeepCallbackAsBool:TRUE];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

}

-(NSMutableArray *) findFWFiles {
    NSMutableArray *FWFiles = [[NSMutableArray alloc]init];

    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];

    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:publicDocumentsDir error:&error];

    NSLog(@"%@", files);
    if (files == nil) {
        NSLog(@"Could not find any firmware files ...");
        return FWFiles;
    }
    for (NSString *file in files) {
        if ([file.pathExtension compare:@"bin" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            NSString *fullPath = [publicDocumentsDir stringByAppendingPathComponent:file];
            [FWFiles addObject:fullPath];
        }
    }

    return FWFiles;
}

- (void) getFWFiles:(CDVInvokedUrlCommand *)command{
    CDVPluginResult* pluginResult = nil;
    NSMutableArray *files = [self findFWFiles];
    NSLog(@"%@", files);
    if([files count] == 0){
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"exist"];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) validateImage:(CDVInvokedUrlCommand *)command{
    CDVPluginResult* pluginResult = nil;
    NSString* filename = [[command.arguments objectAtIndex:0] valueForKey:@"filename"];
    NSLog(@"filename : %@", filename);

    NSString *fullPath = [self getFWImageFullPath:filename];

    self.imageFile = [NSData dataWithContentsOfFile:fullPath];
    NSLog(@"Loaded firmware \"%@\"of size : %lu", filename, (unsigned long)self.imageFile.length);
    if ([self isCorrectImage]){
        NSLog(@"correct image");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:filename];
    }
    else {
        NSLog(@"is not correct image");
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(BOOL) isCorrectImage {
    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];

    img_hdr_t imgHeader;
    memcpy(&imgHeader, &imageFileData[0 + OAD_IMG_HDR_OSET], sizeof(img_hdr_t));

    uint16_t version = 0xFFFF;
    NSLog(@"default img Version : %hu", version);
    NSLog(@"current img Version : %hu", self.imgVersion);
    if ((imgHeader.ver & 0x01) != (self.imgVersion & 0x01)) return YES;
    return NO;
}

-(void) setImageType:(CDVInvokedUrlCommand *)command{
    CDVPluginResult* pluginResult = nil;
    NSString *hexString = [[command.arguments objectAtIndex:0] valueForKey:@"imgType"];

    char const *chars = hexString.UTF8String;
    NSUInteger charCount = strlen(chars);
    if (charCount % 2 != 0) {
        return ;
    }
    NSUInteger byteCount = charCount / 2;
    uint8_t *bytes = malloc(byteCount);
    for (int i = 0; i < byteCount; ++i) {
        unsigned int value;
        sscanf(chars + i * 2, "%2x", &value);
        bytes[i] = value;
    }
    NSData *imgType = [NSData dataWithBytesNoCopy:bytes length:byteCount freeWhenDone:YES];

    NSLog(@"imgType : %@", imgType);

    unsigned char data[imgType.length];
    [imgType getBytes:&data];
    self.imgVersion = ((uint16_t)data[1] << 8 & 0xff00) | ((uint16_t)data[0] & 0xff);
    NSLog(@"img Version : %hu", self.imgVersion);
    NSLog(@"version type : %d", (self.imgVersion & 0x01));
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

# pragma mark -
# pragma mark MISC
# pragma mark -

- (BOOL)existCommandArguments:(NSArray*)comArguments{
    NSMutableArray *commandArguments=[[NSMutableArray alloc] initWithArray:comArguments];
    if (commandArguments.count > 0) {
        return TRUE;
    }else{
        return FALSE;
    }
}

- (NSString*)getBase64EncodedFromData:(NSData*)data{
    NSData *newData = [[NSData alloc] initWithData:data];
    NSString *value = [newData base64EncodedString];
    return value;
}

- (BOOL)isNormalString:(NSString*)string{
    if (![string isEqualToString:@"(null)"] && ![string isEqualToString:@"null"] && string.length > 0){
        return TRUE;
    }else{
        return FALSE;
    }
}

- (NSString*)getFWImageFullPath:(NSString*)filename{
    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];
    NSString *fullPath = [publicDocumentsDir stringByAppendingPathComponent:filename];
    return fullPath;
}

- (NSString*)parseStringFromJS:(NSArray*)commandArguments keyFromJS:(NSString*)key{
    NSString *string = [NSString stringWithFormat:@"%@",[[commandArguments objectAtIndex:0] valueForKey:key]];
    return string;
}

@end
