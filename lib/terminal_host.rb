# Routing constraint for the donation terminals. The terminal found here is reused by
# DonationsController, so a request looks it up once.
module TerminalHost
  def self.matches?(request)
    request.env["app.terminal"] ||= Terminal.includes(:account, :payment_connection).for_host(request.host)
    request.env["app.terminal"].present?
  end
end
