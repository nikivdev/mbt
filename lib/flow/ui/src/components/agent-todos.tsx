import { useState } from "react";
import { CheckCircle2, Circle, Clock, ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";
import type { Todo } from "@/features/session/sessionSlice";
import { Badge } from "@/components/ui/badge";
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible";

interface AgentTodosProps {
  todos: Todo[];
}

function getStatusIcon(status: Todo["status"]) {
  switch (status) {
    case "Completed":
      return <CheckCircle2 className="h-3.5 w-3.5 text-green-600" />;
    case "InProgress":
      return <Clock className="h-3.5 w-3.5 text-blue-600" />;
    case "Pending":
      return <Circle className="h-3.5 w-3.5 text-gray-400" />;
  }
}

function getStatusColor(status: Todo["status"]) {
  switch (status) {
    case "Completed":
      return "bg-green-50/50 dark:bg-green-950/20";
    case "InProgress":
      return "bg-blue-50/50 dark:bg-blue-950/20";
    case "Pending":
      return "bg-muted/50";
  }
}

function getPriorityColor(priority: Todo["priority"]) {
  switch (priority) {
    case "High":
      return "bg-red-100 dark:bg-red-900/40 text-red-800 dark:text-red-200";
    case "Medium":
      return "bg-yellow-100 dark:bg-yellow-900/40 text-yellow-800 dark:text-yellow-200";
    case "Low":
      return "bg-green-100 dark:bg-green-900/40 text-green-800 dark:text-green-200";
  }
}

function computeTodoMetrics(todos: Todo[]) {
  let completed = 0;
  let inProgress = 0;
  let pending = 0;
  for (const todo of todos) {
    switch (todo.status) {
      case "Completed":
        completed++;
        break;
      case "InProgress":
        inProgress++;
        break;
      case "Pending":
        pending++;
        break;
    }
  }
  return { completed, inProgress, pending };
}

interface TodoItemProps {
  todo: Todo;
  isExpanded: boolean;
  onToggleExpanded: () => void;
}

function TodoItem({ todo, isExpanded, onToggleExpanded }: TodoItemProps) {
  return (
    <Collapsible open={isExpanded} onOpenChange={onToggleExpanded}>
      <div
        className={cn(
          "flex items-start gap-2 p-2 rounded border shadow-sm transition-colors",
          getStatusColor(todo.status),
        )}
      >
        <div className="mt-0.5">{getStatusIcon(todo.status)}</div>
        <CollapsibleTrigger className="flex-1 min-w-0 text-left">
          <div className="flex items-start gap-1.5">
            <div className="flex-1">
              <div
                className={cn(
                  "text-xs wrap-break-word",
                  !isExpanded && "line-clamp-1",
                  todo.status === "Completed" &&
                    "line-through text-muted-foreground",
                )}
              >
                {todo.content}
              </div>
            </div>
            <Badge
              variant={"outline"}
              className={cn(
                getPriorityColor(todo.priority),
                "text-[10px] h-4 px-1",
              )}
            >
              {todo.priority}
            </Badge>
          </div>
        </CollapsibleTrigger>
      </div>
    </Collapsible>
  );
}

export function AgentTodos({ todos }: AgentTodosProps) {
  const [expandTodos, setExpandTodos] = useState<boolean>(false);
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const { completed, inProgress, pending } = computeTodoMetrics(todos);

  if (todos.length === 0) {
    return null;
  }

  const toggleExpanded = (id: string) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  return (
    <div className="px-3 py-2">
      <Collapsible
        open={expandTodos}
        onOpenChange={() => setExpandTodos(!expandTodos)}
      >
        <CollapsibleTrigger className="flex items-center gap-1.5 pb-2 w-full">
          <div className="text-xs font-semibold text-foreground">Todos</div>
          <Badge variant="outline" className="text-[10px] h-4 px-1">
            {completed} Completed
          </Badge>
          <Badge variant="outline" className="text-[10px] h-4 px-1">
            {inProgress} In Progress
          </Badge>
          <Badge variant="outline" className="text-[10px] h-4 px-1">
            {pending} Pending
          </Badge>
          <ChevronDown
            className={cn(
              "size-3.5 ml-auto transition-transform",
              expandTodos && "rotate-180",
            )}
          />
        </CollapsibleTrigger>

        <CollapsibleContent className="space-y-1.5">
          {todos.map((todo) => (
            <TodoItem
              key={todo.id}
              todo={todo}
              isExpanded={expandedIds.has(todo.id)}
              onToggleExpanded={() => toggleExpanded(todo.id)}
            />
          ))}
        </CollapsibleContent>
      </Collapsible>
    </div>
  );
}
