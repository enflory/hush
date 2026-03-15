import Foundation
import Testing
@testable import HushCore

final class MockVolumeController: VolumeControlling {
    var currentVolume: Float = 0.5
    var lastSetVolume: Float?
    var fadeTarget: Float?
    var cancelFadeCalled = false

    func getVolume() -> Float { currentVolume }
    func setVolume(_ volume: Float) {
        currentVolume = volume
        lastSetVolume = volume
    }
    func fadeToVolume(_ target: Float, duration: TimeInterval, completion: (() -> Void)?) {
        fadeTarget = target
    }
    func cancelFade() {
        cancelFadeCalled = true
    }
}

@Suite("MediaMonitor.updateVolumeFloor")
struct MediaMonitorUpdateVolumeFloorTests {
    @Test func appliesNewFloorImmediatelyWhenDimmed() {
        let mockVolume = MockVolumeController()
        let monitor = MediaMonitor(
            volumeController: mockVolume
        )
        // Force into dimmed state by simulating ad detection
        monitor.simulateStateForTesting(.dimmed)

        monitor.updateVolumeFloor(0.10)

        #expect(mockVolume.lastSetVolume == 0.10)
    }

    @Test func doesNothingWhenNotDimmed() {
        let mockVolume = MockVolumeController()
        let monitor = MediaMonitor(
            volumeController: mockVolume
        )
        // State is .idle by default
        monitor.updateVolumeFloor(0.10)

        #expect(mockVolume.lastSetVolume == nil)
    }

    @Test func appliesDefaultFloorWhenZero() {
        let mockVolume = MockVolumeController()
        let monitor = MediaMonitor(
            volumeController: mockVolume
        )
        monitor.simulateStateForTesting(.dimmed)

        monitor.updateVolumeFloor(0.0)

        #expect(mockVolume.lastSetVolume == 0.01)
    }
}
