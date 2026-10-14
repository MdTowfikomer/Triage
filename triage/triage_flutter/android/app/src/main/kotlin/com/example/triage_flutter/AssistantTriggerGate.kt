package app.triage.mobile

/** Shared by Activity keys and the explicitly enabled accessibility key listener. */
object AssistantTriggerGate {
    @Volatile private var held = false
    @Volatile private var lastPressAt = 0L

    fun updateVolumeUp(down: Boolean, now: Long) {
        held = down
        if (down) lastPressAt = now
    }

    @Synchronized fun consume(now: Long): Boolean {
        if (!held || now - lastPressAt !in 0..5000) return false
        held = false
        return true
    }

    fun reset() { held = false }
}
