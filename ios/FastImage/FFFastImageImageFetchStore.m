#import "FFFastImageImageFetchStore.h"

@interface FFFastImageImageFetchStore ()

@property (nonatomic, strong) NSMutableDictionary<NSString *, NSMutableArray<FFFastImageCompletionBlock> *> *fetchCallbacks;

@end

@implementation FFFastImageImageFetchStore

+ (instancetype)shared {
    static FFFastImageImageFetchStore *_shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [FFFastImageImageFetchStore new];
    });

    return _shared;
}

- (id)init {
    self = [super init];
    if (self) {
        self.fetchCallbacks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)add:(NSURL *)url completion:(FFFastImageCompletionBlock)completion {
    if (!url || !completion) {
        return;
    }

    NSString *urlString = [url absoluteString];
	@synchronized(self.fetchCallbacks) {
		NSMutableArray<FFFastImageCompletionBlock> *callbacks = self.fetchCallbacks[urlString];

		if (!callbacks) {
			// Create a new list of callbacks for this URL and add the completion block to it
			callbacks = [NSMutableArray arrayWithObject:completion];
			self.fetchCallbacks[urlString] = callbacks;
		} else {
			// Append the callback to the existing list
			[callbacks addObject:completion];
		}
	}
}

- (void)remove:(NSURL *)url {
    if (!url) {
        return;
    }

    NSString *urlString = [url absoluteString];
	@synchronized(self.fetchCallbacks) {
		[self.fetchCallbacks removeObjectForKey:urlString];
	}
}

- (NSArray<FFFastImageCompletionBlock> * _Nullable)get:(NSURL *)url {
	if (!url) {
		return nil;
	}

	NSString *urlString = [url absoluteString];
	@synchronized(self.fetchCallbacks) {
		return self.fetchCallbacks[urlString];
	}
}

- (void)clear {
	@synchronized(self.fetchCallbacks) {
    	[self.fetchCallbacks removeAllObjects];
	}
}

@end
