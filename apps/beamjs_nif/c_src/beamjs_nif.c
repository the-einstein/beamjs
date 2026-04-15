#include "beamjs_nif.h"
#include "term_convert.h"
#include "host_functions.h"
#include "module_loader.h"
#include <string.h>
#include <stdio.h>

/* Global resource type */
ErlNifResourceType *BEAMJS_CONTEXT_RESOURCE = NULL;

/* Cached atoms */
BeamjsAtoms beamjs_atoms;

/* ============================================================
 * Resource destructor
 * Called when the owning BEAM process dies or resource is GC'd.
 * Frees the QuickJS runtime and all associated memory.
 * ============================================================ */
static void beamjs_context_dtor(ErlNifEnv *env, void *obj) {
    BeamjsContext *bctx = (BeamjsContext *)obj;
    if (bctx->ctx) {
        JS_FreeContext(bctx->ctx);
        bctx->ctx = NULL;
    }
    if (bctx->rt) {
        JS_FreeRuntime(bctx->rt);
        bctx->rt = NULL;
    }
    if (bctx->mutex) {
        enif_mutex_destroy(bctx->mutex);
        bctx->mutex = NULL;
    }
    if (bctx->host_reply_cond) {
        enif_cond_destroy(bctx->host_reply_cond);
        bctx->host_reply_cond = NULL;
    }
}

/* ============================================================
 * NIF: new_context/1
 * Creates a new QuickJS runtime + context.
 * Returns {:ok, ref} or {:error, reason}
 * ============================================================ */
static ERL_NIF_TERM nif_new_context(ErlNifEnv *env, int argc,
                                     const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx = enif_alloc_resource(BEAMJS_CONTEXT_RESOURCE,
                                               sizeof(BeamjsContext));
    memset(bctx, 0, sizeof(BeamjsContext));

    bctx->rt = JS_NewRuntime();
    if (!bctx->rt) {
        enif_release_resource(bctx);
        return enif_make_tuple2(env, beamjs_atoms.atom_error,
            enif_make_atom(env, "runtime_creation_failed"));
    }

    bctx->ctx = JS_NewContext(bctx->rt);
    if (!bctx->ctx) {
        JS_FreeRuntime(bctx->rt);
        bctx->rt = NULL;
        enif_release_resource(bctx);
        return enif_make_tuple2(env, beamjs_atoms.atom_error,
            enif_make_atom(env, "context_creation_failed"));
    }

    enif_self(env, &bctx->owner_pid);
    bctx->mutex = enif_mutex_create("beamjs_ctx");
    bctx->host_reply_cond = enif_cond_create("beamjs_reply");
    bctx->host_reply_ready = 0;
    bctx->host_reply_env = NULL;

    /* Set memory and stack limits */
    JS_SetMemoryLimit(bctx->rt, 256 * 1024 * 1024);  /* 256MB default */
    JS_SetMaxStackSize(bctx->rt, 4 * 1024 * 1024);     /* 4MB stack */

    /* Enable ES module support */
    JS_SetModuleLoaderFunc(bctx->rt, beamjs_module_normalize,
                           beamjs_module_loader, bctx);

    /* Install host functions (console.log, __beamjs_send, etc.) */
    install_host_functions(bctx);

    ERL_NIF_TERM ref = enif_make_resource(env, bctx);
    enif_release_resource(bctx);

    return enif_make_tuple2(env, beamjs_atoms.atom_ok, ref);
}

/* ============================================================
 * NIF: destroy_context/1
 * Explicitly destroys a QuickJS context.
 * ============================================================ */
static ERL_NIF_TERM nif_destroy_context(ErlNifEnv *env, int argc,
                                         const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    if (bctx->ctx) {
        JS_FreeContext(bctx->ctx);
        bctx->ctx = NULL;
    }
    if (bctx->rt) {
        JS_FreeRuntime(bctx->rt);
        bctx->rt = NULL;
    }

    return beamjs_atoms.atom_ok;
}

/* ============================================================
 * NIF: eval/3 (DIRTY CPU SCHEDULER)
 * Evaluates JS source code in a context.
 * Returns {:ok, result} or {:error, reason}
 * ============================================================ */
