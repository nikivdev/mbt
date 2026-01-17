import { useState } from "react";
import { Layout } from "@/components/layout";
import { EventsDisplay } from "@/components/events-display";
import { AgentTodos } from "@/components/agent-todos";
import {
  useGetEventsQuery,
  usePostMessageMutation,
} from "@/features/api/apiSlice";
import {
  PromptInput,
  PromptInputSubmit,
  PromptInputTextarea,
  PromptInputToolbar,
  PromptInputTools,
} from "@/components/ai/prompt-input";
import { useAppSelector } from "@/app/hooks";
import {
  selectTodos,
  selectWaitingForEvent,
} from "@/features/session/sessionSlice";
import type { ChatStatus } from "ai";

function ChatView() {
  const [input, setInput] = useState("");
  const todos = useAppSelector(selectTodos);
  const waitingForEvent = useAppSelector(selectWaitingForEvent);

  const status: ChatStatus = waitingForEvent ? "submitted" : "ready";

  const [postMessage] = usePostMessageMutation();

  const { data } = useGetEventsQuery();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setInput("");
    await postMessage(input);
  };

  return (
    <div className="flex-1 min-h-0 flex flex-col m-auto w-full max-w-4xl relative">
      <AgentTodos todos={todos} />
      <EventsDisplay events={data ?? []} />
      <div className="p-4">
        <PromptInput onSubmit={handleSubmit}>
          <PromptInputTextarea
            className="text-lg md:text-lg"
            value={input}
            onFocus={(e) =>
              e.target.scrollIntoView({ behavior: "smooth", block: "center" })
            }
            onChange={(e) => setInput(e.currentTarget.value)}
            placeholder={"Input your task..."}
          />
          <PromptInputToolbar>
            <PromptInputTools></PromptInputTools>
            <PromptInputSubmit
              disabled={waitingForEvent && !input.trim()}
              status={status}
              className="cursor-pointer"
            ></PromptInputSubmit>
          </PromptInputToolbar>
        </PromptInput>
      </div>
    </div>
  );
}

function Home() {
  return (
    <Layout>
      <ChatView />
    </Layout>
  );
}

export default Home;
