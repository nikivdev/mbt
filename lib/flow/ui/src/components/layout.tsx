import {
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from "@/components/ui/sidebar";
import { AppSidebar } from "@/components/app-sidebar";

export function Layout({ children }: { children: React.ReactNode }) {
  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset className="flex flex-col h-dvh overflow-x-hidden">
        {/* TODO: hide the header on desktop screen, move it to sidebar */}
        <header className="flex items-center md:p-2">
          <div className="flex items-center md:hidden gap-3 p-2">
            <SidebarTrigger className="scale-150" />
            <h1 className="font-semibold text-xl">Maria</h1>
          </div>
        </header>
        {/* <main className="flex-1 min-h-0 flex flex-col">
          <div className="flex-1 min-h-0 overflow-y-auto bg-red-50">
            <div className="bg-black overflow-x-auto">
              <div className="bg-yellow-50 w-[400px] h-[400px]">children</div>
            </div>
          </div>
          <div className="h-[100px] bg-blue-50"></div>
        </main> */}
        <div className="flex-1 min-h-0 flex flex-col">{children}</div>
      </SidebarInset>
    </SidebarProvider>
  );
}
