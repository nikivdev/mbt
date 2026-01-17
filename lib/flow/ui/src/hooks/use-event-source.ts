import { useAppDispatch } from "@/app/hooks";
import { addEvent } from "@/features/session/sessionSlice";
import { useEffect, useRef } from "react";

export function useEventSource(url: string) {
  const eventSource = useRef<EventSource | null>(null);
  const dispatch = useAppDispatch();
  useEffect(() => {
    if (eventSource.current) return;
    console.log("Establishing new EventSource connection to:", url);
    eventSource.current = new EventSource(url);

    eventSource.current.addEventListener(
      "maria",
      (event: MessageEvent<string>) => {
        const data = JSON.parse(event.data);
        dispatch(addEvent(data));
      },
    );

    return () => {
      eventSource.current?.close();
      eventSource.current = null;
    };
  }, [dispatch, url]);
}
