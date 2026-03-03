import Foundation
import Combine

/// Manager para conexión WebSocket con servidor de eventos
/// URL: wss://api-dev.vio.live/ws/35
class WebSocketManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var currentPoll: PollEventData?
    @Published var currentProduct: ProductEventData?
    @Published var currentContest: ContestEventData?
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession!
    
    override init() {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect() {
        guard !isConnected else {
            print("🔌 [WebSocket] Ya está conectado, ignorando nueva conexión")
            return
        }
        
        let url = URL(string: "wss://api-dev.vio.live/ws/35")!
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        
        print("🔌 [WebSocket] Conectando a: \(url.absoluteString)")
        receiveMessage()
    }
    
    func disconnect() {
        guard isConnected else { return }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        print("🔌 [WebSocket] Desconectado")
    }
    
    private func receiveMessage() {
        guard isConnected, webSocketTask != nil else {
            print("⚠️ [WebSocket] No se puede recibir mensajes, socket no conectado")
            return
        }
        
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("📩 [WebSocket] Mensaje recibido: \(text)")
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📩 [WebSocket] Mensaje recibido (data): \(text)")
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continuar recibiendo mensajes solo si seguimos conectados
                if self.isConnected {
                    self.receiveMessage()
                }
                
            case .failure(let error):
                print("❌ [WebSocket] Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isConnected = false
                    self.webSocketTask = nil
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        // Primero, obtener el tipo de evento
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventType = json["type"] as? String
        else {
            print("❌ [WebSocket] No se pudo parsear el tipo de evento")
            return
        }
        
        // Decodificar según el tipo
        do {
            switch eventType {
            case "product":
                let event = try JSONDecoder().decode(ProductEvent.self, from: data)
                handleProductEvent(event)
            case "poll":
                let event = try JSONDecoder().decode(PollEvent.self, from: data)
                handlePollEvent(event)
            case "contest":
                let event = try JSONDecoder().decode(ContestEvent.self, from: data)
                handleContestEvent(event)
            default:
                print("⚠️ [WebSocket] Tipo de evento desconocido: \(eventType)")
            }
        } catch {
            print("❌ [WebSocket] Error decodificando evento: \(error)")
        }
    }
    
    private func handleProductEvent(_ event: ProductEvent) {
        DispatchQueue.main.async {
            print("🛍️ [WebSocket] Producto recibido: \(event.data.name)")
            var productData = event.data
            // Copiar campaignLogo del evento al data si existe
            if productData.campaignLogo == nil && event.campaignLogo != nil {
                productData.campaignLogo = event.campaignLogo
            }
            print("🛍️ [WebSocket] Product campaignLogo: \(productData.campaignLogo ?? "nil")")
            self.currentProduct = productData
        }
    }
    
    private func handlePollEvent(_ event: PollEvent) {
        DispatchQueue.main.async {
            print("📊 [WebSocket] Poll recibido: \(event.data.question)")
            var pollData = event.data
            // Copiar campaignLogo del evento al data si existe
            if pollData.campaignLogo == nil && event.campaignLogo != nil {
                pollData.campaignLogo = event.campaignLogo
            }
            print("📊 [WebSocket] Poll campaignLogo: \(pollData.campaignLogo ?? "nil")")
            self.currentPoll = pollData
        }
    }
    
    private func handleContestEvent(_ event: ContestEvent) {
        DispatchQueue.main.async {
            print("🎁 [WebSocket] Concurso recibido: \(event.data.name)")
            print("🎁 [WebSocket] Contest campaignLogo en evento root: \(event.campaignLogo ?? "nil")")
            print("🎁 [WebSocket] Contest campaignLogo en data: \(event.data.campaignLogo ?? "nil")")
            var contestData = event.data
            // Copiar campaignLogo del evento al data si existe
            if contestData.campaignLogo == nil && event.campaignLogo != nil {
                contestData.campaignLogo = event.campaignLogo
                print("🎁 [WebSocket] ✅ Copiado campaignLogo del root al data")
            }
            print("🎁 [WebSocket] Contest campaignLogo final: \(contestData.campaignLogo ?? "nil")")
            self.currentContest = contestData
        }
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            print("✅ [WebSocket] Conectado exitosamente")
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
            print("🔌 [WebSocket] Conexión cerrada. Código: \(closeCode.rawValue)")
        }
    }
}

// MARK: - Event Models

struct ProductEvent: Codable {
    let type: String
    let data: ProductEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct ProductEventData: Codable, Equatable {
    let id: String
    let productId: String  // El ID numérico real del producto en Vio
    let name: String
    let description: String
    let price: String
    let currency: String
    let imageUrl: String
    var campaignLogo: String?
}

struct PollEvent: Codable {
    let type: String
    let data: PollEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct PollEventData: Codable, Identifiable, Equatable {
    let id: String
    let question: String
    let options: [PollOption]
    let duration: Int
    let imageUrl: String?
    var campaignLogo: String?
}

struct PollOption: Codable, Identifiable, Equatable {
    let id = UUID()
    let text: String
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case avatarUrl
        case imageUrl
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        // Try to decode both avatarUrl and imageUrl
        if let url = try container.decodeIfPresent(String.self, forKey: .avatarUrl) {
            avatarUrl = url
        } else {
            avatarUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(avatarUrl, forKey: .avatarUrl)
    }
    
    // Init for manual creation (preview, tests)
    init(text: String, avatarUrl: String?) {
        self.text = text
        self.avatarUrl = avatarUrl
    }
}

struct ContestEvent: Codable {
    let type: String
    let data: ContestEventData
    let campaignLogo: String?
    let timestamp: Int64
}

struct ContestEventData: Codable, Equatable {
    let id: String
    let name: String
    let prize: String
    let deadline: String
    let maxParticipants: Int
    var campaignLogo: String?
}

