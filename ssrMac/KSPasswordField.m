//
//  KSPasswordField.m
//  Sandvox
//
//  Created by Mike Abdullah on 28/04/2012.
//  Copyright (c) 2012-2014 Karelia Software. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "KSPasswordField.h"
//#import "NSData+Karelia.h"

#define YOFFSET 2
#define STRENGTH_INSET 4


static NSArray *sStrengthDescriptions = nil;
static NSSet *sPasswordBlacklist = nil;         // Worst ones
static NSUInteger sMaxStrengthDescriptionWidth = 0;

NSString *MyControlDidBecomeFirstResponderNotification = @"MyControlDidBecomeFirstResponderNotification";

void drawMeter(NSRect bounds, float strength, NSUInteger width)
{
    NSColor *red    = [NSColor colorWithCalibratedHue:1.0 saturation:1.000 brightness:0.9 alpha:1.000];
    NSColor *yellow = [NSColor colorWithCalibratedHue:0.130 saturation:1.0 brightness:1.0 alpha:1.000];
    NSColor *green  = [NSColor colorWithCalibratedHue:0.283 saturation:0.7 brightness:0.9 alpha:1.000];
    NSColor *gray   = [NSColor colorWithCalibratedHue:0.672 saturation:0.06 brightness:0.9 alpha:1.000];   // slight blue tinge
    
    CGFloat endRed, startYellow, endYellow, startGreen;
    
    // https://www.desmos.com/calculator/xqjscbu76v
    
    // We want all red up to 1.0 until about strength 0.3, then start bringing in yellow.
    // At strength 1.0, red is just until 0.05
    endRed      = MAX(0.0,  MIN(1.0, 0.05 - 1.4 * (strength-1)));
    startYellow =           MIN(1.0, endRed + 0.05);        // next color comes 5% after color change
    
    // We want to have yellow until about 0.7, then start bringing in green.
    // At strength 1.0, yellow is just until 0.15
    endYellow   = MAX(0.0,  MIN(1.0, 0.15 - 2.7 * (strength-1)));
    startGreen  =           MIN(1.0, endYellow + 0.05);     // next color comes 5% after color change
    
    //    NSLog(@"Strength %.2f gives us colors at %.2f and %.2f", strength, endRed, endYellow);
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
                            red, 0.0,
                            red, endRed,
                            yellow, startYellow,
                            yellow, endYellow,
                            green, startGreen,
                            green, 1.0, nil];
    
    NSRect rectToUse = bounds;
    rectToUse = NSInsetRect(rectToUse, 1.0, 1.0);
    rectToUse.size.height = 4;

    [NSGraphicsContext saveGraphicsState];
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositePlusDarker];

    // Gray background
    [gray set];
    [NSBezierPath fillRect:rectToUse];
    
    // Now the show the meter
    CGFloat cappedWidth = MIN(rectToUse.size.width, width);
    rectToUse.size.width = cappedWidth;
    [gradient drawInRect:rectToUse angle:0.0];  // not enough room for rounded rect

    [NSGraphicsContext restoreGraphicsState];
}

void drawDescriptionOfStrength(NSRect cellFrame, float strength, NSString *descriptionOfStrength)
{
    NSColor *red    = [NSColor colorWithCalibratedHue:1.0 saturation:1.000 brightness:0.7 alpha:1.000];
    NSColor *yellow = [NSColor colorWithCalibratedHue:0.130 saturation:1.0 brightness:0.7 alpha:1.000];     // Less bright than meter color!
    NSColor *green  = [NSColor colorWithCalibratedHue:0.283 saturation:0.7 brightness:0.8 alpha:1.000];

    NSColor *textColor = strength < 0.4 ? red : (strength > 0.70 ? green : yellow);
    [textColor set];
    
    NSMutableParagraphStyle* rightStyle = [[NSMutableParagraphStyle alloc] init];
	[rightStyle setAlignment:NSRightTextAlignment];
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
            textColor, NSForegroundColorAttributeName,
            rightStyle,NSParagraphStyleAttributeName,
            nil];
    
    NSRect descRect = cellFrame;
    
    descRect = NSInsetRect(descRect, STRENGTH_INSET, 0.0);
    descRect.origin.y += 8;
    
    [descriptionOfStrength drawInRect:descRect withAttributes:attr];
}

