#import "MainOutlineViewDelegate.h"
#import "KnownTableViewDataSource.h"
#import "MainConfigurationTree.h"
#import "MainNameBackgroundView.h"
#import "MainNameCellView.h"
#import "MainValueCellView.h"
#import "PreferencesModel.h"
#import "PreferencesWindowController.h"

#define kLabelLeadingSpaceWithCheckbox 24
#define kLabelLeadingSpaceWithoutCheckbox 4
#define kLabelTopSpace 4
#define kLabelBottomSpace 4

@interface MainOutlineViewDelegate ()

@property(weak) IBOutlet KnownTableViewDataSource* knownTableViewDataSource;
@property(weak) IBOutlet NSTextField* wrappedTextHeightCalculator;
@property(weak) IBOutlet PreferencesModel* preferencesModel;
@property(weak) IBOutlet PreferencesWindowController* preferencesWindowController;
@property(copy) NSDictionary* defaults;
@property NSFont* font;
@property NSMutableDictionary* heightCache;
@property dispatch_queue_t textsHeightQueue;

@end

@implementation MainOutlineViewDelegate

- (instancetype)init {
  self = [super init];

  if (self) {
    self.defaults = @{
#include "defaults.h"
    };
    self.textsHeightQueue = dispatch_queue_create("org.pqrs.Seil.MainOutlineViewDelegate.textsHeightQueue", NULL);
    self.heightCache = [NSMutableDictionary new];
    self.font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  }

  return self;
}

- (void)clearHeightCache {
  [self.heightCache removeAllObjects];
}

- (NSView*)outlineView:(NSOutlineView*)outlineView viewForTableColumn:(NSTableColumn*)tableColumn item:(id)item {
  MainConfigurationTree* tree = (MainConfigurationTree*)(item);

  if ([tableColumn.identifier isEqualToString:@"MainNameColumn"]) {
    NSString* enable = tree.node.enableKey;
    NSString* name = tree.node.name;
    NSString* style = tree.node.style;

    MainNameCellView* result = [outlineView makeViewWithIdentifier:@"MainNameCellView" owner:self];
    result.preferencesModel = self.preferencesModel;
    result.preferencesWindowController = self.preferencesWindowController;
    result.settingIdentifier = enable;

    result.textField.stringValue = name ? name : @"";
    result.textField.font = self.font;

    if ([enable length] == 0) {
      result.labelLeadingSpace.constant = kLabelLeadingSpaceWithoutCheckbox;
    } else {
      result.labelLeadingSpace.constant = kLabelLeadingSpaceWithCheckbox;

      // ----------------------------------------
      // Add checkbox
      result.checkbox = [NSButton new];
      [result.checkbox setButtonType:NSSwitchButton];
      result.checkbox.imagePosition = NSImageOnly;
      result.checkbox.target = result;
      result.checkbox.action = @selector(valueChanged:);
      if ([self.preferencesModel.values[enable] intValue]) {
        result.checkbox.state = NSOnState;
      } else {
        result.checkbox.state = NSOffState;
      }
      result.checkbox.translatesAutoresizingMaskIntoConstraints = NO;
      [result addSubview:result.checkbox positioned:NSWindowBelow relativeTo:nil];

      [result addConstraint:[NSLayoutConstraint constraintWithItem:result.checkbox
                                                         attribute:NSLayoutAttributeLeading
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:result
                                                         attribute:NSLayoutAttributeLeading
                                                        multiplier:1.0
                                                          constant:4]];
      [result addConstraint:[NSLayoutConstraint constraintWithItem:result.checkbox
                                                         attribute:NSLayoutAttributeCenterY
                                                         relatedBy:NSLayoutRelationEqual
                                                            toItem:result
                                                         attribute:NSLayoutAttributeCenterY
                                                        multiplier:1.0
                                                          constant:0]];
    }

    // ----------------------------------------
    // Set backgroundView

    NSColor* backgroundColor = nil;
    if ([style isEqualToString:@"caution"]) {
      backgroundColor = [NSColor greenColor];
    } else if ([style isEqualToString:@"important"]) {
      backgroundColor = [NSColor orangeColor];
    } else if ([style isEqualToString:@"slight"]) {
      backgroundColor = [NSColor lightGrayColor];
    }

    if (backgroundColor) {
      result.backgroundView = [MainNameBackgroundView new];
      result.backgroundView.color = backgroundColor;
      result.backgroundView.translatesAutoresizingMaskIntoConstraints = NO;
      [result addSubview:result.backgroundView positioned:NSWindowBelow relativeTo:nil];
      [result addLayoutConstraint:result.backgroundView top:0 bottom:0 leading:0 trailing:0];
    }

    return result;

  } else {
    NSString* enable = tree.node.enableKey;
    NSString* keycode = tree.node.keyCodeKey;
    if ([enable length] == 0 || [keycode length] == 0) {
      return nil;
    }

    if ([tableColumn.identifier isEqualToString:@"MainDefaultValueColumn"]) {
      int keycodevalue = [self.defaults[keycode] intValue];
      NSString* keycodename = [self.knownTableViewDataSource getKeyName:keycodevalue];

      NSTableCellView* result = [outlineView makeViewWithIdentifier:@"MainDefaultValueCellView" owner:self];
      result.textField.stringValue = [NSString stringWithFormat:@"%d (%@)", keycodevalue, keycodename];
      return result;

    } else if ([tableColumn.identifier isEqualToString:@"MainValueColumn"]) {
      MainValueCellView* result = [outlineView makeViewWithIdentifier:@"MainValueCellView" owner:self];
      result.preferencesModel = self.preferencesModel;
      result.preferencesWindowController = self.preferencesWindowController;
      result.settingIdentifier = keycode;
      result.textField.stringValue = [self.preferencesModel.values[keycode] stringValue];
      return result;
    }
  }

  return nil;
}

- (CGFloat)outlineView:(NSOutlineView*)outlineView heightOfRowByItem:(id)item {
  MainConfigurationTree* tree = (MainConfigurationTree*)(item);

  NSString* name = tree.node.name;
  NSString* enable = tree.node.enableKey;
  NSNumber* itemId = tree.node.id;

  if ([name length] == 0) {
    return [outlineView rowHeight];
  }

  if (!self.heightCache[itemId]) {
    NSTableColumn* column = [outlineView outlineTableColumn];

    CGFloat indentation = outlineView.indentationPerLevel * ([outlineView levelForItem:item] + 1);
    NSInteger preferredMaxLayoutWidth = (NSInteger)(column.width) - indentation;

    if ([enable length] > 0) {
      preferredMaxLayoutWidth -= kLabelLeadingSpaceWithCheckbox;
    } else {
      preferredMaxLayoutWidth -= kLabelLeadingSpaceWithoutCheckbox;
    }

    dispatch_sync(self.textsHeightQueue, ^{
      self.wrappedTextHeightCalculator.stringValue = name;
      self.wrappedTextHeightCalculator.font = self.font;
      self.wrappedTextHeightCalculator.preferredMaxLayoutWidth = preferredMaxLayoutWidth;

      NSSize size = [self.wrappedTextHeightCalculator fittingSize];
      self.heightCache[itemId] = @(size.height + kLabelTopSpace + kLabelBottomSpace);
    });
  }

  return [self.heightCache[itemId] integerValue];
}

@end
