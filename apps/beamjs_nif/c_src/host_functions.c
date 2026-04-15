#include "host_functions.h"
#include "term_convert.h"
#include <string.h>
#include <stdio.h>

/*
 * Generic host function callback mechanism.
 *
 * When JS calls a host function:
 * 1. Convert JS args to Erlang terms
 * 2. Send {:host_call, fn_name, args} to the owner BEAM process
 * 3. Block on condvar (safe on dirty scheduler) waiting for reply
 * 4. Convert Erlang reply back to JS value
 *
 * This is the bridge between JS execution and BEAM OTP.
 */

static JSValue host_call_generic(JSContext *ctx, JSValueConst this_val,
                                  int argc, JSValueConst *argv,
                                  int magic, const char *fn_name) {
    BeamjsContext *bctx = JS_GetContextOpaque(ctx);
    if (!bctx) return JS_ThrowInternalError(ctx, "No BeamJS context");

    /* Build args list as Erlang terms */
    ErlNifEnv *msg_env = enif_alloc_env();

    ERL_NIF_TERM *erl_args = enif_alloc(sizeof(ERL_NIF_TERM) * argc);
    for (int i = 0; i < argc; i++) {
        erl_args[i] = js_value_to_erl(msg_env, ctx, argv[i]);
    }
    ERL_NIF_TERM args_list = enif_make_list_from_array(msg_env, erl_args, argc);
    enif_free(erl_args);

    /* Create function name binary */
    ERL_NIF_TERM fn_name_term;
    unsigned char *fn_buf = enif_make_new_binary(msg_env, strlen(fn_name), &fn_name_term);
    memcpy(fn_buf, fn_name, strlen(fn_name));

    /* Send {:host_call, fn_name, args} to owner */
    ERL_NIF_TERM msg = enif_make_tuple3(msg_env,
        enif_make_atom(msg_env, "host_call"),
        fn_name_term,
        args_list);

    if (!enif_send(NULL, &bctx->owner_pid, msg_env, msg)) {
        enif_free_env(msg_env);
        return JS_ThrowInternalError(ctx, "Failed to send to owner process");
    }
    enif_free_env(msg_env);

    /* Wait for reply from owner (blocks on dirty scheduler) */
    enif_mutex_lock(bctx->mutex);
    while (!bctx->host_reply_ready) {
        enif_cond_wait(bctx->host_reply_cond, bctx->mutex);
    }

    /* Convert reply to JS value */
    ERL_NIF_TERM reply = bctx->host_reply;
    ErlNifEnv *reply_env = bctx->host_reply_env;
    JSValue result = erl_term_to_js(reply_env, reply, ctx);

    bctx->host_reply_ready = 0;
    bctx->host_reply_env = NULL;
    enif_mutex_unlock(bctx->mutex);

    if (reply_env) {
        enif_free_env(reply_env);
    }

    return result;
}

/* Individual host function wrappers */
static JSValue js_beamjs_send(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "send");
}

static JSValue js_beamjs_self(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "self");
}

static JSValue js_beamjs_spawn(JSContext *ctx, JSValueConst this_val,
                                int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "spawn");
}

static JSValue js_beamjs_spawn_link(JSContext *ctx, JSValueConst this_val,
                                     int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "spawn_link");
}

static JSValue js_beamjs_receive(JSContext *ctx, JSValueConst this_val,
                                  int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "receive");
}

static JSValue js_beamjs_register(JSContext *ctx, JSValueConst this_val,
                                   int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "register");
}

static JSValue js_beamjs_whereis(JSContext *ctx, JSValueConst this_val,
                                  int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "whereis");
}

static JSValue js_beamjs_monitor(JSContext *ctx, JSValueConst this_val,
                                  int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "monitor");
}

static JSValue js_beamjs_link(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "link");
}

static JSValue js_beamjs_exit(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "exit");
}

static JSValue js_beamjs_call(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "call");
}

static JSValue js_beamjs_cast(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "cast");
}

static JSValue js_beamjs_reply(JSContext *ctx, JSValueConst this_val,
                                int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "reply");
}

static JSValue js_beamjs_start_gen_server(JSContext *ctx, JSValueConst this_val,
                                           int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "start_gen_server");
}

static JSValue js_beamjs_start_supervisor(JSContext *ctx, JSValueConst this_val,
                                           int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "start_supervisor");
}

static JSValue js_beamjs_log(JSContext *ctx, JSValueConst this_val,
                              int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "log");
}

static JSValue js_beamjs_task_async(JSContext *ctx, JSValueConst this_val,
                                     int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "task_async");
}

static JSValue js_beamjs_task_await(JSContext *ctx, JSValueConst this_val,
                                     int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "task_await");
}

static JSValue js_beamjs_agent_start(JSContext *ctx, JSValueConst this_val,
                                      int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "agent_start");
}

static JSValue js_beamjs_agent_get(JSContext *ctx, JSValueConst this_val,
                                    int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "agent_get");
}

static JSValue js_beamjs_agent_update(JSContext *ctx, JSValueConst this_val,
                                       int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "agent_update");
}

static JSValue js_beamjs_agent_stop(JSContext *ctx, JSValueConst this_val,
                                     int argc, JSValueConst *argv) {
    return host_call_generic(ctx, this_val, argc, argv, 0, "agent_stop");
}

