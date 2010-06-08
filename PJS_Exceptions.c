#include "JS.h"

JSBool PJS_report_exception(PJS_Context *pcx) {
    jsval val;
    SV *sv = NULL;
    JSBool raise = PJS_GetFlag(pcx, "RaiseExceptions");
    JSContext *cx = PJS_GetJSContext(pcx);

    if(!SvTRUE(ERRSV)) {
	if(!JS_GetPendingException(cx, &val)) return JS_FALSE;
	JS_ClearPendingException(cx);
	if(!PJS_ReflectJS2Perl(cx, val, &sv, 1))
	    croak("Failed to convert exception to perl object");
 	SvSetSV(ERRSV, sv);
	sv = NULL;
    }
    if(raise) croak((char *)sv); /* -Wnonnul */
    return JS_TRUE;
}
