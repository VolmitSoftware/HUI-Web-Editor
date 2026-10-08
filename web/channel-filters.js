(function (root) {
  'use strict';
  const defaults = Object.freeze({syntax: 're2', maxInputCharacters: 4096, maxOutputCharacters: 16384,
    maxPatternCharacters: 1024, maxReplacementCharacters: 4096, maxFilters: 64, maxMatches: 4096,
    maxProgramSize: 16384, maxNestingDepth: 32, maxWorkUnits: 2000000, budgetMicros: 2000, onLimit: 'drop'});
  const ranges = {maxInputCharacters: [1, 32768], maxOutputCharacters: [1, 262144],
    maxPatternCharacters: [1, 4096], maxReplacementCharacters: [0, 16384], maxFilters: [0, 256],
    maxMatches: [1, 65536], maxProgramSize: [16, 1000000], maxNestingDepth: [1, 128],
    maxWorkUnits: [1, 100000000], budgetMicros: [1, 100000]};
  const cache = new Map();
  let cachedSize = 0;
  function limitsFor(doc) {
    const limits = {...defaults, ...doc.filtering};
    if (limits.syntax !== 're2') throw new Error('filtering.syntax must be re2');
    if (!['drop', 'keep-completed'].includes(limits.onLimit)) throw new Error('Choose a supported filtering.onLimit policy');
    for (const [key, range] of Object.entries(ranges)) {
      if (!Number.isInteger(limits[key]) || limits[key] < range[0] || limits[key] > range[1]) {
        throw new Error(`filtering.${key} must be within ${range[0]}..${range[1]}`);
      }
    }
    return limits;
  }
  function estimate(pattern, limits) {
    const sizes = [0];
    const atoms = [0];
    let depth = 0;
    for (let index = 0; index < pattern.length; index++) {
      const value = pattern[index];
      if (value === '\\' && index + 1 < pattern.length) {
        const escaped = pattern[++index];
        if (escaped === 'Q') {
          const end = pattern.indexOf('\\E', index + 1);
          const stop = end < 0 ? pattern.length : end;
          atoms[depth] = Math.max(2, (stop - index - 1) * 2);
          sizes[depth] += atoms[depth];
          index = end < 0 ? pattern.length : end + 1;
        } else {
          if (['p', 'P', 'x'].includes(escaped) && pattern[index + 1] === '{') {
            const end = pattern.indexOf('}', index + 2);
            index = end < 0 ? pattern.length : end;
          }
          atoms[depth] = 2;
          sizes[depth] += 2;
        }
      } else if (value === '[') {
        index++;
        if (pattern[index] === '^') index++;
        if (pattern[index] === ']') index++;
        for (; index < pattern.length; index++) {
          if (pattern[index] === '\\') index++;
          else if (pattern[index] === ']') break;
        }
        atoms[depth] = 2;
        sizes[depth] += 2;
      } else if (value === '(') {
        if (++depth > limits.maxNestingDepth) throw new Error('filtering.maxNestingDepth exceeded');
        sizes[depth] = 2;
        atoms[depth] = 0;
      } else if (value === ')' && depth > 0) {
        const group = sizes[depth--] + 2;
        atoms[depth] = group;
        sizes[depth] += group;
      } else if (value === '{') {
        const end = pattern.indexOf('}', index + 1);
        const repeat = end < 0 ? null : /^(\d+)(?:,(\d*))?$/.exec(pattern.slice(index + 1, end));
        if (repeat) {
          const count = text => text.length > 4 ? 1001 : Math.min(1001, Number(text));
          const minimum = count(repeat[1]);
          const copies = Math.max(1, repeat[2] === undefined ? minimum : repeat[2] === '' ? minimum + 1 : count(repeat[2]));
          const expanded = atoms[depth] * copies + 2;
          sizes[depth] += expanded - atoms[depth];
          atoms[depth] = expanded;
          index = end;
        } else {
          atoms[depth] = 2;
          sizes[depth] += 2;
        }
      } else if (value === '*' || value === '+' || value === '?') {
        sizes[depth] += 2;
        atoms[depth] += 2;
      } else {
        atoms[depth] = 2;
        sizes[depth] += 2;
      }
      if (sizes[depth] > limits.maxProgramSize) throw new Error('Conservative filtering.maxProgramSize bound exceeded');
    }
  }
  function compile(filter, limits) {
    if (typeof filter.match !== 'string' || filter.match.trim() === '') throw new Error('A filter requires a match pattern');
    if (filter.match.length > limits.maxPatternCharacters) throw new Error('filtering.maxPatternCharacters exceeded');
    if ((filter.replace ?? '').length > limits.maxReplacementCharacters) throw new Error('filtering.maxReplacementCharacters exceeded');
    estimate(filter.match, limits);
    let pattern = cache.get(filter.match);
    if (!pattern) {
      pattern = root.RE2JS.RE2JS.compile(filter.match);
      const size = pattern.programSize();
      if (size <= 65536) {
        while (cache.size >= 64 || cachedSize + size > 65536) {
          const key = cache.keys().next().value;
          cachedSize -= cache.get(key).programSize();
          cache.delete(key);
        }
        cache.set(filter.match, pattern);
        cachedSize += size;
      }
    }
    if (pattern.programSize() > limits.maxProgramSize) throw new Error('filtering.maxProgramSize exceeded');
    return pattern;
  }
  function validate(doc) {
    if (!root.RE2JS) return 'RE2 preview engine is unavailable';
    try {
      const limits = limitsFor(doc);
      if ((doc.filters ?? []).length > limits.maxFilters) throw new Error('filtering.maxFilters exceeded');
      for (const filter of doc.filters ?? []) compile(filter, limits);
      return null;
    } catch (error) {
      return error.message;
    }
  }
  function run(doc, message, clock = () => performance.now() * 1000) {
    if (message == null || message.trim() === '') return {message: null, notice: null};
    if (!(doc.filters ?? []).length) return {message, notice: null};
    const invalid = validate(doc);
    if (invalid) return {message, notice: invalid};
    const limits = limitsFor(doc);
    const limited = (current, reason, forceDrop = false) => ({
      message: forceDrop || limits.onLimit === 'drop' || current.trim() === '' ? null : current,
      notice: `Filter limit: ${reason}. ${forceDrop || limits.onLimit === 'drop' ? 'Message dropped.' : 'Only completed filters retained.'}`
    });
    if (message.length > limits.maxInputCharacters || message.length > limits.maxOutputCharacters) return limited(message, 'input size', true);
    let current = message;
    let work = 0;
    let matches = 0;
    const started = clock();
    for (let index = 0; index < doc.filters.length; index++) {
      const filter = doc.filters[index];
      const pattern = compile(filter, limits);
      const matcher = pattern.matcher(current);
      const parts = [];
      let length = 0;
      let cursor = 0;
      while (true) {
        work += pattern.programSize() * (current.length - cursor + 1);
        if (work > limits.maxWorkUnits) return limited(current, 'work units');
        if (!matcher.find()) break;
        if (++matches > limits.maxMatches) return limited(current, 'match count');
        if ((matches & 63) === 0 && clock() - started >= limits.budgetMicros) return limited(current, 'elapsed target');
        const replacement = filter.replace ?? '';
        length += matcher.start() - cursor + replacement.length;
        if (length > limits.maxOutputCharacters) return limited(current, 'output size');
        parts.push(current.slice(cursor, matcher.start()), replacement);
        cursor = matcher.end();
      }
      if (length + current.length - cursor > limits.maxOutputCharacters) return limited(current, 'output size');
      parts.push(current.slice(cursor));
      current = parts.join('');
      if (clock() - started >= limits.budgetMicros) {
        if (index + 1 < doc.filters.length) return limited(current, 'elapsed target');
        return {message: current.trim() === '' ? null : current, notice: 'Elapsed target exceeded after all filters completed.'};
      }
    }
    return {message: current.trim() === '' ? null : current, notice: null};
  }
  root.GlossChannelFilters = {run, validate,
    validateBehaviorJson: source => {
      if (!root.RE2JS) return 'RE2 validation engine is unavailable';
      try {
        const doc = JSON.parse(source);
        const limits = limitsFor({filtering: doc.matching});
        for (const entry of doc.on ?? []) {
          if (entry.pattern != null) compile({match: entry.pattern, replace: ''}, limits);
        }
        return null;
      } catch (error) {
        return error.message.replaceAll('filtering.', 'matching.');
      }
    },
    runJson: (source, message) => JSON.stringify(run(JSON.parse(source), message)),
    validateJson: source => validate(JSON.parse(source))};
})(globalThis);