static ERL_NIF_TERM nif_eval(ErlNifEnv *env, int argc,
                              const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    if (!bctx->ctx) {
        return enif_make_tuple2(env, beamjs_atoms.atom_error,
            enif_make_atom(env, "context_destroyed"));
    }

    ErlNifBinary source_bin;
    if (!enif_inspect_binary(env, argv[1], &source_bin)) {
        /* Try iolist */
        if (!enif_inspect_iolist_as_binary(env, argv[1], &source_bin)) {
            return enif_make_badarg(env);
        }
    }

    ErlNifBinary filename_bin;
    if (!enif_inspect_binary(env, argv[2], &filename_bin)) {
        if (!enif_inspect_iolist_as_binary(env, argv[2], &filename_bin)) {
            return enif_make_badarg(env);
        }
    }

    /* Null-terminate source and filename */
    char *source = enif_alloc(source_bin.size + 1);
    memcpy(source, source_bin.data, source_bin.size);
    source[source_bin.size] = '\0';

    char *filename = enif_alloc(filename_bin.size + 1);
    memcpy(filename, filename_bin.data, filename_bin.size);
    filename[filename_bin.size] = '\0';

    /* Update stack top for dirty scheduler thread */
    JS_UpdateStackTop(bctx->rt);

    /* Determine eval flags */
    int eval_flags = JS_EVAL_FLAG_STRICT;

    /* Check if source uses import/export (heuristic for module detection) */
    if (strstr(source, "import ") || strstr(source, "export ")) {
        eval_flags |= JS_EVAL_TYPE_MODULE;
    } else {
        eval_flags |= JS_EVAL_TYPE_GLOBAL;
    }

    /* Evaluate */
    JSValue result = JS_Eval(bctx->ctx, source, source_bin.size,
                              filename, eval_flags);

    /* Execute pending async jobs (microtask queue) */
    JSContext *pctx;
    while (JS_ExecutePendingJob(bctx->rt, &pctx) > 0) {}

    ERL_NIF_TERM erl_result;
    if (JS_IsException(result)) {
        erl_result = js_exception_to_erl(env, bctx->ctx);
    } else {
        ERL_NIF_TERM val = js_value_to_erl(env, bctx->ctx, result);
        erl_result = enif_make_tuple2(env, beamjs_atoms.atom_ok, val);
    }

    JS_FreeValue(bctx->ctx, result);
    enif_free(source);
    enif_free(filename);

    return erl_result;
}

/* ============================================================
 * NIF: call_function/3 (DIRTY CPU SCHEDULER)
 * Calls a global JS function by name with arguments.
 * Returns {:ok, result} or {:error, reason}
 * ============================================================ */
static ERL_NIF_TERM nif_call_function(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    if (!bctx->ctx) {
        return enif_make_tuple2(env, beamjs_atoms.atom_error,
            enif_make_atom(env, "context_destroyed"));
    }

    ErlNifBinary fn_name_bin;
    if (!enif_inspect_binary(env, argv[1], &fn_name_bin)) {
        if (!enif_inspect_iolist_as_binary(env, argv[1], &fn_name_bin)) {
            return enif_make_badarg(env);
        }
    }

    char *fn_name = enif_alloc(fn_name_bin.size + 1);
    memcpy(fn_name, fn_name_bin.data, fn_name_bin.size);
    fn_name[fn_name_bin.size] = '\0';

    /* Update stack top for dirty scheduler thread */
    JS_UpdateStackTop(bctx->rt);

    /* Get function from global object */
    JSValue global = JS_GetGlobalObject(bctx->ctx);
    JSValue func = JS_GetPropertyStr(bctx->ctx, global, fn_name);

    if (!JS_IsFunction(bctx->ctx, func)) {
        JS_FreeValue(bctx->ctx, func);
        JS_FreeValue(bctx->ctx, global);
        enif_free(fn_name);
        return enif_make_tuple2(env, beamjs_atoms.atom_error,
            enif_make_atom(env, "not_a_function"));
    }

    /* Convert args list to JSValue array */
    unsigned args_len;
    if (!enif_get_list_length(env, argv[2], &args_len)) {
        JS_FreeValue(bctx->ctx, func);
        JS_FreeValue(bctx->ctx, global);
        enif_free(fn_name);
        return enif_make_badarg(env);
    }

    JSValue *js_args = enif_alloc(sizeof(JSValue) * (args_len > 0 ? args_len : 1));
    ERL_NIF_TERM head, tail = argv[2];
    for (unsigned i = 0; i < args_len; i++) {
        enif_get_list_cell(env, tail, &head, &tail);
        js_args[i] = erl_term_to_js(env, head, bctx->ctx);
    }

    /* Call the function */
    JSValue result = JS_Call(bctx->ctx, func, global, args_len, js_args);

    /* Execute pending jobs */
    JSContext *pctx;
    while (JS_ExecutePendingJob(bctx->rt, &pctx) > 0) {}

    ERL_NIF_TERM erl_result;
    if (JS_IsException(result)) {
        erl_result = js_exception_to_erl(env, bctx->ctx);
    } else {
        ERL_NIF_TERM val = js_value_to_erl(env, bctx->ctx, result);
        erl_result = enif_make_tuple2(env, beamjs_atoms.atom_ok, val);
    }

    /* Cleanup */
    JS_FreeValue(bctx->ctx, result);
    for (unsigned i = 0; i < args_len; i++) {
        JS_FreeValue(bctx->ctx, js_args[i]);
    }
    enif_free(js_args);
    JS_FreeValue(bctx->ctx, func);
    JS_FreeValue(bctx->ctx, global);
    enif_free(fn_name);

    return erl_result;
}

/* ============================================================
 * NIF: set_global/3 (DIRTY CPU SCHEDULER)
 * Sets a global variable in the JS context.
 * ============================================================ */
