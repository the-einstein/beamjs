#ifndef MODULE_LOADER_H
#define MODULE_LOADER_H

#include "beamjs_nif.h"

/*
 * Module normalizer callback for QuickJS.
 * Resolves module specifiers (e.g., "beamjs:process" -> canonical name).
 */
char *beamjs_module_normalize(JSContext *ctx, const char *base_name,
                               const char *name, void *opaque);

/*
 * Module loader callback for QuickJS.
 * Loads module source by sending a request to the owning BEAM process.
 */
JSModuleDef *beamjs_module_loader(JSContext *ctx, const char *module_name,
                                   void *opaque);

#endif /* MODULE_LOADER_H */
