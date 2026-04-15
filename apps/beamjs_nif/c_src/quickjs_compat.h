#ifndef QUICKJS_COMPAT_H
#define QUICKJS_COMPAT_H

/*
 * Compatibility layer between original QuickJS and QuickJS-ng.
 *
 * Original QuickJS (Bellard, used on Linux/macOS):
 *   JS_IsArray(ctx, val)
 *   JS_IsError(ctx, val)
 *
 * QuickJS-ng (used on Windows):
 *   JS_IsArray(val)
 *   JS_IsError(val)
 */

#ifdef _WIN32
  /* QuickJS-ng: no ctx parameter */
  #define BEAMJS_IsArray(ctx, val)  JS_IsArray(val)
  #define BEAMJS_IsError(ctx, val)  JS_IsError(val)
#else
  /* Original QuickJS: ctx parameter required */
  #define BEAMJS_IsArray(ctx, val)  JS_IsArray(ctx, val)
  #define BEAMJS_IsError(ctx, val)  JS_IsError(ctx, val)
#endif

#endif /* QUICKJS_COMPAT_H */
