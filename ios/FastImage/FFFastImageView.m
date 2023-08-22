#import "FFFastImageView.h"
#import "FFFastImageIgnoreURLParamsMapper.h"
#import "FFFastImageImageFetchStore.h"
#import <SDWebImage/UIImage+MultiFormat.h>
#import <SDWebImage/UIView+WebCache.h>
#import <CoreImage/CoreImage.h>

@interface FFFastImageView ()

@property(nonatomic, assign) BOOL hasSentOnLoadStart;
@property(nonatomic, assign) BOOL hasCompleted;
@property(nonatomic, assign) BOOL hasErrored;
// Whether the latest change of props requires the image to be reloaded
@property(nonatomic, assign) BOOL needsReload;

@property(nonatomic, strong) NSDictionary* onLoadEvent;

@end

@implementation FFFastImageView

- (id) init {
    self = [super init];
    self.resizeMode = RCTResizeModeCover;
    self.clipsToBounds = YES;
    return self;
}

- (void) setResizeMode: (RCTResizeMode)resizeMode {
    if (_resizeMode != resizeMode) {
        _resizeMode = resizeMode;
        self.contentMode = (UIViewContentMode) resizeMode;
    }
}

- (void) setOnFastImageLoadEnd: (RCTDirectEventBlock)onFastImageLoadEnd {
    _onFastImageLoadEnd = onFastImageLoadEnd;
    if (self.hasCompleted) {
        _onFastImageLoadEnd(@{});
    }
}

- (void) setOnFastImageLoad: (RCTDirectEventBlock)onFastImageLoad {
    _onFastImageLoad = onFastImageLoad;
    if (self.hasCompleted) {
        _onFastImageLoad(self.onLoadEvent);
    }
}

- (void) setOnFastImageError: (RCTDirectEventBlock)onFastImageError {
    _onFastImageError = onFastImageError;
    if (self.hasErrored) {
        _onFastImageError(@{});
    }
}

- (void) setOnFastImageLoadStart: (RCTDirectEventBlock)onFastImageLoadStart {
    if (_source && !self.hasSentOnLoadStart) {
        _onFastImageLoadStart = onFastImageLoadStart;
        onFastImageLoadStart(@{});
        self.hasSentOnLoadStart = YES;
    } else {
        _onFastImageLoadStart = onFastImageLoadStart;
        self.hasSentOnLoadStart = NO;
    }
}

- (void) setImageColor: (UIColor*)imageColor {
    if (imageColor != nil) {
        _imageColor = imageColor;
        if (super.image) {
            super.image = [self makeImage: super.image withTint: self.imageColor];
        }
    }
}

- (void)setBlurRadius:(CGFloat)blurRadius {
    if (_blurRadius != blurRadius) {
        _blurRadius = blurRadius;
        _needsReload = YES;
    }
}

- (UIImage*) makeImage: (UIImage*)image withTint: (UIColor*)color {
    UIImage* newImage = [image imageWithRenderingMode: UIImageRenderingModeAlwaysTemplate];

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:image.size format:format];

    UIImage *resultImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
        CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
        [color set];
        [newImage drawInRect:rect];
    }];

    return resultImage;
}

- (void) setImage: (UIImage*)image {
    if (_blurRadius && _blurRadius > 0) {
        UIImage *blurImage = [self blurImage: image withRadius: _blurRadius];
        if (blurImage) {
            image = blurImage;
        }
    }

    if (self.imageColor != nil) {
        super.image = [self makeImage: image withTint: self.imageColor];
    } else {
        super.image = image;
    }
}

- (void) sendOnLoad: (UIImage*)image {
    self.onLoadEvent = @{
            @"width": [NSNumber numberWithDouble: image.size.width],
            @"height": [NSNumber numberWithDouble: image.size.height]
    };
    if (self.onFastImageLoad) {
        self.onFastImageLoad(self.onLoadEvent);
    }
}

- (void) setSource: (FFFastImageSource*)source {
    if (_source != source) {
        _source = source;
        _needsReload = YES;
    }
}

- (void) setDefaultSource: (UIImage*)defaultSource {
    if (_defaultSource != defaultSource) {
        _defaultSource = defaultSource;
        _needsReload = YES;
    }
}

- (void) didSetProps: (NSArray<NSString*>*)changedProps {
    if (_needsReload) {
        [self reloadImage];
    }
}

