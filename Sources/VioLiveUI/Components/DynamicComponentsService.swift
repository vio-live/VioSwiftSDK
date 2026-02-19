import Foundation
import VioCore

public enum DynamicComponentsService {
    struct RemoteDTO: Decodable {
        let id: String
        let type: String
        let startTime: String?
        let endTime: String?
        let position: String?
        let triggerOn: String?
        let data: DataPayload

        struct DataPayload: Decodable {
            let title: String?
            let text: String?
            let animation: String?
            let duration: Double?
            let productId: Int?
            let product: ProductDtoCompat?
        }
    }

    public static func fetch(for streamId: String?) async throws -> [DynamicComponent] {
        let iso = ISO8601DateFormatter()

        guard let streamId = streamId else {
            throw URLError(.badURL) // o tu error custom
        }

        let urlString = "https://api-qa.reachu.io/api/components/stream/\(streamId)"
        print("URL https://api-qa.reachu.io/api/components/stream/\(streamId)")
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("THVXN06-MGB4D4P-KCPRCKP-RHGT6VJ", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await URLSession.shared.data(for: request)
        print("Pase Try await")
        let raw = try JSONDecoder().decode([RemoteDTO].self, from: data)
        print("Pase 1")

        var out: [DynamicComponent] = []
        for dto in raw {
            let type = DynamicComponentType(rawValue: dto.type) ?? .banner
            let position = dto.position.flatMap { DynamicComponentPosition(rawValue: $0) }
            let trigger = dto.triggerOn.flatMap { DynamicComponentTrigger(rawValue: $0) }
            let start = dto.startTime.flatMap { iso.date(from: $0) }
            let end = dto.endTime.flatMap { iso.date(from: $0) }

            switch type {
            case .banner:
                let banner = BannerComponentData(
                    title: dto.data.title,
                    text: dto.data.text,
                    position: position,
                    animation: dto.data.animation,
                    duration: dto.data.duration,
                    startTime: start,
                    endTime: end
                )
                out.append(
                    DynamicComponent(
                        id: dto.id,
                        type: .banner,
                        startTime: start,
                        endTime: end,
                        position: position,
                        triggerOn: trigger,
                        data: .banner(banner)
                    )
                )

            case .featuredProduct:
                // si viene el producto completo, lo usamos
                if let product = dto.data.product?.asProduct() {
                    let fp = FeaturedProductComponentData(
                        product: product,
                        productId: dto.data.productId,
                        position: position,
                        startTime: start,
                        endTime: end,
                        triggerOn: trigger
                    )
                    out.append(
                        DynamicComponent(
                            id: dto.id,
                            type: .featuredProduct,
                            startTime: start,
                            endTime: end,
                            position: position,
                            triggerOn: trigger,
                            data: .featuredProduct(fp)
                        )
                    )
                }
                // if only productId comes, you could do an extra fetch here if needed
            }
        }
        return out
    }
}
