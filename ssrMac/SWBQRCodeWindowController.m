//
//  QRCodeWindowController.m
//  shadowsocks
//
//  Created by clowwindy on 10/12/14.
//  Copyright (c) 2014 clowwindy. All rights reserved.
//

#import "SWBQRCodeWindowController.h"

@interface SWBQRCodeWindowController () <WebFrameLoadDelegate>

@end

@implementation SWBQRCodeWindowController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.webView.mainFrame loadRequest:[NSURLRequest requestWithURL:[[NSBundle mainBundle] URLForResource:@"qrcode" withExtension:@"htm"]]];
    self.webView.frameLoadDelegate = self;
}

-(void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame {
    if (self.qrCode) {
        [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"genCode('%@')", _qrCode]];
    }
}

+ (NSImage *) generateImageFromWebView:(WebView *)webView size:(NSSize)size {
    NSView *webFrameViewDocView = [[[webView mainFrame] frameView] documentView];
    NSRect cacheRect = [webFrameViewDocView bounds];
    
    NSBitmapImageRep *bitmapRep = [webFrameViewDocView bitmapImageRepForCachingDisplayInRect:cacheRect];
    [webFrameViewDocView cacheDisplayInRect:cacheRect toBitmapImageRep:bitmapRep];
    
    NSSize imgSize = cacheRect.size;
    if (imgSize.height > imgSize.width) {
        imgSize.height = imgSize.width;
    }
    
    NSRect srcRect = NSZeroRect;
    srcRect.size = imgSize;
    srcRect.origin.y = cacheRect.size.height - imgSize.height;
    
    NSRect destRect = NSZeroRect;
    destRect.size = imgSize;
    
    NSImage *webImage = [[NSImage alloc] initWithSize:imgSize];
    [webImage lockFocus];
    [bitmapRep drawInRect:destRect
                 fromRect:srcRect
                operation:NSCompositeCopy
                 fraction:1.0
           respectFlipped:YES
                    hints:nil];
    [webImage unlockFocus];
    
    NSSize defaultDisplaySize;
    defaultDisplaySize.height = size.height * (imgSize.height / imgSize.width);
    defaultDisplaySize.width = size.width;
    [webImage setSize:defaultDisplaySize];
    
    return webImage;
}

- (IBAction)copyToPasteboardClicked:(NSButton *)sender {
    // Then copy _qrCode and image to pasteboard
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    NSImage *image = [[self class] generateImageFromWebView:_webView size:NSMakeSize(256., 256.)];
    [pasteboard writeObjects:@[_qrCode, image]];
}

-(void)dealloc {
    self.webView.frameLoadDelegate = nil;
}

@end
