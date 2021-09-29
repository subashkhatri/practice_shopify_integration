# frozen_string_literal: true

# require "graphql/client"
# require "graphql/client/http"

# Created a background job for generating csv
class GenerateCsvJob < ApplicationJob
  queue_as :default

  CSV_HEADER = %w[name email financial_status paid_at fulfillment_status currency
                  price_subtotal price_total billing_street billing_address1 shipping_zip
                  shipping_country refunded_amount vendor tags risk_level].freeze

  def perform
    ShopifyAPI::Base.activate_session(session)
    generate_csv
  end

  private

  def session
    @session ||= ShopifyAPI::Session.new(domain: "#{ENV['SHOP_NAME']}.myshopify.com",
                                         token: ENV['SHOP_TOKEN'],
                                         api_version: ENV['API_VERSION'])
  end

  def generate_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADER

      parse_orders_response.each { |order| csv << order.values }
    end
  end

  def shopify_orders
    @shopify_orders ||= ShopifyAPI::Order.find(:all, params: { status: 'any', limit: 250 })
  end

  def parse_orders_response
    shopify_orders.map do |order|
      response = build_response(order)

      response.transform_values { |v| v.blank? ? 'N/A' : v }
    end
  end

  def build_response(order) # rubocop:disable Metrics/MethodLength
    last_paid_transaction_date, total_refund_amount, vendor_name, order_risk = fetch_from_order(order)
    # {
    #   billing_street: order.billing_address.address1,
    #   billing_address1: order.billing_address.address2,
    #   shipping_zip: order.shipping_address.zip,
    #   shipping_country: order.shipping_address.country,
    # }

    {
      name: order.name,
      email: order.email,
      financial_status: order.financial_status,
      paid_at: last_paid_transaction_date,
      fulfillment_status: order.fulfillment_status,
      currency: order.currency,
      price_subtotal: order.subtotal_price,
      price_total: order.total_price,
      billing_street: check_for_nil_billing_address(order, 'address1'),
      billing_address1: check_for_nil_billing_address(order, 'address1'),
      shipping_zip: check_for_nil_shipping_address(order, 'zip'),
      shipping_country: check_for_nil_shipping_address(order, 'country'),
      refunded_amount: total_refund_amount,
      vendor: vendor_name,
      tags: order.tags,
      risk_level: order_risk
    }
  end

  def check_for_nil_billing_address(order, method_name)
    unless order.billing_address?.nil?
      return order.billing_address.send(method_name)
    end

    'N/A'
  end

  def check_for_nil_shipping_address(order, method_name)
    unless order.shipping_address?.nil?
      return order.shipping_address.send(method_name)
    end

    'N/A'
  end

  def fetch_from_order(order)
    transaction_details = retrieve_transaction_details(order)

    vendor_names = order.line_items.map { |line_item| ShopifyAPI::Product.find(line_item.product_id).vendor }

    order_risk = ShopifyAPI::OrderRisk.where({ order_id: order.id })

    transaction_details.concat([vendor_names, order_risk])
  end

  def retrieve_transaction_details(order)
    success_transactions = ShopifyAPI::Transaction.where({ order_id: order.id, status: 'success' })

    return [] if success_transactions.blank?

    last_paid_transaction_date = success_transactions.where(kind: 'sale', order_id: order.id).to_a.sum(&:amount)

    total_refund_amount = success_transactions.where(kind: 'refund', order_id: order.id).to_a.sum(&:amount)

    [last_paid_transaction_date, total_refund_amount]
  end
end
