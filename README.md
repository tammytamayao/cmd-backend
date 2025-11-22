# Setup Guide

This guide walks you through setting up and running the CMD Backend Rails application locally using Docker.

## Prerequisites

- Docker and Docker Compose installed
- Git installed
- A terminal/shell with sudo access (for Docker commands)

## Quick Start

### 1. Clone and Navigate to Project

```bash
cd /path/to/cmd-backend
```

### 2. Configure Environment

The project uses a `.env` file for environment variables. It should already exist in the root directory with the following:

```env
SECRET_KEY_BASE=your_secret_key_base
DATABASE_URL=sqlite3:db/development.sqlite3
RAILS_ENV=development
AWS_ACCESS_KEY_ID=your_key
AWS_SECRET_ACCESS_KEY=your_secret
AWS_S3_BUCKET=cmd-billing-demo
AWS_S3_REGION=ap-southeast-2
```

**Note**: The `.env` file is gitignored, so you won't see it in git history. Check with your team or your password manager for the correct values if they're missing.

### 3. Build and Start the Docker Container

```bash
sudo docker compose up --build
```

This will:
- Build the Docker image from the Dockerfile
- Start the Rails server on port 3000
- Automatically run database migrations via the docker-entrypoint script
- Create all necessary tables

The app will be accessible at `http://localhost:3000`

### 4. Seed Test Data (Optional)

In a new terminal, populate the database with test data:

```bash
sudo docker compose exec app bundle exec rails db:migrate
sudo docker compose exec app bundle exec rails db:seed
```

This creates:
- 1 test subscriber account with phone `09957795446` and password `tamayao5446`
- Billing records for 2024-2025
- Sample payment data

### 5. Login and Test

Use the test credentials:
- **Phone Number**: `09957795446` (or `+639957795446`)
- **Password**: `tamayao5446`

## Rails Credentials

The application uses Rails encrypted credentials for sensitive configuration:

- **Production/Staging**: Uses `config/credentials.yml.enc` with `config/master.key`
- **Development**: Uses `config/credentials/development.yml.enc` with `config/credentials/development.key`

Development credentials are gitignored and won't affect production deployments.

If you need to edit development credentials:

```bash
sudo docker compose exec app bundle exec rails credentials:edit --environment development
```

## Common Commands

### Start the app
```bash
sudo docker compose up
```

### Stop the app
```bash
sudo docker compose down
```

### View logs
```bash
sudo docker compose logs -f app
```

### Access Rails console
```bash
sudo docker compose exec app bundle exec rails console
```

### Run migrations manually
```bash
sudo docker compose exec app bundle exec rails db:migrate
```

### Run tests
```bash
sudo docker compose exec app bundle exec rspec
```

### Run linting checks
```bash
sudo docker compose exec app bundle exec rubocop
sudo docker compose exec app bundle exec brakeman
```

## Troubleshooting

### Permission Denied Errors

If you get `permission denied` errors with Docker:

**Option 1**: Add your user to the docker group (recommended)
```bash
sudo usermod -aG docker $USER
newgrp docker
docker compose up  # No sudo needed after this
```

**Option 2**: Use sudo for all docker commands
```bash
sudo docker compose up
```

### Port 3000 Already in Use

If port 3000 is already in use, modify `docker-compose.yml`:

```yaml
ports:
  - "3001:3000"  # Change to any available port
```

### Database Errors

If you encounter database errors, reset the database:

```bash
sudo docker compose down --volumes
sudo docker compose up --build
sudo docker compose exec app bundle exec rails db:seed
```

### Credentials Issues

If you get `ActiveSupport::MessageEncryptor::InvalidMessage`:
1. Check that `config/master.key` exists and has the correct value
2. For development, ensure `config/credentials/development.key` was properly generated
3. Try regenerating development credentials:
   ```bash
   rm config/credentials/development.key config/credentials/development.yml.enc
   sudo docker compose exec app bundle exec rails credentials:edit --environment development
   ```

## Project Structure

```
cmd-backend/
├── app/
│   ├── controllers/    # API endpoints
│   ├── models/         # Database models
│   └── lib/            # Utility classes
├── config/
│   ├── credentials.yml.enc          # Production encrypted credentials
│   ├── credentials/development.yml.enc  # Development encrypted credentials
│   └── master.key                   # Decryption key (production, gitignored)
├── db/
│   ├── migrate/        # Database migrations
│   └── seeds.rb        # Test data seeding
├── Dockerfile          # Docker image definition
├── docker-compose.yml  # Docker Compose configuration
├── .env                # Environment variables (gitignored)
└── README.md           # Project overview
```

## API Documentation

The API is RESTful and follows this structure:

```
POST   /api/v1/sessions              # Login
GET    /api/v1/sessions/:id          # Get current user
DELETE /api/v1/sessions/:id          # Logout
GET    /api/v1/subscribers/:id       # Get subscriber info
GET    /api/v1/billings              # List billings
GET    /api/v1/payments              # List payments
POST   /api/v1/file_uploads          # Upload file to S3
GET    /api/v1/file_uploads/:id      # Download file from S3
```

See individual controller files in `app/controllers/api/v1/` for detailed endpoint specifications.

## Additional Notes

- The app uses SQLite for local development (configured in `.env`)
- AWS S3 credentials are required for file upload/download features
- JWT tokens are used for API authentication
- Password hashing uses bcrypt via `has_secure_password`
