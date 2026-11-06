# Turns the single-tenant app into accounts with terminals. A database restored from the
# single-tenant app keeps its rows: they move to an "igbn" account, whose payment
# connection is entered in its dashboard afterwards.
class ConvertToMultiTenant < ActiveRecord::Migration[7.1]
  def up
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :status, null: false, default: "active"
      t.string :time_zone, null: false, default: "Berlin"
      t.string :currency, null: false, default: "EUR"
      t.string :locales, array: true, null: false, default: %w[de bs en]
      t.decimal :preset_amounts, array: true, null: false, default: [5, 10, 20]
      t.boolean :allow_custom_amount, null: false, default: true
      t.boolean :collect_donor_details, null: false, default: true
      t.boolean :show_recent_donations, null: false, default: false
      t.string :primary_color, null: false, default: "#23716b"
      t.string :accent_color, null: false, default: "#e8a23a"
      t.string :background_color, null: false, default: "#12302d"
      t.jsonb :terminal_copy, null: false, default: {}
      t.text :receipt_footer
      t.timestamps
      t.index :subdomain, unique: true
    end

    create_table :users do |t|
      t.references :account, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.string :password_digest, null: false
      t.boolean :admin, null: false, default: false
      t.string :locale
      t.datetime :last_login_at
      t.timestamps
      t.index [:account_id, :email], unique: true
      t.index :email, unique: true, where: "admin", name: "index_users_on_email_for_admins"
    end

    create_table :payment_connections do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.text :credentials
      t.string :webhook_token, null: false
      t.datetime :verified_at
      t.timestamps
      t.index [:account_id, :provider], unique: true
      t.index :webhook_token, unique: true
    end

    create_table :brand_images do |t|
      t.references :account, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.binary :data, null: false
      t.string :content_type, null: false
      t.string :digest, null: false
      t.timestamps
      t.index [:account_id, :kind], unique: true
    end

    rename_table :readers, :terminals
    rename_column :terminals, :subdomain, :slug
    rename_column :terminals, :sumup_reader_id, :provider_reader_id
    remove_index :terminals, :slug
    change_column_null :terminals, :provider_reader_id, true
    add_reference :terminals, :account, foreign_key: true
    add_reference :terminals, :payment_connection, foreign_key: true
    add_column :terminals, :hostname, :string
    add_column :terminals, :active, :boolean, null: false, default: true
    add_column :terminals, :certificate_status, :string

    add_reference :donations, :account, foreign_key: true
    add_reference :donations, :terminal, foreign_key: true
    add_column :donations, :test, :boolean, null: false, default: false
    add_column :donations, :locale, :string

    backfill_single_tenant

    change_column_null :terminals, :account_id, false
    change_column_null :terminals, :payment_connection_id, false
    change_column_null :terminals, :hostname, false
    change_column_null :donations, :account_id, false
    add_index :terminals, [:account_id, :slug], unique: true
    add_index :terminals, :hostname, unique: true
    add_index :donations, [:account_id, :status, :created_at]
    add_index :donations, :checkout_id
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def backfill_single_tenant
    return unless select_value("SELECT EXISTS (SELECT 1 FROM donations) OR EXISTS (SELECT 1 FROM terminals)")

    domain = ENV.fetch("APP_DOMAIN", "localhost")
    now = quote(Time.current)
    account = execute(<<~SQL.squish).first["id"]
      INSERT INTO accounts (name, subdomain, created_at, updated_at)
      VALUES ('IGBN', 'igbn', #{now}, #{now}) RETURNING id
    SQL
    connection_id = execute(<<~SQL.squish).first["id"]
      INSERT INTO payment_connections (account_id, provider, webhook_token, created_at, updated_at)
      VALUES (#{account}, 'sumup', #{quote(SecureRandom.hex(24))}, #{now}, #{now}) RETURNING id
    SQL
    execute <<~SQL.squish
      UPDATE terminals SET account_id = #{account}, payment_connection_id = #{connection_id},
        hostname = slug || '.igbn.' || #{quote(domain)}, certificate_status = 'pending'
    SQL
    execute "UPDATE donations SET account_id = #{account}"
  end
end
