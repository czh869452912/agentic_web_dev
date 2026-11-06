// Only the APIs found in DSH/Office's browser bundles; core-js detects native support.
import 'core-js/actual/promise/with-resolvers.js';
import 'core-js/actual/array/to-sorted.js';
import 'core-js/actual/url/can-parse.js';
import 'core-js/actual/url/parse.js';
import { installAbortSignalAny } from './signal-any.js';

installAbortSignalAny();
globalThis.__DSH_BROWSER_COMPAT__ = { version: 1 };
