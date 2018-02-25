//
//  qrCodeOnScreen.m
//  ssrMac
//
//  Created by ssrlive on 1/25/18.
//  Copyright © 2018 ssrlive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

#import "qrCodeOnScreen.h"

@implementation qrCodeOnScreen

+ (NSArray<NSURL *> *) scan {
    // displays[] Quartz display ID's
    CGDirectDisplayID   *displays = nil;
    
    CGError             err = CGDisplayNoErr;
    CGDisplayCount      dspCount = 0;
    
    // How many active displays do we have?
    err = CGGetActiveDisplayList(0, NULL, &dspCount);
    
    // If we are getting an error here then their won't be much to display.
    if(err != CGDisplayNoErr) {
        NSLog(@"Could not get active display count (%d)\n", err);
        return nil;
    }
    
    // Allocate enough memory to hold all the display IDs we have.
    displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
    
    // Get the list of active displays
    err = CGGetActiveDisplayList(dspCount, displays, &dspCount);
    
    // More error-checking here.
    if (err != CGDisplayNoErr) {
        NSLog(@"Could not get active display list (%d)\n", err);
        return nil;
    }
    
    NSMutableArray* foundSSUrls = [NSMutableArray array];
    
    CIDetector *detector =
    [CIDetector detectorOfType:@"CIDetectorTypeQRCode"
                       context:nil
                       options:@{ CIDetectorAccuracy:CIDetectorAccuracyHigh }];
    
    for (unsigned int displaysIndex = 0; displaysIndex < dspCount; displaysIndex++) {
        // Make a snapshot image of the current display.
        CGImageRef image = CGDisplayCreateImage(displays[displaysIndex]);
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image]];
        for (CIQRCodeFeature *feature in features) {
            NSString *messageString = feature.messageString;
            NSLog(@"%@", messageString);
            if ([messageString hasPrefix:@"ss://"] || [messageString hasPrefix:@"ssr://"]) {
                NSURL *url = [NSURL URLWithString:messageString];
                if (url) {
                    [foundSSUrls addObject:url];
                }
            }
        }
        CGImageRelease(image);
    }

    free(displays);

    return foundSSUrls;
}

@end
