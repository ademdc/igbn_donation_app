class CreateDonations < ActiveRecord::Migration[7.0]
  def change
    create_table :donations do |t|
      t.decimal :amount
      t.string :currency
      t.string :donor_name
      t.string :donor_email
      t.string :status
      t.string :checkout_reference
      t.string :checkout_id
      t.string :transaction_code

      t.timestamps
    end
  end
end
