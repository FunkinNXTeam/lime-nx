#define AL_API  __attribute__((visibility("default")))
#define ALC_API __attribute__((visibility("default")))

#define FORCE_ALIGN

#define ALSOFT_EMBED_HRTF_DATA

/* No dlopen on Vita when linking OpenAL into liblime */
/* #define HAVE_DLFCN_H */

/* #define HAVE_PTHREAD_NP_H */
/* #define HAVE_CPUID_H */
/* #define HAVE_INTRIN_H */
/* #define HAVE_GUIDDEF_H */
/* #define HAVE_GCC_GET_CPUID */
/* #define HAVE_CPUID_INTRINSIC */

/* Vita newlib pthread has no GNU pthread_mutexattr_setkind_np; keep unset. */
/* #define HAVE_PTHREAD_SETSCHEDPARAM */
/* #define HAVE_PTHREAD_SETNAME_NP */
/* #define HAVE_PTHREAD_SET_NAME_NP */

#define HAVE_RTKIT 0
#define ALSOFT_UWP 0
#define ALSOFT_EAX 0