/* Console functions (special: don't round-trip through owner for simple logging) */
static JSValue js_console_log(JSContext *ctx, JSValueConst this_val,
                               int argc, JSValueConst *argv) {
    for (int i = 0; i < argc; i++) {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str) {
            if (i > 0) fprintf(stdout, " ");
            fprintf(stdout, "%s", str);
            JS_FreeCString(ctx, str);
        }
    }
    fprintf(stdout, "\n");
    fflush(stdout);
    return JS_UNDEFINED;
}

static JSValue js_console_error(JSContext *ctx, JSValueConst this_val,
                                 int argc, JSValueConst *argv) {
    for (int i = 0; i < argc; i++) {
        const char *str = JS_ToCString(ctx, argv[i]);
        if (str) {
            if (i > 0) fprintf(stderr, " ");
            fprintf(stderr, "%s", str);
            JS_FreeCString(ctx, str);
        }
    }
    fprintf(stderr, "\n");
    fflush(stderr);
    return JS_UNDEFINED;
}

void install_host_functions(BeamjsContext *bctx) {
    JSContext *ctx = bctx->ctx;
    JSValue global = JS_GetGlobalObject(ctx);

    /* Store context pointer so host functions can access it */
    JS_SetContextOpaque(ctx, bctx);

    /* Process functions */
    JS_SetPropertyStr(ctx, global, "__beamjs_send",
        JS_NewCFunction(ctx, js_beamjs_send, "__beamjs_send", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_self",
        JS_NewCFunction(ctx, js_beamjs_self, "__beamjs_self", 0));
    JS_SetPropertyStr(ctx, global, "__beamjs_spawn",
        JS_NewCFunction(ctx, js_beamjs_spawn, "__beamjs_spawn", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_spawn_link",
        JS_NewCFunction(ctx, js_beamjs_spawn_link, "__beamjs_spawn_link", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_receive",
        JS_NewCFunction(ctx, js_beamjs_receive, "__beamjs_receive", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_register",
        JS_NewCFunction(ctx, js_beamjs_register, "__beamjs_register", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_whereis",
        JS_NewCFunction(ctx, js_beamjs_whereis, "__beamjs_whereis", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_monitor",
        JS_NewCFunction(ctx, js_beamjs_monitor, "__beamjs_monitor", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_link",
        JS_NewCFunction(ctx, js_beamjs_link, "__beamjs_link", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_exit",
        JS_NewCFunction(ctx, js_beamjs_exit, "__beamjs_exit", 1));

    /* GenServer functions */
    JS_SetPropertyStr(ctx, global, "__beamjs_call",
        JS_NewCFunction(ctx, js_beamjs_call, "__beamjs_call", 3));
    JS_SetPropertyStr(ctx, global, "__beamjs_cast",
        JS_NewCFunction(ctx, js_beamjs_cast, "__beamjs_cast", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_reply",
        JS_NewCFunction(ctx, js_beamjs_reply, "__beamjs_reply", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_start_gen_server",
        JS_NewCFunction(ctx, js_beamjs_start_gen_server, "__beamjs_start_gen_server", 4));

    /* Supervisor functions */
    JS_SetPropertyStr(ctx, global, "__beamjs_start_supervisor",
        JS_NewCFunction(ctx, js_beamjs_start_supervisor, "__beamjs_start_supervisor", 1));

    /* Logging */
    JS_SetPropertyStr(ctx, global, "__beamjs_log",
        JS_NewCFunction(ctx, js_beamjs_log, "__beamjs_log", 2));

    /* Task functions */
    JS_SetPropertyStr(ctx, global, "__beamjs_task_async",
        JS_NewCFunction(ctx, js_beamjs_task_async, "__beamjs_task_async", 1));
    JS_SetPropertyStr(ctx, global, "__beamjs_task_await",
        JS_NewCFunction(ctx, js_beamjs_task_await, "__beamjs_task_await", 2));

    /* Agent functions */
    JS_SetPropertyStr(ctx, global, "__beamjs_agent_start",
        JS_NewCFunction(ctx, js_beamjs_agent_start, "__beamjs_agent_start", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_agent_get",
        JS_NewCFunction(ctx, js_beamjs_agent_get, "__beamjs_agent_get", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_agent_update",
        JS_NewCFunction(ctx, js_beamjs_agent_update, "__beamjs_agent_update", 2));
    JS_SetPropertyStr(ctx, global, "__beamjs_agent_stop",
        JS_NewCFunction(ctx, js_beamjs_agent_stop, "__beamjs_agent_stop", 1));

    /* Console object */
    JSValue console = JS_NewObject(ctx);
    JS_SetPropertyStr(ctx, console, "log",
        JS_NewCFunction(ctx, js_console_log, "log", 1));
    JS_SetPropertyStr(ctx, console, "info",
        JS_NewCFunction(ctx, js_console_log, "info", 1));
    JS_SetPropertyStr(ctx, console, "warn",
        JS_NewCFunction(ctx, js_console_error, "warn", 1));
    JS_SetPropertyStr(ctx, console, "error",
        JS_NewCFunction(ctx, js_console_error, "error", 1));
    JS_SetPropertyStr(ctx, global, "console", console);

    JS_FreeValue(ctx, global);
}
