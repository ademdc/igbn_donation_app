class ApplicationController < ActionController::Base
  before_action :keep_tenant_pages_out_of_search

  private

  # Terminals and dashboards live on account hosts and should not show up in Google
  def keep_tenant_pages_out_of_search
    response.headers["X-Robots-Tag"] = "noindex, nofollow" unless AppDomain.marketing_host?(request.host)
  end
end
