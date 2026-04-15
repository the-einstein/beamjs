// beamjs:agent - Simple state management
// Maps to OTP Agent patterns.

export class Agent {
  constructor(pid) {
    this.pid = pid;
  }

  static start(initialFn, opts) {
    const initial = typeof initialFn === 'function' ? initialFn() : initialFn;
    const result = __beamjs_agent_start(initial, opts || {});
    if (result.ok) {
      return new Agent(result.ok);
    }
    throw new Error(result.error || "Failed to start agent");
  }

  get(fn) {
    if (fn) {
      return __beamjs_agent_get(this.pid, fn.toString());
    }
    return __beamjs_agent_get(this.pid, "function(s) { return s; }");
  }

  update(fn) {
    return __beamjs_agent_update(this.pid, fn.toString());
  }

  stop() {
    return __beamjs_agent_stop(this.pid);
  }
}
