// beamjs:test - Minimal test framework

const _tests = [];
let _currentDescribe = null;
let _passed = 0;
let _failed = 0;
let _errors = [];

export function describe(name, fn) {
  const prevDescribe = _currentDescribe;
  _currentDescribe = name;
  fn();
  _currentDescribe = prevDescribe;
}

export function it(name, fn) {
  const fullName = _currentDescribe ? `${_currentDescribe} > ${name}` : name;
  _tests.push({ name: fullName, fn });
}

// Alias
export const test = it;

export function expect(value) {
  return {
    toBe(expected) {
      if (value !== expected) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(value)}`);
      }
    },
    toEqual(expected) {
      if (JSON.stringify(value) !== JSON.stringify(expected)) {
        throw new Error(`Expected ${JSON.stringify(expected)}, got ${JSON.stringify(value)}`);
      }
    },
    toBeTruthy() {
      if (!value) {
        throw new Error(`Expected truthy, got ${JSON.stringify(value)}`);
      }
    },
    toBeFalsy() {
      if (value) {
        throw new Error(`Expected falsy, got ${JSON.stringify(value)}`);
      }
    },
    toThrow(message) {
      if (typeof value !== 'function') {
        throw new Error('Expected a function');
      }
      let threw = false;
      try {
        value();
      } catch (e) {
        threw = true;
        if (message && !e.message.includes(message)) {
          throw new Error(`Expected error containing "${message}", got "${e.message}"`);
        }
      }
      if (!threw) {
        throw new Error('Expected function to throw');
      }
    },
    toContain(item) {
      if (Array.isArray(value)) {
        if (!value.includes(item)) {
          throw new Error(`Expected array to contain ${JSON.stringify(item)}`);
        }
      } else if (typeof value === 'string') {
        if (!value.includes(item)) {
          throw new Error(`Expected string to contain "${item}"`);
        }
      }
    },
    toBeGreaterThan(n) {
      if (!(value > n)) {
        throw new Error(`Expected ${value} > ${n}`);
      }
    },
    toBeLessThan(n) {
      if (!(value < n)) {
        throw new Error(`Expected ${value} < ${n}`);
      }
    },
    toBeNull() {
      if (value !== null) {
        throw new Error(`Expected null, got ${JSON.stringify(value)}`);
      }
    },
    toBeUndefined() {
      if (value !== undefined) {
        throw new Error(`Expected undefined, got ${JSON.stringify(value)}`);
      }
    },
    toBeDefined() {
      if (value === undefined) {
        throw new Error('Expected value to be defined');
      }
    }
  };
}

export function run() {
  _passed = 0;
  _failed = 0;
  _errors = [];

  for (const t of _tests) {
    try {
      t.fn();
      _passed++;
      console.log(`  \u2713 ${t.name}`);
    } catch (e) {
      _failed++;
      _errors.push({ name: t.name, error: e.message });
      console.log(`  \u2717 ${t.name}`);
      console.log(`    ${e.message}`);
    }
  }

  console.log(`\n${_passed} passed, ${_failed} failed, ${_tests.length} total`);

  return { passed: _passed, failed: _failed, total: _tests.length, errors: _errors };
}
