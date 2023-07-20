#import "FFFastImageIgnoreURLParamsMapper.h"
#import <SDWebImage/SDWebImageManager.h>

@implementation NSURL (StaticUrl)

- (NSURL*)staticURL {
	return [[NSURL alloc] initWithScheme:self.scheme host:self.host path:self.path];
}

@end

@interface FFFastImageIgnoreURLParamsMapper ()

@property (strong) NSMutableSet *staticUrls;

@end

@implementation FFFastImageIgnoreURLParamsMapper

+ (instancetype)shared {
	static FFFastImageIgnoreURLParamsMapper *_shared = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_shared = [FFFastImageIgnoreURLParamsMapper new];
	});
	
	return _shared;
}

- (id)init {
	self = [super init];
	if (self) {
		_staticUrls = [NSMutableSet new];
		__weak typeof(self) weakSelf = self;		
		SDWebImageManager.sharedManager.cacheKeyFilter = [SDWebImageCacheKeyFilter cacheKeyFilterWithBlock:^NSString * _Nullable(NSURL * _Nullable url) {
			NSString *staticURLString = [weakSelf getCacheKey:url];
			if ([_staticUrls containsObject:staticURLString]) {
				return staticURLString;
			}
			return url.absoluteString;
		}];
	}
	return self;
}

- (void)add:(NSURL*)url {
	[_staticUrls addObject:[self getCacheKey:url]];
}

- (void)remove:(NSURL*)url {
	[_staticUrls removeObject:[self getCacheKey:url]];
}

- (void)clear {
	[_staticUrls removeAllObjects];
}

- (NSString*)getCacheKey:(NSURL*)url {
	return [[url staticURL] absoluteString];
}

@end
