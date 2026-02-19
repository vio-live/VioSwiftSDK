import Foundation

public enum ChannelGraphQL {

    public static let GET_PRODUCTS_CHANNEL_QUERY = #"""
        query Products(
          $barcodeList: [String!]!
          $skuList: [String!]!
          $categoryIds: [Int!]!
          $productIds: [Int!]!
          $currency: String
          $imageSize: ImageSize
          $useCache: Boolean!
          $shippingCountryCode: String
        ) {
          Channel {
            Products(
              barcode_list: $barcodeList
              sku_list: $skuList
              category_ids: $categoryIds
              product_ids: $productIds
              currency: $currency
              image_size: $imageSize
              useCache: $useCache
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCTS_QUERY = #"""
        query GetProducts(
          $currency: String
          $shippingCountryCode: String
          $imageSize: ImageSize
        ) {
          Channel {
            GetProducts(
              currency: $currency
              shipping_country_code: $shippingCountryCode
              image_size: $imageSize
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCTS_BY_CATEGORY_CHANNEL_QUERY = #"""
        query GetProductsByCategory(
          $categoryId: Int!
          $imageSize: ImageSize
          $currency: String
          $shippingCountryCode: String
        ) {
          Channel {
            GetProductsByCategory(
              categoryId: $categoryId
              image_size: $imageSize
              currency: $currency
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCTS_BY_CATEGORIES_CHANNEL_QUERY = #"""
        query GetProductsByCategories(
          $currency: String
          $imageSize: ImageSize
          $categoryIds: [Int!]
          $shippingCountryCode: String
        ) {
          Channel {
            GetProductsByCategories(
              currency: $currency
              image_size: $imageSize
              categoryIds: $categoryIds
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCT_CHANNEL_QUERY = #"""
        query GetProduct(
          $currency: String
          $imageSize: ImageSize
          $sku: String
          $barcode: String
          $productId: Int
          $shippingCountryCode: String
        ) {
          Channel {
            GetProduct(
              currency: $currency
              image_size: $imageSize
              sku: $sku
              barcode: $barcode
              product_id: $productId
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCTS_BY_IDS_CHANNEL_QUERY = #"""
        query GetProductsByIds(
          $currency: String
          $imageSize: ImageSize
          $productIds: [Int!]
          $useCache: Boolean!
          $shippingCountryCode: String
        ) {
          Channel {
            GetProductsByIds(
              currency: $currency
              image_size: $imageSize
              product_ids: $productIds
              useCache: $useCache
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCT_BY_SKUS_CHANNEL_QUERY = #"""
        query GetProductBySKUs(
          $sku: String!
          $currency: String
          $imageSize: ImageSize
          $productId: Int
          $shippingCountryCode: String
        ) {
          Channel {
            GetProductBySKUs(
              sku: $sku
              currency: $currency
              image_size: $imageSize
              product_id: $productId
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
                images { id url width height order }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_PRODUCT_BY_BARCODES_CHANNEL_QUERY = #"""
        query GetProductByBarcodes(
          $barcode: String!
          $productId: Int
          $imageSize: ImageSize
          $currency: String
          $shippingCountryCode: String
        ) {
          Channel {
            GetProductByBarcodes(
              barcode: $barcode
              product_id: $productId
              image_size: $imageSize
              currency: $currency
              shipping_country_code: $shippingCountryCode
            ) {
              id
              brand
              title
              description
              sku
              quantity
              price {
                amount
                currency_code
                compare_at
                amount_incl_taxes
                compare_at_incl_taxes
                tax_amount
                tax_rate
              }
              variants {
                id
                barcode
                quantity
                sku
                title
                images { id url width height order }
                price {
                  amount
                  currency_code
                  compare_at
                  amount_incl_taxes
                  compare_at_incl_taxes
                  tax_amount
                  tax_rate
                }
              }
              barcode
              options { id name order values }
              categories { id name }
              images { id url width height order }
              product_shipping {
                id
                name
                description
                custom_price_enabled
                default
                shipping_country {
                  id
                  country
                  price {
                    amount
                    currency_code
                    amount_incl_taxes
                    tax_amount
                    tax_rate
                  }
                }
              }
              supplier
              imported_product
              referral_fee
              options_enabled
              digital
              origin
              return {
                return_right
                return_label
                return_cost
                supplier_policy
                return_address {
                  same_as_business
                  same_as_warehouse
                  country
                  timezone
                  address
                  address_2
                  post_code
                  return_city
                }
              }
            }
          }
        }
        """#

    public static let GET_CATEGORIES_CHANNEL_QUERY = #"""
        query GetCategories {
          Channel {
            GetCategories {
              id
              name
              father_category_id
              category_image
            }
          }
        }
        """#

    public static let GET_AVAILABLE_MARKETS_CHANNEL_QUERY = #"""
        query GetAvailableMarkets {
          Channel {
            GetAvailableMarkets {
              name
              official
              code
              flag
              phone_code
              currency { code name symbol }
            }
          }
        }
        """#

    public static let GET_PURCHASE_CONDITIONS_CHANNEL_QUERY = #"""
        query Channel {
          Channel {
            GetPurchaseConditions {
              headline
              lead
              updated
              content { type }
            }
          }
        }
        """#

    public static let GET_TERMS_AND_CONDITIONS_CHANNEL_QUERY = #"""
        query GetTermsAndConditions {
          Channel {
            GetTermsAndConditions {
              headline
              lead
              updated
              content { type }
            }
          }
        }
        """#

    public static let GET_CHANNELS_CHANNEL_QUERY = #"""
        query GetChannels {
          Channel {
            GetChannels {
              channel
              name
              id
              api_key
              settings {
                stripe_payment_link
                stripe_payment_intent
                klarna
                markets
                purchase_conditions
              }
            }
          }
        }
        """#
}
