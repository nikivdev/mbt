import type { PayloadAction } from "@reduxjs/toolkit";
import { createAppSlice } from "@/app/createAppSlice";

type SessionEventBase = {
  time: number;
};

export type SessionEvent = SessionEventBase &
  (RequestCompletedEvent | PostToolCallEvent | MessageAddedEvent);

type ToolCallFunction = {
  name: string;
  arguments: string;
};

type ToolCall = {
  id: string;
  function: ToolCallFunction;
};

export type RequestCompletedEvent = {
  msg: "RequestCompleted";
  message: {
    content: string;
    role: "assistant";
    tool_calls: ToolCall[];
  };
};

export type ExecuteCommandTool = {
  name: "execute_command";
  result: [
    "Completed",
    {
      command: string;
      status: number;
      stdout: string;
      stderr: string;
      max_output_lines: number;
    },
  ];
  error?: unknown;
};

export type ListFilesTool = {
  name: "list_files";
  result: {
    path: string;
    entries: { name: string; kind: string; is_hidden: boolean }[];
    total_count: number;
    file_count: number;
    directory_count: number;
  };
};

export type ReadFileTool = {
  name: "read_file";
  result: {
    path: string;
    content: string;
    start_line: number;
    end_line: number;
  };
};

export type MetaWriteToFileTool = {
  name: "meta_write_to_file";
  result: { path: string; message: string; diff?: string };
};

export type Todo = {
  content: string;
  created_at: string;
  id: string;
  priority: "High" | "Medium" | "Low";
  status: "Pending" | "Completed" | "InProgress";
  updated_at: string;
};

export type TodoWriteTool = {
  name: "todo_write";
  result: {
    message: string;
    todos: Todo[];
    updated_todos: Todo[];
    is_new_creation: boolean;
  };
};

type UnknownTool = {
  name: string;
};

type PostToolCallBase = {
  msg: "PostToolCall";
  tool_call: ToolCall;
  text: string;
  result?: unknown;
  error?: string;
};

// TODO: search_files
export type PostToolCallEvent = PostToolCallBase &
  (
    | ExecuteCommandTool
    | ListFilesTool
    | ReadFileTool
    | MetaWriteToFileTool
    | TodoWriteTool
    | UnknownTool
  );

type MessageContentPart = {
  text: string;
};

type MessageBase = {
  content: MessageContentPart[] | string;
};

type SystemMessage = {
  role: "system";
};

type UserMessage = {
  role: "user";
};

export type AssistantMessage = {
  role: "assistant";
  tool_calls: ToolCall[];
};

export type ToolMessage = {
  role: "tool";
  tool_call_id: string;
};

export type MessageAddedEvent = {
  msg: "MessageAdded";
  message: MessageBase &
    (SystemMessage | UserMessage | AssistantMessage | ToolMessage);
};

export type SessionSliceState = {
  events: SessionEvent[];
  todos: Todo[];
  waitingForEvent: boolean;
};

const initialState: SessionSliceState = {
  events: [],
  todos: [],
  waitingForEvent: false,
};

export const sessionSlice = createAppSlice({
  name: "session",
  initialState,
  reducers: {
    addEvent(state, action: PayloadAction<SessionEvent>) {
      state.events.push(action.payload);
    },
    updateTodos(state, action: PayloadAction<Todo[]>) {
      state.todos = action.payload;
    },
    waitForEvent(state, action: PayloadAction<boolean>) {
      state.waitingForEvent = action.payload;
    },
  },
  selectors: {
    selectEvents: (state) => state.events,
    selectTodos: (state) => state.todos,
    selectWaitingForEvent: (state) => state.waitingForEvent,
  },
});

export const { addEvent, updateTodos, waitForEvent } = sessionSlice.actions;
export const { selectEvents, selectTodos, selectWaitingForEvent } =
  sessionSlice.selectors;
