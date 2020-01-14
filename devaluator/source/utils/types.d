// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.types;

import std.string;
import std.container.array;

enum ErrorTypes {
  // Invalid, comparable with <PAD>
  //PAD = -1,
  // No error detected
  NONE = 0,
  // Non-word error
  NON_WORD = 1,
  // Real-word confusion
  REAL_WORD = 2,
  // Wrong splitting
  SPLIT = 3,
  // Hyphenation error
  HYPHENATION = 4,
  // Compound hypen error
  COMPOUND_HYPHEN = 5,
  // Concatenation error
  CONCATENATION = 6,
  // Capitalisation error
  CAPITALISATION = 7,
  // Outdated spelling for a word
  ARCHAIC = 8,
  // Repeat a word twice
  REPEAT = 9,
  // Repeat a word twice
  PUNCTUATION = 10,
  // Type for Entity Mention Mismatch
  MENTION_MISMATCH = 11,
  // Tense mismatch
  TENSE = 12
}

string TypeToName(ErrorTypes nType) {
  switch (nType) with (ErrorTypes) {
    //case PAD:
    //  return "PAD";
    case NONE:
      return "NONE";
    case NON_WORD:
      return "NON_WORD";
    case REAL_WORD:
      return "REAL_WORD";
    case SPLIT:
      return "SPLIT";
    case HYPHENATION:
      return "HYPHENATION";
    case COMPOUND_HYPHEN:
      return "COMPOUND_HYPHEN";
    case CONCATENATION:
      return "CONCATENATION";
    case CAPITALISATION:
      return "CAPITALISATION";
    case ARCHAIC:
      return "ARCHAIC";
    case REPEAT:
      return "REPEAT";
    case PUNCTUATION:
      return "PUNCTUATION";
    case MENTION_MISMATCH:
      return "MENTION_MISMATCH";
    case TENSE:
      return "TENSE";
    default:
      return "NONE";
  }
}

ErrorTypes NameToType(string name) {
  //if (name == "PAD") {
  //  return ErrorTypes.PAD;
  //}
  if (name == "NONE") {
    return ErrorTypes.NONE;
  }
  if (name == "NON_WORD") {
    return ErrorTypes.NON_WORD;
  }
  if (name == "REAL_WORD") {
    return ErrorTypes.REAL_WORD;
  }
  if (name == "SPLIT") {
    return ErrorTypes.SPLIT;
  }
  if (name == "HYPHENATION") {
    return ErrorTypes.HYPHENATION;
  }
  if (name == "COMPOUND_HYPHEN") {
    return ErrorTypes.COMPOUND_HYPHEN;
  }
  if (name == "CONCATENATION") {
    return ErrorTypes.CONCATENATION;
  }
  if (name == "CAPITALISATION") {
    return ErrorTypes.CAPITALISATION;
  }
  if (name == "ARCHAIC") {
    return ErrorTypes.ARCHAIC;
  }
  if (name == "REPEAT") {
    return ErrorTypes.REPEAT;
  }
  if (name == "PUNCTUATION") {
    return ErrorTypes.PUNCTUATION;
  }
  if (name == "MENTION_MISMATCH") {
    return ErrorTypes.MENTION_MISMATCH;
  }
  if (name == "TENSE") {
    return ErrorTypes.TENSE;
  }

  return ErrorTypes.NONE;
}

/**
 * @enum
 * MarkTypes
 *
 * @brief
 * Enumeration for marking structures within the SentenceRepresentation.
 */
enum MarkTypes {
  NONE = 0,

  SINGLE = 1,

  START = 2,

  INNER = 3,

  END = 4
}

string MarkToName(MarkTypes nMark) {
  switch (nMark) with (MarkTypes) {
    case NONE:
      return "NONE";
    case SINGLE:
      return "SINGLE";
    case START:
      return "START";
    case INNER:
      return "INNER";
    case END:
      return "END";
    default:
      return "NONE";
  }
}


enum GroupAssociation {
  PRD2SRC = 0,
  PRD2GRT = 1
}
