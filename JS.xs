#include "JS.h"

#undef SHADOW /* perl.h includes shadow.h, clash with jsatom.h  */
#include "jsscript.h"

JSObject *
PJS_GetScope(
    JSContext *cx,
    SV *sv
) {
    dTHX;
    jsval val;
    JSObject *newobj = NULL;
    if(!SvOK(sv))
	return JS_GetGlobalObject(cx);

    if(SvROK(sv) && sv_derived_from(sv, PJS_RAW_OBJECT))
	return INT2PTR(JSObject *, SvIV((SV*)SvRV(sv)));

    if(PJS_ReflectPerl2JS(cx, NULL, sv, &val) && JSVAL_IS_OBJECT(val))
	return JSVAL_TO_OBJECT(val);

    if(JS_ValueToObject(cx, val, &newobj) && newobj)
	return newobj;

    croak("%s not a valid value for 'this'", SvPV_nolen(sv));
    return NULL;
}

static JSScript *
PJS_MakeScript(
    JSContext *cx,
    JSObject *scope,
    SV *source,
    const char *name
) {
    svtype type = SvTYPE(source);
    JSScript *script;

    if(!SvOK(source)) {
	if(strlen(name))
	    script = JS_CompileFile(cx, scope, name);
	else 
	    croak("Must supply a STRING or FileName");
    } else if(SvROK(source) || type == SVt_PVIO || type == SVt_PVGV) {
	FILE *file = PerlIO_findFILE(IoIFP(sv_2io(source)));
	if(!file) croak("FD not opened");
	script = JS_CompileFileHandle(cx, scope, name, file);
#if JS_VERSION < 180
	PerlIO_releaseFILE(IoIFP(sv_2io(source)), file);
#endif
    } else {
	STRLEN len;
	char *src = SvPV(source, len);
	script = JS_CompileScript(cx, scope, src, len, name, 1);
    }
    return script;
}

MODULE = JSP     PACKAGE = JSP
PROTOTYPES: DISABLE

char *
js_get_engine_version()
    CODE:
	RETVAL = (char *)JS_GetImplementationVersion();
    OUTPUT:
	RETVAL

IV
get_internal_version()
    CODE:
	RETVAL = (IV)JS_VERSION;
    OUTPUT:
	RETVAL

SV*
does_support_utf8(...)
    CODE:
	PERL_UNUSED_VAR(items); /* -W */
	RETVAL = JS_CStringsAreUTF8() ? &PL_sv_yes : &PL_sv_no;
    OUTPUT:
	RETVAL

SV*
does_support_e4x(...)
    CODE:
	PERL_UNUSED_VAR(items); /* -W */
	RETVAL = JS_HAS_XML_SUPPORT ? &PL_sv_yes : &PL_sv_no;
    OUTPUT:
	RETVAL

SV*
does_support_threading(...)
    CODE:
	PERL_UNUSED_VAR(items); /* -W */
#ifdef JS_THREADING
	RETVAL = &PL_sv_yes;
#else
	RETVAL = &PL_sv_no;
#endif
    OUTPUT:
	RETVAL

void
jsvisitor(sv)
    SV *sv
    PPCODE:
	if(SvOK(sv) && SvROK(sv) && (sv = SvRV(sv)) && SvMAGICAL(sv)) {
	    MAGIC *mg = mg_find(sv, PERL_MAGIC_jsvis);
	    while(mg) {
		if(mg->mg_type == PERL_MAGIC_jsvis && mg->mg_private == 0x4a53) {
		    jsv_mg *jsvis = (jsv_mg *)mg->mg_ptr;
		    XPUSHs(sv_2mortal(newSViv(PTR2IV(jsvis->pcx))));
		}
		mg = mg->mg_moremagic;
	    }
	}

MODULE = JSP     PACKAGE = JSP::RawRT	PREFIX = jsr_

JSP::RawRT
jsr_create(maxbytes)
    int maxbytes
    CODE:
	Newxz(RETVAL, 1, PJS_Runtime);
	if(!RETVAL) XSRETURN_UNDEF;
	RETVAL->rt = JS_NewRuntime(maxbytes);
	if(!RETVAL->rt) {
	    Safefree(RETVAL);
	    croak("Failed to create Runtime");
	}
    OUTPUT:
	RETVAL

void
jsr_DESTROY(runtime)
    JSP::RawRT runtime
    CODE:
	if(!PL_dirty) JS_DestroyRuntime(runtime->rt);
	runtime->rt = NULL;
	Safefree(runtime);

MODULE = JSP     PACKAGE = JSP::Context

JSP::Context 
create(rt)
    JSP::RawRT rt;
    CODE:
	RETVAL = PJS_CreateContext(rt, ST(0));
    OUTPUT:
	RETVAL

