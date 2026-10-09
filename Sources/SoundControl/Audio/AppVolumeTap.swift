import CoreAudio
import Foundation

/// 实时音频线程读取的增益值。Float 的读写在 arm64/x86_64 上是原子的。
final class GainBox: @unchecked Sendable {
    var value: Float = 1
}

/// 截获一组音频进程：原声静音，乘以增益后重新输出到指定设备。见 docs/adr/0001。
final class AppVolumeTap {
    let processes: [AudioObjectID]
    let gain = GainBox()

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "SoundControl.io", qos: .userInteractive)

    init(processes: [AudioObjectID]) {
        self.processes = processes
    }

    func start(outputUID: String) throws {
        do {
            try startUnchecked(outputUID: outputUID)
        } catch {
            stop()
            throw error
        }
    }

    private func startUnchecked(outputUID: String) throws {
        let description = CATapDescription(stereoMixdownOfProcesses: processes)
        description.uuid = UUID()
        description.isPrivate = true
        description.muteBehavior = .mutedWhenTapped
        try check(AudioHardwareCreateProcessTap(description, &tapID), "创建 Process Tap")

        let aggregate: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundControl",
            kAudioAggregateDeviceUIDKey: "SoundControl-\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: description.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "创建聚合设备")

        let gain = self.gain
        try check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { _, input, _, output, _ in
            render(input: input, output: output, gain: gain.value)
        }, "创建音频回调")
        try check(AudioDeviceStart(aggregateID, ioProcID), "启动音频设备")
    }

    func stop() {
        if let ioProcID {
            AudioDeviceStop(aggregateID, ioProcID)
            AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            self.ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    deinit { stop() }
}

/// 把截获的立体声（输入的最后一个缓冲区）乘以增益写到输出的前两个声道，其余声道清零。
/// 假定样本为 Float32，这是 HAL 设备 IO 的常见格式。
private func render(input: UnsafePointer<AudioBufferList>, output: UnsafeMutablePointer<AudioBufferList>, gain: Float) {
    let inList = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
    let outList = UnsafeMutableAudioBufferListPointer(output)

    for buffer in outList {
        if let data = buffer.mData { memset(data, 0, Int(buffer.mDataByteSize)) }
    }
    guard let tap = inList.last, let tapData = tap.mData, tap.mNumberChannels > 0 else { return }

    let inChannels = Int(tap.mNumberChannels)
    let inSamples = tapData.assumingMemoryBound(to: Float.self)
    let inFrames = Int(tap.mDataByteSize) / (MemoryLayout<Float>.size * inChannels)

    // 输出声道 c 取输入声道 min(c, inChannels - 1)，只填前两个声道。
    var outChannel = 0
    for buffer in outList {
        guard let data = buffer.mData else { continue }
        let channels = Int(buffer.mNumberChannels)
        let samples = data.assumingMemoryBound(to: Float.self)
        let frames = min(inFrames, Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels))
        for c in 0..<channels where outChannel + c < 2 {
            let source = min(outChannel + c, inChannels - 1)
            for f in 0..<frames {
                samples[f * channels + c] = inSamples[f * inChannels + source] * gain
            }
        }
        outChannel += channels
        if outChannel >= 2 { break }
    }
}
