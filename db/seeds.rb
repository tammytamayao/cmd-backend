# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# db/seeds.rb

puts "🧹 Clearing old data..."
Payment.destroy_all
Billing.destroy_all
Subscriber.destroy_all

# === Subscriber ===
phone = "09957795446"
last_name = "TAMAYAO"

subscriber = Subscriber.create!(
  collector: "MERVIN PEREZ",
  zone: "DANGAN RM",
  date_installed: "2021-01-15",
  last_name: last_name,
  first_name: "PRINCESS CONNIE",
  phone_number: phone, # model will normalize to +63... and auto-password: tamayao5446
  alternative_phone: "09363523329",
  serial_number: "105959-210",
  tvconnect: true,
  package: "F",
  plan: "H",
  brate: 2299,
  mc_address: "04AB084D5174",
  stb: "S200959895",
  cas: "76394047",
  package_speed: 320,
  requires_password_change: true
)

puts "✅ Seeded 1 subscriber:"

# === Billings & Payments ===
puts "💳 Seeding billings & payments for 2024–2025 with proper status semantics..."

# Use only values that are definitely valid per Payment model validation
# (%w[GCash Cash "Bank Transfer"] is broken, so we avoid "Bank Transfer" entirely)
payment_methods = ["GCash", "Cash"]

(2024..2025).each do |year|
  start_month = 1
  end_month   = (year == 2025 ? 10 : 12)

  (start_month..end_month).each do |month|
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    due_date   = end_date + 14.days

    # Billing status logic:
    # - 2024 all Closed (paid)
    # - 2025 Jan–Jul Closed (paid)
    # - 2025 Aug–Sep Overdue (unpaid)
    # - 2025 Oct Open (unpaid)
    billing_status =
      if year == 2024
        "Closed"
      else
        if month <= 7
          "Closed"
        elsif [8, 9].include?(month)
          "Overdue"
        else
          "Open"
        end
      end

    billing = Billing.create!(
      subscriber: subscriber,
      start_date: start_date,
      end_date: end_date,
      amount: subscriber.brate,
      due_date: due_date,
      status: billing_status
    )

    # Create a payment ONLY for Closed bills (i.e., paid)
    if billing_status == "Closed"
      pay_method = payment_methods.sample

      Payment.create!(
        billing: billing,
        payment_date: due_date + 1.day,           # paid the day after due date
        amount: subscriber.brate,
        payment_method: pay_method,               # "GCash" or "Cash"
        status: "Completed",                      # valid status per model
        attachment: "https://example.com/payment#{billing.id}.jpg",
        reference_number: (pay_method == "Cash" ? nil : "REF#{SecureRandom.hex(4)}")
      )
    end
  end
end

# Mark the latest payment as "Processing" to simulate an unverified one
last_payment = Payment.order(:payment_date, :id).last
if last_payment
  last_payment.update!(status: "Processing")
  puts "🔄 Marked last payment (ID #{last_payment.id}) as Processing"
end

puts "✅ Done seeding billings & payments!"

puts "🌱 Loading subscriber seeds..."
load Rails.root.join("db/seeds_subscribers.rb")
load Rails.root.join("db/seeds_admins.rb")
puts "✅ All seeds loaded!"