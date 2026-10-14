package app.triage.mobile

import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTriggerGateTest {
    @After fun reset() { AssistantTriggerGate.reset() }

    @Test fun shakeAloneCannotTrigger() {
        AssistantTriggerGate.reset()
        assertFalse(AssistantTriggerGate.consume(1000))
    }

    @Test fun holdingVolumeUpAllowsOneShake() {
        AssistantTriggerGate.updateVolumeUp(true, 1000)
        assertTrue(AssistantTriggerGate.consume(1200))
        assertFalse(AssistantTriggerGate.consume(1300))
    }

    @Test fun releasingVolumeUpDisarmsTrigger() {
        AssistantTriggerGate.updateVolumeUp(true, 1000)
        AssistantTriggerGate.updateVolumeUp(false, 1100)
        assertFalse(AssistantTriggerGate.consume(1200))
    }

    @Test fun staleKeyStateCannotTrigger() {
        AssistantTriggerGate.updateVolumeUp(true, 1000)
        assertFalse(AssistantTriggerGate.consume(6100))
    }
}
