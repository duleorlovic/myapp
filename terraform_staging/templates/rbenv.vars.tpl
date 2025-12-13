# input variables:
#   rails_env
#   database_url
#   redis_url
#   secret_key_base
#   aws_region
#   aws_bucket
#   aws_access_key_id
#   aws_secret_access_key

# config/puma.rb uses RAILS_ENV, RAILS_MAX_THREADS and WEB_CONCURENCY
RAILS_ENV=${rails_env}
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
DATABASE_URL=${database_url}
REDIS_URL=${redis_url}

# other env variables
AWS_REGION=${aws_region}
AWS_BUCKET=${aws_bucket}
AWS_ACCESS_KEY_ID=${aws_access_key_id}
AWS_SECRET_ACCESS_KEY=${aws_secret_access_key}
# if config/secrets.yml is used
# SECRET_KEY_BASE="${secret_key_base}"
# if config/credentials is used
RAILS_MASTER_KEY=${rails_master_key}
