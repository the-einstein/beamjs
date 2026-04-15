#include "term_convert.h"
#include <string.h>
#include <stdio.h>

/*
 * Erlang Term -> JS Value conversion
 *
 * Mapping:
 *   integer       -> Number (or BigInt for > 2^53)
 *   float         -> Number
 *   binary (utf8) -> String
 *   atom true     -> true
 *   atom false    -> false
 *   atom nil/null -> null
 *   atom undefined-> undefined
 *   other atom    -> String (atom name)
 *   list          -> Array
 *   map           -> Object
 *   tuple         -> Array (tagged tuples handled specially)
 */
JSValue erl_term_to_js(ErlNifEnv *env, ERL_NIF_TERM term, JSContext *ctx) {
    int i_val;
    long l_val;
    ErlNifSInt64 i64_val;
    double d_val;
    ErlNifBinary bin;
    unsigned atom_len;
    char atom_buf[256];
    int arity;
    const ERL_NIF_TERM *tuple_elems;
    unsigned list_len;

    /* Integer */
    if (enif_get_int(env, term, &i_val)) {
        return JS_NewInt32(ctx, i_val);
    }
    if (enif_get_long(env, term, &l_val)) {
        if (l_val >= -2147483648L && l_val <= 2147483647L) {
            return JS_NewInt32(ctx, (int32_t)l_val);
        }
        return JS_NewFloat64(ctx, (double)l_val);
    }
    if (enif_get_int64(env, term, &i64_val)) {
        if (i64_val >= -2147483648LL && i64_val <= 2147483647LL) {
            return JS_NewInt32(ctx, (int32_t)i64_val);
        }
        return JS_NewFloat64(ctx, (double)i64_val);
    }

    /* Float */
    if (enif_get_double(env, term, &d_val)) {
        return JS_NewFloat64(ctx, d_val);
    }

    /* Atom */
    if (enif_get_atom_length(env, term, &atom_len, ERL_NIF_LATIN1)) {
        if (atom_len < sizeof(atom_buf)) {
            enif_get_atom(env, term, atom_buf, sizeof(atom_buf), ERL_NIF_LATIN1);
            if (strcmp(atom_buf, "true") == 0) return JS_TRUE;
            if (strcmp(atom_buf, "false") == 0) return JS_FALSE;
            if (strcmp(atom_buf, "nil") == 0 || strcmp(atom_buf, "null") == 0)
                return JS_NULL;
            if (strcmp(atom_buf, "undefined") == 0) return JS_UNDEFINED;
            /* Other atoms become strings */
            return JS_NewStringLen(ctx, atom_buf, atom_len);
        }
    }

    /* Binary / String */
    if (enif_inspect_binary(env, term, &bin)) {
        return JS_NewStringLen(ctx, (const char *)bin.data, bin.size);
    }
    if (enif_inspect_iolist_as_binary(env, term, &bin)) {
        return JS_NewStringLen(ctx, (const char *)bin.data, bin.size);
    }

    /* Tuple -> Array (or special handling for tagged tuples) */
    if (enif_get_tuple(env, term, &arity, &tuple_elems)) {
        JSValue arr = JS_NewArray(ctx);
        for (int i = 0; i < arity; i++) {
            JSValue elem = erl_term_to_js(env, tuple_elems[i], ctx);
            JS_SetPropertyUint32(ctx, arr, i, elem);
        }
        return arr;
    }

    /* List -> Array */
    if (enif_get_list_length(env, term, &list_len)) {
        JSValue arr = JS_NewArray(ctx);
        ERL_NIF_TERM head, tail = term;
        unsigned idx = 0;
        while (enif_get_list_cell(env, tail, &head, &tail)) {
            JSValue elem = erl_term_to_js(env, head, ctx);
            JS_SetPropertyUint32(ctx, arr, idx++, elem);
        }
        return arr;
    }

    /* Map -> Object */
    if (enif_is_map(env, term)) {
        JSValue obj = JS_NewObject(ctx);
        ErlNifMapIterator iter;
        ERL_NIF_TERM key, value;
        if (enif_map_iterator_create(env, term, &iter, ERL_NIF_MAP_ITERATOR_FIRST)) {
            while (enif_map_iterator_get_pair(env, &iter, &key, &value)) {
                /* Convert key to string */
                char key_buf[512];
                if (enif_inspect_binary(env, key, &bin)) {
                    JSValue js_val = erl_term_to_js(env, value, ctx);
                    JSAtom atom = JS_NewAtomLen(ctx, (const char *)bin.data, bin.size);
                    JS_SetProperty(ctx, obj, atom, js_val);
                    JS_FreeAtom(ctx, atom);
                } else if (enif_get_atom(env, key, key_buf, sizeof(key_buf), ERL_NIF_LATIN1)) {
                    JSValue js_val = erl_term_to_js(env, value, ctx);
                    JSAtom atom = JS_NewAtom(ctx, key_buf);
                    JS_SetProperty(ctx, obj, atom, js_val);
                    JS_FreeAtom(ctx, atom);
                }
                enif_map_iterator_next(env, &iter);
            }
            enif_map_iterator_destroy(env, &iter);
        }
        return obj;
    }

    /* Fallback: convert to null */
    return JS_NULL;
}

