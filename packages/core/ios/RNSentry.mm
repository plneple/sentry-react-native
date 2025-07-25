#import "RNSentry.h"
#import "RNSentryTimeToDisplay.h"
#import <dlfcn.h>

#if __has_include(<React/RCTConvert.h>)
#    import <React/RCTConvert.h>
#else
#    import "RCTConvert.h"
#endif

#if __has_include(<hermes/hermes.h>) && SENTRY_PROFILING_SUPPORTED
#    define SENTRY_PROFILING_ENABLED 1
#    import <Sentry/SentryProfilingConditionals.h>
#else
#    define SENTRY_PROFILING_ENABLED 0
#    define SENTRY_TARGET_PROFILING_SUPPORTED 0
#endif

#import "RNSentryBreadcrumb.h"
#import "RNSentryId.h"
#import <Sentry/PrivateSentrySDKOnly.h>
#import <Sentry/SentryAppStartMeasurement.h>
#import <Sentry/SentryBinaryImageCache.h>
#import <Sentry/SentryDebugImageProvider+HybridSDKs.h>
#import <Sentry/SentryDependencyContainer.h>
#import <Sentry/SentryFormatter.h>
#import <Sentry/SentryOptions+HybridSDKs.h>
#import <Sentry/SentryScreenFrames.h>

// This guard prevents importing Hermes in JSC apps
#if SENTRY_PROFILING_ENABLED
#    import <hermes/hermes.h>
#endif

// Thanks to this guard, we won't import this header when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
#    import "RNSentrySpec.h"
#endif

#import "RNSentryDependencyContainer.h"
#import "RNSentryEvents.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED
#    import "RNSentryReplay.h"
#endif

#if SENTRY_HAS_UIKIT
#    import "RNSentryFramesTrackerListener.h"
#    import "RNSentryRNSScreen.h"
#endif

#import "RNSentryStart.h"
#import "RNSentryVersion.h"

@interface
SentrySDK (RNSentry)

+ (void)captureEnvelope:(SentryEnvelope *)envelope;

+ (void)storeEnvelope:(SentryEnvelope *)envelope;

@end

static bool hasFetchedAppStart;

@implementation RNSentry {
    bool hasListeners;
    RNSentryTimeToDisplay *_timeToDisplay;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (instancetype)init
{
    if (self = [super init]) {
        _timeToDisplay = [[RNSentryTimeToDisplay alloc] init];
    }
    return self;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(initNativeSdk
                  : (NSDictionary *_Nonnull)options resolve
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    NSError *error = nil;
    [RNSentryStart startWithOptions:options error:&error];
    if (error != nil) {
        reject(@"SentryReactNative", error.localizedDescription, error);
        return;
    }
    resolve(@YES);
}

RCT_EXPORT_METHOD(initNativeReactNavigationNewFrameTracking
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if SENTRY_HAS_UIKIT
    if ([[NSThread currentThread] isMainThread]) {
        [RNSentryRNSScreen swizzleViewDidAppear];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{ [RNSentryRNSScreen swizzleViewDidAppear]; });
    }

    [self initFramesTracking];
#endif
    resolve(nil);
}

- (void)initFramesTracking
{
#if SENTRY_HAS_UIKIT
    RNSentryEmitNewFrameEvent emitNewFrameEvent = ^(NSNumber *newFrameTimestampInSeconds) {
        [RNSentryTimeToDisplay putTimeToInitialDisplayForActiveSpan:newFrameTimestampInSeconds];
    };
    [[RNSentryDependencyContainer sharedInstance]
        initializeFramesTrackerListenerWith:emitNewFrameEvent];
#endif
}

// Will be called when this module's first listener is added.
- (void)startObserving
{
    hasListeners = YES;
}

// Will be called when this module's last listener is removed, or on dealloc.
- (void)stopObserving
{
    hasListeners = NO;
}

- (NSArray<NSString *> *)supportedEvents
{
    return @[ RNSentryNewFrameEvent ];
}

RCT_EXPORT_METHOD(fetchNativeSdkInfo
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    resolve(@ {
        @"name" : PrivateSentrySDKOnly.getSdkName,
        @"version" : PrivateSentrySDKOnly.getSdkVersionString
    });
}

RCT_EXPORT_METHOD(fetchModules
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"modules" ofType:@"json"];
    NSString *modulesString = [NSString stringWithContentsOfFile:filePath
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];
    resolve(modulesString);
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, fetchNativePackageName)
{
    NSString *packageName = [[NSBundle mainBundle] executablePath];
    return packageName;
}

