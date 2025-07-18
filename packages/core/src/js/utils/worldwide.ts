import type { InternalGlobal } from '@sentry/core';
import { GLOBAL_OBJ } from '@sentry/core';
import type { ErrorUtils } from 'react-native/types';

import type { ReactNativeOptions } from '../options';
import type { ExpoGlobalObject } from './expoglobalobject';
export interface HermesPromiseRejectionTrackingOptions {
  allRejections: boolean;
  onUnhandled: (id: string, error: unknown) => void;
  onHandled: (id: string) => void;
}

/** Internal Global object interface with common and Sentry specific properties */
export interface ReactNativeInternalGlobal extends InternalGlobal {
  __sentry_rn_v4_registered?: boolean;
  __sentry_rn_v5_registered?: boolean;
  HermesInternal?: {
    getRuntimeProperties?: () => Record<string, string | undefined>;
    enablePromiseRejectionTracker?: (options: HermesPromiseRejectionTrackingOptions) => void;
    hasPromise?: () => boolean;
  };
  Promise: unknown;
  __turboModuleProxy: unknown;
  nativeFabricUIManager: unknown;
  ErrorUtils?: ErrorUtils;
  expo?: ExpoGlobalObject;
  XMLHttpRequest?: typeof XMLHttpRequest;
  process?: {
    env?: {
      ___SENTRY_METRO_DEV_SERVER___?: string;
    };
  };
  __BUNDLE_START_TIME__?: number;
  nativePerformanceNow?: () => number;
  TextEncoder?: TextEncoder;
  alert?: (message: string) => void;
  __SENTRY_OPTIONS__?: ReactNativeOptions;
}

type TextEncoder = {
  new (): TextEncoder;
  encode(input?: string): Uint8Array;
};

/** Get's the global object for the current JavaScript runtime */
export const RN_GLOBAL_OBJ = GLOBAL_OBJ as ReactNativeInternalGlobal;
