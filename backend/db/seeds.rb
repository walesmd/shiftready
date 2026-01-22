# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

if !Rails.env.production?
  admin_email = "admin@michaelwales.com"
  admin_password = "password"

  admin_user = User.find_or_initialize_by(email: admin_email)
  if admin_user.new_record?
    admin_user.role = :admin
    admin_user.password = admin_password
    admin_user.password_confirmation = admin_password
    admin_user.save!
  else
    admin_user.update!(role: :admin)
  end
end
