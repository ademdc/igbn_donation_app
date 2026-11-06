module AccountScoped
  extend ActiveSupport::Concern

  included do
    before_action :require_account
  end

  private

  def require_account
    Current.account = Account.for_host(request.host)
    render plain: "Not found", status: :not_found unless Current.account
  end
end
