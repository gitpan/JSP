#include "JS.h"

GV *PJS_Context_SV = NULL;
GV *PJS_This = NULL;

/* Global class, does nothing */
static JSClass global_class = {
    "global", JSCLASS_GLOBAL_FLAGS,
    JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,
    JS_EnumerateStub, JS_ResolveStub,   JS_ConvertStub,   JS_FinalizeStub,
    JSCLASS_NO_OPTIONAL_MEMBERS
};

static void
perl_class_finalize (
    JSContext *cx,
    JSObject *object
) {
    PJS_Context *pcx;
#ifdef PJS_CONTEXT_IN_PERL
    pcx = JS_GetPrivate(cx, object);
#else
    pcx = PJS_GET_CONTEXT(cx);
#endif
    sv_free((SV *)pcx->class_by_name);
    pcx->class_by_name = NULL;
    JS_SetReservedSlot(cx, object, 0, JSVAL_VOID);
    pcx->pvisitors = NULL;
    JS_SetReservedSlot(cx, object, 1, JSVAL_VOID);
    pcx->flags = NULL;
#ifndef PJS_CONTEXT_IN_PERL
    JS_SetContextPrivate(cx, NULL);
#endif
}

JSClass perl_class = {
    "perl", 
#ifdef PJS_CONTEXT_IN_PERL
    JSCLASS_HAS_PRIVATE |
#endif
    JSCLASS_HAS_RESERVED_SLOTS(2),
    JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,
    JS_EnumerateStub, JS_ResolveStub,   JS_ConvertStub,   perl_class_finalize,
    JSCLASS_NO_OPTIONAL_MEMBERS
};

JSBool
PJS_InitPerlClasses(PJS_Context *pcx, JSObject *gobj)
{
    JSObject *perl;
    JSContext *cx = pcx->cx;

    perl = JS_NewObject(cx, &perl_class, NULL, gobj);
    if(perl && JS_DefineProperty(cx, gobj, "__PERL__",
                      OBJECT_TO_JSVAL(perl), NULL, NULL, JSPROP_PERMANENT) &&
       (pcx->pvisitors = JS_NewObject(cx, NULL, NULL, perl)) &&
       JS_SetReservedSlot(cx, perl, 0, OBJECT_TO_JSVAL(pcx->pvisitors)) &&
       (pcx->flags = JS_NewObject(cx, NULL,  NULL, NULL)) &&
       JS_SetReservedSlot(cx, perl, 1, OBJECT_TO_JSVAL(pcx->flags))
    ) {
#ifdef PJS_CONTEXT_IN_PERL
	JS_SetPrivate(cx, perl, (void *)pcx);
#else
	JS_SetContextPrivate(cx, (void *)pcx);
#endif
	pcx->jsvisitors = newHV();
	pcx->class_by_name = newHV();
	if(PJS_InitPerlArrayClass(cx, gobj) &&
	   PJS_InitPerlHashClass(cx, gobj) &&
	   PJS_InitPerlScalarClass(cx, gobj) &&
           PJS_InitPerlSubClass(cx, gobj)) {
	    return JS_TRUE;
	}
    }
    return JS_FALSE;
}

#ifdef PJS_CONTEXT_IN_PERL
PJS_Context *
PJS_GetContext(JSContext *cx)
{
    JSObject *tobj;
    jsval temp;
    if((tobj = JS_GetGlobalObject(cx))
       && JS_LookupProperty(cx, tobj, "__PERL__", &temp)
       && JSVAL_IS_OBJECT(temp)
       && (tobj = JSVAL_TO_OBJECT(temp))
       && PJS_GET_CLASS(cx, tobj) == &perl_class) {
	return (PJS_Context *)JS_GetPrivate(cx, tobj);
    }
    return NULL;
}
#endif

static void 
js_error_reporter(
    JSContext *cx,
    const char *message,
    JSErrorReport *report
) {
    if(report->flags & JSREPORT_WARNING) 
	warn(message);
    else {
	// warn("================= Uncaught error: %s", message);
	sv_setsv(ERRSV, newSVpv(message,0));
    }
}

