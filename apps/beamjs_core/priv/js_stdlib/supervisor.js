// beamjs:supervisor - Supervision trees for JavaScript processes
// Maps to OTP Supervisor patterns.

export class Supervisor {
  static start(spec) {
    return __beamjs_start_supervisor(spec);
  }

  static startLink(spec) {
    return __beamjs_start_supervisor(Object.assign({}, spec, { link: true }));
  }
}

// Strategy constants
export const ONE_FOR_ONE = "one_for_one";
export const ONE_FOR_ALL = "one_for_all";
export const REST_FOR_ONE = "rest_for_one";

// Restart constants
export const PERMANENT = "permanent";
export const TEMPORARY = "temporary";
export const TRANSIENT = "transient";
