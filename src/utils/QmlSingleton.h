#pragma once
#include <QQmlEngine>
#include <QJSEngine>

// Boilerplate for C++ objects exposed to QML as a singleton whose instance is
// created/owned in C++ (set via setInstance) and merely surfaced to the QML
// engine via create(). Use DECLARE_QML_SINGLETON in the class body and
// IMPLEMENT_QML_SINGLETON once in the matching .cpp.

#define DECLARE_QML_SINGLETON(Class)                          \
    static Class *instance();                                 \
    static void setInstance(Class *);                         \
    static Class *create(QQmlEngine *, QJSEngine *);

#define IMPLEMENT_QML_SINGLETON(Class)                        \
    static Class *g_##Class##Instance = nullptr;              \
    Class *Class::instance() { return g_##Class##Instance; }  \
    void Class::setInstance(Class *p) { g_##Class##Instance = p; } \
    Class *Class::create(QQmlEngine *, QJSEngine *) {         \
        Q_ASSERT(g_##Class##Instance);                        \
        QQmlEngine::setObjectOwnership(g_##Class##Instance,   \
            QQmlEngine::CppOwnership);                        \
        return g_##Class##Instance;                           \
    }
