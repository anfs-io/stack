#!/bin/bash

# Create main prompt file
cat > main_prompt.txt << 'EOF'
I'm building a Ruby SDK for the HealthSync API to process healthcare data. This is a multi-part prompt to guide the development process.

## API OVERVIEW
The HealthSync API allows secure access to patient health records, lab results, and treatment plans with proper authentication. It uses OAuth2 for authentication and returns JSON responses.

## MY REQUIREMENTS
Please review each section below which contains requirements extracted from separate prompt files. Based on all these requirements, I need you to:

1. Create the initial SDK structure
2. Implement the core API client with proper authentication
3. Implement at least one key resource model
4. Provide a comprehensive README.md file

## SDK STRUCTURE REQUIREMENTS
{{ SDK_STRUCTURE }}

## API CLIENT REQUIREMENTS
{{ API_CLIENT }}

## RESOURCE MODEL REQUIREMENTS 
{{ RESOURCE_MODEL }}

## DOCUMENTATION REQUIREMENTS
{{ DOCUMENTATION }}

I'll need to integrate this SDK with a Rails application that processes healthcare data using AI for analysis and predictions. Please ensure the SDK is designed with this use case in mind.
EOF

# Create individual requirement files
cat > sdk_structure_req.txt << 'EOF'
The SDK should follow these structure requirements:
- Use standard Ruby gem structure with lib/ directory
- Implement a HealthSync namespace for all components
- Support configuration via a Rails initializer
- Include proper error handling with custom exceptions
- Support logging compatible with Rails.logger
- Use RSpec for testing
- Follow a modular design with separate concerns
- Include thorough Yard documentation
EOF

cat > api_client_req.txt << 'EOF'
The API client should:
- Support OAuth2 authentication with refresh token capability
- Handle rate limiting with exponential backoff
- Support request/response logging (with PII filtering)
- Implement proper error handling for different HTTP status codes
- Support both synchronous and asynchronous requests
- Include request timeout configuration
- Support custom headers for tracking and debugging
- Implement proper TLS/SSL verification
EOF

cat > resource_model_req.txt << 'EOF'
Resource models should:
- Implement ActiveModel-like interfaces where appropriate
- Support serialization/deserialization from/to JSON
- Include validation using dry-validation or similar
- Support CRUD operations where applicable
- Handle nested resources appropriately
- Implement proper typecasting
- Support pagination for collection endpoints
- Include helper methods for common operations
EOF

cat > documentation_req.txt << 'EOF'
Documentation should include:
- Comprehensive README.md with installation instructions
- Quick start guide with common use cases
- Authentication setup instructions
- Error handling guide
- Complete API reference for all classes and methods
- Examples for integrating with Rails
- Security best practices
- Performance optimization tips
- Webhook handling examples
EOF

# Function to substitute template variables with file contents
process_template() {
  local template="$1"
  local output="$2"
  
  # Process each placeholder
  cat "$template" | 
    sed -e "/{{ SDK_STRUCTURE }}/r sdk_structure_req.txt" \
        -e "/{{ SDK_STRUCTURE }}/d" \
        -e "/{{ API_CLIENT }}/r api_client_req.txt" \
        -e "/{{ API_CLIENT }}/d" \
        -e "/{{ RESOURCE_MODEL }}/r resource_model_req.txt" \
        -e "/{{ RESOURCE_MODEL }}/d" \
        -e "/{{ DOCUMENTATION }}/r documentation_req.txt" \
        -e "/{{ DOCUMENTATION }}/d" > "$output"
}

# Process the template and create the final prompt
process_template "main_prompt.txt" "final_prompt.txt"

# Display execution instructions
echo "=== FILES CREATED ==="
echo "- sdk_structure_req.txt - SDK structure requirements"
echo "- api_client_req.txt - API client requirements"
echo "- resource_model_req.txt - Resource model requirements"
echo "- documentation_req.txt - Documentation requirements"
echo "- final_prompt.txt - Combined prompt file to use with Claude Code"
echo ""
echo "=== HOW TO USE ==="
echo "Run Claude Code with the combined prompt:"
echo "  claude-code -p final_prompt.txt"
echo ""
echo "To modify requirements, edit the individual *_req.txt files and run this script again."