/*
 * JS Value -> Erlang Term conversion
 */
ERL_NIF_TERM js_value_to_erl(ErlNifEnv *env, JSContext *ctx, JSValue val) {
    /* Undefined */
    if (JS_IsUndefined(val)) {
        return beamjs_atoms.atom_undefined;
    }

    /* Null */
    if (JS_IsNull(val)) {
        return beamjs_atoms.atom_null;
    }

    /* Boolean */
    if (JS_IsBool(val)) {
        return JS_ToBool(ctx, val) ? beamjs_atoms.atom_true : beamjs_atoms.atom_false;
    }

    /* Number */
    if (JS_VALUE_GET_TAG(val) == JS_TAG_INT) {
        int32_t i;
        JS_ToInt32(ctx, &i, val);
        return enif_make_int(env, i);
    }
    if (JS_IsNumber(val)) {
        double d;
        JS_ToFloat64(ctx, &d, val);
        /* If it's a whole number within int range, return integer */
        if (d == (double)(long)d && d >= -2147483648.0 && d <= 2147483647.0) {
            return enif_make_int(env, (int)d);
        }
        return enif_make_double(env, d);
    }

    /* String */
    if (JS_IsString(val)) {
        size_t len;
        const char *str = JS_ToCStringLen(ctx, &len, val);
        if (str) {
            ERL_NIF_TERM bin;
            unsigned char *buf = enif_make_new_binary(env, len, &bin);
            memcpy(buf, str, len);
            JS_FreeCString(ctx, str);
            return bin;
        }
        return beamjs_atoms.atom_null;
    }

    /* Array */
    if (JS_IsArray(val)) {
        JSValue length_val = JS_GetPropertyStr(ctx, val, "length");
        int64_t length;
        JS_ToInt64(ctx, &length, length_val);
        JS_FreeValue(ctx, length_val);

        ERL_NIF_TERM *items = enif_alloc(sizeof(ERL_NIF_TERM) * length);
        for (int64_t i = 0; i < length; i++) {
            JSValue elem = JS_GetPropertyUint32(ctx, val, (uint32_t)i);
            items[i] = js_value_to_erl(env, ctx, elem);
            JS_FreeValue(ctx, elem);
        }
        ERL_NIF_TERM list = enif_make_list_from_array(env, items, (unsigned)length);
        enif_free(items);
        return list;
    }

    /* Object (plain) -> Map */
    if (JS_IsObject(val)) {
        /* Check if it's a special object (Pid, Ref, etc.) */
        JSValue type_val = JS_GetPropertyStr(ctx, val, "__beamjs_type");
        if (JS_IsString(type_val)) {
            const char *type_str = JS_ToCString(ctx, type_val);
            if (type_str) {
                if (strcmp(type_str, "pid") == 0) {
                    /* Extract serialized PID data */
                    JSValue pid_data = JS_GetPropertyStr(ctx, val, "__beamjs_data");
                    ERL_NIF_TERM result = js_value_to_erl(env, ctx, pid_data);
                    JS_FreeValue(ctx, pid_data);
                    JS_FreeCString(ctx, type_str);
                    JS_FreeValue(ctx, type_val);
                    return result;
                }
                JS_FreeCString(ctx, type_str);
            }
        }
        JS_FreeValue(ctx, type_val);

        /* Regular object -> Erlang map */
        JSPropertyEnum *props;
        uint32_t prop_count;
        if (JS_GetOwnPropertyNames(ctx, &props, &prop_count, val,
                                    JS_GPN_STRING_MASK | JS_GPN_ENUM_ONLY) == 0) {
            ERL_NIF_TERM map = enif_make_new_map(env);
            for (uint32_t i = 0; i < prop_count; i++) {
                const char *key_str = JS_AtomToCString(ctx, props[i].atom);
                if (key_str) {
                    JSValue prop_val = JS_GetProperty(ctx, val, props[i].atom);

                    ERL_NIF_TERM key_term;
                    unsigned char *key_buf = enif_make_new_binary(env, strlen(key_str), &key_term);
                    memcpy(key_buf, key_str, strlen(key_str));

                    ERL_NIF_TERM val_term = js_value_to_erl(env, ctx, prop_val);
                    enif_make_map_put(env, map, key_term, val_term, &map);

                    JS_FreeValue(ctx, prop_val);
                    JS_FreeCString(ctx, key_str);
                }
                JS_FreeAtom(ctx, props[i].atom);
            }
            js_free(ctx, props);
            return map;
        }
        return beamjs_atoms.atom_null;
    }

    /* Fallback */
    return beamjs_atoms.atom_undefined;
}