- (NSDictionary *)fetchNativeStackFramesBy:(NSArray<NSNumber *> *)instructionsAddr
                               symbolicate:(SymbolicateCallbackType)symbolicate
{
    BOOL shouldSymbolicateLocally = [SentrySDK.options debug];
    NSString *appPackageName = [[NSBundle mainBundle] executablePath];

    NSMutableSet<NSString *> *_Nonnull imagesAddrToRetrieveDebugMetaImages =
        [[NSMutableSet alloc] init];
    NSMutableArray<NSDictionary<NSString *, id> *> *_Nonnull serializedFrames =
        [[NSMutableArray alloc] init];

    for (NSNumber *addr in instructionsAddr) {
        SentryBinaryImageInfo *_Nullable image = [[[SentryDependencyContainer sharedInstance]
            binaryImageCache] imageByAddress:[addr unsignedLongLongValue]];
        if (image != nil) {
            NSString *imageAddr = sentry_formatHexAddressUInt64([image address]);
            [imagesAddrToRetrieveDebugMetaImages addObject:imageAddr];

            NSDictionary<NSString *, id> *_Nonnull nativeFrame = @{
                @"platform" : @"cocoa",
                @"instruction_addr" : sentry_formatHexAddress(addr),
                @"package" : [image name],
                @"image_addr" : imageAddr,
                @"in_app" : [NSNumber numberWithBool:[appPackageName isEqualToString:[image name]]],
            };

            if (shouldSymbolicateLocally) {
                Dl_info symbolsBuffer;
                bool symbols_succeed = false;
                symbols_succeed
                    = symbolicate((void *)[addr unsignedLongLongValue], &symbolsBuffer) != 0;
                if (symbols_succeed) {
                    NSMutableDictionary<NSString *, id> *_Nonnull symbolicated
                        = nativeFrame.mutableCopy;
                    symbolicated[@"symbol_addr"]
                        = sentry_formatHexAddressUInt64((uintptr_t)symbolsBuffer.dli_saddr);
                    symbolicated[@"function"] = [NSString stringWithCString:symbolsBuffer.dli_sname
                                                                   encoding:NSUTF8StringEncoding];

                    nativeFrame = symbolicated;
                }
            }

            [serializedFrames addObject:nativeFrame];
        } else {
            [serializedFrames addObject:@{
                @"platform" : @"cocoa",
                @"instruction_addr" : sentry_formatHexAddress(addr),
            }];
        }
    }

    if (shouldSymbolicateLocally) {
        return @{
            @"frames" : serializedFrames,
        };
    } else {
        NSMutableArray<NSDictionary<NSString *, id> *> *_Nonnull serializedDebugMetaImages =
            [[NSMutableArray alloc] init];

        NSArray<SentryDebugMeta *> *debugMetaImages =
            [[[SentryDependencyContainer sharedInstance] debugImageProvider]
                getDebugImagesForImageAddressesFromCache:imagesAddrToRetrieveDebugMetaImages];

        for (SentryDebugMeta *debugImage in debugMetaImages) {
            [serializedDebugMetaImages addObject:[debugImage serialize]];
        }

        return @{
            @"frames" : serializedFrames,
            @"debugMetaImages" : serializedDebugMetaImages,
        };
    }
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, fetchNativeStackFramesBy
                                    : (NSArray *)instructionsAddr)
{
    return [self fetchNativeStackFramesBy:instructionsAddr symbolicate:dladdr];
}

