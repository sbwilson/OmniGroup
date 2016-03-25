// Copyright 2015-2016 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import <OmniUI/OUIFontSizeInspectorSlice.h>

#import "OUIParameters.h"
#import <OmniUI/OUIImages.h>
#import <OmniUI/OUIInspector.h>
#import <OmniUI/OUIInspectorTextWell.h>
#import <OmniUI/OUIInspectorStepperButton.h>
#import <OmniUI/OUIFontInspectorPane.h>
#import <OmniUI/OUIFontUtilities.h>
#import <OmniUI/OUIInspectorSliceView.h>
#import <OmniUI/UIView-OUIExtensions.h>

#import <OmniAppKit/OAFontDescriptor.h>
#import <OmniBase/OmniBase.h>

RCS_ID("$Id$");

@implementation OUIFontSizeInspectorSlice
{
    NSNumberFormatter *_wholeNumberFormatter;
    NSNumberFormatter *_fractionalNumberFormatter;
    UIView *_fontSizeControl;
    BOOL _touchIsDown;
}

// TODO: should these be ivars?
static const CGFloat kMinimumFontSize = 2;
static const CGFloat kMaximumFontSize = 128;
static const CGFloat kPrecision = 1000.0f;
    // Font size will be rounded to nearest 1.0f/kPrecision
static const NSString *kDigitsPrecision = @"###";
    // Number of hashes here should match the number of digits after the decimal point in the decimal representation of  1.0f/kPrecision.

static CGFloat _normalizeFontSize(CGFloat fontSize)
{
    CGFloat result = fontSize;

    result = rint(result * kPrecision) / kPrecision;
    
    if (result < kMinimumFontSize)
        result = kMinimumFontSize;
    else if (result > kMaximumFontSize)
        result = kMaximumFontSize;
    
    return result;
}

- (void)_setFontSize:(CGFloat)fontSize;
{
    if (!_touchIsDown) {
        [self.inspector willBeginChangingInspectedObjects];
        _touchIsDown = YES;
    }
    
    for (id <OUIFontInspection> object in self.appropriateObjectsForInspection) {
        OAFontDescriptor *fontDescriptor = [object fontDescriptorForInspectorSlice:self];
        if (fontDescriptor) {
            CGFloat newSize = [fontDescriptor size] + fontSize;
            newSize = _normalizeFontSize(newSize);
            fontDescriptor = [fontDescriptor newFontDescriptorWithSize:newSize];
        } else {
            UIFont *font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
            CGFloat newSize = font.pointSize + fontSize;
            newSize = _normalizeFontSize(newSize);
            fontDescriptor = [[OAFontDescriptor alloc] initWithFamily:font.familyName size:newSize];
        }
        [object setFontDescriptor:fontDescriptor fromInspectorSlice:self];
    }
    
    [self updateInterfaceFromInspectedObjects:OUIInspectorUpdateReasonObjectsEdited];
    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, self->_fontSizeControl.accessibilityValue);
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    // should usually get these from -[OUIInspectorSlice init] and custom class support.
    OBPRECONDITION(nibNameOrNil);
    OBPRECONDITION(nibBundleOrNil);
    
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]))
        return nil;
    
    NSString *baseFormat = @"#,##0";
    
    _wholeNumberFormatter = [[NSNumberFormatter alloc] init];
    [_wholeNumberFormatter setPositiveFormat:baseFormat];
    
    NSString *decimalFormat = [[NSString alloc] initWithFormat:@"%@.%@", baseFormat, kDigitsPrecision];
    
    _fractionalNumberFormatter = [[NSNumberFormatter alloc] init];
    [_fractionalNumberFormatter setPositiveFormat:decimalFormat];
    
    
    return self;
}

- (IBAction)stepperTouchesEnded:(id)sender;
{
    [self.inspector didEndChangingInspectedObjects];
    _touchIsDown = NO;
}

- (IBAction)increaseFontSize:(id)sender;
{
    [self _setFontSize:1];
}

- (IBAction)decreaseFontSize:(id)sender;
{
    [self _setFontSize:-1];
}

- (UIView *)makeFontSizeControlWithFrame:(CGRect)frame; // Return a new view w/o adding it to the view heirarchy

{
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.textColor = [OUIInspector disabledLabelTextColor];
    label.font = [UIFont boldSystemFontOfSize:[OUIInspectorTextWell fontSize]];
    return label;
}

