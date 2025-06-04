provider "aws" {
  region = "us-east-1"
}

# Create a DynamoDB table
resource "aws_dynamodb_table" "taco_truck_panels" {
  name           = "taco-truck-panels-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id" # Partition key
  range_key      = "owner" # Optional: Sort key

  attribute {
    name = "id"
    type = "S" # String
  }

  attribute {
    name = "owner"
    type = "S" # String
  }

  # Define a Global Secondary Index (GSI) for the "owner" attribute
  global_secondary_index {
    name            = "owner-index" # Name of the GSI
    hash_key        = "owner"       # Partition key for the GSI
    projection_type = "ALL"         # Include all attributes in the index
  }

  # Enable server-side encryption (optional)
  server_side_encryption {
    enabled = true
  }

  # Tags for the DynamoDB table
  tags = {
    Environment = "Production"
    Project     = "TacoTruck"
  }
}

# Create an IAM role for the Lambda function
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the IAM role
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy_attachment" "dynamodb_policy" {
  name       = "dynamodb-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Create a zip file for the Lambda functions
resource "null_resource" "lambda_zip" {
  # Trigger this resource when any Lambda file changes
  triggers = {
    lambda_files = "${timestamp()}"
  }

  # Create the zip file
  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module}/lambda && \
      zip -r ../tt-lambdas.zip . -x "node_modules/*" && \
      echo "Lambda functions zipped successfully"
    EOT
  }
}

# Create the Lambda function
resource "aws_lambda_function" "tt-store" {
  depends_on = [ null_resource.lambda_zip ]
  function_name = "tt-store-lambda"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "tt-store.handler"

  # Path to your Lambda function code
  filename = "tt-lambdas.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.taco_truck_panels.name
    }
  }
}

# Create the Lambda function
resource "aws_lambda_function" "tt-get-all" {
  depends_on = [ null_resource.lambda_zip ]
  function_name = "tt-get-all-lambda"
  runtime       = "nodejs18.x"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "tt-get-all.handler"

  # Path to your Lambda function code
  filename = "tt-lambdas.zip"

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.taco_truck_panels.name
    }
  }
}

# Create an API Gateway REST API
resource "aws_api_gateway_rest_api" "taco_truck_api" {
  name = "taco-truck-api"
}

# Create a resource in the API Gateway
resource "aws_api_gateway_resource" "taco_truck_panels" {
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
  parent_id   = aws_api_gateway_rest_api.taco_truck_api.root_resource_id
  path_part   = "panels"
}

# Create a POST method for the resource
resource "aws_api_gateway_method" "create_panel" {
  rest_api_id   = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id   = aws_api_gateway_resource.taco_truck_panels.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Create a GET method for the resource
resource "aws_api_gateway_method" "get_panels" {
  rest_api_id   = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id   = aws_api_gateway_resource.taco_truck_panels.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito_authorizer.id
}

# Add an OPTIONS method for CORS
resource "aws_api_gateway_method" "options" {
  rest_api_id   = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id   = aws_api_gateway_resource.taco_truck_panels.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Integrate the API Gateway with the Lambda function
resource "aws_api_gateway_integration" "create_panel_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id             = aws_api_gateway_resource.taco_truck_panels.id
  http_method             = aws_api_gateway_method.create_panel.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tt-store.invoke_arn
}

# Integrate the API Gateway with the Lambda function
resource "aws_api_gateway_integration" "get_panels_lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id             = aws_api_gateway_resource.taco_truck_panels.id
  http_method             = aws_api_gateway_method.get_panels.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tt-get-all.invoke_arn
}

