class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products, id: :uuid, default: 'gen_random_uuid()' do |t|
      t.string :name, null: false
      t.decimal :price, precision: 10, scale: 2, null: false

      t.decimal :vat_rate, precision: 5, scale: 2, null: false
      t.string :unit_of_measure, null: false, default: 'szt.'

      t.decimal :weight_kg, precision: 10, scale: 2, null: false

      t.decimal :height_cm, precision: 10, scale: 2, null: false
      t.decimal :width_cm, precision: 10, scale: 2, null: false
      t.decimal :length_cm, precision: 10, scale: 2, null: false

      t.string :product_type

      t.text :description

      t.timestamps
    end
  end
end
