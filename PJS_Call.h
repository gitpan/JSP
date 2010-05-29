/*!
    @header PJS_Call.h
    @abstract Types and functions related to calling methods and functions
*/

#ifndef __PJS_CALL_H__
#define __PJS_CALL_H__

#ifdef __cplusplus
extern "C" {
#endif

PJS_EXTERN SV *
PJS_call_perl_method(JSContext *, const char *, ...);

PJS_EXTERN JSBool
perl_call_sv_with_jsvals_rsv(JSContext *, JSObject *, SV *, SV *, uintN, jsval *, SV **, I32);

PJS_EXTERN JSBool
perl_call_sv_with_jsvals(JSContext *, JSObject *, SV *, SV *, uintN, jsval *, jsval *, I32);

PJS_EXTERN JSBool
call_js_function(JSContext *, JSObject *, jsval, AV *, jsval *);

#ifdef __cplusplus
}
#endif

#endif
