class EnforceUniqueBillingPeriod < ActiveRecord::Migration[7.2]
  def up
    # ---- SAFETY CHECKS / BACKFILL (adjust if needed) ----
    # These prevent migration failure if old rows have NULLs

    execute <<~SQL
      UPDATE billings
      SET start_date = DATE(created_at)
      WHERE start_date IS NULL
    SQL

    execute <<~SQL
      UPDATE billings
      SET end_date = DATE(created_at)
      WHERE end_date IS NULL
    SQL

    execute <<~SQL
      UPDATE billings
      SET due_date = DATE(created_at)
      WHERE due_date IS NULL
    SQL

    execute <<~SQL
      UPDATE billings
      SET status = 'unpaid'
      WHERE status IS NULL
    SQL

    execute <<~SQL
      UPDATE billings
      SET amount = 0
      WHERE amount IS NULL
    SQL

    # ---- ENFORCE NOT NULL ----
    change_column_null :billings, :start_date, false
    change_column_null :billings, :end_date, false
    change_column_null :billings, :due_date, false
    change_column_null :billings, :status, false
    change_column_null :billings, :amount, false

    # ---- UNIQUE CONSTRAINT ----
    add_index :billings,
              [ :subscriber_id, :start_date, :end_date ],
              unique: true,
              name: "index_billings_on_subscriber_and_period"
  end

  def down
    remove_index :billings, name: "index_billings_on_subscriber_and_period"

    change_column_null :billings, :amount, true
    change_column_null :billings, :status, true
    change_column_null :billings, :due_date, true
    change_column_null :billings, :end_date, true
    change_column_null :billings, :start_date, true
  end
end
