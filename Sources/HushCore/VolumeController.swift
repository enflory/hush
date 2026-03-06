import AudioToolbox
import CoreAudio
import Foundation

public protocol VolumeControlling {
    func getVolume() -> Float
    func setVolume(_ volume: Float)
    func fadeToVolume(_ target: Float, duration: TimeInterval, completion: (() -> Void)?)
    func cancelFade()
}

public final class VolumeController: VolumeControlling {
    private var fadeTimer: Timer?
    private(set) var isAdjusting = false
    private var volumeChangeCallback: ((Float) -> Void)?

    public init() {}

    private var defaultOutputDevice: AudioDeviceID {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return deviceID
    }

    public func getVolume() -> Float {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(defaultOutputDevice, &address, 0, nil, &size, &volume)
        return volume
    }

    public func setVolume(_ volume: Float) {
        isAdjusting = true
        var vol = max(0, min(1, volume))
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(defaultOutputDevice, &address, 0, nil, size, &vol)
        isAdjusting = false
    }

    public func fadeToVolume(_ target: Float, duration: TimeInterval = 1.0, completion: (() -> Void)? = nil) {
        cancelFade()
        let current = getVolume()
        let steps = 20
        let increment = (target - current) / Float(steps)
        let interval = duration / Double(steps)
        var step = 0

        fadeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            step += 1
            if step >= steps {
                self?.setVolume(target)
                timer.invalidate()
                self?.fadeTimer = nil
                completion?()
            } else {
                self?.setVolume(current + increment * Float(step))
            }
        }
    }

    public func cancelFade() {
        fadeTimer?.invalidate()
        fadeTimer = nil
    }

    /// Register a callback for when the user changes volume externally.
    public func onExternalVolumeChange(_ callback: @escaping (Float) -> Void) {
        volumeChangeCallback = callback
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(defaultOutputDevice, &address, .main) { [weak self] _, _ in
            guard let self = self, !self.isAdjusting else { return }
            let newVolume = self.getVolume()
            self.volumeChangeCallback?(newVolume)
        }
    }
}