/*
 * Convert the current JS exception to an Erlang {:error, reason} tuple.
 */
ERL_NIF_TERM js_exception_to_erl(ErlNifEnv *env, JSContext *ctx) {
    JSValue exc = JS_GetException(ctx);
    ERL_NIF_TERM reason;

    if (JS_IsError(exc)) {
        /* Get message and stack */
        JSValue msg_val = JS_GetPropertyStr(ctx, exc, "message");
        JSValue stack_val = JS_GetPropertyStr(ctx, exc, "stack");

        const char *msg = JS_ToCString(ctx, msg_val);
        const char *stack = JS_ToCString(ctx, stack_val);

        ERL_NIF_TERM msg_bin, stack_bin;
        if (msg) {
            unsigned char *buf = enif_make_new_binary(env, strlen(msg), &msg_bin);
            memcpy(buf, msg, strlen(msg));
            JS_FreeCString(ctx, msg);
        } else {
            msg_bin = enif_make_binary(env, &(ErlNifBinary){0, NULL});
        }
        if (stack) {
            unsigned char *buf = enif_make_new_binary(env, strlen(stack), &stack_bin);
            memcpy(buf, stack, strlen(stack));
            JS_FreeCString(ctx, stack);
        } else {
            stack_bin = enif_make_binary(env, &(ErlNifBinary){0, NULL});
        }

        JS_FreeValue(ctx, msg_val);
        JS_FreeValue(ctx, stack_val);

        reason = enif_make_tuple3(env,
            beamjs_atoms.atom_js_exception, msg_bin, stack_bin);
    } else {
        reason = js_value_to_erl(env, ctx, exc);
    }

    JS_FreeValue(ctx, exc);
    return enif_make_tuple2(env, beamjs_atoms.atom_error, reason);
}