void drawMatch(NSRect cellFrame, MATCHING matching)
{
    if (matching == HIDE_MATCH) return;

    NSColor *fillColor = nil;

    CGFloat w = 8.0;
    NSUInteger y = NSMaxY(cellFrame) - 15;
    NSRect drawFrame = NSMakeRect(NSMaxX(cellFrame)-w-6, y, w, w);

    switch (matching) {
        case PARTIAL_MATCH: fillColor = [NSColor yellowColor]; break;
        case DOESNT_MATCH: fillColor = [NSColor redColor]; break;
        default: break;
    }

    if (fillColor)
    {
        NSBezierPath *fillPath = [NSBezierPath bezierPathWithOvalInRect:drawFrame];
        NSGradient *fillGradient = [[NSGradient alloc] initWithStartingColor:[fillColor highlightWithLevel:0.15]
                                                                  endingColor:[fillColor shadowWithLevel:0.15]];
        [fillGradient drawInBezierPath:fillPath angle:90.0];

        NSBezierPath *strokePath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(drawFrame, -0.5, -0.5)];
        [[fillColor shadowWithLevel:0.25] set];
        [strokePath stroke];
    }
    if (matching == FULL_MATCH)
    {
        NSImage *checkmark = [NSImage imageNamed:@"checkmark"];             // This image resource should be in the app
        NSRect checkmarkFrame = NSMakeRect(NSMaxX(cellFrame)-16-4,3,16,16);
        [checkmark drawInRect:checkmarkFrame fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:1.0 respectFlipped:YES hints:nil];
    }
}

NSRect drawAdornments(NSRect cellFrame, NSView *controlView)
{
    // When editing, use field editor, not string accessors, to avoid rending problems
    NSTextView *fieldEditor = (NSTextView *)[controlView.window fieldEditor:NO forObject:controlView];  // actuall NSSecureTextView (undocumented)
    if ([controlView.window firstResponder] != fieldEditor || fieldEditor.delegate != (id)controlView) fieldEditor = nil;

    KSPasswordField *passwordField = (KSPasswordField *)controlView;
    NSString *stringValue = fieldEditor ? [fieldEditor string] : [passwordField stringValue];
    NSAttributedString *attribStringValue = fieldEditor ? [fieldEditor textStorage] : [passwordField attributedStringValue];
    
	NSRect result = cellFrame;
    NSUInteger strlength = [stringValue length];
    if (passwordField.showStrength)
    {
        NSRect r = NSZeroRect;
        if (passwordField.showsText)
        {
            r = [attribStringValue boundingRectWithSize:[controlView bounds].size options:0];
        }
        else    // get width of bullets
        {
            if (strlength)
            {
                NSDictionary *attr = [attribStringValue attributesAtIndex:0 effectiveRange:nil];
                NSAttributedString *oneBullet = [[NSAttributedString alloc] initWithString:@"•" attributes:attr];
                r = [oneBullet boundingRectWithSize:[controlView bounds].size options:0];
                r.size.width *= strlength;
            }
        }
        if (r.size.width) r.size.width += 5;      // extra to compensate for margin starting to left of actual text
        
        drawMeter(cellFrame, passwordField.strength, r.size.width);
        drawDescriptionOfStrength(cellFrame, passwordField.strength, passwordField.descriptionOfStrength);

        result.origin.y += YOFFSET;
        result.size.height -= YOFFSET;

    }    
    // For the main field, if there is a string not long enough, also show the not-matching indicator to indicate a problem to fix
    MATCHING matchingToShow = passwordField.matching;
    if (!passwordField.showMatchIndicator) {
        matchingToShow = HIDE_MATCH;
    } else if (strlength > 0 && strlength < 8) {
        matchingToShow = DOESNT_MATCH;
    }
    drawMatch(result, matchingToShow);
    
    return result;
}