RCT_EXPORT_METHOD(fetchNativeDeviceContexts
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    if (PrivateSentrySDKOnly.options.debug) {
        NSLog(@"Bridge call to: deviceContexts");
    }
    __block NSMutableDictionary<NSString *, id> *serializedScope;
    // Temp work around until sorted out this API in sentry-cocoa.
    // TODO: If the callback isnt' executed the promise wouldn't be resolved.
    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) {
        serializedScope = [[scope serialize] mutableCopy];

        NSDictionary<NSString *, id> *user = [serializedScope valueForKey:@"user"];
        if (user == nil) {
            [serializedScope setValue:@ { @"id" : PrivateSentrySDKOnly.installationID }
                               forKey:@"user"];
        }

        if (PrivateSentrySDKOnly.options.debug) {
            NSData *data = [NSJSONSerialization dataWithJSONObject:serializedScope
                                                           options:0
                                                             error:nil];
            NSString *debugContext = [[NSString alloc] initWithData:data
                                                           encoding:NSUTF8StringEncoding];
            NSLog(@"Contexts: %@", debugContext);
        }
    }];

    NSDictionary<NSString *, id> *extraContext = [PrivateSentrySDKOnly getExtraContext];
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *contexts =
        [serializedScope[@"context"] mutableCopy];

    if (extraContext && [extraContext[@"device"] isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *deviceContext =
            [contexts[@"device"] mutableCopy];
        [deviceContext addEntriesFromDictionary:extraContext[@"device"]];
        [contexts setValue:deviceContext forKey:@"device"];
    }

    if (extraContext && [extraContext[@"app"] isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *appContext =
            [contexts[@"app"] mutableCopy];
        [appContext addEntriesFromDictionary:extraContext[@"app"]];
        [contexts setValue:appContext forKey:@"app"];
    }

    [serializedScope setValue:contexts forKey:@"contexts"];
    [serializedScope removeObjectForKey:@"context"];

    // Remove react-native breadcrumbs
    NSPredicate *removeRNBreadcrumbsPredicate =
        [NSPredicate predicateWithBlock:^BOOL(NSDictionary *breadcrumb, NSDictionary *bindings) {
            return ![breadcrumb[@"origin"] isEqualToString:@"react-native"];
        }];
    NSArray *breadcrumbs = [[serializedScope[@"breadcrumbs"] mutableCopy]
        filteredArrayUsingPredicate:removeRNBreadcrumbsPredicate];
    [serializedScope setValue:breadcrumbs forKey:@"breadcrumbs"];

    resolve(serializedScope);
}

RCT_EXPORT_METHOD(fetchNativeAppStart
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if SENTRY_HAS_UIKIT
    NSDictionary<NSString *, id> *measurements =
        [PrivateSentrySDKOnly appStartMeasurementWithSpans];
    if (measurements == nil) {
        resolve(nil);
        return;
    }

    NSMutableDictionary<NSString *, id> *mutableMeasurements =
        [[NSMutableDictionary alloc] initWithDictionary:measurements];
    [mutableMeasurements setValue:[NSNumber numberWithBool:hasFetchedAppStart]
                           forKey:@"has_fetched"];

    // This is always set to true, as we would only allow an app start fetch to only happen once
    // in the case of a JS bundle reload, we do not want it to be instrumented again.
    hasFetchedAppStart = true;

    resolve(mutableMeasurements);
#else
    resolve(nil);
#endif
}

RCT_EXPORT_METHOD(fetchNativeFrames
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{

#if TARGET_OS_IPHONE || TARGET_OS_MACCATALYST
    if (PrivateSentrySDKOnly.isFramesTrackingRunning) {
        SentryScreenFrames *frames = PrivateSentrySDKOnly.currentScreenFrames;

        if (frames == nil) {
            resolve(nil);
            return;
        }

        NSNumber *total = [NSNumber numberWithLong:frames.total];
        NSNumber *frozen = [NSNumber numberWithLong:frames.frozen];
        NSNumber *slow = [NSNumber numberWithLong:frames.slow];

        resolve(@ {
            @"totalFrames" : total,
            @"frozenFrames" : frozen,
            @"slowFrames" : slow,
        });
    } else {
        resolve(nil);
    }
#else
    resolve(nil);
#endif
}

RCT_EXPORT_METHOD(fetchNativeRelease
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    resolve(@ {
        @"id" : infoDict[@"CFBundleIdentifier"],
        @"version" : infoDict[@"CFBundleShortVersionString"],
        @"build" : infoDict[@"CFBundleVersion"],
    });
}

RCT_EXPORT_METHOD(captureEnvelope
                  : (NSString *_Nonnull)rawBytes options
                  : (NSDictionary *_Nonnull)options resolve
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    NSData *data = [[NSData alloc] initWithBase64EncodedString:rawBytes options:0];

    SentryEnvelope *envelope = [PrivateSentrySDKOnly envelopeWithData:data];
    if (envelope == nil) {
        reject(@"SentryReactNative", @"Failed to parse envelope from byte array.", nil);
        return;
    }

#if DEBUG
    [PrivateSentrySDKOnly captureEnvelope:envelope];
#else
    if ([[options objectForKey:@"hardCrashed"] boolValue]) {
        // Storing to disk happens asynchronously with captureEnvelope
        [PrivateSentrySDKOnly storeEnvelope:envelope];
    } else {
        [PrivateSentrySDKOnly captureEnvelope:envelope];
    }
#endif
    resolve(@YES);
}

RCT_EXPORT_METHOD(captureScreenshot
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_IPHONE || TARGET_OS_MACCATALYST
    NSArray<NSData *> *rawScreenshots = [PrivateSentrySDKOnly captureScreenshots];
    NSMutableArray *screenshotsArray = [NSMutableArray arrayWithCapacity:[rawScreenshots count]];

    int counter = 1;
    for (NSData *raw in rawScreenshots) {
        NSMutableArray *screenshot = [NSMutableArray arrayWithCapacity:raw.length];
        const char *bytes = (char *)[raw bytes];
        for (int i = 0; i < [raw length]; i++) {
            [screenshot addObject:[[NSNumber alloc] initWithChar:bytes[i]]];
        }

        NSString *filename = @"screenshot.png";
        if (counter > 1) {
            filename = [NSString stringWithFormat:@"screenshot-%d.png", counter];
        }
        [screenshotsArray addObject:@ {
            @"data" : screenshot,
            @"contentType" : @"image/png",
            @"filename" : filename,
        }];
        counter++;
    }

    resolve(screenshotsArray);
#else
    resolve(nil);
#endif
}

RCT_EXPORT_METHOD(fetchViewHierarchy
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_IPHONE || TARGET_OS_MACCATALYST
    NSData *rawViewHierarchy = [PrivateSentrySDKOnly captureViewHierarchy];

    NSMutableArray *viewHierarchy = [NSMutableArray arrayWithCapacity:rawViewHierarchy.length];
    const char *bytes = (char *)[rawViewHierarchy bytes];
    for (int i = 0; i < [rawViewHierarchy length]; i++) {
        [viewHierarchy addObject:[[NSNumber alloc] initWithChar:bytes[i]]];
    }

    resolve(viewHierarchy);
#else
    resolve(nil);
#endif
}

RCT_EXPORT_METHOD(setUser : (NSDictionary *)userKeys otherUserKeys : (NSDictionary *)userDataKeys)
{
    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) {
        [scope setUser:[RNSentry userFrom:userKeys otherUserKeys:userDataKeys]];
    }];
}

