class AddTrackingCodeToShifts < ActiveRecord::Migration[8.1]
  def change
    add_column :shifts, :tracking_code, :string

    reversible do |dir|
      dir.up do
        # Generate tracking codes for any existing shifts
        Shift.reset_column_information
        Shift.where(tracking_code: nil).find_each do |shift|
          shift.update_column(:tracking_code, generate_unique_tracking_code)
        end
      end
    end

    change_column_null :shifts, :tracking_code, false
    add_index :shifts, :tracking_code, unique: true
  end

  private

  def generate_unique_tracking_code
    loop do
      code = "SR-#{SecureRandom.hex(3).upcase}"
      break code unless Shift.exists?(tracking_code: code)
    end
  end
end
