#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <jsapi.h>
#include <jsdbgapi.h>
#include <jsobj.h>

#if JS_VERSION < 180
#define JS_SetCStringsAreUTF8()	    /**/
#endif

static JSClass global_class = {
    "global", JSCLASS_GLOBAL_FLAGS,
    JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,  JS_PropertyStub,
    JS_EnumerateStub, JS_ResolveStub,   JS_ConvertStub,   JS_FinalizeStub,
    JSCLASS_NO_OPTIONAL_MEMBERS
};

int main(int argc, char *argv[]) {
    JSRuntime *rt;
    JSContext *cx;
    int tt = 0;
    int HBJ = 0;
    void *handle = dlopen(NULL, RTLD_NOW);
#ifndef JS_THREADSAFE
#if JS_VERSION >= 185
    if(dlsym(handle, "js_GetCurrentThread")) tt++;
#endif
#else
    tt++;
#endif
#if JS_VERSION < 185
    if(dlsym(handle, "JS_SetBranchCallback")) HBJ++;
#endif
    JS_SetCStringsAreUTF8();
    rt = JS_NewRuntime(8L * 1024 * 1024);
    if(rt) cx = JS_NewContext(rt, 8192);
    if(cx) {
	JSClass *jsclass;
	JSObject *gobj;
	gobj = JS_NewObject(cx, &global_class, NULL, NULL);
	if(!gobj || !JS_InitStandardClasses(cx, gobj)) 
	    goto fail;
	printf("#define JS_VERSION\t%d\n", JS_VERSION);
#ifndef JS_THREADSAFE
	if(tt) printf("#define JS_THREADSAFE\n", tt);
#endif
	if(HBJ) printf("#define JS_HAS_BRANCH_HANDLER\n");
	else printf("#undef JS_HAS_BRANCH_HANDLER\n");
	{ /* Test for bug #533450 */
	    const char *expr = "'\\xe9';";
	    jsval v1;
	    char *bytes;
	    JS_EvaluateScript(cx, gobj, expr, strlen(expr), __FILE__, __LINE__, &v1);
	    bytes = JS_GetStringBytes(JSVAL_TO_STRING(v1));
	    if(strcmp(bytes, "\303\251") == 0)
		printf("#define JS_UTF8_NATIVE\n");
	    else printf("#undef JS_UTF8_NATIVE\n");
	}
	exit(0);
    }
    fail:
    fprintf(stderr, "Not ABI compatible!\n");
    exit(1);
}
