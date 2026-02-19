import Foundation

public enum PaymentGraphQL {
  public static let GET_AVAILABLE_METHODS_PAYMENT_QUERY = #"""
    query GetAvailablePaymentMethods {
      Payment {
        GetAvailablePaymentMethods {
          name
          config {
            name
            type
            value
          }
        }
      }
    }
    """#

  public static let STRIPE_INTENT_PAYMENT_MUTATION = #"""
    mutation CreatePaymentIntentStripe($checkoutId: String!, $returnEphemeralKey: Boolean) {
      Payment {
        CreatePaymentIntentStripe(
          checkout_id: $checkoutId
          return_ephemeral_key: $returnEphemeralKey
        ) {
          client_secret
          customer
          publishable_key
          ephemeral_key
        }
      }
    }
    """#

  public static let STRIPE_PLATFORM_BUILDER_PAYMENT_MUTATION = #"""
    mutation CreatePaymentStripe(
      $checkoutId: String!
      $successUrl: String!
      $paymentMethod: String!
      $email: String!
    ) {
      Payment {
        CreatePaymentStripe(
          checkout_id: $checkoutId
          success_url: $successUrl
          payment_method: $paymentMethod
          email: $email
        ) {
          checkout_url
          order_id
        }
      }
    }
    """#

  public static let KLARNA_PLATFORM_BUILDER_PAYMENT_MUTATION = #"""
    mutation Payment($checkoutId: String!, $countryCode: String!, $href: String!, $email: String!) {
      Payment {
        CreatePaymentKlarna(
          checkout_id: $checkoutId
          country_code: $countryCode
          href: $href
          email: $email
        ) {
          order_id
          status
          locale
          html_snippet
        }
      }
    }
    """#

  public static let KLARNA_NATIVE_INIT_PAYMENT_MUTATION = #"""
    mutation CreatePaymentKlarnaNative(
      $shippingAddress: KlarnaNativeAddressInput
      $checkoutId: String!
      $countryCode: String
      $currency: String
      $locale: String
      $returnUrl: String
      $intent: String
      $autoCapture: Boolean
      $customer: KlarnaNativeCustomerInput
      $billingAddress: KlarnaNativeAddressInput
    ) {
      Payment {
        CreatePaymentKlarnaNative(
          shipping_address: $shippingAddress
          checkout_id: $checkoutId
          country_code: $countryCode
          currency: $currency
          locale: $locale
          return_url: $returnUrl
          intent: $intent
          auto_capture: $autoCapture
          customer: $customer
          billing_address: $billingAddress
        ) {
          cart_id
          checkout_id
          client_token
          purchase_country
          purchase_currency
          session_id
          payment_method_categories {
            identifier
            name
            asset_urls {
              descriptive
              standard
            }
          }
        }
      }
    }
    """#

  public static let KLARNA_NATIVE_CONFIRM_PAYMENT_MUTATION = #"""
    mutation ConfirmPaymentKlarnaNative(
      $checkoutId: String!
      $authorizationToken: String!
      $autoCapture: Boolean
      $customer: KlarnaNativeCustomerInput
      $billingAddress: KlarnaNativeAddressInput
      $shippingAddress: KlarnaNativeAddressInput
    ) {
      Payment {
        ConfirmPaymentKlarnaNative(
          checkout_id: $checkoutId
          authorization_token: $authorizationToken
          auto_capture: $autoCapture
          customer: $customer
          billing_address: $billingAddress
          shipping_address: $shippingAddress
        ) {
          order_id
          checkout_id
          fraud_status
          order {
            order_id
            status
            locale
            html_snippet
            purchase_country
            purchase_currency
            order_amount
            order_tax_amount
            order_lines {
              type
              name
              quantity
              unit_price
              total_amount
              tax_rate
            }
          }
        }
      }
    }
    """#

  public static let KLARNA_NATIVE_ORDER_QUERY = #"""
    query GetKlarnaOrderNative($orderId: String!, $userId: String) {
      Payment {
        GetKlarnaOrderNative(order_id: $orderId, user_id: $userId) {
          order_id
          status
          locale
          html_snippet
          purchase_country
          purchase_currency
          order_amount
          order_tax_amount
          payment_method_categories {
            identifier
            name
          }
          order_lines {
            type
            name
            quantity
            unit_price
            total_amount
            tax_rate
            tax_amount
          }
        }
      }
    }
    """#

  public static let VIPPS_PAYMENT = #"""
    mutation CreatePaymentVipps($checkoutId: String!, $email: String!, $returnUrl: String!) {
      Payment {
        CreatePaymentVipps(checkout_id: $checkoutId, email: $email, return_url: $returnUrl) {
          payment_url
        }
      }
    }
    """#
}
