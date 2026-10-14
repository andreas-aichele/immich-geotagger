package io.github.andreasaichele.diagnostics;

final class LogSanitizer {
    static String sanitize(String text) {
        // Defensive redaction on top of structured call sites. Never log request/response bodies.
        String safe = text.replaceAll("(?i)https?://[^\\s)]+", "[URL]")
            .replaceAll("(?i)(bearer\\s+)[^\\s]+", "$1[REDACTED]")
            .replaceAll("(?i)((?:x-api-key|api[_-]?key|authorization|token|password)\\s*[:=]\\s*)[^\\s,;]+", "$1[REDACTED]")
            .replaceAll("[\\r\\n]+", " | ");
        return safe.substring(0, Math.min(16000, safe.length()));
    }

}
