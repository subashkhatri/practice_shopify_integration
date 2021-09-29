# frozen_string_literal: true

module SessionHelper
  def shopify_api_session(token = nil)
    ShopifyAPI::Session.new(domain: "#{ENV['SHOP_NAME']}.myshopify.com", token: token,
                            api_version: ENV['API_VERSION'])
  end
end
