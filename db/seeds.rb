# db/seeds.rb
puts "🧹 Clearing old data..."
Payment.destroy_all
Billing.destroy_all
Subscriber.destroy_all

puts "🌱 Loading subscriber seeds..."
load Rails.root.join("db/seeds_admins.rb")
puts "✅ All seeds loaded!"
