import Foundation

public enum CheckoutGraphQL {
  public static let GET_BY_ID_CHECKOUT_QUERY = #"""
    query GetCheckout($checkoutId: String!) {
      Checkout {
        GetCheckout(checkout_id: $checkoutId) {
          id
          status
          checkout_url
          success_url
          cancel_url
          email
          payment_method
          created_at
          updated_at
          deleted_at
          available_payment_methods { name }
          discount_code
          cart { cart_id currency subtotal shipping }
          totals { currency_code subtotal total taxes shipping discounts }
        }
      }
    }
    """#

  public static let CREATE_CHECKOUT_MUTATION = #"""
    mutation CreateCheckout($cartId: String!) {
      Checkout {
        CreateCheckout(cart_id: $cartId) {
          id
          status
          checkout_url
          success_url
          cancel_url
          email
          payment_method
          created_at
          updated_at
          deleted_at
          available_payment_methods { name }
          cart { cart_id }
        }
      }
    }
    """#

  public static let UPDATE_CHECKOUT_MUTATION = #"""
    mutation UpdateCheckout(
      $checkoutId: String!
      $buyerAcceptsTermsConditions: Boolean
      $buyerAcceptsPurchaseConditions: Boolean
      $billingAddress: AddressArgs
      $shippingAddress: AddressArgs
      $paymentMethod: String
      $cancelUrl: String
      $successUrl: String
      $email: String
      $status: String
    ) {
      Checkout {
        UpdateCheckout(
          checkout_id: $checkoutId
          buyer_accepts_terms_conditions: $buyerAcceptsTermsConditions
          buyer_accepts_purchase_conditions: $buyerAcceptsPurchaseConditions
          billing_address: $billingAddress
          shipping_address: $shippingAddress
          payment_method: $paymentMethod
          cancel_url: $cancelUrl
          success_url: $successUrl
          email: $email
          status: $status
        ) {
          id
          status
          checkout_url
          success_url
          cancel_url
          email
        }
      }
    }
    """#

  public static let DELETE_CHECKOUT_MUTATION = #"""
    mutation RemoveCheckout($checkoutId: String!) {
      Checkout {
        RemoveCheckout(checkout_id: $checkoutId) {
          success
          message
        }
      }
    }
    """#
}
