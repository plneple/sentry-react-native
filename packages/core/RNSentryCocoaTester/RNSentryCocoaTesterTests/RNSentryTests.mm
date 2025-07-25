#import "RNSentryTests.h"
#import "RNSentryStart+Test.h"
#import <OCMock/OCMock.h>
#import <RNSentry/RNSentry.h>
#import <Sentry/PrivateSentrySDKOnly.h>
#import <Sentry/SentryDebugImageProvider+HybridSDKs.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

@interface RNSentryInitNativeSdkTests : XCTestCase

@end

@implementation RNSentryInitNativeSdkTests

- (void)testStartWithDictionaryRemovesPerformanceProperties
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary =
        @{ @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
            @"beforeSend" : @"will_be_overwritten",
            @"tracesSampleRate" : @1,
            @"tracesSampler" : ^(SentrySamplingContext *_Nonnull samplingContext) { return @1;
}
, @"enableTracing" : @YES,
}
;
[RNSentryStart startWithOptions:mockedReactNativeDictionary error:&error];
SentryOptions *actualOptions = PrivateSentrySDKOnly.options;
XCTAssertNotNil(actualOptions, @"Did not create sentry options");
XCTAssertNil(error, @"Should not pass no error");
XCTAssertNotNil(
    actualOptions.beforeSend, @"Before send is overwriten by the native RNSentry implementation");
XCTAssertEqual(
    actualOptions.tracesSampleRate, nil, @"Traces sample rate should not be passed to native");
XCTAssertEqual(actualOptions.tracesSampler, nil, @"Traces sampler should not be passed to native");
XCTAssertEqual(actualOptions.enableTracing, false, @"EnableTracing should not be passed to native");
}

- (void)testCaptureFailedRequestsIsDisabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
    };
    [RNSentryStart startWithOptions:mockedReactNativeDictionary error:&error];
    SentryOptions *actualOptions = PrivateSentrySDKOnly.options;

    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertFalse(actualOptions.enableCaptureFailedRequests);
}

- (void)testCreateOptionsWithDictionaryNativeCrashHandlingDefault
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual([actualOptions.integrations containsObject:@"SentryCrashIntegration"], true,
        @"Did not set native crash handling");
}

- (void)testCreateOptionsWithDictionaryAutoPerformanceTracingDefault
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual(
        actualOptions.enableAutoPerformanceTracing, true, @"Did not set Auto Performance Tracing");
}

- (void)testCreateOptionsWithDictionaryNativeCrashHandlingEnabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"enableNativeCrashHandling" : @YES,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual([actualOptions.integrations containsObject:@"SentryCrashIntegration"], true,
        @"Did not set native crash handling");
}

- (void)testCreateOptionsWithDictionaryAutoPerformanceTracingEnabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"enableAutoPerformanceTracing" : @YES,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual(
        actualOptions.enableAutoPerformanceTracing, true, @"Did not set Auto Performance Tracing");
}

- (void)testCreateOptionsWithDictionaryNativeCrashHandlingDisabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"enableNativeCrashHandling" : @NO,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual([actualOptions.integrations containsObject:@"SentryCrashIntegration"], false,
        @"Did not disable native crash handling");
}

- (void)testCreateOptionsWithDictionaryAutoPerformanceTracingDisabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"enableAutoPerformanceTracing" : @NO,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertEqual(actualOptions.enableAutoPerformanceTracing, false,
        @"Did not disable Auto Performance Tracing");
}

- (void)testCreateOptionsWithDictionarySpotlightEnabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"spotlight" : @YES,
        @"defaultSidecarUrl" : @"http://localhost:8969/teststream",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertTrue(actualOptions.enableSpotlight, @"Did not enable spotlight");
    XCTAssertEqual(actualOptions.spotlightUrl, @"http://localhost:8969/teststream");
}

- (void)testCreateOptionsWithDictionarySpotlightOne
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"spotlight" : @1,
        @"defaultSidecarUrl" : @"http://localhost:8969/teststream",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertTrue(actualOptions.enableSpotlight, @"Did not enable spotlight");
    XCTAssertEqual(actualOptions.spotlightUrl, @"http://localhost:8969/teststream");
}

- (void)testCreateOptionsWithDictionarySpotlightUrl
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"spotlight" : @"http://localhost:8969/teststream",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertTrue(actualOptions.enableSpotlight, @"Did not enable spotlight");
    XCTAssertEqual(actualOptions.spotlightUrl, @"http://localhost:8969/teststream");
}

- (void)testCreateOptionsWithDictionarySpotlightDisabled
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"spotlight" : @NO,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertFalse(actualOptions.enableSpotlight, @"Did not disable spotlight");
}

