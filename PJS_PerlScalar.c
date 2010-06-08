#include "JS.h"

static const char *PerlScalarPkg = NAMESPACE"PerlScalar";

JSClass perlscalar_class = {
    "PerlScalar",
    JSCLASS_PRIVATE_IS_PERL,
    JS_PropertyStub, JS_PropertyStub, JS_PropertyStub, JS_PropertyStub,
    JS_EnumerateStub, JS_ResolveStub, JS_ConvertStub, PJS_UnrootJSVis,
    JSCLASS_NO_OPTIONAL_MEMBERS
};

JSObject *
PJS_NewPerlScalar(
    JSContext *cx,
    JSObject *parent,
    SV *sref
) {
    dTHX;
    JSObject *newobj = JS_NewObject(cx, &perlscalar_class, NULL, parent);
    return PJS_CreateJSVis(cx, newobj, sref);
}

static JSBool
perlscalar_value(
    JSContext *cx, 
    JSObject *obj, 
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *iref = (SV *)JS_GetPrivate(cx, obj);
    SV *ref = SvRV(iref);
    return PJS_ReflectPerl2JS(cx, obj, ref, rval);
}

static JSPropertySpec perlscalar_props[] = {
    {0, 0, 0, 0, 0}
};

static JSFunctionSpec perlscalar_methods[] = {
    {"valueOf", perlscalar_value, 0, 0, 0},
    {0, 0, 0, 0 ,0}
};

/* Public JS space constructor */
static JSBool
PerlScalar(
    JSContext *cx,
    JSObject *obj,
    uintN argc,
    jsval *argv,
    jsval *rval
) {
    dTHX;
    SV *ref = &PL_sv_undef;

    /* If the path fails, the object will be finalized */
    JS_SetPrivate(cx, obj, (void *)newRV(ref));

    if(argc == 1 && !PJS_ReflectJS2Perl(cx, argv[0], &ref, 1))
	return JS_FALSE;

    return PJS_ReflectPerl2JS(cx, JS_GetParent(cx, obj),
	                           newRV_noinc(ref), rval);
}


JSObject *
PJS_InitPerlScalarClass(
    JSContext *cx,
    JSObject *global
) {
    dTHX;
    JSObject *proto;
    JSObject *stash = PJS_GetPackageObject(cx, PerlScalarPkg);
    proto = JS_InitClass(
        cx, global,
	stash,
	&perlscalar_class,
	PerlScalar, 1, 
        perlscalar_props,
	perlscalar_methods,
        NULL, NULL
    );
    JS_DefineProperty(cx, stash, PJS_PROXY_PROP,
	              OBJECT_TO_JSVAL(proto), NULL, NULL, 0);
    return PJS_CreateJSVis(cx, proto,
		get_sv(NAMESPACE"PerlScalar::prototype", 1));
}