+ (SentryUser *_Nullable)userFrom:(NSDictionary *)userKeys
                    otherUserKeys:(NSDictionary *)userDataKeys
{
    // we can safely ignore userDataKeys since if original JS user was null userKeys will be null
    if ([userKeys isKindOfClass:NSDictionary.class]) {
        SentryUser *userInstance = [[SentryUser alloc] init];

        id userId = [userKeys valueForKey:@"id"];
        if ([userId isKindOfClass:NSString.class]) {
            [userInstance setUserId:userId];
        }
        id ipAddress = [userKeys valueForKey:@"ip_address"];
        if ([ipAddress isKindOfClass:NSString.class]) {
            [userInstance setIpAddress:ipAddress];
        }
        id email = [userKeys valueForKey:@"email"];
        if ([email isKindOfClass:NSString.class]) {
            [userInstance setEmail:email];
        }
        id username = [userKeys valueForKey:@"username"];
        if ([username isKindOfClass:NSString.class]) {
            [userInstance setUsername:username];
        }
        id segment = [userKeys valueForKey:@"segment"];
        if ([segment isKindOfClass:NSString.class]) {
            [userInstance setSegment:segment];
        }

        if ([userDataKeys isKindOfClass:NSDictionary.class]) {
            [userInstance setData:userDataKeys];
        }

        return userInstance;
    }

    if (![[NSNull null] isEqual:userKeys] && nil != userKeys) {
        NSLog(@"[RNSentry] Method setUser received unexpected type of userKeys.");
    }

    return nil;
}

