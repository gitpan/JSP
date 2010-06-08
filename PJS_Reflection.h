/*!
    @header PJS_TypeConversion.h
*/

#ifndef __PJS_TYPECONVERSION_H__
#define __PJS_TYPECONVERSION_H__

#ifdef __cplusplus
extern "C" {
#endif

PJS_EXTERN SV *
PJS_GetPassport(JSContext *, JSObject *);

PJS_EXTERN JSBool
PJS_ReflectJS2Perl(JSContext *, jsval, SV **, int);

PJS_EXTERN SV *
PrimJSVALToSV(JSContext *, jsval);

PJS_EXTERN char *
PJS_ConvertUC(SV *sv, STRLEN *len);

PJS_EXTERN SV *
PJS_JSString2SV(JSString *str);

PJS_EXTERN JSBool
PJS_ReflectPerl2JS(JSContext *, JSObject *, SV *, jsval *);

PJS_EXTERN const char *
PJS_PASSPORT_PROP;

#ifdef __cplusplus
}
#endif

#endif
