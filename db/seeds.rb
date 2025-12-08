# db/seeds.rb

puts "🧹 Clearing old data..."
Payment.destroy_all
Billing.destroy_all
Subscriber.destroy_all

# === Subscriber: PRINCESS CONNIE TAMAYAO ===
phone     = "09957795446"
last_name = "TAMAYAO"

tamayao = Subscriber.create!(
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

puts "💳 Seeding billings & payments for TAMAYAO (2024–2025)..."

payment_methods = [ "GCash", "Cash" ]

# Rules for TAMAYAO:
# - 2024: all months Closed (paid)
# - 2025 Jan–Sep: Closed (paid)
# - 2025 Oct: Overdue (unpaid)
# - 2025 Nov: Open (unpaid)
# - 2025 Dec: no billing created
(2024..2025).each do |year|
  # 2024: Jan–Dec; 2025: Jan–Nov
  end_month = (year == 2024 ? 12 : 11)

  (1..end_month).each do |month|
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    due_date   = end_date + 14.days

    billing_status =
      if year == 2024
        "Closed"
      else # year == 2025
        case month
        when 1..9
          "Closed"   # Jan–Sep
        when 10
          "Overdue"  # Oct
        when 11
          "Open"     # Nov
        end
      end

    billing = Billing.create!(
      subscriber: tamayao,
      start_date: start_date,
      end_date: end_date,
      amount: tamayao.brate,
      due_date: due_date,
      status: billing_status
    )

    # Payments only for Closed (paid) billings
    if billing_status == "Closed"
      pay_method = payment_methods.sample

      Payment.create!(
        billing: billing,
        payment_date: due_date + 1.day,
        amount: tamayao.brate,
        payment_method: pay_method,
        status: "Completed",
        attachment: "NA",
        reference_number: (pay_method == "Cash" ? nil : "NA")
      )
    end
  end
end

puts "🌱 Loading subscriber seeds..."
load Rails.root.join("db/seeds_subscribers.rb")
load Rails.root.join("db/seeds_admins.rb")
puts "✅ All seeds loaded!"
