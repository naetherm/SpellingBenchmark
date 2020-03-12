// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.tokenizer;

import std.regex;

/**
 * The default tokenizer for all sentences.
 */
alias Tokenizer = ctRegex!r"(?:\d+[,.]\d+)|(?:[\w'\u0080-\u9999]+(?:[-]+[\w'\u0080-\u9999]+)+)|(?:[\w\u0080-\u9999]+(?:[']+[\w\u0080-\u9999]+)+)|\b[_]|(?:[_]*[\w\u0080-\u9999]+(?=_\b))|(?:[\w\u00A1-\u9999]+)|[^\w\s\u00A0\p{Z}]";
