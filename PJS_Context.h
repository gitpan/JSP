/*!
    @header PJS_Context.h
    @abstract Types and functions related to context handling
*/

#ifndef __PJS_CONTEXT_H__
#define __PJS_CONTEXT_H__

#ifdef __cplusplus
extern "C" {
#endif

/*! @struct PJS_Context
    @abstract
*/
struct PJS_Context {
    /* The JavaScript context which this instance belongs to */
    JSContext *cx;

    /* A hash of bound classes */
    HV *class_by_name;
	
    PJS_Runtime *rt;
    /* Referece to hi-level RT */
    SV  *rrt;		    

#ifdef JS_HAS_BRANCH_HANDLER
    /* Set to a SVt_PVCV if we have an branch handler */
    SV *branch_handler;
#endif

    /* JSObject for js visitors to perl */
    JSObject *pvisitors;

    /* A hash for perl visitors to js */
    HV *jsvisitors;
    
    /* Keep in JS, jsvals are cheaper than SVs */
    JSObject *flags; 

    /* For GC */
    int svconv;
};

struct jsv_mg {
    PJS_Context *pcx;
    JSObject *object;
};

typedef struct jsv_mg jsv_mg;
#define PERL_MAGIC_jsvis ('j')

PJS_EXTERN PJS_Context *
PJS_GetContext(JSContext *);
/*! @function PJS_DestroyContext
    @abstract Frees a PJS_Context and the underlying JSContext
    @param context The context to free
*/
PJS_EXTERN void
PJS_DestroyContext(PJS_Context *context);

/*! @function PJS_RootObject
    @abstract Add object to the list rooted in context
    @param context The context to use
    @param object  The object to add
*/
PJS_EXTERN JSBool
PJS_RootObject(PJS_Context *context, JSObject *object);

PJS_EXTERN JSObject *
PJS_CreateJSVis(JSContext *, JSObject *, SV *);

PJS_EXTERN void
PJS_UnrootJSVis(JSContext *cx, JSObject *object);

PJS_EXTERN JSObject *
PJS_IsPerlVisitor( PJS_Context *pcx, SV *sv);

/*! @function PJS_CreateContext
    @abstract Creates a new context
    @discussion This function creates a new context in the given runtime and sets
    up initial classes and global object.
    @param runtime Runtime that'll execute the context.
    @param ref A reference to hold alive for the live of the context
    @result A pointer to a PJS_Context structure if successfull.
*/
PJS_EXTERN PJS_Context *
PJS_CreateContext(PJS_Runtime *runtime, SV *ref);

PJS_EXTERN JSBool
PJS_branch_handler(JSContext *, JSScript *);

/*! @functiongroup Querying contexts */

/*! @function PJS_GetFlag
    @abstract Retrieves a flag by name from a given context
    @param fromContext  Context to retrieve the function from
    @param functionName Name of the function
    @result A pointer to a PJS_Function structure if the function was found 
    or NULL if the function did not exist.
*/
PJS_EXTERN JSBool
PJS_GetFlag(PJS_Context *fromContext, const char *flag);

PJS_EXTERN JSBool
PJS_SetFlag(PJS_Context *fromContext, const char *flag, JSBool val); 

/*! @function PJS_GetJSContext
    @abstract Retrieve the JSContext from a PJS_Context
    @param fromContext The context to search in
    @result A pointer to the underlying JSContext
*/
#define PJS_GetJSContext(fromContext) (fromContext->cx)

PJS_EXTERN GV *PJS_Context_SV;
PJS_EXTERN GV *PJS_This;

#ifdef __cplusplus
}
#endif

#endif
