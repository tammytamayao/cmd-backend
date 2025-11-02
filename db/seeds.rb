# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Clear existing records first (optional)
Subscriber.destroy_all

# Create sample subscriber
Subscriber.create!(
  collector: "MERVIN PEREZ",
  zone: "DANGAN RM",
  date_installed: "2021-01-15",
  last_name: "TAMAYAO",
  first_name: "PRINCESS CONNIE",
  phone_number: "09957795446",
  alternative_phone: "09363523329",
  serial_number: "105959-210",
  tvconnect: true,
  package: "F",
  plan: "H",
  brate: 2299,
  mc_address: "04AB084D5174",
  stb: "S200959895",
  cas: "76394047",
  package_speed: 320
)

puts "✅ Seeded 1 subscriber"
