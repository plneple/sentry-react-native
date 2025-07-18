/* eslint-disable complexity */
import type { Breadcrumb, BreadcrumbHint, Integration, Scope, SendFeedbackParams, UserFeedback } from '@sentry/core';
import { captureFeedback, getClient, getGlobalScope, getIntegrationsToSetup, getIsolationScope, initAndBind, logger, makeDsn, stackParserFromStackParserOptions, withScope as coreWithScope } from '@sentry/core';
import {
  defaultStackParser,
  makeFetchTransport,
} from '@sentry/react';
import * as React from 'react';

import { ReactNativeClient } from './client';
import { FeedbackWidgetProvider } from './feedback/FeedbackWidgetProvider';
import { getDevServer } from './integrations/debugsymbolicatorutils';
import { getDefaultIntegrations } from './integrations/default';
import type { ReactNativeClientOptions, ReactNativeOptions, ReactNativeWrapperOptions } from './options';
import { shouldEnableNativeNagger } from './options';
import { enableSyncToNative } from './scopeSync';
import { TouchEventBoundary } from './touchevents';
import { ReactNativeProfiler } from './tracing';
import { useEncodePolyfill } from './transports/encodePolyfill';
import { DEFAULT_BUFFER_SIZE, makeNativeTransportFactory } from './transports/native';
import { getDefaultEnvironment, isExpoGo, isRunningInMetroDevServer } from './utils/environment';
import { safeFactory, safeTracesSampler } from './utils/safe';
import { RN_GLOBAL_OBJ } from './utils/worldwide';
import { NATIVE } from './wrapper';

const DEFAULT_OPTIONS: ReactNativeOptions = {
  enableNativeCrashHandling: true,
  enableNativeNagger: true,
  autoInitializeNativeSdk: true,
  enableAutoPerformanceTracing: true,
  enableWatchdogTerminationTracking: true,
  patchGlobalPromise: true,
  sendClientReports: true,
  maxQueueSize: DEFAULT_BUFFER_SIZE,
  attachStacktrace: true,
  enableCaptureFailedRequests: false,
  enableNdk: true,
  enableAppStartTracking: true,
  enableNativeFramesTracking: true,
  enableStallTracking: true,
  enableUserInteractionTracing: false,
};

/**
 * Inits the SDK and returns the final options.
 */
export function init(passedOptions: ReactNativeOptions): void {
  if (isRunningInMetroDevServer()) {
    return;
  }

  const userOptions = {
    ...RN_GLOBAL_OBJ.__SENTRY_OPTIONS__,
    ...passedOptions,
  };

  const maxQueueSize = userOptions.maxQueueSize
    // eslint-disable-next-line deprecation/deprecation
    ?? userOptions.transportOptions?.bufferSize
    ?? DEFAULT_OPTIONS.maxQueueSize;

  const enableNative = userOptions.enableNative === undefined || userOptions.enableNative
    ? NATIVE.isNativeAvailable()
    : false;

  useEncodePolyfill();
  if (enableNative) {
    enableSyncToNative(getGlobalScope());
    enableSyncToNative(getIsolationScope());
  }

  const getURLFromDSN = (dsn: string | null): string | undefined => {
    if (!dsn) {
      return undefined;
    }
    const dsnComponents = makeDsn(dsn);
    if (!dsnComponents) {
      logger.error('Failed to extract url from DSN: ', dsn);
      return undefined;
    }
    const port = dsnComponents.port ? `:${dsnComponents.port}` : '';
    return `${dsnComponents.protocol}://${dsnComponents.host}${port}`;
  };

  const userBeforeBreadcrumb = safeFactory(userOptions.beforeBreadcrumb, { loggerMessage: 'The beforeBreadcrumb threw an error' });

  // Exclude Dev Server and Sentry Dsn request from Breadcrumbs
  const devServerUrl = getDevServer()?.url;
  const dsn = getURLFromDSN(userOptions.dsn);
  const defaultBeforeBreadcrumb = (breadcrumb: Breadcrumb, _hint?: BreadcrumbHint): Breadcrumb | null => {
    const type = breadcrumb.type || '';
    const url = typeof breadcrumb.data?.url === 'string' ? breadcrumb.data.url : '';
    if (type === 'http' && ((devServerUrl && url.startsWith(devServerUrl)) || (dsn && url.startsWith(dsn)))) {
      return null;
    }
    return breadcrumb;
  };

  const chainedBeforeBreadcrumb = (breadcrumb: Breadcrumb, hint?: BreadcrumbHint): Breadcrumb | null => {
    let modifiedBreadcrumb = breadcrumb;
    if (userBeforeBreadcrumb) {
      const result = userBeforeBreadcrumb(breadcrumb, hint);
      if (result === null) {
        return null;
      }
      modifiedBreadcrumb = result;
    }
    return defaultBeforeBreadcrumb(modifiedBreadcrumb, hint);
  };

  const options: ReactNativeClientOptions = {
    ...DEFAULT_OPTIONS,
    ...userOptions,
    enableNative,
    enableNativeNagger: shouldEnableNativeNagger(userOptions.enableNativeNagger),
    // If custom transport factory fails the SDK won't initialize
    transport: userOptions.transport
      || makeNativeTransportFactory({
        enableNative,
      })
      || makeFetchTransport,
    transportOptions: {
      ...DEFAULT_OPTIONS.transportOptions,
      ...(userOptions.transportOptions ?? {}),
      bufferSize: maxQueueSize,
    },
    maxQueueSize,
    integrations: [],
    stackParser: stackParserFromStackParserOptions(userOptions.stackParser || defaultStackParser),
    beforeBreadcrumb: chainedBeforeBreadcrumb,
    initialScope: safeFactory(userOptions.initialScope, { loggerMessage: 'The initialScope threw an error' }),
  };

  if (!('autoInitializeNativeSdk' in userOptions) && RN_GLOBAL_OBJ.__SENTRY_OPTIONS__) {
    // We expect users to use the file options only in combination with manual native initialization
    // eslint-disable-next-line no-console
    console.info('Initializing Sentry JS with the options file. Expecting manual native initialization before JS. Native will not be initialized automatically.');
    options.autoInitializeNativeSdk = false;
  }

  if ('tracesSampler' in options) {
    options.tracesSampler = safeTracesSampler(options.tracesSampler);
  }

  if (!('environment' in options)) {
    options.environment = getDefaultEnvironment();
  }

  const defaultIntegrations: false | Integration[] = userOptions.defaultIntegrations === undefined
    ? getDefaultIntegrations(options)
    : userOptions.defaultIntegrations;

  options.integrations = getIntegrationsToSetup({
    integrations: safeFactory(userOptions.integrations, { loggerMessage: 'The integrations threw an error' }),
    defaultIntegrations,
  });
  initAndBind(ReactNativeClient, options);

  if (isExpoGo()) {
    logger.info('Offline caching, native errors features are not available in Expo Go.');
    logger.info('Use EAS Build / Native Release Build to test these features.');
  }

  if (RN_GLOBAL_OBJ.__SENTRY_OPTIONS__) {
    logger.info('Sentry JS initialized with options from the options file.');
  }
}

