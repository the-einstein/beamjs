#ifndef HOST_FUNCTIONS_H
#define HOST_FUNCTIONS_H

#include "beamjs_nif.h"

/*
 * Install all host functions into a QuickJS context.
 * These are global JS functions that call back into the BEAM process.
 */
void install_host_functions(BeamjsContext *bctx);

#endif /* HOST_FUNCTIONS_H */
