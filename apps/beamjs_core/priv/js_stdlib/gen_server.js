// beamjs:gen_server - Generic Server behavior for JavaScript
// Provides the GenServer class that maps to OTP GenServer patterns.

export class GenServer {
  init(args) {
    return {};
  }

  handleCall(request, from, state) {
    throw new Error(`Unhandled call: ${JSON.stringify(request)}`);
  }

  handleCast(request, state) {
    return { noreply: true, state };
  }

  handleInfo(message, state) {
    return { noreply: true, state };
  }

  terminate(reason, state) {}

  static start(ServerClass, args, opts) {
    const source = ServerClass.toString();
    return __beamjs_start_gen_server(
      ServerClass.name || 'AnonymousServer',
      source,
      args || {},
      opts || {}
    );
  }

  static startLink(ServerClass, args, opts) {
    const source = ServerClass.toString();
    return __beamjs_start_gen_server(
      ServerClass.name || 'AnonymousServer',
      source,
      args || {},
      Object.assign({}, opts || {}, { link: true })
    );
  }

  static call(server, request, timeout) {
    const pid = typeof server === 'string' ? __beamjs_whereis(server) : server;
    if (!pid) throw new Error(`Process not found: ${server}`);
    return __beamjs_call(pid, request, timeout || 5000);
  }

  static cast(server, request) {
    const pid = typeof server === 'string' ? __beamjs_whereis(server) : server;
    if (!pid) throw new Error(`Process not found: ${server}`);
    return __beamjs_cast(pid, request);
  }

  static reply(from, response) {
    return __beamjs_reply(from, response);
  }
}
