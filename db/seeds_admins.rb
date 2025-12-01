puts "👑 Seeding admin users..."

AdminUser.find_or_create_by!(email: "billing@cmdcable.com") do |admin|
  admin.role = "billing"
  admin.password = "password123"
  admin.password_confirmation = "password123"
end

puts "✅ Admin user: billing@cmdcable.com / password123"
