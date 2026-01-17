# Maria Node.js Examples

This directory contains example usage of the Maria Node.js SDK.

## Running the example

1. Install dependencies:

   ```bash
   npm install
   ```

2. Run the example:

   ```bash
   npm start
   ```

## Example: main.ts

This example demonstrates how to use the Maria SDK to interact with the agent:

- Starts a Maria agent with a prompt
- Listens for events from the agent
- Handles two types of events:
  - `maria.agent.request_completed`: Prints the assistant's response
  - `maria.agent.post_tool_call`: Prints tool call information and output

The example shows how to parse and display tool calls and their results in a formatted way.