void
DESTROY(pcx)
    JSP::Context pcx;
    CODE:
	PJS_DestroyContext(pcx);

void
jsc_begin_request(pcx)
    JSP::Context pcx;
    CODE:
	PJS_BeginRequest(PJS_GetJSContext(pcx));

void
jsc_end_request(pcx)
    JSP::Context pcx;
    CODE:
	PJS_EndRequest(PJS_GetJSContext(pcx));

const char *
get_version(pcx)
    JSP::Context pcx;
    CODE:
	RETVAL = JS_VersionToString(JS_GetVersion(PJS_GetJSContext(pcx)));
    OUTPUT:
	RETVAL

const char *
set_version(pcx, version)
    JSP::Context pcx;
    const char *version;
    CODE:
	RETVAL = JS_VersionToString(JS_SetVersion(
	    PJS_GetJSContext(pcx), JS_StringToVersion(version)
	));
    OUTPUT:
	RETVAL

U32
jsc_get_options(pcx)
    JSP::Context pcx;
    CODE:
	RETVAL = JS_GetOptions(PJS_GetJSContext(pcx));
    OUTPUT:
	RETVAL

U32
jsc_set_options(pcx, options)
    JSP::Context pcx;
    U32	    options;
    CODE:
	RETVAL = JS_SetOptions(PJS_GetJSContext(pcx), options);
    OUTPUT:
	RETVAL
    
void
jsc_toggle_options(pcx, options)
    JSP::Context pcx;
    U32         options;
    CODE:
	JS_ToggleOptions(PJS_GetJSContext(pcx), options);


#ifdef JS_HAS_BRANCH_HANDLER
void
jsc_set_branch_handler(pcx, handler)
    JSP::Context pcx;
    SV *handler;
    CODE:
	if (!SvOK(handler)) {
	    /* Remove handler */
	    sv_free(pcx->branch_handler);
	    pcx->branch_handler = NULL;
	    JS_SetBranchCallback(PJS_GetJSContext(pcx), NULL);
	}
	else if (SvROK(handler) && SvTYPE(SvRV(handler)) == SVt_PVCV) {
	    sv_free(pcx->branch_handler);
	    pcx->branch_handler = SvREFCNT_inc_simple_NN(handler);
	    JS_SetBranchCallback(PJS_GetJSContext(pcx), PJS_branch_handler);
	}

#endif

SV *
jsc_rta(pcx)
    JSP::Context pcx;
    CODE:
	RETVAL = SvREFCNT_inc_simple_NN(pcx->rrt);
    OUTPUT:
	RETVAL

SV *
jsvisitor(pcx, sv)
    JSP::Context pcx;
    SV *sv
    ALIAS:
    _isjsvis = 1
    CODE:
	RETVAL = NULL;
	if(SvOK(sv) && SvROK(sv) && (sv = SvRV(sv)) && SvMAGICAL(sv)) {
	    MAGIC *mg = mg_find(sv, PERL_MAGIC_jsvis);
	    jsv_mg *jsvis;
	    while(mg) {
		if(mg->mg_type == PERL_MAGIC_jsvis &&
		   mg->mg_private == 0x4a53 &&
		  (jsvis = (jsv_mg *)mg->mg_ptr) &&
		  jsvis->pcx == pcx
		) {
		    if(!ix) {
			AV *avbox;
			SV **myref;
			JSObject *object = jsvis->object;
			SV *robj = newSV(0);
			SV *rjsv = newSV(0);
			sv_setref_pv(robj, PJS_RAW_OBJECT, (void*)object);
			sv_setref_iv(rjsv, PJS_RAW_JSVAL, (IV)OBJECT_TO_JSVAL(object));
			RETVAL = PJS_call_perl_method(jsvis->pcx->cx,
			    "__new",
			    sv_2mortal(newSVpv("JSP::Visitor", 0)),	// package
			    sv_2mortal(robj),			// content
			    sv_2mortal(rjsv),			// jsval
			    NULL
			);
			avbox = (AV *)SvRV(SvRV(RETVAL));
			myref = av_fetch(avbox, 6, 1); /* Overload Array cache slot */
			sv_setsv(*myref, ST(1));
			sv_rvweaken(*myref);
			SvREFCNT_inc_void_NN(RETVAL);
		    } else RETVAL = &PL_sv_yes;
		    break;
		}
		else mg = mg->mg_moremagic;
	    }
	    if(!RETVAL) XSRETURN_UNDEF; /* None found */
	}
	else XSRETURN_UNDEF;
    OUTPUT:
	RETVAL

