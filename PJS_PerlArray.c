#include "JS.h"

static const char *PerlArrayPkg = NAMESPACE"PerlArray";

#define PJS_ARRAY_CHECK	                     \
    if(SvTYPE(av) != SVt_PVAV) {             \
	JS_ReportError(cx, "Not an ARRAY");  \
	return JS_FALSE;                     \
    }


static JSBool
perlarray_get(
    JSContext *cx,
    JSObject *obj,
    jsval id,
    jsval *vp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    JSBool ok = JS_TRUE;

    PJS_ARRAY_CHECK

    if(JSVAL_IS_INT(id)) {
        I32 ix = JSVAL_TO_INT(id);
        SV **v;
	ENTER; SAVETMPS;
        v = av_fetch(av, ix, 0);
        if(v) {
	    if(SvGMAGICAL(*v)) mg_get(*v);
            ok = PJS_ReflectPerl2JS(cx, obj, sv_mortalcopy(*v), vp);
        }
        else {
            JS_ReportError(cx, "Failed to retrieve element at index: %d", ix);
            ok = JS_FALSE;
        }
	FREETMPS; LEAVE;
    }
    
    return ok;
}

static JSBool
perlarray_set(
    JSContext *cx,
    JSObject *obj,
    jsval id,
    jsval *vp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);

    PJS_ARRAY_CHECK

    if(JSVAL_IS_INT(id)) {
        IV ix = JSVAL_TO_INT(id);
        SV *sv;
        if(!PJS_ReflectJS2Perl(cx, *vp, &sv, 1)) {
            JS_ReportError(cx, "Failed to convert argument to Perl");
            return JS_FALSE;
        }
        if(!av_store(av, ix, sv)) {
	    if(SvRMAGICAL(av)) mg_set(sv);
	    sv_free(sv);
	}
    }
    
    return JS_TRUE;
}

static JSBool
perlarray_enumerate(
    JSContext *cx,
    JSObject *obj,
    JSIterateOp enum_op,
    jsval *statep,
    jsid  *idp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);

    PJS_ARRAY_CHECK

    if(enum_op == JSENUMERATE_INIT) {
	SV *cc = newSViv(0);
	*statep = PRIVATE_TO_JSVAL(cc);
	if(idp) {
	    I32 alen = av_len(av);
	    *idp = INT_TO_JSVAL(alen + 1);
	}
	return JS_TRUE;
    }
    if(enum_op == JSENUMERATE_NEXT) {
	SV *cc = (SV *)JSVAL_TO_PRIVATE(*statep);
	I32 alen = av_len(av);
	I32 curr;
	if(!SvIOK(cc)) {
	    JS_ReportError(cx, "Wrong Array iterator");
	    return JS_FALSE;
	}
	curr = (I32)SvIVX(cc);
	if(curr > alen) { // At end
	    *statep = JSVAL_NULL;
	    sv_free(cc);
	} else {
	    jsval key = INT_TO_JSVAL(curr);
	    SvIV_set(cc, (IV)(curr+1));
	    return JS_ValueToId(cx, key, idp);
	}
    }
    return JS_TRUE;
}

static JSBool
perlarray_resolve(
    JSContext *cx,
    JSObject *obj,
    jsval id,
    uintN flags,
    JSObject **objp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    SV **v;
    int index;

    PJS_ARRAY_CHECK

    if(JSVAL_IS_STRING(id))
	return JS_TRUE;

    if(JSVAL_IS_INT(id)) {
	index = JSVAL_TO_INT(id);
	v = av_fetch(av, index, 0);
	if(v) {
	    JSString *str = JS_ValueToString(cx,id);
	    if(!JS_DefineProperty(cx, obj, JS_GetStringBytes(str),
	                          JSVAL_VOID, NULL, NULL, 0))
		return JS_FALSE;
	    *objp = obj;
	}
    }
    return JS_TRUE;
}

JSClass perlarray_class = {
    "PerlArray",
    JSCLASS_PRIVATE_IS_PERL | JSCLASS_NEW_ENUMERATE | JSCLASS_NEW_RESOLVE,
    JS_PropertyStub, JS_PropertyStub, perlarray_get, perlarray_set,
    (JSEnumerateOp)perlarray_enumerate, (JSResolveOp)perlarray_resolve,
    JS_ConvertStub, PJS_UnrootJSVis,
    JSCLASS_NO_OPTIONAL_MEMBERS
};

JSObject *
PJS_NewPerlArray(
    JSContext *cx,
    JSObject *parent,
    SV *ref
) {
    dTHX;
    return PJS_CreateJSVis(cx, JS_NewObject(cx, &perlarray_class, NULL, parent), ref);
}


