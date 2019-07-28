# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:names) do
      Integer :id, identity: true, primary_key: true

      String :name, null: false
      Boolean :surname, null: false, default: false
      String :gender, null: true
      column :kinds, 'name_kind[]'

      column :added, 'timestamp with time zone', null: false, default: Sequel.lit('CURRENT_TIMESTAMP')
      String :source

      index :name, type: 'btree'
      index :surname, type: 'btree'
      index :gender, type: 'btree'
      index :kinds, type: 'btree'
      index :source, type: 'btree'
    end

    comment_on :column, %i[names name], 'All in lowercase, spaces allowed but not preferred'
    comment_on :column, %i[names surname], 'Whether the name is a surname'
    comment_on :column, %i[names kinds], 'Rough ethnic provenance and other tags'
    comment_on :column, %i[names source], 'Freeform *short* source description/identifier'
  end
end
