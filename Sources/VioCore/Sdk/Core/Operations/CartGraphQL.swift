import Foundation

public enum CartGraphQL {

  public static let GET_CART_QUERY = #"""
    query GetCart($cartId: String!) {
      Cart {
        GetCart(cart_id: $cartId) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping {
              id
              name
              description
              price { amount currency_code amount_incl_taxes tax_amount tax_rate }
            }
            available_shippings {
              id
              name
              description
              country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#

  public static let GET_LINE_ITEMS_BY_SUPPLIER_QUERY = #"""
    query GetLineItemsBySupplier($cartId: String!) {
      Cart {
        GetLineItemsBySupplier(cart_id: $cartId) {
          supplier { id name }
          available_shippings {
            id
            name
            description
            country_code
            price {
              amount
              currency_code
              amount_incl_taxes
              tax_amount
              tax_rate
            }
          }
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              compare_at_incl_taxes
              amount_incl_taxes
              tax_amount
              tax_rate
            }
            shipping {
              id
              name
              description
              price {
                amount
                currency_code
                amount_incl_taxes
                tax_amount
                tax_rate
              }
            }
          }
        }
      }
    }
    """#

  public static let CREATE_CART_MUTATION = #"""
    mutation CreateCart($customerSessionId: String!, $currency: String!, $shippingCountry: String) {
      Cart {
        CreateCart(
          customer_session_id: $customerSessionId
          currency: $currency
          shipping_country: $shippingCountry
        ) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping { id name description price { amount currency_code amount_incl_taxes tax_amount tax_rate } }
            available_shippings {
              id name description country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#

  public static let UPDATE_CART_MUTATION = #"""
    mutation UpdateCart($cartId: String!, $shippingCountry: String!) {
      Cart {
        UpdateCart(cart_id: $cartId, shipping_country: $shippingCountry) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping { id name description price { amount currency_code amount_incl_taxes tax_amount tax_rate } }
            available_shippings {
              id name description country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#

  public static let DELETE_CART_MUTATION = #"""
    mutation DeleteCart($cartId: String!) {
      Cart {
        DeleteCart(cart_id: $cartId) { success message }
      }
    }
    """#

  public static let ADD_ITEM_TO_CART_MUTATION = #"""
    mutation AddItem($cartId: String!, $lineItems: [LineItemInput!]!) {
      Cart {
        AddItem(cart_id: $cartId, line_items: $lineItems) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping { id name description price { amount currency_code amount_incl_taxes tax_amount tax_rate } }
            available_shippings {
              id name description country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#

  public static let UPDATE_ITEM_TO_CART_MUTATION = #"""
    mutation UpdateItem($cartId: String!, $cartItemId: String!, $qty: Int, $shippingId: String) {
      Cart {
        UpdateItem(cart_id: $cartId, cart_item_id: $cartItemId, qty: $qty, shipping_id: $shippingId) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping { id name description price { amount currency_code amount_incl_taxes tax_amount tax_rate } }
            available_shippings {
              id name description country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#

  public static let DELETE_ITEM_TO_CART_MUTATION = #"""
    mutation DeleteItem($cartId: String!, $cartItemId: String!) {
      Cart {
        DeleteItem(cart_id: $cartId, cart_item_id: $cartItemId) {
          cart_id
          customer_session_id
          shipping_country
          line_items {
            id
            supplier
            image { id url width height }
            sku
            barcode
            brand
            product_id
            title
            variant_id
            variant_title
            variant { option value }
            quantity
            price {
              amount
              currency_code
              discount
              compare_at
              amount_incl_taxes
              compare_at_incl_taxes
              tax_amount
              tax_rate
            }
            shipping { id name description price { amount currency_code amount_incl_taxes tax_amount tax_rate } }
            available_shippings {
              id name description country_code
              price { amount currency_code tax_amount tax_rate amount_incl_taxes }
            }
          }
          currency
          available_shipping_countries
          shipping
          subtotal
        }
      }
    }
    """#
}