@interface NSObject(controlDidBecomeFirstResponder)
- (void) controlDidBecomeFirstResponder:(NSNotification *)aNotification;
@end


@implementation KSPasswordTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    cellFrame = drawAdornments(cellFrame, controlView);
    cellFrame.origin.y -= 1;
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSRect)drawingRectForBounds:(NSRect)aRect
{
    NSRect result = [super drawingRectForBounds:aRect];
    KSPasswordField *field = (KSPasswordField *)[self controlView];

    if ([field showStrength])
    {
        result.origin.y += YOFFSET;
        result.size.height -= YOFFSET;
        result.size.width -= (sMaxStrengthDescriptionWidth + STRENGTH_INSET);	// leave room for drawing strength description
    }
    else if ([field showMatchIndicator])
    {
        result.size.width -= (16 + 2);	// leave room for drawing indicator
    }

    return result;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    NSRect result = aRect;
    if ([((KSPasswordField *)[self controlView]) showStrength])
    {
        result.origin.y += YOFFSET - 1;
        result.size.height -= YOFFSET;
    }
    [super selectWithFrame:result inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect result = aRect;
    if ([((KSPasswordField *)[self controlView]) showStrength])
    {
        result.origin.y += YOFFSET - 1;
        result.size.height -= YOFFSET;
    }
    [super editWithFrame:result inView: controlView editor:textObj delegate:anObject event: theEvent];
}

@end

@implementation KSPasswordSecureTextFieldCell

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
    cellFrame = drawAdornments(cellFrame, controlView);
    [super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (NSRect)drawingRectForBounds:(NSRect)aRect
{
    NSRect result = [super drawingRectForBounds:aRect];
    KSPasswordField *field = (KSPasswordField *)[self controlView];

    if ([field showStrength])
    {
        result.origin.y += YOFFSET;
        result.size.height -= YOFFSET;
        result.size.width -= (sMaxStrengthDescriptionWidth + STRENGTH_INSET);	// leave room for drawing strength description
    }
    else if ([field showMatchIndicator])
    {
        result.size.width -= (16 + 2);	// leave room for drawing indicator
    }

    return result;
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
    NSRect result = aRect;
    if ([((KSPasswordField *)[self controlView]) showStrength])
    {
        result.origin.y += YOFFSET;
        result.size.height -= YOFFSET;
    }
    [super selectWithFrame:result inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
    NSRect result = aRect;
    if ([((KSPasswordField *)[self controlView]) showStrength])
    {
        result.origin.y += YOFFSET;
        result.size.height -= YOFFSET;
    }
    [super editWithFrame:result inView: controlView editor:textObj delegate:anObject event: theEvent];
}

@end


@implementation KSPasswordField


-(BOOL)textView:(NSTextView *)aTextView doCommandBySelector: (SEL)aSelector
{
    if (aSelector == @selector(moveDown:))
    {
        if ([self delegate] && [[self delegate] respondsToSelector:aSelector])
        {
            [((NSResponder *)[self delegate]) moveDown:self];
            return YES;
        }
    }
    return NO;
}

- (id)initWithFrame:(NSRect)frameRect;
{
    if (self = [super initWithFrame:frameRect])
    {
        _becomesFirstResponderWhenToggled = YES;

		// Don't show text by default. This needs to be called to replace the standard cell with our custom one.
		[self setShowsText:NO];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder;
{
    if (self = [super initWithCoder:aDecoder])
    {
        _becomesFirstResponderWhenToggled = YES;

		// Don't show text by default. This needs to be called to replace the standard cell with our custom one.
		[self setShowsText:NO];
    }
    return self;
}

@synthesize showStrength = _showStrength;
@synthesize showMatchIndicator = _showMatchIndicator;
@synthesize passwordMeter = _passwordMeter;;
@synthesize strength = _strength;
@synthesize length = _length;
@synthesize matching = _matching;
@synthesize descriptionOfStrength = _descriptionOfStrength;

+ (Class)cellClass;
{
    return [NSSecureTextFieldCell class];       // Really just a guess; set to the right subclass from code later.
}

+ (void)initialize
{
    NSArray *strengthDescriptions = @[
        @"",        // don't show any status yet
        NSLocalizedString(@"too common", @"description of (strength of) password. SHOULD BE A VERY SHORT WORD/PHRASE!"),
        NSLocalizedString(@"too short", @"description of (strength of) password. SHOULD BE A VERY SHORT WORD/PHRASE!"),
        NSLocalizedString(@"insecure", @"description of (strength of) password. SHOULD BE A VERY SHORT WORD!"),
        NSLocalizedString(@"weak", @"description of (strength of) password. SHOULD BE A VERY SHORT WORD!"),
        NSLocalizedString(@"fair", @"description of (strength of) password. OK but not great. SHOULD BE A VERY SHORT WORD!"),
        NSLocalizedString(@"strong", @"description of (strength of) password. SHOULD BE A VERY SHORT WORD!")];
    sStrengthDescriptions = strengthDescriptions;
    
    // Load in the password blacklist file
    NSURL *blacklistURL = [[NSBundle mainBundle] URLForResource:@"blacklist" withExtension:@"plist"];
    NSArray *blacklistArray = [[NSArray alloc] initWithContentsOfURL:blacklistURL];
    sPasswordBlacklist = [[NSSet alloc] initWithArray:blacklistArray];

    
    NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
                          [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
                          nil];
    for ( NSString *desc in sStrengthDescriptions)
    {
        NSAttributedString *a = [[NSMutableAttributedString alloc] initWithString:desc attributes:attr];
        NSRect r = [a boundingRectWithSize:NSZeroSize options:0];
        if (r.size.width > sMaxStrengthDescriptionWidth) sMaxStrengthDescriptionWidth = ceilf(r.size.width);
    }
}


- (BOOL)becomeFirstResponder;
{
    // If the control's delegate responds to controlDidBecomeFirstResponder, invoke it. Also post a notification.
    BOOL didBecomeFirstResponder = [super becomeFirstResponder];
    NSNotification *notification = [NSNotification notificationWithName:MyControlDidBecomeFirstResponderNotification object:self];
    if ( [self delegate] && [[self delegate] respondsToSelector:@selector(controlDidBecomeFirstResponder:)] ) {
        [((NSObject *)[self delegate]) controlDidBecomeFirstResponder:notification];
    }
    [[NSNotificationCenter defaultCenter] postNotification:notification];
    return didBecomeFirstResponder;
}


#pragma mark strength-o-meter



- (void) setStrength:(float)strength length:(NSUInteger)length;
{
    self.strength = strength;
    self.length = length;
    [self setNeedsDisplay:YES];
}


#pragma mark Showing Password

@synthesize showsText = _showsText;
- (void)setShowsText:(BOOL)showsText;
{
    _showsText = showsText;
    
    [self swapCellForOneOfClass:(showsText ? [KSPasswordTextFieldCell class] : [KSPasswordSecureTextFieldCell class])];
}

@synthesize becomesFirstResponderWhenToggled = _becomesFirstResponderWhenToggled;

- (void)showText:(id)sender;
{
    [self setShowsText:YES];
}

- (void)secureText:(id)sender;
{
    [self setShowsText:NO];
}

- (IBAction)toggleTextShown:(id)sender;
{
    [self setShowsText:![self showsText]];
}

- (void)swapCellForOneOfClass:(Class)cellClass;
{
    // Rememeber current selection for restoration after the swap
    // -valueForKey: neatly gives nil if no currently selected
    NSValue *selection = [[self currentEditor] valueForKey:@"selectedRange"];
    
    // Seems to me the best way to ensure all properties come along for the ride (e.g. border/editability) is to archive the existing cell
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [[self cell] encodeWithCoder:archiver];
    [archiver finishEncoding];
   
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    NSTextFieldCell *cell = [[cellClass alloc] initWithCoder:unarchiver];
    cell.stringValue = [self.cell stringValue]; // restore value; secure text fields wisely don't encode it
    [unarchiver finishDecoding];
    
    [self setCell:cell];
    [self setNeedsDisplay:YES];

    // Restore selection
    if (selection)
    {
        [self.window makeFirstResponder:self];
        [[self currentEditor] setSelectedRange:[selection rangeValue]];
    }
    else if (self.becomesFirstResponderWhenToggled)
    {
        NSTextView *fieldEditor = (NSTextView *)[self.window firstResponder];
        BOOL isEditingPassword = [fieldEditor isKindOfClass:[NSTextView class]] && [fieldEditor.delegate isKindOfClass:[KSPasswordField class]];

        if (isEditingPassword)
        {
            [self.window makeFirstResponder:self];
        }
    }
}

#pragma mark - Password Cleaning Logic

//! Returns the same string if nothing needs changing.
//! Otherwise, returns the password with whitespace trimmed off

- (NSString*)cleanedPasswordForString:(NSString*)string
{
    NSString* result;
    
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSCharacterSet *nonWhitespaceChars = [whitespace invertedSet];
    BOOL containsNonWhitespace = [string rangeOfCharacterFromSet:nonWhitespaceChars].location != NSNotFound;
    if (containsNonWhitespace)
    {
        result = [string stringByTrimmingCharactersInSet:whitespace];
    }
    else
    {
        result = string;
    }
    
    return result;
}

#pragma mark - Smart Paste


- (BOOL)textView:(NSTextView *)textView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString;
{
    BOOL shouldChange = YES;
    BOOL changingEntireContents = (affectedCharRange.location == 0) && (affectedCharRange.length == [textView.string length]);
    if (changingEntireContents)
    {
        // we check for text containing non-whitespace characters but starting with or ending with whitespace
        // if we find it, we assume that it's being pasted in, and we trim the whitespace off first
        NSString* cleaned = [self cleanedPasswordForString:replacementString];
        BOOL wasTrimmed = ![cleaned isEqualToString:replacementString];
        if (wasTrimmed)
        {
            // Store the trimmed value back into the model, which should bubble up to replace what got pasted in
            NSDictionary *binding = [self infoForBinding:NSValueBinding];
            [[binding objectForKey:NSObservedObjectKey] setValue:cleaned forKeyPath:[binding objectForKey:NSObservedKeyPathKey]];
            shouldChange = NO;
        }
    }
    
    return shouldChange;
}

#pragma mark Password strength

// Returns zero (awful) to one (awesome).  We could reject low values, warn if medium values
- (float) strengthOfPassword:(NSString *)proposedPassword;
{
    NSUInteger length = [proposedPassword length];  // the longer the better
    // Not going to use enumerateSubstringsInRange with NSStringEnumerationByComposedCharacterSequences
    // since I just want a quick and dirty measurement, and it's easier to check character-by-character
    
    NSUInteger numberOfLowercase = 0;
    NSUInteger numberOfUppercase = 0;
    NSUInteger numberOfDecimalDigit = 0;
    NSUInteger numberOfOther = 0;
    for (NSUInteger i = 0 ; i < length ; i++)
    {
        unichar aChar = [proposedPassword characterAtIndex:i];
        if ([[NSCharacterSet lowercaseLetterCharacterSet] characterIsMember:aChar])
        {
            numberOfLowercase++;
        }
        else if ([[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:aChar])
        {
            numberOfUppercase++;
        }
        else if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:aChar])
        {
            numberOfDecimalDigit++;
        }
        else
        {
            numberOfOther++;
        }
    }
    NSUInteger diversity = 0;   // We'll find if it has lower-alpha, upper alpha, numeric, and other
    if (numberOfLowercase)      diversity++;
    if (numberOfUppercase)      diversity++;
    if (numberOfDecimalDigit)   diversity++;
    if (numberOfOther)          diversity++;
 
    // Give another point if we have a good number of unique characters in the whole (longish) string

    NSMutableSet *allChars = [NSMutableSet set];
    [proposedPassword enumerateSubstringsInRange:NSMakeRange(0, [proposedPassword length])
                                         options:NSStringEnumerationByComposedCharacterSequences
                                      usingBlock:^(NSString *substring, NSRange substringRange, NSRange enclosingRange, BOOL *stop){
                                          [allChars addObject:substring];
                                      }];
    if ( [proposedPassword length] >= 12 && (float)[allChars count] / (float)[proposedPassword length] > 0.4 )
    {
        diversity++;        // Give it an extra point if there is a variety of characters
    }
    if (NSClassFromString(@"NSRegularExpression"))      // 10.7 up, so ignore if not on 10.7)
    {
        // Look for repetition: 4 or more characters, repeated - if so, reduce the diversity

        NSError *error = NULL;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.{4,}).*\\1"  // 4 or more characters, then anything, then that same group of characters
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:&error];
        
        if (!error)
        {
            NSUInteger numberOfMatches = [regex numberOfMatchesInString:proposedPassword
                                                                    options:0
                                                                      range:NSMakeRange(0, [proposedPassword length])];
            if (numberOfMatches > 0)
            {
                diversity--;    // Might go as low as zero.
            }
        }
    }
    
    // Possible enhancement:  Penalize for ordered sequences like ABCDEFGHI…, 123456789, QWERTY, etc.
    
    
    // Now here's the big emperical formula, devised so that the more diverse and the longer,
    // the better the rating.  An 8-character password with diversity of 4 is right in the middle.
    // It's possible to have a good strength with low diversity ONLY if the password is hecka long.
    
    float strength = MIN(1.0f, 0.015625f * diversity * length);
    return strength;
}

- (BOOL) strongEnough;
{
    return self.passwordMeter >= MeterInsecure;
}

- (void)textDidChange:(NSNotification *)aNotification
{
    if (self.showStrength)
    {
        NSString    *string = [self stringValue];
        float strength = [self strengthOfPassword:string];      // zero to one
        
        BOOL visible = string.length > 0;
        
        PasswordMeter passwordMeter = MeterEmpty;
        if (visible)
        {
            if ([string length] < 8)
            {
                passwordMeter = MeterShort;
            }
            else if ([sPasswordBlacklist containsObject:string])
            {
                passwordMeter = MeterCommon;		// Don't let super-common password be chosen
            }
            else
            {
                      if (strength < 0.25)  { passwordMeter = MeterInsecure; }
                 else if (strength < 0.4)   { passwordMeter = MeterWeak; }
                 else if (strength < 0.70)  { passwordMeter = MeterFair; }
                 else                       { passwordMeter = MeterStrong; }
            }
        }
        self.passwordMeter = passwordMeter;
        self.descriptionOfStrength = [sStrengthDescriptions objectAtIndex:passwordMeter];

        [self setStrength:strength length:[string length]];
    }
    
    // Password fields don't seem to send out continuous binding updates, nor NSControlTextDidChangeNotification.
    // https://developer.apple.com/library/mac/documentation/cocoa/reference/applicationkit/classes/NSControl_Class/Reference/Reference.html#//apple_ref/c/data/NSControlTextDidChangeNotification
    // So we're doing that manually.
    
    NSNotification *newNotif = [NSNotification notificationWithName:NSControlTextDidChangeNotification
    object:self
    userInfo: @{ @"NSFieldEditor" : [self.window fieldEditor:NO forObject:self] }
        ];
    [[NSNotificationCenter defaultCenter] postNotification:newNotif];
}


@end
