# db/seeds_subscribers.rb
require "date"
require "securerandom"

puts "🧹 Clearing subscriber-related data..."
Payment.destroy_all
Billing.destroy_all
Subscriber.destroy_all

SUBSCRIBER_DATA = [
  {
    "collector": "JULIET SICAM",
    "zone": "AURORA WEST DIFFUN",
    "date_installed": "2025-06-07",
    "last_name": "ABAD",
    "first_name": "ROSALINDA",
    "phone_number": "09533052672",
    "alternative_phone": nil,
    "serial_number": "121125-250",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S241129041",
    "cas": "94800429",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "30F947AA638C"
  },
  {
    "collector": "MAILA BRISTOL",
    "zone": "CENTRO-CABATUAN",
    "date_installed": "2023-08-25",
    "last_name": "ABAD",
    "first_name": "ROSALINDA",
    "phone_number": "09550215292",
    "alternative_phone": nil,
    "serial_number": "021240-140",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S190128663",
    "cas": "65678567",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "98:45:62:FF:E2:00"
  },
  {
    "collector": "LITO GOMEZ",
    "zone": "VILLA LUNA",
    "date_installed": "2024-11-09",
    "last_name": "AGUSTIN",
    "first_name": "MARY JANE",
    "phone_number": "09057659828",
    "alternative_phone": "09161834105",
    "serial_number": "118572-240",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S240265623",
    "cas": "93751428",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1076000"
  },
  {
    "collector": "LITO GOMEZ",
    "zone": "VILLA LUNA",
    "date_installed": "2024-04-13",
    "last_name": "CARAG",
    "first_name": "MERIL",
    "phone_number": "09553610894",
    "alternative_phone": nil,
    "serial_number": "116678-240",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S240102692",
    "cas": "93751611",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B106EF20"
  },
  {
    "collector": "MA. TERESA MARQUEZ",
    "zone": "BUNEG CABARROGUIS",
    "date_installed": "2023-03-29",
    "last_name": "CLEMENTE",
    "first_name": "SHARMAINE",
    "phone_number": "09684738293",
    "alternative_phone": nil,
    "serial_number": "113619-230",
    "tvconnect": true,
    "package": "M",
    "plan": "B",
    "brate": 1199,
    "stb": "S230704703",
    "cas": "89956388",
    "package_speed": 80,
    "requires_password_change": true,
    "mac_address": "984562FFC380"
  },
  {
    "collector": "EMUELLE  DANAO",
    "zone": "VILLA LUNA",
    "date_installed": "2024-09-26",
    "last_name": "PINTOCAN",
    "first_name": "VISILAINE",
    "phone_number": "09351344527",
    "alternative_phone": nil,
    "serial_number": "118445-240",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S240701270",
    "cas": "94053373",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "D44D9F6F0423"
  },
  {
    "collector": "BONG DE GUZMAN",
    "zone": "VILLA LUNA",
    "date_installed": "2023-03-07",
    "last_name": "RIVERA",
    "first_name": "DIANA",
    "phone_number": "09274199201",
    "alternative_phone": nil,
    "serial_number": "113517-230",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S221041028",
    "cas": "79170021",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1076200"
  },
  {
    "collector": "JOMARIE MATALANG",
    "zone": "KALABAZA",
    "date_installed": "2025-08-08",
    "last_name": "APAN",
    "first_name": "MARICEL",
    "phone_number": "09543497204",
    "alternative_phone": nil,
    "serial_number": "121770-250",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S200955030",
    "cas": "76393876",
    "package_speed": 80,
    "requires_password_change": true,
    "mac_address": "ACFBC22BF260"
  },
  {
    "collector": "EMUELLE  DANAO",
    "zone": "VILLA LUNA",
    "date_installed": "2024-04-05",
    "last_name": "GARCIA",
    "first_name": "DONNA ROSE",
    "phone_number": "09275639608",
    "alternative_phone": nil,
    "serial_number": "116553-240",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S230847615",
    "cas": "93751529",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1076140"
  },
  {
    "collector": "LOIDA DARAPAN",
    "zone": "AURORA WEST DIFFUN",
    "date_installed": "2025-09-20",
    "last_name": "VINASOY",
    "first_name": "ELIZABETH",
    "phone_number": "09267799422",
    "alternative_phone": nil,
    "serial_number": "121988-250",
    "tvconnect": true,
    "package": "R",
    "plan": "B",
    "brate": 1399,
    "stb": "S231039028",
    "cas": "93751421",
    "package_speed": 150,
    "requires_password_change": true,
    "mac_address": "30F947AA5934"
  },
  {
    "collector": "RAUL FLORENDO",
    "zone": "DIADI SAN PABLO",
    "date_installed": "2025-07-20",
    "last_name": "VIERNES",
    "first_name": "EULISA",
    "phone_number": "09209608700",
    "alternative_phone": nil,
    "serial_number": "121609-250",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S221173100",
    "cas": "79669123",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "30F947AA82DC"
  },
  {
    "collector": "EMUELLE  DANAO",
    "zone": "MARABULIG II",
    "date_installed": "2024-09-19",
    "last_name": "MALUYO",
    "first_name": "MARK LOUIE",
    "phone_number": "09457942507",
    "alternative_phone": nil,
    "serial_number": "118060-240",
    "tvconnect": false,
    "package": "F",
    "plan": "P",
    "brate": 1299,
    "stb": nil,
    "cas": nil,
    "package_speed": 100,
    "requires_password_change": true,
    "mac_address": "D44D9F6F5F2B"
  },
  {
    "collector": "ABIGAIL DE LUNA",
    "zone": "GOMEZ DIFFUN",
    "date_installed": "2025-09-25",
    "last_name": "VIRTUAL ASSET COOPERATIVE",
    "first_name": "",
    "phone_number": "09653163440",
    "alternative_phone": nil,
    "serial_number": "108550-210",
    "tvconnect": true,
    "package": "F",
    "plan": "H",
    "brate": 2299,
    "stb": "S210526476",
    "cas": "784453386",
    "package_speed": 320,
    "requires_password_change": true,
    "mac_address": "04AB084D2584"
  },
  {
    "collector": "THOR BARRIENTOS",
    "zone": "I-PEÑOLES CABARROGUIS",
    "date_installed": "2025-04-27",
    "last_name": "TURLA",
    "first_name": "DENNIS",
    "phone_number": "09564955652",
    "alternative_phone": nil,
    "serial_number": "120659-250",
    "tvconnect": true,
    "package": "M",
    "plan": "B",
    "brate": 1199,
    "stb": "S221173089",
    "cas": "79669995",
    "package_speed": 80,
    "requires_password_change": true,
    "mac_address": "30F947AA8FD4"
  },
  {
    "collector": "RAUL FLORENDO",
    "zone": "BAROBBOBO DIADI",
    "date_installed": "2023-04-18",
    "last_name": "SOMERA",
    "first_name": "ALFREDO",
    "phone_number": "09169450875",
    "alternative_phone": nil,
    "serial_number": "113714-230",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S200955014",
    "cas": "76393931",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "BC9D4E78EB6D"
  },
  {
    "collector": "JOSELITO ECHAVARRIA",
    "zone": "CABULAY II",
    "date_installed": "2023-06-30",
    "last_name": "TURINGAN",
    "first_name": "SAMUEL",
    "phone_number": "09457660066",
    "alternative_phone": nil,
    "serial_number": "114004-230",
    "tvconnect": false,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": nil,
    "cas": nil,
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1137AF6"
  },
  {
    "collector": "JOSELITO ECHAVARRIA",
    "zone": "DIBUL",
    "date_installed": "2022-10-28",
    "last_name": "AYALA",
    "first_name": "ONOFRE",
    "phone_number": "09159114150",
    "alternative_phone": nil,
    "serial_number": "112268-220",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S210566036",
    "cas": "79168829",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1138C46"
  },
  {
    "collector": "DONDON DE VERA",
    "zone": "VILLA LUNA",
    "date_installed": "2023-09-01",
    "last_name": "BARUELA",
    "first_name": "JENNY",
    "phone_number": "09571508893",
    "alternative_phone": nil,
    "serial_number": "114566-230",
    "tvconnect": true,
    "package": "M",
    "plan": "A",
    "brate": 999,
    "stb": "S230705282",
    "cas": "89956426",
    "package_speed": 60,
    "requires_password_change": true,
    "mac_address": "0055B1076210"
  }
]

