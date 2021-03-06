/**
 * Contains compiler-recognized user-defined attribute types.
 *
 * Copyright: Authors 2015-2016
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   David Nadlinger, Johan Engelen
 */
module ldc.attributes;

/// Helper template
private template AliasSeq(TList...)
{
    alias AliasSeq = TList;
}

/**
 * Specifies that the function returns `null` or a pointer to at least a
 * certain number of allocated bytes. `sizeArgIdx` and `numArgIdx` specify
 * the 0-based index of the function arguments that should be used to calculate
 * the number of bytes returned:
 *
 *   bytes = arg[sizeArgIdx] * (numArgIdx < 0) ? arg[numArgIdx] : 1
 *
 * The optimizer may assume that an @allocSize function has no other side
 * effects and that it is valid to eliminate calls to the function if the
 * allocated memory is not used. The optimizer will eliminate all code from
 * `foo` in this example:
 *     @allocSize(0) void* myAlloc(size_t size);
 *     void foo() {
 *         auto p = myAlloc(100);
 *         p[0] = 1;
 *     }
 *
 * See LLVM LangRef for more details:
 *    http://llvm.org/docs/LangRef.html#function-attributes
 *
 * This attribute has no effect for LLVM < 3.9.
 *
 * Example:
 * ---
 * import ldc.attributes;
 *
 * @allocSize(0) extern(C) void* malloc(size_t size);
 * @allocSize(2,1) extern(C) void* reallocarray(void *ptr, size_t nmemb,
 *                                              size_t size);
 * @allocSize(0,1) void* my_calloc(size_t element_size, size_t count,
 *                                 bool irrelevant);
 * ---
 */
struct allocSize
{
    int sizeArgIdx;

    /// If numArgIdx < 0, there is no argument specifying the element count
    int numArgIdx = int.min;
}

/**
 * Explicitly sets "fast math" for a function, enabling aggressive math
 * optimizations. These optimizations may dramatically change the outcome of
 * floating point calculations (e.g. because of reassociation).
 *
 * Example:
 * ---
 * import ldc.attributes;
 *
 * @fastmath
 * double dot(double[] a, double[] b) {
 *     double s = 0;
 *     foreach(size_t i; 0..a.length)
 *     {
 *         // will result in vectorized fused-multiply-add instructions
 *         s += a * b;
 *     }
 *     return s;
 * }
 * ---
 */
alias fastmath = AliasSeq!(llvmAttr("unsafe-fp-math", "true"), llvmFastMathFlag("fast"));

/**
 * Sets the optimization strategy for a function.
 * Valid strategies are "none", "optsize", "minsize". The strategies are mutually exclusive.
 *
 * @optStrategy("none") in particular is useful to selectively debug functions when a
 * fully unoptimized program cannot be used (e.g. due to too low performance).
 *
 * Strategy "none":
 *     Disables most optimizations for a function.
 *     It implies `pragma(inline, false)`: the function is never inlined
 *     in a calling function, and the attribute cannot be combined with
 *     `pragma(inline, true)`.
 *     Functions with `pragma(inline, true)` are still candidates for inlining into
 *     the function.
 *
 * Strategy "optsize":
 *     Tries to keep the code size of the function low and does optimizations to
 *     reduce code size as long as they do not significantly impact runtime performance.
 *
 * Strategy "minsize":
 *     Tries to keep the code size of the function low and does optimizations to
 *     reduce code size that may reduce runtime performance.
 */
struct optStrategy {
    string strategy;
}

/**
 * Adds an LLVM attribute to a function, without checking the validity or
 * applicability of the attribute.
 * The attribute is specified as key-value pair:
 * @llvmAttr("key", "value")
 * If the value string is empty, just the key is added as attribute.
 *
 * Example:
 * ---
 * import ldc.attributes;
 *
 * @llvmAttr("unsafe-fp-math", "true")
 * double dot(double[] a, double[] b) {
 *     double s = 0;
 *     foreach(size_t i; 0..a.length)
 *     {
 *         s = inlineIR!(`
 *         %p = fmul fast double %0, %1
 *         %r = fadd fast double %p, %2
 *         ret double %r`, double)(a[i], b[i], s);
 *     }
 *     return s;
 * }
 * ---
 */
struct llvmAttr
{
    string key;
    string value;
}

/**
 * Sets LLVM's fast-math flags for floating point operations in the function
 * this attribute is applied to.
 * See LLVM LangRef for possible values:
 *    http://llvm.org/docs/LangRef.html#fast-math-flags
 * @llvmFastMathFlag("clear") clears all flags.
 */
struct llvmFastMathFlag
{
    string flag;
}

/**
 * When applied to a global variable or function, causes it to be emitted to a
 * non-standard object file/executable section.
 *
 * The target platform might impose certain restrictions on the format for
 * section names.
 *
 * Examples:
 * ---
 * import ldc.attributes;
 *
 * @section(".mySection") int myGlobal;
 * ---
 */
struct section
{
    string name;
}

/**
 * When applied to a function, specifies that the function should be compiled
 * with different target options than on the command line.
 *
 * The passed string should be a comma-separated list of options. The options
 * are passed to LLVM by adding them to the "target-features" function
 * attribute, after minor processing: negative options (e.g. "no-sse") have the
 * "no" stripped (--> "-sse"), whereas positive options (e.g. sse") gain a
 * leading "+" (--> "+sse"). Negative options override positive options
 * regardless of their order.
 * The "arch=" option is a special case and is passed to LLVM via the
 * "target-cpu" function attribute.
 *
 * Examples:
 * ---
 * import ldc.attributes;
 *
 * @target("no-sse")
 * void foo_nosse(float *A, float* B, float K, uint n) {
 *     for (int i = 0; i < n; ++i)
 *         A[i] *= B[i] + K;
 * }
 * @target("arch=haswell")
 * void foo_haswell(float *A, float* B, float K, uint n) {
 *     for (int i = 0; i < n; ++i)
 *         A[i] *= B[i] + K;
 * }
 * ---
 */
struct target
{
    string specifier;
}

/++
 + When applied to a global symbol, specifies that the symbol should be emitted
 + with weak linkage. An example use case is a library function that should be
 + overridable by user code.
 +
 + Quote from the LLVM manual: "Note that weak linkage does not actually allow
 + the optimizer to inline the body of this function into callers because it
 + doesn’t know if this definition of the function is the definitive definition
 + within the program or whether it will be overridden by a stronger
 + definition."
 +
 + Examples:
 + ---
 + import ldc.attributes;
 +
 + @weak int user_hook() { return 1; }
 + ---
 +/
immutable weak = _weak();
private struct _weak
{
}
