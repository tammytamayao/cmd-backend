# db/seeds.rb
# Only destroy data in development environment (for local dev)
if Rails.env.development?
  puts "🧹 Clearing old data (development environment)..."
  Payment.destroy_all
  Billing.destroy_all
  Subscriber.destroy_all
else
  puts "⚠️  Skipping data destruction in #{Rails.env} environment"
end

puts "🌱 Loading admin seeds..."
load Rails.root.join("db/seeds_admins.rb")
puts "✅ All seeds loaded!"
