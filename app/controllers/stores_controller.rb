# frozen_string_literal: true

# Store controller
class StoresController < ApplicationController
  READ_SCOPES = %w[read_orders read_products].freeze

  # Mock controller for root
  def welcome; end

  def callback
    ENV['SHOP_TOKEN'] = shopify_session.request_token(request.params)
    ShopifyAPI::Base.activate_session(shopify_session)

    redirect_to stores_download_csv_path
  end

  def download_csv_2
    GenerateCsvJob.perform_later
    flash[:notice] = 'Generating order details. Please wait.'
  end

  def download_csv
    csv_data = GenerateCsvJob.perform_now
    respond_to do |format|
      format.html
      format.csv { send_data csv_data, filename: "order-details-#{Date.today}.csv" }
    end
  end

  def create_permission
    permission_url = shopify_session.create_permission_url(READ_SCOPES,
                                                           "#{ENV['DOMAIN']}/auth/shopify/callback",
                                                           { state: 'Nounce' })
    redirect_to permission_url
  end

  private

  # memoraization memoization is saving a method's return value so it does not
  # have to be recomputed each time
  def shopify_session
    @shopify_session ||= ShopifyAPI::Session.new(
      domain: "#{ENV['SHOP_NAME']}.myshopify.com",
      token: nil,
      api_version: ENV['API_VERSION']
    )
  end
end
