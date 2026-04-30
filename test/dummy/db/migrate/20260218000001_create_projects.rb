class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects, id: :uuid do |t|
      t.string :name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :projects, :slug, unique: true
  end
end