# Integrate the OPTIONS method with a mock integration for CORS
resource "aws_api_gateway_integration" "options_cors" {
  rest_api_id             = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id             = aws_api_gateway_resource.taco_truck_panels.id
  http_method             = aws_api_gateway_method.options.http_method
  type                    = "MOCK"
  request_templates       = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Add a response for the POST method to allow CORS
resource "aws_api_gateway_method_response" "create_panel_response" {
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id = aws_api_gateway_resource.taco_truck_panels.id
  http_method = aws_api_gateway_method.create_panel.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Add a response for the GET method to allow CORS
resource "aws_api_gateway_method_response" "get_panels_response" {
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id = aws_api_gateway_resource.taco_truck_panels.id
  http_method = aws_api_gateway_method.get_panels.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Add a response for the OPTIONS method to allow CORS
resource "aws_api_gateway_method_response" "options_response" {
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id = aws_api_gateway_resource.taco_truck_panels.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Add an integration response for the OPTIONS method
resource "aws_api_gateway_integration_response" "options_integration_response" {
  depends_on = [aws_api_gateway_integration.options_cors]
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
  resource_id = aws_api_gateway_resource.taco_truck_panels.id
  http_method = aws_api_gateway_method.options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'",
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,Authorization'"
  }
}

# Deploy the API Gateway
resource "aws_api_gateway_deployment" "taco_truck_api_deployment" {
  depends_on = [
    aws_api_gateway_integration.create_panel_lambda_integration,
    aws_api_gateway_integration.get_panels_lambda_integration,
    aws_api_gateway_method_response.create_panel_response,
    aws_api_gateway_method_response.get_panels_response,
    aws_api_gateway_integration.options_cors
  ]
  rest_api_id = aws_api_gateway_rest_api.taco_truck_api.id
}

# Create a stage for the API Gateway
resource "aws_api_gateway_stage" "taco_truck_stage_dev" {
  deployment_id = aws_api_gateway_deployment.taco_truck_api_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.taco_truck_api.id
  stage_name    = "dev"
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "apigw-create-panel" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tt-store.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.taco_truck_api.execution_arn}/*/*"
}

# Grant API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "apigw-get-panels" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tt-get-all.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.taco_truck_api.execution_arn}/*/*"
}

# Add Cognito User Pool
resource "aws_cognito_user_pool" "taco_truck_user_pool" {
  name = "taco-truck-user-pool"

  # Optional: Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Optional: Attributes for users
  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = false
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = false
    mutable             = true
  }

  # Enable email as a sign-in option
  alias_attributes = ["email"]

  # Enable MFA (optional)
  mfa_configuration = "OFF"
}

# Regular User Group
resource "aws_cognito_user_group" "regular_user_group" {
  user_pool_id = aws_cognito_user_pool.taco_truck_user_pool.id
  name         = "RegularUser"
  description  = "Regular users with limited access"
}

# Admin Group
resource "aws_cognito_user_group" "admin_group" {
  user_pool_id = aws_cognito_user_pool.taco_truck_user_pool.id
  name         = "Admin"
  description  = "Admins with full access"
}

# Add Cognito User Pool Client
resource "aws_cognito_user_pool_client" "taco_truck_app_client" {
  name         = "taco-truck-app-client"
  user_pool_id = aws_cognito_user_pool.taco_truck_user_pool.id

  # Allow authentication flows
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  # OAuth 2.0 settings
  allowed_oauth_flows = ["code", "implicit"] # Authorization Code and Implicit flows
  allowed_oauth_scopes = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true

  # Specify allowed redirect URLs
  callback_urls = [
    # "https://your-app.com/callback",  # Replace with your app's callback URL
    "http://localhost:3000/callback" # For local development
  ]

  # Specify allowed logout URLs
  logout_urls = [
    # "https://your-app.com/logout",  # Replace with your app's logout URL
    "http://localhost:3000/logout" # For local development
  ]

  # Prevent client secret (useful for public apps like SPAs)
  generate_secret = false
}

# Add Cognito Identity Pool (optional, for federated identities)
resource "aws_cognito_identity_pool" "taco_truck_identity_pool" {
  identity_pool_name               = "taco-truck-identity-pool"
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    client_id   = aws_cognito_user_pool_client.taco_truck_app_client.id
    provider_name = aws_cognito_user_pool.taco_truck_user_pool.endpoint
  }
}

# Add API Gateway Cognito Authorizer
resource "aws_api_gateway_authorizer" "cognito_authorizer" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.taco_truck_api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [aws_cognito_user_pool.taco_truck_user_pool.arn]
  identity_source = "method.request.header.Authorization"
}

# IAM Role for Authenticated Users (Optional, for federated identities)
resource "aws_iam_role" "authenticated_role" {
  name = "taco-truck-authenticated-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: {
          Federated: "cognito-identity.amazonaws.com"
        },
        Action: "sts:AssumeRoleWithWebIdentity",
        Condition: {
          StringEquals: {
            "cognito-identity.amazonaws.com:aud": aws_cognito_identity_pool.taco_truck_identity_pool.id
          },
          "ForAnyValue:StringLike": {
            "cognito-identity.amazonaws.com:amr": "authenticated"
          }
        }
      }
    ]
  })
}

# Attach Policies to Authenticated Role
resource "aws_iam_role_policy_attachment" "authenticated_role_policy" {
  role       = aws_iam_role.authenticated_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" # Example: Full access to DynamoDB
}

# Define the Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "taco_truck_domain" {
  domain      = "taco-truck" # Replace with your desired unique domain prefix
  user_pool_id = aws_cognito_user_pool.taco_truck_user_pool.id
}

