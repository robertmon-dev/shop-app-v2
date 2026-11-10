class ProductPhoto < ActiveRecord::Migration[8.0]
  def change
    create_table :product_photos, id: :uuid do |t|
      t.text :url, null: true
      t.text :thumbnail_url, null: true
      t.references :product, null: true, foreign_key: true, type: :uuid
      t.timestamps
    end
  end
end