RCT_EXPORT_METHOD(addBreadcrumb : (NSDictionary *)breadcrumb)
{
    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) {
        [scope addBreadcrumb:[RNSentryBreadcrumb from:breadcrumb]];
    }];

#if SENTRY_HAS_UIKIT
    NSString *_Nullable screen = [RNSentryBreadcrumb getCurrentScreenFrom:breadcrumb];
    if (screen != nil) {
        [PrivateSentrySDKOnly setCurrentScreen:screen];
    }
#endif // SENTRY_HAS_UIKIT
}

RCT_EXPORT_METHOD(clearBreadcrumbs)
{
    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) { [scope clearBreadcrumbs]; }];
}

RCT_EXPORT_METHOD(setExtra : (NSString *)key extra : (NSString *)extra)
{
    [SentrySDK
        configureScope:^(SentryScope *_Nonnull scope) { [scope setExtraValue:extra forKey:key]; }];
}

RCT_EXPORT_METHOD(setContext : (NSString *)key context : (NSDictionary *)context)
{
    if (key == nil) {
        return;
    }

    [SentrySDK configureScope:^(SentryScope *_Nonnull scope) {
        if (context == nil) {
            [scope removeContextForKey:key];
        } else {
            [scope setContextValue:context forKey:key];
        }
    }];
}

RCT_EXPORT_METHOD(setTag : (NSString *)key value : (NSString *)value)
{
    [SentrySDK
        configureScope:^(SentryScope *_Nonnull scope) { [scope setTagValue:value forKey:key]; }];
}

RCT_EXPORT_METHOD(crash) { [SentrySDK crash]; }

RCT_EXPORT_METHOD(closeNativeSdk
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    [SentrySDK close];
    resolve(@YES);
}

RCT_EXPORT_METHOD(disableNativeFramesTracking)
{
    // Do nothing on iOS, this bridge method only has an effect on android.
}

RCT_EXPORT_METHOD(enableNativeFramesTracking)
{
    // Do nothing on iOS, this bridge method only has an effect on android.
    // If you're starting the Cocoa SDK manually,
    // you can set the 'enableAutoPerformanceTracing: true' option and
    // the 'tracesSampleRate' or 'tracesSampler' option.
}

RCT_EXPORT_METHOD(captureReplay
                  : (BOOL)isHardCrash resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if SENTRY_TARGET_REPLAY_SUPPORTED
    [PrivateSentrySDKOnly captureReplay];
    resolve([PrivateSentrySDKOnly getReplayId]);
#else
    resolve(nil);
#endif
}