# Create a predefined Cognito user with a temporary password
resource "null_resource" "create_cognito_user" {
  depends_on = [aws_cognito_user_pool.taco_truck_user_pool]

  provisioner "local-exec" {
    command = <<EOT
      TEMP_PASSWORD=$(openssl rand -base64 12 | tr -d '=+/')$(openssl rand -base64 4 | tr -dc '!@#$%^&*()_+-=') && \
      echo "Generated temporary password: $TEMP_PASSWORD" && \
      echo $TEMP_PASSWORD > temp_password.txt && \
      aws cognito-idp admin-create-user \
        --user-pool-id ${aws_cognito_user_pool.taco_truck_user_pool.id} \
        --username god_hand \
        --temporary-password $TEMP_PASSWORD \
        --user-attributes Name="email",Value="user@example.com" Name="name",Value="Predefined User" \
        --message-action SUPPRESS
    EOT
  }
}

# Read the temporary password from the file
data "local_file" "temp_password" {
  depends_on = [null_resource.create_cognito_user]
  filename = "${path.module}/temp_password.txt"
}

# Output the temporary password
output "temporary_password" {
  value       = data.local_file.temp_password.content
  description = "The temporary password for the predefined Cognito user"
}

# Output the Cognito Domain URL
output "cognito_domain_url" {
  value = "https://${aws_cognito_user_pool_domain.taco_truck_domain.domain}.auth.us-east-1.amazoncognito.com"
  description = "The Cognito Hosted UI domain URL"
}

# Output the Cognito User Pool ID
output "cognito_user_pool_id" {
  value       = aws_cognito_user_pool.taco_truck_user_pool.id
  description = "The Cognito User Pool ID"
}

# Output the Cognito User Pool App Client ID
output "cognito_app_client_id" {
  value       = aws_cognito_user_pool_client.taco_truck_app_client.id
  description = "The Cognito User Pool App Client ID"
}

# Create an S3 bucket for the React app
resource "aws_s3_bucket" "react_app_bucket" {
  bucket = "taco-truck-react-app"
}

# Configure the bucket for website hosting
resource "aws_s3_bucket_website_configuration" "react_app_website" {
  bucket = aws_s3_bucket.react_app_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# Make the bucket public
resource "aws_s3_bucket_public_access_block" "react_app_public_access" {
  bucket = aws_s3_bucket.react_app_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Add bucket policy to allow public read access
resource "aws_s3_bucket_policy" "react_app_bucket_policy" {
  bucket = aws_s3_bucket.react_app_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.react_app_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.react_app_public_access]
}

# Create CloudFront distribution for the React app
resource "aws_cloudfront_distribution" "react_app_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.react_app_website.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.react_app_bucket.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.react_app_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Handle SPA routing by redirecting all paths to index.html
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Output the CloudFront URL
output "cloudfront_url" {
  value = aws_cloudfront_distribution.react_app_distribution.domain_name
}

# Update the React config file with the correct values
resource "local_file" "react_config" {
  depends_on = [
    aws_cognito_user_pool_domain.taco_truck_domain,
    aws_api_gateway_stage.taco_truck_stage_dev
  ]
  filename   = "${path.module}/react/taco-truck-react/src/config/react-config.json"
  content    = jsonencode({
    cognito_domain_url = "https://${aws_cognito_user_pool_domain.taco_truck_domain.domain}.auth.us-east-1.amazoncognito.com",
    user_pool_id       = aws_cognito_user_pool.taco_truck_user_pool.id,
    user_pool_client_id = aws_cognito_user_pool_client.taco_truck_app_client.id,
    api_gateway_id = aws_api_gateway_rest_api.taco_truck_api.id,
    cloudfront_url = aws_cloudfront_distribution.react_app_distribution.domain_name
  })
}

# Build and deploy the React app
resource "null_resource" "deploy_react_app" {
  depends_on = [
    local_file.react_config,
    aws_s3_bucket.react_app_bucket,
    aws_cloudfront_distribution.react_app_distribution
  ]

  # Build the React app
  provisioner "local-exec" {
    command = "cd ${path.module}/react/taco-truck-react && npm install && npm run build"
  }

  # Deploy to S3
  provisioner "local-exec" {
    command = "aws s3 sync ${path.module}/react/taco-truck-react/build/ s3://${aws_s3_bucket.react_app_bucket.bucket} --delete"
  }

  # Invalidate CloudFront cache
  provisioner "local-exec" {
    command = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.react_app_distribution.id} --paths '/*'"
  }
}