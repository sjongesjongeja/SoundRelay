import Foundation

struct DiscoveredServer: Identifiable {
    let id = UUID()
    let name: String
    let ip: String
    let audioPort: Int
    let webPort: Int
}

class DiscoveryManager: ObservableObject {
    @Published var discoveredServer: DiscoveredServer?
    @Published var isSearching: Bool = false
    
    private var udpSocket: Int32 = -1
    
    func startDiscovery() {
        isSearching = true
        discoveredServer = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
            if sock < 0 {
                DispatchQueue.main.async { self.isSearching = false }
                return
            }
            
            var broadcastEnable: Int32 = 1
            setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))
            
            var timeout = timeval(tv_sec: 2, tv_usec: 500000)
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = in_port_t(59101).bigEndian
            addr.sin_addr.s_addr = INADDR_BROADCAST
            
            let message = "SOUNDRELAY_DISCOVER"
            let msgBytes = Array(message.utf8)
            
            withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    _ = sendto(sock, msgBytes, msgBytes.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            
            var buffer = [UInt8](repeating: 0, count: 1024)
            var senderAddr = sockaddr_in()
            var senderLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let received = withUnsafeMutablePointer(to: &senderAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    recvfrom(sock, &buffer, buffer.count, 0, sa, &senderLen)
                }
            }
            
            close(sock)
            
            if received > 0 {
                let response = String(bytes: buffer.prefix(received), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if response.starts(with: "SOUNDRELAY_OFFER:") {
                    let parts = response.components(separatedBy: ":")
                    if parts.count >= 5 {
                        let name = parts[1]
                        let ip = parts[2]
                        let audioPort = Int(parts[3]) ?? 59102
                        let webPort = Int(parts[4]) ?? 59100
                        
                        DispatchQueue.main.async {
                            self.discoveredServer = DiscoveredServer(name: name, ip: ip, audioPort: audioPort, webPort: webPort)
                            self.isSearching = false
                        }
                        return
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.isSearching = false
            }
        }
    }
}
