module ApplicationHelper
  CURRENCY_SYMBOLS = { "EUR" => "€", "GBP" => "£", "USD" => "$", "CHF" => "CHF ", "SEK" => "SEK ", "NOK" => "NOK ", "DKK" => "DKK ", "PLN" => "PLN " }.freeze

  def brand_name
    Rails.configuration.x.brand_name
  end

  def currency_symbol(currency)
    CURRENCY_SYMBOLS.fetch(currency, "#{currency} ")
  end

  def money(amount, currency, precision: 2)
    number_to_currency(amount, unit: currency_symbol(currency), format: "%u%n", precision: precision, strip_insignificant_zeros: false)
  end

  # Whole amounts without decimals, for preset buttons: €5 but €2.50
  def preset_money(amount, currency)
    money(amount, currency, precision: amount.to_d.frac.zero? ? 0 : 2)
  end

  # Dark text on light brand colours, white on dark ones
  def readable_on(hex)
    red, green, blue = hex.delete("#").scan(/../).map { |pair| pair.to_i(16) / 255.0 }
    linear = ->(value) { value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055)**2.4 }
    luminance = 0.2126 * linear[red] + 0.7152 * linear[green] + 0.0722 * linear[blue]
    luminance > 0.4 ? "#12302d" : "#ffffff"
  end
end
