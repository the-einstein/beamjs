#ifndef BEAMJS_NIF_H
#define BEAMJS_NIF_H

#include "erl_nif.h"
#include "quickjs/quickjs.h"

/* Context resource wrapping a QuickJS runtime+context */
typedef struct {
    JSRuntime *rt;
    JSContext *ctx;
    ErlNifPid owner_pid;
    ErlNifMutex *mutex;
    /* Host function callback synchronization */
    ErlNifCond *host_reply_cond;
    ErlNifEnv *host_reply_env;
    ERL_NIF_TERM host_reply;
    int host_reply_ready;
} BeamjsContext;

/* Resource type (defined in beamjs_nif.c) */
extern ErlNifResourceType *BEAMJS_CONTEXT_RESOURCE;

/* Atoms cache */
typedef struct {
    ERL_NIF_TERM atom_ok;
    ERL_NIF_TERM atom_error;
    ERL_NIF_TERM atom_undefined;
    ERL_NIF_TERM atom_null;
    ERL_NIF_TERM atom_true;
    ERL_NIF_TERM atom_false;
    ERL_NIF_TERM atom_host_call;
    ERL_NIF_TERM atom_host_reply;
    ERL_NIF_TERM atom_js_exception;
} BeamjsAtoms;

extern BeamjsAtoms beamjs_atoms;

#endif /* BEAMJS_NIF_H */