/*
  Create PJS_Context structure
*/
PJS_Context *
PJS_CreateContext(PJS_Runtime *rt, SV *ref) {
    PJS_Context *pcx;
    JSObject *gobj;

    Newz(1, pcx, 1, PJS_Context);
    if(!pcx)
        croak("Failed to allocate memory for PJS_Context");
    /* 
        The 'stack size' param here isn't actually the stack size, it's
        the "chunk size of the stack pool--an obscure memory management
        tuning knob"
        
        http://groups.google.com/group/mozilla.dev.tech.js-engine/browse_thread/thread/be9f404b623acf39
    */
    
    pcx->cx = JS_NewContext(rt->rt, 8192);

    if(!pcx->cx) {
        Safefree(pcx);
        croak("Failed to create JSContext");
    }
    PJS_BeginRequest(pcx->cx);

    JS_SetOptions(pcx->cx, JSOPTION_DONT_REPORT_UNCAUGHT);
    JS_SetErrorReporter(pcx->cx, &js_error_reporter);

    /* Create a global object for the context */
    gobj = JS_NewObject(pcx->cx, &global_class, NULL, NULL);
    if(!gobj || !JS_InitStandardClasses(pcx->cx, gobj)) {
        PJS_DestroyContext(pcx);
        croak("Standard classes not loaded properly.");
    }

    pcx->rt = rt;
    if(ref && SvOK(ref))
	pcx->rrt = SvREFCNT_inc_simple_NN(ref);
    pcx->svconv = 0;

    if(PJS_InitPerlClasses(pcx, gobj)) {
	return pcx;
    }
    else {
        PJS_DestroyContext(pcx);
        croak("Perl classes not loaded properly.");        
    }
    return NULL; /* Not really reached */
}

static void
PJS_unmagic(
    PJS_Context *pcx,
    SV *sv
) {
    dTHX;
    MAGIC* mg;
    MAGIC** mgp;

    assert(SvMAGIC(sv));
#if PERL_VERSION > 9
    mgp = &(((XPVMG*) SvANY(sv))->xmg_u.xmg_magic);
#else
    mgp = &(SvMAGIC(sv));
#endif
    jsv_mg *jsvis;
    for(mg = *mgp; mg; mg = *mgp) {
	if(mg->mg_type == PERL_MAGIC_jsvis &&
	   mg->mg_private == 0x4a53 &&
	   (jsvis = (jsv_mg *)mg->mg_ptr) &&
	   jsvis->pcx == pcx
	) { // Found my magic
	    *mgp = mg->mg_moremagic;
	    Safefree(jsvis); // Free struct;
	    Safefree(mg);
	    goto exit;
	}
	mgp = &mg->mg_moremagic;
    }
    exit:
    if (!SvMAGIC(sv)) {
        SvMAGICAL_off(sv);
        SvFLAGS(sv) |= (SvFLAGS(sv) & (SVp_IOK|SVp_NOK|SVp_POK)) >> PRIVSHIFT;
        SvMAGIC_set(sv, NULL);
    }
}

/*
  Free memory occupied by PJS_Context structure
*/
void PJS_DestroyContext(PJS_Context *pcx) {
    SV *rrt = NULL;
    if(pcx->cx && pcx->rt && pcx->rt->rt) {
	JSContext *cx = pcx->cx; 
	HV *hv = pcx->jsvisitors;
	I32 len = hv_iterinit(hv);
	if(len) {
	    /* As SM don't warrant us that every object will be finalized in 
	     * JS_DestroyContext, we can't depend of UnrootJSVis for magic clearing
	     */
	    SV *val;
	    char *key;
	    while( (val = hv_iternextsv(hv, &key, &len)) ) {
		JSObject *shell = (JSObject *)SvIVX(val);
		SV *ref = (SV *)JS_GetPrivate(cx, shell);
		if(ref && SvROK(ref)) PJS_unmagic(pcx, SvRV(ref));
		// TODO: Assert needed?
	    }
	}
	JS_SetErrorReporter(cx, NULL);
	JS_ClearScope(cx, JS_GetGlobalObject(cx));
	JS_GC(cx);
	pcx->cx = NULL; /* Mark global clean */
	PJS_EndRequest(cx);
	JS_DestroyContext(cx);
	len = hv_iterinit(hv);
	// warn("Orphan jsvisitors: %d\n", len);
	sv_free((SV *)hv);
	rrt = pcx->rrt;
    } else croak("PJS_Assert: Without runtime at context destruction\n");
    Safefree(pcx);
    pcx = NULL;
    if(rrt) sv_free(rrt); // Liberate runtime reference
}

JSBool
PJS_RootObject(
    PJS_Context *pcx,
    JSObject *object
) {
    char hkey[32];

    (void)snprintf(hkey, 32, "%p", (void *)object);
    return JS_DefineProperty(pcx->cx, pcx->pvisitors, hkey,
	OBJECT_TO_JSVAL(object), NULL, NULL, 0
    );
}

static int jsv_free(pTHX_ SV *sv, MAGIC *mg) {
    jsv_mg *jsvis = (jsv_mg *)mg->mg_ptr;
    assert(mg->mg_private == 0x4a53);
    Safefree(jsvis);
    return 1;
}

static MGVTBL vtbl_jsvt = { 0, 0, 0, 0, jsv_free };

