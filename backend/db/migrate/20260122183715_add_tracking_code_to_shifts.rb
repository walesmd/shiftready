class AddTrackingCodeToShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :shifts, :tracking_code, :string
    add_index :shifts, :tracking_code, unique: true

    reversible do |dir|
      dir.up do
        # Generate tracking codes for any existing shifts
        Shift.reset_column_information
        Shift.where(tracking_code: nil).find_each do |shift|
          # Rely on the unique index and retry on constraint violations.
          loop do
            code = generate_unique_tracking_code
            begin
              shift.update_column(:tracking_code, code)
              break
            rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation
              next
            end
          end
        end
      end
    end

    change_column_null :shifts, :tracking_code, false
  end

  private

  def generate_unique_tracking_code
    "SR-#{SecureRandom.hex(4).upcase}"
  end
end