- (void)testCreateOptionsWithDictionarySpotlightZero
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"spotlight" : @0,
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];
    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");
    XCTAssertFalse(actualOptions.enableSpotlight, @"Did not disable spotlight");
}

- (void)testCreateOptionsWithDictionaryEnableUnhandledCPPExceptionsV2Enabled
{
    RNSentry *rnSentry = [[RNSentry alloc] init];
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"_experiments" : @ {
            @"enableUnhandledCPPExceptionsV2" : @YES,
        },
    };
    SentryOptions *actualOptions = [rnSentry createOptionsWithDictionary:mockedReactNativeDictionary
                                                                   error:&error];

    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");

    id experimentalOptions = [actualOptions valueForKey:@"experimental"];
    XCTAssertNotNil(experimentalOptions, @"Experimental options should not be nil");

    BOOL enableUnhandledCPPExceptions =
        [[experimentalOptions valueForKey:@"enableUnhandledCPPExceptionsV2"] boolValue];
    XCTAssertTrue(
        enableUnhandledCPPExceptions, @"enableUnhandledCPPExceptionsV2 should be enabled");
}

- (void)testCreateOptionsWithDictionaryEnableUnhandledCPPExceptionsV2Disabled
{
    RNSentry *rnSentry = [[RNSentry alloc] init];
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
        @"_experiments" : @ {
            @"enableUnhandledCPPExceptionsV2" : @NO,
        },
    };
    SentryOptions *actualOptions = [rnSentry createOptionsWithDictionary:mockedReactNativeDictionary
                                                                   error:&error];

    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");

    id experimentalOptions = [actualOptions valueForKey:@"experimental"];
    XCTAssertNotNil(experimentalOptions, @"Experimental options should not be nil");

    BOOL enableUnhandledCPPExceptions =
        [[experimentalOptions valueForKey:@"enableUnhandledCPPExceptionsV2"] boolValue];
    XCTAssertFalse(
        enableUnhandledCPPExceptions, @"enableUnhandledCPPExceptionsV2 should be disabled");
}

- (void)testCreateOptionsWithDictionaryEnableUnhandledCPPExceptionsV2Default
{
    RNSentry *rnSentry = [[RNSentry alloc] init];
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"https://abcd@efgh.ingest.sentry.io/123456",
    };
    SentryOptions *actualOptions = [rnSentry createOptionsWithDictionary:mockedReactNativeDictionary
                                                                   error:&error];

    XCTAssertNotNil(actualOptions, @"Did not create sentry options");
    XCTAssertNil(error, @"Should not pass no error");

    // Test that when no _experiments are provided, the experimental option defaults to false
    id experimentalOptions = [actualOptions valueForKey:@"experimental"];
    XCTAssertNotNil(experimentalOptions, @"Experimental options should not be nil");

    BOOL enableUnhandledCPPExceptions =
        [[experimentalOptions valueForKey:@"enableUnhandledCPPExceptionsV2"] boolValue];
    XCTAssertFalse(
        enableUnhandledCPPExceptions, @"enableUnhandledCPPExceptionsV2 should default to disabled");
}

- (void)testPassesErrorOnWrongDsn
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedReactNativeDictionary = @{
        @"dsn" : @"not_a_valid_dsn",
    };
    SentryOptions *actualOptions =
        [RNSentryStart createOptionsWithDictionary:mockedReactNativeDictionary error:&error];

    XCTAssertNil(actualOptions, @"Created invalid sentry options");
    XCTAssertNotNil(error, @"Did not created error on invalid dsn");
}

- (void)testBeforeBreadcrumbsCallbackFiltersOutSentryDsnRequestBreadcrumbs
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedDictionary = @{
        @"dsn" : @"https://abc@def.ingest.sentry.io/1234567",
        @"devServerUrl" : @"http://localhost:8081"
    };
    SentryOptions *options = [RNSentryStart createOptionsWithDictionary:mockedDictionary
                                                                  error:&error];

    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] init];
    breadcrumb.type = @"http";
    breadcrumb.data = @{ @"url" : @"https://def.ingest.sentry.io/1234567" };

    SentryBreadcrumb *result = options.beforeBreadcrumb(breadcrumb);

    XCTAssertNil(result, @"Breadcrumb should be filtered out");
}

