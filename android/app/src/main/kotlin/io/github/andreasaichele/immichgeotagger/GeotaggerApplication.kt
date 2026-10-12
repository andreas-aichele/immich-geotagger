package io.github.andreasaichele.immichgeotagger

import android.app.Application
import io.github.andreasaichele.diagnostics.DiagnosticLoggerPlugin

class GeotaggerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        DiagnosticLoggerPlugin.initialize(this)
    }

    override fun onTrimMemory(level: Int) {
        DiagnosticLoggerPlugin.lifecycle("Memory pressure level=$level")
        super.onTrimMemory(level)
    }
}