void
jsc_unbind_value(pcx, parent, name)
    JSP::Context pcx;
    char *parent;
    char *name;
    PREINIT:
	JSContext *cx;
	jsval pval,val;
	JSObject *gobj, *pobj;
    CODE:
	cx = PJS_GetJSContext(pcx);
	gobj = JS_GetGlobalObject(cx);

	if (strlen(parent)) {
	    if(JS_EvaluateScript(cx, gobj, parent, strlen(parent), "", 1, &pval) &&
	       JSVAL_IS_OBJECT(pval))
		pobj = JSVAL_TO_OBJECT(pval);
	    else
		croak("No property '%s' exists", parent);
	}
	else pobj = gobj;

	if(!JS_DeleteProperty2(cx, pobj, name, &val))
	    croak("Failed to unbind %s", name);
	if(val != JSVAL_TRUE)
	    croak("Can't delete %s", name);

SV*
get_global(pcx)
    JSP::Context pcx;
    CODE:
	if(!PJS_ReflectJS2Perl(pcx->cx,
		      OBJECT_TO_JSVAL(JS_GetGlobalObject(pcx->cx)),
		      &RETVAL,
		      0) // Return untied wrapper
	) {
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
	};
    OUTPUT:
	RETVAL

SV*
new_object(pcx, parent)
    JSP::Context pcx;
    JSObject *parent = NO_INIT;
    PREINIT:
	JSContext *cx;
	JSObject *newobj;
    CODE:
	cx = PJS_GetJSContext(pcx);
	parent = PJS_GetScope(cx, ST(1));
	newobj = JS_NewObject(cx, NULL, NULL, parent);
	if(!newobj || !PJS_ReflectJS2Perl(cx, OBJECT_TO_JSVAL(newobj), &RETVAL, 0)) {
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
	}
    OUTPUT:
	RETVAL

SV* 
jsc_eval(pcx, scope, source, name = "")
    JSP::Context pcx;
    JSObject *scope = NO_INIT;
    SV *source;
    const char *name;
    PREINIT:
	jsval rval;
	JSContext *cx;
	JSScript *script;
	JSBool ok = JS_FALSE;
    CODE:
	cx = PJS_GetJSContext(pcx);
	scope = PJS_GetScope(cx, ST(1));

	sv_setsv(ERRSV, &PL_sv_undef);

	script = PJS_MakeScript(cx, scope, source, name);

	if(script != NULL) {
	    ok = JS_ExecuteScript(cx, scope, script, &rval);
	    JS_DestroyScript(cx, script);
	}
	if(!ok || !PJS_ReflectJS2Perl(cx, rval, &RETVAL, 1)) {
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
        }
	PJS_GC(cx);
    OUTPUT:
        RETVAL

SV*
jsc_call(pcx, scope, function, args)
    JSP::Context pcx;
    JSObject *scope = NO_INIT;
    SV *function;
    AV *args;
    PREINIT:
	JSContext *cx;
        jsval rval;
        jsval fval;
    CODE:
        cx = PJS_GetJSContext(pcx);
	scope = PJS_GetScope(cx, ST(1));

	if(sv_derived_from(function, PJS_FUNCTION_PACKAGE)) {
	    SV *box = SvRV(function);
	    SV **fref = av_fetch((AV *)SvRV(box), 2, 0);
	    fval = (jsval)SvIV(SvRV(*fref));
	} else if(sv_derived_from(function, PJS_RAW_JSVAL)) {
	    fval = (jsval)SvIVX(SvRV(function));
        } else {
	    char *name = SvPV_nolen(function);
	    JSObject *nextObj;

	    if (!JS_GetMethod(cx, scope, name, &nextObj, &fval))
		croak("No function named '%s' exists", name);

	    if(JSVAL_IS_VOID(fval) || JSVAL_IS_NULL(fval))
		croak("Undefined subroutine %s called\n", name);
	}

	if(!call_js_function(cx, scope, fval, args, &rval) ||
	   !PJS_ReflectJS2Perl(cx, rval, &RETVAL, 1))
	{
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
        }
	PJS_GC(cx);
    OUTPUT:
	RETVAL

SV *
jsc_can(pcx, scope, func)
    JSP::Context pcx;
    JSObject *scope = NO_INIT;
    SV *func;
    PREINIT:
	JSContext *cx;
	jsval val;
    CODE:
	cx = PJS_GetJSContext(pcx);
	scope = PJS_GetScope(cx, ST(1));

	if(sv_derived_from(func, PJS_FUNCTION_PACKAGE) ||
	   // Completeness and allow check if exported
	   (SvROK(func) && SvTYPE(SvRV(func)) == SVt_PVCV &&
	    SvMAGICAL(SvRV(func)) && mg_find(SvRV(func), PERL_MAGIC_jsvis))
	)
	    RETVAL = SvREFCNT_inc_simple_NN(func);
	else {
	    JSExceptionState *es = JS_SaveExceptionState(cx);
	    const char *fname = SvPV_nolen(func);
	    if(JS_GetProperty(cx, scope, fname, &val) &&
	       (JS_TypeOfValue(cx, val) == JSTYPE_FUNCTION
		|| JS_ValueToFunction(cx, val) != NULL)) {
		if(!PJS_ReflectJS2Perl(cx, val, &RETVAL, 1))
		    PJS_report_exception(pcx);
	    }
	    else RETVAL = &PL_sv_undef;
	    JS_RestoreExceptionState(cx, es);
	}
    OUTPUT:
	RETVAL

