import Foundation
import VioCore

/// Mock data provider for testing and previews
public class MockDataProvider {
    public static let shared = MockDataProvider()

    private init() {}

    // MARK: - Sample Products

    public let sampleProducts: [Product] = [
        Product(
            id: 101,
            title: "Vio Wireless Headphones",
            brand: "Vio Audio",
            description:
                "Experience immersive sound with our premium noise-cancelling wireless headphones. Perfect for music lovers and professionals.",
            tags: "audio, headphones, wireless, noise-cancelling",
            sku: "RCH-HP-001",
            quantity: 50,
            price: Price(
                amount: 199.99,
                currency_code: "USD",
                amount_incl_taxes: 219.99,
                tax_amount: 20.00,
                tax_rate: 0.10,
                compare_at: 249.99,
                compare_at_incl_taxes: 274.99
            ),
            variants: [
                Variant(
                    id: "v101-black",
                    barcode: "1234567890123",
                    price: Price(amount: 199.99, currency_code: "USD"),
                    quantity: 25,
                    sku: "RCH-HP-001-BLK",
                    title: "Black"
                ),
                Variant(
                    id: "v101-white",
                    barcode: "1234567890124",
                    price: Price(amount: 199.99, currency_code: "USD"),
                    quantity: 25,
                    sku: "RCH-HP-001-WHT",
                    title: "White"
                ),
            ],
            barcode: "1234567890123",
            options: [
                Option(id: "opt1", name: "Color", order: 1, values: "Black, White")
            ],
            categories: [
                _Category(id: 1, name: "Electronics"),
                _Category(id: 5, name: "Audio"),
            ],
            images: [
                ProductImage(
                    id: "img101-1",
                    url:
                        "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
                ProductImage(
                    id: "img101-2",
                    url:
                        "https://images.unsplash.com/photo-1583394838336-acd977736f90?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
                ProductImage(
                    id: "img101-3",
                    url:
                        "https://images.unsplash.com/photo-1487215078519-e21cc028cb29?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 2
                ),
            ],
            supplier: "Vio Tech",
            supplier_id: 1
        ),
        Product(
            id: 102,
            title: "Vio Smart Watch Series 5",
            brand: "Vio Wearables",
            description:
                "Track your fitness, monitor your health, and stay connected with our latest smartwatch featuring advanced sensors and long battery life.",
            tags: "wearable, smartwatch, fitness, health",
            sku: "RCH-SW-005",
            quantity: 30,
            price: Price(
                amount: 349.99,
                currency_code: "USD",
                amount_incl_taxes: 384.99,
                tax_amount: 35.00,
                tax_rate: 0.10
            ),
            variants: [
                Variant(
                    id: "v102-42mm",
                    barcode: "1234567890125",
                    price: Price(amount: 349.99, currency_code: "USD"),
                    quantity: 15,
                    sku: "RCH-SW-005-42MM",
                    title: "42mm"
                ),
                Variant(
                    id: "v102-44mm",
                    barcode: "1234567890126",
                    price: Price(amount: 349.99, currency_code: "USD"),
                    quantity: 15,
                    sku: "RCH-SW-005-44MM",
                    title: "44mm"
                ),
            ],
            barcode: "1234567890125",
            options: [
                Option(id: "opt2", name: "Size", order: 1, values: "42mm, 44mm")
            ],
            categories: [
                _Category(id: 1, name: "Electronics"),
                _Category(id: 6, name: "Wearables"),
            ],
            images: [
                ProductImage(
                    id: "img102-1",
                    url:
                        "https://images.unsplash.com/photo-1434493789847-2f02dc6ca35d?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
                ProductImage(
                    id: "img102-2",
                    url:
                        "https://images.unsplash.com/photo-1544117519-31a4b719223d?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
            ],
            supplier: "Vio Innovations",
            supplier_id: 2
        ),
        Product(
            id: 103,
            title: "Vio Minimalist Backpack",
            brand: "Vio Gear",
            description:
                "Stylish and durable backpack perfect for daily commutes, travel, and outdoor adventures. Made with premium materials and thoughtful design.",
            tags: "bag, backpack, travel, outdoor, minimalist",
            sku: "RCH-BP-001",
            quantity: 0,  // Out of stock
            price: Price(
                amount: 89.99,
                currency_code: "USD",
                amount_incl_taxes: 98.99,
                tax_amount: 9.00,
                tax_rate: 0.10,
                compare_at: 100.00,
                compare_at_incl_taxes: 110.00
            ),
            variants: [
                Variant(
                    id: "v103-charcoal",
                    barcode: "1234567890127",
                    price: Price(amount: 89.99, currency_code: "USD"),
                    quantity: 0,
                    sku: "RCH-BP-001-CHR",
                    title: "Charcoal"
                ),
                Variant(
                    id: "v103-navy",
                    barcode: "1234567890128",
                    price: Price(amount: 89.99, currency_code: "USD"),
                    quantity: 0,
                    sku: "RCH-BP-001-NVY",
                    title: "Navy"
                ),
            ],
            barcode: "1234567890127",
            options: [
                Option(id: "opt3", name: "Color", order: 1, values: "Charcoal, Navy")
            ],
            categories: [
                _Category(id: 2, name: "Accessories"),
                _Category(id: 7, name: "Bags"),
            ],
            images: [
                ProductImage(
                    id: "img103-1",
                    url:
                        "https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
                ProductImage(
                    id: "img103-2",
                    url:
                        "https://images.unsplash.com/photo-1622560480605-d83c853bc5c3?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
                ProductImage(
                    id: "img103-3",
                    url:
                        "https://images.unsplash.com/photo-1581605405669-fcdf81165afa?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 2
                ),
            ],
            supplier: "Vio Outdoors",
            supplier_id: 3
        ),
        Product(
            id: 104,
            title: "Vio Wireless Charging Pad",
            brand: "Vio Power",
            description:
                "Fast and convenient wireless charging for all your devices. Sleek design with LED indicator and built-in safety features.",
            tags: "charger, wireless, power, fast-charging",
            sku: "RCH-CP-002",
            quantity: 15,  // Back in stock
            price: Price(
                amount: 39.99,
                currency_code: "USD",
                amount_incl_taxes: 43.99,
                tax_amount: 4.00,
                tax_rate: 0.10
            ),
            variants: [],
            barcode: "1234567890129",
            options: [],
            categories: [
                _Category(id: 1, name: "Electronics"),
                _Category(id: 8, name: "Chargers"),
            ],
            images: [
                ProductImage(
                    id: "img104-1",
                    url:
                        "https://images.unsplash.com/photo-1585338447937-7082f8fc763d?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
                ProductImage(
                    id: "img104-2",
                    url:
                        "https://images.unsplash.com/photo-1609592373050-87a8f2e04f40?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
            ],
            supplier: "Vio Energy",
            supplier_id: 4
        ),
        Product(
            id: 105,
            title: "Vio Bluetooth Speaker",
            brand: "Vio Audio",
            description:
                "Portable bluetooth speaker with 360-degree sound, waterproof design, and 12-hour battery life. Perfect for outdoor adventures.",
            tags: "speaker, bluetooth, portable, waterproof, music",
            sku: "RCH-BT-003",
            quantity: 25,
            price: Price(
                amount: 79.99,
                currency_code: "USD",
                amount_incl_taxes: 87.99,
                tax_amount: 8.00,
                tax_rate: 0.10,
                compare_at: 99.99,
                compare_at_incl_taxes: 109.99
            ),
            variants: [
                Variant(
                    id: "v105-red",
                    barcode: "1234567890130",
                    price: Price(amount: 79.99, currency_code: "USD"),
                    quantity: 10,
                    sku: "RCH-BT-003-RED",
                    title: "Red"
                ),
                Variant(
                    id: "v105-blue",
                    barcode: "1234567890131",
                    price: Price(amount: 79.99, currency_code: "USD"),
                    quantity: 15,
                    sku: "RCH-BT-003-BLU",
                    title: "Blue"
                ),
            ],
            barcode: "1234567890130",
            options: [
                Option(id: "opt4", name: "Color", order: 1, values: "Red, Blue")
            ],
            categories: [
                _Category(id: 1, name: "Electronics"),
                _Category(id: 5, name: "Audio"),
            ],
            images: [
                ProductImage(
                    id: "img105-1",
                    url:
                        "https://images.unsplash.com/photo-1608043152269-423dbba4e7e1?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
                ProductImage(
                    id: "img105-2",
                    url:
                        "https://images.unsplash.com/photo-1588422904075-be4be63e1bd6?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
                ProductImage(
                    id: "img105-3",
                    url:
                        "https://images.unsplash.com/photo-1545454675-3531b543be5d?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 2
                ),
            ],
            supplier: "Vio Audio",
            supplier_id: 1
        ),
        Product(
            id: 106,
            title: "Vio Gaming Mouse",
            brand: "Vio Gaming",
            description:
                "High-precision gaming mouse with customizable RGB lighting, programmable buttons, and ergonomic design for competitive gaming.",
            tags: "gaming, mouse, rgb, precision, ergonomic",
            sku: "RCH-GM-004",
            quantity: 40,
            price: Price(
                amount: 59.99,
                currency_code: "USD",
                amount_incl_taxes: 65.99,
                tax_amount: 6.00,
                tax_rate: 0.10
            ),
            variants: [],
            barcode: "1234567890132",
            options: [],
            categories: [
                _Category(id: 1, name: "Electronics"),
                _Category(id: 9, name: "Gaming"),
            ],
            images: [
                ProductImage(
                    id: "img106-1",
                    url:
                        "https://images.unsplash.com/photo-1527814050087-3793815479db?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 0
                ),
                ProductImage(
                    id: "img106-2",
                    url:
                        "https://images.unsplash.com/photo-1615663245857-ac93bb7c39e7?w=400&h=300&fit=crop&crop=center",
                    width: 400,
                    height: 300,
                    order: 1
                ),
            ],
            supplier: "Vio Gaming",
            supplier_id: 5
        ),
    ]
}
