#ifndef QTMEDIATE_GLOBAL_H
#define QTMEDIATE_GLOBAL_H

// Export define
#ifdef _MSC_VER
#  define QTMEDIATE_DECL_EXPORT __declspec(dllexport)
#  define QTMEDIATE_DECL_IMPORT __declspec(dllimport)
#else
#  define QTMEDIATE_DECL_EXPORT __attribute__((visibility("default")))
#  define QTMEDIATE_DECL_IMPORT __attribute__((visibility("default")))
#endif

// Qt style P-IMPL
#define QTMEDIATE_DECL_PRIVATE(Class)                                                               \
    inline Class##Private *d_func() {                                                              \
        return reinterpret_cast<Class##Private *>(d_ptr.get());                                    \
    }                                                                                              \
    inline const Class##Private *d_func() const {                                                  \
        return reinterpret_cast<const Class##Private *>(d_ptr.get());                              \
    }                                                                                              \
    friend class Class##Private;

#define QTMEDIATE_DECL_PUBLIC(Class)                                                                \
    inline Class *q_func() {                                                                       \
        return static_cast<Class *>(q_ptr);                                                        \
    }                                                                                              \
    inline const Class *q_func() const {                                                           \
        return static_cast<const Class *>(q_ptr);                                                  \
    }                                                                                              \
    friend class Class;

#define QM_D(Class) Class##Private *const d = d_func()
#define QM_Q(Class) Class *const q = q_func()

// Some classes do not permit copies to be made of an object.
#define QTMEDIATE_DISABLE_COPY(Class)                                                               \
    Class(const Class &) = delete;                                                                 \
    Class &operator=(const Class &) = delete;

#define QTMEDIATE_DISABLE_MOVE(Class)                                                               \
    Class(Class &&) = delete;                                                                      \
    Class &operator=(Class &&) = delete;

#define QTMEDIATE_DISABLE_COPY_MOVE(Class)                                                          \
    QTMEDIATE_DISABLE_COPY(Class)                                                                   \
    QTMEDIATE_DISABLE_MOVE(Class)

// Logging functions
#ifndef QTMEDIATE_TRACE
#  ifdef QTMEDIATE_YES_TRACE
#    define QTMEDIATE_TRACE_(fmt, ...)                                                              \
        printf("%s:%d:trace: " fmt "%s\n", __FILE__, __LINE__, __VA_ARGS__)
#    define QTMEDIATE_TRACE(...) QTMEDIATE_TRACE_(__VA_ARGS__, "")
#  else
#    define QTMEDIATE_TRACE(...)
#  endif
#endif

#ifndef QTMEDIATE_DEBUG
#  ifndef QTMEDIATE_NO_DEBUG
#    define QTMEDIATE_DEBUG_(fmt, ...)                                                              \
        printf("%s:%d:debug: " fmt "%s\n", __FILE__, __LINE__, __VA_ARGS__)
#    define QTMEDIATE_DEBUG(...) QTMEDIATE_DEBUG_(__VA_ARGS__, "")
#  else
#    define QTMEDIATE_DEBUG(...)
#  endif
#endif

#ifndef QTMEDIATE_WARNING
#  ifndef QTMEDIATE_NO_WARNING
#    define QTMEDIATE_WARNING_(fmt, ...)                                                            \
        printf("%s:%d:warning: " fmt "%s\n", __FILE__, __LINE__, __VA_ARGS__)
#    define QTMEDIATE_WARNING(...) QTMEDIATE_WARNING_(__VA_ARGS__, "")
#  else
#    define QTMEDIATE_WARNING(...)
#  endif
#endif

#ifndef QTMEDIATE_FATAL
#  ifndef QTMEDIATE_NO_FATAL
#    define QTMEDIATE_FATAL_(fmt, ...)                                                              \
        (fprintf(stderr, "%s:%d:fatal: " fmt "%s\n", __FILE__, __LINE__, __VA_ARGS__), std::abort())
#    define QTMEDIATE_FATAL(...) QTMEDIATE_FATAL_(__VA_ARGS__, "")
#  else
#    define QTMEDIATE_FATAL(...)
#  endif
#endif

// Utils
#define QM_UNUSED(X) (void) X;

#endif // QTMEDIATE_GLOBAL_H