puts "📌 Seeding #{SUBSCRIBER_DATA.length} subscribers..."
payment_methods = [ "GCash", "Cash" ]

SPECIAL_UNPAID = {
  "118060-240" => [ "Sep", "Oct" ],   # PINTOCAN
  "121988-250" => [ "Sep", "Oct" ]    # VINASOY
}

def month_name(date)
  date.strftime("%b")
end

SUBSCRIBER_DATA.each do |rec|
  subscriber = Subscriber.create!(
    collector: rec[:collector],
    zone: rec[:zone],
    date_installed: Date.parse(rec[:date_installed]),
    last_name: rec[:last_name],
    first_name: rec[:first_name],
    phone_number: rec[:phone_number],
    alternative_phone: rec[:alternative_phone],
    serial_number: rec[:serial_number],
    tvconnect: rec[:tvconnect],
    package: rec[:package],
    plan: rec[:plan],
    brate: rec[:brate],
    mc_address: rec[:mac_address],
    stb: rec[:stb],
    cas: rec[:cas],
    package_speed: rec[:package_speed],
    requires_password_change: rec[:requires_password_change]
  )

  puts "👤 Seeded Subscriber: #{subscriber.last_name} #{subscriber.first_name} (#{subscriber.serial_number})"

  # === BILLINGS ===
  (2024..2025).each do |year|
    end_month = (year == 2025 ? 10 : 12)

    (1..end_month).each do |month|
      start_date = Date.new(year, month, 1)
      end_date   = start_date.end_of_month
      due_date   = end_date + 14

      month_short = month_name(start_date)

      # Default billing status logic
      billing_status =
        if year == 2024
          "Closed"
        else
          if month <= 7
            "Closed"
          elsif [ 8, 9 ].include?(month)
            "Overdue"
          else
            "Open"
          end
        end

      # === Apply special rule for PINTOCAN + VINASOY ===
      if SPECIAL_UNPAID.key?(rec[:serial_number]) && SPECIAL_UNPAID[rec[:serial_number]].include?(month_short)
        billing_status = "Overdue"
      elsif month_short == "Oct" && year == 2025
        billing_status = "Open" unless SPECIAL_UNPAID[rec[:serial_number]]&.include?("Oct")
      end

      billing = Billing.create!(
        subscriber: subscriber,
        start_date: start_date,
        end_date: end_date,
        amount: subscriber.brate,
        due_date: due_date,
        status: billing_status
      )

      # === Payments only for Closed (paid) billings ===
      if billing_status == "Closed"
        pay_method = payment_methods.sample

        Payment.create!(
          billing: billing,
          payment_date: due_date + 1,
          amount: subscriber.brate,
          payment_method: pay_method,
          status: "Completed",
          attachment: "https://example.com/payment#{billing.id}.jpg",
          reference_number: (pay_method == "Cash" ? nil : "REF#{SecureRandom.hex(4)}")
        )
      end
    end
  end
end

# === Mark last Payment as Processing ===
last_payment = Payment.order(:payment_date, :id).last
if last_payment
  last_payment.update!(status: "Processing")
  puts "🔄 Marked last payment (ID #{last_payment.id}) as Processing"
end

puts "✅ Done seeding all subscribers!"
