# Keeps checking until Fly has issued the terminal's certificate, usually within minutes.
# Runs in the app process, so a deploy can interrupt it, and DNS may not resolve yet. The
# terminals page therefore checks again, and a terminal only counts as failed after a while.
class TerminalCertificateJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 20
  CHECK_INTERVAL = 30.seconds
  GIVE_UP_AFTER = 1.hour

  def perform(terminal, attempt = 1)
    return unless terminal.certificate_status.in?(%w[pending failed])
    return terminal.update!(certificate_status: nil) unless TerminalCertificates.needed?

    if TerminalCertificates.request_for(terminal.hostname)
      terminal.update!(certificate_status: "issued")
    elsif attempt < MAX_ATTEMPTS
      self.class.set(wait: CHECK_INTERVAL).perform_later(terminal, attempt + 1)
    elsif terminal.created_at < GIVE_UP_AFTER.ago
      terminal.update!(certificate_status: "failed")
    end
  rescue TerminalCertificates::Error => e
    Rails.logger.error "Certificate for #{terminal.hostname}: #{e.message}"
    terminal.update!(certificate_status: "failed")
  end
end
