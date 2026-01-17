from maria import Maria
import asyncio
import json


async def main():
    maria = Maria()
    async for event in maria.start(prompt="Hello?"):
        if event.method == "maria.agent.request_completed":
            content = event.params.message.content
            if content is not None:
                print(content)
        elif event.method == "maria.agent.post_tool_call":
            tool_call = event.params.tool_call
            tool_name = tool_call.function.name
            tool_args = tool_call.function.arguments
            try:
                tool_args = json.loads(tool_args)
                print(f"% {tool_name} {json.dumps(tool_args, indent=2)}")
            except json.JSONDecodeError:
                print(f"% {tool_name} {tool_args}")
            for line in event.params.text.splitlines():
                print(f"> {line}")


if __name__ == "__main__":
    asyncio.run(main())
