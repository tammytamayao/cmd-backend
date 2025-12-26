
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

(2024..2025).each do |year|
  end_month = (year == 2024 ? 12 : 11)

  (1..end_month).each do |month|
    start_date = Date.new(year, month, 1)
    end_date   = start_date.end_of_month
    due_date   = end_date + 14.days

    paid_month =
      if year == 2024
        true
      else
        case month
        when 1..9
          true
        when 10
          false
        when 11
          false
        end
      end

    status_value = paid_month ? "paid" : "unpaid"

    billing = Billing.create!(
      subscriber: tamayao,
      start_date: start_date,
      end_date: end_date,
      amount: tamayao.brate,
      due_date: due_date,
      status: status_value,
      adjustment: nil,
      adjustment_notes: nil
    )

    if paid_month
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
