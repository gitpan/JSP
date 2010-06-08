#include "JS.h"

PJS_GTYPEDEF(JSObject, RawObj);

MODULE = JSP::RawObj	PACKAGE = JSP::RawObj PREFIX = rop_
PROTOTYPES: DISABLE

const char *
get_class_name(object, pcx)
    JSP::Context pcx;
    JSP::RawObj object;
    CODE:
	RETVAL = PJS_GET_CLASS(PJS_GetJSContext(pcx), object)->name;
    OUTPUT:
	RETVAL

void 
rop_seal_object(object, pcx, deep = 0)
    JSP::Context pcx;
    JSP::RawObj	object;
    U32	    deep;
    CODE:
	JS_SealObject(PJS_GetJSContext(pcx), object, (JSBool)deep);

#define PJS_EL_MODE_FLAG	2

int
rop_set_prop(dest, pcx, name, val)
    JSP::RawObj  dest;
    JSP::Context pcx;
    SV *name;
    SV *val;
    ALIAS:
	set_elem = 2
    PREINIT:
	JSBool ok = JS_FALSE;
	jsval rval;
	JSContext *cx;
    CODE:
	cx = PJS_GetJSContext(pcx);

	ok = PJS_ReflectPerl2JS(cx, NULL, val, &rval);

	if(ok) {
	    if(ix & PJS_EL_MODE_FLAG)
		ok = JS_SetElement(cx, dest, SvIV(name), &rval);
	    else {
		STRLEN len;
		char *str = PJS_SvPV(name, len);
		if((int)len >= 0) ok = JS_SetProperty(cx, dest, str, &rval);
		else ok = JS_SetUCProperty(cx, dest, (jschar *)str, -(int)len, &rval);
	    }
        }

	if(!ok && PJS_report_exception(pcx))
	    XSRETURN_UNDEF;
	RETVAL = 1;
    OUTPUT:
	RETVAL

jsval
rop_get_prop(source, pcx, property)
    JSP::RawObj  source;
    JSP::Context pcx;
    SV *property;
    ALIAS:
	get_elem = 2
    PREINIT:
	JSBool ok = JS_FALSE;
	JSContext *cx;
    CODE:
	cx = PJS_GetJSContext(pcx);

	if(ix & PJS_EL_MODE_FLAG)
	    ok = JS_GetElement(cx, source, SvIV(property), &RETVAL);
	else {
	    STRLEN len;
	    char *name = PJS_SvPV(property, len);
#if JS_HAS_XML_SUPPORT
	    if(strEQ(PJS_GET_CLASS(cx, source)->name, "XML") && (int)len > 0) {
		/* TODO: if len < 0, name is UC2 encoded, so we need a JS_GetUCMethod */
		JSObject *other;
		ok = JS_GetMethod(cx, source, name, &other, &RETVAL);
		// Don't report if method fails
		if(!ok) JS_ClearPendingException(cx);
	    }
#endif
	    if(!ok) {
		if((int)len >= 0) ok = JS_GetProperty(cx, source, name, &RETVAL);
		else ok = JS_GetUCProperty(cx, source, (jschar *)name, -(int)len,
		                           &RETVAL);
	    }
	}
	if(!ok && PJS_report_exception(pcx))
	    XSRETURN_UNDEF;
    OUTPUT:
	RETVAL

int
rop_delete_prop(dest, pcx, name)
    JSP::RawObj  dest;
    JSP::Context pcx;
    SV *name;
    ALIAS:
	delete_elem = 2
    PREINIT:
	JSContext *cx;
	JSBool ok;
    CODE:
	cx = PJS_GetJSContext(pcx);

	if(ix & PJS_EL_MODE_FLAG)
	    ok = JS_DeleteElement(cx, dest, SvIV(name));
	else {
	    STRLEN len;
	    char *str = PJS_SvPV(name, len);
	    jsval tmp;
	    if((int)len >= 0)
		ok = JS_DeleteProperty2(cx, dest, str, &tmp);
	    else ok = JS_DeleteUCProperty2(cx, dest, (jschar *)str, -(int)len, &tmp);
	}
	if(!ok && PJS_report_exception(pcx))
	    XSRETURN_UNDEF;
	RETVAL = 1;
    OUTPUT:
	RETVAL