static ERL_NIF_TERM nif_set_global(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    ErlNifBinary name_bin;
    if (!enif_inspect_binary(env, argv[1], &name_bin)) {
        if (!enif_inspect_iolist_as_binary(env, argv[1], &name_bin)) {
            return enif_make_badarg(env);
        }
    }

    char *name = enif_alloc(name_bin.size + 1);
    memcpy(name, name_bin.data, name_bin.size);
    name[name_bin.size] = '\0';

    JSValue global = JS_GetGlobalObject(bctx->ctx);
    JSValue js_val = erl_term_to_js(env, argv[2], bctx->ctx);
    JS_SetPropertyStr(bctx->ctx, global, name, js_val);
    JS_FreeValue(bctx->ctx, global);

    enif_free(name);
    return beamjs_atoms.atom_ok;
}

/* ============================================================
 * NIF: get_global/2 (DIRTY CPU SCHEDULER)
 * Gets a global variable from the JS context.
 * ============================================================ */
static ERL_NIF_TERM nif_get_global(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    ErlNifBinary name_bin;
    if (!enif_inspect_binary(env, argv[1], &name_bin)) {
        if (!enif_inspect_iolist_as_binary(env, argv[1], &name_bin)) {
            return enif_make_badarg(env);
        }
    }

    char *name = enif_alloc(name_bin.size + 1);
    memcpy(name, name_bin.data, name_bin.size);
    name[name_bin.size] = '\0';

    JSValue global = JS_GetGlobalObject(bctx->ctx);
    JSValue val = JS_GetPropertyStr(bctx->ctx, global, name);
    ERL_NIF_TERM result = js_value_to_erl(env, bctx->ctx, val);
    JS_FreeValue(bctx->ctx, val);
    JS_FreeValue(bctx->ctx, global);
    enif_free(name);

    return enif_make_tuple2(env, beamjs_atoms.atom_ok, result);
}

/* ============================================================
 * NIF: execute_pending_jobs/1 (DIRTY CPU SCHEDULER)
 * Runs the JS microtask queue.
 * ============================================================ */
static ERL_NIF_TERM nif_execute_pending_jobs(ErlNifEnv *env, int argc,
                                              const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    int count = 0;
    JSContext *pctx;
    while (JS_ExecutePendingJob(bctx->rt, &pctx) > 0) {
        count++;
    }

    return enif_make_tuple2(env, beamjs_atoms.atom_ok, enif_make_int(env, count));
}

/* ============================================================
 * NIF: deliver_host_reply/2
 * Called by the Elixir GenServer to deliver a reply to a blocked
 * host function call on the dirty scheduler.
 * ============================================================ */
static ERL_NIF_TERM nif_deliver_host_reply(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
    BeamjsContext *bctx;
    if (!enif_get_resource(env, argv[0], BEAMJS_CONTEXT_RESOURCE, (void **)&bctx)) {
        return enif_make_badarg(env);
    }

    enif_mutex_lock(bctx->mutex);

    /* Copy the reply into a new env that persists until the NIF reads it */
    ErlNifEnv *reply_env = enif_alloc_env();
    bctx->host_reply = enif_make_copy(reply_env, argv[1]);
    bctx->host_reply_env = reply_env;
    bctx->host_reply_ready = 1;

    enif_cond_signal(bctx->host_reply_cond);
    enif_mutex_unlock(bctx->mutex);

    return beamjs_atoms.atom_ok;
}

/* ============================================================
 * NIF function table
 * ============================================================ */
static ErlNifFunc nif_funcs[] = {
    {"new_context",          1, nif_new_context,          0},
    {"destroy_context",      1, nif_destroy_context,      0},
    {"eval",                 3, nif_eval,                 ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"call_function",        3, nif_call_function,        ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"set_global",           3, nif_set_global,           ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"get_global",           2, nif_get_global,           ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"execute_pending_jobs", 1, nif_execute_pending_jobs, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"deliver_host_reply",   2, nif_deliver_host_reply,   0},
};

/* ============================================================
 * NIF lifecycle callbacks
 * ============================================================ */
static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
    /* Register the resource type */
    BEAMJS_CONTEXT_RESOURCE = enif_open_resource_type(
        env, NULL, "beamjs_context",
        beamjs_context_dtor,
        ERL_NIF_RT_CREATE | ERL_NIF_RT_TAKEOVER,
        NULL);

    if (!BEAMJS_CONTEXT_RESOURCE) return -1;

    /* Cache atoms */
    beamjs_atoms.atom_ok = enif_make_atom(env, "ok");
    beamjs_atoms.atom_error = enif_make_atom(env, "error");
    beamjs_atoms.atom_undefined = enif_make_atom(env, "undefined");
    beamjs_atoms.atom_null = enif_make_atom(env, "nil");
    beamjs_atoms.atom_true = enif_make_atom(env, "true");
    beamjs_atoms.atom_false = enif_make_atom(env, "false");
    beamjs_atoms.atom_host_call = enif_make_atom(env, "host_call");
    beamjs_atoms.atom_host_reply = enif_make_atom(env, "host_reply");
    beamjs_atoms.atom_js_exception = enif_make_atom(env, "js_exception");

    return 0;
}

ERL_NIF_INIT(Elixir.BeamjsNif, nif_funcs, load, NULL, NULL, NULL)