- (void)testBeforeBreadcrumbsCallbackFiltersOutDevServerRequestBreadcrumbs
{
    NSError *error = nil;

    NSString *mockDevServer = @"http://localhost:8081";

    NSDictionary *_Nonnull mockedDictionary =
        @{ @"dsn" : @"https://abc@def.ingest.sentry.io/1234567", @"devServerUrl" : mockDevServer };
    SentryOptions *options = [RNSentryStart createOptionsWithDictionary:mockedDictionary
                                                                  error:&error];

    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] init];
    breadcrumb.type = @"http";
    breadcrumb.data = @{ @"url" : mockDevServer };

    SentryBreadcrumb *result = options.beforeBreadcrumb(breadcrumb);

    XCTAssertNil(result, @"Breadcrumb should be filtered out");
}

- (void)testBeforeBreadcrumbsCallbackDoesNotFiltersOutNonDevServerOrDsnRequestBreadcrumbs
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedDictionary = @{
        @"dsn" : @"https://abc@def.ingest.sentry.io/1234567",
        @"devServerUrl" : @"http://localhost:8081"
    };
    SentryOptions *options = [RNSentryStart createOptionsWithDictionary:mockedDictionary
                                                                  error:&error];

    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] init];
    breadcrumb.type = @"http";
    breadcrumb.data = @{ @"url" : @"http://testurl.com/service" };

    SentryBreadcrumb *result = options.beforeBreadcrumb(breadcrumb);

    XCTAssertEqual(breadcrumb, result);
}

- (void)testBeforeBreadcrumbsCallbackKeepsBreadcrumbWhenDevServerUrlIsNotPassedAndDsnDoesNotMatch
{
    NSError *error = nil;

    NSDictionary *_Nonnull mockedDictionary = @{ // dsn is always validated in SentryOptions initialization
        @"dsn" : @"https://abc@def.ingest.sentry.io/1234567"
    };
    SentryOptions *options = [RNSentryStart createOptionsWithDictionary:mockedDictionary
                                                                  error:&error];

    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] init];
    breadcrumb.type = @"http";
    breadcrumb.data = @{ @"url" : @"http://testurl.com/service" };

    SentryBreadcrumb *result = options.beforeBreadcrumb(breadcrumb);

    XCTAssertEqual(breadcrumb, result);
}

- (void)testEventFromSentryCocoaReactNativeHasOriginAndEnvironmentTags
{
    SentryEvent *testEvent = [[SentryEvent alloc] init];
    testEvent.sdk = @{
        @"name" : @"sentry.cocoa.react-native",
    };

    [RNSentryStart setEventOriginTag:testEvent];

    XCTAssertEqual(testEvent.tags[@"event.origin"], @"ios");
    XCTAssertEqual(testEvent.tags[@"event.environment"], @"native");
}

- (void)testEventFromSentryReactNativeOriginAndEnvironmentTagsAreOverwritten
{
    SentryEvent *testEvent = [[SentryEvent alloc] init];
    testEvent.sdk = @{
        @"name" : @"sentry.cocoa.react-native",
    };
    testEvent.tags = @{
        @"event.origin" : @"testEventOriginTag",
        @"event.environment" : @"testEventEnvironmentTag",
    };

    [RNSentryStart setEventOriginTag:testEvent];

    XCTAssertEqual(testEvent.tags[@"event.origin"], @"ios");
    XCTAssertEqual(testEvent.tags[@"event.environment"], @"native");
}

void (^expectRejecterNotCalled)(NSString *, NSString *, NSError *)
    = ^(NSString *code, NSString *message, NSError *error) {
          @throw [NSException exceptionWithName:@"Promise Rejector should not be called."
                                         reason:nil
                                       userInfo:nil];
      };

uint64_t MOCKED_SYMBOL_ADDRESS = 123;
char const *MOCKED_SYMBOL_NAME = "symbolicatedname";

int
sucessfulSymbolicate(const void *, Dl_info *info)
{
    info->dli_saddr = (void *)MOCKED_SYMBOL_ADDRESS;
    info->dli_sname = MOCKED_SYMBOL_NAME;
    return 1;
}

