import Foundation

public enum MarketGraphQL {
  public static let GET_AVAILABLE_MARKET_QUERY = #"""
    query GetAvailableMarkets {
      Markets {
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
}
