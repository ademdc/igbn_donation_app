# Served by digest (?v=…), so browsers can keep an image until it's replaced
class BrandImagesController < ApplicationController
  def show
    terminal = Terminal.for_host(request.host)
    account = terminal&.account || Account.for_host(request.host)
    image = account&.brand_images&.find_by(kind: params[:kind])
    return head :not_found unless image

    expires_in 1.year, public: true
    send_data image.data, type: image.content_type, disposition: "inline"
  end
end