static JSBool
perlarray_push(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    IV tmp;

    PJS_ARRAY_CHECK

    for(tmp = 0; tmp < argc; tmp++) {
	SV *sv;
	if(!PJS_ReflectJS2Perl(cx, argv[tmp], &sv, 1)) {
	    JS_ReportError(cx, "Failed to convert argument %d to Perl", tmp);
	    return JS_FALSE;
	}
	av_push(av, sv);
    }
    
    return JS_TRUE;
}

static JSBool
perlarray_unshift(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    IV tmp;

    PJS_ARRAY_CHECK

    if(argc) {
        av_unshift(av, argc);
        for(tmp = 0; tmp < argc; tmp++) {
            SV *sv;
            if(!PJS_ReflectJS2Perl(cx, argv[tmp], &sv, 1)) {
                JS_ReportError(cx, "Failed to convert argument %d to Perl", tmp);
                return JS_FALSE;
            }
            if(!av_store(av, tmp, sv)) {
		if(SvRMAGICAL(av)) mg_set(sv);
		sv_free(sv);
	    }
        }
    }
    
    return JS_TRUE;
}

static JSBool
perlarray_shift(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    SV *sv;
    JSBool ok;

    PJS_ARRAY_CHECK

    sv = av_shift(av);
    
    if(!sv || sv == &PL_sv_undef) {
        *rval = JSVAL_VOID;
        return JS_TRUE;
    }
    ENTER; SAVETMPS;
    ok = PJS_ReflectPerl2JS(cx, obj, sv_mortalcopy(sv), rval);
    FREETMPS; LEAVE;
    return ok;
}

static JSBool
perlarray_pop(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    SV *sv;
    JSBool ok;

    PJS_ARRAY_CHECK

    sv = av_pop(av);
    
    if(!sv || sv == &PL_sv_undef) {
        *rval = JSVAL_VOID;
        return JS_TRUE;
    }
    ENTER; SAVETMPS;
    ok = PJS_ReflectPerl2JS(cx, obj, sv_mortalcopy(sv), rval);
    FREETMPS; LEAVE;
    return ok;
}

static JSBool
perlarray_proplen_get(
    JSContext *cx,
    JSObject *obj,
    jsval id,
    jsval *vp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);

    PJS_ARRAY_CHECK

    *vp = INT_TO_JSVAL(av_len(av) + 1);
    
    return JS_TRUE;
}

static JSBool
perlarray_proplen_set(
    JSContext *cx, 
    JSObject *obj, 
    jsval id,
    jsval *vp
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, obj);
    AV *av = (AV *)SvRV(ref);
    int nlen = JSVAL_TO_INT(*vp);

    PJS_ARRAY_CHECK

    if(nlen < 0) {
	JS_ReportError(cx, "Illegal value for 'length'");
	return JS_FALSE;
    }

    av_fill(av, nlen - 1);

    return JS_TRUE;
}

static JSPropertySpec perlarray_props[] = {
    {"length", 0, JSPROP_PERMANENT, perlarray_proplen_get, perlarray_proplen_set },
    {0, 0, 0, 0, 0}
};

static JSFunctionSpec perlarray_methods[] = {
    {"push", perlarray_push, 1, 0, 0},
    {"unshift", perlarray_unshift, 1, 0, 0},
    {"shift", perlarray_shift, 0, 0, 0},
    {"pop", perlarray_pop, 0, 0, 0},
    {0, 0, 0, 0 ,0}
};

static JSBool
PerlArray(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    AV *av = newAV();
    SV *ref = newRV_noinc((SV *)av);
    uintN arg;
    JSBool ok = JS_FALSE;
    SV *sv;

    /* If the path fails, the object will be finalized */
    JS_SetPrivate(cx, obj, (void *)newRV(&PL_sv_undef));

    av_extend(av, argc);
    for(arg = 0; arg < argc; arg++) {
	if(!PJS_ReflectJS2Perl(cx, argv[arg], &sv, 1) ||
	   !av_store(av, arg, sv)) goto fail;
    }

    if(SvTRUE(get_sv(NAMESPACE"PerlArray::construct_blessed", 0)))
	sv_bless(ref, gv_stashpv(PerlArrayPkg,0));

    ok = PJS_CreateJSVis(cx, obj, ref) != NULL;
    fail:
    sv_free(ref);
    return ok;
}

JSObject *
PJS_InitPerlArrayClass(
    JSContext *cx,
    JSObject *global
) {
    dTHX;
    JSObject *proto;
    JSObject *stash = PJS_GetPackageObject(cx, PerlArrayPkg);
    proto = JS_InitClass(
        cx,
	global,
	stash,
	&perlarray_class,
	PerlArray, 0, 
        perlarray_props, perlarray_methods,
        NULL, NULL
    );
    if(!proto ||
       !JS_DefineProperty(cx, stash, PJS_PROXY_PROP,
	                  OBJECT_TO_JSVAL(proto), NULL, NULL, 0))
	return NULL;

    return PJS_CreateJSVis(cx, proto,
		newRV_inc((SV *)get_av(NAMESPACE"PerlArray::prototype",1)));
}
