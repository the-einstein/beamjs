// beamjs:task - Async task execution
// Maps to OTP Task patterns.

export class Task {
  constructor(pid, ref) {
    this.pid = pid;
    this.ref = ref;
  }

  static async(fn) {
    const source = typeof fn === 'string' ? fn : `(${fn.toString()})()`;
    const result = __beamjs_task_async(source);
    return new Task(result.pid, result.ref);
  }

  static await(task, timeout) {
    return __beamjs_task_await(task.ref, timeout || 5000);
  }

  static yield(task, timeout) {
    return __beamjs_task_await(task.ref, timeout || 0);
  }
}
