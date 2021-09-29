# frozen_string_literal: true

ShopifyAPI::Session.setup(api_key: ENV['SHOPIFY_API_KEY'],
                          secret: ENV['SHOPIFY_SHARED_SECRET'])
