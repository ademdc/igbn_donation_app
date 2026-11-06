class SignupsController < MarketingController
  def new
    @signup = Signup.new
  end

  def create
    @signup = Signup.new(signup_params.merge(locale: I18n.locale.to_s))

    if @signup.save
      AccountMailer.with(user: @signup.user).welcome.deliver_later
      # Session cookies are per host, so hand over to the new subdomain with a short-lived token
      redirect_to @signup.account.url("/session/#{@signup.user.generate_token_for(:handover)}?welcome=1"), allow_other_host: true
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Live availability check for the subdomain field
  def check
    subdomain = params[:subdomain].to_s.downcase
    probe = Account.new(name: "x", subdomain: subdomain)
    probe.validate
    errors = probe.errors[:subdomain]
    render json: { available: errors.empty?, message: errors.first, host: "#{subdomain}.#{AppDomain.host}" }
  end

  private

  def signup_params
    params.require(:signup).permit(:organisation_name, :subdomain, :name, :email, :password, :terms)
  end
end
