import Foundation
import Network

class RTSPCommandSender {
    
    static let serverIP = "27.105.113.156"   // Windows 區網 IP
    static let serverPort: UInt16 = 9001     // Python command_listener Port
    static var destIP : String = ""
    
    private static var pingTimer: Timer?

    static func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            sendCommand("ping\n") { _, _ in }
        }
    }

    static func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
    
    private static func sendCommand(_ command: String, completion: @escaping (Bool, String) -> Void) {
        let connection = NWConnection(
            host: NWEndpoint.Host(serverIP),
            port: NWEndpoint.Port(rawValue: serverPort)!,
            using: .tcp
        )
        
        // 5 秒連線逾時，避免永遠卡住
        let timeout = DispatchWorkItem {
            connection.cancel()
            completion(false, "連線逾時（5秒）")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: timeout)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                timeout.cancel()
                guard let data = command.data(using: .utf8) else {
                    completion(false, "指令編碼失敗")
                    connection.cancel()
                    return
                }
                connection.send(content: data, completion: .contentProcessed({ error in
                    if let error = error {
                        completion(false, "發送失敗: \(error.localizedDescription)")
                    } else {
                        completion(true, "正在轉發 \(destIP)")
                    }
                    connection.cancel()
                }))
                
            case .failed(let error):
                timeout.cancel()
                completion(false, "連線失敗: \(error.localizedDescription)")
                
            case .cancelled:
                break
                
            default:
                break
            }
        }
        connection.start(queue: .main)
    }
    
    // MARK: - 啟動轉發
    static func sendForwardCommand(sourceURL: String, completion: @escaping (Bool, String) -> Void) {
//        let dest = "rtsp://\(serverIP):8555/cam_recv"
        let dest = "rtsp://127.0.0.1:8555/cam_recv"
        let command = "ffmpeg -rtsp_transport tcp -i \(sourceURL) -c copy -f rtsp -rtsp_transport tcp \(dest)\n"
        destIP = sourceURL
        sendCommand(command, completion: completion)
    }
    
    // MARK: - 停止轉發
    static func sendStopCommand(completion: @escaping (Bool, String) -> Void) {
        sendCommand("stop_forward\n", completion: completion)
    }
}