- (void)updateFontSizeControl:(UIView *)fontSizeControl forFontSizes:(NSArray *)fontSizes extent:(OFExtent)fontSizeExtent;
{
    NSString *valueText;
    
    switch ([fontSizes count]) {
        case 0:
            OBASSERT_NOT_REACHED("why are we even visible?");
            // leave value where ever it was
            // disable controls? 
            valueText = nil;
            break;
        case 1:
            valueText = [self _formatFontSize:OFExtentMin(fontSizeExtent)];
            break;
        default:
            {
                CGFloat minSize = floor(OFExtentMin(fontSizeExtent));
                CGFloat maxSize = ceil(OFExtentMax(fontSizeExtent));

                // If either size is fractional, slap a ~ on the front.
                NSString *format = nil;
                if (minSize != OFExtentMin(fontSizeExtent) || maxSize != OFExtentMax(fontSizeExtent)) 
                    format = @"~ %@\u2013%@";  /* tilde, two numbers, en-dash */
                else
                    format = @"%@\u2013%@";  /* two numbers, en-dash */
                valueText = [NSString stringWithFormat:format, [self _formatFontSize:minSize], [self _formatFontSize:maxSize]];
            }
            break;
    }
    
    NSString *text = [NSString stringWithFormat:NSLocalizedStringFromTableInBundle(@"%@ points", @"OUIInspectors", OMNI_BUNDLE, @"font size label format string in points"), valueText];

    [self updateFontSizeControl:_fontSizeControl withText:text];
}

- (void)updateFontSizeControl:(UIView *)fontSizeControl withText:(NSString *)text;
{
    UILabel *label = OB_CHECKED_CAST(UILabel, fontSizeControl);
    label.text = text;
}

#pragma mark - OUIInspectorSlice subclass

- (void)updateInterfaceFromInspectedObjects:(OUIInspectorUpdateReason)reason;
{
    [super updateInterfaceFromInspectedObjects:reason];
    
    OUIFontSelection *selection = OUICollectFontSelection(self, self.appropriateObjectsForInspection);

    OUIWithoutAnimating(^{
        [self updateFontSizeControl:_fontSizeControl forFontSizes:selection.fontSizes extent:selection.fontSizeExtent];
    });
}

#pragma mark - UIViewController subclass

static const CGFloat buttonWidth = 30;
static const CGFloat fontSizeLabelWidth = 125.0f;
static const CGFloat fontSizeControlWidth = 100.0f;

