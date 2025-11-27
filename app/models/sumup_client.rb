require 'net/http'
require 'json'

class SumupClient
  BASE_URL = 'https://api.sumup.com/v0.1'
  
  def initialize(api_key = ENV['SUMUP_API_KEY'])
    @api_key = api_key
  end

  def create_reader_checkout(amount:, currency: 'EUR', email: nil)
    merchant_code = ENV['SUMUP_MERCHANT_CODE']
    reader_id = ENV['SUMUP_READER_ID']
    
    url = URI("#{BASE_URL}/merchants/#{merchant_code}/readers/#{reader_id}/checkout")
    
    request = Net::HTTP::Post.new(url)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request.body = {
      return_url: set_return_url,
      total_amount: {
        value: (amount*100).to_i,
        currency: currency,
        minor_unit: 2
      },
      checkout_reference: "Spende/Donacija ##{SecureRandom.uuid} #{email}".strip
    }.to_json
    response = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    unless response.is_a?(Net::HTTPSuccess)
      raise "Payment failed: #{response.body}"
    end
    
    JSON.parse(response.body)
  end
  
  def get_checkout_status(checkout_id)
    url = URI("#{BASE_URL}/checkouts/#{checkout_id}")
    
    request = Net::HTTP::Get.new(url)
    request['Authorization'] = "Bearer #{@api_key}"
    
    response = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  end
  
  def get_reader_status
    merchant_code = ENV['SUMUP_MERCHANT_CODE']
    reader_id = ENV['SUMUP_READER_ID']
    
    url = URI("#{BASE_URL}/merchants/#{merchant_code}/readers/#{reader_id}")
    
    request = Net::HTTP::Get.new(url)
    request['Authorization'] = "Bearer #{@api_key}"
    
    response = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  end

  def set_return_url
    "https://#{ENV['APP_HOST']}/sumup/checkout_return_url"
  end
end