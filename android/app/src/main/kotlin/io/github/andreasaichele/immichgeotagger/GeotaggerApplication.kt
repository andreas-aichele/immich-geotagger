package io.github.andreasaichele.immichgeotagger

import android.app.Application
import io.flutter.FlutterInjector
import io.github.andreasaichele.diagnostics.DiagnosticLoggerPlugin

class GeotaggerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DiagnosticLoggerPlugin.initialize(this)
        // libre_location 0.4.3 looks up callback information before creating
        // its headless engine. A restarted service has no Activity to load JNI.
        // Application.onCreate runs before services/receivers and on the main
        // thread, so complete the runtime setup before either can dispatch.
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(this)
            loader.ensureInitializationComplete(this, null)
        }
        DiagnosticLoggerPlugin.lifecycle("Flutter runtime initialized before background callbacks")
    }

    override fun onTrimMemory(level: Int) {
        DiagnosticLoggerPlugin.lifecycle("Memory pressure level=$level")
        super.onTrimMemory(level)
    }
}