- (void)loadView;
{
    CGRect frame = CGRectMake(0, 0, 100, kOUIInspectorWellHeight); // Width doesn't matter; we'll get width-resized as we get put in the stack.
    UIView *containerView = [[UIView alloc] initWithFrame:frame];
    containerView.preservesSuperviewLayoutMargins = YES;
    CGRect fontSizeLabelFrame = CGRectMake(frame.origin.x, frame.origin.y, fontSizeLabelWidth, frame.size.height);
    CGRect fontSizeControlFrame = CGRectMake(CGRectGetMidX(frame) - fontSizeControlWidth / 2, frame.origin.y, fontSizeControlWidth, frame.size.height);
    CGRect increaseButtonFrame = CGRectMake(CGRectGetMaxX(frame) - buttonWidth, frame.origin.y, buttonWidth, frame.size.height);
    CGRect decreaseButtonFrame = CGRectMake(CGRectGetMinX(increaseButtonFrame) - buttonWidth, frame.origin.y, buttonWidth, frame.size.height);
    
    _fontSizeLabel = [[UILabel alloc] initWithFrame:fontSizeLabelFrame];
    
    _fontSizeDecreaseStepperButton = [[OUIInspectorStepperButton alloc] initWithFrame:decreaseButtonFrame];
    [_fontSizeDecreaseStepperButton addTarget:self action:@selector(decreaseFontSize:) forControlEvents:UIControlEventTouchDown];
    _fontSizeIncreaseStepperButton = [[OUIInspectorStepperButton alloc] initWithFrame:increaseButtonFrame];
    [_fontSizeIncreaseStepperButton addTarget:self action:@selector(increaseFontSize:) forControlEvents:UIControlEventTouchDown];

    _fontSizeDecreaseStepperButton.accessibilityLabel = NSLocalizedStringFromTableInBundle(@"Font smaller", @"OUIInspectors", OMNI_BUNDLE, @"Decrement font size button accessibility label");
    [_fontSizeDecreaseStepperButton addTarget:self action:@selector(stepperTouchesEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside| UIControlEventTouchCancel];
    _fontSizeIncreaseStepperButton.accessibilityLabel = NSLocalizedStringFromTableInBundle(@"Font bigger", @"OUIInspectors", OMNI_BUNDLE, @"Increment font size button accessibility label");
    [_fontSizeIncreaseStepperButton addTarget:self action:@selector(stepperTouchesEnded:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside| UIControlEventTouchCancel];
    
    _fontSizeLabel.text = NSLocalizedStringFromTableInBundle(@"Size", @"OUIInspectors", OMNI_BUNDLE, @"Label for font size controls");
    
//    // Put the font size control beside the two buttons.
    _fontSizeControl = [self makeFontSizeControlWithFrame:fontSizeControlFrame];
    _fontSizeControl.accessibilityLabel = NSLocalizedStringFromTableInBundle(@"Font size", @"OUIInspectors", OMNI_BUNDLE, @"Font size description accessibility label");
    
    [containerView addSubview:_fontSizeLabel];
    [containerView addSubview:_fontSizeControl];
    [containerView addSubview:_fontSizeDecreaseStepperButton];
    [containerView addSubview:_fontSizeIncreaseStepperButton];

    self.view = containerView;
    self.view.translatesAutoresizingMaskIntoConstraints = NO;

    _fontSizeControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.fontSizeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.fontSizeIncreaseStepperButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.fontSizeDecreaseStepperButton.translatesAutoresizingMaskIntoConstraints = NO;

    // constraint configuration
    CGFloat buffer = [OUIInspectorSlice sliceAlignmentInsets].left;

    [NSLayoutConstraint activateConstraints:
     @[
       [self.fontSizeIncreaseStepperButton.topAnchor constraintEqualToAnchor:containerView.topAnchor],
       [self.fontSizeIncreaseStepperButton.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
       [self.fontSizeIncreaseStepperButton.widthAnchor constraintEqualToConstant:buttonWidth],
       [self.fontSizeIncreaseStepperButton.rightAnchor constraintEqualToAnchor:containerView.rightAnchor constant:buffer * -1],
       
       [self.fontSizeDecreaseStepperButton.topAnchor constraintEqualToAnchor:containerView.topAnchor],
       [self.fontSizeDecreaseStepperButton.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
       [self.fontSizeDecreaseStepperButton.rightAnchor constraintEqualToAnchor:self.fontSizeIncreaseStepperButton.leftAnchor],
       [self.fontSizeDecreaseStepperButton.widthAnchor constraintEqualToConstant:buttonWidth],
       
       [self.fontSizeLabel.topAnchor constraintEqualToAnchor:containerView.topAnchor],
       [self.fontSizeLabel.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
       [self.fontSizeLabel.widthAnchor constraintEqualToConstant:CGRectGetWidth(self.fontSizeLabel.frame)],
       [self.fontSizeLabel.leadingAnchor constraintEqualToAnchor:containerView.layoutMarginsGuide.leadingAnchor],
       
       [_fontSizeControl.topAnchor constraintEqualToAnchor:containerView.topAnchor],
       [_fontSizeControl.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor],
       [_fontSizeControl.rightAnchor constraintEqualToAnchor:self.fontSizeDecreaseStepperButton.rightAnchor],
       [_fontSizeControl.leftAnchor constraintEqualToAnchor:self.fontSizeLabel.rightAnchor],
       ]
     ];
}

- (void)viewDidLoad;
{
    [super viewDidLoad];

    _fontSizeIncreaseStepperButton.image = OUIStepperPlusImage();
    _fontSizeDecreaseStepperButton.image = OUIStepperMinusImage();
}

#pragma mark - Private

- (NSString *)_formatFontSize:(CGFloat)fontSize;
{
    CGFloat displaySize = _normalizeFontSize(fontSize);
    NSNumberFormatter *formatter = nil;
    if (rint(displaySize) != displaySize)
        formatter = _fractionalNumberFormatter;
    else
        formatter = _wholeNumberFormatter;
    
    return [formatter stringFromNumber:[NSNumber numberWithDouble:displaySize]];
}

@end

