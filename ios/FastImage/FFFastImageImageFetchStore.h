#import <Foundation/Foundation.h>

typedef void (^FFFastImageCompletionBlock)(UIImage* _Nullable image, NSError* _Nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface FFFastImageImageFetchStore : NSObject

+ (instancetype)shared;
- (void)add:(NSURL *)url completion:(FFFastImageCompletionBlock)completion;
- (void)remove:(NSURL *)url;
- (NSArray<FFFastImageCompletionBlock> * _Nullable)get:(NSURL *)url;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