- (void)prepareNativeFrameMocksWithLocalSymbolication:(BOOL)debug
{
    SentryOptions *sentryOptions = [[SentryOptions alloc] init];
    sentryOptions.debug = debug; // no local symbolication

    id sentrySDKMock = OCMClassMock([SentrySDK class]);
    OCMStub([(SentrySDK *)sentrySDKMock options]).andReturn(sentryOptions);

    id sentryDependencyContainerMock = OCMClassMock([SentryDependencyContainer class]);
    OCMStub(ClassMethod([sentryDependencyContainerMock sharedInstance]))
        .andReturn(sentryDependencyContainerMock);

    id sentryBinaryImageInfoMockOne = OCMClassMock([SentryBinaryImageInfo class]);
    OCMStub([(SentryBinaryImageInfo *)sentryBinaryImageInfoMockOne address])
        .andReturn([@112233 unsignedLongLongValue]);
    OCMStub([sentryBinaryImageInfoMockOne name]).andReturn(@"testnameone");

    id sentryBinaryImageInfoMockTwo = OCMClassMock([SentryBinaryImageInfo class]);
    OCMStub([(SentryBinaryImageInfo *)sentryBinaryImageInfoMockTwo address])
        .andReturn([@112233 unsignedLongLongValue]);
    OCMStub([sentryBinaryImageInfoMockTwo name]).andReturn(@"testnametwo");

    id sentryBinaryImageCacheMock = OCMClassMock([SentryBinaryImageCache class]);
    OCMStub([(SentryDependencyContainer *)sentryDependencyContainerMock binaryImageCache])
        .andReturn(sentryBinaryImageCacheMock);
    OCMStub([sentryBinaryImageCacheMock imageByAddress:[@123 unsignedLongLongValue]])
        .andReturn(sentryBinaryImageInfoMockOne);
    OCMStub([sentryBinaryImageCacheMock imageByAddress:[@456 unsignedLongLongValue]])
        .andReturn(sentryBinaryImageInfoMockTwo);

    NSDictionary *serializedDebugImage = @{
        @"uuid" : @"mockuuid",
        @"debug_id" : @"mockdebugid",
        @"type" : @"macho",
        @"image_addr" : @"0x000000000001b669",
    };
    id sentryDebugImageMock = OCMClassMock([SentryDebugMeta class]);
    OCMStub([sentryDebugImageMock serialize]).andReturn(serializedDebugImage);

    id sentryDebugImageProviderMock = OCMClassMock([SentryDebugImageProvider class]);
    OCMStub(
        [sentryDebugImageProviderMock
            getDebugImagesForImageAddressesFromCache:[NSSet setWithObject:@"0x000000000001b669"]])
        .andReturn(@[ sentryDebugImageMock ]);

    OCMStub([sentryDependencyContainerMock debugImageProvider])
        .andReturn(sentryDebugImageProviderMock);
}

- (void)testFetchNativeStackFramesByInstructionsServerSymbolication
{
    [self prepareNativeFrameMocksWithLocalSymbolication:NO];
    RNSentry *rnSentry = [[RNSentry alloc] init];
    NSDictionary *actual = [rnSentry fetchNativeStackFramesBy:@[ @123, @456 ]
                                                  symbolicate:sucessfulSymbolicate];

    NSDictionary *expected = @{
        @"debugMetaImages" : @[
            @{
                @"uuid" : @"mockuuid",
                @"debug_id" : @"mockdebugid",
                @"type" : @"macho",
                @"image_addr" : @"0x000000000001b669",
            },
        ],
        @"frames" : @[
            @{
                @"package" : @"testnameone",
                @"in_app" : @NO,
                @"platform" : @"cocoa",
                @"instruction_addr" : @"0x000000000000007b", // 123
                @"image_addr" : @"0x000000000001b669", // 112233
            },
            @{
                @"package" : @"testnametwo",
                @"in_app" : @NO,
                @"platform" : @"cocoa",
                @"instruction_addr" : @"0x00000000000001c8", // 456
                @"image_addr" : @"0x000000000001b669", // 445566
            },
        ],
    };
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

- (void)testFetchNativeStackFramesByInstructionsOnDeviceSymbolication
{
    [self prepareNativeFrameMocksWithLocalSymbolication:YES];
    RNSentry *rnSentry = [[RNSentry alloc] init];
    NSDictionary *actual = [rnSentry fetchNativeStackFramesBy:@[ @123, @456 ]
                                                  symbolicate:sucessfulSymbolicate];

    NSDictionary *expected = @{
        @"frames" : @[
            @{
                @"function" : @"symbolicatedname",
                @"package" : @"testnameone",
                @"in_app" : @NO,
                @"platform" : @"cocoa",
                @"symbol_addr" : @"0x000000000000007b", // 123
                @"instruction_addr" : @"0x000000000000007b", // 123
                @"image_addr" : @"0x000000000001b669", // 112233
            },
            @{
                @"function" : @"symbolicatedname",
                @"package" : @"testnametwo",
                @"in_app" : @NO,
                @"platform" : @"cocoa",
                @"symbol_addr" : @"0x000000000000007b", // 123
                @"instruction_addr" : @"0x00000000000001c8", // 456
                @"image_addr" : @"0x000000000001b669", // 445566
            },
        ],
    };
    XCTAssertTrue([actual isEqualToDictionary:expected]);
}

@end
