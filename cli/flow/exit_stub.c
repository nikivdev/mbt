#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#ifndef _WIN32
#include <unistd.h>
#include <sys/stat.h>
#endif
#include "moonbit.h"

MOONBIT_FFI_EXPORT int32_t moonbit_flow_exit(int32_t code) {
  exit(code);
}

#ifndef _WIN32
MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_flow_fzf_select(moonbit_bytes_t input) {
  if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO)) {
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }

  int32_t length = Moonbit_array_length(input);
  char template_path[] = "/tmp/flow-fzf-XXXXXX";
  int fd = mkstemp(template_path);
  if (fd == -1) {
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }

  int32_t written = 0;
  while (written < length) {
    ssize_t chunk = write(fd, input + written, (size_t)(length - written));
    if (chunk <= 0) {
      close(fd);
      unlink(template_path);
      return (moonbit_bytes_t)moonbit_empty_int8_array;
    }
    written += (int32_t)chunk;
  }
  close(fd);

  char command[512];
  int n = snprintf(command, sizeof(command),
                   "fzf --height=40%% --layout=reverse-list --prompt='fm> ' "
                   "--info=inline --border=rounded < '%s'",
                   template_path);
  if (n <= 0 || (size_t)n >= sizeof(command)) {
    unlink(template_path);
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }

  FILE *pipe = popen(command, "r");
  if (!pipe) {
    unlink(template_path);
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }

  char buffer[4096];
  char *line = fgets(buffer, sizeof(buffer), pipe);
  int status = pclose(pipe);
  unlink(template_path);
  if (!line || status != 0) {
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }

  size_t out_len = strlen(buffer);
  while (out_len > 0 && (buffer[out_len - 1] == '\n' || buffer[out_len - 1] == '\r')) {
    out_len--;
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)out_len, 0);
  if (out_len > 0) {
    memcpy(result, buffer, out_len);
  }
  return result;
}
#else
MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_flow_fzf_select(moonbit_bytes_t input) {
  (void)input;
  return (moonbit_bytes_t)moonbit_empty_int8_array;
}
#endif

MOONBIT_FFI_EXPORT moonbit_bytes_t moonbit_flow_read_line(void) {
#ifdef _WIN32
  char buffer[4096];
  if (!fgets(buffer, sizeof(buffer), stdin)) {
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }
  size_t len = strlen(buffer);
  while (len > 0 && (buffer[len - 1] == '\n' || buffer[len - 1] == '\r')) {
    len--;
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(result, buffer, len);
  }
  return result;
#else
  char *line = NULL;
  size_t cap = 0;
  ssize_t read = getline(&line, &cap, stdin);
  if (read < 0) {
    if (line) {
      free(line);
    }
    return (moonbit_bytes_t)moonbit_empty_int8_array;
  }
  while (read > 0 && (line[read - 1] == '\n' || line[read - 1] == '\r')) {
    read--;
  }
  moonbit_bytes_t result = moonbit_make_bytes((int32_t)read, 0);
  if (read > 0) {
    memcpy(result, line, (size_t)read);
  }
  free(line);
  return result;
#endif
}
