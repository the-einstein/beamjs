#ifndef TERM_CONVERT_H
#define TERM_CONVERT_H

#include "beamjs_nif.h"

/*
 * Convert an Erlang term to a QuickJS JSValue.
 * The caller owns the returned JSValue (must JS_FreeValue if not consumed).
 */
JSValue erl_term_to_js(ErlNifEnv *env, ERL_NIF_TERM term, JSContext *ctx);

/*
 * Convert a QuickJS JSValue to an Erlang term.
 * Returns an Erlang term in the given env.
 */
ERL_NIF_TERM js_value_to_erl(ErlNifEnv *env, JSContext *ctx, JSValue val);

/*
 * Convert a JS exception to an Erlang {:error, reason} term.
 */
ERL_NIF_TERM js_exception_to_erl(ErlNifEnv *env, JSContext *ctx);

#endif /* TERM_CONVERT_H */
