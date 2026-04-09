#!/bin/bash

export S3_BUCKET=bybeprod
export S3_REGION=us-east-1
export AWS_ACCESS_KEY_ID=sample-access-key-id
export AWS_SECRET_ACCESS_KEY=sample-secret-access-key
export GOOGLE_API_KEY=google_api_key
export TASK_SYSTEM_HOST=localhost
       TASK_SYSTEM_PORT=3001
       GOOGLE_OAUTH_CLIENT_ID=google_oauth_client_id
       GOOGLE_OAUTH_CLIENT_SECRET=google_oauth_client_secret

       # To be removed ater we remove HtmlFiles completely
       BASE_DIR=/var/www/my_actual_static_files_dir




docker build -t benyehuda.org/bybe ./