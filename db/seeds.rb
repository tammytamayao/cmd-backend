# db/seeds.rb

puts "🧹 Clearing old data..."
Payment.destroy_all
Billing.destroy_all
Subscriber.destroy_all

# === Subscriber: PRINCESS CONNIE TAMAYAO ===
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

puts "✅ Seeded 1 subscriber (TAMAYAO)"

# === Billings & Payments ===
puts "💳 Seeding billings & payments for 2024–2025 with proper status semantics..."

# Use only values that are definitely valid per Payment model validation
# (we avoid "Bank Transfer" entirely)
payment_methods = [ "GCash", "Cash" ]

# Rules:
# - All subscribers (including TAMAYAO):
#   - 2024: all months Closed (paid)
#   - 2025 Jan–Nov: Closed (paid)
#   - 2025 Dec: Open (unpaid)
# - Special overdue months:
#   - TAMAYAO: 2025 Sep & Oct => Overdue (unpaid)
(2024..2025).each do |year|
  start_month = 1
  end_month   = 12  # go up to December 2025

  (start_month..end_month).each do |month|
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    due_date   = end_date + 14.days

    # Default status: everything paid (Closed) except December 2025
    billing_status =
      if year == 2024 || (year == 2025 && month <= 11)
        "Closed"
      else
        # year == 2025 && month == 12
        "Open"   # unpaid current month
      end

    # Special rule for TAMAYAO: 2025 Sep & Oct are Overdue (unpaid)
    if year == 2025 && [ 9, 10 ].include?(month)
      billing_status = "Overdue"
    end

    billing = Billing.create!(
      subscriber: subscriber,
      start_date: start_date,
      end_date: end_date,
      amount: subscriber.brate,
      due_date: due_date,
      status: billing_status
    )

    # Create a payment ONLY for Closed (paid) bills
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

puts "✅ Done seeding billings & payments for TAMAYAO!"

puts "🌱 Loading subscriber seeds..."
load Rails.root.join("db/seeds_subscribers.rb")
load Rails.root.join("db/seeds_admins.rb")
puts "✅ All seeds loaded!"
