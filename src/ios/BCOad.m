//
//  BCOad.m
//  Created by Richie on 2014-6-8.
//

#import "BCIOad.h"

#define EVENT_NAME @"eventName"

@implementation BCIBeacon

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

-(void) makeConfigurationForProfile {
    if (!self.setupData) self.setupData = [[NSMutableDictionary alloc] init];
    // Append the UUID to make it easy for app
    [self.setupData setValue:@"0xF000FFC0-0451-4000-B000-000000000000" forKey:@"OAD Service UUID"];
    [self.setupData setValue:@"0xF000FFC1-0451-4000-B000-000000000000" forKey:@"OAD Image Notify UUID"];
    [self.setupData setValue:@"0xF000FFC2-0451-4000-B000-000000000000" forKey:@"OAD Image Block Request UUID"];
    NSLog(@"%@",self.setupData);
}

-(void) configureProfile {
    NSLog(@"Configurating OAD Profile");
    // CBUUID *sUUID = [CBUUID UUIDWithString:[self.setupData valueForKey:@"OAD Service UUID"]];
    // CBUUID *cUUID = [CBUUID UUIDWithString:[self.setupData valueForKey:@"OAD Image Notify UUID"]];
    // [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
    // unsigned char data = 0x00;
    // [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
    self.imageDetectTimer = [NSTimer scheduledTimerWithTimeInterval:1.5f target:self selector:@selector(imageDetectTimerTick:) userInfo:nil repeats:NO];
    self.imgVersion = 0xFFFF;
    self.start = YES;
}

-(void) deconfigureProfile {
    NSLog(@"Deconfiguring OAD Profile");
    // CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Service UUID"]];
    // CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Image Notify UUID"]];
    // [BLEUtility setNotificationForCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID enable:YES];
}

- (void) uploadImage:(CDVInvokedUrlCommand *)command{
    NSString* filename = [command.arguments objectAtIndex:0];
    self.imageFile = [NSData dataWithContentsOfFile:filename];

    self.inProgramming = YES;
    self.canceled = NO;

    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];
    uint8_t requestData[OAD_IMG_HDR_SIZE + 2 + 2]; // 12Bytes

    for(int ii = 0; ii < 20; ii++) {
        NSLog(@"%02hhx",imageFileData[ii]);
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

    // CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Service UUID"]];
    // CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Image Notify UUID"]];

    // [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:OAD_IMG_HDR_SIZE + 2 + 2]];

    self.nBlocks = imgHeader.len / (OAD_BLOCK_SIZE / HAL_FLASH_WORD_SIZE);
    self.nBytes = imgHeader.len * HAL_FLASH_WORD_SIZE;
    self.iBlocks = 0;
    self.iBytes = 0;

    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];

}

-(void) programmingTimerTick:(NSTimer *)timer {
    if (self.canceled) {
        self.canceled = FALSE;
        return;
    }

    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];

    //Prepare Block
    uint8_t requestData[2 + OAD_BLOCK_SIZE];

    // This block is run 4 times, this is needed to get CoreBluetooth to send consequetive packets in the same connection interval.
    for (int ii = 0; ii < 4; ii++) {

        requestData[0] = LO_UINT16(self.iBlocks);
        requestData[1] = HI_UINT16(self.iBlocks);

        memcpy(&requestData[2] , &imageFileData[self.iBytes], OAD_BLOCK_SIZE);

        // CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Service UUID"]];
        // CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Image Block Request UUID"]];

        // [BLEUtility writeNoResponseCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:requestData length:2 + OAD_BLOCK_SIZE]];

        self.iBlocks++;
        self.iBytes += OAD_BLOCK_SIZE;

        if(self.iBlocks == self.nBlocks) {
            self.inProgramming = NO;
            return;
        }
        else {
            if (ii == 3)[NSTimer scheduledTimerWithTimeInterval:0.09 target:self selector:@selector(programmingTimerTick:) userInfo:nil repeats:NO];
        }
    }

    float secondsPerBlock = 0.09 / 4;
    float secondsLeft = (float)(self.nBlocks - self.iBlocks) * secondsPerBlock;

}

-(void) didUpdateValueForProfile:(CBCharacteristic *)characteristic {
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Image Notify UUID"]]]) {
        if (self.imgVersion == 0xFFFF) {
            unsigned char data[characteristic.value.length];
            [characteristic.value getBytes:&data];
            self.imgVersion = ((uint16_t)data[1] << 8 & 0xff00) | ((uint16_t)data[0] & 0xff);
            NSLog(@"self.imgVersion : %04hx",self.imgVersion);
        }
        NSLog(@"OAD Image notify : %@",characteristic.value);

    }
}

-(NSMutableArray *) findFWFiles {
    NSMutableArray *FWFiles = [[NSMutableArray alloc]init];

    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *publicDocumentsDir = [paths objectAtIndex:0];

    NSError *error;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:publicDocumentsDir error:&error];


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
    if(files == nil){
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }else{
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:'exist'];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) validateImage:(CDVInvokedUrlCommand *)command{
    CDVPluginResult* pluginResult = nil;
    NSString* filename = [command.arguments objectAtIndex:0];
    self.imageFile = [NSData dataWithContentsOfFile:filename];
    NSLog(@"Loaded firmware \"%@\"of size : %d", filename, self.imageFile.length);
    if ([self isCorrectImage])
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:filename];
    else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

-(BOOL) isCorrectImage {
    unsigned char imageFileData[self.imageFile.length];
    [self.imageFile getBytes:imageFileData];

    img_hdr_t imgHeader;
    memcpy(&imgHeader, &imageFileData[0 + OAD_IMG_HDR_OSET], sizeof(img_hdr_t));

    if ((imgHeader.ver & 0x01) != (self.imgVersion & 0x01)) return YES;
    return NO;
}

-(void) imageDetectTimerTick:(NSTimer *)timer {
    //IF we have come here, the image userID is B.
    NSLog(@"imageDetectTimerTick:");
    CBUUID *sUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Service UUID"]];
    CBUUID *cUUID = [CBUUID UUIDWithString:[self.d.setupData valueForKey:@"OAD Image Notify UUID"]];
    unsigned char data = 0x01;
    NSLog(@" image detect timer ");
    // [BLEUtility writeCharacteristic:self.d.p sCBUUID:sUUID cCBUUID:cUUID data:[NSData dataWithBytes:&data length:1]];
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

- (NSString*)parseStringFromJS:(NSArray*)commandArguments keyFromJS:(NSString*)key{
    NSString *string = [NSString stringWithFormat:@"%@",[[commandArguments objectAtIndex:0] valueForKey:key]];
    return string;
}

@end
