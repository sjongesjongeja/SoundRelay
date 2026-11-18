import Foundation
import AVFoundation

class AudioStreamer: ObservableObject {
    @Published var isStreaming: Bool = false
    @Published var peakLevel: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var udpSocket: Int32 = -1
    private var serverAddr = sockaddr_in()
    private var sequenceNumber: UInt32 = 0
    private var startTime: Date?
    
    private let targetSampleRate: Double = 48000.0
    private let magicBytes: [UInt8] = [0x53, 0x52, 0x4C, 0x59] // 'SRLY'
    
    func startStreaming(toHost host: String, port: Int) -> Bool {
        guard !isStreaming else { return true }
        
        // 1. Setup UDP Socket
        udpSocket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        if udpSocket < 0 {
            print("Failed to create UDP socket")
            return false
        }
        
        var bufferSize: Int32 = 1024 * 512
        setsockopt(udpSocket, SOL_SOCKET, SO_SNDBUF, &bufferSize, socklen_t(MemoryLayout<Int32>.size))
        
        serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = in_port_t(port).bigEndian
        serverAddr.sin_addr.s_addr = inet_addr(host)
        
        // 2. Configure Audio Session for background streaming
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers])
            try session.setPreferredSampleRate(targetSampleRate)
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession setup failed: \(error)")
            close(udpSocket)
            return false
        }
        
        // 3. Configure AVAudioEngine
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return false }
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        sequenceNumber = 0
        startTime = Date()
        
        // Output format: 48kHz, 2 channels, 16-bit Int PCM
        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                              sampleRate: targetSampleRate,
                                              channels: 2,
                                              interleaved: true) else {
            return false
        }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            print("Unable to create audio converter")
            return false
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, when) in
            guard let self = self, self.isStreaming else { return }
            
            // Calculate VU peak for UI
            if let channelData = buffer.floatChannelData?[0] {
                var maxVal: Float = 0.0
                let frameLength = Int(buffer.frameLength)
                for i in 0..<frameLength {
                    let v = abs(channelData[i])
                    if v > maxVal { maxVal = v }
                }
                DispatchQueue.main.async {
                    self.peakLevel = min(1.0, maxVal * 1.5)
                }
            }
            
            // Convert to 48kHz stereo 16-bit
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * (self.targetSampleRate / inputFormat.sampleRate))
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else { return }
            
            var error: NSError?
            var allRead = false
            converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
                if !allRead {
                    allRead = true
                    outStatus.pointee = .haveData
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            
            if error == nil && convertedBuffer.frameLength > 0 {
                self.sendAudioBuffer(convertedBuffer)
            }
        }
        
        do {
            try engine.start()
            isStreaming = true
            return true
        } catch {
            print("Engine failed to start: \(error)")
            stopStreaming()
            return false
        }
    }
    
    private func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let int16Data = buffer.int16ChannelData?[0] else { return }
        let sampleCount = Int(buffer.frameLength) * 2 // Stereo = 2 samples per frame
        let byteCount = sampleCount * 2 // 2 bytes per 16-bit sample
        
        let timeOffsetMs = UInt32((Date().timeIntervalSince(startTime ?? Date())) * 1000)
        
        // Header: 4 bytes Magic + 4 bytes Sequence + 4 bytes Timestamp
        var packetData = Data(capacity: 12 + byteCount)
        packetData.append(contentsOf: magicBytes)
        
        var seqBE = sequenceNumber.bigEndian
        packetData.append(UnsafeBufferPointer(start: &seqBE, count: 1))
        sequenceNumber &+= 1
        
        var timeBE = timeOffsetMs.bigEndian
        packetData.append(UnsafeBufferPointer(start: &timeBE, count: 1))
        
        // Append PCM bytes
        packetData.append(UnsafeRawPointer(int16Data), count: byteCount)
        
        // Send packet via UDP
        packetData.withUnsafeBytes { rawPtr in
            guard let baseAddress = rawPtr.baseAddress else { return }
            withUnsafePointer(to: &serverAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    _ = sendto(udpSocket, baseAddress, packetData.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }
    
    func stopStreaming() {
        isStreaming = false
        peakLevel = 0.0
        
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        
        if udpSocket >= 0 {
            close(udpSocket)
            udpSocket = -1
        }
        
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
