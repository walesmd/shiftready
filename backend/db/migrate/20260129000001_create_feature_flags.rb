# frozen_string_literal: true

class CreateFeatureFlags < ActiveRecord::Migration[8.1]
  def change
    create_table :feature_flags do |t|
      t.string :key, null: false
      t.jsonb :value, null: false, default: false
      t.text :description
      t.boolean :archived, null: false, default: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :feature_flags, :key, unique: true
    add_index :feature_flags, :archived
  end
end
