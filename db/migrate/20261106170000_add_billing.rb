# Yearly plans paid by bank transfer. Accounts created before billing get their 30 days
# from signup. An account with neither date never expires, which is how an account
# stays free of charge.
class AddBilling < ActiveRecord::Migration[7.1]
  def up
    change_table :accounts, bulk: true do |t|
      t.datetime :trial_ends_at
      t.datetime :paid_until
      t.integer :extra_terminals, null: false, default: 0
      t.string :billing_name
      t.string :billing_address
      t.string :billing_zip
      t.string :billing_city
      t.string :billing_email
      t.string :country
      t.string :last_reminder
    end

    create_table :payments do |t|
      t.references :account, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.integer :amount_cents, null: false
      t.integer :extra_terminals, null: false, default: 0
      t.datetime :period_start
      t.datetime :period_end
      t.datetime :approved_at
      t.string :confirmed_by
      t.timestamps
      t.index [:account_id, :status]
    end

    execute "UPDATE accounts SET trial_ends_at = created_at + interval '30 days'"
  end

  def down
    drop_table :payments
    remove_columns :accounts, :trial_ends_at, :paid_until, :extra_terminals, :billing_name, :billing_address,
                   :billing_zip, :billing_city, :billing_email, :country, :last_reminder
  end
end
