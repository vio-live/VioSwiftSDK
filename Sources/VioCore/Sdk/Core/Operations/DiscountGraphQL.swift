import Foundation

public enum DiscountGraphQL {
  public static let GET_DISCOUNT_QUERY = #"""
    query GetDiscounts {
      Discounts {
        GetDiscounts {
          id
          code
          percentage
          start_date
          end_date
          discount_count
          discount_type { id type }
          discount_product { id product { id title sku revenue } }
          discount_metadata { apiKey }
        }
      }
    }
    """#

  public static let GET_DISCOUNT_BY_ID_QUERY = #"""
    query GetDiscountsById($discountId: Int!) {
      Discounts {
        GetDiscountsById(discount_id: $discountId) {
          id
          code
          percentage
          start_date
          end_date
          discount_count
          discount_type { id type }
          discount_product { id product { id title sku revenue } }
        }
      }
    }
    """#

  public static let GET_DISCOUNT_TYPE_QUERY = #"""
    query GetDiscountType($getDiscountTypeId: Int, $type: String) {
      Discounts {
        GetDiscountType(id: $getDiscountTypeId, type: $type) {
          id
          type
        }
      }
    }
    """#

  public static let ADD_DISCOUNT_MUTATION = #"""
    mutation AddDiscount(
      $code: String!
      $percentage: Int!
      $startDate: String!
      $endDate: String!
      $typeId: Int!
    ) {
      Discounts {
        AddDiscount(
          code: $code
          percentage: $percentage
          start_date: $startDate
          end_date: $EndDate
          type_id: $typeId
        ) {
          id
          code
          percentage
          start_date
          end_date
          discount_count
          discount_type { id type }
          discount_product { id product { id title sku revenue } }
        }
      }
    }
    """#.replacingOccurrences(of: "$EndDate", with: " $endDate ")

  public static let APPLY_DISCOUNT_MUTATION = #"""
    mutation ApplyDiscount($code: String!, $cartId: String!) {
      Discounts {
        ApplyDiscount(code: $code, cart_id: $cartId) {
          executed
          message
        }
      }
    }
    """#

  public static let DELETE_APPLIED_DISCOUNT_MUTATION = #"""
    mutation DeleteAppliedDiscount($code: String!, $cartId: String!) {
      Discounts {
        DeleteAppliedDiscount(code: $code, cart_id: $cartId) {
          executed
          message
        }
      }
    }
    """#

  public static let DELETE_DISCOUNT_MUTATION = #"""
    mutation DeleteDiscount($discountId: Int!) {
      Discounts {
        DeleteDiscount(discount_id: $discountId) {
          executed
          message
        }
      }
    }
    """#

  public static let UPDATE_DISCOUNT_MUTATION = #"""
    mutation UpdateDiscount(
      $discountId: Int!
      $code: String
      $percentage: Int
      $startDate: String
      $endDate: String
      $products: [Int!]
    ) {
      Discounts {
        UpdateDiscount(
          discount_id: $discountId
          code: $code
          percentage: $percentage
          start_date: $startDate
          end_date: $endDate
          products: $products
        ) {
          id
          code
          percentage
          start_date
          end_date
          discount_count
          discount_type { id type }
          discount_product { id product { id title sku revenue } }
        }
      }
    }
    """#

  public static let VERIFY_DISCOUNT_MUTATION = #"""
    mutation VerifyDiscount($verifyDiscountId: Int, $code: String) {
      Discounts {
        VerifyDiscount(id: $verifyDiscountId, code: $code) {
          valid
          message
          discount {
            id
            code
            percentage
            start_date
            end_date
            discount_type { id type }
            discount_product { id product { id title sku revenue } }
          }
        }
      }
    }
    """#
}