#undef PJS_EX_MODE_FLAG
#undef PJS_EL_MODE_FLAG

JSP::RawObj
rop_firstkey(object, pcx)
    JSP::RawObj  object;
    JSP::Context pcx;
    PREINIT:
	JSContext *cx;
	char hkey[32];
    CODE:
	cx = PJS_GetJSContext(pcx);

	RETVAL = JS_NewPropertyIterator(cx, object);

	/* Root Iterator */
	snprintf(hkey, 32, "%p", (void *)RETVAL);
	JS_DefineProperty(cx, pcx->pvisitors, hkey,
	    OBJECT_TO_JSVAL(RETVAL), NULL, NULL, 0);
    OUTPUT:
	RETVAL
	
jsval
rop_nextkey(iterator, pcx)
    JSP::RawObj  iterator;
    JSP::Context pcx;
    PREINIT:
	JSContext *cx;
	jsid idp;
    CODE:
	cx = PJS_GetJSContext(pcx);

	if(!JS_NextProperty(cx, iterator, &idp))
	    croak("NextProperty fail!");

	if(idp == JSVAL_VOID) {
	    /* End of properties, unroot iterator */
	    char hkey[32];
	    snprintf(hkey, 32, "%p", (void *)iterator);
	    JS_DeleteProperty(cx, pcx->pvisitors, hkey);
            XSRETURN_UNDEF;
	}
	if(!JS_IdToValue(cx, idp, &RETVAL))
	    croak("Can't convert id to value");
    OUTPUT:
	RETVAL

SV *
rop_length(source, pcx)
    JSP::RawObj  source;
    JSP::Context pcx;
    PREINIT:
	JSContext *cx;
	jsuint len;
    CODE:
	cx = PJS_GetJSContext(pcx);
	RETVAL = JS_HasArrayLength(cx, source, &len) ? newSViv(len) : &PL_sv_undef;
    OUTPUT:
	RETVAL

SV *
rop_tie(thing, pcx, isarr)
    JSP::RawObj  thing;
    JSP::Context pcx;
    I32 isarr;
    PREINIT:
	SV *box;
	SV *tied = NULL;
	SV *tier;
	AV *avbox;
	SV **last;
    CODE:
	box = PJS_GetPassport(pcx->cx, thing);
	avbox = (AV *)SvRV(box);
	last = av_fetch(avbox, 5+isarr, 1);
	if(last && SvOK(*last) && SvROK(*last)) {
	    RETVAL = newSVsv(*last);
	    PJS_DEBUG1("Tied cached:%s\n", SvPV_nolen(RETVAL));
	} else {
	    tied = isarr ? (SV *)newAV() : (SV *)newHV();
	    tier = newRV_inc(box);
	    hv_magic((HV *)tied, (GV *)tier, PERL_MAGIC_tied);
	    sv_free(tier);
	    RETVAL = newRV_noinc(tied);
	    sv_setsv(*last, RETVAL);
	    sv_rvweaken(*last);
	    PJS_DEBUG1("Return extra tied for %s\n", SvPV_nolen(tier));
	}
    OUTPUT:
	RETVAL

void
rop_free_root(thing, pcx)
    JSP::RawObj  thing;
    JSP::Context pcx;
    PREINIT:
	char hkey[32];
	SV *box;
    CODE:
	snprintf(hkey, 32, "%p", (void *)thing);
	box = PJS_GetPassport(pcx->cx, thing);
	PJS_DEBUG2("Freing %s brc: %d\n", hkey, (int)SvREFCNT(box));
	/* Invalidate CODEREF cache, its maybe holding a reference */
	av_store((AV *)SvRV(box), 7, &PL_sv_undef);
	/* Avoid destructing box a little, will be freed in passport_finalize.
	 * This transfers ownership to the passport, because there isn't more
	 * references in perl land to the Boxed.
	 */
	if(!PL_dirty) SvREFCNT_inc_simple_NN(box); 
	JS_DeleteProperty(pcx->cx, pcx->pvisitors, hkey);
	PJS_GC(pcx->cx);
