export type FileContent = {
    path: string;
    start_line?: number;
    end_line?: number;
}

export type Arguments = {
    files: FileContent[]
}