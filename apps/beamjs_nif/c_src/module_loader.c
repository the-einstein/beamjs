#include "module_loader.h"
#include "term_convert.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

/*
 * Module normalizer: converts relative paths and beamjs: specifiers
 * to canonical module names.
 */
char *beamjs_module_normalize(JSContext *ctx, const char *base_name,
                               const char *name, void *opaque) {
    /* beamjs:* modules are already canonical */
    if (strncmp(name, "beamjs:", 7) == 0) {
        char *result = js_strdup(ctx, name);
        return result;
    }

    /* Relative imports: resolve against base_name's directory */
    if (name[0] == '.' && (name[1] == '/' || (name[1] == '.' && name[2] == '/'))) {
        /* Find the directory of base_name */
        const char *last_slash = strrchr(base_name, '/');
        size_t dir_len = last_slash ? (size_t)(last_slash - base_name) : 0;

        size_t result_len = dir_len + 1 + strlen(name) + 4; /* +4 for .js extension */
        char *result = js_malloc(ctx, result_len + 1);
        if (dir_len > 0) {
            snprintf(result, result_len + 1, "%.*s/%s", (int)dir_len, base_name, name);
        } else {
            snprintf(result, result_len + 1, "%s", name);
        }
        return result;
    }

    /* Absolute or package name: pass through */
    char *result = js_strdup(ctx, name);
    return result;
}

/*
 * Module loader: loads module source code.
 * For beamjs:* modules, sends a request to the owner BEAM process.
 * For file modules, reads from disk via the owner process.
 */
JSModuleDef *beamjs_module_loader(JSContext *ctx, const char *module_name,
                                   void *opaque) {
    BeamjsContext *bctx = (BeamjsContext *)opaque;
    if (!bctx) return NULL;

    /* Send {:load_module, module_name} to owner process */
    ErlNifEnv *msg_env = enif_alloc_env();

    ERL_NIF_TERM name_term;
    size_t name_len = strlen(module_name);
    unsigned char *buf = enif_make_new_binary(msg_env, name_len, &name_term);
    memcpy(buf, module_name, name_len);

    ERL_NIF_TERM msg = enif_make_tuple2(msg_env,
        enif_make_atom(msg_env, "load_module"),
        name_term);

    if (!enif_send(NULL, &bctx->owner_pid, msg_env, msg)) {
        enif_free_env(msg_env);
        JS_ThrowReferenceError(ctx, "Cannot load module '%s': owner process dead", module_name);
        return NULL;
    }
    enif_free_env(msg_env);

    /* Wait for reply with module source */
    enif_mutex_lock(bctx->mutex);
    while (!bctx->host_reply_ready) {
        enif_cond_wait(bctx->host_reply_cond, bctx->mutex);
    }

    ERL_NIF_TERM reply = bctx->host_reply;
    ErlNifEnv *reply_env = bctx->host_reply_env;

    /* Check if reply is {:ok, source_binary} or {:error, reason} */
    int arity;
    const ERL_NIF_TERM *tuple;
    JSModuleDef *mod = NULL;

    if (enif_get_tuple(reply_env, reply, &arity, &tuple) && arity == 2) {
        char atom_buf[16];
        if (enif_get_atom(reply_env, tuple[0], atom_buf, sizeof(atom_buf), ERL_NIF_LATIN1)
            && strcmp(atom_buf, "ok") == 0) {
            ErlNifBinary source_bin;
            if (enif_inspect_binary(reply_env, tuple[1], &source_bin)) {
                /* Compile and evaluate the module */
                JSValue func_val = JS_Eval(ctx,
                    (const char *)source_bin.data, source_bin.size,
                    module_name,
                    JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY);

                if (!JS_IsException(func_val)) {
                    mod = JS_VALUE_GET_PTR(func_val);
                    /* The module needs to be evaluated to register its exports */
                    JSValue eval_result = JS_EvalFunction(ctx, func_val);
                    if (JS_IsException(eval_result)) {
                        /* Module evaluation failed */
                        JS_FreeValue(ctx, eval_result);
                        mod = NULL;
                    } else {
                        JS_FreeValue(ctx, eval_result);
                    }
                } else {
                    JS_FreeValue(ctx, func_val);
                }
            }
        }
    }

    bctx->host_reply_ready = 0;
    bctx->host_reply_env = NULL;
    enif_mutex_unlock(bctx->mutex);

    if (reply_env) {
        enif_free_env(reply_env);
    }

    if (!mod) {
        JS_ThrowReferenceError(ctx, "Could not load module '%s'", module_name);
    }

    return mod;
}
