class MarketingController < ApplicationController
  LOCALES = Account::LOCALES

  layout "marketing"
  around_action :switch_locale, except: :locale_redirect

  def locale_redirect
    # The site opens in German whatever the browser language; visitors switch in the header
    redirect_to marketing_path(locale: "de")
  end

  def index
  end

  def imprint
  end

  def privacy
  end

  def terms
  end

  private

  def switch_locale(&action)
    I18n.with_locale(params[:locale], &action)
  end
end
