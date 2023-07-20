#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFFastImageIgnoreURLParamsMapper : NSObject

+ (instancetype)shared;
- (void)add:(NSURL*)url;
- (void)remove:(NSURL*)url;
- (void)clear;
- (NSString*)getCacheKey:(NSURL*)url;

@end

NS_ASSUME_NONNULL_END