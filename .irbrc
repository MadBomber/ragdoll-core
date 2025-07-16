require_relative 'lib/ragdoll'

# Configure Ragdoll for PostgreSQL development
Ragdoll.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['RAGDOLL_DATABASE_PASSWORD'] || 'ragdoll',
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end

puts "Ragdoll configured for PostgreSQL development"
puts "Database: ragdoll_development"
puts "Username: ragdoll"
puts "Try: Ragdoll.add_document(path: 'README.md')"
