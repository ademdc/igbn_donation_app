# The super admin is in English, whatever the app's default language is
module EnglishLocale
  extend ActiveSupport::Concern

  included do
    around_action { |_, action| I18n.with_locale(:en, &action) }
  end
end
