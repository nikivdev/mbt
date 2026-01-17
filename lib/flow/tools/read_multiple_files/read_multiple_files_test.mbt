///|
async test "nonexistent" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let args : Json = { "files": [{ "path": "nonexistent.txt" }] }
    let tool = @read_multiple_files.new(manager)
    let result = tool.call(args)
    inspect(
      result,
      content=(
        #|Error reading file: File not found: nonexistent.txt
        #|[
        #|  "MultipleErrors",
        #|  [
        #|    [
        #|      [
        #|        "ToolFailure",
        #|        "Error reading file: File not found: nonexistent.txt"
        #|      ],
        #|      "Error reading file: File not found: nonexistent.txt"
        #|    ]
        #|  ]
        #|]
      ),
    )
    @json.inspect(result, content=[
      "Error",
      [
        "MultipleErrors",
        [
          [
            [
              "ToolFailure", "Error reading file: File not found: nonexistent.txt",
            ],
            "Error reading file: File not found: nonexistent.txt",
          ],
        ],
      ],
      "Error reading file: File not found: nonexistent.txt",
    ])
  })
}

///|
async test "content" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file(
      "foo.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
        #|line 4
      ),
    )
    let _ = taco.add_file(
      "bar.txt",
      content=(
        #|line 1 hello world
        #|line 2 apple
        #|line 3 orange
        #|line 4
      ),
    )
    let args : Json = {
      "files": [{ "path": "foo.txt" }, { "path": "bar.txt" }],
    }
    let tool = @read_multiple_files.new(manager)
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "ReadMultipleFilesResult",
      [
        [
          "ReadFileResult",
          {
            "path": "bar.txt",
            "content": "line 1 hello world\nline 2 apple\nline 3 orange\nline 4",
            "start_line": 1,
            "end_line": 4,
          },
        ],
        [
          "ReadFileResult",
          {
            "path": "foo.txt",
            "content": "line 1\nline 2\nline 3\nline 4",
            "start_line": 1,
            "end_line": 4,
          },
        ],
      ],
    ])
    inspect(
      output,
      content=(
        #|File: bar.txt (lines 1-4 (4 lines))
        #|line 1 hello world
        #|line 2 apple
        #|line 3 orange
        #|line 4
        #|
        #|File: foo.txt (lines 1-4 (4 lines))
        #|line 1
        #|line 2
        #|line 3
        #|line 4
        #|
        #|
      ),
    )
  })
}

///|
async test "line_range" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file(
      "foo.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
        #|line 4
        #|line 5
      ),
    )
    let _ = taco.add_file(
      "bar.txt",
      content=(
        #|line 1 hello world
        #|line 2 apple
        #|line 3 orange
        #|line 4
      ),
    )
    let args : Json = {
      "files": [
        { "path": "foo.txt", "start_line": 2, "end_line": 4 },
        { "path": "bar.txt", "start_line": 1, "end_line": 3 },
      ],
    }
    let tool = @read_multiple_files.new(manager)
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "ReadMultipleFilesResult",
      [
        [
          "ReadFileResult",
          {
            "path": "bar.txt",
            "content": "line 1 hello world\nline 2 apple\nline 3 orange\nline 4",
            "start_line": 1,
            "end_line": 3,
          },
        ],
        [
          "ReadFileResult",
          {
            "path": "foo.txt",
            "content": "line 1\nline 2\nline 3\nline 4\nline 5",
            "start_line": 2,
            "end_line": 4,
          },
        ],
      ],
    ])
    inspect(
      output,
      content=(
        #|File: bar.txt (lines 1-3 (3 lines))
        #|line 1 hello world
        #|line 2 apple
        #|line 3 orange
        #|
        #|File: foo.txt (lines 2-4 (3 lines))
        #|line 2
        #|line 3
        #|line 4
        #|
        #|
      ),
    )
  })
}

///|
async test "directory" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    taco.add_files([("file1.txt", "content1"), ("file2.txt", "content2")])
    let subdir = taco.add_directory("subdir")
    let _ = subdir.add_file("file3.txt", content="content3")
    let args : Json = { "files": [{ "path": "." }] }
    let tool = @read_multiple_files.new(manager)
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "ReadMultipleFilesResult",
      [
        [
          "ReadDirectoryResult",
          {
            "path": ".",
            "entries": ["subdir/", "file1.txt", "file2.txt"],
            "display": "subdir/\nfile1.txt\nfile2.txt",
          },
        ],
      ],
    ])
    inspect(
      output,
      content=(
        #|Directory: .
        #|Entries:
        #|subdir/
        #|file1.txt
        #|file2.txt
        #|
        #|
      ),
    )
  })
}