int
jsc_get_flag(pcx, flag)
    JSP::Context pcx;
    const char *flag;
    CODE:
	RETVAL = (int)PJS_GetFlag(pcx, flag);
    OUTPUT:
	RETVAL

void
jsc_set_flag(pcx, flag, val)
    JSP::Context pcx;
    const char *flag;
    int val;
    CODE:
	PJS_SetFlag(pcx, flag, val);

MODULE = JSP     PACKAGE = JSP::Script

jsval
jss_execute(pcx, scope, obj)
    JSP::Context pcx;
    JSObject *scope = NO_INIT;
    JSObject* obj;
    PREINIT:
	JSContext *cx;
    CODE:
	cx = PJS_GetJSContext(pcx);
	scope = PJS_GetScope(cx, ST(1));

	if(!JS_ExecuteScript(cx, scope, (JSScript *)JS_GetPrivate(cx, obj), &RETVAL)) {
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
	}
    OUTPUT:
	RETVAL

SV *
jss_compile(pcx, scope, source, name = "")
    JSP::Context pcx;
    JSObject *scope = NO_INIT;
    SV *source;
    const char *name;
    PREINIT:
	JSContext *cx;
        JSScript *script;
	JSObject *newobj;
    CODE:
	cx = PJS_GetJSContext(pcx);
	scope = PJS_GetScope(cx, ST(1));

	if(!(script = PJS_MakeScript(cx, scope, source, name)) ||
	   !(newobj = JS_NewScriptObject(cx, script)) ||
	   !PJS_ReflectJS2Perl(cx, OBJECT_TO_JSVAL(newobj), &RETVAL, 0)
	) {
	    PJS_report_exception(pcx);
	    XSRETURN_UNDEF;
	}
    OUTPUT:
	RETVAL

SV *
jss_prolog(pcx, obj)
    JSP::Context pcx;
    JSObject *obj;
    PREINIT:
	JSContext *cx;
	JSScript *script;
	char *prolog;
    CODE:
	cx = PJS_GetJSContext(pcx);
	script = (JSScript *)JS_GetPrivate(cx, obj);
	prolog = (char *)script->code;
#ifdef JS_HAS_JSOP_TRACE
	while(*prolog == (char)JSOP_TRACE)
	    prolog++;
#endif
	RETVAL = sv_setref_pvn(newSV(0), NULL, prolog,
	    (char *)script->main - prolog);
    OUTPUT:
	RETVAL

SV *
jss_getatom(pcx, obj, index)
    JSP::Context pcx;
    JSObject *obj;
    I16 index;
    PREINIT:
	JSContext *cx;
	JSScript *script;
    CODE:
	cx = PJS_GetJSContext(pcx);
	script = (JSScript *)JS_GetPrivate(cx, obj);

	RETVAL = newSVpv(JS_GetStringBytes(
			  JS_ValueToString(cx,ATOM_KEY(script->atomMap.vector[index]))
			), 0);
    OUTPUT:
	RETVAL
	
MODULE = JSP    PACKAGE = JSP::Controller

jsval
_get_stash(pcx, package)
    JSP::Context pcx;
    char *package;
    PREINIT:
	JSContext *cx;
    CODE:
	cx = PJS_GetJSContext(pcx);
	RETVAL = OBJECT_TO_JSVAL(PJS_GetPackageObject(cx, package));
    OUTPUT:
	RETVAL

MODULE = JSP	PACKAGE = JSP::Boolean

SV *
False()
    ALIAS:
	True = 1
    CODE:
	RETVAL = newSV(0);
	sv_setref_iv(RETVAL, PJS_BOOLEAN, (IV)ix);
    OUTPUT:
	RETVAL

BOOT:
    PJS_Context_SV = gv_fetchpv("JSP::Context::CURRENT", GV_ADDMULTI, SVt_IV);
    PJS_This = gv_fetchpv("JSP::This", GV_ADDMULTI, SVt_PV);
#if PJS_UTF8_NATIVE
    JS_SetCStringsAreUTF8();
#else
    eval_sv(sv_2mortal(newSVpv("require Encode",0)), G_DISCARD);
    if(SvTRUE(ERRSV)) croak(NULL);
#endif
