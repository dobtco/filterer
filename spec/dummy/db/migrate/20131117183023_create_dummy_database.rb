class CreateDummyDatabase < ActiveRecord::Migration
  def change
    create_table :people do |t|
      t.string :name
      t.string :email
      t.integer :company_id

      t.timestamps
    end

    create_table :companies do |t|
      t.string :name
      t.timestamps
    end
  end
end