///|
async test "invalid-range" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    let _ = taco.add_file(
      "test.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
      ),
    )
    let _ = taco.add_file(
      "foo.txt",
      content=(
        #|line 1
        #|line 2
        #|line 3
        #|line 4
        #|line 5
      ),
    )
    let _ = taco.add_file(
      "bar.txt",
      content=(
        #|line 1 hello world
        #|line 2 apple
        #|line 3 orange
        #|line 4
      ),
    )
    let args : Json = {
      "files": [
        { "path": "test.txt", "start_line": 3, "end_line": 2 },
        { "path": "foo.txt", "start_line": 1, "end_line": 2 },
        { "path": "bar.txt", "start_line": 3, "end_line": 2 },
      ],
    }
    let result = new(manager).call(args)
    inspect(
      result,
      content=(
        #|Error: end_line (2) must be greater than start_line (3)
        #|Error: end_line (2) must be greater than start_line (3)
        #|[
        #|  "MultipleErrors",
        #|  [
        #|    [
        #|      [
        #|        "ToolFailure",
        #|        "Error: end_line (2) must be greater than start_line (3)"
        #|      ],
        #|      "Error: end_line (2) must be greater than start_line (3)"
        #|    ],
        #|    [
        #|      [
        #|        "ToolFailure",
        #|        "Error: end_line (2) must be greater than start_line (3)"
        #|      ],
        #|      "Error: end_line (2) must be greater than start_line (3)"
        #|    ]
        #|  ]
        #|]
      ),
    )
    let args : Json = { "files": [{ "path": "test.txt", "start_line": 0 }] }
    let result = new(manager).call(args)
    inspect(
      result,
      content=(
        #|Error: start_line must be >= 1, got 0
        #|[
        #|  "MultipleErrors",
        #|  [
        #|    [
        #|      [
        #|        "ToolFailure",
        #|        "Error: start_line must be >= 1, got 0"
        #|      ],
        #|      "Error: start_line must be >= 1, got 0"
        #|    ]
        #|  ]
        #|]
      ),
    )
    let args : Json = {
      "files": [{ "path": "test.txt", "start_line": 2, "end_line": 1024 }],
    }
    let tool = new(manager)
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "ReadMultipleFilesResult",
      [
        [
          "ReadFileResult",
          {
            "path": "test.txt",
            "content": "line 1\nline 2\nline 3",
            "start_line": 2,
            "end_line": 3,
          },
        ],
      ],
    ])
    inspect(
      output,
      content=(
        #|File: test.txt (lines 2-3 (2 lines))
        #|line 2
        #|line 3
        #|
        #|
      ),
    )
  })
}

///|
async test "read multiple mixed files" (t : @test.Test) {
  @mock.run(t, taco => {
    let manager = @file.manager(cwd=taco.cwd.path())
    taco.add_files([("file1.txt", "content1"), ("file2.txt", "content2")])
    let subdir = taco.add_directory("subdir")
    let _ = subdir.add_file("file3.txt", content="content3")
    let args : Json = {
      "files": [
        { "path": "file1.txt" },
        { "path": "file2.txt" },
        { "path": "subdir" },
      ],
    }
    let tool = @read_multiple_files.new(manager)
    let result = tool.call(args)
    guard result is Ok(output) else {
      fail("Expected Ok result but got: \{result}")
    }
    @json.inspect(output, content=[
      "ReadMultipleFilesResult",
      [
        [
          "ReadDirectoryResult",
          { "path": "subdir", "entries": ["file3.txt"], "display": "file3.txt" },
        ],
        [
          "ReadFileResult",
          {
            "path": "file1.txt",
            "content": "content1",
            "start_line": 1,
            "end_line": 1,
          },
        ],
        [
          "ReadFileResult",
          {
            "path": "file2.txt",
            "content": "content2",
            "start_line": 1,
            "end_line": 1,
          },
        ],
      ],
    ])
    inspect(
      output,
      content=(
        #|Directory: subdir
        #|Entries:
        #|file3.txt
        #|
        #|File: file1.txt (lines 1-1 (1 lines))
        #|content1
        #|
        #|File: file2.txt (lines 1-1 (1 lines))
        #|content2
        #|
        #|
      ),
    )
  })
}
