// beamjs:timer - Timer utilities
// Note: setTimeout/setInterval are not natively available in QuickJS.
// These are bridged through the BEAM scheduler.

export function sleep(ms) {
  return __beamjs_receive(ms);
}

export function sendAfter(pid, message, delay) {
  return __beamjs_send_after(pid, message, delay);
}
