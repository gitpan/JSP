/*!
    @header JavaScript.pm
    @abstract This module provides an interface between SpiderMonkey and perl.
        
    @copyright Claes Jakobsson 2001-2007
    @copyright Matias Software Group 2008-2010
*/

#ifndef __JAVASCRIPT_H__
#define __JAVASCRIPT_H__

#include "JS_Env.h"
#ifndef WIN32
#define PERL_NO_GET_CONTEXT
#endif
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

#if defined(__cplusplus) && defined(__GNUC__)
#undef dNOOP
#define dNOOP	extern int __attribute__ ((unused)) Perl___notused
#endif

#include <jsapi.h>
#include <jsdbgapi.h>

#ifndef JS_ARGV_CALLEE
#define JS_ARGV_CALLEE(argv)	    ((argv)[-2])
#endif

#ifdef	JS_THREADSAFE
#define PJS_BeginRequest(cx)	    JS_BeginRequest(cx)
#define PJS_EndRequest(cx)	    JS_EndRequest(cx)
#else
#define PJS_BeginRequest(cx)	    /**/
#define PJS_EndRequest(cx)	    /**/
#endif

#define	PJS_GET_CLASS(cx,obj)	    JS_GET_CLASS(cx,obj)

#if PJS_UTF8_NATIVE
#define PJS_SvPV(sv, len)	    SvPVutf8(sv, len)
#else
#define	PJS_SvPV(sv, len)	    (!JS_CStringsAreUTF8() ? PJS_ConvertUC(aTHX_ sv, &len) : SvPVutf8(sv, len))
#endif

#if JS_VERSION == 185
#define PJS_GC(cx)		    {\
    JSErrorReporter older = JS_SetErrorReporter(cx,NULL);\
    JS_GC(cx);\
    JS_SetErrorReporter(cx,older);\
}
#else
#define PJS_GC(cx)		    JS_GC(cx)
#endif

#if defined(PJSDEBUG)
#define	PJS_DEBUG(x)		    warn(x)
#define	PJS_DEBUG1(x,x1)	    warn(x,x1)
#define	PJS_DEBUG2(x,x1,x2)	    warn(x,x1,x2)
#define	PJS_DEBUG3(x,x1,x2,x3)	    warn(x,x1,x2,x3)
#else
#define PJS_DEBUG(x)		    /**/
#define PJS_DEBUG1(x,x1)	    /**/
#define PJS_DEBUG2(x,x1,x2)	    /**/
#define PJS_DEBUG3(x,x1,x2,x3)	    /**/
#endif
    
#define JSCLASS_IS_BRIDGE	(1<<(JSCLASS_HIGH_FLAGS_SHIFT+5))
#define	JSCLASS_PRIVATE_IS_PERL	(JSCLASS_HAS_PRIVATE|JSCLASS_IS_BRIDGE|JSCLASS_HAS_RESERVED_SLOTS(1))

#define IS_PERL_CLASS(clasp)	(((clasp)->flags & JSCLASS_PRIVATE_IS_PERL)==JSCLASS_PRIVATE_IS_PERL)
#undef  PJS_CONTEXT_IN_PERL

#define NAMESPACE		    "JSP::"
#define PJS_GTYPEDEF(type, wrap)    typedef type * JSP__ ## wrap
#define PJS_TYPEDEF(x)		    PJS_GTYPEDEF(PJS_ ## x, x)

#include "PJS_Types.h"
#include "PJS_Common.h"
#include "PJS_Call.h"
#include "PJS_Context.h"
#include "PJS_Reflection.h"
#include "PJS_Exceptions.h"
#include "PJS_PerlArray.h"
#include "PJS_PerlHash.h"
#include "PJS_PerlSub.h"
#include "PJS_PerlPackage.h"
#include "PJS_PerlScalar.h"

#ifndef SvREFCNT_inc_void_NN
#define SvREFCNT_inc_void_NN(x)	    SvREFCNT_inc(x)
#define SvREFCNT_inc_simple_NN(x)   SvREFCNT_inc(x)
#endif

#endif