RCT_EXPORT_METHOD(getDataFromUri
                  : (NSString *_Nonnull)uri resolve
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
#if TARGET_OS_IPHONE || TARGET_OS_MACCATALYST
    NSURL *fileURL = [NSURL URLWithString:uri];
    if (![fileURL isFileURL]) {
        reject(@"SentryReactNative", @"The provided URI is not a valid file:// URL", nil);
        return;
    }
    NSError *error = nil;
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL options:0 error:&error];
    if (error || !fileData) {
        reject(@"SentryReactNative", @"Failed to read file data", error);
        return;
    }
    NSMutableArray *byteArray = [NSMutableArray arrayWithCapacity:fileData.length];
    const unsigned char *bytes = (const unsigned char *)fileData.bytes;

    for (NSUInteger i = 0; i < fileData.length; i++) {
        [byteArray addObject:@(bytes[i])];
    }
    resolve(byteArray);
#else
    resolve(nil);
#endif
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSString *, getCurrentReplayId)
{
#if SENTRY_TARGET_REPLAY_SUPPORTED
    return [PrivateSentrySDKOnly getReplayId];
#else
    return nil;
#endif
}

static NSString *const enabledProfilingMessage = @"Enable Hermes to use Sentry Profiling.";
static SentryId *nativeProfileTraceId = nil;
static uint64_t nativeProfileStartTime = 0;

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, startProfiling : (BOOL)platformProfilers)
{
#if SENTRY_PROFILING_ENABLED
    try {
        facebook::hermes::HermesRuntime::enableSamplingProfiler();
        if (nativeProfileTraceId == nil && nativeProfileStartTime == 0 && platformProfilers) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            nativeProfileTraceId = [RNSentryId newId];
            nativeProfileStartTime =
                [PrivateSentrySDKOnly startProfilerForTrace:nativeProfileTraceId];
#    endif
        } else {
            if (!platformProfilers) {
                NSLog(@"Native profiling is disabled. Only starting Hermes profiling.");
            } else {
                NSLog(@"Native profiling already in progress. Currently existing trace: %@",
                    nativeProfileTraceId);
            }
        }
        return @{@"started" : @YES};
    } catch (const std::exception &ex) {
        if (nativeProfileTraceId != nil) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            [PrivateSentrySDKOnly discardProfilerForTrace:nativeProfileTraceId];
#    endif
            nativeProfileTraceId = nil;
        }
        nativeProfileStartTime = 0;
        return @ {
            @"error" : [NSString stringWithCString:ex.what()
                                          encoding:[NSString defaultCStringEncoding]]
        };
    } catch (...) {
        if (nativeProfileTraceId != nil) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            [PrivateSentrySDKOnly discardProfilerForTrace:nativeProfileTraceId];
#    endif
            nativeProfileTraceId = nil;
        }
        nativeProfileStartTime = 0;
        return @ { @"error" : @"Failed to start profiling" };
    }
#else
    return @ { @"error" : enabledProfilingMessage };