- (void) reloadImage {
    _needsReload = NO;

    if (_source) {
        // Load base64 images.
        NSString* url = [_source.url absoluteString];
        if (url && [url hasPrefix: @"data:image"]) {
            if (self.onFastImageLoadStart) {
                self.onFastImageLoadStart(@{});
                self.hasSentOnLoadStart = YES;
            } else {
                self.hasSentOnLoadStart = NO;
            }
            // Use SDWebImage API to support external format like WebP images
            UIImage* image = [UIImage sd_imageWithData: [NSData dataWithContentsOfURL: _source.url]];
            [self setImage: image];
            if (self.onFastImageProgress) {
                self.onFastImageProgress(@{
                        @"loaded": @(1),
                        @"total": @(1)
                });
            }
            self.hasCompleted = YES;
            [self sendOnLoad: image];

            if (self.onFastImageLoadEnd) {
                self.onFastImageLoadEnd(@{});
            }
            return;
        }

        if (_source.url != nil) {
            if (_source.cacheKeyIgnoreURLParams) {
            [[FFFastImageIgnoreURLParamsMapper shared] add:_source.url];
            } else {
                [[FFFastImageIgnoreURLParamsMapper shared] remove:_source.url];
            }
        }

        NSString *cacheKey = [[SDWebImageManager sharedManager] cacheKeyForURL:_source.url];
        UIImage *cachedImage = [[SDImageCache sharedImageCache] imageFromCacheForKey:cacheKey];
        if (cachedImage) {
            // If the image is in the cache, use it directly
            [self setImage:cachedImage];
            self.hasCompleted = YES;
            [self sendOnLoad:cachedImage];
            if (self.onFastImageLoadEnd) {
                self.onFastImageLoadEnd(@{});
            }
            return;
        }

        // Set headers.
        NSDictionary* headers = _source.headers;
        SDWebImageDownloaderRequestModifier* requestModifier = [SDWebImageDownloaderRequestModifier requestModifierWithBlock: ^NSURLRequest* _Nullable (NSURLRequest* _Nonnull request) {
            NSMutableURLRequest* mutableRequest = [request mutableCopy];
            for (NSString* header in headers) {
                NSString* value = headers[header];
                [mutableRequest setValue: value forHTTPHeaderField: header];
            }
            return [mutableRequest copy];
        }];
        SDWebImageContext* context = @{SDWebImageContextDownloadRequestModifier: requestModifier};

        // Set priority.
        SDWebImageOptions options = SDWebImageRetryFailed | SDWebImageHandleCookies;
        switch (_source.priority) {
            case FFFPriorityLow:
                options |= SDWebImageLowPriority;
                break;
            case FFFPriorityNormal:
                // Priority is normal by default.
                break;
            case FFFPriorityHigh:
                options |= SDWebImageHighPriority;
                break;
        }

        // Set cache.
        switch (_source.cacheControl) {
            case FFFCacheControlWeb:
                options |= SDWebImageRefreshCached;
                break;
            case FFFCacheControlCacheOnly:
                options |= SDWebImageFromCacheOnly;
                break;
            case FFFCacheControlImmutable:
                break;
        }

        if (self.onFastImageLoadStart) {
            self.onFastImageLoadStart(@{});
            self.hasSentOnLoadStart = YES;
        } else {
            self.hasSentOnLoadStart = NO;
        }
        self.hasCompleted = NO;
        self.hasErrored = NO;

        __weak typeof(self) weakSelf = self;
        FFFastImageCompletionBlock completion = ^(UIImage* _Nullable image, NSError* _Nullable error) {
            if (error) {
                weakSelf.hasErrored = YES;
                if (weakSelf.onFastImageError) {
                    weakSelf.onFastImageError(@{});
                }
                if (weakSelf.onFastImageLoadEnd) {
                    weakSelf.onFastImageLoadEnd(@{});
                }
            } else {
                weakSelf.hasCompleted = YES;
                [weakSelf setImage:image];
                [weakSelf sendOnLoad:image];
                if (weakSelf.onFastImageLoadEnd) {
                    weakSelf.onFastImageLoadEnd(@{});
                }
            }
        };

        NSArray<FFFastImageCompletionBlock> *existingPromise = [[FFFastImageImageFetchStore shared] get:_source.url];
        if (!existingPromise) {
            [self downloadImage: _source options: options context: context];
        }

        // Add the completion to the store
        [[FFFastImageImageFetchStore shared] add:_source.url completion:completion];
    } else if (_defaultSource) {
        [self setImage: _defaultSource];
    }
}

- (void) downloadImage: (FFFastImageSource*)source options: (SDWebImageOptions)options context: (SDWebImageContext*)context {
    __weak typeof(self) weakSelf = self;
    [self sd_setImageWithURL: _source.url
            placeholderImage: _defaultSource
                     options: options
                     context: context
                    progress: ^(NSInteger receivedSize, NSInteger expectedSize, NSURL* _Nullable targetURL) {
                        if (weakSelf.onFastImageProgress) {
                            weakSelf.onFastImageProgress(@{
                                    @"loaded": @(receivedSize),
                                    @"total": @(expectedSize)
                            });
                        }
                    }
                    completed: ^(UIImage* _Nullable image,
                                NSError* _Nullable error,
                                SDImageCacheType cacheType,
                                NSURL* _Nullable imageURL) {
                        // Fetch all the callbacks for this URL
                        NSArray<FFFastImageCompletionBlock> *completions = [[FFFastImageImageFetchStore shared] get:_source.url];
                        if (completions) {
                            // Loop through all the completion callbacks and call them
                            for (FFFastImageCompletionBlock completion in completions) {
                                completion(image, error);
                            }
                            [[FFFastImageImageFetchStore shared] remove:_source.url];
                        }
                    }];
}

- (UIImage *)blurImage:(UIImage *)image withRadius:(CGFloat)radius {
    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];

    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    [filter setValue:[NSNumber numberWithFloat:radius] forKey:kCIInputRadiusKey];
    CIImage *outputImage = [filter valueForKey:kCIOutputImageKey];

    if (outputImage) {
        CGRect rect = CGRectMake(radius * 2, radius * 2, image.size.width - radius * 4, image.size.height - radius * 4);
        CGImageRef outputImageRef = [context createCGImage:outputImage fromRect:rect];

        if (outputImageRef) {
            UIImage *blurImage = [UIImage imageWithCGImage:outputImageRef];
            CGImageRelease(outputImageRef);
            return blurImage;
        }
    }

    return nil;
}

- (void) dealloc {
    [self sd_cancelCurrentImageLoad];
}

@end
