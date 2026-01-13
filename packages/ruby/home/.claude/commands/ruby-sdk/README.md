I routinely build ruby SDKs to message with external APIs. These SDKs are often integrated into Rails apps. Please generate a set of modular prompts that I can use with claude code


I'll create a set of modular prompts you can use with Claude Code to help build Ruby SDKs for API integration with Rails applications. These prompts can be saved as separate files and invoked using the `-p` flag.

I've created a set of modular prompts you can use with Claude Code to streamline your Ruby SDK development process. These are designed to be saved as individual text files that you can invoke with the `claude-code -p` command.

The prompts cover the full lifecycle of SDK development:

1. **Initial SDK Structure** - Sets up the foundation with proper directory structure, configuration, and dependencies
2. **API Client Implementation** - Creates the core HTTP client with authentication and error handling
3. **Resource Model Implementation** - Builds Ruby classes for specific API resources
4. **Pagination Implementation** - Handles different pagination methods with Enumerable support
5. **Error Handling** - Creates custom exception classes mapped to API error codes
6. **Authentication** - Implements token management and credential handling
7. **Testing Strategy** - Sets up RSpec, VCR, and mocks for thorough testing
8. **Rails Integration** - Optimizes the SDK for Rails with proper initializers and instrumentation
9. **Webhook Handling** - Implements webhook processing for event-driven functionality
10. **Documentation Generation** - Creates YARD docs and comprehensive README
11. **Performance Optimization** - Addresses connection pooling, caching, and benchmarking
12. **SDK Upgrade Implementation** - Handles version changes and backward compatibility

These prompts contain placeholders (like `[API_NAME]` or `[LIST_ENDPOINTS...]`) that you should replace with your specific details before using them with Claude Code.


Claude Code doesn't currently support specifying multiple prompt files with the `-p` flag in a single command. Each `-p` flag can only reference one file.

However, you have a few options to work with multiple prompt files:

1. **Create a single composite prompt file** that includes the content from multiple files, perhaps using a script to concatenate them

2. **Chain prompts sequentially** by sending the output of one Claude Code command as input to the next

3. **Create a shell script wrapper** that manages a multi-step workflow, passing results between Claude Code invocations

4. **Use a main prompt file that references others** - Your main prompt could instruct Claude to "read contents from these files" and then you could provide those files as context separately

If you're looking to build a more complex workflow with multiple prompts, you might want to consider creating a simple bash script that orchestrates the process, or using a tool like Make to define your prompt workflow steps.

Would you like me to create an example of how you might implement one of these approaches with your Ruby SDK development prompts?


I'll create an example of how to implement approach #4 - using a main prompt file that references other prompt files for your Ruby SDK development workflow.

I've created a script that demonstrates how to implement a main prompt file that references multiple other prompt files for your Ruby SDK development workflow.

Here's how this approach works:

1. The script creates a main prompt template (`main_prompt.txt`) that contains placeholders like `{{ SDK_STRUCTURE }}`, `{{ API_CLIENT }}`, etc.

2. It then creates separate requirement files for different aspects of your SDK:
   - `sdk_structure_req.txt` - Contains structure requirements
   - `api_client_req.txt` - Contains API client implementation requirements
   - `resource_model_req.txt` - Contains resource model requirements
   - `documentation_req.txt` - Contains documentation requirements

3. The script uses `sed` to replace the placeholders in the main prompt with the contents of these individual files, creating a `final_prompt.txt` file.

4. You can then use the combined `final_prompt.txt` with Claude Code: `claude-code -p final_prompt.txt`

### Benefits of this approach:

- You can maintain modular prompt files for different aspects of SDK development
- Each file stays focused on a specific concern, making them easier to update and maintain
- You can reuse the same component prompt files for different API SDKs
- The final prompt provides a comprehensive context with all requirements in one place

### How to use it:

1. Save the script to a file (e.g., `prepare_sdk_prompt.sh`)
2. Make it executable: `chmod +x prepare_sdk_prompt.sh`
3. Run the script: `./prepare_sdk_prompt.sh`
4. Use the generated `final_prompt.txt` with Claude Code

This approach gives you the modularity of separate prompt files with the convenience of a single prompt for Claude Code. You can easily modify the individual requirement files and regenerate the main prompt whenever needed.
