# Locale for the account-facing app (login, dashboard): the user's saved choice,
# then ?locale=, then the browser language.
module AppLocale
  extend ActiveSupport::Concern

  included do
    around_action :switch_app_locale
  end

  private

  def switch_app_locale(&action)
    if Account::LOCALES.include?(params[:locale])
      session[:locale] = params[:locale]
      # Picking a language in the switcher replaces the one saved at signup
      current_user.update_column(:locale, params[:locale]) if current_user && current_user.locale != params[:locale]
    end
    locale = current_user&.locale || session[:locale] || browser_locale
    I18n.with_locale(locale, &action)
  end

  def browser_locale
    accepted = request.headers["Accept-Language"].to_s.scan(/([a-z]{2})(?:-[A-Za-z]{2})?(?:;q=([\d.]+))?/)
      .sort_by { |_, q| -(q || 1).to_f }
      .map { |code, _| %w[hr sr].include?(code) ? "bs" : code }
    (accepted & Account::LOCALES).first || "de"
  end
end
