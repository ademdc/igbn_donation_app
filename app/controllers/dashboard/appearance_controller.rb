module Dashboard
  class AppearanceController < BaseController
    def show
    end

    def update
      saved = @account.update(appearance_params)
      saved &&= store_images

      if saved
        redirect_to dashboard_appearance_path, notice: t("app.appearance.saved")
      else
        render :show, status: :unprocessable_entity
      end
    end

    def remove_image
      @account.brand_images.where(kind: params[:kind]).destroy_all
      redirect_to dashboard_appearance_path, notice: t("app.appearance.saved")
    end

    private

    def store_images
      BrandImage::KINDS.all? do |kind|
        upload = params.dig(:account, kind)
        next true if upload.blank?

        image = BrandImage.store(@account, kind, upload)
        next true if image.persisted? && image.errors.empty?

        @account.errors.add(:base, t("app.appearance.image_invalid", size: BrandImage::MAX_BYTES / 1.megabyte))
        false
      end
    end

    def appearance_params
      copy_fields = Account::LOCALES.index_with { Account::COPY_KEYS }
      permitted = params.require(:account).permit(
        :primary_color, :accent_color, :background_color, :currency, :time_zone, :preset_amounts_text,
        :allow_custom_amount, :collect_donor_details, :show_recent_donations, :receipt_footer,
        locales: [], terminal_copy: copy_fields
      )
      # Unchecking every box submits only the hidden blank value
      permitted[:locales] = permitted[:locales].compact_blank if permitted.key?(:locales)
      permitted[:terminal_copy] = permitted[:terminal_copy].to_h if permitted.key?(:terminal_copy)
      permitted
    end
  end
end
