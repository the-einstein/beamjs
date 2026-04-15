// beamjs:process - Process management, message passing, and concurrency
// These functions bridge to BEAM OTP processes via host function callbacks.

export function self() {
  return __beamjs_self();
}

export function spawn(fn, opts) {
  const source = typeof fn === 'string' ? fn : `(${fn.toString()})()`;
  return __beamjs_spawn(source, opts || {});
}

export function spawnLink(fn, opts) {
  const source = typeof fn === 'string' ? fn : `(${fn.toString()})()`;
  return __beamjs_spawn_link(source, opts || {});
}

export function send(pid, message) {
  return __beamjs_send(pid, message);
}

export function receive(timeout) {
  return __beamjs_receive(timeout || 0);
}

export function register(name) {
  return __beamjs_register(name);
}

export function whereis(name) {
  return __beamjs_whereis(name);
}

export function monitor(pid) {
  return __beamjs_monitor(pid);
}

export function link(pid) {
  return __beamjs_link(pid);
}

export function exit(reason) {
  return __beamjs_exit(reason || "normal");
}