JSObject *
PJS_CreateJSVis(
    JSContext *cx,
    JSObject *object,
    SV *ref
) {
    dTHX;
    jsv_mg *jsvis;
    MAGIC *mg;
    char hkey[32];

    if(!object) return NULL;
    Newz(1, jsvis, 1, jsv_mg);
    if(jsvis) {
	SV *sv = SvRV(ref);
#if 0	/* Will be needed for Subs prototype chain mangling */
	JSObject *stash = NULL;
	HV *st = (SvTYPE(sv) == SVt_PVCV) ? CvSTASH(sv) : SvSTASH(sv);
	char *package = st ? HvNAME(st) : NULL;
	if(package) {
	    stash = PJS_GetPackageObject(cx, package);
	    warn("ST: %s %d\n", package, SvTYPE(sv));
	}
#endif
	snprintf(hkey, 32, "%p", (void *)sv);
	jsvis->pcx = PJS_GET_CONTEXT(cx);
	jsvis->object = object;
	if(hv_store(jsvis->pcx->jsvisitors, hkey, strlen(hkey),
		    newSViv((IV)object), 0))
	{
	    sv_free((SV *)JS_GetPrivate(cx, object)); // Don't leak
	    mg = sv_magicext(sv, NULL, PERL_MAGIC_jsvis,
		             &vtbl_jsvt, (char *)jsvis, 0);
	    mg->mg_private = 0x4a53;
#ifdef DEBUG
	    warn("New jsvisitor %s: %s RC %d,%d\n",
		 jsvis->hkey, SvPV_nolen(ref), SvREFCNT(ref), SvREFCNT(sv)
	    );
#endif
	    /* The shell object takes ownership of ref */
	    JS_SetPrivate(cx, object, (void *)SvREFCNT_inc_simple_NN(ref));
	    return object;
	} 
	else {
	    JS_ReportError(cx, "Can't register a JSVis");
	    Safefree(jsvis);
	}
    }
    else JS_ReportOutOfMemory(cx);

    return NULL;
}

void
PJS_UnrootJSVis(
    JSContext *cx,
    JSObject *object
) {
    dTHX;
    SV *ref = (SV *)JS_GetPrivate(cx, object);
    if(ref && SvOK(ref) && SvROK(ref)) {
	char hkey[32];
	PJS_Context *pcx = PJS_GET_CONTEXT(cx); // At Context destruction can be NULL
	(void)snprintf(hkey, 32, "%p", (void *)SvRV(ref));
	if(pcx && SvMAGICAL(SvRV(ref))) PJS_unmagic(pcx, SvRV(ref));
	if(pcx && pcx->jsvisitors) {
	    (void)hv_delete(pcx->jsvisitors, hkey, strlen(hkey), G_DISCARD);
	}
	sv_free(ref);
    }
    else croak("PJS_Assert: Not a REF in finalize for %s\n",
	       PJS_GET_CLASS(cx, object)->name);
}

JSObject *
PJS_IsPerlVisitor(
    PJS_Context *pcx,
    SV *sv
) {
    char hkey[32];
    SV **oguardp;
    snprintf(hkey, 32, "%p", (void *)sv);
    PJS_DEBUG1("Check Visitor %s\n", hkey);
    oguardp = hv_fetch(pcx->jsvisitors, hkey, strlen(hkey), 0);
    if(oguardp) {
	assert(SvIOK(*oguardp));
	return (JSObject *)SvIVX(*oguardp);
    }
    else return NULL;
}

JSBool
PJS_SetFlag(
    PJS_Context *pcx,
    const char *flag,
    JSBool val
) {
    return JS_DefineProperty(pcx->cx, pcx->flags, flag,
	                     val ? JSVAL_TRUE : JSVAL_FALSE,
		             NULL, NULL,  0);
}

JSBool
PJS_GetFlag(
    PJS_Context *pcx,
    const char *flag
) {
    jsval val;
    JS_LookupProperty(pcx->cx, pcx->flags, flag, &val);
    return !JSVAL_IS_VOID(val) && JSVAL_TO_BOOLEAN(val);
}

#ifdef JS_HAS_BRANCH_HANDLER
/* Called by context when a branch occurs */
JSBool PJS_branch_handler(
    JSContext *cx,
    JSScript *script
) {
    PJS_Context *pcx;
    SV *rv;
    JSBool status = JS_TRUE;
    
    pcx = PJS_GET_CONTEXT(cx);

    if(pcx && pcx->branch_handler) {
	dSP;
        ENTER; SAVETMPS;
        PUSHMARK(SP);
        
        (void)call_sv(SvRV(pcx->branch_handler), G_SCALAR | G_EVAL);

        SPAGAIN;
        rv = POPs;
        if(!SvTRUE(rv))
            status = JS_FALSE;

        if(SvTRUE(ERRSV)) {
            sv_setsv(ERRSV, &PL_sv_undef);
            status = JS_FALSE;
        }
        
        PUTBACK;
        FREETMPS; LEAVE;
    }
    return status;
}
#endif