/**
 * Inits the Sentry React Native SDK with automatic instrumentation and wrapped features.
 */
export function wrap<P extends Record<string, unknown>>(
  RootComponent: React.ComponentType<P>,
  options?: ReactNativeWrapperOptions
): React.ComponentType<P> {
  const profilerProps = {
    ...(options?.profilerProps ?? {}),
    name: RootComponent.displayName ?? 'Root',
  };

  const RootApp: React.FC<P> = (appProps) => {
    return (
      <TouchEventBoundary {...(options?.touchEventBoundaryProps ?? {})}>
        <ReactNativeProfiler {...profilerProps}>
          <FeedbackWidgetProvider>
            <RootComponent {...appProps} />
          </FeedbackWidgetProvider>
        </ReactNativeProfiler>
      </TouchEventBoundary>
    );
  };

  return RootApp;
}

/**
 * If native client is available it will trigger a native crash.
 * Use this only for testing purposes.
 */
export function nativeCrash(): void {
  NATIVE.nativeCrash();
}

/**
 * Flushes all pending events in the queue to disk.
 * Use this before applying any realtime updates such as code-push or expo updates.
 */
export async function flush(): Promise<boolean> {
  try {
    const client = getClient();

    if (client) {
      const result = await client.flush();

      return result;
    }
    // eslint-disable-next-line no-empty
  } catch (_) { }

  logger.error('Failed to flush the event queue.');

  return false;
}

/**
 * Closes the SDK, stops sending events.
 */
export async function close(): Promise<void> {
  try {
    const client = getClient();

    if (client) {
      await client.close();
    }
  } catch (e) {
    logger.error('Failed to close the SDK');
  }
}

/**
 * Captures user feedback and sends it to Sentry.
 * @deprecated Use `Sentry.captureFeedback` instead.
 */
export function captureUserFeedback(feedback: UserFeedback): void {
  const feedbackParams: SendFeedbackParams = {
    name: feedback.name,
    email: feedback.email,
    message: feedback.comments,
    associatedEventId: feedback.event_id,
  };
  captureFeedback(feedbackParams);
}

/**
 * Creates a new scope with and executes the given operation within.
 * The scope is automatically removed once the operation
 * finishes or throws.
 *
 * This is essentially a convenience function for:
 *
 *     pushScope();
 *     callback();
 *     popScope();
 *
 * @param callback that will be enclosed into push/popScope.
 */
export function withScope<T>(callback: (scope: Scope) => T): T | undefined {
  const safeCallback = (scope: Scope): T | undefined => {
    try {
      return callback(scope);
    } catch (e) {
      logger.error('Error while running withScope callback', e);
      return undefined;
    }
  };
  return coreWithScope(safeCallback);
}

/**
 * Returns if the app crashed in the last run.
 */
export async function crashedLastRun(): Promise<boolean | null> {
  return NATIVE.crashedLastRun();
}