#endif
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSDictionary *, stopProfiling)
{
#if SENTRY_PROFILING_ENABLED
    try {
        NSDictionary<NSString *, id> *nativeProfile = nil;
        if (nativeProfileTraceId != nil && nativeProfileStartTime != 0) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            uint64_t nativeProfileStopTime = clock_gettime_nsec_np(CLOCK_UPTIME_RAW);
            nativeProfile = [PrivateSentrySDKOnly collectProfileBetween:nativeProfileStartTime
                                                                    and:nativeProfileStopTime
                                                               forTrace:nativeProfileTraceId];
#    endif
        }
        // Cleanup native profiles
        nativeProfileTraceId = nil;
        nativeProfileStartTime = 0;

        facebook::hermes::HermesRuntime::disableSamplingProfiler();
        std::stringstream ss;
        // Before RN 0.69 Hermes used llvh::raw_ostream (profiling is supported for 0.69 and newer)
        facebook::hermes::HermesRuntime::dumpSampledTraceToStream(ss);

        std::string s = ss.str();
        NSString *data = [NSString stringWithCString:s.c_str()
                                            encoding:[NSString defaultCStringEncoding]];

#    if SENTRY_PROFILING_DEBUG_ENABLED
        NSString *rawProfileFileName = @"hermes.profile";
        NSError *error = nil;
        NSString *rawProfileFilePath =
            [NSTemporaryDirectory() stringByAppendingPathComponent:rawProfileFileName];
        if (![data writeToFile:rawProfileFilePath
                    atomically:YES
                      encoding:NSUTF8StringEncoding
                         error:&error]) {
            NSLog(@"Error writing Raw Hermes Profile to %@: %@", rawProfileFilePath, error);
        } else {
            NSLog(@"Raw Hermes Profile saved to %@", rawProfileFilePath);
        }
#    endif

        if (data == nil) {
            return @ { @"error" : @"Failed to retrieve Hermes profile." };
        }

        if (nativeProfile == nil) {
            return @ { @"profile" : data };
        }

        return @ {
            @"profile" : data,
            @"nativeProfile" : nativeProfile,
        };
    } catch (const std::exception &ex) {
        if (nativeProfileTraceId != nil) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            [PrivateSentrySDKOnly discardProfilerForTrace:nativeProfileTraceId];
#    endif
            nativeProfileTraceId = nil;
        }
        nativeProfileStartTime = 0;
        return @ {
            @"error" : [NSString stringWithCString:ex.what()
                                          encoding:[NSString defaultCStringEncoding]]
        };
    } catch (...) {
        if (nativeProfileTraceId != nil) {
#    if SENTRY_TARGET_PROFILING_SUPPORTED
            [PrivateSentrySDKOnly discardProfilerForTrace:nativeProfileTraceId];
#    endif
            nativeProfileTraceId = nil;
        }
        nativeProfileStartTime = 0;
        return @ { @"error" : @"Failed to stop profiling" };
    }
#else
    return @ { @"error" : enabledProfilingMessage };
#endif
}

RCT_EXPORT_METHOD(crashedLastRun
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    resolve(@([SentrySDK crashedLastRun]));
}

// Thanks to this guard, we won't compile this code when we build for the old architecture.
#ifdef RCT_NEW_ARCH_ENABLED
- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeRNSentrySpecJSI>(params);
}
#endif

RCT_EXPORT_METHOD(getNewScreenTimeToDisplay
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    [_timeToDisplay getTimeToDisplay:resolve];
}

RCT_EXPORT_METHOD(popTimeToDisplayFor
                  : (NSString *)key resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    resolve([RNSentryTimeToDisplay popTimeToDisplayFor:key]);
}

RCT_EXPORT_SYNCHRONOUS_TYPED_METHOD(NSNumber *, setActiveSpanId : (NSString *)spanId)
{
    [RNSentryTimeToDisplay setActiveSpanId:spanId];
    return @YES; // The return ensures that the method is synchronous
}

RCT_EXPORT_METHOD(encodeToBase64
                  : (NSArray *)array resolver
                  : (RCTPromiseResolveBlock)resolve rejecter
                  : (RCTPromiseRejectBlock)reject)
{
    NSUInteger count = array.count;
    uint8_t *bytes = (uint8_t *)malloc(count);

    if (!bytes) {
        reject(@"encodeToBase64", @"Memory allocation failed", nil);
        return;
    }

    for (NSUInteger i = 0; i < count; i++) {
        bytes[i] = (uint8_t)[array[i] unsignedCharValue];
    }

    NSData *data = [NSData dataWithBytes:bytes length:count];
    free(bytes);

    NSString *base64String = [data base64EncodedStringWithOptions:0];
    resolve(base64String);
}

@end
