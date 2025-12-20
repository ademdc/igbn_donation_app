class CreateReaders < ActiveRecord::Migration[7.0]
  def change
    create_table :readers do |t|
      t.string :subdomain, null: false
      t.string :sumup_reader_id, null: false
      t.string :name

      t.timestamps
    end
    add_index :readers, :subdomain, unique: true
  end
end
