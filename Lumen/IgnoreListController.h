// Copyright (c) Anish Athalye (me@anishathalye.com)
// Released under GPLv3. See the included LICENSE.txt for details

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 IgnoreListController is a simple wrapper for easier ignore list management. It handles notification subscription for data changes, and provides simple interfaces to manage the list.
 */
@interface IgnoreListController : NSObject

/**
 Checks whether the URL string exists in the ignore list.

 @param URLString The URL string of the application.
 @return YES if the URL string exists in the list; NO otherwise.
 */
- (BOOL)containsURLString:(NSString *)URLString;

/**
 Get a list of ignored URL strings.

 @return List of ignored URL strings
 */
- (NSArray<NSString *> *)ignoredURLStrings;

/**
 Add multiple URL strings in the array to the ignore list.

 @param URLStrings An array containing URL strings of apps.
 */
- (void)ignoreURLStringsInArray:(NSArray<NSString *> *)URLStrings;

/**
 Remove multiple URL strings in the array from the ignore list.

 @param URLStrings An array containing URL strings of apps.
 */
- (void)removeURLStringsInArray:(NSArray<NSString *> *)URLStrings;

/**
 Gets the preferred brightness for a specific URL string.
 
 If the app does not have a preferred brightness level yet, the method will return -1. Additionally, if the app is not actually ignored, `nil` will be returned.

 @param URLString The URL string of an ignored application
 @return The preferred brightness level of the ignored application.
 */
- (nullable NSNumber *)preferredBrightnessForURLString:(NSString *)URLString;

/**
 Updates the preferred brightness for a specific URL string, and persists the changes.

 @param preferredBrightness The new preferred brightness for the ignored application.
 @param URLString The URL string of the ignored application.
 */
- (void)setPreferredBrightness:(NSNumber *)preferredBrightness forURLString:(NSString *)URLString;

@end

NS_ASSUME_NONNULL_END
