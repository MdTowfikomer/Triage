package app.triage.mobile

import android.accessibilityservice.AccessibilityService
import android.os.SystemClock
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

/** Observes Volume Up only. Does not read UI content or consume normal volume keys. */
class TriggerKeyService : AccessibilityService() {
    override fun onKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            AssistantTriggerGate.updateVolumeUp(event.action == KeyEvent.ACTION_DOWN, SystemClock.elapsedRealtime())
        }
        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() { AssistantTriggerGate.reset() }
    override fun onDestroy() {
        AssistantTriggerGate.reset()
        super.onDestroy()
    }
}
